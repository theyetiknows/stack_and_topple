import 'package:flutter/material.dart';

import '../core/game_state.dart';
import '../core/tuning.dart';

/// Draws the tower from a read-only [GameState] snapshot. Pure presentation: it
/// never mutates game state.
///
/// Rendering is hand-rolled on the canvas (rather than via Flame components) so
/// we own the camera and the tower transform directly. Increment A draws a
/// near-flat side view; the depth (`Lz`) foreshortening that turns this into the
/// 2.5D perspective is a localized addition here in Increment B — the world→screen
/// mapping and the lean pivot are already structured for it.
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

  void paint(Canvas canvas) {
    if (width <= 0 || height <= 0) return;
    final t = tuning;

    // World→screen mapping. Horizontal view spans the sweep range plus a margin.
    final viewWorldWidth = 2 * t.sweepHalfRange + 2.0;
    final scale = width / viewWorldWidth;
    final anchorScreenY = height * 0.62; // where `cameraY` lands on screen

    double sx(double wx) => width / 2 + wx * scale;
    // Higher world-Y renders higher on screen (smaller screen-Y).
    double sy(double wy) => anchorScreenY + (cameraY - wy) * scale;

    // Background + ground.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFF10141C),
    );
    final groundY = sy(0);
    canvas.drawRect(
      Rect.fromLTRB(0, groundY, width, height),
      Paint()..color = const Color(0xFF0B0E14),
    );
    canvas.drawLine(
      Offset(0, groundY),
      Offset(width, groundY),
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 1,
    );

    // The whole tower tilts by the lean angle, pivoting about the base centre.
    // (+lean = leaning right; canvas.rotate is clockwise for +angle in y-down.)
    final pivot = Offset(sx(0), sy(0));
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(state.leanLateral);
    canvas.translate(-pivot.dx, -pivot.dy);

    // Placed blocks, base upward.
    for (final b in state.tower) {
      final bottomY = b.index * t.blockHeight;
      final topY = bottomY + t.blockHeight;
      _drawBlock(
        canvas,
        Rect.fromLTRB(sx(b.left), sy(topY), sx(b.right), sy(bottomY)),
        b.index,
        active: false,
      );
    }

    // The sweeping piece hovers one block-height above the current top.
    if (state.phase == GamePhase.sweeping) {
      final bottomY = (state.blocksPlaced + 1) * t.blockHeight;
      final topY = bottomY + t.blockHeight;
      _drawBlock(
        canvas,
        Rect.fromLTRB(
            sx(state.pieceLeft), sy(topY), sx(state.pieceRight), sy(bottomY)),
        state.blocksPlaced + 1,
        active: true,
      );
    }

    canvas.restore();
  }

  void _drawBlock(Canvas canvas, Rect rect, int index, {required bool active}) {
    final hue = (200 + index * 16) % 360;
    final fill = HSVColor.fromAHSV(1, hue.toDouble(), 0.45, active ? 0.98 : 0.86)
        .toColor();
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (active) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
}
