import 'dart:math';

/// 通用小工具：日期格式化、文件大小、ID 生成等。
/// 这里不依赖第三方日期库，避免多语言包带来的额外体积。
class WuUtils {
  WuUtils._();

  static final Random _random = Random.secure();

  /// 生成一个 v4 UUID，用作条目 ID 与附件文件名。
  static String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // 按 RFC 4122 设置版本位与变体位
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// 2026.11.07
  static String formatDate(DateTime time) {
    final local = time.toLocal();
    return '${local.year}.${_two(local.month)}.${_two(local.day)}';
  }

  /// 2026.11.07 15:32
  static String formatDateTime(DateTime time) {
    final local = time.toLocal();
    return '${formatDate(local)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  /// 2026.11.07_153208（备份文件名使用，避免重名）
  static String formatStamp(DateTime time) {
    final local = time.toLocal();
    return '${formatDate(local)}_${_two(local.hour)}${_two(local.minute)}${_two(local.second)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// 只保留年月日，用于倒数日的天数计算。
  static DateTime dateOnly(DateTime time) {
    final local = time.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// 今天与目标日期的天数差（目标日期 - 今天）。已过去返回负数。
  static int daysFromToday(DateTime target) {
    final today = dateOnly(DateTime.now());
    return dateOnly(target).difference(today).inDays;
  }

  /// 人性化文件大小：12.4 MB
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  /// 从文件名里取扩展名（不含点），没有扩展名返回空串。
  static String extensionOf(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index <= 0 || index == fileName.length - 1) return '';
    return fileName.substring(index + 1).toLowerCase();
  }

  /// 去掉文件名里的扩展名。
  static String nameWithoutExtension(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index <= 0) return fileName;
    return fileName.substring(0, index);
  }

  /// 解锁密码的规范性校验（长度 6-128）。
  static bool isValidMasterPassword(String value) =>
      value.trim().length >= 6 && value.trim().length <= 128;
}
