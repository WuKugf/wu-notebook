import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'backup_types.dart';
import 'crypto_service.dart';

/// .wuback 备份文件服务（手机 / 电脑端实现）。
///
/// 文件结构（全部为小端序）：
/// ```
/// 偏移   长度   内容
/// 0      8     magic "WUBACK01"
/// 8      2     版本号（当前为 1）
/// 10     2     保留
/// 12     16    PBKDF2 盐
/// 28     12    分块 nonce 前缀（前 8 字节随机，后 4 字节为 0）
/// 40     8     加密负载总长度（字节）
/// 48     32    加密负载的 SHA-256 校验值
/// 80     ...   加密负载，按 1MB 分块
/// ```
/// 加密负载的明文结构：
/// ```
/// 4 字节索引长度 + 索引 JSON + 各附件原始字节（顺序与索引里的 assets 一致）
/// ```
/// 每个分块的密文前有 4 字节明文长度，密文使用 AES-256-GCM 加密并带认证标签，
/// 任何分块被篡改或损坏都会在解密时被发现。
class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const int version = 1;
  static const int headerLength = 80;
  static const int chunkSize = 1024 * 1024; // 1MB 明文一个分块，避免整包读进内存

  static const String fileExtension = '.wuback';

  static final Uint8List _magic = Uint8List.fromList(utf8.encode('WUBACK01'));

  static final AesGcm _aead = AesGcm.with256bits();

  final CryptoService _crypto = CryptoService.instance;

  // ---------------------------------------------------------------- 导出

  /// 导出备份到 [targetPath]。
  /// [data] 是明文的结构化数据（敏感字段已解密），[assets] 是附件清单。
  /// 整个过程按分块流式写入：先写占位头，再边读边加密，最后回填长度与校验值。
  Future<void> export({
    required String password,
    required String note,
    required Map<String, dynamic> data,
    required List<BackupAsset> assets,
    required String targetPath,
    void Function(double progress)? onProgress,
  }) async {
    final salt = CryptoService.randomBytes(CryptoService.saltLength);
    final noncePrefix = Uint8List(CryptoService.nonceLength);
    noncePrefix.setRange(0, 8, CryptoService.randomBytes(8));
    final key = await _crypto.deriveKey(password, salt);

    // 索引 JSON：包含全部结构化数据与附件元信息
    final index = <String, dynamic>{
      'app': 'wu-notebook',
      'schema': version,
      'note': note,
      'createdAt': DateTime.now().toIso8601String(),
      'data': data,
      'assets': [
        for (final asset in assets) {'storedName': asset.storedName, 'size': asset.size}
      ],
    };
    final indexBytes = utf8.encode(jsonEncode(index));

    final assetsTotal = assets.fold<int>(0, (sum, item) => sum + item.size);
    // 明文总长度：用于进度显示；文件头里记录的是“写完后的密文总长度”。
    final plainLength = 4 + indexBytes.length + assetsTotal;

    final target = File(targetPath);
    if (await target.exists()) {
      await target.delete();
    }
    final temp = File('$targetPath.part');
    if (await temp.exists()) {
      await temp.delete();
    }
    final raf = await temp.open(mode: FileMode.write);

    // 1) 写占位头
    await raf.writeFrom(Uint8List(headerLength));

    // 2) 按分块加密写入
    final feeder = _ChunkFeeder(
      indexBytes: indexBytes,
      assets: assets,
      chunkSize: chunkSize,
    );
    final digestSink = _DigestSink();
    final hashInput = sha256.startChunkedConversion(digestSink);

    int chunkIndex = 0;
    int written = 0;
    while (true) {
      final plain = await feeder.next();
      if (plain == null) break;
      final nonce = CryptoService.chunkNonce(noncePrefix, chunkIndex);
      final box = await _aead.encrypt(plain, secretKey: key, nonce: nonce);
      final cipher = <int>[...box.cipherText, ...box.mac.bytes];

      final lengthBytes = Uint8List(4)
        ..buffer.asByteData().setUint32(0, plain.length, Endian.little);
      final record = Uint8List.fromList(<int>[...lengthBytes, ...cipher]);
      await raf.writeFrom(record);
      hashInput.add(record); // 校验值覆盖“长度 + 密文”
      written += record.length;
      chunkIndex++;
      onProgress?.call(math.min(1.0, written / math.max(1, plainLength)));
    }
    hashInput.close();
    // Digest 的字节内容才是校验值（32 字节）
    final checksum = digestSink.value?.bytes ?? <int>[];

    // 3) 回填文件头（payloadLength 记录密文总长度，校验值覆盖这段密文）
    final header = <int>[
      ..._magic,
      ..._uint16(version),
      ..._uint16(0),
      ...salt,
      ...noncePrefix,
      ..._uint64(written),
      ...checksum,
    ];
    await raf.setPosition(0);
    await raf.writeFrom(Uint8List.fromList(header));
    await raf.close();

    // 4) 原子替换到目标位置
    if (await target.exists()) {
      await target.delete();
    }
    await temp.rename(targetPath);
    onProgress?.call(1.0);
  }

  // ---------------------------------------------------------------- 导入

  /// 第一步：校验文件头与完整性（不需要密码）。
  /// 依次判断：magic → 版本 → 文件长度 → SHA-256 校验值。
  Future<BackupHeader> inspect(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw BackupException(BackupErrorType.notBackup, '文件不存在');
    }
    final fileLength = await file.length();
    if (fileLength < headerLength) {
      throw BackupException(BackupErrorType.notBackup, '文件太小');
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      final head = await raf.read(headerLength);
      if (head.length < headerLength) {
        throw BackupException(BackupErrorType.corrupted, '文件头不完整');
      }
      for (int i = 0; i < 8; i++) {
        if (head[i] != _magic[i]) {
          throw BackupException(BackupErrorType.notBackup, '标识不匹配');
        }
      }
      final headerVersion = head.buffer.asByteData(8, 2).getUint16(0, Endian.little);
      if (headerVersion != version) {
        throw BackupException(BackupErrorType.notBackup, '版本不支持：$headerVersion');
      }
      final salt = head.sublist(12, 28);
      final noncePrefix = head.sublist(28, 40);
      final payloadLength = head.buffer.asByteData(40, 8).getUint64(0, Endian.little);
      final checksum = head.sublist(48, 80);

      if (payloadLength <= 0 || headerLength + payloadLength > fileLength) {
        throw BackupException(BackupErrorType.corrupted, '负载长度异常');
      }

      // 重新计算加密负载的校验值，必须与实际文件字节一致
      final digestSink = _DigestSink();
      final hashInput = sha256.startChunkedConversion(digestSink);
      await raf.setPosition(headerLength);
      int remaining = payloadLength;
      while (remaining > 0) {
        final bytes = await raf.read(math.min(remaining, 1024 * 1024));
        if (bytes.isEmpty) {
          throw BackupException(BackupErrorType.corrupted, '数据被截断');
        }
        hashInput.add(bytes);
        remaining -= bytes.length;
      }
      hashInput.close();
      final actual = digestSink.value?.bytes;
      if (actual == null || actual.length != checksum.length) {
        throw BackupException(BackupErrorType.corrupted, '校验值缺失');
      }
      for (int i = 0; i < checksum.length; i++) {
        if (actual[i] != checksum[i]) {
          throw BackupException(BackupErrorType.corrupted, '校验值不一致');
        }
      }

      return BackupHeader(
        version: headerVersion,
        salt: Uint8List.fromList(salt),
        noncePrefix: Uint8List.fromList(noncePrefix),
        payloadLength: payloadLength,
        checksum: checksum,
      );
    } finally {
      await raf.close();
    }
  }

  /// 第二步：用备份密码解密索引。密码错误会抛出 wrongPassword。
  Future<BackupContent> readContent(String path, BackupHeader header, String password) async {
    final key = await _crypto.deriveKey(password, header.salt);
    final raf = await File(path).open(mode: FileMode.read);
    try {
      await raf.setPosition(headerLength);
      final reader = _CipherReader(raf, key, header.noncePrefix);

      final prefixBytes = await reader.readPlain(4);
      if (prefixBytes.length < 4) {
        throw BackupException(BackupErrorType.corrupted, '索引不完整');
      }
      final indexLength =
          prefixBytes.buffer.asByteData(0, 4).getUint32(0, Endian.little);
      final indexBytes = await reader.readPlain(indexLength);
      if (indexBytes.length < indexLength) {
        throw BackupException(BackupErrorType.corrupted, '索引不完整');
      }
      final decoded = jsonDecode(utf8.decode(indexBytes));
      if (decoded is! Map || decoded['app'] != 'wu-notebook') {
        throw BackupException(BackupErrorType.notBackup, '索引标识异常');
      }
      final data = <String, dynamic>{};
      final rawData = decoded['data'];
      if (rawData is Map) {
        data.addAll(rawData.map((key, value) => MapEntry(key.toString(), value)));
      }
      final assets = <BackupAssetMeta>[];
      final rawAssets = decoded['assets'];
      if (rawAssets is List) {
        for (final item in rawAssets) {
          if (item is Map) {
            assets.add(BackupAssetMeta(
              storedName: (item['storedName'] ?? '').toString(),
              size: (item['size'] as num?)?.toInt() ?? 0,
            ));
          }
        }
      }
      return BackupContent(
        note: (decoded['note'] ?? '').toString(),
        exportedAt:
            DateTime.tryParse((decoded['createdAt'] ?? '').toString()) ?? DateTime.now(),
        data: data,
        assets: assets,
        header: header,
        passwordKey: key,
        storagePath: path,
      );
    } on SecretBoxAuthenticationError {
      throw BackupException(BackupErrorType.wrongPassword, '认证失败');
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(BackupErrorType.corrupted, error.toString());
    } finally {
      await raf.close();
    }
  }

  /// 第三步：把附件按索引顺序还原到 [targetDirectory]，返回写出的附件数量。
  Future<int> restoreAssets({
    required String path,
    required BackupContent content,
    required String targetDirectory,
    void Function(double progress)? onProgress,
    void Function(String storedName, String targetPath)? onAssetWritten,
  }) async {
    final raf = await File(path).open(mode: FileMode.read);
    int writtenAssets = 0;
    try {
      await raf.setPosition(headerLength);
      final reader = _CipherReader(
        raf,
        content.passwordKey,
        content.header.noncePrefix,
      );

      final prefixBytes = await reader.readPlain(4);
      if (prefixBytes.length < 4) {
        throw BackupException(BackupErrorType.corrupted, '索引不完整');
      }
      final indexLength =
          prefixBytes.buffer.asByteData(0, 4).getUint32(0, Endian.little);
      await reader.readPlain(indexLength);

      final dir = Directory(targetDirectory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      for (final asset in content.assets) {
        if (asset.storedName.isEmpty) continue;
        final targetFile = File(p.join(targetDirectory, asset.storedName));
        final sink = targetFile.openWrite();
        int remaining = asset.size;
        // 一个附件可能跨多个 1MB 分块，逐块取出写入文件，不会整包驻留内存
        while (remaining > 0) {
          final chunk = await reader.readPlain(math.min(remaining, chunkSize));
          if (chunk.isEmpty) {
            await sink.close();
            throw BackupException(BackupErrorType.corrupted, '附件数据被截断');
          }
          sink.add(chunk);
          remaining -= chunk.length;
        }
        await sink.flush();
        await sink.close();
        writtenAssets++;
        onAssetWritten?.call(asset.storedName, targetFile.path);
        onProgress?.call(writtenAssets / math.max(1, content.assets.length));
      }
      return writtenAssets;
    } on SecretBoxAuthenticationError {
      throw BackupException(BackupErrorType.wrongPassword, '认证失败');
    } on BackupException {
      rethrow;
    } catch (error) {
      throw BackupException(BackupErrorType.corrupted, error.toString());
    } finally {
      await raf.close();
    }
  }

  /// 导出时建议的文件名，例如 WU本子备份_2026.11.07_153208.wuback
  String suggestedFileName() {
    final stamp = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'WU本子备份_${stamp.year}.${two(stamp.month)}.${two(stamp.day)}_'
        '${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}$fileExtension';
  }

  // ---------------------------------------------------------------- 工具

  static List<int> _uint16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  static List<int> _uint64(int value) {
    final data = ByteData(8)..setUint64(0, value, Endian.little);
    return data.buffer.asUint8List();
  }
}

