// Engine micro-benchmarks adapted from Flame's own suite
// (package:flame/benchmark/*.dart, MIT licence, © Blue Fire), run inside the
// app with a small harness instead of benchmark_harness, and a real
// PictureRecorder canvas instead of MockCanvas.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class MicroResult {
  MicroResult(this.name, this.what, this.usPerRun, this.runs, this.perUnit, this.unit);
  final String name;
  final String what;
  final double usPerRun;
  final int runs;
  final double perUnit;
  final String unit;

  Map<String, Object> toJson() => {
        'name': name,
        'what': what,
        'usPerRun': usPerRun.round(),
        'runs': runs,
        'perUnit': (perUnit * 100).round() / 100,
        'unit': unit,
      };
}

abstract class _Micro {
  String get name;
  String get what;
  int get units; // how many "things" one run does, for a per-unit figure
  String get unit;
  Future<void> setup();
  void run();
}

/// Same idea as benchmark_harness: warm up, then time as many runs as fit.
Future<MicroResult> _measure(_Micro m) async {
  await m.setup();
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < 300) {
    m.run();
  }
  var runs = 0;
  sw
    ..reset()
    ..start();
  while (sw.elapsedMilliseconds < 2000) {
    m.run();
    runs++;
  }
  final us = sw.elapsedMicroseconds / runs;
  return MicroResult(m.name, m.what, us, runs, us / m.units, m.unit);
}

// --- Updating components (update_components_benchmark.dart) ---------------

class _UpdateComponents extends _Micro {
  final Random random = Random(69420);
  late final FlameGame _game;
  late final List<_Mover> _components;
  late final List<double> _dts;
  late final Set<int> _inputTicks;

  @override
  String get name => 'Update components';
  @override
  String get what => '1,000 components × 10 children, 2,000 ticks';
  @override
  int get units => 2000;
  @override
  String get unit => 'µs per tick (11k components)';

  @override
  Future<void> setup() async {
    _game = FlameGame();
    _game.addAll(List.generate(1000, _Mover.new));
    await _game.ready();
    _components = _game.children.whereType<_Mover>().toList(growable: false);
    _dts = List.generate(2000, (_) => random.nextDouble());
    _inputTicks = List.generate(500, (_) => random.nextInt(2000)).toSet();
  }

  @override
  void run() {
    for (final (index, dt) in _dts.indexed) {
      if (_inputTicks.contains(index)) {
        _components[random.nextInt(1000)].input(xDirection: random.nextInt(3) - 1);
      }
      _game.update(dt);
    }
  }
}

class _Mover extends PositionComponent {
  _Mover(this.id);
  final int id;
  final Vector2 velocity = Vector2.zero();
  static const _groundY = -20.0;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 10; i++) {
      add(PositionComponent(position: Vector2(i * 2, 0)));
    }
  }

  void input({required int xDirection}) {
    velocity.x = xDirection * 100;
    if (position.y == _groundY) velocity.y -= 100;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(velocity * dt);
    velocity.add(Vector2(0, 10 * dt));
    if (position.y > _groundY) {
      position.y = _groundY;
      velocity.setValues(0, 0);
    }
  }
}

// --- Rendering components (render_components_benchmark.dart) -------------

class _RenderComponents extends _Micro {
  final Random random = Random(69420);
  late final FlameGame _game;

  @override
  String get name => 'Render components';
  @override
  String get what => '500 nested PositionComponents, 2 renders (recorded)';
  @override
  int get units => 2;
  @override
  String get unit => 'µs per render pass';

  @override
  Future<void> setup() async {
    _game = FlameGame()..onGameResize(Vector2.all(100));
    _game.addAll(List.generate(500, (_) => _Nested(random: random, level: 1)));
    await _game.ready();
  }

  @override
  void run() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 2; i++) {
      _game.render(canvas);
    }
    recorder.endRecording().dispose();
  }
}

class _Nested extends PositionComponent {
  _Nested({required this.random, required this.level}) : super(size: Vector2.all(4));
  final Random random;
  final double level;
  static final _paint = Paint()..color = const Color(0xFFFF7A2E);

  @override
  Future<void> onLoad() async {
    if (random.nextDouble() <= level) {
      addAll(List.generate(random.nextInt(2) + 1, (_) => _Nested(random: random, level: level * 0.25)));
    }
  }

  // The original renders nothing; drawing a rect keeps the canvas honest.
  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _paint);
}

// --- Collision detection (collision_detection_benchmark.dart) ------------

class _FlatCollision extends _Micro {
  final Random random = Random(69420);
  late final FlameGame _game;

  @override
  String get name => 'Collision detection';
  @override
  String get what => '100 moving blocks with RectangleHitbox, 500 ticks';
  @override
  int get units => 500;
  @override
  String get unit => 'µs per tick';

  @override
  Future<void> setup() async {
    _game = _CollisionGame()..onGameResize(Vector2.all(800));
    _game.addAll(List.generate(
      100,
      (_) => _Block(
        position: Vector2.random(random) * 700,
        size: Vector2.random(random) * 50 + Vector2.all(10),
        velocity: Vector2(
          random.nextInt(200) * (random.nextBool() ? 1.0 : -1.0),
          random.nextInt(200) * (random.nextBool() ? 1.0 : -1.0),
        ),
      ),
    ));
    await _game.ready();
  }

