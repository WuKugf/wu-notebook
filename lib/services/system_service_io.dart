import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 与系统打交道的操作（导出目录、打开文件夹、用系统程序打开文件、申请存储权限）。
/// 集中在单独的服务里，界面层不需要直接依赖 dart:io。
class SystemService {
  SystemService._();

  static final SystemService instance = SystemService._();

  /// 备份与导出文件默认保存的位置。
  /// 安卓写在应用专属的外部目录（文件管理器可以找到），
  /// 电脑端优先使用“下载”文件夹。
  Future<String?> exportDirectory() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && await downloads.exists()) {
        return downloads.path;
      }
      final docs = await getApplicationDocumentsDirectory();
      return docs.path;
    }
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir = Directory(p.join(external.path, 'WU本子'));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir.path;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  /// 把文件复制到导出目录，返回目标路径。
  Future<String?> exportFile(String sourcePath, String fileName) async {
    final dir = await exportDirectory();
    if (dir == null) return null;
    final target = p.join(dir, fileName);
    final file = File(sourcePath);
    if (!await file.exists()) return null;
    await file.copy(target);
    return target;
  }

  /// 打开文件夹（电脑端）。安卓端返回 false。
  Future<bool> openFolder(String path) async {
    if (Platform.isWindows) {
      try {
        await Process.run('explorer', [path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isMacOS) {
      try {
        await Process.run('open', [path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 用系统默认程序打开文件（电脑端）。安卓端返回 false。
  Future<bool> openWithSystem(String path) async {
    if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isMacOS) {
      try {
        await Process.run('open', [path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [path]);
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 安卓端申请文件读写权限（备份文件与文件库素材）。
  /// 高版本安卓对公共目录使用分区存储，应用专属目录不需要权限，
  /// 这里只申请传统的存储权限（Android 12 及以下有效），
  /// 不额外弹照片/视频权限，避免多次授权打扰；被拒绝也不影响应用自身目录的读写。
  Future<void> ensureStoragePermission() async {
    if (!Platform.isAndroid) return;
    try {
      final status = await Permission.storage.status;
      if (status.isGranted) return;
      await Permission.storage.request();
    } catch (_) {
      // 权限申请失败不影响使用，保持静默
    }
  }

  /// 当前平台是否是电脑桌面端。
  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool get isAndroid => Platform.isAndroid;
}