/// 把索引与多个附件拼成一个顺序字节流，并按固定大小切块。
class _ChunkFeeder {
  _ChunkFeeder({
    required List<int> indexBytes,
    required List<BackupAsset> assets,
    required this.chunkSize,
  })  : _indexBytes = indexBytes,
        _assets = assets;

  final List<int> _indexBytes;
  final List<BackupAsset> _assets;
  final int chunkSize;

  int _segment = 0; // 0 = 索引长度，1 = 索引内容，2.. = 附件
  int _offsetInSegment = 0;
  int _assetIndex = 0;
  RandomAccessFile? _raf;

  Future<Uint8List?> next() async {
    final builder = BytesBuilder(copy: false);
    while (builder.length < chunkSize) {
      final remaining = chunkSize - builder.length;
      if (_segment == 0) {
        final value = ByteData(4)..setUint32(0, _indexBytes.length, Endian.little);
        builder.add(value.buffer.asUint8List());
        _segment = 1;
        continue;
      }
      if (_segment == 1) {
        final take = math.min(remaining, _indexBytes.length - _offsetInSegment);
        builder.add(_indexBytes.sublist(_offsetInSegment, _offsetInSegment + take));
        _offsetInSegment += take;
        if (_offsetInSegment >= _indexBytes.length) {
          _segment = 2;
          _offsetInSegment = 0;
        }
        continue;
      }
      if (_assetIndex >= _assets.length) break;
      final asset = _assets[_assetIndex];
      if (_raf == null) {
        final file = File(asset.path);
        if (!await file.exists()) {
          throw BackupException(BackupErrorType.corrupted, '附件丢失：${asset.storedName}');
        }
        _raf = await file.open(mode: FileMode.read);
      }
      final take = math.min(remaining, asset.size - _offsetInSegment);
      if (take <= 0) {
        await _raf!.close();
        _raf = null;
        _assetIndex++;
        _offsetInSegment = 0;
        continue;
      }
      final bytes = await _raf!.read(take);
      if (bytes.isEmpty) {
        await _raf!.close();
        _raf = null;
        _assetIndex++;
        _offsetInSegment = 0;
        continue;
      }
      builder.add(bytes);
      _offsetInSegment += bytes.length;
      if (_offsetInSegment >= asset.size) {
        await _raf!.close();
        _raf = null;
        _assetIndex++;
        _offsetInSegment = 0;
      }
    }
    if (builder.length == 0) {
      await _raf?.close();
      _raf = null;
      return null;
    }
    return builder.takeBytes();
  }
}

