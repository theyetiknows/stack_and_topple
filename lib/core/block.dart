/// One placed block in the tower. Pure world-space data; no rendering concerns.
///
/// The X axis is world-space horizontal, centred on 0. Vertical position is
/// derived from [index] by the renderer (block `i` occupies the vertical band
/// [i*blockHeight, (i+1)*blockHeight]), so the core never deals in pixels or Y.
class Block {
  /// World-space X of the block's horizontal centre.
  final double centerX;

  /// Horizontal size (world units).
  final double width;

  /// Stacking index; 0 is the base.
  final int index;

  const Block({
    required this.centerX,
    required this.width,
    required this.index,
  });

  double get left => centerX - width / 2;
  double get right => centerX + width / 2;

  Block copyWith({double? centerX, double? width, int? index}) => Block(
        centerX: centerX ?? this.centerX,
        width: width ?? this.width,
        index: index ?? this.index,
      );
}
