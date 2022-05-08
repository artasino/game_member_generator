import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_member_generator/TabPage.dart';

void main() {
  runApp(const GameMemberGenerator());
}

class GameMemberGenerator extends StatelessWidget {
  const GameMemberGenerator({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ダブルス組み合わせ生成',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TabPage(),
    );
  }
}
