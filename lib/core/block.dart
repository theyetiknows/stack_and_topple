/// One placed block in the tower. Pure world-space data; no rendering concerns.
///
/// The X axis is world-space horizontal, centred on 0. Vertical position is
/// derived from [index] by the renderer (block `i` occupies the vertical band
/// [i*blockHeight, (i+1)*blockHeight]), so the core never deals in pixels or Y.
///
/// [centerX] is MUTABLE: in Loose Stack mode a placed block can slide against
/// the one beneath it, so its horizontal position keeps evolving after the
/// drop. Mutating in place (rather than rebuilding the list) keeps the loop
/// allocation-free, matching the rest of the core.
class Block {
  /// World-space X of the block's horizontal centre.
  double centerX;

  /// Horizontal size (world units).
  final double width;

  /// Stacking index; 0 is the base.
  final int index;

  /// Slide speed RELATIVE to the block directly beneath (world units/s).
  /// Always 0 outside Loose Stack mode.
  double slideVel;

  Block({
    required this.centerX,
    required this.width,
    required this.index,
    this.slideVel = 0,
  });

  double get left => centerX - width / 2;
  double get right => centerX + width / 2;

  Block copyWith({double? centerX, double? width, int? index}) => Block(
        centerX: centerX ?? this.centerX,
        width: width ?? this.width,
        index: index ?? this.index,
      );
}
