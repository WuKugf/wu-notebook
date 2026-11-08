import 'package:flutter_test/flutter_test.dart';
import 'package:wu_notebook/core/utils.dart';

void main() {
  test('解锁密码长度校验', () {
    expect(WuUtils.isValidMasterPassword('12345'), isFalse);
    expect(WuUtils.isValidMasterPassword('123456'), isTrue);
    expect(WuUtils.isValidMasterPassword('  '), isFalse);
  });

  test('日期格式化与天数差', () {
    expect(WuUtils.formatDate(DateTime(2026, 11, 7)), '2026.11.07');
    expect(WuUtils.formatDateTime(DateTime(2026, 11, 7, 15, 32)), '2026.11.07 15:32');
    expect(WuUtils.daysFromToday(DateTime.now()), 0);
  });

  test('文件大小与扩展名', () {
    expect(WuUtils.formatSize(512), '512 B');
    expect(WuUtils.formatSize(1536), '1.5 KB');
    expect(WuUtils.extensionOf('旅行照片.JPG'), 'jpg');
    expect(WuUtils.nameWithoutExtension('报告.pdf'), '报告');
  });
}
