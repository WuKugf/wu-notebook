/// 通过条件导出，网页端使用占位实现，其余平台使用真实文件系统实现。
export 'attachment_store_web.dart' if (dart.library.io) 'attachment_store_io.dart';
