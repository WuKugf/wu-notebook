import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../theme/wu_theme.dart';
import '../../core/utils.dart';

/// 首次启动：设置解锁密码。
/// 这个密码会派生加密密钥，用来加密密码本条目与备份文件。
class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key, required this.state});

  final AppState state;

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text.trim();
    if (!WuUtils.isValidMasterPassword(password)) {
      setState(() => _error = '密码至少 6 位，最多 128 位');
      return;
    }
    if (password != _confirm.text.trim()) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.setupPassword(password);
    } catch (error) {
      if (mounted) setState(() => _error = '初始化失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(WuSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WU本子', style: context.texts.displaySmall),
                  const SizedBox(height: WuSpace.xs),
                  Text('一本放在自己设备里的本子', style: context.texts.bodyMedium),
                  const SizedBox(height: WuSpace.xl),
                  Container(
                    padding: const EdgeInsets.all(WuSpace.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(WuSpace.radiusM),
                      border: Border.all(color: colors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('设置解锁密码', style: context.texts.titleLarge),
                        const SizedBox(height: WuSpace.xxs),
                        Text(
                          '用于加密密码本条目与备份文件。忘记后无法恢复，请记牢。',
                          style: context.texts.bodySmall,
                        ),
                        const SizedBox(height: WuSpace.md),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofocus: true,
                          decoration: const InputDecoration(hintText: '解锁密码（至少 6 位）'),
                        ),
                        const SizedBox(height: WuSpace.sm),
                        TextField(
                          controller: _confirm,
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(hintText: '再输入一次确认'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: WuSpace.xs),
                          Text(
                            _error!,
                            style: context.texts.bodySmall?.copyWith(color: colors.danger),
                          ),
                        ],
                        const SizedBox(height: WuSpace.md),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('开始使用'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: WuSpace.md),
                  Text(
                    '所有内容只保存在本机，不登录、不联网、不上传。',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 解锁页：输入解锁密码进入本子。
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key, required this.state});

  final AppState state;

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_password.text.trim().isEmpty) {
      setState(() => _error = '请输入解锁密码');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.state.unlock(_password.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = '密码不正确';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(WuSpace.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WU本子', style: context.texts.displaySmall),
                  const SizedBox(height: WuSpace.xs),
                  Text(WuUtils.formatDate(DateTime.now()), style: context.texts.bodySmall),
                  const SizedBox(height: WuSpace.xl),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofocus: true,
                    onSubmitted: (_) => _unlock(),
                    decoration: InputDecoration(
                      hintText: '解锁密码',
                      errorText: _error,
                      prefixIcon: Icon(Icons.lock_outline, size: 18, color: colors.inkTertiary),
                      errorStyle: TextStyle(color: colors.danger, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: WuSpace.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _unlock,
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('解锁'),
                    ),
                  ),
                  const SizedBox(height: WuSpace.lg),
                  Text(
                    '本子内容已加密保存在本机，只有输入正确密码才能打开。',
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
