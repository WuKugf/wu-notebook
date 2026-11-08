import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../data/models/file_item.dart';
import '../../services/system_service.dart';
import '../../theme/wu_theme.dart';
import '../media/local_video_view.dart';
import '../widgets/wu_widgets.dart';

/// 文件库：导入照片、视频、PDF、文档等，全部保存在应用私有目录。
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _tag;
  bool _importing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FileItem> get _files => widget.state.files.where((e) => !e.inTrash).toList();

  List<String> get _tags {
    final set = <String>{};
    for (final file in _files) {
      set.addAll(file.tags);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  List<FileItem> get _visible {
    final query = _query.trim().toLowerCase();
    return _files.where((file) {
      if (_tag != null && !file.tags.contains(_tag)) return false;
      if (query.isEmpty) return true;
      return file.originalName.toLowerCase().contains(query) ||
          file.note.toLowerCase().contains(query) ||
          file.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  /// 选择本机文件并复制到附件目录。
  Future<void> _importFiles() async {
    if (!widget.state.supportsFiles) {
      wuSnack(context, '网页预览不支持导入本地文件');
      return;
    }
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await SystemService.instance.ensureStoragePermission();
      final picked = await FilePicker.pickFiles(type: FileType.any);
      if (picked.isEmpty) return;
      for (final file in picked) {
        final path = file.path;
        if (path == null) continue;
        final storedName = await widget.state.attachments.copyIntoStore(path, file.name);
        final size = await widget.state.attachments.sizeOf(storedName);
        widget.state.upsertFile(FileItem(
          id: WuUtils.newId(),
          originalName: file.name,
          storedName: storedName,
          size: size,
        ));
      }
      if (mounted) {
        wuSnack(context, '已导入 ${picked.length} 个文件');
      }
    } catch (error) {
      if (mounted) wuSnack(context, '导入失败：$error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 预览：图片直接看，视频本地播放，其他格式交给系统程序打开。
  Future<void> _preview(FileItem file) async {
    final store = widget.state.attachments;
    final path = store.pathOf(file.storedName);
    if (path == null) {
      wuSnack(context, '当前环境无法打开本地文件');
      return;
    }

    if (file.isImage) {
      final bytes = await store.readBytes(file.storedName);
      if (!mounted) return;
      if (bytes == null) {
        wuSnack(context, '图片文件不存在');
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: dialogContext.colors.surface,
          insetPadding: const EdgeInsets.all(WuSpace.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(WuSpace.md, WuSpace.sm, WuSpace.xs, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.originalName,
                          style: dialogContext.texts.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: InteractiveViewer(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: WuSpace.xs),
              ],
            ),
          ),
        ),
      );
      return;
    }

    if (file.isVideo) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: dialogContext.colors.surface,
          insetPadding: const EdgeInsets.all(WuSpace.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(WuSpace.sm),
              child: LocalVideoView(path: path),
            ),
          ),
        ),
      );
      return;
    }

    // PDF / 文档等：电脑端用系统默认程序打开；手机端给出提示。
    final opened = await SystemService.instance.openWithSystem(path);
    if (opened && SystemService.instance.isDesktop) {
      return;
    }
    if (mounted) {
      wuSnack(context, '这个格式需要在系统文件管理器里打开');
    }
  }

  /// 重命名 + 备注 + 标签。
  Future<void> _edit(FileItem file) async {
    final nameController = TextEditingController(text: file.originalName);
    final noteController = TextEditingController(text: file.note);
    final tagController = TextEditingController(text: file.tags.join('，'));

    final result = await showDialog<FileItem>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('文件信息'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: '文件名'),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: '备注（可不填）'),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: tagController,
                decoration: const InputDecoration(hintText: '分类标签，用逗号分隔'),
              ),
              const SizedBox(height: WuSpace.sm),
              Text(
                '${WuUtils.formatSize(file.size)} · ${WuUtils.formatDateTime(file.createdAt)}',
                style: dialogContext.texts.labelSmall,
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final tags = tagController.text
                  .split(RegExp('[,，]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();
              Navigator.of(dialogContext).pop(
                file.copyWith(
                  originalName: name.isEmpty ? file.originalName : name,
                  note: noteController.text.trim(),
                  tags: tags,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    nameController.dispose();
    noteController.dispose();
    tagController.dispose();

    if (result != null) {
      widget.state.upsertFile(result);
    }
  }

  /// 把单个文件导出到本机（电脑端是下载文件夹，手机端是应用外部目录）。
  Future<void> _export(FileItem file) async {
    try {
      final directory = await SystemService.instance.exportDirectory();
      if (directory == null) {
        if (mounted) wuSnack(context, '没有找到可用的导出目录');
        return;
      }
      final targetPath = '$directory/${file.originalName}';
      await widget.state.attachments.exportTo(file.storedName, targetPath);
      if (!mounted) return;
      if (SystemService.instance.isDesktop) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('已导出到 $targetPath'),
            action: SnackBarAction(
              label: '打开文件夹',
              onPressed: () => SystemService.instance.openFolder(directory),
            ),
          ));
      } else {
        wuSnack(context, '已导出到 $targetPath');
      }
    } catch (error) {
      if (mounted) wuSnack(context, '导出失败：$error');
    }
  }

  Future<void> _delete(FileItem file) async {
    final ok = await showWuConfirm(
      context,
      title: '删除「${file.originalName}」',
      message: '文件会移入回收站，可以之后恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    widget.state.moveToTrash(EntityType.file, file.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _visible;
    final tags = _tags;
    return WuPageScaffold(
      title: '文件库',
      subtitle: '共 ${_files.length} 个文件 · 全部保存在本机',
      actions: [
        OutlinedButton.icon(
          onPressed: _importing ? null : _importFiles,
          icon: Icon(Icons.add, size: 16, color: colors.inkSecondary),
          label: const Text('导入'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            minimumSize: const Size(0, 34),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
            child: WuSearchField(
              controller: _search,
              hintText: '搜索文件名、备注、标签',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: WuSpace.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
              child: Wrap(
                spacing: WuSpace.xs,
                runSpacing: WuSpace.xs,
                children: [
                  WuTag(
                    label: '全部',
                    selected: _tag == null,
                    onTap: () => setState(() => _tag = null),
                  ),
                  for (final tag in tags)
                    WuTag(
                      label: tag,
                      selected: _tag == tag,
                      onTap: () => setState(() => _tag = _tag == tag ? null : tag),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: WuSpace.sm),
          Expanded(
            child: items.isEmpty
                ? WuEmptyState(
                    icon: Icons.folder_outlined,
                    title: _files.isEmpty ? '文件库还是空的' : '没有匹配的文件',
                    hint: _files.isEmpty
                        ? '导入照片、视频、PDF 或文档，全部只存在本机'
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: WuSpace.sm),
                    itemBuilder: (context, index) {
                      final file = items[index];
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
                        child: _FileCard(
                          file: file,
                          onTap: () => _preview(file),
                          onEdit: () => _edit(file),
                          onExport: () => _export(file),
                          onDelete: () => _delete(file),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 文件卡片：类型图标 + 名称 + 大小/时间 + 备注与标签。
class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.onTap,
    required this.onEdit,
    required this.onExport,
    required this.onDelete,
  });

  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  IconData get _icon {
    if (file.isImage) return Icons.image_outlined;
    if (file.isVideo) return Icons.videocam_outlined;
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return WuCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(WuSpace.md, WuSpace.sm, WuSpace.xxs, WuSpace.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: BorderRadius.circular(WuSpace.radiusS),
            ),
            child: Icon(_icon, size: 18, color: colors.inkSecondary),
          ),
          const SizedBox(width: WuSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalName,
                  style: context.texts.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${WuUtils.formatSize(file.size)} · ${WuUtils.formatDate(file.createdAt)}',
                  style: context.texts.labelSmall,
                ),
                if (file.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    file.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ],
                if (file.tags.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [for (final tag in file.tags) WuTag(label: tag)],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            icon: Icon(Icons.more_horiz, size: 18, color: colors.inkTertiary),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'export':
                  onExport();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('重命名 / 备注')),
              PopupMenuItem(value: 'export', child: Text('导出到本机')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}
