# Stack & Topple

A hyper-casual stacking game (V1 / MVP). Tap to drop falling blocks and stack
them as high as you can before the tower topples. Built to produce short,
filmable, shareable runs.

> **Status: Increment B5 — Loose Stack.** The core loop, Balance Mode, and now
> an expert layer on top of it: with **Loose Stack** on, placed blocks are no
> longer welded to the tower — tilting shears the stack like a deck of cards.
> Blocks that slide off cost points, and the run ends only when the tower is
> stripped back to the bare base. Record & share is next.


## Run it

The repo already contains the `android/`, `ios/`, and `web/` platform folders.

```bash
flutter pub get

# On a connected phone (the real feel test):
flutter run

# Or a quick desktop-browser preview:
flutter run -d chrome
```

Requires Flutter (stable, 3.44+). Everything is one codebase (Dart).

## Tuning the feel

**All the feel knobs live in one file:** [`lib/core/tuning.dart`](lib/core/tuning.dart).
Edit a value and hot-reload (press `r` in `flutter run`) to feel the change
instantly, without touching rendering or input. The most important dials:

- `perfectTolerance` — the forgiveness lever: how generous a "perfect" (no-loss)
  drop is. Imperfect drops slice to the exact overlap and the overhang visibly
  falls away as debris.
- `levelSize` / `sweepSpeedPerLevel` — the difficulty graduation: every
  `levelSize` blocks the sweep speed takes a chunky step up.
- `baseSweepSpeed` / `sweepSpeedPerBlock` / `maxSweepSpeed` — starting speed,
  smooth creep, and the cap.
- `restoringStiffness` / `wobbleDamping` — how the tower wobbles and self-rights.
- `toppleThreshold` — how far it can lean before it falls.
- `debrisGravity` / `debrisSpin` — how the sliced-off pieces tumble (cosmetic).

## Balance Mode (opt-in hard mode)

Toggle it in Settings (gear icon). Starting a run then shows a calibration
card: hold the phone the way you want to play and tap — that pose becomes the
neutral baseline (works upright, flat, or lying on a couch). Tilt then DRIVES
the tower's lean on two axes (roll → left/right, pitch → depth, rendered as a
true-feeling 2.5D lean); tilting too far topples it, counter-tilting saves a
leaning stack. When the tower goes critical it sheds its top blocks and shows
SAVE IT! — recover the lean inside the window to continue from the lower
height (+bonus, minus a point per fallen block). Classic mode has no save:
crossing the threshold collapses the whole tower. Motion permission is
requested only at that tap, never at launch.

**Loose Stack** (Settings, requires Balance Mode) replaces the topple-and-save
failure model with continuous erosion: each interface between two blocks slips
once the lean beats its grip (grip rises with the load above it, so the stack
shears from the top down and the base stays planted), a section falls when its
combined centre of mass leaves the block below, and the tower never topples
outright. Key dials: `slipAngle`, `gripPerBlockAbove`, `slideAccelGain`,
`minSupportFraction`, `looseLeanWall`.

Tilt is mapped roughly **1:1**: `tiltMaxAngle` = 45°, so tilting the phone 45°
leans the tower ~45°. Because a tall tower at a steep lean is wider than the
viewport, `StackGame` runs a **dynamic fit camera** in Loose Stack that pans and
zooms to contain the tower (lateral shear + lean rotation + depth projection).
Roughly how fast a 13-block tower erodes at a held lean: 5° ≈ never, 10° ≈ first
loss at 2.4s (stabilises), 15° ≈ stripped in 4.8s, 25° ≈ 1.8s, 45° ≈ instant.

Platform notes:
- **iOS app**: needs `NSMotionUsageDescription` (already in Info.plist).
- **Web on iPhone (Safari)**: works via DeviceMotion — Safari shows its motion
  permission prompt on the calibration tap. Requires HTTPS.
- If tilt feels **inverted** on some device, flip `rollSign` / `pitchSign` in
  `lib/core/tuning.dart` — don't touch the math.
- Key feel dials: `tiltLeanTarget` (how much lean full tilt commands),
  `tiltMaxAngle` (phone angle = full input), `tiltDeadZone`, `tiltSmoothing`,
  `balanceStiffnessFactor` (how lazy self-righting gets in Balance Mode).

## Architecture (short version)

A pure-Dart game core owns all state and feel; everything else is an adapter:

- `lib/core/` — **pure Dart, no Flutter imports.** `GameState` (single source of
  truth), `StabilityModel` (an interface; `CustomStabilityModel` is the V1 impl,
  swappable for a physics-backed one later), `GameLoop`, and `TuningConfig`.
- `lib/input/` — source-agnostic input adapters (tap, and later tilt / test
  scripts). "Drop" and "balance" are just events; Balance Mode is a toggle.
- `lib/game/` — the Flame rendering adapter (`StackGame`, `TowerPainter`).
- `lib/ui/` — the Flutter shell (screen, HUD, start/game-over overlays).

Because the core is pure and deterministic, it is unit-tested headless:

```bash
flutter test
```

See the full architecture plan for the decoupling seams and the V2 extension
points (object sets, environments, gravity modifiers, record/share).
