import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 本地存储：使用 Hive 保存所有结构化数据。
/// 只保存“已经由上层加密好的字段”，本层不关心加密细节，保持简单可靠。
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const String _boxName = 'wu_notebook_store';

  /// 结构化数据在 box 里使用的 key。
  static const String keySettings = 'settings';
  static const String keyPasswords = 'passwords';
  static const String keyNotes = 'notes';
  static const String keyTodos = 'todos';
  static const String keyCountdowns = 'countdowns';
  static const String keyFiles = 'files';

  Box<dynamic>? _box;

  bool get isReady => _box != null;

  /// 初始化 Hive。手机、电脑、网页（预览）都能用。
  /// [path] 仅供测试指定临时目录；正式运行传空即可，走应用私有目录。
  Future<void> init({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter('wu_notebook');
    }
    _box = await Hive.openBox<dynamic>(_boxName);
  }

  Map<String, dynamic> readMap(String key) {
    final raw = _box?.get(key);
    if (raw is! Map) return <String, dynamic>{};
    return _stringKeyedMap(raw);
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    await _box?.put(key, value);
  }

  List<Map<String, dynamic>> readList(String key) {
    final raw = _box?.get(key);
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => _stringKeyedMap(item))
        .toList(growable: true);
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> value) async {
    await _box?.put(key, value);
  }

  Future<void> clearAll() async {
    await _box?.clear();
  }

  /// Hive 读取出来的嵌套 Map 键类型是 dynamic，这里统一转成 String 键。
  static Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> raw) {
    return raw.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _stringKeyedMap(value));
      }
      if (value is List) {
        return MapEntry(
          key.toString(),
          value.map((item) {
            if (item is Map) return _stringKeyedMap(item);
            return item;
          }).toList(),
        );
      }
      return MapEntry(key.toString(), value);
    });
  }

  /// 存储位置的说明文案，设置页展示用。
  String get locationLabel {
    if (kIsWeb) return '浏览器本地存储（网页预览模式）';
    return '应用私有目录内的本地数据库';
  }
}
