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
            title: '1. メンバ画面で準備する',
            icon: Icons.group_add,
            items: [
              '「メンバ」タブで + ボタンから登録し、参加メンバをONにします。',
              '同時出場制限を設定すると、夫婦でどちらかが小さい子供を見る必要がある場合などにどちらかは必ず休みになります。',
              '検索バーで名前・よみがなをすぐに探せます。',
              '右上メニューからCSV/JSONで保存・読み込み、複数メンバの登録・削除ができます。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '2. 試合履歴画面で進行する',
            icon: Icons.sports_tennis,
            items: [
              '自動で試合タイプを提案(男女の入る回数を平滑化)し、必要なら手動で編集できます。',
              'ペア回数の記録を見える化し、偏りの確認がしやすいです。',
              'できるだけ連続休みを避けつつ、種目バランス・ペア回数・敵になる回数を考慮して試合生成します。',
              '履歴は時系列で追えるので、進行が見失いにくいです。',
            ],
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: '3. 費用計算画面で精算する',
            icon: Icons.calculate,
            items: [
              '予め買っておいたシャトル・ボールの価格を登録しておけます。',
              '当日使った個数を入力すると、消耗分の費用を自動計算できます。',
              'コート代など他の費用も追加して、1人あたり金額をまとめて算出できます。',
              '男子/女子/全員など分担対象を切り替えられます。',
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
                      Chip(label: Text('今日のコート数を設定')),
                      Chip(label: Text('試合生成画面で自動で試合生成！')),
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
            '''メンバ登録 → 試合生成 → 試合開始！''',
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
