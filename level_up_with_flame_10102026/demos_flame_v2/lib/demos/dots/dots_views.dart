import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/palette.dart';
import 'dots_sim.dart';

enum DotsMode {
  widgets('Widgets'),
  painter('CustomPainter'),
  flame('Flame'),
  flameBatch('Flame (1 comp)');

  const DotsMode(this.label);
  final String label;
}

Widget buildDots(DotsMode mode, int n) => switch (mode) {
      DotsMode.widgets => DotsWidgets(n: n),
      DotsMode.painter => DotsPainterView(n: n),
      DotsMode.flame => DotsFlameView(n: n, batch: false),
      DotsMode.flameBatch => DotsFlameView(n: n, batch: true),
    };

final _paints = [
  for (final c in Palette.dots) Paint()..color = c,
];

// ---------------------------------------------------------------------------
// 1. Widgets: one Positioned per dot, setState every frame.

class DotsWidgets extends StatefulWidget {
  const DotsWidgets({super.key, required this.n});
  final int n;

  @override
  State<DotsWidgets> createState() => _DotsWidgetsState();
}

class _DotsWidgetsState extends State<DotsWidgets> with SingleTickerProviderStateMixin {
  late final DotsSim _sim = DotsSim(widget.n);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  static final _decorations = [
    for (final c in Palette.dots) BoxDecoration(color: c, shape: BoxShape.circle),
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      setState(() => _sim.step(dt));
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _sim.layout(c.biggest);
      const d = DotsSim.radius * 2;
      return Stack(
        children: [
          for (var i = 0; i < _sim.n; i++)
            Positioned(
              left: _sim.x[i] - DotsSim.radius,
              top: _sim.y[i] - DotsSim.radius,
              width: d,
              height: d,
              child: DecoratedBox(decoration: _decorations[i % _decorations.length]),
            ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 2. CustomPainter: one painter, repainted by a ticker.

class DotsPainterView extends StatefulWidget {
  const DotsPainterView({super.key, required this.n});
  final int n;

  @override
  State<DotsPainterView> createState() => _DotsPainterViewState();
}

class _DotsPainterViewState extends State<DotsPainterView> with SingleTickerProviderStateMixin {
  late final DotsSim _sim = DotsSim(widget.n);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
      _last = elapsed;
      _sim.step(dt);
      _frame.value++;
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _sim.layout(c.biggest);
      return CustomPaint(size: c.biggest, painter: _DotsPainter(_sim, _frame));
    });
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.sim, Listenable repaint) : super(repaint: repaint);
  final DotsSim sim;

  @override
  void paint(Canvas canvas, Size size) => paintDots(canvas, sim);

  @override
  bool shouldRepaint(_DotsPainter old) => old.sim != sim;
}

void paintDots(Canvas canvas, DotsSim sim) {
  for (var i = 0; i < sim.n; i++) {
    canvas.drawCircle(Offset(sim.x[i], sim.y[i]), DotsSim.radius, _paints[i % _paints.length]);
  }
}

// ---------------------------------------------------------------------------
// 3. Flame: one component per dot (or one component drawing all of them).

class DotsFlameView extends StatefulWidget {
  const DotsFlameView({super.key, required this.n, required this.batch});
  final int n;
  final bool batch;

  @override
  State<DotsFlameView> createState() => _DotsFlameViewState();
}

class _DotsFlameViewState extends State<DotsFlameView> {
  late final DotsGame _game = DotsGame(n: widget.n, batch: widget.batch);

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}

class DotsGame extends FlameGame {
  DotsGame({required this.n, required this.batch});

  final int n;
  final bool batch;
  late final DotsSim sim = DotsSim(n);

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    sim.layout(Size(size.x, size.y));
    if (batch) {
      add(_DotsBatch(sim));
      return;
    }
    for (var i = 0; i < n; i++) {
      add(DotComponent(
        position: Vector2(sim.x[i], sim.y[i]),
        velocity: Vector2(sim.vx[i], sim.vy[i]),
        paint: _paints[i % _paints.length],
      ));
    }
  }
}

/// A dot that owns its own position and velocity, like any game object.
class DotComponent extends PositionComponent with HasGameRef<DotsGame> {
  DotComponent({required super.position, required this.velocity, required this.paint})
      : super(size: Vector2.all(DotsSim.radius * 2), anchor: Anchor.center);

  final Vector2 velocity;
  final Paint paint;

  static const _center = Offset(DotsSim.radius, DotsSim.radius);

  @override
  void update(double dt) {
    position.x += velocity.x * dt;
    position.y += velocity.y * dt;
    final w = gameRef.size.x, h = gameRef.size.y;
    const r = DotsSim.radius;
    if (position.x < r || position.x > w - r) {
      velocity.x = -velocity.x;
      position.x = position.x.clamp(r, w - r);
    }
    if (position.y < r || position.y > h - r) {
      velocity.y = -velocity.y;
      position.y = position.y.clamp(r, h - r);
    }
  }

  @override
  void render(Canvas canvas) => canvas.drawCircle(_center, DotsSim.radius, paint);
}

class _DotsBatch extends Component {
  _DotsBatch(this.sim);
  final DotsSim sim;

  @override
  void update(double dt) => sim.step(dt);

  @override
  void render(Canvas canvas) => paintDots(canvas, sim);
}
