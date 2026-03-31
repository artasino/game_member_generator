import 'package:flutter/material.dart';
import 'package:game_member_generator/domain/entities/match_type.dart';

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
    return AlertDialog(
      title: const Text('シャトル/ボール消費履歴',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<List<ShuttleUsageRecord>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('記録がありません'));
            }

            final history = snapshot.data!;
            return ListView.separated(
              itemCount: history.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final record = history[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _formatDate(record.date),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('合計シャトル/ボール: ${record.totalShuttles} 個',
                          style: const TextStyle(fontSize: 12)),
                      Text(
                        record.matchTypeCounts.entries
                            .map((e) => '${e.key.displayName}: ${e.value}')
                            .join(' / '),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () async {
                      if (record.id != null) {
                        await widget.repository.delete(record.id!);
                        _refresh();
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
