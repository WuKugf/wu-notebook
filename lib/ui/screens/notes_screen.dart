import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../data/attachment_store.dart';
import '../../data/models/note.dart';
import '../../theme/wu_theme.dart';
import '../widgets/wu_widgets.dart';

/// 备忘录列表：支持全局搜索、标签、置顶与单条加密。
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Note> get _notes => widget.state.notes.where((e) => !e.inTrash).toList();

  List<Note> get _visible {
    final query = _query.trim().toLowerCase();
    final list = _notes.where((note) {
      if (query.isEmpty) return true;
      return note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  Future<void> _openEditor([Note? note]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => NoteEditorPage(state: widget.state, note: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _visible;
    return WuPageScaffold(
      title: '备忘录',
      subtitle: '共 ${_notes.length} 条 · 支持单条加密与本地图片',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(WuSpace.radiusM)),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
            child: WuSearchField(
              controller: _search,
              hintText: '搜索标题、正文、标签',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(height: WuSpace.sm),
          Expanded(
            child: items.isEmpty
                ? WuEmptyState(
                    icon: Icons.description_outlined,
                    title: _notes.isEmpty ? '还没有笔记' : '没有匹配的笔记',
                    hint: _notes.isEmpty ? '记录一些想留住的东西' : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: WuSpace.sm),
                    itemBuilder: (context, index) {
                      final note = items[index];
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
                        child: WuCard(
                          onTap: () => _openEditor(note),
                          padding: const EdgeInsets.fromLTRB(
                            WuSpace.md,
                            WuSpace.sm,
                            WuSpace.xs,
                            WuSpace.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (note.pinned) ...[
                                    Icon(Icons.push_pin_outlined,
                                        size: 14, color: colors.inkTertiary),
                                    const SizedBox(width: 5),
                                  ],
                                  if (note.encrypted) ...[
                                    Icon(Icons.lock_outline,
                                        size: 13, color: colors.inkTertiary),
                                    const SizedBox(width: 5),
                                  ],
                                  Expanded(
                                    child: Text(
                                      note.displayTitle,
                                      style: context.texts.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    WuUtils.formatDateTime(note.updatedAt),
                                    style: context.texts.labelSmall,
                                  ),
                                  const SizedBox(width: WuSpace.xs),
                                ],
                              ),
                              if (note.content.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  note.content.replaceAll('\n', ' '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.bodySmall,
                                ),
                              ],
                              const SizedBox(height: WuSpace.xs),
                              Row(
                                children: [
                                  for (final tag in note.tags.take(4)) ...[
                                    WuTag(label: tag),
                                    const SizedBox(width: 4),
                                  ],
                                  if (note.images.isNotEmpty) ...[
                                    Icon(Icons.image_outlined,
                                        size: 13, color: colors.inkTertiary),
                                    const SizedBox(width: 3),
                                    Text('${note.images.length}', style: context.texts.labelSmall),
                                  ],
                                  const SizedBox(width: WuSpace.xs),
                                ],
                              ),
                            ],
                          ),
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

/// 笔记编辑页：手机与电脑共用，宽屏时限制内容宽度。
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, required this.state, this.note});

  final AppState state;
  final Note? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _tags;
  late List<String> _images;
  late bool _encrypted;
  late bool _pinned;
  bool _saving = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _title = TextEditingController(text: note?.title ?? '');
    _content = TextEditingController(text: note?.content ?? '');
    _tags = TextEditingController(text: note?.tags.join('，') ?? '');
    _images = List<String>.from(note?.images ?? const <String>[]);
    _encrypted = note?.encrypted ?? false;
    _pinned = note?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tags.text
      .split(RegExp('[,，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  void _save() {
    if (_saving) return;
    if (_title.text.trim().isEmpty && _content.text.trim().isEmpty && _images.isEmpty) {
      wuSnack(context, '标题和正文都是空的');
      return;
    }
    final base = widget.note;
    final note = base == null
        ? Note(
            id: WuUtils.newId(),
            title: _title.text.trim(),
            content: _content.text,
            tags: _parseTags(),
            images: _images,
            pinned: _pinned,
            encrypted: _encrypted,
          )
        : base.copyWith(
            title: _title.text.trim(),
            content: _content.text,
            tags: _parseTags(),
            images: _images,
            pinned: _pinned,
            encrypted: _encrypted,
          );
    widget.state.upsertNote(note);
    Navigator.of(context).pop();
  }

  Future<void> _addImages() async {
    if (!widget.state.supportsFiles) {
      wuSnack(context, '网页预览不支持插入本地图片');
      return;
    }
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      if (picked.isEmpty) return;
      for (final file in picked) {
        if (file.path == null) continue;
        final storedName = await widget.state.attachments
            .copyIntoStore(file.path!, file.name);
        _images.add(storedName);
      }
      setState(() {});
    } catch (error) {
      if (mounted) wuSnack(context, '插入图片失败：$error');
    }
  }

  Future<void> _delete() async {
    final note = widget.note;
    if (note == null) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showWuConfirm(
      context,
      title: '删除笔记',
      message: '笔记会移入回收站，可以之后恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    widget.state.moveToTrash(EntityType.note, note.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isWide = MediaQuery.sizeOf(context).width >= WuSpace.wideBreakpoint;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_isNew ? '新建笔记' : '编辑笔记', style: context.texts.titleLarge),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '删除',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline, size: 19),
              color: colors.inkTertiary,
            ),
          Padding(
            padding: const EdgeInsets.only(right: WuSpace.sm),
            child: TextButton(
              onPressed: _save,
              child: Text('保存', style: TextStyle(color: colors.accent)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 720 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(WuSpace.md, WuSpace.xs, WuSpace.md, WuSpace.xl),
              children: [
                TextField(
                  controller: _title,
                  style: context.texts.headlineMedium,
                  decoration: const InputDecoration(
                    hintText: '标题',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Divider(color: colors.line, height: 1),
                const SizedBox(height: WuSpace.sm),
                TextField(
                  controller: _content,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: context.texts.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: '写点什么…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: WuSpace.md),
                if (_images.isNotEmpty)
                  Wrap(
                    spacing: WuSpace.xs,
                    runSpacing: WuSpace.xs,
                    children: [
                      for (final image in _images)
                        _NoteImageTile(
                          storedName: image,
                          store: widget.state.attachments,
                          onRemove: () => setState(() => _images.remove(image)),
                        ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: _addImages,
                  icon: const Icon(Icons.image_outlined, size: 16),
                  label: const Text('插入本地图片'),
                ),
                const SizedBox(height: WuSpace.lg),
                TextField(
                  controller: _tags,
                  decoration: const InputDecoration(hintText: '标签，用逗号分隔'),
                ),
                const SizedBox(height: WuSpace.md),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 15, color: colors.inkSecondary),
                    const SizedBox(width: 6),
                    Text('加密这条笔记', style: context.texts.bodyMedium),
                    const Spacer(),
                    Switch(
                      value: _encrypted,
                      onChanged: (value) => setState(() => _encrypted = value),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.push_pin_outlined, size: 15, color: colors.inkSecondary),
                    const SizedBox(width: 6),
                    Text('置顶', style: context.texts.bodyMedium),
                    const Spacer(),
                    Switch(
                      value: _pinned,
                      onChanged: (value) => setState(() => _pinned = value),
                    ),
                  ],
                ),
                if (!_isNew) ...[
                  const SizedBox(height: WuSpace.sm),
                  Text(
                    '创建于 ${WuUtils.formatDateTime(widget.note!.createdAt)}  ·  '
                    '修改于 ${WuUtils.formatDateTime(widget.note!.updatedAt)}',
                    style: context.texts.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 笔记里的图片缩略图，点击可放大查看。
class _NoteImageTile extends StatelessWidget {
  const _NoteImageTile({
    required this.storedName,
    required this.store,
    required this.onRemove,
  });

  final String storedName;
  final AttachmentStore store;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(WuSpace.radiusS),
            child: FutureBuilder<Uint8List?>(
              future: store.readBytes(storedName),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) {
                  return Container(
                    color: colors.surfaceAlt,
                    alignment: Alignment.center,
                    child: Icon(Icons.image_outlined, size: 20, color: colors.inkTertiary),
                  );
                }
                return GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => Dialog(
                      backgroundColor: colors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(WuSpace.xs),
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  child: Image.memory(bytes, fit: BoxFit.cover, width: 96, height: 96),
                );
              },
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.close, size: 12, color: colors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
