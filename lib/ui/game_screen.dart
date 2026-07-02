import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/stack_game.dart';
import 'hud.dart';
import 'overlays.dart';

/// Hosts the Flame game and layers the Flutter HUD + start/game-over overlays on
/// top. A single top-level tap handler feeds drops to the game; overlays handle
/// their own taps for start/retry.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final StackGame game = StackGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF10141C),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => game.onDropTap(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GameWidget(game: game),
            Hud(game: game),
            GameOverlays(game: game),
          ],
        ),
      ),
    );
  }
}