/// 顺序解密读取器：按分块解密，并支持跨分块读取指定长度的明文。
/// 读取长度由调用方决定（索引长度、各附件大小），读到文件末尾时返回空数据。
class _CipherReader {
  _CipherReader(this._raf, this._key, this._noncePrefix);

  final RandomAccessFile _raf;
  final SecretKey _key;
  final Uint8List _noncePrefix;

  int _chunkIndex = 0;
  int _offsetInChunk = 0;
  Uint8List? _currentChunk;
  bool _finished = false;

  /// 最多读取 [maxBytes] 字节的明文。返回实际读到的字节（可能不足）。
  Future<Uint8List> readPlain(int maxBytes) async {
    final builder = BytesBuilder(copy: false);
    while (builder.length < maxBytes) {
      final chunk = await _ensureChunk();
      if (chunk == null) break;
      final available = chunk.length - _offsetInChunk;
      if (available <= 0) {
        _currentChunk = null;
        _offsetInChunk = 0;
        continue;
      }
      final take = math.min(maxBytes - builder.length, available);
      builder.add(Uint8List.sublistView(chunk, _offsetInChunk, _offsetInChunk + take));
      _offsetInChunk += take;
    }
    return builder.takeBytes();
  }

  Future<Uint8List?> _ensureChunk() async {
    if (_currentChunk != null) return _currentChunk;
    if (_finished) return null;

    final lengthBytes = await _raf.read(4);
    // 读到文件末尾：正常结束，不是错误
    if (lengthBytes.isEmpty) {
      _finished = true;
      return null;
    }
    if (lengthBytes.length < 4) {
      throw BackupException(BackupErrorType.corrupted, '分块长度缺失');
    }
    final plainLength = lengthBytes.buffer.asByteData(0, 4).getUint32(0, Endian.little);
    final cipherBytes = await _raf.read(plainLength + 16);
    if (cipherBytes.length < plainLength + 16) {
      throw BackupException(BackupErrorType.corrupted, '分块不完整');
    }

    final cipherText = Uint8List.sublistView(cipherBytes, 0, plainLength);
    final mac = Uint8List.sublistView(cipherBytes, plainLength);
    final nonce = CryptoService.chunkNonce(_noncePrefix, _chunkIndex);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: _key,
    );
    _chunkIndex++;
    _currentChunk = Uint8List.fromList(clear);
    return _currentChunk;
  }
}

/// 收集 sha256 的最终摘要。
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) {
    value = data;
  }

  @override
  void close() {}
}
