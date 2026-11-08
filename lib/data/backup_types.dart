import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 备份相关的公共类型定义。
/// 单独放在这里，保证网页预览构建时也能引用这些类型（不依赖 dart:io）。

/// 备份失败的类型，界面据此显示三种不同的提示文案。
enum BackupErrorType {
  /// 解锁密码错误
  wrongPassword,

  /// 文件损坏（校验值不对、结构不完整）
  corrupted,

  /// 不是 WU本子 的备份文件（magic 不匹配或版本不支持）
  notBackup,
}

class BackupException implements Exception {
  BackupException(this.type, [this.detail = '']);

  final BackupErrorType type;
  final String detail;

  @override
  String toString() => 'BackupException($type): $detail';
}

/// 备份中的一个附件（文件库素材或笔记图片）。
class BackupAsset {
  BackupAsset({required this.storedName, required this.path, required this.size});

  final String storedName;
  final String path;
  final int size;
}

/// 备份文件头部信息（明文部分，不含任何用户数据）。
class BackupHeader {
  BackupHeader({
    required this.version,
    required this.salt,
    required this.noncePrefix,
    required this.payloadLength,
    required this.checksum,
  });

  final int version;
  final Uint8List salt;
  final Uint8List noncePrefix;
  final int payloadLength;
  final List<int> checksum;
}

/// 索引里的附件元数据。
class BackupAssetMeta {
  BackupAssetMeta({required this.storedName, required this.size});

  final String storedName;
  final int size;
}

/// 读取备份后得到的索引信息。
class BackupContent {
  BackupContent({
    required this.note,
    required this.exportedAt,
    required this.data,
    required this.assets,
    required this.header,
    required this.passwordKey,
    required this.storagePath,
  });

  final String note;
  final DateTime exportedAt;
  final Map<String, dynamic> data;
  final List<BackupAssetMeta> assets;
  final BackupHeader header;
  final SecretKey passwordKey;

  /// 备份文件自身的路径，还原附件时需要再次读取。
  final String storagePath;
}
