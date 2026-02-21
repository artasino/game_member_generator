import 'package:flutter/material.dart';
import '../../domain/entities/court_settings.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../notifiers/session_notifier.dart';

class MatchHistoryScreen extends StatelessWidget {
  final SessionNotifier notifier;

  const MatchHistoryScreen({Key? key, required this.notifier}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('試合履歴'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showClearConfirmDialog(context),
            tooltip: '履歴をクリア',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: notifier,
        builder: (context, _) {
          final sessions = notifier.sessions.reversed.toList();

          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('試合履歴がありません', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '第 ${session.index} 試合',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Divider(),
                      ...session.games.map((game) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    _PlayerTag(name: game.teamA.player1.name, gender: game.teamA.player1.gender),
                                    const SizedBox(height: 4),
                                    _PlayerTag(name: game.teamA.player2.name, gender: game.teamA.player2.gender),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text('vs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    _PlayerTag(name: game.teamB.player1.name, gender: game.teamB.player1.gender),
                                    const SizedBox(height: 4),
                                    _PlayerTag(name: game.teamB.player2.name, gender: game.teamB.player2.gender),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSettingsAndGenerate(context),
        tooltip: '試合を生成',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSettingsAndGenerate(BuildContext context) {
    final currentSettings = notifier.getCurrentSettings();
    List<MatchType> selectedTypes = List.from(currentSettings.matchTypes);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('次の試合の設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('マッチタイプを追加:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TypeButton(
                        label: '男子W',
                        color: Colors.blue,
                        onPressed: () => setState(() => selectedTypes.add(MatchType.menDoubles)),
                      ),
                      _TypeButton(
                        label: '女子W',
                        color: Colors.pink,
                        onPressed: () => setState(() => selectedTypes.add(MatchType.womenDoubles)),
                      ),
                      _TypeButton(
                        label: '混合W',
                        color: Colors.purple,
                        onPressed: () => setState(() => selectedTypes.add(MatchType.mixedDoubles)),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  const Text('生成する試合:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (selectedTypes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('試合が選択されていません', style: TextStyle(fontSize: 14)),
                    ),
                  Wrap(
                    spacing: 8,
                    children: selectedTypes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final type = entry.value;
                      return Chip(
                        label: Text(_matchTypeName(type), style: const TextStyle(fontSize: 12)),
                        onDeleted: () => setState(() => selectedTypes.removeAt(index)),
                        deleteIconColor: Colors.red,
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: selectedTypes.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(context);
                          _generateWithSettings(context, CourtSettings(selectedTypes));
                        },
                  child: const Text('生成'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _matchTypeName(MatchType type) {
    switch (type) {
      case MatchType.menDoubles: return '男子W';
      case MatchType.womenDoubles: return '女子W';
      case MatchType.mixedDoubles: return '混合W';
    }
  }

  Future<void> _generateWithSettings(BuildContext context, CourtSettings settings) async {
    try {
      await notifier.generateSessionWithSettings(settings);
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('生成エラー'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('履歴のクリア'),
        content: const Text('全ての試合履歴を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              notifier.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('クリア', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _TypeButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _PlayerTag extends StatelessWidget {
  final String name;
  final Gender gender;

  const _PlayerTag({required this.name, required this.gender});

  @override
  Widget build(BuildContext context) {
    final color = gender == Gender.male ? Colors.blue : Colors.pink;
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
