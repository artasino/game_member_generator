import 'package:flutter/material.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../domain/entities/shuttle_usage_record.dart';
import '../../domain/repository/shuttle_usage_repository.dart';

class ShuttleHistoryDialog extends StatefulWidget {
  final ShuttleUsageRepository repository;

  const ShuttleHistoryDialog({super.key, required this.repository});

  @override
  State<ShuttleHistoryDialog> createState() => _ShuttleHistoryDialogState();
}

class _ShuttleHistoryDialogState extends State<ShuttleHistoryDialog> {
  late Future<List<ShuttleUsageRecord>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _historyFuture = widget.repository.getAll();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.history_rounded,
                color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 16),
          const Text('消費履歴',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: double.maxFinite,
        height: 520,
        child: Column(
          children: [
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<ShuttleUsageRecord>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final history = snapshot.data ?? [];
                  if (history.isEmpty) {
                    return _buildEmptyState(theme);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final record = history[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 14,
                                      color: theme.colorScheme.outline),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDate(record.date),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton.filledTonal(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 20),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('削除の確認'),
                                          content: const Text('この履歴を削除しますか？'),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('キャンセル')),
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text('削除',
                                                    style: TextStyle(
                                                        color: Colors.red))),
                                          ],
                                        ),
                                      );
                                      if (confirm == true &&
                                          record.id != null) {
                                        await widget.repository
                                            .delete(record.id!);
                                        _refresh();
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        theme.colorScheme.primaryContainer,
                                    child: Icon(Symbols.badminton,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '合計 ${record.totalShuttles} 個',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18),
                                      ),
                                      Text(
                                        '使用シャトル',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.outline),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: record.matchTypeCounts.entries
                                    .where((e) => e.value > 0)
                                    .map((e) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainer,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color:
                                              theme.colorScheme.outlineVariant),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          e.key.displayName,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme
                                                  .onSurfaceVariant),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${e.value}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child:
              const Text('閉じる', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded,
                size: 48, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Text('記録がありません',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
