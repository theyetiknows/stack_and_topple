import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../game/stack_game.dart';

/// Full-screen start and game-over cards. Both are "tap anywhere" to keep the
/// loop frictionless. Shown only in the [GamePhase.ready] / [GamePhase.gameOver]
/// phases; during play they collapse so taps fall through to the drop handler.
class GameOverlays extends StatelessWidget {
  const GameOverlays({super.key, required this.game, required this.onStart});

  final StackGame game;

  /// Invoked on the start/retry tap. The screen decides whether the run needs
  /// the Balance-Mode calibration step first.
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GamePhase>(
      valueListenable: game.phase,
      builder: (context, phase, _) {
        switch (phase) {
          case GamePhase.ready:
            return OverlayCard(
              title: 'STACK & TOPPLE',
              subtitle: 'Tap to drop each block.\nStack as high as you can.',
              cta: 'TAP TO START',
              onTap: onStart,
            );
          case GamePhase.gameOver:
            return OverlayCard(
              title: 'Score  ${game.score.value}',
              subtitle: 'The tower toppled.',
              cta: 'TAP TO RETRY',
              onTap: onStart,
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

/// The Balance-Mode calibration step: capture the player's comfortable pose as
/// the neutral baseline. Shown instead of starting the run when the toggle is
/// on. The tap doubles as the user gesture iOS Safari requires for its motion
/// permission prompt.
class CalibrationCard extends StatelessWidget {
  const CalibrationCard({
    super.key,
    required this.busy,
    required this.error,
    required this.onCalibrate,
    required this.onPlayClassic,
  });

  final bool busy;
  final String? error;
  final VoidCallback onCalibrate;
  final VoidCallback onPlayClassic;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onCalibrate,
      child: Container(
        color: const Color(0xCC0B0E14),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BALANCE MODE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hold your phone the way you want to play —\n'
              'that pose becomes your neutral.\n'
              'Then tilt gently to steady the tower.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFFFF8A80)),
              ),
            ],
            const SizedBox(height: 36),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: busy ? Colors.white38 : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                busy ? 'CALIBRATING…' : 'TAP WHEN STEADY',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF10141C),
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: onPlayClassic,
              child: const Text(
                'PLAY CLASSIC INSTEAD',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 1.5,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OverlayCard extends StatelessWidget {
  const OverlayCard({
    super.key,
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
