/// 备份服务在网页预览下的占位实现：网页只用于查看界面，不提供备份导入导出。
library;

import 'backup_types.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const String fileExtension = '.wuback';

  Future<void> export({
    required String password,
    required String note,
    required Map<String, dynamic> data,
    required List<BackupAsset> assets,
    required String targetPath,
    void Function(double progress)? onProgress,
  }) async {
    throw BackupException(BackupErrorType.notBackup, '网页预览不支持备份导出');
  }

  Future<BackupHeader> inspect(String path) async {
    throw BackupException(BackupErrorType.notBackup, '网页预览不支持备份导入');
  }

  Future<BackupContent> readContent(
    String path,
    BackupHeader header,
    String password,
  ) async {
    throw BackupException(BackupErrorType.notBackup, '网页预览不支持备份导入');
  }

  Future<int> restoreAssets({
    required String path,
    required BackupContent content,
    required String targetDirectory,
    void Function(double progress)? onProgress,
    void Function(String storedName, String targetPath)? onAssetWritten,
  }) async {
    throw BackupException(BackupErrorType.notBackup, '网页预览不支持备份导入');
  }

  String suggestedFileName() => 'WU本子备份_预览$fileExtension';
}
