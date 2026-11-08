import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../theme/wu_theme.dart';
import '../backup/backup_flow.dart';
import '../widgets/wu_widgets.dart';
import 'about_screen.dart';
import 'trash_screen.dart';

/// 设置页：外观、安全、数据管理与关于。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get _state => widget.state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final settings = _state.settings;
    return WuPageScaffold(
      title: '设置',
      subtitle: '本子只属于你 · 全部数据保存在本机',
      body: ListView(
        padding: const EdgeInsets.only(bottom: WuSpace.xl),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------- 外观
                const WuSectionLabel('外观'),
                WuCard(
                  padding: const EdgeInsets.fromLTRB(WuSpace.md, WuSpace.sm, WuSpace.md, WuSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('主题', style: context.texts.titleMedium),
                      const SizedBox(height: WuSpace.xxs),
                      Text('浅色是米白的纸面，深色是安静的墨色。', style: context.texts.bodySmall),
                      const SizedBox(height: WuSpace.xs),
                      Wrap(
                        spacing: WuSpace.xs,
                        children: [
                          for (final option in const [
                            (0, '跟随系统'),
                            (1, '浅色'),
                            (2, '深色'),
                          ])
                            WuTag(
                              label: option.$2,
                              selected: settings.themeModeIndex == option.$1,
                              onTap: () => _state.setThemeModeIndex(option.$1),
                            ),
                        ],
                      ),
                      Divider(color: colors.line, height: WuSpace.lg),
                      Row(
                        children: [
                          Text('字体大小', style: context.texts.titleMedium),
                          const Spacer(),
                          Text(
                            '${(settings.fontScale * 100).round()}%',
                            style: context.texts.labelSmall,
                          ),
                        ],
                      ),
                      Slider(
                        value: settings.fontScale.clamp(0.85, 1.35),
                        min: 0.85,
                        max: 1.35,
                        divisions: 10,
                        onChanged: (value) => _state.setFontScale(value),
                      ),
                      Text(
                        '调整后整个界面的字号会一起变化，这里可以预览效果。',
                        style: context.texts.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WuSpace.md),

                // -------------------------------------------------- 安全
                const WuSectionLabel('安全'),
                WuCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingTile(
                        icon: Icons.key_outlined,
                        title: '修改解锁密码',
                        subtitle: '新密码会重新加密本子里的所有条目',
                        onTap: () => _changePassword(context),
                      ),
                      Divider(height: 1, color: colors.line, indent: WuSpace.md),
                      _SettingTile(
                        icon: Icons.timer_outlined,
                        title: '自动锁屏',
                        subtitle: '一段时间没有操作就自动回到解锁页',
                        value: settings.autoLockMinutes == 0
                            ? '关闭'
                            : '${settings.autoLockMinutes} 分钟',
                        onTap: () => _pickAutoLock(context),
                      ),
                      Divider(height: 1, color: colors.line, indent: WuSpace.md),
                      _SettingTile(
                        icon: Icons.lock_outline,
                        title: '立即锁屏',
                        subtitle: '马上清空内存里的明文并回到解锁页',
                        onTap: () => _state.lockNow(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WuSpace.md),

                // -------------------------------------------------- 数据
                const WuSectionLabel('数据'),
                WuCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingTile(
                        icon: Icons.unarchive_outlined,
                        title: '导入备份',
                        subtitle: '选择 .wuback 文件，可合并或覆盖导入',
                        onTap: () => startImportFlow(context),
                      ),
                      Divider(height: 1, color: colors.line, indent: WuSpace.md),
                      _SettingTile(
                        icon: Icons.restore_from_trash_outlined,
                        title: '回收站',
                        subtitle: '删除的条目与文件都在这里，可以恢复',
                        value: '${_state.trashRecords.length} 项',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TrashScreen(state: _state),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: colors.line, indent: WuSpace.md),
                      _SettingTile(
                        icon: Icons.delete_outline,
                        title: '清除本地数据',
                        subtitle: '删除全部条目与本地文件，保留解锁密码',
                        danger: true,
                        onTap: () => _clearData(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WuSpace.md),

                // -------------------------------------------------- 关于
                const WuSectionLabel('关于'),
                WuCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingTile(
                        icon: Icons.info_outline,
                        title: '关于 WU本子',
                        subtitle: '版本 1.0.0 · 纯本地离线工具',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WuSpace.md),

                // -------------------------------------------------- 离线说明
                Container(
                  padding: const EdgeInsets.all(WuSpace.md),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(WuSpace.radiusM),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.wifi_off_outlined, size: 16, color: colors.inkSecondary),
                          const SizedBox(width: 6),
                          Text('完全离线', style: context.texts.titleMedium),
                        ],
                      ),
                      const SizedBox(height: WuSpace.xs),
                      Text(
                        '只有手动导出、手动传输、手动导入，不是自动云同步，不会联网上传任何数据。'
                        '不需要登录，也没有任何云端服务。',
                        style: context.texts.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: WuSpace.md),
                Text(
                  _state.isPreviewMode
                      ? '当前是网页预览模式，附件与备份功能需要在手机或电脑端的安装包中使用。'
                      : '数据目录：${_state.supportsFiles ? '本机应用私有目录' : '不可用'}',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 修改解锁密码：先校验旧密码，再重新派生密钥并加密全部数据。
  Future<void> _changePassword(BuildContext context) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;
    bool busy = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('修改解锁密码'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '修改后会用新密码重新加密本子里的所有条目。已经导出的旧备份仍然只认旧的密码。',
                      style: context.texts.bodySmall,
                    ),
                    const SizedBox(height: WuSpace.md),
                    TextField(
                      controller: oldController,
                      obscureText: true,
                      enabled: !busy,
                      decoration: const InputDecoration(hintText: '当前密码'),
                    ),
                    const SizedBox(height: WuSpace.xs),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      enabled: !busy,
                      decoration: const InputDecoration(hintText: '新密码（至少 6 位）'),
                    ),
                    const SizedBox(height: WuSpace.xs),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      enabled: !busy,
                      decoration: InputDecoration(
                        hintText: '再输入一次新密码',
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
                  onPressed: busy ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final oldPassword = oldController.text;
                          final newPassword = newController.text.trim();
                          final confirm = confirmController.text.trim();
                          if (!WuUtils.isValidMasterPassword(newPassword)) {
                            setState(() => errorText = '新密码需要 6 到 128 位');
                            return;
                          }
                          if (newPassword != confirm) {
                            setState(() => errorText = '两次输入的新密码不一致');
                            return;
                          }
                          setState(() {
                            busy = true;
                            errorText = null;
                          });
                          final ok = await _state.checkPassword(oldPassword);
                          if (!ok) {
                            setState(() {
                              busy = false;
                              errorText = '当前密码不正确';
                            });
                            return;
                          }
                          try {
                            await _state.changePassword(newPassword);
                            await _state.flush();
                            if (context.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            setState(() {
                              busy = false;
                              errorText = '修改失败：$error';
                            });
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    oldController.dispose();
    newController.dispose();
    confirmController.dispose();

    if (changed == true && context.mounted) {
      wuSnack(context, '解锁密码已修改');
    }
  }

  /// 选择自动锁屏时间。
  Future<void> _pickAutoLock(BuildContext context) async {
    const options = <int>[0, 1, 5, 15, 30];
    final current = _state.settings.autoLockMinutes;
    await showWuSheet<void>(
      context,
      builder: (sheetContext) {
        final colors = sheetContext.colors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(WuSpace.md, WuSpace.md, WuSpace.md, WuSpace.xs),
                child: Text('自动锁屏', style: sheetContext.texts.titleLarge),
              ),
              for (final minutes in options)
                ListTile(
                  title: Text(
                    minutes == 0 ? '关闭' : '$minutes 分钟',
                    style: sheetContext.texts.bodyLarge,
                  ),
                  trailing: current == minutes
                      ? Icon(Icons.check, size: 18, color: colors.accent)
                      : null,
                  onTap: () {
                    _state.setAutoLockMinutes(minutes);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: WuSpace.sm),
            ],
          ),
        );
      },
    );
  }

  /// 清除本地数据：输入当前密码确认后，删除全部条目与附件。
  Future<void> _clearData(BuildContext context) async {
    final ok = await showWuConfirm(
      context,
      title: '清除本地数据',
      message: '会删除密码本、备忘录、待办、倒数日、文件库的全部内容与本地文件，'
          '并且无法恢复。解锁密码会保留。',
      confirmText: '继续',
      danger: true,
    );
    if (!ok || !context.mounted) return;

    final controller = TextEditingController();
    String? errorText;
    bool busy = false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('再确认一次'),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('请输入当前解锁密码，确认清除全部本地数据。',
                        style: context.texts.bodyMedium),
                    const SizedBox(height: WuSpace.md),
                    TextField(
                      controller: controller,
                      obscureText: true,
                      enabled: !busy,
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
                  onPressed: busy ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: colors.danger),
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            errorText = null;
                          });
                          final ok = await _state.checkPassword(controller.text);
                          if (!ok) {
                            setState(() {
                              busy = false;
                              errorText = '密码不正确';
                            });
                            return;
                          }
                          try {
                            await _state.clearLocalData();
                            if (context.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (error) {
                            setState(() {
                              busy = false;
                              errorText = '清除失败：$error';
                            });
                          }
                        },
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('确认清除'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (confirmed == true && context.mounted) {
      wuSnack(context, '本地数据已清除');
    }
  }
}

/// 设置项：图标 + 标题 + 说明 + 右侧值。
class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.danger = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WuSpace.md, vertical: WuSpace.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: danger ? colors.danger : colors.inkSecondary),
            const SizedBox(width: WuSpace.sm),
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
                  const SizedBox(height: 1),
                  Text(subtitle, style: context.texts.bodySmall),
                ],
              ),
            ),
            if (value != null) ...[
              Text(value!, style: context.texts.labelMedium),
              const SizedBox(width: WuSpace.xxs),
            ],
            Icon(Icons.chevron_right, size: 16, color: colors.inkTertiary),
          ],
        ),
      ),
    );
  }
}
