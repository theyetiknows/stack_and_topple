import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../game/stack_game.dart';

/// The in-run heads-up display: just the current score, big and centred.
/// Reads the game's [ValueNotifier]s so it repaints only when they change.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final StackGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<GamePhase>(
        valueListenable: game.phase,
        builder: (context, phase, _) {
          final visible =
              phase == GamePhase.sweeping || phase == GamePhase.toppling;
          if (!visible) return const SizedBox.shrink();
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ValueListenableBuilder<int>(
                valueListenable: game.score,
                builder: (context, score, _) => Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
