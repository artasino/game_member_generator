import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/player_stats.dart';
import '../../domain/entities/player_with_stats.dart';
import '../theme/app_theme.dart';
import 'common_widgets.dart';

export 'common_widgets.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: title, subtitle: subtitle);
  }
}

class GenderLabel extends StatelessWidget {
  final String label;
  final Color color;

  const GenderLabel({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

class PlayerChip extends StatelessWidget {
  final PlayerWithStats playerWithStats;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showCheckbox;
  final bool showStats;

  const PlayerChip({
    super.key,
    required this.playerWithStats,
    required this.onTap,
    required this.onLongPress,
    this.showCheckbox = false,
    this.showStats = false,
  });

  @override
  Widget build(BuildContext context) {
    final player = playerWithStats.player;
    final stats = playerWithStats.stats;
    final genderColor = GenderTheme.getColor(context, player.gender);
    final colorScheme = Theme.of(context).colorScheme;
    final token = _PlayerChipVisualToken.from(
      isActive: player.isActive,
      genderColor: genderColor,
      colorScheme: colorScheme,
    );

    final sameGenderCount = player.gender == Gender.male
        ? (stats.typeCounts[MatchType.menDoubles] ?? 0)
        : (stats.typeCounts[MatchType.womenDoubles] ?? 0);
    final mxCount = stats.typeCounts[MatchType.mixedDoubles] ?? 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: showCheckbox
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              )
            : EdgeInsets.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: token.opacity,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: token.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: token.borderColor,
                width: token.borderWidth,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheckbox) ...[
                  _PlayerChipSelectionIcon(token: token),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PlayerChipHeader(player: player, token: token),
                      if (showStats) ...[
                        const SizedBox(height: AppSpacing.xs + 2),
                        _PlayerChipStats(
                          player: player,
                          stats: stats,
                          sameGenderCount: sameGenderCount,
                          mxCount: mxCount,
                          token: token,
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerChipHeader extends StatelessWidget {
  final Player player;
  final _PlayerChipVisualToken token;

  const _PlayerChipHeader({
    required this.player,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.05,
                color: token.nameColor,
              ),
            ),
          ),
        ),
        if (player.isMustRest) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.coffee_outlined, size: 14, color: token.mustRestIconColor),
        ],
      ],
    );
  }
}

class _PlayerChipStats extends StatelessWidget {
  final Player player;
  final PlayerStats stats;
  final int sameGenderCount;
  final int mxCount;
  final _PlayerChipVisualToken token;

  const _PlayerChipStats({
    required this.player,
    required this.stats,
    required this.sameGenderCount,
    required this.mxCount,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBadge(
              label: '出${stats.totalMatches}',
              color: token.statsPrimaryBadgeColor,
              scale: 0.88,
            ),
            const SizedBox(width: AppSpacing.xs),
            AppBadge(
              label: '休${stats.totalRests}',
              color: token.statsRestBadgeColor,
              scale: 0.88,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${player.gender == Gender.male ? "男" : "女"}$sameGenderCount 混$mxCount',
              style: TextStyle(
                fontSize: 10,
                color: token.statsTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerChipSelectionIcon extends StatelessWidget {
  final _PlayerChipVisualToken token;

  const _PlayerChipSelectionIcon({required this.token});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: Icon(
          token.selectionIcon,
          size: 18,
          color: token.selectionIconColor,
        ),
      ),
    );
  }
}

class _PlayerChipVisualToken {
  final double opacity;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final IconData selectionIcon;
  final Color selectionIconColor;
  final Color nameColor;
  final Color mustRestIconColor;
  final Color statsPrimaryBadgeColor;
  final Color statsRestBadgeColor;
  final Color statsTextColor;

  const _PlayerChipVisualToken({
    required this.opacity,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.selectionIcon,
    required this.selectionIconColor,
    required this.nameColor,
    required this.mustRestIconColor,
    required this.statsPrimaryBadgeColor,
    required this.statsRestBadgeColor,
    required this.statsTextColor,
  });

  factory _PlayerChipVisualToken.from({
    required bool isActive,
    required Color genderColor,
    required ColorScheme colorScheme,
  }) {
    return _PlayerChipVisualToken(
      opacity: isActive ? 1.0 : 0.64,
      backgroundColor: isActive
          ? genderColor.withValues(alpha: 0.1)
          : genderColor.withValues(alpha: 0.02),
      borderColor: isActive
          ? genderColor.withValues(alpha: 0.45)
          : genderColor.withValues(alpha: 0.2),
      borderWidth: isActive ? 1.6 : 1.1,
      selectionIcon: isActive ? Icons.check_circle : Icons.circle_outlined,
      selectionIconColor:
          isActive ? genderColor : genderColor.withValues(alpha: 0.48),
      nameColor: isActive
          ? colorScheme.onSurface
          : colorScheme.onSurfaceVariant,
      mustRestIconColor:
          isActive ? colorScheme.tertiary : colorScheme.outline,
      statsPrimaryBadgeColor:
          isActive ? const Color(0xFF2F7D8C) : colorScheme.outline,
      statsRestBadgeColor:
          isActive ? const Color(0xFF8A6D3B) : colorScheme.outline,
      statsTextColor:
          isActive
              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.92)
              : colorScheme.outline,
    );
  }
}
