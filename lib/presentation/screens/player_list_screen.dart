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
          final allPlayers = List<Player>.from(notifier.players);
          if (allPlayers.isEmpty) {
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

          // よみがな順にソート
          allPlayers.sort((a, b) => a.yomigana.compareTo(b.yomigana));

          // Activeメンバを抽出
          final activePlayers = allPlayers.where((p) => p.isActive).toList();
          final statsMap = sessionNotifier.playerStats;

          // 五十音の行ごとにグループ化 (よみがなを使用)
          final groupedPlayers = <String, List<Player>>{};
          for (var player in allPlayers) {
            final indexLabel = _getIndexLabel(player.yomigana);
            groupedPlayers.putIfAbsent(indexLabel, () => []).add(player);
          }
          final sortedLabels = groupedPlayers.keys.toList()
            ..sort((a, b) => _labelOrder(a).compareTo(_labelOrder(b)));

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activePlayers.isNotEmpty) ...[
                  _buildSectionTitle(
                      context, _buildActiveMemberTitle(activePlayers)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activePlayers
                        .map((player) =>
                            _buildPlayerChip(context, player, statsMap, theme))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                _buildSectionTitle(context, '全メンバ (五十音順)'),
                const SizedBox(height: 16),
                ...sortedLabels.map((label) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary.withOpacity(0.7),
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: groupedPlayers[label]!
                            .map((player) => _buildPlayerChip(
                                context, player, statsMap, theme))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                }).toList(),
              ],
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

  String _buildActiveMemberTitle(List<Player> activePlayers) {
    final maleCount =
        activePlayers.where((p) => p.gender == Gender.male).length;
    final femaleCount =
        activePlayers.where((p) => p.gender == Gender.female).length;
    return '本日の参加メンバ (計${activePlayers.length}名: 男$maleCount 女$femaleCount)';
  }

  /// 名前の先頭文字からインデックスラベル（あ、か、さ...）を返す
  String _getIndexLabel(String yomigana) {
    if (yomigana.isEmpty) return '#';
    final firstChar = yomigana.substring(0, 1);

    const mapping = {
      'あ': 'あ',
      'い': 'あ',
      'う': 'あ',
      'え': 'あ',
      'お': 'あ',
      'か': 'か',
      'き': 'か',
      'く': 'か',
      'け': 'か',
      'こ': 'か',
      'さ': 'さ',
      'し': 'さ',
      'す': 'さ',
      'せ': 'さ',
      'そ': 'さ',
      'た': 'た',
      'ち': 'た',
      'つ': 'た',
      'て': 'た',
      'と': 'た',
      'な': 'な',
      'に': 'な',
      'ぬ': 'な',
      'ね': 'な',
      'の': 'な',
      'は': 'は',
      'ひ': 'は',
      'ふ': 'は',
      'へ': 'は',
      'ほ': 'は',
      'ま': 'ま',
      'み': 'ま',
      'む': 'ま',
      'め': 'ま',
      'も': 'ま',
      'や': 'や',
      'ゆ': 'や',
      'よ': 'や',
      'ら': 'ら',
      'り': 'ら',
      'る': 'ら',
      'れ': 'ら',
      'ろ': 'ら',
      'わ': 'わ',
      'を': 'わ',
      'ん': 'わ',
      'が': 'か',
      'ぎ': 'か',
      'ぐ': 'か',
      'げ': 'か',
      'ご': 'か',
      'ざ': 'さ',
      'じ': 'さ',
      'ず': 'さ',
      'ぜ': 'さ',
      'ぞ': 'さ',
      'だ': 'た',
      'ぢ': 'た',
      'づ': 'た',
      'で': 'た',
      'ど': 'た',
      'ば': 'は',
      'び': 'は',
      'ぶ': 'は',
      'べ': 'は',
      'ぱ': 'は',
      'ぴ': 'は',
      'ぷ': 'は',
      'ぺ': 'は',
      'ぽ': 'は',
    };

    return mapping[firstChar] ??
        (RegExp(r'^[a-zA-Z]').hasMatch(firstChar)
            ? firstChar.toUpperCase()
            : '#');
  }

  int _labelOrder(String label) {
    const order = 'あかさたなはまやらわ';
    final index = order.indexOf(label);
    if (index != -1) return index;
    if (RegExp(r'^[A-Z]$').hasMatch(label)) return 100 + label.codeUnitAt(0);
    return 1000;
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
    );
  }

  Widget _buildPlayerChip(BuildContext context, Player player,
      Map<String, PlayerStats> statsMap, ThemeData theme) {
    final genderColor =
        player.gender == Gender.male ? Colors.blue : Colors.pink;
    final stats =
        statsMap[player.id] ?? PlayerStats(totalMatches: 0, typeCounts: {});

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
                    fontWeight:
                        player.isActive ? FontWeight.bold : FontWeight.normal,
                    decoration:
                        player.isActive ? null : TextDecoration.lineThrough,
                    color: player.isActive ? Colors.black87 : Colors.grey,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _buildStatsString(stats),
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
  }

  String _buildStatsString(PlayerStats stats) {
    final m = stats.typeCounts[MatchType.menDoubles] ?? 0;
    final w = stats.typeCounts[MatchType.womenDoubles] ?? 0;
    final x = stats.typeCounts[MatchType.mixedDoubles] ?? 0;

    return '計${stats.totalMatches} (男$m 女$w 混$x)';
  }

  void _showAddEditDialog(BuildContext context, {Player? player}) {
    final isEdit = player != null;
    final nameController = TextEditingController(text: player?.name ?? '');
    final yomiganaController =
        TextEditingController(text: player?.yomigana ?? '');
    Gender selectedGender = player?.gender ?? Gender.male;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'メンバ編集' : 'メンバ登録'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: !isEdit,
                      decoration: const InputDecoration(
                        labelText: '名前',
                        hintText: '例: 山田 太郎',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: yomiganaController,
                      decoration: const InputDecoration(
                        labelText: 'よみがな',
                        hintText: '例: やまだ たろう',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('性別',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<Gender>(
                            title: const Text('男性'),
                            value: Gender.male,
                            groupValue: selectedGender,
                            onChanged: (v) =>
                                setState(() => selectedGender = v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<Gender>(
                            title: const Text('女性'),
                            value: Gender.female,
                            groupValue: selectedGender,
                            onChanged: (v) =>
                                setState(() => selectedGender = v!),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                    child:
                        const Text('削除', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final yomigana = yomiganaController.text.trim();
                    if (name.isEmpty || yomigana.isEmpty) return;

                    if (isEdit) {
                      notifier.updatePlayer(player.copyWith(
                        name: name,
                        yomigana: yomigana,
                        gender: selectedGender,
                      ));
                    } else {
                      notifier.addPlayer(Player(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: name,
                        yomigana: yomigana,
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
