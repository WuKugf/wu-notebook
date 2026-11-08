import 'package:flutter/material.dart';

import '../../theme/wu_theme.dart';
import '../widgets/wu_widgets.dart';

/// 关于页：说明本子的定位与数据存放方式。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('关于', style: context.texts.titleLarge),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                WuSpace.md,
                WuSpace.lg,
                WuSpace.md,
                WuSpace.xl,
              ),
              children: [
                Text('WU本子', style: context.texts.headlineMedium),
                const SizedBox(height: 2),
                Text('版本 1.0.0', style: context.texts.bodySmall),
                const SizedBox(height: WuSpace.lg),
                Text(
                  '一本放在自己设备里的本子。密码本、备忘录、待办、倒数日与文件库，'
                  '记录日常需要记住的东西。',
                  style: context.texts.bodyLarge,
                ),
                const SizedBox(height: WuSpace.lg),
                const WuSectionLabel('数据与隐私'),
                _Bullet(
                  icon: Icons.wifi_off_outlined,
                  text: '完全离线使用，不需要网络，不需要登录或注册。',
                ),
                _Bullet(
                  icon: Icons.lock_outline,
                  text: '解锁密码与条目内容保存在本机；密码本、加密笔记使用 AES-GCM 加密，密钥由解锁密码派生。',
                ),
                _Bullet(
                  icon: Icons.save_outlined,
                  text: '只有手动导出、手动传输、手动导入，不是自动云同步，不会联网上传任何数据。',
                ),
                _Bullet(
                  icon: Icons.folder_outlined,
                  text: '导入的图片、视频、文档按文件名保存在应用私有目录，删除会先进入回收站。',
                ),
                const SizedBox(height: WuSpace.lg),
                const WuSectionLabel('备份说明'),
                Text(
                  '导出的 .wuback 文件使用解锁密码加密，里面包含全部文字记录与附件。'
                  '换设备或重装后，只有输入正确的解锁密码才能导入。'
                  '建议把备份文件复制到自己的 U 盘或另一台设备保存。',
                  style: context.texts.bodyMedium,
                ),
                const SizedBox(height: WuSpace.lg),
                Divider(color: colors.line, height: 1),
                const SizedBox(height: WuSpace.md),
                Text(
                  '本工具不提供任何云端功能，也不收集任何使用数据。',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: WuSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: colors.inkTertiary),
          ),
          const SizedBox(width: WuSpace.xs),
          Expanded(child: Text(text, style: context.texts.bodyMedium)),
        ],
      ),
    );
  }
}
