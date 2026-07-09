import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/game_state.dart';
import '../game/stack_game.dart';
import '../settings/settings.dart';

/// Fires haptic pulses off game-state transitions: a light tick per placed
/// block, a firmer pulse on PERFECT, a click on level-up, and a heavy thud
/// when the run ends. Presentation-side only — it observes the game's
/// notifiers and never touches the loop. HapticFeedback needs no permission
/// and is a silent no-op on web.
class HapticsController {
  HapticsController({required this.game, required this.settings}) {
    _lastScore = game.score.value;
    _lastPerfects = game.perfectDrops.value;
    _lastLevel = game.level.value;
    game.score.addListener(_onScore);
    game.perfectDrops.addListener(_onPerfect);
    game.level.addListener(_onLevel);
    game.phase.addListener(_onPhase);
  }

  final StackGame game;
  final Settings settings;

  late int _lastScore;
  late int _lastPerfects;
  late int _lastLevel;

  bool get _enabled => settings.haptics && !kIsWeb;

  void _onScore() {
    final v = game.score.value;
    final rose = v > _lastScore;
    _lastScore = v;
    // Perfect drops get their own, stronger pulse in _onPerfect.
    if (rose && _enabled && !game.state.lastDropPerfect) {
      HapticFeedback.lightImpact();
    }
  }

  void _onPerfect() {
    final v = game.perfectDrops.value;
    final rose = v > _lastPerfects;
    _lastPerfects = v;
    if (rose && _enabled) HapticFeedback.mediumImpact();
  }

  void _onLevel() {
    final v = game.level.value;
    final rose = v > _lastLevel;
    _lastLevel = v;
    if (rose && _enabled) HapticFeedback.selectionClick();
  }

  void _onPhase() {
    final p = game.phase.value;
    if ((p == GamePhase.toppling || p == GamePhase.ending) && _enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void dispose() {
    game.score.removeListener(_onScore);
    game.perfectDrops.removeListener(_onPerfect);
    game.level.removeListener(_onLevel);
    game.phase.removeListener(_onPhase);
  }
}
