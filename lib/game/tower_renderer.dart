import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/debris.dart';
import '../core/game_state.dart';
import '../core/tuning.dart';

/// One sky/world colour scheme. Levels cycle through [kLevelPalettes], so
/// every graduation lands the player in a visibly new world.
class LevelPalette {
  const LevelPalette(this.top, this.bottom, this.accent);
  final Color top;
  final Color bottom;
  final Color accent;
}

/// Curated dark-friendly palettes, cycled by `level % length`. The accent
/// tints the halo and the level-up confetti.
const List<LevelPalette> kLevelPalettes = [
  LevelPalette(Color(0xFF131A2E), Color(0xFF23304F), Color(0xFF7C9EFF)), // indigo night
  LevelPalette(Color(0xFF0E2426), Color(0xFF14524E), Color(0xFF4DD0C7)), // teal dawn
  LevelPalette(Color(0xFF2A1230), Color(0xFF66323F), Color(0xFFFF8A65)), // sunset ember
  LevelPalette(Color(0xFF10241A), Color(0xFF2F5D3A), Color(0xFF81C784)), // forest dusk
  LevelPalette(Color(0xFF1B1030), Color(0xFF45276B), Color(0xFFB388FF)), // royal violet
  LevelPalette(Color(0xFF260F17), Color(0xFF6E2438), Color(0xFFFF5C8A)), // crimson sky
  LevelPalette(Color(0xFF241B0C), Color(0xFF6B4A1F), Color(0xFFFFD54F)), // golden hour
  LevelPalette(Color(0xFF0E1E2A), Color(0xFF275D75), Color(0xFF4FC3F7)), // arctic
];

LevelPalette paletteForLevel(int level) =>
    kLevelPalettes[level % kLevelPalettes.length];

/// Draws the tower from a read-only [GameState] snapshot. Pure presentation: it
/// never mutates game state.
///
/// The look is a hand-rolled pseudo-3D: each block is a lit front face plus a
/// highlighted top and shaded side face receding up-right. The DEPTH lean (Lz,
/// Balance Mode) projects onto that same receding diagonal. Debris tumbles as
/// full 3D blocks (same three faces), keeping its stacked colour, and stays
/// solid until the tail of its lifetime.
class TowerPainter {
  TowerPainter({
    required this.state,
    required this.tuning,
    required this.cameraY,
    required this.cameraX,
    required this.viewHalfWidth,
    required this.width,
    required this.height,
    required this.prevLevel,
    required this.paletteBlend,
  });

  final GameState state;
  final TuningConfig tuning;

  /// Smoothed world-Y the camera is centred on (follows the tower up).
  final double cameraY;

  /// Smoothed world-X the camera is centred on. Non-zero only in Loose Stack,
  /// where a sheared tower would otherwise walk straight off the screen edge.
  final double cameraX;

  /// World units visible either side of [cameraX]. [kDefaultViewHalfWidth]
  /// normally; the fit camera widens it so a tower leaning up to 45° still
  /// fits on screen.
  final double viewHalfWidth;
  final double width;
  final double height;

  /// Sky crossfade: the palette eases from [prevLevel]'s to the current
  /// level's as [paletteBlend] runs 0→1 (driven by StackGame).
  final int prevLevel;
  final double paletteBlend;

  // Screen direction (unit-ish) in which the pseudo-3D depth recedes.
  static const double depthDirX = 0.78;
  static const double _depthDirY = -0.52;

  /// The framing used whenever the tower is upright: the full sweep range
  /// plus a block's worth of margin.
  static double defaultViewHalfWidth(TuningConfig t) =>
      t.sweepHalfRange + 1.0;

  late final double _scale = width / (2 * viewHalfWidth);
  late final double _anchorScreenY = height * 0.62;
  late final double _depthPx = tuning.visualBlockDepth * _scale;

  double _sx(double wx) => width / 2 + (wx - cameraX) * _scale;
  // Higher world-Y renders higher on screen (smaller screen-Y).
  double _sy(double wy) => _anchorScreenY + (cameraY - wy) * _scale;

  /// World-space displacement along the depth diagonal for a point at world
  /// height [hWorld], given the current depth lean. Static so the fit camera
  /// can budget for the same displacement it is about to draw.
  static double depthShiftWorld(
    double hWorld,
    double leanDepth,
    TuningConfig t,
  ) =>
      math.sin(leanDepth) * hWorld * t.depthLeanVisualGain;

  double _depthShiftWorld(double hWorld) =>
      depthShiftWorld(hWorld, state.leanDepth, tuning);

