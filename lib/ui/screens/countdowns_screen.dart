import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../data/models/countdown_item.dart';
import '../../theme/wu_theme.dart';
import '../widgets/wu_widgets.dart';

/// 倒数日列表。
/// 排序规则：置顶优先 → 未来的按剩余天数升序 → 已经过去的按刚刚过去的优先。
class CountdownsScreen extends StatefulWidget {
  const CountdownsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CountdownsScreen> createState() => _CountdownsScreenState();
}

class _CountdownsScreenState extends State<CountdownsScreen> {
  /// 当前选中的标签（null 表示全部）。
  String? _tag;

  List<CountdownItem> get _items => widget.state.countdowns.where((e) => !e.inTrash).toList();

  /// 所有出现过的标签，用来做筛选条。
  List<String> get _tags {
    final set = <String>{};
    for (final item in _items) {
      set.addAll(item.tags);
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  List<CountdownItem> get _visible {
    final list = _items.where((item) {
      if (_tag == null) return true;
      return item.tags.contains(_tag);
    }).toList();

    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      final daysA = WuUtils.daysFromToday(a.targetDate);
      final daysB = WuUtils.daysFromToday(b.targetDate);
      final futureA = daysA >= 0;
      final futureB = daysB >= 0;
      // 未来的排在已经过去的前面
      if (futureA != futureB) return futureA ? -1 : 1;
      if (futureA) return daysA.compareTo(daysB); // 越近越靠前
      return daysB.compareTo(daysA); // 过去：刚刚过去的靠前
    });
    return list;
  }

