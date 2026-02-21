import 'package:flutter/material.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../notifiers/player_notifier.dart';
import '../notifiers/session_notifier.dart';

class PlayerListScreen extends StatelessWidget {
  final PlayerNotifier notifier;
  final SessionNotifier sessionNotifier;

  const PlayerListScreen({
    Key? key,
    required this.notifier,
    required this.sessionNotifier,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('メンバ一覧'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([notifier, sessionNotifier]),
        builder: (context, _) {
          final players = notifier.players;
          final statsMap = sessionNotifier.playerStats;

          if (players.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('メンバを登録してください', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: players.map((player) {
                final genderColor = player.gender == Gender.male ? Colors.blue : Colors.pink;
                // statsMap は全プレイヤーを包含しているため、必ず取得できる
                final stats = statsMap[player.id] ?? PlayerStats(totalMatches: 0, typeCounts: {});
                
                return InkWell(
                  onTap: () => notifier.toggleActive(player),
                  onLongPress: () => _showAddEditDialog(context, player: player),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: player.isActive 
                          ? genderColor.withOpacity(0.1) 
                          : theme.colorScheme.onSurface.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: player.isActive 
                            ? genderColor.withOpacity(0.5) 
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          player.gender == Gender.male ? Icons.male : Icons.female,
                          size: 16,
                          color: player.isActive ? genderColor : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: player.isActive ? FontWeight.bold : FontWeight.normal,
                                decoration: player.isActive ? null : TextDecoration.lineThrough,
                                color: player.isActive ? Colors.black87 : Colors.grey,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _buildStatsString(player, stats),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: player.isActive ? Colors.black54 : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        tooltip: 'メンバを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _buildStatsString(Player player, PlayerStats stats) {
    final m = stats.typeCounts[MatchType.menDoubles] ?? 0;
    final w = stats.typeCounts[MatchType.womenDoubles] ?? 0;
    final x = stats.typeCounts[MatchType.mixedDoubles] ?? 0;
    
    final List<String> details = [];
    if (player.gender == Gender.male) {
      details.add('男$m');
    } else {
      details.add('女$w');
    }
    details.add('混$x');
    
    return '計${stats.totalMatches} (${details.join(' ')})';
  }

  void _showAddEditDialog(BuildContext context, {Player? player}) {
    final isEdit = player != null;
    final nameController = TextEditingController(text: player?.name ?? '');
    Gender selectedGender = player?.gender ?? Gender.male;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'メンバ編集' : 'メンバ登録'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '名前',
                      hintText: '例: 山田 太郎',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('性別', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<Gender>(
                          title: const Text('男性'),
                          value: Gender.male,
                          groupValue: selectedGender,
                          onChanged: (v) => setState(() => selectedGender = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<Gender>(
                          title: const Text('女性'),
                          value: Gender.female,
                          groupValue: selectedGender,
                          onChanged: (v) => setState(() => selectedGender = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                if (isEdit)
                  TextButton(
                    onPressed: () {
                      notifier.removePlayer(player.id);
                      Navigator.pop(context);
                    },
                    child: const Text('削除', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    if (isEdit) {
                      notifier.updatePlayer(player.copyWith(
                        name: name,
                        gender: selectedGender,
                      ));
                    } else {
                      notifier.addPlayer(Player(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        gender: selectedGender,
                      ));
                    }
                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? '更新' : '登録'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
