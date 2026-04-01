import 'package:flutter/material.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('使い方ガイド'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _HeroGuideCard(theme: theme),
          const SizedBox(height: 16),
          const _GuideSection(
            title: '1. メンバを登録する',
            icon: Icons.group_add,
            items: [
              '「メンバ」タブで + ボタンから登録します。',
              '検索バーで名前・よみがなをすぐに探せます。',
              '右上メニューからCSV/JSONで保存・読み込みできます。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '2. 試合を進める',
            icon: Icons.sports_tennis,
            items: [
              '「試合履歴」タブで試合の流れを確認できます。',
              '長押しで選手を選択し、交代操作もスムーズに行えます。',
              '履歴は時系列で追えるので、進行が見失いにくいです。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '3. 費用を計算する',
            icon: Icons.calculate,
            items: [
              '「費用計算」タブでシャトル・コート代をまとめて入力。',
              '男子/女子/全員など分担対象を切り替えられます。',
              '入力後は1人あたりの金額を自動計算できます。',
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
                    '使いこなしのコツ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('まずは8〜12人を登録')),
                      Chip(label: Text('検索で素早く切替')),
                      Chip(label: Text('履歴で振り返り')),
                      Chip(label: Text('費用計算は最後にまとめて')),
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
                'はじめてでも3ステップ',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '''メンバ登録 → 試合進行 → 費用計算の順に使うと、
最短で迷わず運用できます。''',
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
