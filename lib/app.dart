import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_state.dart';
import 'theme/wu_theme.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/shell/app_shell.dart';

/// 应用根组件：负责主题、字体缩放，以及“首次设置 / 解锁 / 主界面”的切换。
class WuNotebookApp extends StatelessWidget {
  const WuNotebookApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final themeMode = switch (state.settings.themeModeIndex) {
          1 => ThemeMode.light,
          2 => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          title: 'WU本子',
          debugShowCheckedModeBanner: false,
          theme: WuTheme.build(Brightness.light),
          darkTheme: WuTheme.build(Brightness.dark),
          themeMode: themeMode,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const <Locale>[Locale('zh', 'CN')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            final scale = state.settings.fontScale;
            if (scale == 1.0 || child == null) return child ?? const SizedBox.shrink();
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(scale)),
              child: child,
            );
          },
          home: _RootGate(state: state),
        );
      },
    );
  }
}

/// 根据状态显示对应页面，切换时只用淡入淡出，保持克制。
class _RootGate extends StatelessWidget {
  const _RootGate({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    Widget content;
    String stage;
    if (!state.ready) {
      stage = 'loading';
      content = const _LoadingView();
    } else if (state.needsSetup) {
      stage = 'setup';
      content = FirstRunScreen(state: state);
    } else if (state.locked) {
      stage = 'lock';
      content = UnlockScreen(state: state);
    } else {
      stage = 'shell';
      content = AppShell(state: state);
    }

    return Listener(
      onPointerDown: (_) => state.touch(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(stage), child: content),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('WU本子', style: context.texts.headlineMedium),
            const SizedBox(height: WuSpace.md),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: colors.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
