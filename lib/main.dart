import 'package:flutter/material.dart';

import 'ui/game_screen.dart';

void main() => runApp(const StackAndToppleApp());

class StackAndToppleApp extends StatelessWidget {
  const StackAndToppleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stack & Topple',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF10141C),
      ),
      home: const GameScreen(),
    );
  }
}
