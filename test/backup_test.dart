import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wu_notebook/data/backup_service.dart';
import 'package:wu_notebook/data/backup_types.dart';
import 'package:wu_notebook/data/crypto_service.dart';

/// 备份与加密的自查测试：
/// 1. 导出 → 校验 → 解密 → 还原附件 的完整闭环；
/// 2. 密码错误 / 文件损坏 / 不是备份文件 三种失败要能区分；
/// 3. 数据量跨多个分块时仍然正确（验证分块读写逻辑）。
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('wu_backup_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<BackupAsset> makeAsset(String name, int size) async {
    final file = File('${tempDir.path}/$name');
    final bytes = Uint8List(size);
    for (int i = 0; i < size; i++) {
      bytes[i] = i % 251;
    }
    await file.writeAsBytes(bytes);
    return BackupAsset(storedName: name, path: file.path, size: size);
  }

  test('导出后可以用同一密码解密并还原附件', () async {
    // 造一个超过 2MB 的附件，确保跨多个 1MB 分块
    final asset = await makeAsset('photo.jpg', 2 * 1024 * 1024 + 123);
    final data = <String, dynamic>{
      'schema': 1,
      'passwords': [
        {'id': 'p1', 'title': '邮箱', 'username': 'me@example.com', 'password': 'secret'}
      ],
      'notes': [
        {'id': 'n1', 'title': '笔记', 'content': '本地存储'}
      ],
    };
    final target = '${tempDir.path}/demo.wuback';

    await BackupService.instance.export(
      password: 'test123456',
      note: '2026.11.07 手机备份',
      data: data,
      assets: [asset],
      targetPath: target,
    );

    final file = File(target);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(asset.size));

    // 1) 完整性校验
    final header = await BackupService.instance.inspect(target);
    expect(header.version, 1);

    // 2) 用正确密码解密
    final content =
        await BackupService.instance.readContent(target, header, 'test123456');
    expect(content.note, '2026.11.07 手机备份');
    expect(content.assets.length, 1);
    expect(content.assets.first.size, asset.size);
    expect((content.data['passwords'] as List).first['title'], '邮箱');

    // 3) 还原附件并比对字节
    final restoreDir = '${tempDir.path}/restore';
    final count = await BackupService.instance.restoreAssets(
      path: target,
      content: content,
      targetDirectory: restoreDir,
    );
    expect(count, 1);
    final restored = File('$restoreDir/${asset.storedName}');
    final originalBytes = await File(asset.path).readAsBytes();
    final restoredBytes = await restored.readAsBytes();
    expect(restoredBytes.length, originalBytes.length);
    expect(restoredBytes, originalBytes);
  });

  test('密码错误时给出 wrongPassword', () async {
    final target = '${tempDir.path}/wrong.wuback';
    await BackupService.instance.export(
      password: 'correct-password',
      note: '',
      data: {'schema': 1},
      assets: const [],
      targetPath: target,
    );
    final header = await BackupService.instance.inspect(target);

    await expectLater(
      BackupService.instance.readContent(target, header, 'wrong-password'),
      throwsA(isA<BackupException>().having(
        (e) => e.type,
        'type',
        BackupErrorType.wrongPassword,
      )),
    );
  });

  test('改动一个字节会被判定为文件损坏', () async {
    final target = '${tempDir.path}/corrupt.wuback';
    await BackupService.instance.export(
      password: 'test123456',
      note: '完整性',
      data: {'schema': 1},
      assets: const [],
      targetPath: target,
    );

    final file = File(target);
    final bytes = await file.readAsBytes();
    // 改动负载区最后一个字节
    bytes[bytes.length - 1] = bytes[bytes.length - 1] ^ 0xFF;
    await file.writeAsBytes(bytes);

    await expectLater(
      BackupService.instance.inspect(target),
      throwsA(isA<BackupException>().having(
        (e) => e.type,
        'type',
        BackupErrorType.corrupted,
      )),
    );
  });

  test('普通文件会被判定为不是本子备份', () async {
    final target = '${tempDir.path}/plain.txt';
    await File(target).writeAsString('hello world ' * 20);

    await expectLater(
      BackupService.instance.inspect(target),
      throwsA(isA<BackupException>().having(
        (e) => e.type,
        'type',
        BackupErrorType.notBackup,
      )),
    );
  });

  test('同一密码派生出的密钥可以互相校验', () async {
    final salt = CryptoService.randomBytes(CryptoService.saltLength);
    final key = await CryptoService.instance.deriveKey('abc123456', salt);
    final verifier = await CryptoService.instance.createVerifier(key);

    final again = await CryptoService.instance.deriveKey('abc123456', salt);
    expect(await CryptoService.instance.verifyKey(again, verifier), isTrue);

    final wrong = await CryptoService.instance.deriveKey('abc123457', salt);
    expect(await CryptoService.instance.verifyKey(wrong, verifier), isFalse);
  });

  test('加密字符串可以解密还原，且密文每次都不同', () async {
    final salt = CryptoService.randomBytes(CryptoService.saltLength);
    final key = await CryptoService.instance.deriveKey('abc123456', salt);

    final a = await CryptoService.instance.encryptString(key, '一段需要加密的内容');
    final b = await CryptoService.instance.encryptString(key, '一段需要加密的内容');
    expect(a, isNot(b));
    expect(await CryptoService.instance.decryptString(key, a), '一段需要加密的内容');

    // 用另一个密钥解密应当失败
    final other = await CryptoService.instance.deriveKey('other123456', salt);
    await expectLater(
      CryptoService.instance.decryptString(other, a),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('密码生成器遵守长度与字符规则', () {
    final onlyDigits = CryptoService.instance.generatePassword(
      length: 12,
      useUpper: false,
      useLower: false,
      useDigits: true,
      useSymbols: false,
    );
    expect(onlyDigits.length, 12);
    expect(RegExp(r'^[0-9]+$').hasMatch(onlyDigits), isTrue);

    final mixed = CryptoService.instance.generatePassword(
      length: 20,
      useUpper: true,
      useLower: true,
      useDigits: true,
      useSymbols: true,
    );
    expect(mixed.length, 20);
    expect(RegExp(r'[A-Z]').hasMatch(mixed), isTrue);
    expect(RegExp(r'[a-z]').hasMatch(mixed), isTrue);
    expect(RegExp(r'[0-9]').hasMatch(mixed), isTrue);
    expect(utf8.encode(mixed).length, 20);
  });
}
