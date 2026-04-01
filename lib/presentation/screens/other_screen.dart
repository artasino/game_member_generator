import 'package:flutter/material.dart';

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
            title: Text('バージョン (Gitタグ)'),
            subtitle: Text(_gitTagVersion),
          ),
        ],
      ),
    );
  }
}
