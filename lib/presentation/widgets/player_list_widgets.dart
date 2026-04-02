import 'package:flutter/material.dart';

import '../../domain/entities/gender.dart';
import '../../domain/entities/match_type.dart';
import '../../domain/entities/player_with_stats.dart';
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
            borderRadius: BorderRadius.circular(2),
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
    final genderColor = GenderTheme.getColor(player.gender);

    final sameGenderCount = player.gender == Gender.male
        ? (stats.typeCounts[MatchType.menDoubles] ?? 0)
        : (stats.typeCounts[MatchType.womenDoubles] ?? 0);
    final mxCount = stats.typeCounts[MatchType.mixedDoubles] ?? 0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onDoubleTap: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: player.isActive ? 1.0 : 0.6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: player.isActive
                ? genderColor.withValues(alpha: 0.12)
                : genderColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: player.isActive
                  ? genderColor.withValues(alpha: 0.5)
                  : genderColor.withValues(alpha: 0.2),
              width: player.isActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showCheckbox) ...[
                Icon(
                  player.isActive
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: player.isActive
                      ? genderColor
                      : genderColor.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: player.isActive
                                  ? Colors.black87
                                  : Colors.black54,
                            ),
                          ),
                        ),
                        if (player.isMustRest) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.coffee_outlined,
                              size: 14, color: Colors.orange),
                        ],
                      ],
                    ),
                    if (showStats) ...[
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppBadge(
                              label: '出${stats.totalMatches}',
                              color: Colors.indigo,
                              scale: 0.9,
                            ),
                            const SizedBox(width: 4),
                            AppBadge(
                              label: '休${stats.totalRests}',
                              color: Colors.deepOrange,
                              scale: 0.9,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${player.gender == Gender.male ? "男" : "女"}$sameGenderCount 混$mxCount',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: player.isActive
                                    ? Colors.black54
                                    : Colors.grey.shade600,
                                fontWeight: player.isActive
                                    ? FontWeight.w900
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
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
