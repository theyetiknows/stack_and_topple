import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../game/stack_game.dart';

/// Full-screen start and game-over cards. Both are "tap anywhere" to keep the
/// loop frictionless. Shown only in the [GamePhase.ready] / [GamePhase.gameOver]
/// phases; during play they collapse so taps fall through to the drop handler.
class GameOverlays extends StatelessWidget {
  const GameOverlays({super.key, required this.game});

  final StackGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamePhase>(
      valueListenable: game.phase,
      builder: (context, phase, _) {
        switch (phase) {
          case GamePhase.ready:
            return _Card(
              title: 'STACK & TOPPLE',
              subtitle: 'Tap to drop each block.\nStack as high as you can.',
              cta: 'TAP TO START',
              onTap: game.startRun,
            );
          case GamePhase.gameOver:
            return _Card(
              title: 'Score  ${game.score.value}',
              subtitle: 'The tower toppled.',
              cta: 'TAP TO RETRY',
              onTap: game.startRun,
            );
          case GamePhase.sweeping:
          case GamePhase.toppling:
          case GamePhase.ending:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: const Color(0xCC0B0E14),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 36),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                cta,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10141C),
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
