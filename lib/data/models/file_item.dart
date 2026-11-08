/// 文件库条目。
/// 真正的文件内容存放在应用的私有附件目录里，这里只保存元信息。
class FileItem {
  FileItem({
    required this.id,
    required this.originalName,
    required this.storedName,
    required this.size,
    this.note = '',
    List<String>? tags,
    DateTime? createdAt,
    this.deletedAt,
  })  : tags = tags ?? <String>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;

  /// 导入时的原始文件名。
  final String originalName;

  /// 附件目录里的实际文件名（UUID + 扩展名）。
  final String storedName;

  final int size;
  final String note;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? deletedAt;

  bool get inTrash => deletedAt != null;

  String get extension {
    final index = storedName.lastIndexOf('.');
    if (index < 0) return '';
    return storedName.substring(index + 1).toLowerCase();
  }

  bool get isImage =>
      const {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'}.contains(extension);
  bool get isVideo =>
      const {'mp4', 'mov', 'm4v', 'avi', 'mkv', 'webm', '3gp'}.contains(extension);
  bool get isPdf => extension == 'pdf';

  /// 列表里显示的名称，允许用户重命名。
  String get displayName => originalName;

  FileItem copyWith({
    String? originalName,
    String? note,
    List<String>? tags,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return FileItem(
      id: id,
      originalName: originalName ?? this.originalName,
      storedName: storedName,
      size: size,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toPlainMap() => {
        'id': id,
        'originalName': originalName,
        'storedName': storedName,
        'size': size,
        'note': note,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory FileItem.fromPlainMap(Map<String, dynamic> map) {
    return FileItem(
      id: map['id'] as String,
      originalName: (map['originalName'] ?? '').toString(),
      storedName: (map['storedName'] ?? '').toString(),
      size: (map['size'] as num?)?.toInt() ?? 0,
      note: (map['note'] ?? '').toString(),
      tags: (map['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: _parseDate(map['createdAt']),
      deletedAt: map['deletedAt'] == null ? null : _parseDate(map['deletedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
