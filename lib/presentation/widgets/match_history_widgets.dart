import 'package:flutter/material.dart';

import '../../domain/entities/game.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../notifiers/session_notifier.dart';

Color getMatchTypeColor(MatchType type) {
  switch (type) {
    case MatchType.menDoubles:
      return Colors.blue;
    case MatchType.womenDoubles:
      return Colors.pink.shade300;
    case MatchType.mixedDoubles:
      return Colors.orange.shade700;
  }
}

class GamesArea extends StatelessWidget {
  final Session session;
  final PlayerStatsPool pool;
  final double scale;
  final double screenWidth;
  final Player? selectedPlayer;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;

  const GamesArea({
    super.key,
    required this.session,
    required this.pool,
    required this.scale,
    required this.screenWidth,
    required this.selectedPlayer,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
  });

  @override
  Widget build(BuildContext context) {
    int count = session.games.length;
    int cross = count == 4
        ? (screenWidth > 850 ? 2 : 1)
        : (screenWidth > 1300 && count >= 3
            ? 3
            : (screenWidth > 800 && count >= 2 ? 2 : 1));
    final double spacing = 16.0 * scale;
    final double cardWidth = (screenWidth - (spacing * (cross + 1))) / cross;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: session.games
          .asMap()
          .entries
          .map((e) => SizedBox(
                width: cardWidth,
                child: GameCard(
                    index: e.key,
                    game: e.value,
                    pool: pool,
                    scale: scale,
                    session: session,
                    selectedPlayer: selectedPlayer,
                    onPlayerTap: onPlayerTap,
                    onPlayerLongPress: onPlayerLongPress),
              ))
          .toList(),
    );
  }
}

class GameCard extends StatelessWidget {
  final int index;
  final Game game;
  final PlayerStatsPool pool;
  final double scale;
  final Session session;
  final Player? selectedPlayer;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;

  const GameCard(
      {super.key,
      required this.index,
      required this.game,
      required this.pool,
      required this.scale,
      required this.session,
      required this.selectedPlayer,
      required this.onPlayerTap,
      required this.onPlayerLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p1Stats =
        pool.all.where((p) => p.player.id == game.teamA.player1.id).firstOrNull;
    final pairCountA = p1Stats?.stats.partnerCounts[game.teamA.player2.id] ?? 0;
    final p2Stats =
        pool.all.where((p) => p.player.id == game.teamB.player1.id).firstOrNull;
    final pairCountB = p2Stats?.stats.partnerCounts[game.teamB.player2.id] ?? 0;
    final typeColor = getMatchTypeColor(game.type);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * scale),
          side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: 1.5)),
      child: Column(children: [
        Container(
          padding:
              EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
          decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16 * scale))),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Icon(Icons.emoji_events,
                  size: 18 * scale, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('コート ${index + 1}',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w900))
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: typeColor.withValues(alpha: 0.5)),
              ),
              child: Text(game.type.displayName,
                  style: TextStyle(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w900,
                    color: typeColor,
                  )),
            ),
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(10 * scale),
          child: Row(children: [
            Expanded(
                child: TeamColumn(
                    session: session,
                    team: game.teamA,
                    pairCount: pairCountA,
                    scale: scale,
                    selectedPlayer: selectedPlayer,
                    onPlayerTap: onPlayerTap,
                    onPlayerLongPress: onPlayerLongPress)),
            _VSDivider(scale: scale),
            Expanded(
                child: TeamColumn(
                    session: session,
                    team: game.teamB,
                    pairCount: pairCountB,
                    scale: scale,
                    selectedPlayer: selectedPlayer,
                    onPlayerTap: onPlayerTap,
                    onPlayerLongPress: onPlayerLongPress)),
          ]),
        ),
      ]),
    );
  }
}

class _VSDivider extends StatelessWidget {
  final double scale;

  const _VSDivider({required this.scale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10 * scale),
      child: Column(children: [
        Text('VS',
            style: TextStyle(
                fontSize: 16 * scale,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.outline.withValues(alpha: 0.3))),
        Container(
            width: 1.5,
            height: 50 * scale,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ]),
    );
  }
}

class TeamColumn extends StatelessWidget {
  final Session session;
  final Team team;
  final int pairCount;
  final double scale;
  final Player? selectedPlayer;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;

