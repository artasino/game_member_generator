import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:game_member_generator/Gender.dart';
import 'package:game_member_generator/Member.dart';
import 'package:game_member_generator/MemberList.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({Key? key}) : super(key: key);

  @override
  _MemberPageState createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  var memberList = MemberListSingleton().memberList;

  @override
  Widget build(BuildContext context) {
    loadMemberList();
    return Scaffold(
      appBar: AppBar(
        title: const Text("メンバー"),
        actions: [
          IconButton(
              onPressed: () {
                loadMemberList();
                build(context);
              },
              icon: const Icon(Icons.update)),
          IconButton(onPressed: saveMemberList, icon: const Icon(Icons.save))
        ],
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () async {
            var newMember = await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) {
                return const AddMemberPage();
              }),
            );
            if (newMember != null) {
              setState(() {
                memberList.add(newMember);
                memberList = memberList.toSet().toList();
              });
            }
          },
          child: const Icon(Icons.add, color: Colors.white)),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: memberList
              .map((member) => Card(
                  shadowColor: Colors.grey,
                  child: ListTile(
                    onTap: () => {},
                    onLongPress: () => {},
                    tileColor: Colors.white,
                    title: Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: member.getGenderIcon(),
                  )))
              .toList(),
        ),
      ),
    );
  }

  void saveMemberList() async {
    // List<String> list = "{}"
    final member = memberList.map((f) => json.encode(f.toJson())).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('MEMBER_LIST', member);
  }

  void loadMemberList() async {
    final prefs = await SharedPreferences.getInstance();
    final member = prefs.getStringList('MEMBER_LIST');
    if (member != null) {
      List<Member> result =
          member.map((f) => Member.fromJson(json.decode(f))).toList();
      memberList.addAll(result);
      memberList = memberList.toSet().toList();
    }
  }
}

class AddMemberPage extends StatefulWidget {
  const AddMemberPage({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _AddMemberPageState();
}

enum RadioValue { FIRST, SECOND }

class _AddMemberPageState extends State<AddMemberPage> {
  final dateTextController = TextEditingController();

  RadioValue _gValue = RadioValue.FIRST;
  String name = "";

  Member createMember(String name, RadioValue rValue) {
    return rValue == RadioValue.FIRST
        ? Member(name: name, gender: Gender.male)
        : Member(name: name, gender: Gender.female);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("追加するメンバー"),
      ),
      body: Container(
          padding: const EdgeInsets.all(20),
          child: Column(children: <Widget>[
            TextField(
              decoration: const InputDecoration(
                  labelText: "名前", icon: Icon(Icons.list, color: Colors.blue)),
              onChanged: (text) {
                name = text;
              },
            ),
            Container(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    Radio(
                      value: RadioValue.FIRST,
                      groupValue: _gValue,
                      onChanged: (value) => _onRadioSelected(value),
                    ),
                    const Text("男")
                  ],
                ),
                Row(
                  children: [
                    Radio(
                      value: RadioValue.SECOND,
                      groupValue: _gValue,
                      onChanged: (value) => _onRadioSelected(value),
                    ),
                    const Text("女")
                  ],
                ),
              ],
            ),
            Container(height: 200),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(createMember(name, _gValue));
                  },
                  child: const Text("追加")),
              ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(null);
                  },
                  child: const Text("キャンセル")),
            ]),
          ])),
    );
  }

  void _onRadioSelected(value) {
    setState(() {
      _gValue = value;
    });
  }
}
