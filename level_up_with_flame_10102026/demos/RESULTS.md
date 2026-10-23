# Benchmark results & what they mean

Device: macOS, profile mode, 120 Hz, window 1452×965 @1x. Raw data: `../benchmarks.json`.
Frame budget at 120 Hz = **8.3 ms**. "Jank" = frames where build or raster went over budget.

## Headline numbers

### Seat map: the one clear story (autopilot camera + 30 live bookings/s)
| Seats | Widgets | CustomPainter | Flame · comp per seat | Flame · sections + culling |
|---:|---:|---:|---:|---:|
| 2k | 115 fps · 6% jank | 120 · 0% | 120 · 0% | 120 · 0% |
| 5k | **71 fps · 51% jank** | 120 · 0% | 120 · 0.6% | 120 · 0% |
| 10k | **20 fps** (build p90 60 ms) | 120 · 0% | 113 · 17% | 120 · 0% |
| 20k | **11 fps** (build p90 103 ms) | 120 · 0% | 65 · 100% | 120 · 0% |

### Dots (no interaction)
- Up to 2k: everything at 120 fps (one odd 79 fps reading for Flame comps at 2k, needs a re-run).
- 5k: widgets still 117 fps but **28% jank**; the others are clean.
- 10k: widgets 54 fps · CustomPainter **105** · Flame (1 comp) 75 · Flame (comp per dot) 72.
  Same drawing code, but Flame's raster time is ~4 ms higher at 10k. That's an open question; worth one look before quoting it.

### Factory, tracker: no story
- Realistic loads (20–80 machines, 50–1000 riders): **both 120 fps, near-zero jank**.
- Factory at 160 machines: widgets 7% jank, Flame **15% jank** (one particle component per airflow dot = lots of add/remove churn).

### Flame-only demos: cheap
Bubbles (Forge2D, 300 bodies), rewards, waveform (20k samples), graph (160 springs + n² repulsion):
**all 120 fps, 0% jank, build p90 ≤ 5.6 ms**.

## What this says
1. **Widgets are the wrong tool for thousands of live, moving, tappable things.** Seat map at 10k: 20 fps. Not controversial, very visible.
2. **Any canvas fixes it.** CustomPainter and Flame-done-right are equally fast. **Flame is not faster than CustomPainter**, and its naive "one component per seat" style is *slower*.
3. Flame needs the same thinking as a painter (batching, culling) to scale. The engine gives you the tools (`visibleWorldRect`, sections); it doesn't do it for you.
4. **Flame's value is capability, not speed.** Physics, collisions, particles, effects, camera follow, drag/tap per object, game loop and overlays. All of it ran at 120 fps with a few ms per frame.
5. Code size isn't a win for plain shapes either (seat map: painter 152 lines vs Flame 198 for both Flame modes). Flame's code advantage shows up where you'd otherwise write an engine: physics, collisions, effects.

## Proposed way to portray it: the "ladder"
**Widgets → CustomPainter → Flame.** Each rung buys something different.

| Rung | Buys you | Step up when… |
|---|---|---|
| Widgets | layout, text, accessibility, forms | most of your app |
| CustomPainter | **speed**: one canvas instead of N widgets | many items, every frame (seat map: 11 → 120 fps) |
| Flame | **behaviour**: loop, physics, collisions, particles, effects, camera, per-object input | things should *move like things*: bounce, pile up, collide, follow, react |

- The perf section becomes "rung 1 → 2": seat map widgets vs canvas. Honest and dramatic.
- The "Why not just CustomPainter?" slide becomes the pivot: *a canvas is fast, but a canvas doesn't know about gravity.*
- The demos then show rung 3, where you'd otherwise be writing an engine: the scratch card spilling coins into a bowl (Forge2D), the interest bubbles, the network graph, the sticker editor, the sentence builder.
- The twist still works: **"This was never about games. It's about game *mechanics* in apps."**
- Gyro Maze closes it: raw sensors → physics → Flame, with Flutter around it.

## Changed after run 1
- **Rewards demo rebuilt**: scratch the card and coins spill out of the scratched area *while you scratch*, fall with Forge2D physics, bounce and pile up in a bowl. A Flutter chip counts ₹ live; "Collect" pops back to a Flutter sheet. The bench now measures auto-scratch with 50/150/400 coins.

## To re-run / check
- [ ] Dots `flame` at 2k (79 fps outlier).
- [ ] Why Flame raster > CustomPainter raster for identical drawing at 10k dots.
- [ ] `seats` + `rewards` suites on a real mid-range Android phone (the macOS numbers flatter everything).


---

# Run 2: Android, Realme XT (RMX1921, 2019 mid-range), 60 Hz, profile

Frame budget at 60 Hz = **16.7 ms**. This is the run the slides should quote.

