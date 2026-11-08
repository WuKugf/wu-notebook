/// 网页预览环境下的附件仓库占位实现。
/// 网页只是用来先看界面，不支持本地附件读写，所有方法都会返回空值。
library;

import 'dart:typed_data';

class AttachmentStore {
  AttachmentStore._();

  static final AttachmentStore instance = AttachmentStore._();

  bool get supported => false;

  Future<void> init() async {}

  String? get directoryPath => null;

  String? pathOf(String storedName) => null;

  Future<int> sizeOf(String storedName) async => 0;

  Future<String> saveBytes(List<int> bytes, String extension) async {
    throw StateError('网页预览不支持本地附件');
  }

  Future<String> copyIntoStore(String sourcePath, String originalName) async {
    throw StateError('网页预览不支持本地附件');
  }

  Future<Uint8List?> readBytes(String storedName) async => null;

  Future<void> delete(String storedName) async {}

  Future<bool> exists(String storedName) async => false;

  Future<void> exportTo(String storedName, String targetPath) async {}

  Future<void> wipe() async {}

  /// 复制一份附件并返回新的存储文件名（网页预览不可用）。
  Future<String> duplicate(String storedName) async {
    throw StateError('网页预览不支持本地附件');
  }
}
