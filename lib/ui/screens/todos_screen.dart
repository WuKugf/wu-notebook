import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../data/models/todo_item.dart';
import '../../theme/wu_theme.dart';
import '../widgets/wu_widgets.dart';

enum _TodoFilter { active, done, archived }

/// 待办清单：勾选、截止时间、优先级、拖拽排序、归档、重复待办与子任务。
class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  _TodoFilter _filter = _TodoFilter.active;

  List<TodoItem> get _items {
    final list = widget.state.todos.where((item) {
      if (item.inTrash) return false;
      switch (_filter) {
        case _TodoFilter.active:
          return !item.archived && !item.done;
        case _TodoFilter.done:
          return !item.archived && item.done;
        case _TodoFilter.archived:
          return item.archived;
      }
    }).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  Future<void> _openEditor([TodoItem? item]) async {
    final result = await showDialog<TodoItem>(
      context: context,
      builder: (dialogContext) => _TodoEditor(item: item),
    );
    if (result != null) {
      widget.state.upsertTodo(result);
    }
  }

  Future<void> _archiveDone() async {
    final count = widget.state.archiveCompleted();
    if (!mounted) return;
    wuSnack(context, count == 0 ? '没有可归档的已完成待办' : '已归档 $count 条待办');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _items;
    final activeCount = widget.state.todos
        .where((e) => !e.inTrash && !e.done && !e.archived)
        .length;
    return WuPageScaffold(
      title: '待办',
      subtitle: '还有 $activeCount 条未完成',
      actions: [
        IconButton(
          tooltip: '归档已完成',
          onPressed: _archiveDone,
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          color: colors.inkSecondary,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(WuSpace.radiusM)),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _FilterChip(
                label: '进行中',
                selected: _filter == _TodoFilter.active,
                onTap: () => setState(() => _filter = _TodoFilter.active),
              ),
              const SizedBox(width: WuSpace.xs),
              _FilterChip(
                label: '已完成',
                selected: _filter == _TodoFilter.done,
                onTap: () => setState(() => _filter = _TodoFilter.done),
              ),
              const SizedBox(width: WuSpace.xs),
              _FilterChip(
                label: '已归档',
                selected: _filter == _TodoFilter.archived,
                onTap: () => setState(() => _filter = _TodoFilter.archived),
              ),
            ],
          ),
          const SizedBox(height: WuSpace.sm),
          Expanded(
            child: items.isEmpty
                ? WuEmptyState(
                    icon: Icons.check_circle_outline,
                    title: '这里还是空的',
                    hint: _filter == _TodoFilter.active
                        ? '添加一件想完成的小事'
                        : '这个分类下暂时没有内容',
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 90),
                    buildDefaultDragHandles: _filter == _TodoFilter.active,
                    itemCount: items.length,
                    // onReorderItem 已经修正过 newIndex，无需再减一
                    onReorderItem: (oldIndex, newIndex) {
                      if (_filter != _TodoFilter.active) return;
                      final ids = items.map((e) => e.id).toList();
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                      widget.state.applyTodoOrder(ids);
                    },
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Padding(
                        key: ValueKey(item.id),
                        padding: const EdgeInsets.only(bottom: WuSpace.xs),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
                          child: _TodoTile(
                            item: item,
                            state: widget.state,
                            onEdit: () => _openEditor(item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WuSpace.radiusS),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(WuSpace.radiusS),
          border: Border.all(color: selected ? colors.accent.withValues(alpha: 0.4) : colors.line),
        ),
        child: Text(
          label,
          style: context.texts.labelMedium?.copyWith(
            color: selected ? colors.ink : colors.inkSecondary,
          ),
        ),
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile({required this.item, required this.state, required this.onEdit});

  final TodoItem item;
  final AppState state;
  final VoidCallback onEdit;

  Color _priorityColor(WuColors colors) {
    switch (item.priority) {
      case TodoPriority.high:
        return colors.danger;
      case TodoPriority.medium:
        return colors.accent;
      case TodoPriority.low:
        return colors.inkTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final overdue = item.dueDate != null &&
        !item.done &&
        WuUtils.dateOnly(item.dueDate!).isBefore(WuUtils.dateOnly(DateTime.now()));
    return WuCard(
      padding: const EdgeInsets.fromLTRB(WuSpace.sm, WuSpace.xs, WuSpace.xxs, WuSpace.xs),
      onTap: onEdit,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: item.done ? '标记未完成' : '标记完成',
            icon: Icon(
              item.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: item.done ? colors.accent : colors.inkTertiary,
            ),
            onPressed: () => state.setTodoDone(item.id, !item.done),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _priorityColor(colors),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleMedium?.copyWith(
                          color: item.done ? colors.inkTertiary : colors.ink,
                          decoration: item.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.dueDate != null || item.repeat != TodoRepeat.none || item.subtasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 12),
                    child: Row(
                      children: [
                        if (item.dueDate != null) ...[
                          Icon(Icons.event_outlined, size: 12,
                              color: overdue ? colors.danger : colors.inkTertiary),
                          const SizedBox(width: 3),
                          Text(
                            WuUtils.formatDate(item.dueDate!),
                            style: context.texts.labelSmall?.copyWith(
                              color: overdue ? colors.danger : colors.inkTertiary,
                            ),
                          ),
                          const SizedBox(width: WuSpace.xs),
                        ],
                        if (item.repeat != TodoRepeat.none) ...[
                          Icon(Icons.repeat, size: 12, color: colors.inkTertiary),
                          const SizedBox(width: 3),
                          Text(item.repeat.label, style: context.texts.labelSmall),
                          const SizedBox(width: WuSpace.xs),
                        ],
                        if (item.subtasks.isNotEmpty)
                          Text(
                            '子任务 ${item.subtaskProgress}',
                            style: context.texts.labelSmall,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '更多',
            icon: Icon(Icons.more_horiz, size: 18, color: colors.inkTertiary),
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'delete':
                  state.moveToTrash(EntityType.todo, item.id);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 新增 / 编辑待办。
class _TodoEditor extends StatefulWidget {
  const _TodoEditor({this.item});

  final TodoItem? item;

  @override
  State<_TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<_TodoEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _subtaskInput;
  late DateTime? _dueDate;
  late TodoPriority _priority;
  late TodoRepeat _repeat;
  late List<TodoSubtask> _subtasks;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _subtaskInput = TextEditingController();
    _dueDate = item?.dueDate;
    _priority = item?.priority ?? TodoPriority.medium;
    _repeat = item?.repeat ?? TodoRepeat.none;
    _subtasks = List<TodoSubtask>.from(item?.subtasks ?? const <TodoSubtask>[]);
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _subtaskInput.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) {
      setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  void _addSubtask() {
    final text = _subtaskInput.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(TodoSubtask(id: WuUtils.newId(), title: text));
      _subtaskInput.clear();
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请填写待办内容');
      return;
    }
    final base = widget.item;
    final result = base == null
        ? TodoItem(
            id: WuUtils.newId(),
            title: title,
            note: _note.text.trim(),
            dueDate: _dueDate,
            priority: _priority,
            repeat: _repeat,
            subtasks: _subtasks,
          )
        : base.copyWith(
            title: title,
            note: _note.text.trim(),
            dueDate: _dueDate,
            clearDueDate: _dueDate == null,
            priority: _priority,
            repeat: _repeat,
            subtasks: _subtasks,
          );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text(widget.item == null ? '新增待办' : '编辑待办'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(hintText: '要做什么'),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: _note,
                maxLines: 2,
                minLines: 1,
                decoration: const InputDecoration(hintText: '备注（可选）'),
              ),
              const SizedBox(height: WuSpace.sm),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      _dueDate == null ? '选择截止时间' : WuUtils.formatDate(_dueDate!),
                    ),
                  ),
                  if (_dueDate != null) ...[
                    const SizedBox(width: WuSpace.xs),
                    IconButton(
                      tooltip: '清除时间',
                      onPressed: () => setState(() => _dueDate = null),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: WuSpace.sm),
              Text('优先级', style: context.texts.labelMedium),
              const SizedBox(height: WuSpace.xxs),
              Row(
                children: [
                  for (final priority in TodoPriority.values) ...[
                    _FilterChip(
                      label: priority.label,
                      selected: _priority == priority,
                      onTap: () => setState(() => _priority = priority),
                    ),
                    const SizedBox(width: WuSpace.xs),
                  ],
                ],
              ),
              const SizedBox(height: WuSpace.sm),
              Text('重复', style: context.texts.labelMedium),
              const SizedBox(height: WuSpace.xxs),
              Wrap(
                spacing: WuSpace.xs,
                runSpacing: WuSpace.xs,
                children: [
                  for (final repeat in TodoRepeat.values)
                    _FilterChip(
                      label: repeat.label,
                      selected: _repeat == repeat,
                      onTap: () => setState(() => _repeat = repeat),
                    ),
                ],
              ),
              const SizedBox(height: WuSpace.md),
              Text('子任务', style: context.texts.labelMedium),
              const SizedBox(height: WuSpace.xxs),
              for (final sub in _subtasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.drag_handle, size: 14, color: colors.inkTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(sub.title, style: context.texts.bodyMedium),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 15,
                        onPressed: () => setState(() => _subtasks.remove(sub)),
                        icon: Icon(Icons.close, size: 15, color: colors.inkTertiary),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subtaskInput,
                      onSubmitted: (_) => _addSubtask(),
                      decoration: const InputDecoration(hintText: '添加子任务'),
                    ),
                  ),
                  const SizedBox(width: WuSpace.xs),
                  IconButton(
                    onPressed: _addSubtask,
                    icon: Icon(Icons.add, size: 18, color: colors.accent),
                  ),
                ],
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: context.texts.bodySmall?.copyWith(color: colors.danger),
                ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }
}