  @override
  void run() {
    for (var i = 0; i < 500; i++) {
      _game.update(1 / 60);
    }
  }
}

class _CollisionGame extends FlameGame with HasCollisionDetection {}

class _Block extends PositionComponent with CollisionCallbacks {
  _Block({required super.position, required super.size, required this.velocity}) {
    add(RectangleHitbox());
  }
  final Vector2 velocity;

  @override
  void update(double dt) {
    super.update(dt);
    if (position.length2 > 100000) velocity.negate();
    position.add(velocity * dt);
  }
}

// --- Hit testing taps (components_at_point_benchmark.dart) ---------------

class _HitTest extends _Micro {
  final Random random = Random(69420);
  late final FlameGame _game;
  late final List<Vector2> _positions;

  @override
  String get name => 'Hit-test taps';
  @override
  String get what => '500 taps into a 10-level component tree (cached path)';
  @override
  int get units => 500;
  @override
  String get unit => 'µs per tap';

  @override
  Future<void> setup() async {
    _game = _buildTree();
    await _game.ready();
    _positions = List.generate(500, (_) => Vector2(random.nextDouble() * 800, random.nextDouble() * 800));
  }

  @override
  void run() {
    for (final position in _positions) {
      final hasHandler = _game.containsEventHandlerAt(position);
      for (final c in _game.componentsAtPoint(position, <Vector2>[])) {
        if (c is TapCallbacks) break;
      }
      if (hasHandler) {
        for (final c in _game.componentsAtPoint(position, <Vector2>[])) {
          if (c is TapCallbacks) break;
        }
      }
    }
  }
}

FlameGame _buildTree() {
  final random = Random(12345);
  final game = FlameGame()..onGameResize(Vector2.all(800));
  void build(PositionComponent parent, int depth, double size) {
    if (depth >= 10) return;
    final count = 1 + random.nextInt(2);
    final childSize = size * (0.3 + random.nextDouble() * 0.3);
    for (var i = 0; i < count; i++) {
      final maxOffset = size - childSize;
      final pos = Vector2(
        random.nextDouble() * maxOffset.clamp(0, double.infinity),
        random.nextDouble() * maxOffset.clamp(0, double.infinity),
      );
      final child = (depth == 9 && i % 3 == 0 ? _Tappable() : PositionComponent())
        ..position = pos
        ..size = Vector2.all(childSize);
      parent.add(child);
      build(child, depth + 1, childSize);
    }
  }

  for (var i = 0; i < 4; i++) {
    final root = PositionComponent()
      ..position = Vector2((i % 2) * 400, (i ~/ 2) * 400)
      ..size = Vector2.all(400);
    game.add(root);
    build(root, 1, 400);
  }
  return game;
}

class _Tappable extends PositionComponent with TapCallbacks {}

// --- Runner ---------------------------------------------------------------

class FlameMicro {
  static final List<MicroResult> results = [];
  static String status = 'idle';

  static Future<List<MicroResult>> runAll({void Function(MicroResult)? onEach}) async {
    status = 'running';
    results.clear();
    for (final m in <_Micro>[_UpdateComponents(), _RenderComponents(), _FlatCollision(), _HitTest()]) {
      // Let a frame through between benchmarks so the UI can update.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final r = await _measure(m);
      results.add(r);
      debugPrint('[showcase] micro ${r.name}: ${r.perUnit.toStringAsFixed(2)} ${r.unit} '
          '(${r.usPerRun.round()} µs per run, ${r.runs} runs) — ${r.what}');
      onEach?.call(r);
    }
    status = 'done';
    debugPrint('[showcase] micro JSON: ${jsonEncode(toJson())}');
    return results;
  }

  static Map<String, Object> toJson() => {
        'status': status,
        'buildMode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
        'platform': defaultTargetPlatform.name,
        'results': [for (final r in results) r.toJson()],
      };

  static void registerExtension() {
    developer.registerExtension('ext.showcase.micro', (method, params) async {
      if (params['start'] == 'true' && status != 'running') unawaited(runAll());
      return developer.ServiceExtensionResponse.result(jsonEncode(toJson()));
    });
  }
}

class MicroBenchScreen extends StatefulWidget {
  const MicroBenchScreen({super.key});

  @override
  State<MicroBenchScreen> createState() => _MicroBenchScreenState();
}

class _MicroBenchScreenState extends State<MicroBenchScreen> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    await FlameMicro.runAll(onEach: (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = FlameMicro.results;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flame engine micro-benchmarks'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.data_object),
            label: const Text('Copy JSON'),
            onPressed: r.isEmpty ? null : () => Clipboard.setData(ClipboardData(text: jsonEncode(FlameMicro.toJson()))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Adapted from Flame\'s own benchmark suite (package:flame/benchmark). '
            'Runs on the UI thread; the screen freezes for ~10 s while it runs.',
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _running ? null : _run, child: Text(_running ? 'Running…' : 'Run')),
          const SizedBox(height: 12),
          for (final x in r)
            ListTile(
              title: Text('${x.name}: ${x.perUnit.toStringAsFixed(2)} ${x.unit}'),
              subtitle: Text('${x.what} · ${x.usPerRun.round()} µs per run · ${x.runs} runs'),
            ),
        ],
      ),
    );
  }
}
