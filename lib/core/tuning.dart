/// Centralised, tunable constants for the game *feel*.
///
/// This is the single place to dial wobble, topple, forgiveness, difficulty and
/// scoring. Nothing here imports Flutter or Flame — it is pure data — so it is
/// hot-reloadable and unit-testable. Every value below is an initial guess meant
/// to be tuned on-device together; the names and comments explain intent.
///
/// Axis convention for the 2.5D design:
///   - "lateral" = left/right in screen space  (Lx) — active in the base game.
///   - "depth"   = toward/away from camera      (Lz) — driven by Balance Mode.
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
  // ANGLE (radians), independently per axis. Per tick:
  //   a = -k*lean - c*leanVel (+ balance force);  integrate.
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

  /// Lean magnitude ‖(Lx, Lz)‖ beyond this (radians) topples the tower.
  /// ~0.38 rad ≈ 22°. (With Balance OFF, Lz is always 0, so this is just |Lx|.)
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
  // Balance Mode — tilt input shaping (TiltProcessor)
  //
  // All tilt is measured as DEVIATION FROM A CALIBRATED BASELINE (the pose the
  // player holds at run start), never from true horizontal — so it works lying
  // on a couch. Angles are normalised so that [tiltMaxAngle] radians of
  // deviation = full input (±1).
  // ---------------------------------------------------------------------------

  /// The lean (radians) the tower is DRIVEN TOWARD at full roll input: tilt
  /// shifts the tower's equilibrium, it does not just nudge it. Set ABOVE
  /// [toppleThreshold] so that, per the spec, holding a too-far tilt topples
  /// the tower — and counter-tilting can pull a leaning tower back upright.
  final double tiltLeanTarget;

  /// Same, for pitch driving the DEPTH lean. Kept gentler than roll: the depth
  /// axis is threatened only by the player's wrist, so it gets extra
  /// forgiveness — but still above threshold so extreme pitch topples.
  final double tiltLeanTargetPitch;

  /// Ignore normalised tilt inputs smaller than this (dead-zone) to kill jitter.
  final double tiltDeadZone;

  /// Deviation angle (radians) that maps to full input. ~0.35 rad ≈ 20°.
  final double tiltMaxAngle;

  /// Low-pass smoothing factor per sensor sample (0..1; higher = snappier).
  final double tiltSmoothing;

  /// Number of sensor samples averaged to set the calibration baseline.
  final int calibrationSamples;

  /// Sign flips for platform quirks. If tilt feels inverted on a device, flip
  /// the corresponding constant to -1 — do not touch the math.
  final double rollSign;
  final double pitchSign;

  // ---------------------------------------------------------------------------
  // Balance Mode — how tilt reshapes the stability game
  //
  // With Balance ON the tower self-rights far more lazily, so the player's
  // hand becomes the main stabilising force: tense, but recoverable.
  // ---------------------------------------------------------------------------

  /// Multiplier on [restoringStiffness] while Balance Mode is active (<1 =
  /// lazier self-righting = the player's tilt matters more).
  final double balanceStiffnessFactor;

  /// Multiplier on [wobbleDamping] while Balance Mode is active.
  final double balanceDampingFactor;

  // ---------------------------------------------------------------------------
  // Balance Mode — depth-lean presentation (pseudo-3D projection of Lz)
  // ---------------------------------------------------------------------------

  /// How far (world units per world unit of height) blocks displace along the
  /// pseudo-3D depth diagonal per radian of depth lean. Purely visual.
  final double depthLeanVisualGain;

  /// How much receding blocks narrow per world unit of depth displacement.
  final double depthForeshorten;

  /// Max darkening overlay (0..1 alpha) on fully receding blocks.
  final double depthShade;

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
    this.tiltLeanTarget = 0.55,
    this.tiltLeanTargetPitch = 0.46,
    this.tiltDeadZone = 0.06,
    this.tiltMaxAngle = 0.35,
    this.tiltSmoothing = 0.22,
    this.calibrationSamples = 15,
    this.rollSign = 1.0,
    this.pitchSign = 1.0,
    this.balanceStiffnessFactor = 0.45,
    this.balanceDampingFactor = 0.8,
    this.depthLeanVisualGain = 1.0,
    this.depthForeshorten = 0.055,
    this.depthShade = 0.35,
    this.perfectBonus = 2,
  });
}

/// The default tuning used by the app. Tests can construct their own variants.
const TuningConfig defaultTuning = TuningConfig();
