import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flame/game.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:material_ui/material_ui.dart';

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const windowSizes = [1000, 5000, 20000];

List<Scenario> waveformSuite() => [
      for (final w in windowSizes)
        Scenario(suite: 'waveform', mode: 'flame', load: w, note: 'visible samples, 500 samples/s',
            build: () => GameWidget(game: WaveGame(window: w))),
    ];

class WaveformScreen extends StatefulWidget {
  const WaveformScreen({super.key});

  @override
  State<WaveformScreen> createState() => _WaveformScreenState();
}

class _WaveformScreenState extends State<WaveformScreen> {
  late final WaveGame _game = WaveGame(window: 2500);
  double _start = 1;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Live heart-rate signal',
      controls: ValueListenableBuilder<int>(
        valueListenable: _game.bpm,
        builder: (_, bpm, _) => Row(children: [
          const Icon(Icons.favorite, color: Palette.flame),
          const SizedBox(width: 8),
          Text('$bpm bpm', style: const TextStyle(color: Palette.cream, fontSize: 20, fontWeight: FontWeight.w700)),
          const Spacer(),
          const Text('Pinch / scroll to change the time window', style: TextStyle(color: Palette.muted)),
        ]),
      ),
      body: Listener(
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) _game.zoomWindow(math.exp(e.scrollDelta.dy / 300));
        },
        child: GestureDetector(
          onScaleStart: (_) => _start = 1,
          onScaleUpdate: (d) {
            _game.zoomWindow(_start / d.scale);
            _start = d.scale;
          },
          child: GameWidget(game: _game),
        ),
      ),
    );
  }
}

/// Synthetic ECG-ish signal pushed into a ring buffer at [sampleRate];
/// the visible window is drawn with one drawRawPoints call per frame.
class WaveGame extends FlameGame {
  WaveGame({required int window}) : _window = window.toDouble();

  static const sampleRate = 500;
  static const capacity = 40000;
  final Float32List _buf = Float32List(capacity);
  int _head = 0;
  int _count = 0;
  double _acc = 0;
  double _phase = 0;
  double _window;
  final ValueNotifier<int> bpm = ValueNotifier(72);
  final _rng = math.Random(4);
  Float32List _points = Float32List(0);

  static final _paint = Paint()
    ..color = Palette.flame
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  @override
  Color backgroundColor() => const Color(0x00000000);

  void zoomWindow(double f) => _window = (_window * f).clamp(200, capacity - 1.0);

  double _sample() {
    final rate = bpm.value / 60;
    _phase = (_phase + rate / sampleRate) % 1;
    final p = _phase;
    double v = 0;
    v += 0.12 * math.exp(-math.pow((p - 0.2) / 0.03, 2)); // P
    v -= 0.15 * math.exp(-math.pow((p - 0.36) / 0.008, 2)); // Q
    v += 1.0 * math.exp(-math.pow((p - 0.38) / 0.01, 2)); // R
    v -= 0.25 * math.exp(-math.pow((p - 0.40) / 0.01, 2)); // S
    v += 0.3 * math.exp(-math.pow((p - 0.6) / 0.05, 2)); // T
    return v + (_rng.nextDouble() - 0.5) * 0.03;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _acc += dt * sampleRate;
    while (_acc >= 1) {
      _acc -= 1;
      _buf[_head] = _sample();
      _head = (_head + 1) % capacity;
      if (_count < capacity) _count++;
    }
    if (_rng.nextDouble() < dt * 0.5) {
      bpm.value = (bpm.value + _rng.nextInt(5) - 2).clamp(60, 110);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final n = math.min(_window.round(), _count);
    if (n < 2) return;
    if (_points.length != n * 2) _points = Float32List(n * 2);
    final w = size.x, h = size.y;
    for (var k = 0; k < n; k++) {
      final idx = (_head - n + k + capacity) % capacity;
      _points[2 * k] = w * k / (n - 1);
      _points[2 * k + 1] = h * 0.6 - _buf[idx] * h * 0.4;
    }
    canvas.drawRawPoints(PointMode.polygon, _points, _paint);
  }
}
