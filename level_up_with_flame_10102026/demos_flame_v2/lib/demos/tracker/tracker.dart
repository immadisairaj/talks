import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../bench/bench.dart';
import '../../common/autopilot.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const riderCounts = [50, 200, 500, 1000];

enum TrackerMode {
  widgets('Widgets'),
  flame('Flame');

  const TrackerMode(this.label);
  final String label;
}

List<Scenario> trackerSuite() => [
      for (final n in riderCounts)
        for (final m in TrackerMode.values)
          Scenario(suite: 'tracker', mode: m.name, load: n, note: 'autopilot camera',
              build: () => buildTracker(m, City(n), autopilot: true)),
    ];

Widget buildTracker(TrackerMode m, City c, {bool autopilot = false, ValueNotifier<int?>? followed}) => switch (m) {
      TrackerMode.widgets => TrackerWidgets(city: c, autopilot: autopilot, followed: followed),
      TrackerMode.flame => TrackerFlameView(city: c, autopilot: autopilot, followed: followed),
    };

/// A grid city with seeded rider routes along the streets. Pure Dart.
class City {
  City(this.riders, {int seed = 21}) {
    final r = math.Random(seed);
    for (var i = 0; i < riders; i++) {
      var x = r.nextInt(blocks + 1), y = r.nextInt(blocks + 1);
      final path = ui.Path()..moveTo(x * block, y * block);
      var lastDir = -1;
      for (var s = 0; s < 10; s++) {
        int dir;
        do {
          dir = r.nextInt(4);
        } while (dir == (lastDir + 2) % 4 ||
            (dir == 0 && x == blocks) ||
            (dir == 2 && x == 0) ||
            (dir == 1 && y == blocks) ||
            (dir == 3 && y == 0));
        lastDir = dir;
        final len = 1 + r.nextInt(3);
        for (var k = 0; k < len; k++) {
          if (dir == 0 && x < blocks) x++;
          if (dir == 2 && x > 0) x--;
          if (dir == 1 && y < blocks) y++;
          if (dir == 3 && y > 0) y--;
        }
        path.lineTo(x * block, y * block);
      }
      routes.add(path);
      metrics.add(path.computeMetrics().first);
      durations.add(14 + r.nextDouble() * 12);
      colors.add(Palette.dots[i % Palette.dots.length]);
    }
  }

  final int riders;
  static const blocks = 20;
  static const block = 120.0;
  final List<ui.Path> routes = [];
  final List<ui.PathMetric> metrics = [];
  final List<double> durations = [];
  final List<Color> colors = [];

  Rect get bounds => const Rect.fromLTWH(-60, -60, blocks * block + 120, blocks * block + 120);

  /// Back-and-forth progress along route [i] at time [t] (same as an
  /// alternating EffectController).
  Offset at(int i, double t) {
    final d = durations[i];
    final cycle = (t / d) % 2;
    final p = cycle < 1 ? cycle : 2 - cycle;
    final m = metrics[i];
    return m.getTangentForOffset(p * m.length)!.position;
  }
}

class _Streets extends CustomPainter {
  static final _road = Paint()
    ..color = const Color(0xFF2B201B)
    ..strokeWidth = 18;
  static final _block = Paint()..color = const Color(0xFF241A16);

  static void paintCity(Canvas canvas) {
    const n = City.blocks, b = City.block;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(i * b + 14, j * b + 14, b - 28, b - 28), const Radius.circular(10)),
          _block,
        );
      }
    }
    for (var i = 0; i <= n; i++) {
      canvas
        ..drawLine(Offset(i * b, 0), Offset(i * b, n * b), _road)
        ..drawLine(Offset(0, i * b), Offset(n * b, i * b), _road);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(60, 60);
    paintCity(canvas);
  }

  @override
  bool shouldRepaint(_Streets old) => false;
}

// ---------------------------------------------------------------------------
// Flutter only.

class TrackerWidgets extends StatefulWidget {
  const TrackerWidgets({super.key, required this.city, required this.autopilot, this.followed});
  final City city;
  final bool autopilot;
  final ValueNotifier<int?>? followed;

  @override
  State<TrackerWidgets> createState() => _TrackerWidgetsState();
}

