import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../data/crypto_service.dart';
import '../../data/models/password_entry.dart';
import '../../theme/wu_theme.dart';
import '../widgets/wu_widgets.dart';

/// 密码本：条目内容加密保存在本地，默认掩码，可一键复制账号或密码。
class PasswordsScreen extends StatefulWidget {
  const PasswordsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends State<PasswordsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _activeTag;
  final Set<String> _revealed = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PasswordEntry> get _all =>
      widget.state.passwords.where((e) => !e.inTrash).toList();

  List<PasswordEntry> get _visible {
    final query = _query.trim().toLowerCase();
    final list = _all.where((entry) {
      final matchQuery = query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          entry.username.toLowerCase().contains(query) ||
          entry.notes.toLowerCase().contains(query) ||
          entry.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchTag = _activeTag == null || entry.tags.contains(_activeTag);
      return matchQuery && matchTag;
    }).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  List<String> get _tags {
    final tags = <String>{};
    for (final entry in _all) {
      tags.addAll(entry.tags);
    }
    final list = tags.toList()..sort();
    return list;
  }

  Future<void> _openEditor([PasswordEntry? entry]) async {
    final result = await showDialog<PasswordEntry>(
      context: context,
      builder: (dialogContext) => _PasswordEditor(entry: entry),
    );
    if (result != null) {
      widget.state.upsertPassword(result);
    }
  }

  Future<void> _openGenerator() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const PasswordGeneratorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final items = _visible;
    return WuPageScaffold(
      title: '密码本',
      subtitle: '共 ${_all.length} 条 · 账号与密码加密保存',
      actions: [
        IconButton(
          tooltip: '密码生成器',
          onPressed: _openGenerator,
          icon: const Icon(Icons.password_outlined, size: 18),
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
            child: WuSearchField(
              controller: _search,
              hintText: '搜索名称、账号、标签',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: WuSpace.sm),
            SizedBox(
              height: 26,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  WuTag(
                    label: '全部',
                    selected: _activeTag == null,
                    onTap: () => setState(() => _activeTag = null),
                  ),
                  const SizedBox(width: WuSpace.xs),
                  for (final tag in _tags) ...[
                    WuTag(
                      label: tag,
                      selected: _activeTag == tag,
                      onTap: () => setState(() {
                        _activeTag = _activeTag == tag ? null : tag;
                      }),
                    ),
                    const SizedBox(width: WuSpace.xs),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: WuSpace.sm),
          Expanded(
            child: items.isEmpty
                ? WuEmptyState(
                    icon: Icons.lock_outline,
                    title: _all.isEmpty ? '还没有密码条目' : '没有匹配的条目',
                    hint: _all.isEmpty ? '点右下角加号，记录第一个账号密码' : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: WuSpace.sm),
                    itemBuilder: (context, index) {
                      final entry = items[index];
                      return _PasswordCard(
                        entry: entry,
                        revealed: _revealed.contains(entry.id),
                        onToggleReveal: () => setState(() {
                          if (_revealed.contains(entry.id)) {
                            _revealed.remove(entry.id);
                          } else {
                            _revealed.add(entry.id);
                          }
                        }),
                        onEdit: () => _openEditor(entry),
                        onPin: () => widget.state.upsertPassword(
                          entry.copyWith(pinned: !entry.pinned),
                        ),
                        onDelete: () => widget.state.moveToTrash(EntityType.password, entry.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PasswordCard extends StatelessWidget {
  const _PasswordCard({
    required this.entry,
    required this.revealed,
    required this.onToggleReveal,
    required this.onEdit,
    required this.onPin,
    required this.onDelete,
  });

  final PasswordEntry entry;
  final bool revealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final masked = '•' * entry.password.length.clamp(0, 24);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
      child: WuCard(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (entry.pinned) ...[
                  Icon(Icons.push_pin_outlined, size: 14, color: colors.inkTertiary),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    entry.title.isEmpty ? '未命名' : entry.title,
                    style: context.texts.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final tag in entry.tags.take(2)) ...[
                  WuTag(label: tag),
                  const SizedBox(width: 4),
                ],
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: Icon(Icons.more_horiz, size: 18, color: colors.inkTertiary),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'pin':
                        onPin();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(entry.pinned ? '取消置顶' : '置顶'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: WuSpace.xs),
            _ValueRow(
              label: '账号',
              value: entry.username,
              onCopy: () => wuCopy(context, entry.username, '账号'),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('密码', style: context.texts.labelSmall),
                ),
                Expanded(
                  child: Text(
                    entry.password.isEmpty ? '—' : (revealed ? entry.password : masked),
                    style: context.texts.bodyMedium?.copyWith(
                      color: colors.ink,
                      letterSpacing: revealed ? 0 : 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: revealed ? '隐藏' : '查看',
                  icon: Icon(
                    revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16,
                    color: colors.inkTertiary,
                  ),
                  onPressed: onToggleReveal,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: '复制密码',
                  icon: Icon(Icons.content_copy_outlined, size: 16, color: colors.inkTertiary),
                  onPressed: () => wuCopy(context, entry.password, '密码'),
                ),
              ],
            ),
            if (entry.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: context.texts.labelSmall),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: context.texts.bodyMedium?.copyWith(color: colors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 16,
          tooltip: '复制$label',
          icon: Icon(Icons.content_copy_outlined, size: 16, color: colors.inkTertiary),
          onPressed: onCopy,
        ),
      ],
    );
  }
}

/// 新增 / 编辑密码条目。
class _PasswordEditor extends StatefulWidget {
  const _PasswordEditor({this.entry});

  final PasswordEntry? entry;

  @override
  State<_PasswordEditor> createState() => _PasswordEditorState();
}

class _PasswordEditorState extends State<_PasswordEditor> {
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _notes;
  late final TextEditingController _tags;
  late bool _pinned;
  String? _error;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title ?? '');
    _username = TextEditingController(text: entry?.username ?? '');
    _password = TextEditingController(text: entry?.password ?? '');
    _notes = TextEditingController(text: entry?.notes ?? '');
    _tags = TextEditingController(text: entry?.tags.join('，') ?? '');
    _pinned = entry?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _notes.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tags.text
      .split(RegExp('[,，]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请填写名称');
      return;
    }
    final base = widget.entry;
    final result = base == null
        ? PasswordEntry(
            id: WuUtils.newId(),
            title: title,
            username: _username.text.trim(),
            password: _password.text,
            notes: _notes.text.trim(),
            tags: _parseTags(),
            pinned: _pinned,
          )
        : base.copyWith(
            title: title,
            username: _username.text.trim(),
            password: _password.text,
            notes: _notes.text.trim(),
            tags: _parseTags(),
            pinned: _pinned,
          );
    Navigator.of(context).pop(result);
  }

  Future<void> _generate() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PasswordGeneratorDialog(
        onUse: (value) {
          _password.text = value;
          Navigator.of(dialogContext).pop();
        },
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: Text(widget.entry == null ? '新增条目' : '编辑条目'),
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
                decoration: const InputDecoration(hintText: '名称，例如：邮箱'),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: _username,
                decoration: const InputDecoration(hintText: '账号'),
              ),
              const SizedBox(height: WuSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _password,
                      obscureText: false,
                      decoration: const InputDecoration(hintText: '密码'),
                    ),
                  ),
                  const SizedBox(width: WuSpace.xs),
                  OutlinedButton(
                    onPressed: _generate,
                    child: const Text('生成'),
                  ),
                ],
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: _notes,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(hintText: '备注（可选）'),
              ),
              const SizedBox(height: WuSpace.sm),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(hintText: '标签，用逗号分隔'),
              ),
              const SizedBox(height: WuSpace.xxs),
              Row(
                children: [
                  Text('置顶', style: context.texts.bodyMedium),
                  const Spacer(),
                  Switch(
                    value: _pinned,
                    onChanged: (value) => setState(() => _pinned = value),
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

/// 本地密码生成器（纯本地随机，不联网）。
class PasswordGeneratorDialog extends StatefulWidget {
  const PasswordGeneratorDialog({super.key, this.onUse});

  final ValueChanged<String>? onUse;

  @override
  State<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  int _length = 16;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = false;
  String _preview = '';

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      _preview = CryptoService.instance.generatePassword(
        length: _length,
        useUpper: _upper,
        useLower: _lower,
        useDigits: _digits,
        useSymbols: _symbols,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('密码生成器'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(WuSpace.sm),
              decoration: BoxDecoration(
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(WuSpace.radiusS),
              ),
              child: SelectableText(
                _preview.isEmpty ? '请至少选择一种字符' : _preview,
                style: context.texts.bodyLarge?.copyWith(
                  color: colors.ink,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: WuSpace.sm),
            Row(
              children: [
                Text('长度 $_length', style: context.texts.bodyMedium),
                Expanded(
                  child: Slider(
                    value: _length.toDouble(),
                    min: 6,
                    max: 40,
                    divisions: 34,
                    label: '$_length',
                    onChanged: (value) {
                      _length = value.round();
                      _regenerate();
                    },
                  ),
                ),
              ],
            ),
            _SwitchRow(
              label: '包含大写字母',
              value: _upper,
              onChanged: (value) {
                _upper = value;
                _regenerate();
              },
            ),
            _SwitchRow(
              label: '包含小写字母',
              value: _lower,
              onChanged: (value) {
                _lower = value;
                _regenerate();
              },
            ),
            _SwitchRow(
              label: '包含数字',
              value: _digits,
              onChanged: (value) {
                _digits = value;
                _regenerate();
              },
            ),
            _SwitchRow(
              label: '包含符号',
              value: _symbols,
              onChanged: (value) {
                _symbols = value;
                _regenerate();
              },
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(WuSpace.md, 0, WuSpace.md, WuSpace.sm),
      actions: [
        TextButton(
          onPressed: _regenerate,
          child: const Text('换一个'),
        ),
        TextButton(
          onPressed: () => wuCopy(context, _preview, '密码'),
          child: const Text('复制'),
        ),
        if (widget.onUse != null)
          FilledButton(
            onPressed: _preview.isEmpty ? null : () => widget.onUse!(_preview),
            child: const Text('使用'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: context.texts.bodyMedium),
        const Spacer(),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