  Future<void> _openEditor([CountdownItem? item]) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CountdownEditor(state: widget.state, item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _visible;
    final tags = _tags;
    return WuPageScaffold(
      title: '倒数日',
      subtitle: '共 ${_items.length} 个 · 未来是倒数，过去是纪念日',
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
          if (tags.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
              child: Wrap(
                spacing: WuSpace.xs,
                runSpacing: WuSpace.xs,
                children: [
                  WuTag(
                    label: '全部',
                    selected: _tag == null,
                    onTap: () => setState(() => _tag = null),
                  ),
                  for (final tag in tags)
                    WuTag(
                      label: tag,
                      selected: _tag == tag,
                      onTap: () => setState(() => _tag = _tag == tag ? null : tag),
                    ),
                ],
              ),
            ),
            const SizedBox(height: WuSpace.sm),
          ],
          Expanded(
            child: items.isEmpty
                ? WuEmptyState(
                    icon: Icons.event_outlined,
                    title: _items.isEmpty ? '还没有倒数日' : '这个标签下没有条目',
                    hint: _items.isEmpty ? '记下值得等待与纪念的日子' : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: WuSpace.sm),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
                        child: _CountdownCard(
                          item: item,
                          onEdit: () => _openEditor(item),
                          onPin: () {
                            widget.state.upsertCountdown(
                              item.copyWith(pinned: !item.pinned),
                            );
                          },
                          onDelete: () => _delete(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(CountdownItem item) async {
    final ok = await showWuConfirm(
      context,
      title: '删除「${item.title}」',
      message: '会移入回收站，可以之后恢复。',
      confirmText: '删除',
      danger: true,
    );
    if (!ok) return;
    widget.state.moveToTrash(EntityType.countdown, item.id);
  }
}

/// 单条倒数日卡片：左侧颜色条 + 大号天数 + 右侧信息。
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.item,
    required this.onEdit,
    required this.onPin,
    required this.onDelete,
  });

  final CountdownItem item;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = WuUtils.daysFromToday(item.targetDate);
    final isFuture = days >= 0;
    final numberText = days == 0 ? '0' : '${days.abs()}';
    final caption = days == 0
        ? '就是今天'
        : (isFuture ? '还有 $days 天' : '已经过去 ${days.abs()} 天');

    return WuCard(
      onTap: onEdit,
      padding: const EdgeInsets.fromLTRB(WuSpace.sm, WuSpace.sm, WuSpace.xxs, WuSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 颜色标记（低饱和的纸感色条）
          Container(
            width: 4,
            height: 60,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: WuSpace.sm),
          // 大号天数
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  numberText,
                  style: context.texts.displaySmall?.copyWith(
                    fontSize: 30,
                    height: 1.1,
                    color: item.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(caption, style: context.texts.labelSmall),
              ],
            ),
          ),
          // 标题、备注、标签
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.pinned) ...[
                      Icon(Icons.push_pin_outlined, size: 12, color: colors.inkTertiary),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        item.title,
                        style: context.texts.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  WuUtils.formatDate(item.targetDate),
                  style: context.texts.bodySmall,
                ),
                if (item.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.bodySmall?.copyWith(color: colors.inkSecondary),
                  ),
                ],
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final tag in item.tags) WuTag(label: tag, color: item.color),
                    ],
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: '',
            icon: Icon(Icons.more_horiz, size: 18, color: colors.inkTertiary),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                  break;
                case 'pin':
                  onPin();
                  break;
                case 'delete':
                  onDelete();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(
                value: 'pin',
                child: Text(item.pinned ? '取消置顶' : '置顶'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 新增 / 编辑倒数日的弹窗。
class _CountdownEditor extends StatefulWidget {
  const _CountdownEditor({required this.state, this.item});

  final AppState state;
  final CountdownItem? item;

  @override
  State<_CountdownEditor> createState() => _CountdownEditorState();
}

class _CountdownEditorState extends State<_CountdownEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _tags;
  late DateTime _targetDate;
  late int _colorIndex;
  late bool _pinned;
  bool _saving = false;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _tags = TextEditingController(text: item?.tags.join('，') ?? '');
    _targetDate = item?.targetDate ?? DateTime.now().add(const Duration(days: 30));
    _colorIndex = item?.colorIndex ?? 0;
    _pinned = item?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tags.text
      .split(RegExp('[,，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      helpText: '选择目标日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _targetDate = picked);
  }

  void _save() {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      wuSnack(context, '给这个日子起个名字');
      return;
    }
    _saving = true;
    final base = widget.item;
    final item = base == null
        ? CountdownItem(
            id: WuUtils.newId(),
            title: _title.text.trim(),
            targetDate: _targetDate,
            note: _note.text.trim(),
            tags: _parseTags(),
            pinned: _pinned,
            colorIndex: _colorIndex,
          )
        : base.copyWith(
            title: _title.text.trim(),
            targetDate: _targetDate,
            note: _note.text.trim(),
            tags: _parseTags(),
            pinned: _pinned,
            colorIndex: _colorIndex,
          );
    widget.state.upsertCountdown(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final days = WuUtils.daysFromToday(_targetDate);
    return AlertDialog(
      title: Text(_isNew ? '新增倒数日' : '编辑倒数日'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(hintText: '标题，例如 生日 / 旅行出发'),
              ),
              const SizedBox(height: WuSpace.sm),
              // 日期选择：点击整行打开系统日期选择器
              Material(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(WuSpace.radiusS),
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(WuSpace.radiusS),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WuSpace.sm,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(WuSpace.radiusS),
                      border: Border.all(color: colors.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_outlined, size: 16, color: colors.inkSecondary),
                        const SizedBox(width: WuSpace.xs),
                        Expanded(
                          child: Text(
                            WuUtils.formatDate(_targetDate),
                            style: context.texts.bodyLarge,
                          ),
                        ),
                        Text(
                          days == 0
                              ? '今天'
                              : (days > 0 ? '还有 $days 天' : '已过去 ${days.abs()} 天'),
                          style: context.texts.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(hintText: '备注（可不填）'),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(hintText: '标签，用逗号分隔'),
              ),
              const SizedBox(height: WuSpace.md),
              Text('颜色标记', style: context.texts.labelMedium),
              const SizedBox(height: WuSpace.xs),
              Wrap(
                spacing: WuSpace.xs,
                children: [
                  for (int i = 0; i < kCountdownColors.length; i++)
                    InkWell(
                      onTap: () => setState(() => _colorIndex = i),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: kCountdownColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == _colorIndex ? colors.ink : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: WuSpace.sm),
              Row(
                children: [
                  Icon(Icons.push_pin_outlined, size: 15, color: colors.inkSecondary),
                  const SizedBox(width: 6),
                  Text('置顶', style: context.texts.bodyMedium),
                  const Spacer(),
                  Switch(
                    value: _pinned,
                    onChanged: (value) => setState(() => _pinned = value),
                  ),
                ],
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
        FilledButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
