import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../data/backup_service.dart';
import '../../data/backup_types.dart';
import '../../services/system_service.dart';
import '../../theme/wu_theme.dart';

/// 页面右上角的【保存数据】按钮。
class SaveDataButton extends StatelessWidget {
  const SaveDataButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.save_outlined, size: 16, color: colors.inkSecondary),
      label: Text('保存数据', style: TextStyle(fontSize: 13, color: colors.ink)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// 打开“保存数据”面板：导出备份为主，同时提供导入入口。
Future<void> showSaveDataFlow(BuildContext context) async {
  final state = AppState.instance;
  if (!state.supportsFiles) {
    await _showSimpleMessage(
      context,
      title: '网页预览模式',
      message: '网页预览只能查看界面，导出与导入备份请在手机或电脑端的安装包中使用。',
    );
    return;
  }
  final noteController = TextEditingController(
    text: '${WuUtils.formatDate(DateTime.now())} 手机备份',
  );
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        title: const Text('保存数据'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把密码本、备忘录、待办、倒数日、文件库以及其中的图片、视频、文档，'
                '打包成一个 .wuback 加密备份文件，保存到本机。',
                style: dialogContext.texts.bodyMedium,
              ),
              const SizedBox(height: WuSpace.md),
              Text('备份备注（可不填）', style: dialogContext.texts.labelMedium),
              const SizedBox(height: WuSpace.xxs),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(hintText: '例如：2026.11.07 手机备份'),
              ),
              const SizedBox(height: WuSpace.md),
              Container(
                padding: const EdgeInsets.all(WuSpace.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(WuSpace.radiusS),
                ),
                child: Text(
                  '备份使用你的解锁密码加密。只有手动导出、手动传输、手动导入，'
                  '不是自动云同步，不会联网上传任何数据。',
                  style: dialogContext.texts.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('import'),
            child: const Text('导入备份'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('export'),
            child: const Text('导出'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;
  if (result == 'export') {
    await _runExport(context, noteController.text.trim());
  } else if (result == 'import') {
    await startImportFlow(context);
  }
}

/// 导出备份：写到本地目录，完成后给出提示与“打开文件夹”按钮。
Future<void> _runExport(BuildContext context, String note) async {
  final state = AppState.instance;
  final password = state.sessionPassword;
  if (password == null) {
    await _showSimpleMessage(context, title: '请先解锁', message: '需要解锁后才能导出备份。');
    return;
  }
  final directory = await SystemService.instance.exportDirectory();
  if (directory == null) {
    if (context.mounted) {
      await _showSimpleMessage(context, title: '无法保存', message: '没有找到可用的本地目录。');
    }
    return;
  }
  final fileName = BackupService.instance.suggestedFileName();
  // Dart 的文件 API 在 Windows 上同样接受 “/”，所以这里统一用正斜杠拼接。
  final targetPath = '$directory/$fileName';

  final progress = ValueNotifier<double>(0);
  final status = ValueNotifier<String>('正在准备数据…');
  if (!context.mounted) return;
  _showProgressDialog(context, progress: progress, status: status, title: '正在导出备份');

  try {
    await state.flush();
    status.value = '正在打包附件…';
    final assets = await state.collectAssets();
    status.value = '正在加密写入…';
    await state.backup.export(
      password: password,
      note: note,
      data: state.exportSnapshot(),
      assets: assets,
      targetPath: targetPath,
      onProgress: (value) => progress.value = value,
    );
  } catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await _showSimpleMessage(
        context,
        title: '导出失败',
        message: '备份文件写入失败：$error',
      );
    }
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return AlertDialog(
        title: const Text('文件已保存'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '文件已保存到手机/电脑，记得记住你的解锁密码，没有密码无法导入。',
                style: dialogContext.texts.bodyMedium,
              ),
              const SizedBox(height: WuSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(WuSpace.sm),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(WuSpace.radiusS),
                ),
                child: SelectableText(
                  targetPath,
                  style: dialogContext.texts.bodySmall?.copyWith(color: colors.inkSecondary),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
        actions: [
          if (SystemService.instance.isDesktop)
            TextButton(
              onPressed: () => SystemService.instance.openFolder(directory),
              child: const Text('打开文件夹'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('完成'),
          ),
        ],
      );
    },
  );
}

/// 导入备份的完整流程：选文件 → 完整性校验 → 输入密码 → 选择模式 → 导入。
Future<void> startImportFlow(BuildContext context) async {
  final state = AppState.instance;
  if (!state.supportsFiles) {
    await _showSimpleMessage(
      context,
      title: '网页预览模式',
      message: '网页预览只能查看界面，导入备份请在手机或电脑端的安装包中使用。',
    );
    return;
  }

  // file_picker 13.x：pickFiles 直接返回文件列表，没有选择时是空列表。
  List<PlatformFile> picked;
  try {
    picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wuback'],
    );
  } catch (error) {
    if (context.mounted) {
      await _showSimpleMessage(context, title: '无法选择文件', message: '$error');
    }
    return;
  }
  final path = picked.isNotEmpty ? picked.first.path : null;
  if (path == null) return;

  BackupHeader header;
  try {
    header = await state.backup.inspect(path);
  } on BackupException catch (error) {
    if (context.mounted) {
      await _showSimpleMessage(
        context,
        title: '无法导入',
        message: _errorMessage(error),
      );
    }
    return;
  } catch (error) {
    if (context.mounted) {
      await _showSimpleMessage(context, title: '文件损坏', message: '文件损坏，无法导入。');
    }
    return;
  }

  if (!context.mounted) return;
  final content = await _askBackupPassword(context, path, header);
  if (content == null || !context.mounted) return;

  final overwrite = await _askImportMode(context, content);
  if (overwrite == null || !context.mounted) return;

  final progress = ValueNotifier<double>(0);
  final status = ValueNotifier<String>('正在还原数据…');
  _showProgressDialog(context, progress: progress, status: status, title: '正在导入备份');

  ImportSummary summary;
  try {
    summary = await state.importBackup(
      content: content,
      overwrite: overwrite,
      onProgress: (value) => progress.value = value,
      onMessage: (message) => status.value = message,
    );
  } catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      await _showSimpleMessage(
        context,
        title: '导入失败',
        message: _errorMessage(error),
      );
    }
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  await _showSimpleMessage(
    context,
    title: '导入完成',
    message:
        '已${overwrite ? '覆盖' : '合并'}导入：密码本 ${summary.passwords} 条，'
        '备忘录 ${summary.notes} 条，待办 ${summary.todos} 条，'
        '倒数日 ${summary.countdowns} 条，文件 ${summary.files} 个。',
  );
}

/// 输入备份密码，密码错误时在弹窗内提示并允许重试。
Future<BackupContent?> _askBackupPassword(
  BuildContext context,
  String path,
  BackupHeader header,
) async {
  final controller = TextEditingController();
  String? errorText;
  bool busy = false;

  return showDialog<BackupContent>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final colors = context.colors;
          return AlertDialog(
            title: const Text('输入备份密码'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '备份文件使用导出时的解锁密码加密，请输入那个密码。',
                    style: context.texts.bodyMedium,
                  ),
                  const SizedBox(height: WuSpace.md),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    enabled: !busy,
                    onSubmitted: (_) {},
                    decoration: InputDecoration(
                      hintText: '解锁密码',
                      errorText: errorText,
                      errorStyle: TextStyle(color: colors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.of(dialogContext).pop(null),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final password = controller.text;
                        if (password.isEmpty) {
                          setState(() => errorText = '请输入密码');
                          return;
                        }
                        setState(() {
                          busy = true;
                          errorText = null;
                        });
                        try {
                          final content = await AppState.instance.backup
                              .readContent(path, header, password);
                          if (context.mounted) {
                            Navigator.of(dialogContext).pop(content);
                          }
                        } on BackupException catch (error) {
                          setState(() {
                            busy = false;
                            errorText = error.type == BackupErrorType.wrongPassword
                                ? '密码错误，请重新输入'
                                : _errorMessage(error);
                          });
                        } catch (_) {
                          setState(() {
                            busy = false;
                            errorText = '文件损坏，无法导入';
                          });
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('继续'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// 展示备份备注与内容统计，并选择导入模式（默认合并）。
Future<bool?> _askImportMode(BuildContext context, BackupContent content) async {
  final data = content.data;
  int count(String key) {
    final value = data[key];
    if (value is List) return value.length;
    return 0;
  }

  bool overwrite = false;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = dialogContext.colors;
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('确认导入'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('备份备注', style: context.texts.labelMedium),
                  const SizedBox(height: WuSpace.xxs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(WuSpace.sm),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(WuSpace.radiusS),
                    ),
                    child: Text(
                      content.note.trim().isEmpty ? '（没有填写备注）' : content.note,
                      style: context.texts.bodyMedium?.copyWith(color: colors.ink),
                    ),
                  ),
                  const SizedBox(height: WuSpace.xs),
                  Text(
                    '备份时间：${WuUtils.formatDateTime(content.exportedAt)}',
                    style: context.texts.bodySmall,
                  ),
                  const SizedBox(height: WuSpace.xs),
                  Text(
                    '包含：密码本 ${count('passwords')} 条 · 备忘录 ${count('notes')} 条 · '
                    '待办 ${count('todos')} 条 · 倒数日 ${count('countdowns')} 条 · '
                    '文件 ${count('files')} 个',
                    style: context.texts.bodySmall,
                  ),
                  const SizedBox(height: WuSpace.md),
                  _ModeOption(
                    title: '合并模式（默认）',
                    subtitle: '保留本机原有数据，把备份里的内容新增进来。',
                    selected: !overwrite,
                    onTap: () => setState(() => overwrite = false),
                  ),
                  const SizedBox(height: WuSpace.xs),
                  _ModeOption(
                    title: '覆盖模式',
                    subtitle: '清空本机旧数据与本地文件，完全替换为备份内容。',
                    selected: overwrite,
                    danger: true,
                    onTap: () => setState(() => overwrite = true),
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
                onPressed: () => Navigator.of(dialogContext).pop(overwrite),
                style: FilledButton.styleFrom(
                  backgroundColor: overwrite ? colors.danger : colors.accent,
                ),
                child: const Text('开始导入'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _showSimpleMessage(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(message, style: dialogContext.texts.bodyMedium),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

void _showProgressDialog(
  BuildContext context, {
  required ValueNotifier<double> progress,
  required ValueNotifier<String> status,
  required String title,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value <= 0 ? null : value.clamp(0.0, 1.0),
                ),
              ),
              const SizedBox(height: WuSpace.sm),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (context, value, _) => Text(
                  value,
                  style: dialogContext.texts.bodySmall,
                ),
              ),
            ],
          ),
        ),
        actions: const [],
      );
    },
  );
}

String _errorMessage(Object error) {
  if (error is BackupException) {
    switch (error.type) {
      case BackupErrorType.wrongPassword:
        return '密码错误，无法解密这份备份。';
      case BackupErrorType.corrupted:
        return '文件损坏，无法导入。';
      case BackupErrorType.notBackup:
        return '这不是WU本子备份文件。';
    }
  }
  return '文件损坏，无法导入。';
}

/// 导入模式的可选项（自己绘制，避免不同 Flutter 版本里 Radio 组件 API 的差异）。
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.accentSoft : colors.surfaceAlt,
      borderRadius: BorderRadius.circular(WuSpace.radiusS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WuSpace.radiusS),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WuSpace.sm, vertical: 10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: selected
                    ? (danger ? colors.danger : colors.accent)
                    : colors.inkTertiary,
              ),
              const SizedBox(width: WuSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.texts.titleMedium?.copyWith(
                        color: danger ? colors.danger : colors.ink,
                      ),
                    ),
                    Text(subtitle, style: context.texts.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
