# Stack & Topple

A hyper-casual stacking game (V1 / MVP). Tap to drop falling blocks and stack
them as high as you can before the tower topples. Built to produce short,
filmable, shareable runs.

> **Status: Increment B — Balance Mode + haptics.** The core loop (tap-drop,
> exact-overlap slicing with falling debris, level-stepped difficulty,
> pseudo-3D look) plus the opt-in tilt hard mode: calibrate to your holding
> pose, then tilt to steady — or topple — the tower on BOTH the lateral and the
> depth axis. Haptics throughout. Record & share is the next increment.

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
leaning stack. Motion permission is requested only at that tap, never at
launch.

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