  void paint(Canvas canvas) {
    if (width <= 0 || height <= 0) return;

    _paintSky(canvas);
    _paintGround(canvas);

    // The whole tower tilts by the LATERAL lean angle, pivoting about the base
    // centre. (+lean = leaning right; canvas.rotate is clockwise in y-down.)
    final pivot = Offset(_sx(0), _sy(0));
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(state.leanLateral);
    canvas.translate(-pivot.dx, -pivot.dy);

    // Placed blocks, base upward (higher blocks correctly occlude the top
    // faces of the ones beneath them).
    for (final b in state.tower) {
      final isTop = identical(b, state.tower.last);
      // Landing squash: the just-placed block compresses and springs back.
      var blockH = tuning.blockHeight;
      if (isTop && state.dropBounceTimer > 0 && state.blocksPlaced > 0) {
        final p = (state.dropBounceTimer / tuning.dropBounceDuration)
            .clamp(0.0, 1.0);
        blockH *= 1 - 0.22 * p;
      }
      final bottomY = b.index * tuning.blockHeight;
      _drawLeanedBlock(
        canvas,
        centerX: b.centerX,
        width: b.width,
        bottomY: bottomY,
        blockH: blockH,
        index: b.index,
        active: false,
      );
    }

    // The sweeping piece hovers one block-height above the current top. It
    // stays in the un-leaned aiming plane on purpose: it is the reference the
    // player is lining up against.
    if (state.phase == GamePhase.sweeping) {
      final bottomY = (state.blocksPlaced + 1) * tuning.blockHeight;
      _drawLeanedBlock(
        canvas,
        centerX: state.pieceCenterX,
        width: state.pieceWidth,
        bottomY: bottomY,
        blockH: tuning.blockHeight,
        index: state.blocksPlaced + 1,
        active: true,
      );
    }

    // PERFECT: an expanding ring pulsing out of the just-placed block.
    if (state.perfectFlashTimer > 0 && state.tower.isNotEmpty) {
      final p = (state.perfectFlashTimer / tuning.perfectFlashDuration)
          .clamp(0.0, 1.0);
      final top = state.tower.last;
      final c = Offset(
        _sx(top.centerX),
        _sy(top.index * tuning.blockHeight + tuning.blockHeight / 2),
      );
      canvas.drawCircle(
        c,
        (1 - p) * _scale * 2.2 + _scale * 0.4,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55 * p)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + 5 * p,
      );
    }

    canvas.restore();

    // Debris is detached from the tower, so it is drawn OUTSIDE the lean
    // transform, tumbling in plain world space.
    for (final d in state.debris) {
      _drawDebris(canvas, d);
    }

