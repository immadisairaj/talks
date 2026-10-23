import 'package:material_ui/material_ui.dart';

import '../bench/bench.dart';
import '../bench/flame_micro.dart';
import '../common/side_by_side.dart';
import 'bubbles/bubbles.dart';
import 'dots/dots_screen.dart';
import 'factory/factory_screen.dart';
import 'rewards/rewards.dart';
import 'tracker/tracker.dart';
import 'graph/graph.dart';
import 'waveform/waveform.dart';
import 'sticker/sticker.dart';
import 'sentence/sentence.dart';
import 'dots/dots_views.dart';
import 'seats/seat_layout.dart';
import 'seats/seat_screen.dart';
import 'seats/seat_views.dart';

class DemoEntry {
  const DemoEntry(this.title, this.subtitle, this.builder, {this.suite});
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
  final String? suite;
}

final demos = <DemoEntry>[
  DemoEntry('Flame engine micro-benchmarks', 'Flame\'s own benchmark suite, run in-app', (_) => const MicroBenchScreen()),
  DemoEntry('0 · Bouncing dots', 'Widgets vs CustomPainter vs Flame', (_) => const DotsScreen(), suite: 'dots'),
  DemoEntry('1 · Stadium seat map', 'Widgets vs Flame · pan, zoom, live bookings', (_) => const SeatScreen(), suite: 'seats'),
  DemoEntry('2 · Live factory floor', 'IoT dashboard · widgets vs Flame', (_) => const FactoryScreen(), suite: 'factory'),
  DemoEntry('3 · Pick your interests', 'Wrap of chips vs Forge2D bubbles', (_) => const BubblesScreen(), suite: 'bubbles'),
  DemoEntry('4 · Savings reward', 'Scratch card + catch the coins, inside a dialog', (_) => const RewardsScreen(), suite: 'rewards'),
  DemoEntry('5 · Delivery tracker', 'Riders on a map · follow with the camera', (_) => const TrackerScreen(), suite: 'tracker'),
  DemoEntry('6 · Live waveform', 'Heart-rate signal, pinch the time window', (_) => const WaveformScreen(), suite: 'waveform'),
  DemoEntry('7 · Connection graph', 'Forge2D springs · drag and focus', (_) => const GraphScreen(), suite: 'graph'),
  DemoEntry('8 · Sticker editor', 'Drag, rotate and scale stickers on a tee', (_) => const StickerScreen()),
  DemoEntry('9 · Sentence builder', 'Drag-and-snap tiles with Flutter HUD', (_) => const SentenceScreen()),
  DemoEntry(
    '0 · Dots side by side',
    'Same dots, panes next to each other',
    (_) => SideBySideScreen<DotsMode>(
      title: 'Dots · side by side',
      modes: DotsMode.values,
      label: (m) => m.label,
      initialPanes: const {DotsMode.widgets, DotsMode.flame},
      loads: dotCounts,
      initialLoad: 2000,
      loadLabel: (n) => '$n',
      paneBuilder: (m, n, _) => buildDots(m, n),
    ),
  ),
  DemoEntry(
    '1 · Seat map side by side',
    'Same stadium, same camera path, same bookings',
    (_) => SideBySideScreen<SeatMode>(
      title: 'Seat map · side by side',
      modes: SeatMode.values,
      label: (m) => m.label,
      initialPanes: const {SeatMode.widgets, SeatMode.flameSections},
      loads: seatCounts,
      initialLoad: 10000,
      loadLabel: (n) => '${n ~/ 1000}k seats',
      autopilotOption: true,
      paneBuilder: (m, n, auto) => buildSeatMap(m, SeatLayout(n), autopilot: auto),
    ),
  ),
];

void registerSuites() {
  FlameMicro.registerExtension();
  Bench.instance.register('dots', dotsSuite);
  Bench.instance.register('seats', seatsSuite);
  Bench.instance.register('factory', factorySuite);
  Bench.instance.register('bubbles', bubblesSuite);
  Bench.instance.register('rewards', rewardsSuite);
  Bench.instance.register('tracker', trackerSuite);
  Bench.instance.register('waveform', waveformSuite);
  Bench.instance.register('graph', graphSuite);
  // Everything, back to back (~9 minutes).
  final named = Map.of(Bench.instance.suites);
  Bench.instance.register('all', () => [for (final b in named.values) ...b()]);
}
