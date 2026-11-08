import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../theme/wu_theme.dart';
import '../screens/countdowns_screen.dart';
import '../screens/files_screen.dart';
import '../screens/notes_screen.dart';
import '../screens/passwords_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/todos_screen.dart';

class _NavItem {
  const _NavItem(this.label, this.icon);

  final String label;
  final IconData icon;
}

const List<_NavItem> _navItems = <_NavItem>[
  _NavItem('密码本', Icons.lock_outline),
  _NavItem('备忘录', Icons.description_outlined),
  _NavItem('待办', Icons.check_circle_outline),
  _NavItem('倒数日', Icons.event_outlined),
  _NavItem('文件库', Icons.folder_outlined),
  _NavItem('设置', Icons.tune),
];

/// 主界面外壳。
/// 同一套代码按宽度自适应：窄屏是底部 Tab，宽屏是左侧常驻导航。
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state});

  final AppState state;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<Widget> get _screens => <Widget>[
        PasswordsScreen(state: widget.state),
        NotesScreen(state: widget.state),
        TodosScreen(state: widget.state),
        CountdownsScreen(state: widget.state),
        FilesScreen(state: widget.state),
        SettingsScreen(state: widget.state),
      ];

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= WuSpace.wideBreakpoint;
    final pages = IndexedStack(index: _index, children: _screens);

    if (isWide) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Row(
          children: [
            _SideBar(
              index: _index,
              onSelect: _select,
              onLock: () => widget.state.lockNow(),
              state: widget.state,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: pages,
      bottomNavigationBar: _BottomBar(index: _index, onSelect: _select),
    );
  }
}

/// 左侧常驻导航（电脑端宽屏）。
class _SideBar extends StatelessWidget {
  const _SideBar({
    required this.index,
    required this.onSelect,
    required this.onLock,
    required this.state,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onLock;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: WuSpace.sidebarWidth,
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(WuSpace.lg, WuSpace.lg, WuSpace.md, WuSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WU本子', style: context.texts.headlineMedium),
                  const SizedBox(height: 2),
                  Text('本地记录 · 不联网', style: context.texts.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: WuSpace.sm),
                itemCount: _navItems.length,
                itemBuilder: (context, i) {
                  final item = _navItems[i];
                  final selected = i == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: selected ? colors.accentSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(WuSpace.radiusS),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(WuSpace.radiusS),
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: WuSpace.sm,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: selected ? colors.ink : colors.inkTertiary,
                              ),
                              const SizedBox(width: WuSpace.sm),
                              Text(
                                item.label,
                                style: context.texts.titleMedium?.copyWith(
                                  color: selected ? colors.ink : colors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Divider(height: 1, color: colors.line),
            _SideFooter(state: state, onLock: onLock),
          ],
        ),
      ),
    );
  }
}

class _SideFooter extends StatelessWidget {
  const _SideFooter({required this.state, required this.onLock});

  final AppState state;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(WuSpace.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: dark ? '切换浅色' : '切换深色',
            icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 18),
            onPressed: () => state.setThemeModeIndex(dark ? 1 : 2),
          ),
          IconButton(
            tooltip: '立即锁屏',
            icon: const Icon(Icons.lock_outline, size: 18),
            color: colors.inkTertiary,
            onPressed: onLock,
          ),
          const Spacer(),
          Text('v1.0', style: context.texts.labelSmall),
          const SizedBox(width: WuSpace.xs),
        ],
      ),
    );
  }
}

/// 底部 Tab（手机端竖屏）。
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (int i = 0; i < _navItems.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onSelect(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _navItems[i].icon,
                          size: 20,
                          color: i == index ? colors.accent : colors.inkTertiary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _navItems[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            color: i == index ? colors.ink : colors.inkTertiary,
                            fontWeight: i == index ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
