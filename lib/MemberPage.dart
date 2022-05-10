import 'package:flutter/material.dart';

class MemberPage extends StatelessWidget {
  MemberPage({Key? key}) : super(key: key);

  final List<Member> memberList = [
    const Member(name: "篠原", gender: Gender.male),
    const Member(name: "菜南", gender: Gender.female)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("メンバー"),
        leading: IconButton(
            onPressed: () {
              showDialog(context: context, builder: (context) {
                return const AlertDialog(
                  title: Text("Test"),
                );
              });
            },
            icon: const Icon(Icons.add, color: Colors.white)),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: memberList
              .map((member) =>
              Card(
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
}

class Member {
  final String name;
  final Gender gender;

  const Member({
    required this.name,
    required this.gender,
  });

  Icon getGenderIcon() {
    if (gender == Gender.male) {
      return const Icon(Icons.male, color: Colors.blue);
    } else {
      return const Icon(Icons.female, color: Colors.pink);
    }
  }
}

enum Gender { male, female }

// class TextEditDialog extends StatefulWidget{
//   const TextEditDialog({Key? key}) : super(key: key);
//
//   @override
//   State<StatefulWidget> createState() => _TextEditDialogState();
// }

// class _TextEditDialogState extends State<TextEditDialog>{
//   final dateTextController = TextEditingController();
//
//   @override
//   Widget build(BuildContext context) {
//     MaterialLocalizations localizations = MaterialLocalizations.of(context);
//     final AlertDialog dialog = AlertDialog(
//       title: Text("Set Timer"),
//       content: TextField(
//         controller: dateTextController,
//         decoration: InputDecoration(
//           hintText: "sec",
//         ),
//         autofocus: true,
//         keyboardType: TextInputType.number,
//       ),
//       actions: actions,
//     );
//     return dialog;
//   }
//
// }
