import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 加密服务。
/// 采用 PBKDF2-HMAC-SHA256 从解锁密码派生 256 位密钥，
/// 所有敏感字段与备份文件都使用 AES-256-GCM 加密（带认证标签，可发现篡改/损坏）。
/// 解锁密码本身不会以任何形式写入磁盘，只保存随机盐与一段“校验密文”。
class CryptoService {
  CryptoService._();

  static final CryptoService instance = CryptoService._();

  /// PBKDF2 迭代次数。数值越大越安全，解锁耗时也越长。
  /// 只在解锁、修改密码、导出/导入备份时执行，因此这里取 100000 次。
  static const int pbkdf2Iterations = 100000;

  static const int saltLength = 16;
  static const int nonceLength = 12;

  static final AesGcm _aead = AesGcm.with256bits();
  static final Random _random = Random.secure();

  /// 生成密码学安全的随机字节。
  static Uint8List randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  /// 从密码与盐派生密钥。
  Future<SecretKey> deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  /// 加密一段文本，返回 base64(nonce + tag + 密文)。
  /// 空字符串直接返回空字符串，避免无意义的密文。
  Future<String> encryptString(SecretKey key, String plainText) async {
    if (plainText.isEmpty) return '';
    final box = await _aead.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: randomBytes(nonceLength),
    );
    final bytes = <int>[
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ];
    return base64Encode(bytes);
  }

  /// 解密 [encryptString] 的结果。
  /// 密码错误或密文损坏都会抛出异常，由调用方决定提示文案。
  Future<String> decryptString(SecretKey key, String payload) async {
    if (payload.isEmpty) return '';
    final bytes = base64Decode(payload);
    final nonce = bytes.sublist(0, nonceLength);
    final mac = bytes.sublist(nonceLength, nonceLength + 16);
    final cipherText = bytes.sublist(nonceLength + 16);
    final clear = await _aead.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  /// 用解锁密码生成“校验密文”，用于判断用户输入的密码是否正确。
  Future<String> createVerifier(SecretKey key) =>
      encryptString(key, 'wu-notebook/vault');

  /// 校验密码是否匹配。
  Future<bool> verifyKey(SecretKey key, String? verifier) async {
    if (verifier == null || verifier.isEmpty) return false;
    try {
      final text = await decryptString(key, verifier);
      return text == 'wu-notebook/vault';
    } catch (_) {
      return false;
    }
  }

  /// 备份文件分块加密时使用的 nonce：
  /// 前 8 字节来自文件头里的随机前缀，后 4 字节是分块序号。
  static Uint8List chunkNonce(Uint8List prefix, int index) {
    final nonce = Uint8List(nonceLength);
    nonce.setRange(0, 8, prefix);
    // 大端写入序号
    nonce[8] = (index >> 24) & 0xff;
    nonce[9] = (index >> 16) & 0xff;
    nonce[10] = (index >> 8) & 0xff;
    nonce[11] = index & 0xff;
    return nonce;
  }

  static final String _lower = 'abcdefghijklmnopqrstuvwxyz';
  static final String _upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static final String _digits = '0123456789';
  static final String _symbols = '!@#\$%^&*()-_=+[]{};:,.<>?';

  /// 本地密码生成器。至少包含每个被勾选字符集中的一个字符。
  String generatePassword({
    int length = 16,
    bool useUpper = true,
    bool useLower = true,
    bool useDigits = true,
    bool useSymbols = false,
  }) {
    final sets = <String>[
      if (useUpper) _upper,
      if (useLower) _lower,
      if (useDigits) _digits,
      if (useSymbols) _symbols,
    ];
    if (sets.isEmpty || length <= 0) return '';

    final buffer = <String>[];
    // 先按每个字符集各取一个，保证各类字符都出现
    for (final set in sets) {
      if (buffer.length >= length) break;
      buffer.add(set[_random.nextInt(set.length)]);
    }
    final all = sets.join();
    while (buffer.length < length) {
      buffer.add(all[_random.nextInt(all.length)]);
    }
    // 打乱顺序
    for (int i = buffer.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = buffer[i];
      buffer[i] = buffer[j];
      buffer[j] = temp;
    }
    return buffer.join();
  }
}
