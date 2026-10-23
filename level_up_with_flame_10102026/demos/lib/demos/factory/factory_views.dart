import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart' hide Matrix4, Timer;
import 'package:flame/events.dart';
import 'package:flame/extensions.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flame/particles.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/autopilot.dart';
import 'factory_model.dart';

enum FactoryMode {
  widgets('Widgets'),
  flame('Flame');

  const FactoryMode(this.label);
  final String label;
}

Widget buildFactory(FactoryMode mode, Factory f, {bool autopilot = false, MachineTap? onTap}) => switch (mode) {
      FactoryMode.widgets => FactoryWidgets(factory: f, autopilot: autopilot, onTap: onTap),
      FactoryMode.flame => FactoryFlameView(factory: f, autopilot: autopilot, onTap: onTap),
    };

const _ink = Color(0xFF1C1411);
const _duct = Color(0xFF3A2B24);
const _flow = Color(0xFFF7EFE4);

// ---------------------------------------------------------------------------
// Flutter only: Stack of machine widgets, setState on every sensor tick,
// ducts + flowing dots in an animated CustomPainter.

class FactoryWidgets extends StatefulWidget {
  const FactoryWidgets({super.key, required this.factory, required this.autopilot, this.onTap});
  final Factory factory;
  final bool autopilot;
  final MachineTap? onTap;

  @override
  State<FactoryWidgets> createState() => _FactoryWidgetsState();
}

class _FactoryWidgetsState extends State<FactoryWidgets> with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final Timer _feed;
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(0);
  Size _view = Size.zero;
  bool _fitted = false;

  Factory get _f => widget.factory;

  @override
  void initState() {
    super.initState();
    _feed = _f.startFeed(onTick: () => setState(() {}));
    _ticker = createTicker((e) {
      final t = e.inMicroseconds / 1e6;
      _time.value = t;
      if (widget.autopilot && !_view.isEmpty) _tc.value = _matrix(CameraPose.at(t, _f.bounds, _view));
    })
      ..start();
  }

  Matrix4 _matrix(CameraPose p) => Matrix4.identity()
    ..translateByDouble(_view.width / 2, _view.height / 2, 0, 1)
    ..scaleByDouble(p.zoom, p.zoom, 1, 1)
    ..translateByDouble(-p.center.dx, -p.center.dy, 0, 1);

  @override
  void dispose() {
    _feed.cancel();
    _ticker.dispose();
    _time.dispose();
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _view = c.biggest;
      if (!_fitted && !widget.autopilot) {
        _fitted = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tc.value = _matrix(CameraPose(_f.bounds.center, CameraPose.fitZoom(_f.bounds, _view)));
        });
      }
      return InteractiveViewer(
        transformationController: _tc,
        constrained: false,
        minScale: 0.1,
        maxScale: 10,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: SizedBox.fromSize(
          size: _f.size,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _DuctPainter(_f, _time))),
              for (final m in _f.machines)
                Positioned.fromRect(
                  rect: m.rect,
                  child: GestureDetector(
                    onTap: () => widget.onTap?.call(m),
                    child: _MachineTile(m),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _MachineTile extends StatelessWidget {
  const _MachineTile(this.m);
  final Machine m;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tempColor(m.temp),
        borderRadius: BorderRadius.circular(8),
        border: m.alarm ? Border.all(color: const Color(0xFFFFE8D6), width: 3) : null,
      ),
      child: Center(
        child: Text(
          '${m.name}\n${m.temp.toStringAsFixed(1)}°C',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
        ),
      ),
    );
  }
}

/// Ducts and the dots flowing up them; dot count and speed follow power.
class _DuctPainter extends CustomPainter {
  _DuctPainter(this.f, this.time) : super(repaint: time);
  final Factory f;
  final ValueNotifier<double> time;

  static final _ductPaint = Paint()
    ..color = _duct
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;
  static final _flowPaint = Paint()..color = _flow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(const Offset(20, Factory.mainDuctY), Offset(size.width - 20, Factory.mainDuctY), _ductPaint);
    final t = time.value;
    for (final m in f.machines) {
      final (a, b) = Factory.duct(m);
      canvas.drawLine(a, b, _ductPaint);
      final dots = (m.power * 12).round();
      final len = a.dy - b.dy;
      for (var k = 0; k < dots; k++) {
        final phase = ((t * (0.4 + m.power) + k / dots) % 1.0);
        canvas.drawCircle(Offset(a.dx + math.sin(phase * 12 + k) * 2, a.dy - phase * len), 2.2, _flowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_DuctPainter old) => true;
}

// ---------------------------------------------------------------------------
// Flame: each machine is a component that reads its own data; airflow is a
// particle system per duct; camera handles pan/zoom.

class FactoryFlameView extends StatefulWidget {
  const FactoryFlameView({super.key, required this.factory, required this.autopilot, this.onTap});
  final Factory factory;
  final bool autopilot;
  final MachineTap? onTap;

  @override
  State<FactoryFlameView> createState() => _FactoryFlameViewState();
}

class _FactoryFlameViewState extends State<FactoryFlameView> {
  late final FactoryGame _game = FactoryGame(widget.factory, autopilot: widget.autopilot, onTap: widget.onTap);
  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (_) => _lastScale = 1,
      onScaleUpdate: (d) {
        _game.panZoom(d.focalPointDelta, d.scale / _lastScale, d.localFocalPoint);
        _lastScale = d.scale;
      },
      child: GameWidget(game: _game),
    );
  }
}