### Seat map: still the headline, and stronger
| Seats | Widgets | CustomPainter | Flame · comp per seat | Flame · sections + culling |
|---:|---:|---:|---:|---:|
| 2k | **26 fps** · 100% jank | 60 · 0% | 48 · 29% | 60 · 0% |
| 5k | **11 fps** | 60 · 0% | 32 · 97% | 60 · 0% |
| 10k | **3.8 fps** (build p90 277 ms) | 60 · 26% jank | 16 | **60 · 0%** |
| 20k | **2.1 fps** (build p90 541 ms) | 50 · 5% | 12 | **60 · 0%** (build 4.2 / raster 6.2 ms) |

- On a real phone, widgets fall over at **2,000** seats.
- Flame sections is the **only** version that holds 60 fps with no jank at every load. CustomPainter starts slipping at 10k.
  The difference is culling: the Flame version skips sections the camera can't see with one check against
  `camera.visibleWorldRect`. A painter could do this too, but you'd write the camera maths yourself.
- One component per seat is still a trap (12 fps at 20k).

### Dots: GPU-bound past 1k
- 1k dots: widgets **51 fps, 25% jank** · painter 60 · Flame 59 · Flame (1 comp) 60.
- 2k and up, every mode is limited by raster time (drawing 2k+ circles on that GPU), so all of them sink together.
- Usable video: **1k dots, widgets vs Flame**.

### Factory: widgets win on this phone (Flame v1)
- 40 machines: widgets 51 fps · Flame 56. 80: widgets 40 · Flame 35. 160: both ~15–17.
- The Flame version spawns one `ParticleSystemComponent` per airflow dot. Flame v2's new particle system targets exactly this (see below).

### Tracker: mixed
- 500 riders: widgets 46 fps vs Flame 39. 1,000 riders: widgets 21 vs Flame 30. No clean story: leave it out.

### Flame-only demos on the phone
| Demo | Load | fps | jank |
|---|---|---:|---:|
| Bubbles (Forge2D) | 30 / 100 / 300 bodies | 60 / 60 / 60 | 0 / 0 / 0.3% |
| Coins into the bowl (Forge2D) | 50 / 150 / 400 coins | 60 / 60 / 60 | 0 / 0.8 / 1.9% |
| Connection graph (Forge2D + n² forces) | 40 / 80 / 160 | 60 / 60 / 57 | 0 / 0 / 4.7% |
| Waveform | 1k / 5k / 20k samples | 60 / 45 / 49 | GPU-bound past 1k |

The physics demos hold 60 fps on a five-year-old phone, with hundreds of bodies.

## Slide numbers to use
- **Seat map, Realme XT:** widgets 26 → 11 → 3.8 → 2.1 fps; Flame 60 fps at every size (2k → 20k).
- **Physics, Realme XT:** 400 coins / 300 bubbles at 60 fps.

---

# Flame v2 (ongoing)

- **`flame 2.0.0-dev.0` was published on 2026-10-01** as a pre-release, with `flame_forge2d 0.21.0-dev.0`.
  Tracking issue: flame-engine/flame#1938 "Flame v2 changes" (open).
- The performance work is the **Flame Component System core rewrite**, flame-engine/flame#3957 (closed; merged via #4019 + #3960):
  the `OrderedSet` children container was replaced by a flat sorted array, the update pass was flattened, and allocations were removed from hot paths.
