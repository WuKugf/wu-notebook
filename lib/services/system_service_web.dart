/// 网页预览下的系统服务占位实现：不提供本地文件导出与外部程序调用。
class SystemService {
  SystemService._();

  static final SystemService instance = SystemService._();

  Future<String?> exportDirectory() async => null;

  Future<String?> exportFile(String sourcePath, String fileName) async => null;

  Future<bool> openFolder(String path) async => false;

  Future<bool> openWithSystem(String path) async => false;

  Future<void> ensureStoragePermission() async {}

  bool get isDesktop => false;

  bool get isAndroid => false;
}
