# flame_showcase

Demos + benchmarks for **Level Up your Flutter Apps with Flame** (Flutter South India 2026).
Plan: `PLAN.md`. Specs: `../demos.md`.

## Run
```bash
flutter pub get
flutter run -d macos --profile        # or -d <phone>
```
Always measure in **profile** (or release) mode, never debug.

## Benchmarks
- Home → speedometer icon next to a demo runs that suite; **Run all benchmarks** runs everything (~9 min, don't touch the window).
- Each scenario: 2 s warm-up + 6 s measured, scripted camera path, seeded data, so every mode gets identical input.
- Output: console lines prefixed `[showcase]`, then a Markdown table + JSON at the end; results screen has **Copy table** / **Copy JSON**.
- **Flame engine micro-benchmarks**: Flame's own suite (`package:flame/benchmark`) run in-app.
- Remote: paste the VM service URI to Claude; it calls `ext.showcase.run` (`suite=…`), `ext.showcase.results`, `ext.showcase.micro` (`start=true`).

## Demos
| # | Demo | Modes |
|---|------|-------|
| 0 | Bouncing dots | Widgets · CustomPainter · Flame (comp per dot) · Flame (1 comp) · side-by-side |
| 1 | Stadium seat map | Widgets · CustomPainter · Flame seat comps · Flame sections · side-by-side |
| 2 | Live factory floor | Widgets · Flame |
| 3 | Pick your interests | Wrap of chips · Flame + Forge2D |
| 4 | Savings reward (scratch + coins) | Flame in a Flutter dialog |
| 5 | Delivery tracker | Widgets · Flame |
| 6 | Live waveform | Flame |
| 7 | Connection graph | Flame + Forge2D |
| 8 | Sticker editor | Flame |
| 9 | Sentence builder | Flame + Flutter overlays |