    // SAVE window: pulsing red edge glow + a countdown bar so the player can
    // SEE the clock they are fighting. Driven by the deterministic save
    // timer, not wall-clock.
    if (state.phase == GamePhase.critical) {
      final pulse = 0.28 + 0.18 * math.sin(state.saveWindowTimer * 12).abs();
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height).deflate(3),
        Paint()
          ..color = const Color(0xFFFF5252).withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      final frac =
          (state.saveWindowTimer / tuning.saveWindow).clamp(0.0, 1.0);
      final barMax = width * 0.56;
      final barY = height * 0.30;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(width / 2, barY), width: barMax, height: 7),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(width / 2, barY),
              width: barMax * frac,
              height: 7),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.95),
      );
    }
  }

  /// Draws one tower block with the depth-lean projection applied.
  void _drawLeanedBlock(
    Canvas canvas, {
    required double centerX,
    required double width,
    required double bottomY,
    required double blockH,
    required int index,
    required bool active,
  }) {
    final dz = _depthShiftWorld(bottomY + blockH / 2);
    final dxPx = dz * _scale * depthDirX;
    final dyPx = dz * _scale * _depthDirY;
    // Foreshorten: receding blocks narrow slightly, approaching ones widen.
    final ws = (1 - dz * tuning.depthForeshorten).clamp(0.55, 1.45).toDouble();
    final halfW = width * ws / 2;
    final front = Rect.fromLTRB(
      _sx(centerX - halfW) + dxPx,
      _sy(bottomY + blockH) + dyPx,
      _sx(centerX + halfW) + dxPx,
      _sy(bottomY) + dyPx,
    );
    final shade = dz > 0 ? math.min(tuning.depthShade, dz * 0.12) : 0.0;
    _drawBlock3D(canvas, front, index, active: active, shadeAlpha: shade);
  }

  // --- Sky / ground -----------------------------------------------------------

  void _paintSky(Canvas canvas) {
    // Each level is a distinct world colour; boundaries crossfade over
    // paletteBlend. Slight overdraw hides camera-shake edges.
    final from = paletteForLevel(prevLevel);
    final to = paletteForLevel(state.level);
    final topColor = Color.lerp(from.top, to.top, paletteBlend)!;
    final bottomColor = Color.lerp(from.bottom, to.bottom, paletteBlend)!;
    final accent = Color.lerp(from.accent, to.accent, paletteBlend)!;

    final rect = Rect.fromLTWH(-16, -16, width + 32, height + 32);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ).createShader(rect),
    );

    // A faint accent-tinted halo keeps the action area luminous.
    final haloCenter = Offset(width / 2, _anchorScreenY - height * 0.08);
    canvas.drawCircle(
      haloCenter,
      width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: haloCenter, radius: width * 0.55),
        ),
    );
  }

  void _paintGround(Canvas canvas) {
    final groundY = _sy(0);
    if (groundY > height + 16) return;
    final rect = Rect.fromLTRB(-16, groundY, width + 16, height + 16);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF0A0D13), const Color(0xFF06080C)],
        ).createShader(rect),
    );
    // Soft contact shadow under the base block.
    if (state.tower.isNotEmpty) {
      final base = state.tower.first;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(_sx(base.centerX) + _depthPx * 0.4, groundY + 4),
          width: (base.width * _scale) * 1.25,
          height: 12,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
  }

  // --- Blocks -------------------------------------------------------------------

  Color _blockColor(int index, {required bool active}) {
    final hue = (200 + index * 14) % 360;
    return HSVColor.fromAHSV(1, hue.toDouble(), 0.48, active ? 0.98 : 0.88)
        .toColor();
  }

  /// Front face at [front], with top and right faces receding by [_depthPx]
  /// toward the upper-right — the pseudo-3D that makes the stack feel solid.
  /// [opacity] < 1 is used only by end-of-life debris fade.
  void _drawBlock3D(
    Canvas canvas,
    Rect front,
    int index, {
    required bool active,
    double shadeAlpha = 0,
    double opacity = 1,
  }) {
    final base =
        _blockColor(index, active: active).withValues(alpha: opacity);
    final topFace =
        Color.lerp(base, Colors.white, 0.32)!.withValues(alpha: opacity);
    final sideFace =
        Color.lerp(base, Colors.black, 0.34)!.withValues(alpha: opacity);
    final dx = _depthPx * depthDirX;
    final dy = _depthPx * _depthDirY;

    // Top face.
    canvas.drawPath(
      Path()
        ..moveTo(front.left, front.top)
        ..lineTo(front.left + dx, front.top + dy)
        ..lineTo(front.right + dx, front.top + dy)
        ..lineTo(front.right, front.top)
        ..close(),
      Paint()..color = topFace,
    );
    // Right side face.
    canvas.drawPath(
      Path()
        ..moveTo(front.right, front.top)
        ..lineTo(front.right + dx, front.top + dy)
        ..lineTo(front.right + dx, front.bottom + dy)
        ..lineTo(front.right, front.bottom)
        ..close(),
      Paint()..color = sideFace,
    );
    // Front face last so it crisply overlaps the receding faces.
    canvas.drawRect(front, Paint()..color = base);
    // Subtle front-face vertical shading for volume.
    canvas.drawRect(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.10 * opacity),
            Colors.black.withValues(alpha: 0.12 * opacity),
          ],
        ).createShader(front),
    );
    // Depth-lean shading: receding blocks darken toward the horizon.
    if (shadeAlpha > 0) {
      canvas.drawRect(
        front,
        Paint()..color = Colors.black.withValues(alpha: shadeAlpha * opacity),
      );
    }
    if (active) {
      canvas.drawRect(
        front,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawDebris(Canvas canvas, Debris d) {
    final w = d.width * _scale;
    final h = d.height * _scale;
    final center = Offset(_sx(d.centerX), _sy(d.bottomY + d.height / 2));

    // Solid for most of its life; fade only in the last quarter so culling is
    // invisible but the wreckage never looks ghostly.
    final lifeFrac = (d.age / tuning.debrisLifetime).clamp(0.0, 1.0);
    final opacity =
        lifeFrac < 0.75 ? 1.0 : (1 - (lifeFrac - 0.75) / 0.25).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(d.rotation);
    final front = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    // Same three-face 3D block as the tower, keeping its stacked colour.
    _drawBlock3D(canvas, front, d.colorIndex, active: false, opacity: opacity);
    canvas.restore();
  }
}
