import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'manual_screen.dart';

class OtherScreen extends StatelessWidget {
  const OtherScreen({super.key});

  static const String _gitTagVersion = 'v2.0.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('その他')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('マニュアル'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManualScreen(),
                ),
              );
            },
          ),
          const Divider(height: 0),
          const ListTile(
            leading: Icon(Icons.tag_outlined),
            title: Text('バージョン'),
            subtitle: Text(_gitTagVersion),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('🏸 応援する'),
            subtitle: const Text('開発者が無償で作成しています。\n練習のお供に役立ったら、ぜひ応援をお願いします！'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('外部サイトへ移動'),
                  content: const Text('応援ページ（外部サイト）へ移動します。よろしいですか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('キャンセル'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('移動する'),
                    ),
                  ],
                ),
              );

              if (ok == true) {
                final url = Uri.parse('https://ofuse.me/37202113/letter');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
