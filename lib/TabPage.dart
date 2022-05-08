import 'package:flutter/material.dart';
import 'package:game_member_generator/MemberPage.dart';
import 'package:game_member_generator/GamePage.dart';

class TabPage extends StatelessWidget {
  final _tab = <Tab>[const Tab(text: "メンバー"), const Tab(text: "対戦表")];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: _tab.length,
        child: Scaffold(
          appBar: AppBar(
            title: const Text("ダブルス組み合わせ"),
            bottom: TabBar(
              tabs: _tab,
            ),
          ),
          body:  TabBarView(
            children: <Widget>[
              MemberPage(),
              const GamePage(),
            ],
          ),
        ));
  }
}
