# Stack & Topple

A hyper-casual stacking game (V1 / MVP). Tap to drop falling blocks and stack
them as high as you can before the tower topples. Built to produce short,
filmable, shareable runs.

> **Status: Increment A — core-feel prototype.** Tap-to-drop + stacking + wobble
> + topple, on the lateral (left/right) axis, with every feel constant exposed
> for tuning. Balance Mode (tilt / depth axis), record & share, and the full
> settings shell come in later increments — see `docs`/the architecture plan.

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

- `shrinkFactor` — the forgiveness slider: `1.0` = hard "slice to the overlap"
  (fast, unforgiving), `0.0` = no shrink (mistakes only add wobble).
- `perfectTolerance` — how generous a "perfect" (no-loss) drop is.
- `restoringStiffness` / `wobbleDamping` — how the tower wobbles and self-rights.
- `toppleThreshold` — how far it can lean before it falls.
- `baseSweepSpeed` / `sweepSpeedPerBlock` — starting difficulty and the ramp.

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
