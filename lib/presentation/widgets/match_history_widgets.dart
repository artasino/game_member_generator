import 'package:flutter/material.dart';
import 'package:game_member_generator/config/app_config.dart';

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

    // 列数の決定
    int cross;
    if (count == 4) {
      cross = 2; // 4試合のときは2x2
    } else if (count == 3) {
      cross = 3; // 3試合のときは横に3つ
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

    final typeColor = _getMatchTypeColor(context, game.type);

    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16 * scale),
        side: BorderSide(color: colorScheme.outlineVariant, width: 2),
      ),
      color: colorScheme.surface,
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
                Row(
                  children: [
                    SizedBox(width: 8 * scale),
                    CircleAvatar(
                      radius: 16 * scale,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                AppBadge(
                  label: game.type.displayName,
                  color: typeColor,
                  isFilled: true,
                  scale: scale,
                ),
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
                    showPairInfo: showPairInfo,
                  ),
                ),
                _VSDivider(scale: scale),
                Expanded(
                  child: TeamColumn(
                    team: game.teamB,
                    pairCount: pairCountB,
                    scale: scale,
                    selectedPlayer: selectedPlayer,
                    onPlayerTap: onPlayerTap,
                    onPlayerLongPress: onPlayerLongPress,
                    showPairInfo: showPairInfo,
                  ),
                ),
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

  const TeamColumn({
    super.key,
    required this.team,
    required this.pairCount,
    required this.scale,
    required this.selectedPlayer,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
    required this.showPairInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlayerTag(
          player: team.player1,
          isSelected: selectedPlayer?.id == team.player1.id,
          onTap: () => onPlayerTap(team.player1),
          onLongPress: () => onPlayerLongPress(team.player1),
          scale: scale,
        ),
        SizedBox(height: 8 * scale),
        PlayerTag(
          player: team.player2,
          isSelected: selectedPlayer?.id == team.player2.id,
          onTap: () => onPlayerTap(team.player2),
          onLongPress: () => onPlayerLongPress(team.player2),
          scale: scale,
        ),
        if (showPairInfo && pairCount > 0) ...[
          SizedBox(height: 6 * scale),
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

  const PlayerTag({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final genderColor = GenderTheme.getColor(player.gender);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onLongPress,
      borderRadius: BorderRadius.circular(12 * scale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        width: double.infinity,
        height: 64 * scale,
        padding: EdgeInsets.symmetric(horizontal: 10 * scale),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : genderColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : genderColor.withValues(alpha: 0.4),
            width: isSelected ? 3.0 : 1.5,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            player.name,
            style: TextStyle(
                fontSize: 32 * scale,
                color:
                    isSelected ? colorScheme.onPrimaryContainer : Colors.black,
                fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class RestingContainer extends StatelessWidget {
  final Session session;
  final double scale;
  final double maxWidth;
  final String? selectedPlayerId;
  final Function(Player) onPlayerTap;
  final Function(Player) onPlayerLongPress;
  final PlayerStatsPool pool;

  const RestingContainer({
    super.key,
    required this.session,
    required this.scale,
    required this.maxWidth,
    this.selectedPlayerId,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
    required this.pool,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rs = scale.clamp(0.8, 1.2);

    // 休憩中メンバーを男女でソート
    final sortedResting = List<Player>.from(session.restingPlayers)
      ..sort((a, b) {
        // Gender.male を先、Gender.female を後に
        if (a.gender == b.gender) return a.name.compareTo(b.name);
        return a.gender == Gender.male ? -1 : 1;
      });

    // 試合に出ているプレイヤーのIDセット
    final activePlayerIds = session.games
        .expand((g) => [
              g.teamA.player1.id,
              g.teamA.player2.id,
              g.teamB.player1.id,
              g.teamB.player2.id
            ])
        .toSet();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8 * rs, horizontal: 16 * rs),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
            top: BorderSide(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bedtime_outlined,
                  size: 14 * rs, color: theme.colorScheme.secondary),
              SizedBox(width: 6 * rs),
              Text('休憩中',
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.secondary,
                      fontSize: 12 * rs)),
              SizedBox(width: 10 * rs),
              AppBadge(
                label: '${session.restingPlayers.length} 名',
                color: theme.colorScheme.secondary,
                isFilled: true,
                scale: rs,
              ),
            ],
          ),
          SizedBox(height: 6 * rs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sortedResting.map((p) {
                // ペアが試合に出ているために自分が休んでいるか判定
                final partnerId = p.excludedPartnerId;
                final isConflictRest =
                    partnerId != null && activePlayerIds.contains(partnerId);

                return Padding(
                  padding: EdgeInsets.only(right: 8 * rs),
                  child: RestingChip(
                    player: p,
                    isSelected: selectedPlayerId == p.id,
                    consecutiveRests:
                        pool.getPlayer(p.id).stats.consecutiveRests,
                    isConflictRest: isConflictRest,
                    onTap: () => onPlayerTap(p),
                    onLongPress: () => onPlayerLongPress(p),
                    onDoubleTap: () => onPlayerLongPress(p),
                    scale: rs,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class RestingChip extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final double scale;
  final int consecutiveRests;
  final bool isConflictRest;

  const RestingChip({
    super.key,
    required this.player,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.scale,
    required this.consecutiveRests,
    this.isConflictRest = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genderColor = GenderTheme.getColor(player.gender);
    final isConsecutive = consecutiveRests >= 2;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 4 * scale),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : (isConsecutive
                  ? genderColor.withValues(alpha: 0.15)
                  : genderColor.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isConsecutive
                      ? genderColor.withValues(alpha: 0.6)
                      : genderColor.withValues(alpha: 0.3)),
              width: isConsecutive ? 2.5 : 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConflictRest) ...[
              Icon(Icons.child_care,
                  size: 16 * scale, color: Colors.orange.shade800),
              SizedBox(width: 6 * scale),
            ],
            if (isConsecutive) ...[
              Icon(Icons.bedtime, size: 16 * scale, color: genderColor),
              const SizedBox(width: 2),
              Text(
                '$consecutiveRests',
                style: TextStyle(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w900,
                  color: genderColor,
                ),
              ),
              SizedBox(width: 6 * scale),
            ],
            Text(
              player.name,
              style: TextStyle(
                  fontSize: 18 * scale,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : Colors.black87,
                  fontWeight: FontWeight.w900),
            ),
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
    final theme = Theme.of(context);
    final isFrequent = count > 1;
    return AppBadge(
      label: '$count',
      color: isFrequent ? Colors.orange.shade700 : theme.colorScheme.outline,
      icon: Icons.people_alt_outlined,
      scale: scale,
    );
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

  const MatchHistoryHeader({
    super.key,
    required this.isSwapping,
    this.session,
    required this.total,
    this.currentIndex,
    this.selectedPlayer,
    required this.onIndexChange,
    required this.onCancelSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (session == null) {
      return Text('HISTORY',
          style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: colorScheme.onPrimary));
    }

    if (isSwapping) {
      return Row(
        children: [
          Icon(Icons.swap_horiz_rounded,
              color: colorScheme.onPrimary, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'SWAP: ${selectedPlayer!.name}',
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary, fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppActionButton(
            label: 'キャンセル',
            onPressed: onCancelSwap,
            isPrimary: false,
            color: colorScheme.onPrimary,
          ),
        ],
      );
    }

    final bool canGoBack = currentIndex! > 0;
    final bool canGoForward = currentIndex! < total - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 56,
            color: canGoBack
                ? colorScheme.onPrimary
                : colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
          onPressed: canGoBack ? () => onIndexChange(currentIndex! - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MATCH ${session!.index}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: colorScheme.onPrimary,
                ),
              ),
              Text(
                'HISTORY: $total',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 56,
            color: canGoForward
                ? colorScheme.onPrimary
                : colorScheme.onPrimary.withValues(alpha: 0.3),
          ),
          onPressed:
              canGoForward ? () => onIndexChange(currentIndex! + 1) : null,
        ),
      ],
    );
  }
}

class MatchSettingsDialog extends StatefulWidget {
  final SessionNotifier notifier;
  final bool isRecalc;
  final Session? currentSession;

  const MatchSettingsDialog({
    super.key,
    required this.notifier,
    required this.isRecalc,
    this.currentSession,
  });

  @override
  State<MatchSettingsDialog> createState() => _MatchSettingsDialogState();
}

class _MatchSettingsDialogState extends State<MatchSettingsDialog> {
  List<MatchType> types = [];
  bool loading = true;
  bool isAutoRecommendEnabled = false; // デフォルトは自動選択

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
      }
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    final res = widget.notifier.checkRequirements(types);
    final theme = Theme.of(context);

    // アクティブ人数のカウント
    final activeMale = widget.notifier.playerStatsPool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.male);
    final activeMaleLen = activeMale.length;
    final mustRestMaleLen = activeMale.where((p) => p.player.isMustRest).length;
    final activeFemale = widget.notifier.playerStatsPool.all
        .where((p) => p.player.isActive && p.player.gender == Gender.female);
    final activeFemaleLen = activeFemale.length;
    final mustRestFemaleLen =
        activeFemale.where((p) => p.player.isMustRest).length;

    return AlertDialog(
      title: Text('MATCH SETTINGS',
          style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: theme.colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 現在の参加人数表示
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CompactGenderBadge(
                  label: '男性: $activeMaleLen 名(休$mustRestMaleLen）',
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                _CompactGenderBadge(
                  label: '女性: $activeFemaleLen 名(休$mustRestFemaleLen）',
                  color: Colors.pink.shade600,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            if (AppConfig.autoRecommendEnabled) ...[
              // 自動・手動切り替え
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('自動選択'),
                      icon: Icon(Icons.auto_awesome)),
                  ButtonSegment(
                      value: false,
                      label: Text('手動選択'),
                      icon: Icon(Icons.touch_app)),
                ],
                selected: {isAutoRecommendEnabled},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    isAutoRecommendEnabled = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isAutoRecommendEnabled ? 0.5 : 1.0,
              child: IgnorePointer(
                ignoring: isAutoRecommendEnabled,
                child: Column(
                  children: [
                    const Text('Select match types for each court',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: MatchType.values.map((type) {
                        final color = _getMatchTypeColor(context, type);
                        return ActionChip(
                          label: Text(type.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                          onPressed: () => setState(() => types.add(type)),
                          avatar: Icon(Icons.add, size: 20, color: color),
                          side: BorderSide(color: color, width: 2.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        );
                      }).toList(),
                    ),
                    const Divider(height: 48, thickness: 2.5),
                    if (types.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('EMPTY',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w900)),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: types.asMap().entries.map((e) {
                          final color = _getMatchTypeColor(context, e.value);
                          return InputChip(
                            label: Text(e.value.displayName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                            onDeleted: () =>
                                setState(() => types.removeAt(e.key)),
                            deleteIconColor: Colors.white,
                            backgroundColor: color,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),

            if (!res.canGenerate && types.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  res.errorMessage ?? '',
                  style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
      ),
      actions: [
        AppActionButton(
          label: 'キャンセル',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        AppActionButton(
          label: 'スタート',
          onPressed: !res.canGenerate || types.isEmpty
              ? null
              : () => Navigator.pop(context, types),
          isPrimary: true,
        ),
      ],
    );
  }
}

class _CompactGenderBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _CompactGenderBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
