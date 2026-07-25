import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/custom_stability_model.dart';
import '../core/game_loop.dart';
import '../core/game_state.dart';
import '../core/input/input_event.dart';
import '../core/tuning.dart';
import '../input/tap_input_source.dart';
import '../input/tilt_input_source.dart';
import 'tower_renderer.dart';

/// One confetti particle for milestone celebrations. Screen-space,
/// presentation-only: bursts live ~1.5 s, so camera drift is imperceptible
/// and the simulation never knows they exist.
class _Confetti {
  _Confetti({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.angVel,
    required this.size,
    required this.color,
    required this.life,
  });

  double x, y, vx, vy, rotation, angVel;
  final double size;
  final Color color;
  final double life;
  double age = 0;
}

/// The Flame adapter: it owns the game loop, drives a fixed-timestep tick, and
/// renders the read-only [GameState]. It contains NO game rules — all feel
/// logic lives in the pure-Dart core. Phase/score/level/perfects/saves are
/// exposed as [ValueNotifier]s so Flutter overlays react without polling.
class StackGame extends FlameGame {
  StackGame({TuningConfig? tuning}) : tuning = tuning ?? defaultTuning;

  final TuningConfig tuning;

  late final GameState state = GameState(tuning);
  late final GameLoop loop =
      GameLoop(state: state, stability: CustomStabilityModel());
  final TapInputSource _tap = TapInputSource();
  TiltInputSource? _tilt;

  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.ready);
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> level = ValueNotifier(0);
  final ValueNotifier<int> perfectDrops = ValueNotifier(0);
  final ValueNotifier<int> saves = ValueNotifier(0);
  final ValueNotifier<int> blocksLost = ValueNotifier(0);

  /// Fixed simulation step — decouples feel from frame rate for determinism.
  static const double _fixedDt = 1 / 120;
  double _accum = 0;
  double _cameraY = 0;
  double _cameraX = 0;
  double _shakePhase = 0; // presentation-only clock for the shake wiggle

  // Sky crossfade between level palettes (presentation-only).
  int _prevLevel = 0;
  double _paletteBlend = 1;
  static const double _paletteFadeSeconds = 0.8;

  // Milestone confetti (presentation-only).
  final List<_Confetti> _confetti = [];
  int _confettiSeed = 0;

  /// Permission + baseline calibration for Balance Mode. Must be called from
  /// a user gesture (the calibration tap) — iOS Safari's motion permission
  /// only resolves inside one. Returns false if motion is unavailable/denied.
  Future<bool> prepareBalanceMode() async {
    _tilt ??= TiltInputSource(tuning);
    if (!await _tilt!.requestPermission()) return false;
    return _tilt!.calibrate();
  }

  /// Drop the tilt source (used when starting a classic run so a stale sensor
  /// subscription never outlives the mode that needed it).
  void detachTilt() {
    _tilt?.dispose();
    _tilt = null;
  }

  void startRun({bool balanceMode = false, bool looseStack = false}) {
    // Entropy enters the deterministic core only here, as the run seed.
    loop.startRun(
      balanceMode: balanceMode && _tilt != null,
      looseStack: looseStack,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    _accum = 0;
    _cameraY = 0;
    _cameraX = 0;
    _prevLevel = 0;
    _paletteBlend = 1;
    _confetti.clear();
    _syncNotifiers();
  }

  /// Called by the widget layer on a screen tap.
  void onDropTap() {
    if (state.phase == GamePhase.sweeping) _tap.tap();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _updateConfetti(dt);
    if (_paletteBlend < 1) {
      _paletteBlend =
          math.min(1, _paletteBlend + dt / _paletteFadeSeconds);
    }
    if (state.phase == GamePhase.ready) {
      _syncNotifiers();
      return;
    }

    _accum += dt;
    if (_accum > 0.25) _accum = 0.25; // clamp to avoid a spiral of death

    // Deliver this frame's inputs only to the first sub-step: drops resolve
    // once at the piece's current position, and balance values are held on
    // the state for the remaining sub-steps anyway.
    final events = <InputEvent>[..._tap.drain(), ...?_tilt?.drain()];
    var firstStep = true;
    while (_accum >= _fixedDt) {
      loop.tick(_fixedDt, firstStep ? events : const []);
      _accum -= _fixedDt;
      firstStep = false;
    }

    // Smoothly follow the top of the tower (exponential ease, frame-rate safe).
    final targetY = (state.blocksPlaced + 1) * tuning.blockHeight;
    _cameraY += (targetY - _cameraY) * (1 - math.exp(-dt * 6.0));

    // In Loose Stack the tower shears sideways AND the lean swings its top
    // about a base pivot far below the viewport, so the camera tracks
    // horizontally too. Target includes the rotation displacement, which is
    // what actually throws a tall tower off-screen.
    var targetX = 0.0;
    if (state.looseStackActive && state.tower.isNotEmpty) {
      final topH = (state.tower.length - 1) * tuning.blockHeight;
      // Partial compensation: cancelling the rotation swing outright keeps the
      // top perfectly centred but throws the tower's lower half out of frame.
      // Following ~70% frames the whole stack.
      targetX = 0.7 *
          (state.tower.last.centerX + math.sin(state.leanLateral) * topH);
    }
    _cameraX += (targetX - _cameraX) * (1 - math.exp(-dt * 4.0));

    _shakePhase += dt;
    _syncNotifiers();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;

    // Impact shake: a small decaying wiggle after sloppy drops. Purely a
    // canvas translation — the simulation never sees it.
    canvas.save();
    if (state.impactShakeTimer > 0) {
      final p = state.impactShakeTimer / tuning.impactShakeDuration;
      final mag = 5.0 * p;
      canvas.translate(
        math.sin(_shakePhase * 70) * mag,
        math.cos(_shakePhase * 63) * mag * 0.6,
      );
    }
    TowerPainter(
      state: state,
      tuning: tuning,
      cameraY: _cameraY,
      cameraX: _cameraX,
      width: size.x,
      height: size.y,
      prevLevel: _prevLevel,
      paletteBlend: _paletteBlend,
    ).paint(canvas);
    _renderConfetti(canvas);
    canvas.restore();
  }

  // --- Milestone confetti -------------------------------------------------------

  /// Cheap deterministic-ish hash for particle variation.
  double _rand() {
    _confettiSeed = (_confettiSeed * 1103515245 + 12345) & 0x7fffffff;
    return _confettiSeed / 0x7fffffff;
  }

  /// Burst of coloured quads from a point; [tint] flavours ~2/3 of them and
  /// the rest are white/gold for sparkle.
  void _spawnBurst(Color tint, {int count = 42, double yFrac = 0.38}) {
    if (size.x <= 0) return;
    final origin = Offset(size.x / 2, size.y * yFrac);
    for (var i = 0; i < count; i++) {
      final angle = _rand() * math.pi * 2;
      final speed = 140 + _rand() * 320;
      final pick = _rand();
      final color = pick < 0.62
          ? tint
          : (pick < 0.84 ? Colors.white : const Color(0xFFFFD54F));
      _confetti.add(_Confetti(
        x: origin.dx,
        y: origin.dy,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 160, // bias upward
        rotation: _rand() * math.pi,
        angVel: (_rand() - 0.5) * 14,
        size: 5 + _rand() * 7,
        color: color,
        life: 1.1 + _rand() * 0.5,
      ));
    }
  }

  void _updateConfetti(double dt) {
    for (final c in _confetti) {
      c.age += dt;
      c.vy += 640 * dt; // screen-space gravity (y-down)
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      c.rotation += c.angVel * dt;
    }
    _confetti.removeWhere((c) => c.age >= c.life);
  }

  void _renderConfetti(Canvas canvas) {
    for (final c in _confetti) {
      final t = (c.age / c.life).clamp(0.0, 1.0);
      final alpha = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.rotate(c.rotation);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: c.size, height: c.size * 0.62),
        Paint()..color = c.color.withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  void _syncNotifiers() {
    if (phase.value != state.phase) phase.value = state.phase;
    if (score.value != state.score) score.value = state.score;

    final newLevel = state.level;
    if (newLevel != level.value) {
      // Any level change re-keys the sky crossfade; only genuine climbs (not
      // shed/collapse resets) get the celebration burst.
      _prevLevel = level.value;
      _paletteBlend = 0;
      if (newLevel > level.value && state.phase == GamePhase.sweeping) {
        _spawnBurst(paletteForLevel(newLevel).accent);
      }
      level.value = newLevel;
    }

    if (perfectDrops.value != state.perfectDrops) {
      perfectDrops.value = state.perfectDrops;
    }
    if (saves.value != state.saves) {
      if (state.saves > saves.value) {
        _spawnBurst(const Color(0xFF69F0AE), count: 30, yFrac: 0.45);
      }
      saves.value = state.saves;
    }
    if (blocksLost.value != state.blocksLost) {
      blocksLost.value = state.blocksLost;
    }
  }

  @override
  void onRemove() {
    detachTilt();
    phase.dispose();
    score.dispose();
    level.dispose();
    perfectDrops.dispose();
    saves.dispose();
    blocksLost.dispose();
    super.onRemove();
  }
}
