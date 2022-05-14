import 'package:flutter/material.dart';

class GamePage extends StatelessWidget {
  const GamePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("対戦表"),
        leading: IconButton(
            onPressed: () => {},
            icon: const Icon(Icons.add, color: Colors.white)),
      ),
      backgroundColor: Colors.white,
      body: const Center(
        child: Text(
          "対戦表",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
