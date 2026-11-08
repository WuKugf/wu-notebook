/// 密码本条目。
/// 标题与标签保留明文（列表与搜索需要），账号、密码、备注三个字段在落盘前加密。
class PasswordEntry {
  PasswordEntry({
    required this.id,
    required this.title,
    this.username = '',
    this.password = '',
    this.notes = '',
    List<String>? tags,
    this.pinned = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : tags = tags ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;

  /// 以下三个字段为内存中的明文，写入本地库时会被加密。
  final String username;
  final String password;
  final String notes;

  final List<String> tags;
  final bool pinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 不为空表示已进入回收站。
  final DateTime? deletedAt;

  bool get inTrash => deletedAt != null;

  PasswordEntry copyWith({
    String? title,
    String? username,
    String? password,
    String? notes,
    List<String>? tags,
    bool? pinned,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return PasswordEntry(
      id: id,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// 内存模型（明文），不直接落盘。
  Map<String, dynamic> toPlainMap() => {
        'id': id,
        'title': title,
        'username': username,
        'password': password,
        'notes': notes,
        'tags': tags,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory PasswordEntry.fromPlainMap(Map<String, dynamic> map) {
    return PasswordEntry(
      id: map['id'] as String,
      title: (map['title'] ?? '').toString(),
      username: (map['username'] ?? '').toString(),
      password: (map['password'] ?? '').toString(),
      notes: (map['notes'] ?? '').toString(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      pinned: map['pinned'] == true,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      deletedAt: map['deletedAt'] == null ? null : _parseDate(map['deletedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
