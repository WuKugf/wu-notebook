/// 备忘录。
/// 单条笔记可以选择加密：加密后正文以密文落盘，只有在本子解锁状态下才能读到。
class Note {
  Note({
    required this.id,
    this.title = '',
    this.content = '',
    List<String>? tags,
    List<String>? images,
    this.pinned = false,
    this.encrypted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : tags = tags ?? <String>[],
        images = images ?? <String>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String content;

  /// 正文中包含的本地图片文件名（实际文件存放在附件目录）。
  final List<String> images;

  final List<String> tags;
  final bool pinned;

  /// 是否加密正文。
  final bool encrypted;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get inTrash => deletedAt != null;

  /// 列表里显示的标题，空标题时用正文首行兜底。
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final firstLine = content.split('\n').first.trim();
    if (firstLine.isNotEmpty) return firstLine;
    return '无标题笔记';
  }

  Note copyWith({
    String? title,
    String? content,
    List<String>? tags,
    List<String>? images,
    bool? pinned,
    bool? encrypted,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      pinned: pinned ?? this.pinned,
      encrypted: encrypted ?? this.encrypted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toPlainMap() => {
        'id': id,
        'title': title,
        'content': content,
        'tags': tags,
        'images': images,
        'pinned': pinned,
        'encrypted': encrypted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Note.fromPlainMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      images: (map['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      pinned: map['pinned'] == true,
      encrypted: map['encrypted'] == true,
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
