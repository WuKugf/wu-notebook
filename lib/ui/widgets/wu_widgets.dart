import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/wu_theme.dart';
import '../backup/backup_flow.dart';

/// 页面统一骨架：标题区 + 右上角【保存数据】+ 内容区。
/// 手机与电脑共用，靠内边距自适应，不维护两套界面。
class WuPageScaffold extends StatelessWidget {
  const WuPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    required this.body,
    this.showSaveButton = true,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final bool showSaveButton;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isWide = MediaQuery.sizeOf(context).width >= WuSpace.wideBreakpoint;
    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isWide ? WuSpace.lg : WuSpace.md,
            isWide ? WuSpace.lg : WuSpace.sm,
            isWide ? WuSpace.lg : WuSpace.md,
            WuSpace.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.texts.headlineMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: context.texts.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                  if (showSaveButton) ...[
                    if (actions.isNotEmpty) const SizedBox(width: WuSpace.xs),
                    SaveDataButton(onPressed: () => showSaveDataFlow(context)),
                  ],
                ],
              ),
              SizedBox(height: isWide ? WuSpace.md : WuSpace.sm),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// 纸感卡片：细边框、极浅圆角，没有阴影。
class WuCard extends StatelessWidget {
  const WuCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(WuSpace.md),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderRadius = BorderRadius.circular(WuSpace.radiusM);
    return Material(
      color: color ?? colors.surface,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: borderColor ?? colors.line, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 小标签。可以带一个低饱和的色点。
class WuTag extends StatelessWidget {
  const WuTag({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dotColor = color ?? colors.accent;
    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: selected ? colors.accentSoft : colors.surfaceAlt,
        borderRadius: BorderRadius.circular(WuSpace.radiusS),
        border: Border.all(color: selected ? colors.accent.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? colors.ink : colors.inkSecondary,
                ),
          ),
        ],
      ),
    );
    if (onTap == null) return container;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WuSpace.radiusS),
      child: container,
    );
  }
}

/// 搜索框，统一样式。
class WuSearchField extends StatelessWidget {
  const WuSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: colors.ink),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search, size: 18, color: colors.inkTertiary),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: Icon(Icons.close, size: 16, color: colors.inkTertiary),
              onPressed: () {
                controller.clear();
                onChanged?.call('');
              },
            );
          },
        ),
      ),
    );
  }
}

/// 空状态。
class WuEmptyState extends StatelessWidget {
  const WuEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
  });

  final IconData icon;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WuSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: colors.inkTertiary),
            const SizedBox(height: WuSpace.sm),
            Text(title, style: context.texts.titleMedium?.copyWith(color: colors.inkSecondary)),
            if (hint != null) ...[
              const SizedBox(height: WuSpace.xs),
              Text(hint!, textAlign: TextAlign.center, style: context.texts.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

/// 小标题（分区标题）。
class WuSectionLabel extends StatelessWidget {
  const WuSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WuSpace.xs, top: WuSpace.xs),
      child: Text(
        text,
        style: context.texts.labelSmall?.copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// 确认弹窗。
Future<bool> showWuConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = '确定',
  String cancelText = '取消',
  bool danger = false,
}) async {
  final colors = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: message == null
            ? null
            : Text(message, style: dialogContext.texts.bodyMedium),
        actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? colors.danger : colors.accent,
            ),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// 信息弹窗。[content] 可以是任意自定义内容。
Future<void> showWuInfo(
  BuildContext context, {
  required String title,
  required Widget content,
  String closeText = '知道了',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: content,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(closeText),
          ),
        ],
      );
    },
  );
}

/// 轻提示。
void wuSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// 统一的底部面板容器。
Future<T?> showWuSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final colors = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    barrierColor: colors.scrim,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
          ),
          child: builder(sheetContext),
        ),
      );
    },
  );
}

/// 复制到剪贴板并提示。
Future<void> wuCopy(BuildContext context, String text, String label) async {
  if (text.isEmpty) {
    wuSnack(context, '内容为空，未复制');
    return;
  }
  await ClipboardHelper.copy(text);
  if (context.mounted) {
    wuSnack(context, '$label已复制');
  }
}

/// 简化的剪贴板封装（避免界面层到处 import services）。
class ClipboardHelper {
  ClipboardHelper._();

  static Future<void> copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