- **Upstream numbers** (from #3957; `flutter test` JIT on one desktop, so relative only. The authors say AOT device numbers are pending and should show "smaller but same-ranked multiples"):

| Benchmark | v1 (main) ms | v2 (#3960) ms | Speed-up |
|---|---:|---:|---:|
| Update wide tree (10k × 1) | 8.09 | 3.44 | 2.4× |
| Update nested tree (1k × 10) | 16.96 | 3.97 | 4.3× |
| Update deep tree (100 levels) | 18.14 | 3.36 | 5.4× |
| Render wide tree (10k × 1) | 12.81 | 4.64 | 2.8× |
| Render nested tree (1k × 10) | 23.05 | 8.25 | 2.8× |
| Render deep tree (100 levels) | 27.44 | 6.89 | 4.0× |
| Priority change (1 child per parent) | 74.46 | 6.92 | 10.8× |
| Hit test + delivery (cached) | 90.93 | 39.06 | 2.3× |
| Flat collision detection | 9.24 | 3.35 | 2.8× |
| Nested collision detection | 15.41 | 3.52 | 4.4× |
| Game-like update pass | 185.29 | 95.31 | 1.9× |

- v2 also replaces the particle system with a **data-oriented one** (#3948): struct-of-arrays simulation and one batched draw call per emitter.
- **Our own measurement:** `../demos_flame_v2/` is the same app ported to `flame 2.0.0-dev.0`, so v1 and v2 run on the same phone.
  Port notes: `HasGameReference` → `HasGameRef` (`game` → `gameRef`), `add`/`addAll` are now sync,
  `event.handled` removed, and the new `ParticleEmitterComponent` API (factory airflow + sentence sparkles).
  Every result row now records the Flame version.

## To run next
- [ ] `demos_flame_v2`: **Flame engine micro-benchmarks** + `seats` + `factory` + `dots` on the Realme XT → v1 vs v2 table.
- [ ] Dots `flame` at 2k on macOS (79 fps outlier) and Flame vs painter raster gap at 10k: low priority now.


---

# Run 3: Flame v1 (1.38.2) vs v2 (2.0.0-dev.0), same Realme XT, 60 Hz

**Read with care:** rows that don't touch Flame also moved between the two runs (factory *widgets* @20: 59.7 → 50.2 fps;
tracker *widgets* @200: 59.7 → 48.1). The phone was warmer for the second full run, so treat ±15% as noise and compare
**Flame against widgets/painter within the same run**. The Flame engine micro-benchmarks weren't in this file. Run that screen in both apps for a clean A/B.

### Where v2 clearly helps
| Demo | Load | v1: Flame vs widgets | v2: Flame vs widgets | Why |
|---|---|---|---|---|
| Factory (airflow particles) | 160 machines | 15.3 vs **17.4** fps (Flame raster p90 51 ms) | **23.0** vs 19.3 fps (Flame raster p90 **13 ms**) | new data-oriented particle system: one batched draw per duct |
| Factory | 40 machines | 56.3 vs 51.2 | 40.7 vs 38.8 | both hot in run 2; Flame still ahead |
| Delivery tracker (effects) | 500 riders | 38.5 vs **45.6** fps (Flame jank 62%) | **53.0** vs 45.3 fps (Flame jank 11%) | flattened update pass (500 `MoveAlongPathEffect`s) |
| Delivery tracker | 1,000 riders | 29.9 vs 21.1 | **40.5** vs 26.8 | same |

### Where v2 makes no visible difference
- **Seat map, Flame sections**: 60 fps / 0% jank at every size in both. It was already cheap (~100 components).
- **Seat map, comp per seat**: noisy, no clear win (10k: 16 → 22 fps; 20k: 12 → 8 fps). Render is still one draw per component. v2 doesn't batch or cull for you.
- **Dots, rewards, bubbles, waveform**: same fps. Dots and waveform are GPU-bound. Rewards and bubbles were already at 60.

### Possible regression to re-check
- **Connection graph @160**: 57 → **37 fps** (build p90 9 → 28 ms). v2 resolved `forge2d 0.15.1` (v1 had 0.15.2), and the n² force loop is plain Dart.
  Re-run it cold before drawing any conclusion.

---


### Engine micro-benchmarks: measurement on a real phone (Realme XT, Android, profile/AOT)
Same app, same phone; Flame's own benchmark suite adapted into the app (`Flame engine micro-benchmarks` screen).
Lower is better.

| Benchmark (from `package:flame/benchmark`) | v1 1.38.2 | v2 2.0.0-dev.0 | Speed-up | Upstream (desktop JIT) |
|---|---:|---:|---:|---:|
| Update 1,000 components × 10 children (per tick) | 340.6 µs | 231.1 µs | **1.5×** | 2.4–4.3× |
| Render 500 nested components (per pass) | 5,530 µs | 4,808 µs | **1.15×** | 2.8× |
| Collision detection, 100 moving hitboxes (per tick) | 57.0 µs | 16.9 µs | **3.4×** | 2.8× |
| Hit-test a tap into a 10-level tree | 462 µs | 443 µs | **1.04×** | 2.3× |

Notes:
- As the Flame team predicted, gains on a device are **smaller but same-ranked**. Collision detection is the big win, and on the phone it is even bigger than on desktop.
- Our render benchmark also records each rect into a real `Picture` (the original uses a mock canvas), so drawing cost dilutes the traversal gain.
- The update benchmark fits only 3 (v1) and 5 (v2) runs in the 2 s window. Treat it as approximate.
- Plus the frame-level win from the new particle system: factory airflow at 160 machines, Flame raster p90 **51 → 13 ms**.

**Slide line:** *On a 2019 Android phone, Flame v2 dev runs collision detection 3.4× faster and component updates 1.5× faster, and its new particle system cut our airflow demo's draw time by 4×.*

---

# Widgets vs CustomPainter vs Flame (Android, both runs)

| Seat map | Widgets | CustomPainter | Flame · comp per seat | Flame · sections |
|---:|---:|---:|---:|---:|
| 2k | 26 fps | **60** | 48–50 | **60** |
| 5k | 9–11 | **60** | 27–32 | **60** |
| 10k | 3.7 | 60 (26% jank in run 1) | 16–22 | **60, 0% jank** |
| 20k | 2.1 | 50 (5% jank) | 8–12 | **60, 0% jank** |

| Dots | Widgets | CustomPainter | Flame comps | Flame 1 comp |
|---:|---:|---:|---:|---:|
| 1k | 51–53 fps, 19–25% jank | 60 | 59–60 | 60 |
| 2k+ | all modes ~equal, GPU-bound (raster 25–130 ms) | | | |

**What this says about CustomPainter vs Flame:**
1. **Same technique, same speed.** Painter, Flame (1 comp) and Flame sections all draw with a few batched calls, and all hold 60 fps up to 5k.
2. **The gap at 10k–20k is culling plus change tracking, not "Flame is faster".** Flame sections skips off-screen sections
   (`camera.visibleWorldRect`) and rebuilds only the section that changed. Our painter redraws and rebuilds everything
   (build p90 16 ms at 20k from rebuilding all points on each booking). A painter *can* do both, but you write the camera,
   culling, hit-testing and dirty tracking by hand. In Flame, a component is the natural unit for all of that.
3. **Flame used naively (one component per seat) is slower than a plain CustomPainter.** Worth saying on stage.
4. **Where CustomPainter has no answer:** physics (bubbles, coins), collisions, particle systems, effects. That's where Flame earns its place.

**One-liner for the slide:** *Widgets for UI. CustomPainter for drawing. Flame for drawing that has to behave.*

---

# App size (release APK, android-arm64)
| App | APK | vs CustomPainter baseline |
|---|---:|---:|
| Flutter + CustomPainter | 14.35 MB | — |
| + Flame | 14.54 MB | **+192 KB** |
| + Flame + Forge2D | 14.89 MB | **+551 KB**, incl. 257 KB native Box2D |

Details: `../size_test/size_results.md`. *A fixed cost of ~200 KB (Flame) / ~550 KB (with physics). Writing your own engine on CustomPainter would cost similar code, so use the one that's built, tested and maintained.*

---

# Final picks for the talk

| Demo | Verdict | Why |
|---|---|---|
| **Seat map** | **Keep. Main perf story** | Widgets 26 → 2 fps vs Flame 60 fps at every size, on a 2019 phone. Painter numbers on the slide; video = widgets vs Flame. Explains comp-per-seat vs sections. |
| **Scratch card → coins into the bowl** | **Keep. Flagship** | Physics + scratch at once, inside a Flutter dialog; 400 coins at 60 fps. Something CustomPainter can't do without writing an engine. |
| **Interest bubbles** | **Keep** | Onboarding physics, 300 bodies at 60 fps; relatable in any app. |
| **Gyro Maze** | **Keep. Closing** | Sensors → physics → Flame, Flutter around it; QR for the audience. |
| Sticker editor, sentence builder | **Montage only** (a few seconds each) | Effects/drag/overlays; no perf claim. |
| Factory floor | **v2 slide only** | v1: widgets win. v2: Flame wins at 160 machines (raster 51 → 13 ms) thanks to the new particle system. |
| Delivery tracker | **v2 slide only (optional)** | 500 riders: 38 → 53 fps in v2. Too mixed to be a main demo. |
| Dots | **Discard** (keep as backup) | GPU-bound past 1k; no differentiator. |
| Waveform | **Discard** | GPU-bound; nothing Flame-specific. |
| Connection graph | **Discard** | Overlaps bubbles; v2 regression to check. |

## Still to run
- [x] Flame engine micro-benchmarks in both apps (see Run 3).
- [ ] Cold re-run (phone cooled, unplugged) of `seats`, `factory`, `tracker`, `graph` in v1 then v2.
- [ ] New smaller bowl: one manual run to check how many coins miss.

## Resources (for slides)
- Flame docs: https://docs.flame-engine.org · Performance: https://docs.flame-engine.org/latest/flame/other/performance.html
- Flame on pub.dev: https://pub.dev/packages/flame · flame_forge2d: https://pub.dev/packages/flame_forge2d
- Flame source: https://github.com/flame-engine/flame · v2 tracking: https://github.com/flame-engine/flame/issues/1938
- FCS rewrite numbers: https://github.com/flame-engine/flame/issues/3957 · Particles: https://github.com/flame-engine/flame/pull/3948
- Flutter CustomPainter: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- Flutter InteractiveViewer: https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html
- Flutter performance best practices: https://docs.flutter.dev/perf/best-practices
- DevTools performance view: https://docs.flutter.dev/tools/devtools/performance
- Box2D v3 (what Forge2D binds to): https://box2d.org
- Gyro Maze web trial: https://gyromaze.immadisairaj.dev
