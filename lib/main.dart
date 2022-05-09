import 'package:flutter/material.dart';
import 'package:game_member_generator/GamePage.dart';
import 'package:game_member_generator/MemberPage.dart';
import 'package:flutter/widgets.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected_index = 0;

  List<Widget> _widgetOptions = <Widget>[MemberPage(), GamePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selected_index,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(IconData(0xe042, fontFamily: 'MaterialIcons'),
                color: Colors.black12),
            label: 'メンバー',
            activeIcon: Icon(IconData(0xe042, fontFamily: 'MaterialIcons'),
                color: Colors.blueAccent),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis, color: Colors.black12),
            label: '組み合わせ',
            activeIcon: Icon(Icons.sports_tennis, color: Colors.blueAccent),
          ),
        ],
        onTap: (index) {
          setState(() {
            _selected_index = index;
          });
        },
      ),
      body: _widgetOptions.elementAt(_selected_index),
    );
  }
}