  const TeamColumn(
      {super.key,
      required this.session,
      required this.team,
      required this.pairCount,
      required this.scale,
      required this.selectedPlayer,
      required this.onPlayerTap,
      required this.onPlayerLongPress});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      PlayerTag(
          player: team.player1,
          isSelected: selectedPlayer?.id == team.player1.id,
          onTap: () => onPlayerTap(team.player1),
          onLongPress: () => onPlayerLongPress(team.player1),
          scale: scale),
      SizedBox(height: 8 * scale),
      PlayerTag(
          player: team.player2,
          isSelected: selectedPlayer?.id == team.player2.id,
          onTap: () => onPlayerTap(team.player2),
          onLongPress: () => onPlayerLongPress(team.player2),
          scale: scale),
      const SizedBox(height: 6),
      PairInfoLabel(count: pairCount, scale: scale),
    ]);
  }
}

class RestingContainer extends StatelessWidget {
  final Session session;
  final double scale;
  final double maxWidth;
  final String? selectedPlayerId;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;

  const RestingContainer(
      {super.key,
      required this.session,
      required this.scale,
      required this.maxWidth,
      this.selectedPlayerId,
      required this.onPlayerTap,
      required this.onPlayerLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rs = (scale * 0.85).clamp(1.0, 1.5);
    final males =
        session.restingPlayers.where((p) => p.gender == Gender.male).toList();
    final females =
        session.restingPlayers.where((p) => p.gender == Gender.female).toList();

    return Container(
      width: maxWidth,
      padding: EdgeInsets.all(16 * rs),
      decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20 * rs),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('お休み中',
              style: TextStyle(
                  fontSize: 14 * rs,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(width: 12),
          _Badge(text: '計 ${session.restingPlayers.length} 名', scale: rs),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (males.isNotEmpty)
            Expanded(
                child: RestingSubSection(
                    label: '男性',
                    players: males,
                    color: Colors.blue,
                    onPlayerTap: onPlayerTap,
                    onPlayerLongPress: onPlayerLongPress,
                    selectedPlayerId: selectedPlayerId,
                    scale: rs)),
          if (males.isNotEmpty && females.isNotEmpty) SizedBox(width: 16 * rs),
          if (females.isNotEmpty)
            Expanded(
                child: RestingSubSection(
                    label: '女性',
                    players: females,
                    color: Colors.pink,
                    onPlayerTap: onPlayerTap,
                    onPlayerLongPress: onPlayerLongPress,
                    selectedPlayerId: selectedPlayerId,
                    scale: rs)),
        ]),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final double scale;

  const _Badge({required this.text, required this.scale});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10 * scale,
                color: Colors.orange,
                fontWeight: FontWeight.bold)),
      );
}

class RestingSubSection extends StatelessWidget {
  final String label;
  final List<Player> players;
  final Color color;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;
  final String? selectedPlayerId;
  final double scale;

  const RestingSubSection(
      {super.key,
      required this.label,
      required this.players,
      required this.color,
      required this.onPlayerTap,
      required this.onPlayerLongPress,
      this.selectedPlayerId,
      required this.scale});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8 * scale),
            child: Row(children: [
              Container(
                  width: 4,
                  height: 16 * scale,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w900,
                      color: color.withValues(alpha: 0.85))),
            ])),
        Wrap(
            spacing: 8 * scale,
            runSpacing: 8 * scale,
            children: players
                .map((p) => RestingChip(
                    player: p,
                    isSelected: selectedPlayerId == p.id,
                    onTap: () => onPlayerTap(p),
                    onLongPress: () => onPlayerLongPress(p),
                    scale: scale))
                .toList()),
      ]);
}

class PairInfoLabel extends StatelessWidget {
  final int count;
  final double scale;

  const PairInfoLabel({super.key, required this.count, required this.scale});

  @override
  Widget build(BuildContext context) {
    final im = count > 1;
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 2.5 * scale),
      decoration: BoxDecoration(
          color: im
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10 * scale),
          border: Border.all(
              color: im
                  ? Colors.orange.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2))),
      child: Text('ペア $count回目',
          style: TextStyle(
              fontSize: 9.5 * scale,
              color: im ? Colors.orange : Colors.grey.shade600,
              fontWeight: im ? FontWeight.w900 : FontWeight.bold)),
    );
  }
}

class RestingChip extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double scale;

  const RestingChip(
      {super.key,
      required this.player,
      required this.isSelected,
      required this.onTap,
      required this.onLongPress,
      required this.scale});

  @override
  Widget build(BuildContext context) {
    final c = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 8 * scale),
          decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orange.withValues(alpha: 0.25)
                  : c.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16 * scale),
              border: Border.all(
                  color: isSelected ? Colors.orange : c.withValues(alpha: 0.3),
                  width: 1.5)),
          child: Text(player.name,
              style: TextStyle(
                  fontSize: 14 * scale,
                  color: isSelected ? Colors.orange.shade900 : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold)),
        ));
  }
}

