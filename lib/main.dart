import 'package:flutter/material.dart';

import 'settings/settings.dart';
import 'ui/game_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  runApp(StackAndToppleApp(settings: settings));
}

class StackAndToppleApp extends StatelessWidget {
  const StackAndToppleApp({super.key, required this.settings});

  final Settings settings;

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
      home: GameScreen(settings: settings),
    );
  }
}
