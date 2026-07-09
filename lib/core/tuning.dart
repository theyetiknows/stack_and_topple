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
class TuningConfig {
  // ---------------------------------------------------------------------------
  // Piece sweep & difficulty ramp
  //
  // Difficulty graduates in LEVELS: every [levelSize] placed blocks the sweep
  // speed takes a noticeable step up (sweepSpeedPerLevel), on top of a small
  // per-block creep (sweepSpeedPerBlock). The background also evolves with
  // height so each graduation visibly reads as a new tier.
  // ---------------------------------------------------------------------------

  /// Vertical size of every block, in world units. Rendering maps this to pixels.
  final double blockHeight;

  /// Visual depth of a block (world units) for the pseudo-3D faces. Presentation
  /// only — it never affects collision or stability.
  final double visualBlockDepth;

  /// Width of the starting platform (the base block).
  final double initialBlockWidth;

  /// The sweeping piece's centre oscillates within [-sweepHalfRange, +sweepHalfRange].
  final double sweepHalfRange;

  /// Horizontal sweep speed (world units / second) at the very bottom.
  final double baseSweepSpeed;

  /// Small added sweep speed for each successfully placed block (smooth creep).
  final double sweepSpeedPerBlock;

  /// Blocks per difficulty level.
  final int levelSize;

  /// Chunky speed step added at each level boundary — the felt "graduation".
  final double sweepSpeedPerLevel;

  /// Hard cap on sweep speed so it never becomes literally untappable.
  final double maxSweepSpeed;

  // ---------------------------------------------------------------------------
  // Drop resolution & forgiveness
  //
  // Imperfect drops slice the piece to the EXACT overlap with the platform: the
  // kept part stays precisely where the piece landed and the overhang breaks
  // off as visible falling debris. Forgiveness therefore lives in
  // [perfectTolerance] (how generous a "no-loss" drop is), not in a shrink blend.
  // ---------------------------------------------------------------------------

  /// |misalignment| <= this counts as a PERFECT drop: no slice, no lean kick,
  /// snap to alignment, and a score bonus. Bigger = more forgiving.
  final double perfectTolerance;

  /// If a slice leaves the platform narrower than this, the tower fails
  /// structurally and topples.
  final double minPlatformWidth;

  // ---------------------------------------------------------------------------
  // Sliced-debris cosmetics (the falling cut-off). Purely visual: debris never
  // affects stability. World-space kinematics, deterministic.
  // ---------------------------------------------------------------------------

  /// Downward acceleration on debris (world units / s^2).
  final double debrisGravity;

  /// Sideways drift given to a sliced overhang, away from the tower.
  final double debrisKickVx;

  /// Initial spin (rad/s), signed away from the tower.
  final double debrisSpin;

  /// Seconds a debris piece lives before being culled (it is off-screen long
  /// before this; lifetime culling keeps the core camera-agnostic).
  final double debrisLifetime;

  /// Pause after a total miss so the player watches the piece fall before the
  /// game-over card appears.
  final double missEndDelay;

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
  // Feedback / effects timers (presentation reads these; core just counts down)
  // ---------------------------------------------------------------------------

  /// Duration of the expanding PERFECT ring/flash.
  final double perfectFlashDuration;

  /// Duration of the landing squash on the just-placed block.
  final double dropBounceDuration;

  /// Duration of the small camera shake after an imperfect drop.
  final double impactShakeDuration;

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
    this.visualBlockDepth = 0.55,
    this.initialBlockWidth = 3.2,
    this.sweepHalfRange = 3.6,
    this.baseSweepSpeed = 4.2,
    this.sweepSpeedPerBlock = 0.10,
    this.levelSize = 5,
    this.sweepSpeedPerLevel = 0.9,
    this.maxSweepSpeed = 13.0,
    this.perfectTolerance = 0.18,
    this.minPlatformWidth = 0.5,
    this.debrisGravity = 26.0,
    this.debrisKickVx = 1.4,
    this.debrisSpin = 3.2,
    this.debrisLifetime = 2.5,
    this.missEndDelay = 0.9,
    this.restoringStiffness = 42.0,
    this.wobbleDamping = 5.5,
    this.dropKickGain = 0.9,
    this.leanOffsetGain = 0.06,
    this.toppleThreshold = 0.38,
    this.toppleAnimDuration = 1.1,
    this.toppleFallAccel = 9.0,
    this.perfectFlashDuration = 0.55,
    this.dropBounceDuration = 0.16,
    this.impactShakeDuration = 0.28,
    this.tiltGain = 2.2,
    this.tiltDeadZone = 0.03,
    this.perfectBonus = 2,
  });
}

/// The default tuning used by the app. Tests can construct their own variants.
const TuningConfig defaultTuning = TuningConfig();
