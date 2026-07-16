/// A sliced-off overhang, missed piece, or collapsed block tumbling away.
///
/// Debris is purely cosmetic — it never affects stability or scoring — but it
/// lives in the core so its motion is deterministic and testable, and so the
/// renderer stays a dumb read-only view. Mutable and updated in place by
/// [GameLoop] (zero per-frame allocation).
class Debris {
  Debris({
    required this.centerX,
    required this.bottomY,
    required this.width,
    required this.height,
    required this.vx,
    required this.vy,
    required this.angVel,
    required this.colorIndex,
  });

  double centerX;

  /// World-space Y of the piece's bottom edge at spawn attitude.
  double bottomY;

  final double width;
  final double height;

  /// Tower colour slot this piece fell from, so a fallen block keeps the exact
  /// colour it had while stacked.
  final int colorIndex;

  double vx;
  double vy;

  /// Spin rate (rad/s) and accumulated rotation about the piece's own centre.
  double angVel;
  double rotation = 0;

  double age = 0;
}
