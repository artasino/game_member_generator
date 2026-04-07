import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
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
            fontWeight: FontWeight.w900,
            color: color.withValues(alpha: 0.85),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final genderColor = GenderTheme.getColor(context, player.gender);
    final tokens = _PlayerChipTokens.resolve(
      colorScheme: colorScheme,
      genderColor: genderColor,
      isActive: player.isActive,
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
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: tokens.opacity,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            showCheckbox ? AppSpacing.sm : AppSpacing.md - 2,
            AppSpacing.sm,
            AppSpacing.md - 2,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: tokens.backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: tokens.borderColor,
              width: tokens.borderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCheckbox) ...[
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: Icon(
                      tokens.checkboxIcon,
                      size: 18,
                      color: tokens.checkboxIconColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PlayerChipHeader(
                      name: player.name,
                      isMustRest: player.isMustRest,
                      nameColor: tokens.nameColor,
                      mustRestColor: colorScheme.tertiary,
                    ),
                    if (showStats) ...[
                      const SizedBox(height: AppSpacing.xs + 1),
                      _PlayerChipStats(
                        totalMatches: stats.totalMatches,
                        totalRests: stats.totalRests,
                        sameGenderCount: sameGenderCount,
                        mixedCount: mxCount,
                        genderLabel: player.gender == Gender.male ? '男' : '女',
                        badgePrimaryColor:
                            colorScheme.primary.withValues(alpha: 0.82),
                        badgeErrorColor: colorScheme.error.withValues(alpha: 0.82),
                        textColor: tokens.statsTextColor,
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerChipHeader extends StatelessWidget {
  final String name;
  final bool isMustRest;
  final Color nameColor;
  final Color mustRestColor;

  const _PlayerChipHeader({
    required this.name,
    required this.isMustRest,
    required this.nameColor,
    required this.mustRestColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w900,
                color: nameColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (isMustRest) ...[
            const SizedBox(width: 6),
            Icon(Icons.coffee_outlined, size: 14, color: mustRestColor),
          ],
        ],
      ),
    );
  }
}

class _PlayerChipStats extends StatelessWidget {
  final int totalMatches;
  final int totalRests;
  final int sameGenderCount;
  final int mixedCount;
  final String genderLabel;
  final Color badgePrimaryColor;
  final Color badgeErrorColor;
  final Color textColor;

  const _PlayerChipStats({
    required this.totalMatches,
    required this.totalRests,
    required this.sameGenderCount,
    required this.mixedCount,
    required this.genderLabel,
    required this.badgePrimaryColor,
    required this.badgeErrorColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: TextStyle(color: textColor),
      child: Opacity(
        opacity: 0.86,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBadge(
                label: '出$totalMatches',
                color: badgePrimaryColor,
                scale: 0.88,
              ),
              const SizedBox(width: 4),
              AppBadge(
                label: '休$totalRests',
                color: badgeErrorColor,
                scale: 0.88,
              ),
              const SizedBox(width: 6),
              Text(
                '$genderLabel$sameGenderCount 混$mixedCount',
                style: TextStyle(
                  fontSize: 9.5,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerChipTokens {
  final double opacity;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final IconData checkboxIcon;
  final Color checkboxIconColor;
  final Color nameColor;
  final Color statsTextColor;

  const _PlayerChipTokens({
    required this.opacity,
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.checkboxIcon,
    required this.checkboxIconColor,
    required this.nameColor,
    required this.statsTextColor,
  });

  factory _PlayerChipTokens.resolve({
    required ColorScheme colorScheme,
    required Color genderColor,
    required bool isActive,
  }) {
    if (isActive) {
      return _PlayerChipTokens(
        opacity: 1,
        backgroundColor: genderColor.withValues(alpha: 0.14),
        borderColor: genderColor.withValues(alpha: 0.55),
        borderWidth: 1.5,
        checkboxIcon: Icons.check_circle,
        checkboxIconColor: genderColor,
        nameColor: colorScheme.onSurface,
        statsTextColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
      );
    }

    return _PlayerChipTokens(
      opacity: 0.62,
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.8),
      borderWidth: 1.0,
      checkboxIcon: Icons.radio_button_unchecked,
      checkboxIconColor: colorScheme.outline,
      nameColor: colorScheme.onSurfaceVariant,
      statsTextColor: colorScheme.outline,
    );
  }
}
