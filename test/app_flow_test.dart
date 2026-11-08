import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wu_notebook/app.dart';
import 'package:wu_notebook/data/app_state.dart';

/// 界面自查：验证锁屏门禁、主界面外壳与模块切换。
///
/// 注意：Hive 与文件读写是真实异步操作，在 flutter_test 的假时钟里不会完成，
/// 所以初始化、设置密码、解锁这些动作都放在 tester.runAsync 里执行；
/// 纯数据层的加密与持久化验证放在 storage_test.dart。
void main() {
  Future<void> settle(WidgetTester tester, [int times = 10]) async {
    for (int i = 0; i < times; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('锁屏门禁、主界面导航与设置页', (tester) async {
    // 手机竖屏尺寸，验证底部 Tab 布局
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final state = AppState();
    AppState.instance = state;

    // 注意：testWidgets 内部是假时钟，真实文件 IO 必须放进 runAsync。
    late Directory tempDir;
    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('wu_ui_test');
      debugPrint('step: bootstrap start');
      await state.bootstrap(storagePath: tempDir.path);
      debugPrint('step: bootstrap done');
      state.setAutoLockMinutes(0);
      // 首次启动先设置解锁密码，验证「设置 → 主界面」的门禁
      await state.setupPassword('test123456');
      debugPrint('step: setup done');
    });
    debugPrint('step: runAsync done');

    addTearDown(() async {
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // box 仍打开时 Windows 上可能删不掉，忽略
        }
      }
    });

    await tester.pumpWidget(WuNotebookApp(state: state));
    await settle(tester);

    // 已设置密码且已解锁：应直接进入主界面
    expect(state.needsSetup, isFalse);
    expect(find.text('密码本'), findsWidgets);
    expect(find.text('保存数据'), findsOneWidget);

    // 依次切换五个模块与设置页
    for (final label in ['备忘录', '待办', '倒数日', '文件库', '设置']) {
      await tester.tap(find.text(label).last);
      await settle(tester, 5);
    }
    expect(find.text('完全离线'), findsOneWidget);

    // 锁屏后应回到解锁页
    await tester.runAsync(() async {
      await state.lockNow();
    });
    await settle(tester, 8);
    expect(find.text('解锁'), findsWidgets);
    expect(find.text('保存数据'), findsNothing);

    // 错误密码不能解锁
    bool wrongOk = true;
    await tester.runAsync(() async {
      wrongOk = await state.unlock('wrong-password');
    });
    expect(wrongOk, isFalse);

    // 正确密码解锁后又回到主界面
    bool rightOk = false;
    await tester.runAsync(() async {
      rightOk = await state.unlock('test123456');
    });
    expect(rightOk, isTrue);
    await settle(tester, 8);
    expect(find.text('保存数据'), findsOneWidget);
  });
}
