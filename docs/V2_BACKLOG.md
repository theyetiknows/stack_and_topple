# V2 Backlog — captured ideas, NOT in V1

V1 stays tight: core loop → Balance Mode → record/share → polish. Everything
here is deliberately deferred, but each item already has an architecture seam,
so nothing being built today blocks it.

## From playtest feedback (2026-07)

| Idea | Where it plugs in | Notes |
|---|---|---|
| **Diverse piece shapes** (non-rectangles, varied sizes) | `PieceFactory` in `lib/game/` + `Block`/overlap logic generalised to shape footprints | Biggest ripple: drop resolution currently assumes rectangles. Worth a design pass on what "overlap" means per shape before building. |
| **Power-ups** (e.g. widen platform, slow sweep, steady-hand) | New `PowerUpSystem` consuming `InputEvent`s + a rule hook in `StabilityModel`/`GameLoop` | Also a monetisation surface later. Needs a product pass on earn vs. buy. |
| **Selectable backgrounds / environments** | `EnvironmentTheme` provider (planned seam) feeding `TowerPainter` sky/ground/palette | V1 already ships a height-evolving gradient; themes would swap palettes & motifs. Natural pairing with the settings screen. |
| **"Levels" as content** (distinct stages, not just speed tiers) | Level system now exists (`TuningConfig.levelSize` + `GameState.level`); content levels would attach themes/shapes/modifiers per level | V1 treats levels as difficulty graduations only. |

## From the original scope

- Gravity/physics modifiers → rule hook in `StabilityModel` (V1 = identity).
- Physics-backed stability (`Forge2DStabilityModel`) / richer collapse tumble →
  swap behind the `StabilityModel` interface; `CollapseSimulator` seam.
- Leaderboards / accounts / ads / IAP → out of architecture entirely for now.

## Tuning ideas parked (cheap, but gated on feel review)

- Perfect-streak reward: platform regrows slightly on consecutive perfects
  (classic Stack mechanic; one constant + 3 lines in `GameLoop`).
- Combo multiplier on perfect streaks (scoring juice for shareable big numbers).
