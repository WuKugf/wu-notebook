/// 待办优先级。用低饱和的颜色区分，不使用大红大紫。
enum TodoPriority {
  low('低', 0),
  medium('中', 1),
  high('高', 2);

  const TodoPriority(this.label, this.level);

  final String label;
  final int level;

  static TodoPriority fromLevel(int? level) {
    return TodoPriority.values.firstWhere(
      (item) => item.level == (level ?? 1),
      orElse: () => TodoPriority.medium,
    );
  }
}

/// 重复规则。
enum TodoRepeat {
  none('不重复'),
  daily('每天'),
  weekly('每周'),
  monthly('每月');

  const TodoRepeat(this.label);

  final String label;

  static TodoRepeat fromName(String? name) {
    return TodoRepeat.values.firstWhere(
      (item) => item.name == name,
      orElse: () => TodoRepeat.none,
    );
  }

  /// 按规则推算下一次截止时间。
  DateTime? nextDate(DateTime? from) {
    if (from == null || this == TodoRepeat.none) return null;
    switch (this) {
      case TodoRepeat.daily:
        return from.add(const Duration(days: 1));
      case TodoRepeat.weekly:
        return from.add(const Duration(days: 7));
      case TodoRepeat.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case TodoRepeat.none:
        return null;
    }
  }
}

/// 子任务。
class TodoSubtask {
  TodoSubtask({required this.id, required this.title, this.done = false});

  final String id;
  final String title;
  final bool done;

  TodoSubtask copyWith({String? title, bool? done}) =>
      TodoSubtask(id: id, title: title ?? this.title, done: done ?? this.done);

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'done': done};

  factory TodoSubtask.fromMap(Map<String, dynamic> map) => TodoSubtask(
        id: (map['id'] ?? '').toString(),
        title: (map['title'] ?? '').toString(),
        done: map['done'] == true,
      );
}

/// 待办条目。
class TodoItem {
  TodoItem({
    required this.id,
    required this.title,
    this.note = '',
    this.dueDate,
    this.priority = TodoPriority.medium,
    this.repeat = TodoRepeat.none,
    List<TodoSubtask>? subtasks,
    this.done = false,
    this.archived = false,
    this.order = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : subtasks = subtasks ?? <TodoSubtask>[],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String title;
  final String note;
  final DateTime? dueDate;
  final TodoPriority priority;
  final TodoRepeat repeat;
  final List<TodoSubtask> subtasks;
  final bool done;

  /// 归档后不在主列表显示，可在“已归档”视图查看。
  final bool archived;

  /// 手动拖拽排序的序号，越小越靠上。
  final int order;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get inTrash => deletedAt != null;

  /// 子任务完成进度，例如 1/3。
  String get subtaskProgress {
    if (subtasks.isEmpty) return '';
    final doneCount = subtasks.where((e) => e.done).length;
    return '$doneCount/${subtasks.length}';
  }

  TodoItem copyWith({
    String? title,
    String? note,
    DateTime? dueDate,
    bool clearDueDate = false,
    TodoPriority? priority,
    TodoRepeat? repeat,
    List<TodoSubtask>? subtasks,
    bool? done,
    bool? archived,
    int? order,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TodoItem(
      id: id,
      title: title ?? this.title,
      note: note ?? this.note,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
      repeat: repeat ?? this.repeat,
      subtasks: subtasks ?? this.subtasks,
      done: done ?? this.done,
      archived: archived ?? this.archived,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toPlainMap() => {
        'id': id,
        'title': title,
        'note': note,
        'dueDate': dueDate?.toIso8601String(),
        'priority': priority.level,
        'repeat': repeat.name,
        'subtasks': subtasks.map((e) => e.toMap()).toList(),
        'done': done,
        'archived': archived,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory TodoItem.fromPlainMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as String,
      title: (map['title'] ?? '').toString(),
      note: (map['note'] ?? '').toString(),
      dueDate: map['dueDate'] == null ? null : _parseDate(map['dueDate']),
      priority: TodoPriority.fromLevel((map['priority'] as num?)?.toInt()),
      repeat: TodoRepeat.fromName(map['repeat']?.toString()),
      subtasks: (map['subtasks'] as List?)
              ?.whereType<Map>()
              .map((e) => TodoSubtask.fromMap(e.cast<String, dynamic>()))
              .toList() ??
          [],
      done: map['done'] == true,
      archived: map['archived'] == true,
      order: (map['order'] as num?)?.toInt() ?? 0,
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
