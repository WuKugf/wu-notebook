import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/app_state.dart';
import '../../theme/wu_theme.dart';
import '../widgets/wu_widgets.dart';

/// 回收站：所有模块删除的条目与文件都可以在这里恢复或彻底删除。
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('回收站', style: context.texts.titleLarge),
        actions: [
          ListenableBuilder(
            listenable: state,
            builder: (context, _) {
              if (state.trashRecords.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: WuSpace.xs),
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  onPressed: () => _emptyAll(context),
                  child: const Text('清空'),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final records = state.trashRecords;
            if (records.isEmpty) {
              return const WuEmptyState(
                icon: Icons.restore_from_trash_outlined,
                title: '回收站是空的',
                hint: '在任意模块里删除的内容都会先放在这里',
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: WuSpace.contentMaxWidth),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    WuSpace.md,
                    WuSpace.sm,
                    WuSpace.md,
                    WuSpace.xl,
                  ),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: WuSpace.sm),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return WuCard(
                      padding: const EdgeInsets.fromLTRB(WuSpace.md, WuSpace.sm, WuSpace.xs, WuSpace.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    WuTag(label: record.type.label),
                                    const SizedBox(width: WuSpace.xs),
                                    Expanded(
                                      child: Text(
                                        record.title,
                                        style: context.texts.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  record.subtitle.trim().isEmpty
                                      ? '删除于 ${WuUtils.formatDateTime(record.deletedAt)}'
                                      : '${record.subtitle} · 删除于 ${WuUtils.formatDateTime(record.deletedAt)}',
                                  style: context.texts.labelSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              state.restoreFromTrash(record.type, record.id);
                              wuSnack(context, '已恢复「${record.title}」');
                            },
                            child: const Text('恢复'),
                          ),
                          IconButton(
                            tooltip: '彻底删除',
                            icon: Icon(Icons.delete_outline, size: 18, color: colors.danger),
                            onPressed: () => _purge(context, record),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _purge(BuildContext context, TrashRecord record) async {
    final ok = await showWuConfirm(
      context,
      title: '彻底删除',
      message: '「${record.title}」将被永久删除，无法恢复。',
      confirmText: '永久删除',
      danger: true,
    );
    if (!ok) return;
    await state.purgeFromTrash(record.type, record.id);
    if (context.mounted) wuSnack(context, '已永久删除');
  }

  Future<void> _emptyAll(BuildContext context) async {
    if (state.trashRecords.isEmpty) return;
    final ok = await showWuConfirm(
      context,
      title: '清空回收站',
      message: '回收站里的条目与文件都会被永久删除，无法恢复。',
      confirmText: '清空',
      danger: true,
    );
    if (!ok) return;
    await state.emptyTrash();
    if (context.mounted) wuSnack(context, '回收站已清空');
  }
}
