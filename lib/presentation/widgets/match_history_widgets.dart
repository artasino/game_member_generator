import 'dart:math';
import 'dart:ui';

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
import '../../domain/services/match_requirement_service.dart';
import '../notifiers/session_notifier.dart';
import 'common_widgets.dart';

class MatchHistoryLayoutTokens {
  const MatchHistoryLayoutTokens._();

  static const int maxColumns = 3;
  static const double contentHorizontalPadding = 32;
  static const double minCardWidthBase = 280;
  static const double minCardWidthLarge = 380;
  static const double maxCardWidthBase = 520;
  static const double maxCardWidthLarge = 620;
  static const double twoColumnBreakpoint = 760;
  static const double threeColumnBreakpoint = 1120;
  static const double compactPlayerTagWidth = 180;
  static const double tightPlayerTagWidth = 145;
  static const int longNameWarningLength = 8;
  static const double extremeNarrowWidth = 560;
  static const double extremeWideWidth = 1600;
}

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
    final double spacing = 16.0 * scale;
    final int cross = _calculateCrossAxisCount(count, spacing);
    final double cardWidth =
        _calculateCardWidth(cross, spacing).clamp(0, _maxCardWidth);
    _logLayoutMetrics(gameCount: count, columns: cross, cardWidth: cardWidth);

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

  int _calculateCrossAxisCount(int gameCount, double spacing) {
    if (gameCount <= 1 || screenWidth <= 0) return 1;

    if (screenWidth < MatchHistoryLayoutTokens.twoColumnBreakpoint) return 1;
    if (screenWidth < MatchHistoryLayoutTokens.threeColumnBreakpoint) {
      return min(gameCount, 2);
    }

    final double minCardWidth = _minCardWidth;
    final int maxColumns = min(gameCount, MatchHistoryLayoutTokens.maxColumns);

    for (int columns = maxColumns; columns >= 1; columns--) {
      if (_calculateCardWidth(columns, spacing) >= minCardWidth) {
        return columns;
      }
    }
    return 1;
  }

  double _calculateCardWidth(int crossAxisCount, double spacing) {
    final double totalSpacing = spacing * max(crossAxisCount - 1, 0);
    final double availableWidth = max(screenWidth - totalSpacing, 0);
    return availableWidth / crossAxisCount;
  }

  double get _minCardWidth {
    final double t = ((scale - 1.0) / 0.8).clamp(0.0, 1.0);
    return lerpDouble(
      MatchHistoryLayoutTokens.minCardWidthBase,
      MatchHistoryLayoutTokens.minCardWidthLarge,
      t,
    )!;
  }

  double get _maxCardWidth {
    final double t = ((scale - 1.0) / 0.8).clamp(0.0, 1.0);
    return lerpDouble(
      MatchHistoryLayoutTokens.maxCardWidthBase,
      MatchHistoryLayoutTokens.maxCardWidthLarge,
      t,
    )!;
  }

  void _logLayoutMetrics({
    required int gameCount,
    required int columns,
    required double cardWidth,
  }) {
    final bool shouldLog =
        screenWidth <= MatchHistoryLayoutTokens.extremeNarrowWidth ||
        screenWidth >= MatchHistoryLayoutTokens.extremeWideWidth;
    if (!shouldLog) return;

    assert(() {
      debugPrint(
        '[GamesArea] width=${screenWidth.toStringAsFixed(1)} '
        'games=$gameCount columns=$columns cardWidth=${cardWidth.toStringAsFixed(1)} '
        'scale=${scale.toStringAsFixed(2)}',
      );
      return true;
    }());
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
          _buildHeader(context, colorScheme),
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

  Widget _buildHeader(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
            bottom: BorderSide(color: colorScheme.outlineVariant, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleAvatar(
            radius: 16 * scale,
            backgroundColor: colorScheme.primary,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 18 * scale,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          AppBadge(
            label: game.type.displayName,
            color: _getMatchTypeColor(context, game.type),
            isFilled: true,
            scale: scale,
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
          Text(
            'VS',
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
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
    this.selectedPlayer,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
    required this.showPairInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPlayerTag(team.player1),
        const SizedBox(height: 8),
        _buildPlayerTag(team.player2),
        if (showPairInfo && pairCount > 0) ...[
          const SizedBox(height: 6),
          PairInfoLabel(count: pairCount, scale: scale),
        ],
      ],
    );
  }

  Widget _buildPlayerTag(Player player) {
    return PlayerTag(
      player: player,
      isSelected: selectedPlayer?.id == player.id,
      onTap: () => onPlayerTap(player),
      onLongPress: () => onPlayerLongPress(player),
      scale: scale,
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
              : genderColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12 * scale),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : genderColor.withOpacity(0.4),
            width: isSelected ? 3 : 1.5,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = _adaptivePlayerTextScale(constraints.maxWidth);
            _logNameTuning(constraints.maxWidth);
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 24 * scale * textScale,
                  fontWeight: FontWeight.w900,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : Colors.black87,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _adaptivePlayerTextScale(double maxWidth) {
    if (maxWidth <= MatchHistoryLayoutTokens.tightPlayerTagWidth) return 0.62;
    if (maxWidth <= MatchHistoryLayoutTokens.compactPlayerTagWidth) {
      return 0.75;
    }
    return 1.0;
  }

  void _logNameTuning(double tagWidth) {
    final int nameLength = player.name.runes.length;
    if (nameLength < MatchHistoryLayoutTokens.longNameWarningLength) {
      return;
    }
    if (tagWidth > MatchHistoryLayoutTokens.compactPlayerTagWidth) return;
    assert(() {
      debugPrint(
        '[PlayerTag] compact tag width=${tagWidth.toStringAsFixed(1)} '
        'name="${player.name}" len=$nameLength',
      );
      return true;
    }());
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

  const RestingContainer({
    super.key,
    required this.session,
    required this.pool,
    required this.scale,
    required this.maxWidth,
    this.selectedPlayerId,
    required this.onPlayerTap,
    required this.onPlayerLongPress,
  });

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
              Text(
                '休憩中 (${session.restingPlayers.length}名)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary),
              ),
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

  const RestingChip({
    super.key,
    required this.player,
    required this.isSelected,
    required this.consecutiveRests,
    required this.onTap,
    required this.onLongPress,
    required this.scale,
  });

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
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (consecutiveRests >= 2) ...[
              Icon(Icons.bedtime, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              player.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : Colors.black87,
              ),
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
    return AppBadge(
      label: '$count',
      color: count > 1 ? Colors.orange.shade700 : Colors.grey,
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
    if (isSwapping) {
      return Row(children: [
        const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '入れ替え対象: ${selectedPlayer?.name}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
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
          onPressed:
              currentIndex! > 0 ? () => onIndexChange(currentIndex! - 1) : null,
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'MATCH ${session!.index}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            '$total 試合中 ${currentIndex! + 1} 試合目',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ]),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: currentIndex! < total - 1
              ? () => onIndexChange(currentIndex! + 1)
              : null,
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
  List<MatchType> currentRecommendTypes = [];
  bool loading = true;
  bool isAutoRecommendMode = false;
  int autoCourtCount = 3;
  AutoCourtPolicy autoCourtPolicy = AutoCourtPolicy.balance;
  RequirementResult? _requirementResult;
  final MatchRequirementService _requirementService =
      const MatchRequirementService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await widget.notifier.getCurrentSettings();
    if (!mounted) return;

    final initialTypes = (widget.isRecalc && widget.currentSession != null)
        ? widget.currentSession!.games.map((g) => g.type).toList()
        : List<MatchType>.from(s.matchTypes);

    setState(() {
      types = initialTypes;
      if (!(widget.isRecalc && widget.currentSession != null)) {
        autoCourtCount = s.autoCourtCount;
        autoCourtPolicy = s.autoCourtPolicy;
        isAutoRecommendMode = s.isAutoRecommendMode;
      } else {
        isAutoRecommendMode = false;
      }
      loading = false;
    });

    _updateRequirement();
  }

  void _updateRequirement() {
    final selectedTypes = isAutoRecommendMode ? _calculateAutoTypes() : types;
    setState(() {
      _requirementResult = widget.notifier.checkRequirements(selectedTypes);
      if (isAutoRecommendMode) {
        currentRecommendTypes = selectedTypes;
      }
    });
  }

  bool _checkRequirementWithAddType(MatchType type) {
    var selectedTypes = isAutoRecommendMode ? _calculateAutoTypes() : types;
    List<MatchType> newTypes = List.from(selectedTypes);
    newTypes.add(type);
    return widget.notifier.checkRequirements(newTypes).canGenerate;
  }

  List<MatchType> _calculateAutoTypes() {
    final pool = widget.notifier.playerStatsPool;
    final effective = _requirementService.calculateEffectiveCounts(pool);

    Map<Gender, int> genderHistory =
        widget.notifier.getGenderParticipationTotalCounts();
    var maleGameCount = genderHistory[Gender.male] ?? 0;
    var femaleGameCount = genderHistory[Gender.female] ?? 0;

    int maxMaleDoublesNumPossible =
        min((effective.male / 4).floor(), autoCourtCount);
    int maxFemaleDoublesNumPossible =
        min((effective.female / 4).floor(), autoCourtCount);
    int maxMixNumPossible = min(
        min((effective.male / 2).floor(), (effective.female / 2).floor()),
        autoCourtCount);

    switch (autoCourtPolicy) {
      case AutoCourtPolicy.genderSeparated:
        return _recommendGenderSeparated(
          effective.male,
          effective.female,
          maleGameCount,
          femaleGameCount,
          maxMaleDoublesNumPossible,
          maxFemaleDoublesNumPossible,
        );
      case AutoCourtPolicy.mix:
        return List.filled(maxMixNumPossible, MatchType.mixedDoubles);
      case AutoCourtPolicy.balance:
        return _recommendBalanced(
          effective.male,
          effective.female,
          maleGameCount,
          femaleGameCount,
          maxMaleDoublesNumPossible,
          maxFemaleDoublesNumPossible,
          maxMixNumPossible,
        );
    }
  }

  List<MatchType> _recommendGenderSeparated(
      double m, double f, int mg, int fg, int maxM, int maxF) {
    double minScore = double.infinity;
    List<MatchType> result = [];
    for (int md = 0; md <= maxM; md++) {
      for (int wd = 0; wd <= maxF; wd++) {
        if (md + wd != autoCourtCount) continue;
        double score = pow((mg + md * 4) / m - (fg + wd * 4) / f, 2).toDouble();
        if (score < minScore) {
          minScore = score;
          result = [
            ...List.filled(md, MatchType.menDoubles),
            ...List.filled(wd, MatchType.womenDoubles)
          ];
        }
      }
    }
    return result;
  }

  List<MatchType> _recommendBalanced(
      double m, double f, int mg, int fg, int maxM, int maxF, int maxMix) {
    double minScore = double.infinity;
    List<MatchType> result = [];
    for (int mix = 0; mix <= maxMix; mix++) {
      for (int md = 0; md <= maxM; md++) {
        for (int wd = 0; wd <= maxF; wd++) {
          if (md + wd + mix != autoCourtCount) continue;
          double score =
              pow((mg + md * 4 + mix * 2) / m - (fg + wd * 4 + mix * 2) / f, 2)
                  .toDouble();
          if (score < minScore) {
            minScore = score;
            result = [
              ...List.filled(md, MatchType.menDoubles),
              ...List.filled(wd, MatchType.womenDoubles),
              ...List.filled(mix, MatchType.mixedDoubles)
            ];
          }
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    final res =
        _requirementResult ?? const RequirementResult(canGenerate: true);
    final theme = Theme.of(context);
    final selectedTypes = isAutoRecommendMode ? currentRecommendTypes : types;

    return AlertDialog(
      title: const Text('MATCH SETTINGS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildGenderStatsHeader(),
            const SizedBox(height: 20),
            const Divider(),
            if (AppConfig.autoRecommendEnabled) _buildModeToggle(),
            const SizedBox(height: 20),
            if (isAutoRecommendMode)
              _buildAutoSettingsSection()
            else
              _buildManualSettingsSection(context),
            _buildRequirementMessage(res, selectedTypes, theme),
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
                    CourtSettings(
                      selectedTypes,
                      autoCourtCount: autoCourtCount,
                      autoCourtPolicy: autoCourtPolicy,
                      isAutoRecommendMode: isAutoRecommendMode,
                    ),
                  ),
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _buildGenderStatsHeader() {
    final pool = widget.notifier.playerStatsPool;
    final effective = _requirementService.calculateEffectiveCounts(pool);

    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _CompactBadge(
              label: '男性: ${pool.activeMales.length} 名',
              color: Colors.blue.shade700),
          const SizedBox(width: 12),
          _CompactBadge(
              label: '女性: ${pool.activeFemales.length} 名',
              color: Colors.pink.shade600),
        ]),
        if (effective.male < pool.activeMales.length ||
            effective.female < pool.activeFemales.length)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '※ 同時出場制限により実質 男性:${effective.male.toStringAsFixed(1)}名, 女性:${effective.female.toStringAsFixed(1)}名 として計算',
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
            value: true, label: Text('自動'), icon: Icon(Icons.auto_awesome)),
        ButtonSegment(
            value: false, label: Text('手動'), icon: Icon(Icons.touch_app))
      ],
      selected: {isAutoRecommendMode},
      onSelectionChanged: (val) => setState(() {
        isAutoRecommendMode = val.first;
        _updateRequirement();
      }),
    );
  }

  Widget _buildRequirementMessage(
      RequirementResult res, List<MatchType> selectedTypes, ThemeData theme) {
    if (selectedTypes.isEmpty) return const SizedBox.shrink();

    if (!res.canGenerate) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text(
          res.errorMessage ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
      );
    }

    if (res.predictedRestPlayerNames.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text(
          '同時出場制限による選外候補:\n${res.predictedRestPlayerNames.join(', ')}',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAutoSettingsSection() {
    return Column(children: [
      _buildCourtCountDropdown(),
      const SizedBox(height: 12),
      const Text('生成ポリシー', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      _buildPolicySelector(),
      const SizedBox(height: 16),
      _MatchTypeSelector(
        selectedTypes: currentRecommendTypes,
        onAdd: (type) {
          setState(() => currentRecommendTypes.add(type));
          _updateRequirement();
        },
        onRemove: (index) {
          setState(() => currentRecommendTypes.removeAt(index));
          _updateRequirement();
        },
        checkRequirement: _checkRequirementWithAddType,
      ),
    ]);
  }

  Widget _buildManualSettingsSection(BuildContext context) {
    return _MatchTypeSelector(
      selectedTypes: types,
      onAdd: (type) {
        setState(() => types.add(type));
        _updateRequirement();
      },
      onRemove: (index) {
        setState(() => types.removeAt(index));
        _updateRequirement();
      },
      checkRequirement: _checkRequirementWithAddType,
    );
  }

  Widget _buildCourtCountDropdown() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('コート数', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(width: 16),
      DropdownButton<int>(
        value: autoCourtCount,
        items: List.generate(6, (i) => i + 1)
            .map((c) => DropdownMenuItem(value: c, child: Text('$c 面')))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            autoCourtCount = v;
            _updateRequirement();
          });
        },
      ),
    ]);
  }

  Widget _buildPolicySelector() {
    return SegmentedButton<AutoCourtPolicy>(
      segments: AutoCourtPolicy.values
          .map((p) => ButtonSegment(value: p, label: Text(p.displayName)))
          .toList(),
      selected: {autoCourtPolicy},
      onSelectionChanged: (val) => setState(() {
        autoCourtPolicy = val.first;
        _updateRequirement();
      }),
    );
  }
}

class _MatchTypeSelector extends StatelessWidget {
  final List<MatchType> selectedTypes;
  final Function(MatchType) onAdd;
  final Function(int) onRemove;
  final bool Function(MatchType) checkRequirement;

  const _MatchTypeSelector({
    required this.selectedTypes,
    required this.onAdd,
    required this.onRemove,
    required this.checkRequirement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('形式を選択', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: MatchType.values
              .map((type) => _buildAddChip(context, type))
              .toList(),
        ),
        const SizedBox(height: 20),
        if (selectedTypes.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: selectedTypes
                .asMap()
                .entries
                .map((e) => _buildSelectedChip(context, e.key, e.value))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildAddChip(BuildContext context, MatchType type) {
    return ActionChip(
      label: Text(type.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: checkRequirement(type) ? () => onAdd(type) : null,
      avatar:
          Icon(Icons.add, size: 18, color: _getMatchTypeColor(context, type)),
      side: BorderSide(color: _getMatchTypeColor(context, type)),
    );
  }

  Widget _buildSelectedChip(BuildContext context, int index, MatchType type) {
    return InputChip(
      label: Text(type.displayName,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
      onDeleted: () => onRemove(index),
      deleteIconColor: Colors.white,
      backgroundColor: _getMatchTypeColor(context, type),
      side: BorderSide.none,
    );
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}
