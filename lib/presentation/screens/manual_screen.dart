import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualGuideTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _GuideSection(
            title: l10n.manualPrepareTitle,
            icon: Icons.group_add,
            items: [
              l10n.manualPrepareItem1,
              l10n.manualPrepareItem2,
              l10n.manualPrepareItem3,
            ],
          ),
          const SizedBox(height: 12),
          _GuideSection(
            title: l10n.manualGenerateTitle,
            icon: Icons.sports_tennis,
            items: [
              l10n.manualGenerateItem1,
              l10n.manualGenerateItem2,
              l10n.manualGenerateItem3,
            ],
          ),
          const SizedBox(height: 12),
          _GuideSection(
            title: l10n.manualSwapTitle,
            icon: Icons.swap_horiz,
            items: [
              l10n.manualSwapItem1,
              l10n.manualSwapItem2,
              l10n.manualSwapItem3,
            ],
          ),
          const SizedBox(height: 12),
          _GuideSection(
            title: l10n.manualTroubleshootTitle,
            icon: Icons.help_outline,
            items: [
              l10n.manualTroubleshootItem1,
              l10n.manualTroubleshootItem2,
            ],
          ),
          const SizedBox(height: 12),
          _GuideSection(
            title: l10n.manualExpenseTitle,
            icon: Icons.calculate,
            items: [
              l10n.manualExpenseItem1,
              l10n.manualExpenseItem2,
              l10n.manualExpenseItem3,
            ],
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
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
