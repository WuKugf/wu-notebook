import 'package:flutter/material.dart';

/// 倒数日的颜色标记（低饱和的纸感色）。
const List<Color> kCountdownColors = <Color>[
  Color(0xFF8C9A80), // 苔绿
  Color(0xFFB08F7A), // 陶土
  Color(0xFF8E9AA8), // 雾蓝
  Color(0xFFB7A36B), // 麦黄
  Color(0xFF9C8FA6), // 藕紫
  Color(0xFF7F8F8C), // 青灰
];

/// 倒数日 / 纪念日条目。
class CountdownItem {
  CountdownItem({
    required this.id,
    required this.title,
    required this.targetDate,
    this.note = '',
    List<String>? tags,
    this.pinned = false,
    this.colorIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : tags = tags ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final DateTime targetDate;
  final String note;
  final List<String> tags;
  final bool pinned;

  /// 颜色标记在 kCountdownColors 中的下标。
  final int colorIndex;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get inTrash => deletedAt != null;

  Color get color => kCountdownColors[colorIndex % kCountdownColors.length];

  CountdownItem copyWith({
    String? title,
    DateTime? targetDate,
    String? note,
    List<String>? tags,
    bool? pinned,
    int? colorIndex,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return CountdownItem(
      id: id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toPlainMap() => {
        'id': id,
        'title': title,
        'targetDate': targetDate.toIso8601String(),
        'note': note,
        'tags': tags,
        'pinned': pinned,
        'colorIndex': colorIndex,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory CountdownItem.fromPlainMap(Map<String, dynamic> map) {
    return CountdownItem(
      id: map['id'] as String,
      title: (map['title'] ?? '').toString(),
      targetDate: _parseDate(map['targetDate']),
      note: (map['note'] ?? '').toString(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      pinned: map['pinned'] == true,
      colorIndex: (map['colorIndex'] as num?)?.toInt() ?? 0,
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