class FactoryGame extends FlameGame {
  FactoryGame(this.f, {required this.autopilot, this.onTap});

  final Factory f;
  final bool autopilot;
  final MachineTap? onTap;
  late final Timer _feed;
  double _t = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder
      ..position = f.bounds.center.toVector2()
      ..zoom = CameraPose.fitZoom(f.bounds, size.toSize());
    world.add(_Ducts(f));
    for (final m in f.machines) {
      world.add(DuctFlow(m));
      world.add(MachineComponent(m, onTap));
    }
    // The feed just mutates the data; components read it when they render.
    _feed = f.startFeed(onTick: () {});
  }

  @override
  void onRemove() {
    _feed.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!autopilot) return;
    _t += dt;
    final p = CameraPose.at(_t, f.bounds, size.toSize());
    camera.viewfinder
      ..position = p.center.toVector2()
      ..zoom = p.zoom;
  }

  void panZoom(Offset delta, double scaleRatio, Offset focal) {
    final vf = camera.viewfinder;
    final half = Offset(size.x / 2, size.y / 2);
    final before = vf.position + ((focal - half) / vf.zoom).toVector2();
    vf.zoom = (vf.zoom * scaleRatio).clamp(0.1, 10.0);
    final after = before - ((focal - half) / vf.zoom).toVector2();
    vf.position = after - (delta / vf.zoom).toVector2();
  }
}

class _Ducts extends Component {
  // Drawn first: behind the airflow and the machines.
  _Ducts(this.f) : super(priority: -2);
  final Factory f;
  static final _paint = Paint()
    ..color = _duct
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    canvas.drawLine(const Offset(20, Factory.mainDuctY), Offset(f.size.width - 20, Factory.mainDuctY), _paint);
    for (final m in f.machines) {
      final (a, b) = Factory.duct(m);
      canvas.drawLine(a, b, _paint);
    }
  }
}

/// Spawns particles that rise up the duct; rate and speed follow power.
class DuctFlow extends Component {
  // Behind every machine (ducts pass under the machines in the rows above).
  DuctFlow(this.m) : super(priority: -1);
  final Machine m;
  double _acc = 0;
  final _rng = math.Random();
  static final _paint = Paint()..color = _flow;

  @override
  void update(double dt) {
    final rate = m.power * 10; // particles per second
    _acc += dt * rate;
    final (a, b) = Factory.duct(m);
    final life = (a.dy - b.dy) / (40 + m.power * 60);
    while (_acc >= 1) {
      _acc -= 1;
      final wobble = (_rng.nextDouble() - 0.5) * 4;
      add(ParticleSystemComponent(
        particle: MovingParticle(
          from: Vector2(a.dx + wobble, a.dy),
          to: Vector2(b.dx + wobble, b.dy),
          lifespan: life,
          child: CircleParticle(radius: 2.2, paint: _paint),
        ),
      ));
    }
  }
}

class MachineComponent extends PositionComponent with TapCallbacks {
  MachineComponent(this.m, this.onTap)
      : super(position: m.rect.topLeft.toVector2(), size: m.rect.size.toVector2());

  final Machine m;
  final MachineTap? onTap;
  final Paint _fill = Paint();
  static final _alarm = Paint()
    ..color = const Color(0xFFFFE8D6)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  late final RRect _rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8));
  final TextPainter _tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
  String _shown = '';
  double _pulse = 0;

  @override
  void update(double dt) {
    _pulse = m.alarm ? (_pulse + dt * 6) % (2 * math.pi) : 0;
  }

  @override
  void render(Canvas canvas) {
    _fill.color = tempColor(m.temp);
    canvas.drawRRect(_rrect, _fill);
    if (m.alarm) {
      _alarm.strokeWidth = 3 + 2 * math.sin(_pulse).abs();
      canvas.drawRRect(_rrect, _alarm);
    }
    final label = '${m.name}\n${m.temp.toStringAsFixed(1)}°C';
    if (label != _shown) {
      _shown = label;
      _tp
        ..text = TextSpan(
          text: label,
          style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
        )
        ..layout(maxWidth: size.x);
    }
    _tp.paint(canvas, Offset((size.x - _tp.width) / 2, (size.y - _tp.height) / 2));
  }

  @override
  void onTapUp(TapUpEvent event) => onTap?.call(m);
}
