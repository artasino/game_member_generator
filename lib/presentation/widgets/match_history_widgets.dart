import 'package:flutter/material.dart';
import 'package:game_member_generator/config/app_config.dart';

import '../../domain/entities/court_settings.dart';
import '../../domain/entities/game.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats_pool.dart';
import '../../domain/entities/session.dart';
import '../../domain/entities/team.dart';
import '../notifiers/session_notifier.dart';
import 'common_widgets.dart';

/// 試合形式に応じたテーマカラーを取得
Color _getMatchTypeColor(BuildContext context, MatchType type) {
  return switch (type) {
    MatchType.menDoubles => Colors.blue.shade800,
    MatchType.womenDoubles => Colors.pink.shade700,
    MatchType.mixedDoubles => Colors.orange.shade900,
  };
}

class GamesArea extends StatelessWidget {
  final Session session;
  final PlayerStatsPool pool;
  final double scale;
  final double screenWidth;
  final Player? selectedPlayer;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;
  final bool showPairInfo;

  const GamesArea({
    super.key,
    required this.session,
    required this.pool,
    required this.scale,
    required this.screenWidth,
    required this.selectedPlayer,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
    this.showPairInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final int count = session.games.length;

    int cross;
    if (screenWidth < 500 * scale) {
      cross = 1;
    } else if (count == 4) {
      cross = 2;
    } else if (count == 3) {
      cross = 3;
    } else {
      final double minCardWidth = 360 * scale;
      cross = (screenWidth / minCardWidth).floor().clamp(1, 3);
      if (count < cross) cross = count;
    }

    final double spacing = 16.0 * scale;
    final double cardWidth = (screenWidth - (spacing * (cross + 1))) / cross;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: session.games.asMap().entries.map((e) {
        return SizedBox(
          width: cardWidth.clamp(0, screenWidth),
          child: GameCard(
            index: e.key,
            game: e.value,
            pool: pool,
            scale: scale,
            session: session,
            selectedPlayer: selectedPlayer,
            onPlayerTap: onPlayerTap,
            onPlayerLongPress: onPlayerLongPress,
            showPairInfo: showPairInfo,
          ),
        );
      }).toList(),
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
  final bool showPairInfo;

  const GameCard({
    super.key,
    required this.index,
    required this.game,
    required this.pool,
    required this.scale,
    required this.session,
    required this.selectedPlayer,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
    this.showPairInfo = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final p1Stats =
        pool.all.where((p) => p.player.id == game.teamA.player1.id).firstOrNull;
    final pairCountA = p1Stats?.stats.partnerCounts[game.teamA.player2.id] ?? 0;
    final p2Stats =
        pool.all.where((p) => p.player.id == game.teamB.player1.id).firstOrNull;
    final pairCountB = p2Stats?.stats.partnerCounts[game.teamB.player2.id] ?? 0;

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * scale),
        side: BorderSide(color: colorScheme.outlineVariant, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 14 * scale, vertical: 8 * scale),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              border: Border(
                  bottom:
                      BorderSide(color: colorScheme.outlineVariant, width: 2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 16 * scale,
                  backgroundColor: colorScheme.primary,
                  child: Text('${index + 1}',
                      style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.bold)),
                ),
                AppBadge(
                    label: game.type.displayName,
                    color: _getMatchTypeColor(context, game.type),
                    isFilled: true,
                    scale: scale),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12 * scale),
            child: Row(
              children: [
                Expanded(
                    child: TeamColumn(
                        team: game.teamA,
                        pairCount: pairCountA,
                        scale: scale,
                        selectedPlayer: selectedPlayer,
                        onPlayerTap: onPlayerTap,
                        onPlayerLongPress: onPlayerLongPress,
                        showPairInfo: showPairInfo)),
                _VSDivider(scale: scale),
                Expanded(
                    child: TeamColumn(
                        team: game.teamB,
                        pairCount: pairCountB,
                        scale: scale,
                        selectedPlayer: selectedPlayer,
                        onPlayerTap: onPlayerTap,
                        onPlayerLongPress: onPlayerLongPress,
                        showPairInfo: showPairInfo)),
              ],
            ),
          ),
        ],
      ),
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
      child: Column(
        children: [
          Text('VS',
              style: TextStyle(
                  fontSize: 18 * scale,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.outline.withValues(alpha: 0.4))),
          Container(
              width: 2,
              height: 60 * scale,
              color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}

class TeamColumn extends StatelessWidget {
  final Team team;
  final int pairCount;
  final double scale;
  final Player? selectedPlayer;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;
  final bool showPairInfo;

  const TeamColumn(
      {super.key,
      required this.team,
      required this.pairCount,
      required this.scale,
      this.selectedPlayer,
      required this.onPlayerTap,
      required this.onPlayerLongPress,
      required this.showPairInfo});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlayerTag(
            player: team.player1,
            isSelected: selectedPlayer?.id == team.player1.id,
            onTap: () => onPlayerTap(team.player1),
            onLongPress: () => onPlayerLongPress(team.player1),
            scale: scale),
        const SizedBox(height: 8),
        PlayerTag(
            player: team.player2,
            isSelected: selectedPlayer?.id == team.player2.id,
            onTap: () => onPlayerTap(team.player2),
            onLongPress: () => onPlayerLongPress(team.player2),
            scale: scale),
        if (showPairInfo && pairCount > 0) ...[
          const SizedBox(height: 6),
          PairInfoLabel(count: pairCount, scale: scale),
        ],
      ],
    );
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
    final theme = Theme.of(context);
    final genderColor = GenderTheme.getColor(player.gender);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12 * scale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        width: double.infinity,
        height: 60 * scale,
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : genderColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : genderColor.withValues(alpha: 0.4),
              width: isSelected ? 3 : 1.5),
        ),
        child: Text(player.name,
            style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.w900,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : Colors.black87)),
      ),
    );
  }
}

