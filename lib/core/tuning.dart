/// Centralised, tunable constants for the game *feel*.
///
/// This is the single place to dial wobble, topple, forgiveness, difficulty and
/// scoring. Nothing here imports Flutter or Flame — it is pure data — so it is
/// hot-reloadable and unit-testable. Every value below is an initial guess meant
/// to be tuned on-device together; the names and comments explain intent.
///
/// Axis convention for the 2.5D design:
///   - "lateral" = left/right in screen space  (Lx) — active in the base game.
///   - "depth"   = toward/away from camera      (Lz) — dormant until Balance Mode.
/// Increment A only exercises the lateral axis.
class TuningConfig {
  // ---------------------------------------------------------------------------
  // Piece sweep & difficulty ramp
  // ---------------------------------------------------------------------------

  /// Vertical size of every block, in world units. Rendering maps this to pixels.
  final double blockHeight;

  /// Width of the starting platform (the base block).
  final double initialBlockWidth;

  /// The sweeping piece's centre oscillates within [-sweepHalfRange, +sweepHalfRange].
  final double sweepHalfRange;

  /// Horizontal sweep speed (world units / second) at the very bottom.
  final double baseSweepSpeed;

  /// Added sweep speed for each successfully placed block — the tension ramp.
  final double sweepSpeedPerBlock;

  /// Hard cap on sweep speed so it never becomes literally untappable.
  final double maxSweepSpeed;

  // ---------------------------------------------------------------------------
  // Drop resolution & "forgiveness" (the core feel knob)
  // ---------------------------------------------------------------------------

  /// |misalignment| <= this counts as a PERFECT drop: no platform loss, no lean
  /// kick, and a score bonus. Bigger = more forgiving / easier to feel good.
  final double perfectTolerance;

  /// How much of the overhang is sliced off the platform on an imperfect drop.
  ///   1.0 = hard Ketchapp-style (new platform == overlap, unforgiving, fast death)
  ///   0.0 = no shrink at all    (pure wobble mode — mistakes only add lean)
  /// This single value slides us between the two "forgiveness" philosophies the
  /// plan flagged as a product decision. Default is a deliberate blend.
  final double shrinkFactor;

  /// If a drop leaves the platform narrower than this, the tower fails structurally.
  final double minPlatformWidth;

  // ---------------------------------------------------------------------------
  // Lean / wobble dynamics
  //
  // The tower's lean is modelled as a damped harmonic oscillator on the tilt
  // ANGLE (radians). Per tick:  a = -k*lean - c*leanVel (+ balance);  integrate.
  // ---------------------------------------------------------------------------

  /// Spring stiffness k: how strongly the tower self-rights toward upright.
  /// Higher = snappier recovery, more forgiving.
  final double restoringStiffness;

  /// Damping c: how fast wobble energy bleeds off. Higher = fewer oscillations.
  final double wobbleDamping;

  /// Angular-velocity kick (rad/s) per unit of NORMALISED misalignment on a drop.
  /// (normalised = misalign / currentPlatformWidth, so tighter towers punish more.)
  final double dropKickGain;

  /// Instantaneous lean (rad) added per unit of normalised misalignment on a drop.
  final double leanOffsetGain;

  // ---------------------------------------------------------------------------
  // Topple
  // ---------------------------------------------------------------------------

  /// |lean| beyond this (radians) topples the tower. ~0.38 rad ≈ 22°.
  final double toppleThreshold;

  /// Seconds of "falling over" animation before the run ends (juice).
  final double toppleAnimDuration;

  /// Angular acceleration (rad/s^2) applied during the topple animation.
  final double toppleFallAccel;

  // ---------------------------------------------------------------------------
  // Balance Mode (Increment B — unused in A, listed here so all dials live together)
  // ---------------------------------------------------------------------------

  /// How strongly tilt deviation pushes the lean.
  final double tiltGain;

  /// Ignore tilt deviations smaller than this (dead-zone) to kill jitter.
  final double tiltDeadZone;

  // ---------------------------------------------------------------------------
  // Scoring
  // ---------------------------------------------------------------------------

  /// Extra points awarded for a perfect drop (on top of the +1 for placing).
  final int perfectBonus;

  const TuningConfig({
    this.blockHeight = 1.0,
    this.initialBlockWidth = 3.2,
    this.sweepHalfRange = 3.6,
    this.baseSweepSpeed = 4.2,
    this.sweepSpeedPerBlock = 0.14,
    this.maxSweepSpeed = 11.0,
    this.perfectTolerance = 0.18,
    this.shrinkFactor = 0.55,
    this.minPlatformWidth = 0.5,
    this.restoringStiffness = 42.0,
    this.wobbleDamping = 5.5,
    this.dropKickGain = 0.9,
    this.leanOffsetGain = 0.06,
    this.toppleThreshold = 0.38,
    this.toppleAnimDuration = 1.1,
    this.toppleFallAccel = 9.0,
    this.tiltGain = 2.2,
    this.tiltDeadZone = 0.03,
    this.perfectBonus = 2,
  });
}

/// The default tuning used by the app. Tests can construct their own variants.
const TuningConfig defaultTuning = TuningConfig();
