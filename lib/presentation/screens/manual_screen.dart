import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manualGuideTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _HeroGuideCard(theme: theme),
          const SizedBox(height: 16),
          _GuideSection(
            title: l10n.manualStep1Title,
            icon: Icons.group_add,
            items: [
              l10n.manualStep1Item1,
              l10n.manualStep1Item2,
              l10n.manualStep1Item3,
              l10n.manualStep1Item4,
            ],
          ),
          const SizedBox(height: 12),
          _GuideSection(
            title: l10n.manualStep2Title,
            icon: Icons.sports_tennis,
            items: [
              l10n.manualStep2Item1,
              l10n.manualStep2Item2,
              l10n.manualStep2Item3,
              l10n.manualStep2Item4,
            ],
          ),
          const SizedBox(height: 12),
          _GuideSection(
            title: l10n.manualStep3Title,
            icon: Icons.calculate,
            items: [
              l10n.manualStep3Item1,
              l10n.manualStep3Item2,
              l10n.manualStep3Item3,
              l10n.manualStep3Item4,
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.manualTipsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(l10n.manualTipsChipRegister)),
                      Chip(label: Text(l10n.manualTipsChipCourt)),
                      Chip(label: Text(l10n.manualTipsChipGenerate)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroGuideCard extends StatelessWidget {
  final ThemeData theme;

  const _HeroGuideCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates,
                  color: theme.colorScheme.onPrimary, size: 28),
              const SizedBox(width: 8),
              Text(
                l10n.manualHeroTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.manualHeroSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.check_circle,
                          size: 16, color: Colors.green),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
