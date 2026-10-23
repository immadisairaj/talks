# flame_showcase: build & measure plan

Source spec: `../demos.md`. Talk flow: `../talk-outline.md`. **Deck is frozen until results are in.**

## Constraints (how we work)
- Claude writes the code here (`demos/`) and checks it with the Dart analyzer through the Dart MCP server on your Mac.
  Claude can't run Flutter itself (no SDK in its sandboxes), so **you run the app**.
- Platform folders are generated once by you: `cd demos && flutter create . --project-name flame_showcase --platforms android,ios,web,macos`
- Same stack as Gyro Maze: Flutter 3.47 / Dart 3.13, `flame ^1.38.2`, `material_ui` (not `package:flutter/material.dart`).
- Measuring happens **inside the app**, so the numbers come from your real phone in profile mode:
  `flutter run --profile -d <phone>`. Paste the VM service URI it prints and Claude connects,
  starts the benchmark through a service extension, and reads the results back as JSON. No copying numbers by hand.

## Measuring harness (`lib/bench/`)
- `FrameStats`: `SchedulerBinding.addTimingsCallback`. Per window: frames, avg FPS (from vsync timestamps),
  p50/p90/p99 of build ms, raster ms, total ms; jank % (frames over the refresh budget, read from `display.refreshRate`).
- `Scenario`: demo × mode (Flutter / CustomPainter / Flame) × load (N items, update rate).
  Each one runs 2 s warm-up, then 6 s measured, under a **scripted driver** so both modes get identical input
  (same seeded data, same camera pan/zoom path, same stream rates).
- `BenchRunner`: runs a list of scenarios one after another, shows a results table, keeps the JSON.
- Service extensions: `ext.showcase.run` (args: suite) → starts a suite; `ext.showcase.results` → JSON.
- On-screen `StatsOverlay` (FPS, build, raster) shows in every demo for the recordings.

## Phases & checkpoints
| Phase | Scope | Checkpoint |
|---|---|---|
| 1 | Project skeleton, harness, **Demo 0 dots** (Widgets / CustomPainter / Flame), demo list home | You: `flutter create .` + `flutter run --profile`. Claude runs suite `dots` and reads the numbers. |
| 2 | **Demo 1 seat map**, **Demo 2 factory floor** (Flutter-only baseline + Flame + scripted driver) | Suites `seats`, `factory`. |
| 3 | **Demo 3 interest bubbles** (Forge2D), **Demo 4 scratch + coins** (no baseline; scripted play for FPS only) | Suites `bubbles`, `rewards` + a manual feel check. |
| 4 | Demos 5–7: delivery tracker, waveform, connection graph (baselines for 5 and 6) | Suites `tracker`, `waveform`, `graph`. |
| 5 | Demos 8–10: sticker editor, sentence builder, tilt card (montage only, a light FPS check) | Quick manual run. |
| 6 | Results → `RESULTS.md` → decide which demos and claims make the deck → update slides | Your go-ahead. |

## Load levels per suite (first guess, tuned after the first run)
- dots: N = 500, 1k, 2k, 5k, 10k × {widgets, painter, flame}
- seats: 2k, 5k, 10k, 20k seats × {flutter, flame}; camera pans/zooms continuously; 30 bookings/s
- factory: 20, 40, 80 machines at 20 Hz sensor updates × {flutter, flame}; particles on
- tracker: 50, 200, 500 riders × {flutter, flame}
- waveform: 1k, 5k, 20k visible samples at 500 samples/s × {chart widget, flame}

## What counts as a result
- A demo makes the deck only if Flame **clearly** wins on the phone (FPS, or worst-frame time) **or** is clearly
  simpler to build (for the physics demos, where there's no fair baseline).
- If the baseline is fine at realistic loads, we say so on stage. The "it's rarely about the count" slide depends on that honesty.

## Status (updated as we go)
| Item | State |
|---|---|
| Harness (FrameStats, BenchRunScreen, console/Markdown/JSON output, copy buttons, VM extensions) | written, analyzer clean |
| Flame engine micro-benchmarks (from `package:flame/benchmark`) | written, analyzer clean |
| Side-by-side screen (pause per pane) | written, analyzer clean |
| 0 dots · 1 seat map (incl. CustomPainter mode) · 2 factory · 3 bubbles · 4 rewards · 5 tracker · 6 waveform · 7 graph · 8 sticker · 9 sentence | written, analyzer clean, **not run yet** |
| 10 tilt card | skipped for now (no sensors on macOS; `sensors_plus` removed) |

Decisions: recorded videos for demos (live only for the Gyro Maze QR); add a short "Why not just CustomPainter?" slide; claim = "CustomPainter gives a canvas, Flame gives the canvas + the engine".
