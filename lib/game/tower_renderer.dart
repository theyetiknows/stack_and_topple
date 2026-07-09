import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/debris.dart';
import '../core/game_state.dart';
import '../core/tuning.dart';

/// Draws the tower from a read-only [GameState] snapshot. Pure presentation: it
/// never mutates game state.
///
/// The look is a hand-rolled pseudo-3D: each block is a lit front face plus a
/// highlighted top and shaded side face receding up-right. The DEPTH lean (Lz,
/// Balance Mode) projects onto that same receding diagonal: blocks displace
/// along it with height, narrow slightly (foreshortening) and darken as they
/// recede — so a depth topple visibly falls "into" or "out of" the screen.
class TowerPainter {
  TowerPainter({
    required this.state,
    required this.tuning,
    required this.cameraY,
    required this.width,
    required this.height,
  });

  final GameState state;
  final TuningConfig tuning;

  /// Smoothed world-Y the camera is centred on (follows the tower up).
  final double cameraY;
  final double width;
  final double height;

  // Screen direction (unit-ish) in which the pseudo-3D depth recedes.
  static const double _depthDirX = 0.78;
  static const double _depthDirY = -0.52;

  late final double _scale = width / (2 * tuning.sweepHalfRange + 2.0);
  late final double _anchorScreenY = height * 0.62;
  late final double _depthPx = tuning.visualBlockDepth * _scale;

  double _sx(double wx) => width / 2 + wx * _scale;
  // Higher world-Y renders higher on screen (smaller screen-Y).
  double _sy(double wy) => _anchorScreenY + (cameraY - wy) * _scale;

  /// World-space displacement along the depth diagonal for a point at world
  /// height [hWorld], given the current depth lean (sin keeps the topple
  /// animation bounded as the angle grows).
  double _depthShiftWorld(double hWorld) =>
      math.sin(state.leanDepth) * hWorld * tuning.depthLeanVisualGain;

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
    final dxPx = dz * _scale * _depthDirX;
    final dyPx = dz * _scale * _depthDirY;
    // Foreshorten: receding blocks narrow slightly, approaching ones widen.
    final ws =
        (1 - dz * tuning.depthForeshorten).clamp(0.55, 1.45).toDouble();
    final halfW = width * ws / 2;
    final front = Rect.fromLTRB(
      _sx(centerX - halfW) + dxPx,
      _sy(bottomY + blockH) + dyPx,
      _sx(centerX + halfW) + dxPx,
      _sy(bottomY) + dyPx,
    );
    final shade =
        dz > 0 ? math.min(tuning.depthShade, dz * 0.12) : 0.0;
    _drawBlock3D(canvas, front, index, active: active, shadeAlpha: shade);
  }

  // --- Sky / ground -----------------------------------------------------------

  void _paintSky(Canvas canvas) {
    // Hue drifts continuously with height; level steps are felt through speed
    // while the sky records the climb. Slight overdraw hides camera-shake edges.
    final rect = Rect.fromLTWH(-16, -16, width + 32, height + 32);
    final hue = (222 + state.blocksPlaced * 3.0) % 360;
    final topColor = HSVColor.fromAHSV(1, hue, 0.55, 0.13).toColor();
    final bottomColor =
        HSVColor.fromAHSV(1, (hue + 34) % 360, 0.42, 0.30).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, bottomColor],
        ).createShader(rect),
    );

    // A faint halo behind the tower keeps the action area luminous.
    canvas.drawCircle(
      Offset(width / 2, _anchorScreenY - height * 0.08),
      width * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(width / 2, _anchorScreenY - height * 0.08),
            radius: width * 0.55,
          ),
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
  void _drawBlock3D(
    Canvas canvas,
    Rect front,
    int index, {
    required bool active,
    double shadeAlpha = 0,
  }) {
    final base = _blockColor(index, active: active);
    final topFace = Color.lerp(base, Colors.white, 0.32)!;
    final sideFace = Color.lerp(base, Colors.black, 0.34)!;
    final dx = _depthPx * _depthDirX;
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
            Colors.white.withValues(alpha: 0.10),
            Colors.black.withValues(alpha: 0.12),
          ],
        ).createShader(front),
    );
    // Depth-lean shading: receding blocks darken toward the horizon.
    if (shadeAlpha > 0) {
      canvas.drawRect(
        front,
        Paint()..color = Colors.black.withValues(alpha: shadeAlpha),
      );
    }
    if (active) {
      canvas.drawRect(
        front,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawDebris(Canvas canvas, Debris d) {
    final w = d.width * _scale;
    final h = d.height * _scale;
    final center = Offset(_sx(d.centerX), _sy(d.bottomY + d.height / 2));
    // Fade out near end-of-life so culling is invisible.
    final life = 1 - (d.age / tuning.debrisLifetime);
    final alpha = life.clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(d.rotation);
    final front = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    final base = _blockColor(state.blocksPlaced + 1, active: false)
        .withValues(alpha: alpha);
    canvas.drawRect(front, Paint()..color = base);
    canvas.drawRect(
      front,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25 * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }
}