class PlayerTag extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double scale;

  const PlayerTag(
      {super.key,
      required this.player,
      required this.isSelected,
      required this.onTap,
      required this.onLongPress,
      required this.scale});

  @override
  Widget build(BuildContext context) {
    final c = player.gender == Gender.male ? Colors.blue : Colors.pink;
    return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onDoubleTap: onLongPress,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
              horizontal: 14 * scale, vertical: 10 * scale),
          decoration: BoxDecoration(
              color: isSelected
                  ? Colors.orange.withValues(alpha: 0.3)
                  : c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14 * scale),
              border: Border.all(
                  color: isSelected ? Colors.orange : c.withValues(alpha: 0.5),
                  width: isSelected ? 2.5 : 1.5)),
          child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(player.name,
                  style: TextStyle(
                      fontSize: 28 * scale,
                      color:
                          isSelected ? Colors.orange.shade900 : Colors.black87,
                      fontWeight: FontWeight.w900))),
        ));
  }
}

class TypeButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const TypeButton(
      {super.key,
      required this.label,
      required this.color,
      required this.onPressed});

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.1),
            foregroundColor: color,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 8)),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );
}

class MatchHistoryHeader extends StatelessWidget {
  final bool isSwapping;
  final Session? session;
  final int total;
  final int? currentIndex;
  final Player? selectedPlayer;
  final Function(int) onIndexChange;
  final VoidCallback onCancelSwap;

  const MatchHistoryHeader(
      {super.key,
      required this.isSwapping,
      this.session,
      required this.total,
      this.currentIndex,
      this.selectedPlayer,
      required this.onIndexChange,
      required this.onCancelSwap});

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return const Text('試合履歴', style: TextStyle(fontWeight: FontWeight.w900));
    }
    if (isSwapping) {
      return Row(children: [
        const Icon(Icons.swap_horizontal_circle, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(
            child: Text('${selectedPlayer!.name} と入れ替える',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis)),
        TextButton(
            onPressed: onCancelSwap,
            child: const Text('中止',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          onPressed: currentIndex! > 0
              ? () => onIndexChange(currentIndex! - 1)
              : null),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('第 ${session!.index} 試合',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text('$total 試合中',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
      IconButton(
          icon: const Icon(Icons.chevron_right, size: 32),
          onPressed: currentIndex! < total - 1
              ? () => onIndexChange(currentIndex! + 1)
              : null),
    ]);
  }
}

class MatchSettingsDialog extends StatefulWidget {
  final SessionNotifier notifier;
  final bool isRecalc;
  final Session? currentSession;

  const MatchSettingsDialog(
      {super.key,
      required this.notifier,
      required this.isRecalc,
      this.currentSession});

  @override
  State<MatchSettingsDialog> createState() => _MatchSettingsDialogState();
}

class _MatchSettingsDialogState extends State<MatchSettingsDialog> {
  List<MatchType> types = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.notifier.getCurrentSettings();
    if (!mounted) return;
    setState(() {
      if (widget.isRecalc && widget.currentSession != null) {
        types = widget.currentSession!.games.map((g) => g.type).toList();
      } else {
        types = List.from(s.matchTypes);
      }
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    final res = widget.notifier.checkRequirements(types);
    return AlertDialog(
      title: Text(widget.isRecalc ? '試合の再生成' : '試合の設定'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          TypeButton(
              label: '男子W',
              color: Colors.blue,
              onPressed: () => setState(() => types.add(MatchType.menDoubles))),
          TypeButton(
              label: '女子W',
              color: Colors.pink.shade300,
              onPressed: () =>
                  setState(() => types.add(MatchType.womenDoubles))),
          TypeButton(
              label: '混合W',
              color: Colors.orange.shade700,
              onPressed: () =>
                  setState(() => types.add(MatchType.mixedDoubles))),
        ]),
        const Divider(height: 32),
        Wrap(
            spacing: 8,
            children: types.asMap().entries.map((e) {
              final color = getMatchTypeColor(e.value);
              return Chip(
                label: Text(e.value.displayName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                backgroundColor: color.withValues(alpha: 0.1),
                side: BorderSide(color: color.withValues(alpha: 0.3)),
                onDeleted: () => setState(() => types.removeAt(e.key)),
                deleteIconColor: color.withValues(alpha: 0.7),
              );
            }).toList()),
        if (!res.canGenerate && types.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(res.errorMessage ?? '',
                style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル')),
        ElevatedButton(
          onPressed: !res.canGenerate || types.isEmpty
              ? null
              : () => Navigator.pop(context, types),
          child: Text(widget.isRecalc ? '再生成' : '生成'),
        ),
      ],
    );
  }
}
