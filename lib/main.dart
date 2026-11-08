import 'package:flutter/material.dart';

import 'app.dart';
import 'data/app_state.dart';

/// 应用入口：先初始化本地数据库，再根据是否已设置解锁密码进入不同页面。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  AppState.instance = state;
  await state.bootstrap();
  runApp(WuNotebookApp(state: state));
}
