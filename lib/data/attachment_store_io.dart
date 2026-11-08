import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils.dart';

/// 附件仓库（手机 / 电脑端实现）：
/// 文件库素材与笔记图片都保存在应用私有目录下的 attachments 文件夹，
/// 全部是本地文件，不会上传到任何地方。
class AttachmentStore {
  AttachmentStore._();

  static final AttachmentStore instance = AttachmentStore._();

  Directory? _dir;

  bool get supported => true;

  Directory? get directory => _dir;

  String? get directoryPath => _dir?.path;

  Future<void> init() async {
    final docs = await getApplicationSupportDirectory();
    final dir = Directory(p.join(docs.path, 'attachments'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
  }

  /// 通过存储文件名拿到绝对路径。
  String? pathOf(String storedName) {
    final dir = _dir;
    if (dir == null) return null;
    return p.join(dir.path, storedName);
  }

  /// 把字节写入附件目录，返回存储文件名（UUID + 扩展名）。
  Future<String> saveBytes(List<int> bytes, String extension) async {
    final dir = _dir;
    if (dir == null) throw StateError('当前环境不支持本地附件');
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final storedName = ext == '.' ? WuUtils.newId() : '${WuUtils.newId()}$ext';
    final file = File(p.join(dir.path, storedName));
    await file.writeAsBytes(bytes, flush: true);
    return storedName;
  }

  /// 从任意本地路径复制一份到附件目录。
  Future<String> copyIntoStore(String sourcePath, String originalName) async {
    final dir = _dir;
    if (dir == null) throw StateError('当前环境不支持本地附件');
    final ext = WuUtils.extensionOf(originalName);
    final storedName = ext.isEmpty ? WuUtils.newId() : '${WuUtils.newId()}.$ext';
    final target = File(p.join(dir.path, storedName));
    await File(sourcePath).copy(target.path);
    return storedName;
  }

  /// 复制一份已存在的附件，返回新的存储文件名。
  Future<String> duplicate(String storedName) async {
    final path = pathOf(storedName);
    if (path == null) throw StateError('当前环境不支持本地附件');
    final source = File(path);
    if (!await source.exists()) throw StateError('附件不存在');
    final ext = WuUtils.extensionOf(storedName);
    final newName = ext.isEmpty ? WuUtils.newId() : '${WuUtils.newId()}.$ext';
    await source.copy(p.join(_dir!.path, newName));
    return newName;
  }

  /// 读取附件内容（图片预览用，体积一般不大）。
  Future<Uint8List?> readBytes(String storedName) async {
    final path = pathOf(storedName);
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> delete(String storedName) async {
    final path = pathOf(storedName);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> exists(String storedName) async {
    final path = pathOf(storedName);
    if (path == null) return false;
    return File(path).exists();
  }

  /// 附件大小（字节），不存在时返回 0。
  Future<int> sizeOf(String storedName) async {
    final path = pathOf(storedName);
    if (path == null) return 0;
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  /// 导出单个附件到用户选择的目标路径。
  Future<void> exportTo(String storedName, String targetPath) async {
    final source = pathOf(storedName);
    if (source == null) throw StateError('当前环境不支持本地附件');
    final file = File(source);
    if (!await file.exists()) throw StateError('附件不存在');
    await file.copy(targetPath);
  }

  /// 清空附件目录（覆盖式导入、清除数据时使用）。
  Future<void> wipe() async {
    final dir = _dir;
    if (dir == null) return;
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
  }
}
