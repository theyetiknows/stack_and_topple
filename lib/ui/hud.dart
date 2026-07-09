import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../game/stack_game.dart';

/// The in-run heads-up display: score (with a pop on change), the current
/// level tag, a PERFECT flash, and a LEVEL-UP toast. Reads the game's
/// [ValueNotifier]s so it rebuilds only when they change.
class Hud extends StatelessWidget {
  const Hud({super.key, required this.game});

  final StackGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<GamePhase>(
        valueListenable: game.phase,
        builder: (context, phase, _) {
          final visible = phase == GamePhase.sweeping ||
              phase == GamePhase.critical ||
              phase == GamePhase.toppling ||
              phase == GamePhase.ending;
          if (!visible) return const SizedBox.shrink();
          return Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScorePop(score: game.score),
                      const SizedBox(height: 2),
                      _LevelTag(level: game.level),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.45),
                child: _PerfectFlash(perfectDrops: game.perfectDrops),
              ),
              Align(
                alignment: const Alignment(0, -0.25),
                child: _LevelUpToast(
                  level: game.level,
                  bonus: game.tuning.levelBonus,
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.6),
                child: _SaveFlash(
                  saves: game.saves,
                  bonus: game.tuning.saveBonus,
                ),
              ),
              if (phase == GamePhase.critical)
                const Align(
                  alignment: Alignment(0, -0.35),
                  child: _CriticalWarning(),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Score readout that scale-pops each time the value changes.
class _ScorePop extends StatelessWidget {
  const _ScorePop({required this.score});

  final ValueNotifier<int> score;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: score,
      builder: (context, value, _) => TweenAnimationBuilder<double>(
        key: ValueKey(value),
        tween: Tween(begin: value == 0 ? 1.0 : 1.35, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Text(
          '$value',
          style: const TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
          ),
        ),
      ),
    );
  }
}

/// Blinking SAVE IT! while the tower is critical and the player can rescue it.
class _CriticalWarning extends StatefulWidget {
  const _CriticalWarning();

  @override
  State<_CriticalWarning> createState() => _CriticalWarningState();
}

class _CriticalWarningState extends State<_CriticalWarning>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
      child: const Text(
        'SAVE IT!',
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
          color: Color(0xFFFF5252),
          shadows: [Shadow(blurRadius: 14, color: Colors.black87)],
        ),
      ),
    );
  }
}

/// "SAVED! +N" celebration when a critical tower is rescued.
class _SaveFlash extends StatelessWidget {
  const _SaveFlash({required this.saves, required this.bonus});

  final ValueNotifier<int> saves;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: saves,
      builder: (context, count, _) {
        if (count == 0) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey(count),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 950),
          builder: (context, t, _) {
            final opacity = t < 0.2 ? t / 0.2 : (1 - t) / 0.8;
            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(
                scale: 0.9 + 0.35 * t,
                child: Text(
                  'SAVED!  +$bonus',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: Color(0xFF69F0AE),
                    shadows: [Shadow(blurRadius: 14, color: Colors.black87)],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _LevelTag extends StatelessWidget {
  const _LevelTag({required this.level});

  final ValueNotifier<int> level;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: level,
      builder: (context, value, _) => Text(
        'LEVEL ${value + 1}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// "PERFECT!" that flashes and floats up on each perfect drop.
class _PerfectFlash extends StatelessWidget {
  const _PerfectFlash({required this.perfectDrops});

  final ValueNotifier<int> perfectDrops;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: perfectDrops,
      builder: (context, count, _) {
        if (count == 0) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey(count),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 650),
          builder: (context, t, _) {
            final opacity = t < 0.25 ? t / 0.25 : (1 - t) / 0.75;
            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, -22 * t),
                child: const Text(
                  'PERFECT!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                    color: Color(0xFFFFE082),
                    shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Brief toast when the difficulty steps up a level (with its one-time bonus).
class _LevelUpToast extends StatelessWidget {
  const _LevelUpToast({required this.level, required this.bonus});

  final ValueNotifier<int> level;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: level,
      builder: (context, value, _) {
        if (value == 0) return const SizedBox.shrink();
        return TweenAnimationBuilder<double>(
          key: ValueKey(value),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1100),
          builder: (context, t, _) {
            final opacity = t < 0.15 ? t / 0.15 : (1 - t) / 0.85;
            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Text(
                'LEVEL ${value + 1} — FASTER  +$bonus',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black87)],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