class _TrackerWidgetsState extends State<TrackerWidgets> with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final Ticker _ticker;
  double _t = 0;
  Size _view = Size.zero;
  bool _fitted = false;

  City get _c => widget.city;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      setState(() => _t = e.inMicroseconds / 1e6);
      if (_view.isEmpty) return;
      final f = widget.followed?.value;
      if (widget.autopilot) {
        _tc.value = _matrix(CameraPose.at(_t, _c.bounds, _view));
      } else if (f != null) {
        _tc.value = _matrix(CameraPose(_c.at(f, _t), 2.5));
      }
    })
      ..start();
  }

  Matrix4 _matrix(CameraPose p) => Matrix4.identity()
    ..translateByDouble(_view.width / 2, _view.height / 2, 0, 1)
    ..scaleByDouble(p.zoom, p.zoom, 1, 1)
    ..translateByDouble(-(p.center.dx - _c.bounds.left), -(p.center.dy - _c.bounds.top), 0, 1);

  @override
  void dispose() {
    _ticker.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      _view = cons.biggest;
      if (!_fitted && !widget.autopilot) {
        _fitted = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tc.value = _matrix(CameraPose(_c.bounds.center, CameraPose.fitZoom(_c.bounds, _view)));
        });
      }
      final b = _c.bounds;
      return InteractiveViewer(
        transformationController: _tc,
        constrained: false,
        minScale: 0.05,
        maxScale: 10,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: SizedBox(
          width: b.width,
          height: b.height,
          child: Stack(
            children: [
              Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _Streets()))),
              for (var i = 0; i < _c.riders; i++)
                Builder(builder: (_) {
                  final p = _c.at(i, _t);
                  return Positioned(
                    left: p.dx - b.left - 8,
                    top: p.dy - b.top - 8,
                    width: 16,
                    height: 16,
                    child: GestureDetector(
                      onTap: () => widget.followed?.value = i,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _c.colors[i],
                          shape: BoxShape.circle,
                          border: Border.all(color: Palette.ink, width: 2),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Flame.

class TrackerFlameView extends StatefulWidget {
  const TrackerFlameView({super.key, required this.city, required this.autopilot, this.followed});
  final City city;
  final bool autopilot;
  final ValueNotifier<int?>? followed;

  @override
  State<TrackerFlameView> createState() => _TrackerFlameViewState();
}

class _TrackerFlameViewState extends State<TrackerFlameView> {
  late final TrackerGame _game = TrackerGame(widget.city, autopilot: widget.autopilot, followed: widget.followed);
  double _last = 1;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onScaleStart: (_) => _last = 1,
        onScaleUpdate: (d) {
          _game.panZoom(d.focalPointDelta, d.scale / _last, d.localFocalPoint);
          _last = d.scale;
        },
        child: GameWidget(game: _game),
      );
}

class TrackerGame extends FlameGame {
  TrackerGame(this.city, {required this.autopilot, this.followed});
  final City city;
  final bool autopilot;
  final ValueNotifier<int?>? followed;
  final List<Rider> _riders = [];
  double _t = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..position = city.bounds.center.toVector2()
      ..zoom = CameraPose.fitZoom(city.bounds, size.toSize());
    world.add(_StreetsComponent());
    for (var i = 0; i < city.riders; i++) {
      final r = Rider(i, city.colors[i])
        ..add(MoveAlongPathEffect(
          city.routes[i],
          EffectController(duration: city.durations[i], alternate: true, infinite: true),
          absolute: true,
        ));
      _riders.add(r);
      world.add(r);
    }
  }

  void follow(int i) {
    followed?.value = i;
    camera.follow(_riders[i], maxSpeed: 1500);
    camera.viewfinder.add(ScaleEffect.to(Vector2.all(2.5), EffectController(duration: 0.6, curve: Curves.easeOut)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!autopilot) return;
    _t += dt;
    final p = CameraPose.at(_t, city.bounds, size.toSize());
    camera.viewfinder
      ..position = p.center.toVector2()
      ..zoom = p.zoom;
  }

  void panZoom(Offset delta, double scaleRatio, Offset focal) {
    camera.stop();
    final vf = camera.viewfinder;
    final half = Offset(size.x / 2, size.y / 2);
    final before = vf.position + ((focal - half) / vf.zoom).toVector2();
    vf.zoom = (vf.zoom * scaleRatio).clamp(0.05, 10.0);
    final after = before - ((focal - half) / vf.zoom).toVector2();
    vf.position = after - (delta / vf.zoom).toVector2();
  }
}

/// The static streets are recorded once into a Picture and replayed each
/// frame (the Flame equivalent of the RepaintBoundary in the widget version).
class _StreetsComponent extends Component {
  late final ui.Picture _picture = () {
    final rec = ui.PictureRecorder();
    _Streets.paintCity(Canvas(rec));
    return rec.endRecording();
  }();

  @override
  void render(Canvas canvas) => canvas.drawPicture(_picture);

  @override
  void onRemove() {
    _picture.dispose();
    super.onRemove();
  }
}

class Rider extends CircleComponent with TapCallbacks, HasGameRef<TrackerGame> {
  Rider(this.i, Color color)
      : super(
          radius: 8,
          anchor: Anchor.center,
          paint: Paint()..color = color,
          children: [
            CircleComponent(
              radius: 8,
              paint: Paint()
                ..color = Palette.ink
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
            ),
          ],
        );
  final int i;

  @override
  void onTapUp(TapUpEvent event) => gameRef.follow(i);
}

// ---------------------------------------------------------------------------

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  TrackerMode _mode = TrackerMode.flame;
  int _n = 200;
  late City _city = City(_n);
  final ValueNotifier<int?> _followed = ValueNotifier(null);

  void _reset({TrackerMode? mode, int? n}) => setState(() {
        _mode = mode ?? _mode;
        _n = n ?? _n;
        _city = City(_n);
        _followed.value = null;
      });

  @override
  void dispose() {
    _followed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Delivery tracker',
      controls: Column(children: [
        SegmentedButton<TrackerMode>(
          showSelectedIcon: false,
          segments: [for (final m in TrackerMode.values) ButtonSegment(value: m, label: Text(m.label))],
          selected: {_mode},
          onSelectionChanged: (s) => _reset(mode: s.first),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final n in riderCounts)
            ChoiceChip(label: Text('$n riders'), selected: _n == n, onSelected: (_) => _reset(n: n)),
        ]),
      ]),
      body: KeyedSubtree(key: ObjectKey(_city), child: buildTracker(_mode, _city, followed: _followed)),
      bottom: ValueListenableBuilder<int?>(
        valueListenable: _followed,
        builder: (_, f, _) => Material(
          color: Palette.card,
          child: ListTile(
            leading: const Icon(Icons.delivery_dining, color: Palette.flame),
            title: Text(f == null ? 'Tap a rider to follow it' : 'Order #${4100 + f}',
                style: const TextStyle(color: Palette.cream)),
            subtitle: f == null
                ? null
                : Text('Rider ${f + 1} · arriving in ${3 + f % 9} min', style: const TextStyle(color: Palette.muted)),
          ),
        ),
      ),
    );
  }
}
