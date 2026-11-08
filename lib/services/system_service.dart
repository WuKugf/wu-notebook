/// 通过条件导出，网页端使用占位实现，其余平台使用真实系统能力。
export 'system_service_web.dart' if (dart.library.io) 'system_service_io.dart';