class RestingContainer extends StatelessWidget {
  final Session session;
  final PlayerStatsPool pool;
  final double scale;
  final double maxWidth;
  final String? selectedPlayerId;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;

  const RestingContainer(
      {super.key,
      required this.session,
      required this.pool,
      required this.scale,
      required this.maxWidth,
      this.selectedPlayerId,
      required this.onPlayerTap,
      required this.onPlayerLongPress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedResting = List<Player>.from(session.restingPlayers)
      ..sort((a, b) => a.gender == b.gender
          ? a.name.compareTo(b.name)
          : (a.gender == Gender.male ? -1 : 1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined,
                  size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text('休憩中 (${session.restingPlayers.length}名)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedResting
                .map((p) => RestingChip(
                      player: p,
                      isSelected: selectedPlayerId == p.id,
                      consecutiveRests: pool.all
                          .firstWhere((ps) => ps.player.id == p.id)
                          .stats
                          .consecutiveRests,
                      onTap: () => onPlayerTap(p),
                      onLongPress: () => onPlayerLongPress(p),
                      scale: scale,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class RestingChip extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final int consecutiveRests;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double scale;

  const RestingChip(
      {super.key,
      required this.player,
      required this.isSelected,
      required this.consecutiveRests,
      required this.onTap,
      required this.onLongPress,
      required this.scale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = GenderTheme.getColor(player.gender);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (consecutiveRests >= 2) ...[
              Icon(Icons.bedtime, size: 14, color: color),
              const SizedBox(width: 4)
            ],
            Text(player.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : Colors.black87)),
          ],
        ),
      ),
    );
  }
}

class PairInfoLabel extends StatelessWidget {
  final int count;
  final double scale;

  const PairInfoLabel({super.key, required this.count, required this.scale});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
        label: '$count',
        color: count > 1 ? Colors.orange.shade700 : Colors.grey,
        icon: Icons.people_alt_outlined,
        scale: scale);
  }
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
    if (isSwapping) {
      return Row(children: [
        const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
        const SizedBox(width: 8),
        Expanded(
            child: Text('入れ替え対象: ${selectedPlayer?.name}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16))),
        TextButton(
            onPressed: onCancelSwap,
            child: const Text('キャンセル', style: TextStyle(color: Colors.white))),
      ]);
    }
    if (session == null) {
      return const Text('HISTORY',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: currentIndex! > 0
                ? () => onIndexChange(currentIndex! - 1)
                : null),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('MATCH ${session!.index}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
          Text('$total 試合中 ${currentIndex! + 1} 試合目',
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
        IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: currentIndex! < total - 1
                ? () => onIndexChange(currentIndex! + 1)
                : null),
      ],
    );
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
  bool isAutoRecommendEnabled = false;
  int autoCourtCount = 2;
  AutoCourtPolicy autoCourtPolicy = AutoCourtPolicy.balance;
  RequirementResult? _requirementResult;

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
        isAutoRecommendEnabled = false;
      } else {
        types = List.from(s.matchTypes);
        autoCourtCount = s.autoCourtCount;
        autoCourtPolicy = s.autoCourtPolicy;
        isAutoRecommendEnabled = AppConfig.autoRecommendEnabled;
      }
      loading = false;
      _updateRequirement();
    });
  }

  void _updateRequirement() {
    final selectedTypes = isAutoRecommendEnabled ? _buildAutoTypes() : types;
    setState(() {
      _requirementResult = widget.notifier.checkRequirements(selectedTypes);
    });
  }

  bool _checkRequirementWithAddType(MatchType type) {
    var selectedTypes = isAutoRecommendEnabled ? _buildAutoTypes() : types;
    List<MatchType> newTypes = List.from(selectedTypes);
    newTypes.add(type);
    return widget.notifier.checkRequirements(newTypes).canGenerate;
  }

  List<MatchType> _buildAutoTypes() {
    return List<MatchType>.generate(autoCourtCount, (index) {
      switch (autoCourtPolicy) {
        case AutoCourtPolicy.genderSeparated:
          return index.isEven ? MatchType.menDoubles : MatchType.womenDoubles;
        case AutoCourtPolicy.balance:
          if (index == autoCourtCount - 1 && autoCourtCount.isOdd) {
            return MatchType.mixedDoubles;
          }
          return index.isEven ? MatchType.menDoubles : MatchType.womenDoubles;
        case AutoCourtPolicy.mix:
          return MatchType.mixedDoubles;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    final res =
        _requirementResult ?? const RequirementResult(canGenerate: true);
    final theme = Theme.of(context);
    final selectedTypes = isAutoRecommendEnabled ? _buildAutoTypes() : types;
    final pool = widget.notifier.playerStatsPool;
    final activeMale = pool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.male)
        .length;
    final activeFemale = pool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.female)
        .length;

    return AlertDialog(
      title: const Text('MATCH SETTINGS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _CompactBadge(
                  label: '男性: $activeMale 名', color: Colors.blue.shade700),
              const SizedBox(width: 12),
              _CompactBadge(
                  label: '女性: $activeFemale 名', color: Colors.pink.shade600),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            if (AppConfig.autoRecommendEnabled) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('自動'),
                      icon: Icon(Icons.auto_awesome)),
                  ButtonSegment(
                      value: false,
                      label: Text('手動'),
                      icon: Icon(Icons.touch_app))
                ],
                selected: {isAutoRecommendEnabled},
                onSelectionChanged: (val) {
                  setState(() => isAutoRecommendEnabled = val.first);
                  _updateRequirement();
                },
              ),
              const SizedBox(height: 20),
              if (isAutoRecommendEnabled) _buildAutoSettingsSection(),
            ],
            if (!isAutoRecommendEnabled) _buildManualSettingsSection(context),
            if (!res.canGenerate && selectedTypes.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(res.errorMessage ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 13))),
            if (res.canGenerate &&
                selectedTypes.isNotEmpty &&
                res.predictedRestPlayerNames.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                      '同時出場制限による選外候補:\n${res.predictedRestPlayerNames.join(', ')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))),
          ],
        ),
      ),
      actions: [
        AppActionButton(
            label: 'キャンセル',
            onPressed: () => Navigator.pop(context),
            isPrimary: false),
        AppActionButton(
            label: 'スタート',
            onPressed: !res.canGenerate || selectedTypes.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    CourtSettings(selectedTypes,
                        autoCourtCount: autoCourtCount,
                        autoCourtPolicy: autoCourtPolicy)),
            isPrimary: true),
      ],
    );
  }

  Widget _buildAutoSettingsSection() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('コート数', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        DropdownButton<int>(
            value: autoCourtCount,
            items: List.generate(6, (i) => i + 1)
                .map((c) => DropdownMenuItem(value: c, child: Text('$c 面')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => autoCourtCount = v);
              _updateRequirement();
            }),
      ]),
      const SizedBox(height: 12),
      const Text('生成ポリシー', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SegmentedButton<AutoCourtPolicy>(
          segments: AutoCourtPolicy.values
              .map((p) => ButtonSegment(value: p, label: Text(p.displayName)))
              .toList(),
          selected: {autoCourtPolicy},
          onSelectionChanged: (val) {
            setState(() => autoCourtPolicy = val.first);
            _updateRequirement();
          }),
    ]);
  }

  Widget _buildManualSettingsSection(BuildContext context) {
    return Column(children: [
      const Text('形式を選択', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: MatchType.values
              .map((type) => ActionChip(
                  label: Text(type.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _checkRequirementWithAddType(type)
                      ? () {
                          setState(() {
                            types.add(type);
                          });
                          _updateRequirement();
                        }
                      : null,
                  avatar: Icon(Icons.add,
                      size: 18, color: _getMatchTypeColor(context, type)),
                  side: BorderSide(color: _getMatchTypeColor(context, type))))
              .toList()),
      const SizedBox(height: 20),
      if (types.isNotEmpty)
        Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: types
                .asMap()
                .entries
                .map((e) => InputChip(
                    label: Text(e.value.displayName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    onDeleted: () {
                      setState(() => types.removeAt(e.key));
                      _updateRequirement();
                    },
                    deleteIconColor: Colors.white,
                    backgroundColor: _getMatchTypeColor(context, e.value),
                    side: BorderSide.none))
                .toList()),
    ]);
  }
}

class _CompactBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CompactBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}
