import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show PointMode;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/events.dart';
import 'package:flame/extensions.dart' hide Matrix4;
import 'package:flame/game.dart' hide Matrix4;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../common/autopilot.dart';
import 'seat_layout.dart';

enum StadiumMode { widgets, flame }

const seatColors = [Color(0xFF55617E), Color(0xFFF2C766), Color(0xFF2A2A33)];

/// The pitch sits inside the innermost ring of seats.
Rect fieldRect(SeatLayout l) => Rect.fromCenter(center: Offset.zero, width: 390, height: 283);

Widget buildStadium(StadiumMode mode, SeatLayout layout, {required bool autopilot}) => switch (mode) {
      StadiumMode.widgets => StadiumWidgets(layout: layout, autopilot: autopilot),
      StadiumMode.flame => StadiumFlame(layout: layout, autopilot: autopilot),
    };

// ---------------------------------------------------------------------------
// Flutter widgets: InteractiveViewer + one widget per seat.

class StadiumWidgets extends StatefulWidget {
  const StadiumWidgets({super.key, required this.layout, required this.autopilot});
  final SeatLayout layout;
  final bool autopilot;

  @override
  State<StadiumWidgets> createState() => _StadiumWidgetsState();
}

class _StadiumWidgetsState extends State<StadiumWidgets> with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final BookingFeed _feed = BookingFeed(widget.layout);
  Ticker? _ticker;
  Size _view = Size.zero;
  bool _fitted = false;

  SeatLayout get _l => widget.layout;

  @override
  void initState() {
    super.initState();
    _feed.start((_) => setState(() {}));
    if (widget.autopilot) {
      _ticker = createTicker((e) {
        if (!_view.isEmpty) _tc.value = _matrix(CameraPose.at(e.inMicroseconds / 1e6, _l.bounds, _view));
      })
        ..start();
    }
  }

  Matrix4 _matrix(CameraPose p) => Matrix4.identity()
    ..translateByDouble(_view.width / 2, _view.height / 2, 0, 1)
    ..scaleByDouble(p.zoom, p.zoom, 1, 1)
    ..translateByDouble(-(p.center.dx - _l.bounds.left), -(p.center.dy - _l.bounds.top), 0, 1);

  @override
  void dispose() {
    _feed.stop();
    _ticker?.dispose();
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
          if (mounted) _tc.value = _matrix(CameraPose(_l.bounds.center, CameraPose.fitZoom(_l.bounds, _view)));
        });
      }
      final b = _l.bounds;
      final f = fieldRect(_l);
      return InteractiveViewer(
        transformationController: _tc,
        constrained: false,
        minScale: 0.05,
        maxScale: 20,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: SizedBox(
          width: b.width,
          height: b.height,
          child: Stack(
            children: [
              Positioned(
                left: f.left - b.left,
                top: f.top - b.top,
                width: f.width,
                height: f.height,
                child: Image.asset('assets/images/stadium_field.png', fit: BoxFit.fill),
              ),
              for (var i = 0; i < _l.n; i++)
                Positioned(
                  left: _l.x[i] - b.left,
                  top: _l.y[i] - b.top,
                  width: Seat.size,
                  height: Seat.size,
                  child: GestureDetector(
                    onTap: () => setState(() => _l.toggle(i)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: seatColors[_l.state[i]],
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Flame: Stadium (world + camera) → Blocks (components) → Seats (plain data).

class StadiumFlame extends StatefulWidget {
  const StadiumFlame({super.key, required this.layout, required this.autopilot});
  final SeatLayout layout;
  final bool autopilot;

  @override
  State<StadiumFlame> createState() => _StadiumFlameState();
}

class _StadiumFlameState extends State<StadiumFlame> {
  late final StadiumGame _game = StadiumGame(widget.layout, autopilot: widget.autopilot);
  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) _game.panZoom(Offset.zero, math.exp(-e.scrollDelta.dy / 300), e.localPosition);
      },
      child: GestureDetector(
        onScaleStart: (_) => _lastScale = 1,
        onScaleUpdate: (d) {
          _game.panZoom(d.focalPointDelta, d.scale / _lastScale, d.localFocalPoint);
          _lastScale = d.scale;
        },
        child: GameWidget(game: _game),
      ),
    );
  }
}

class StadiumGame extends FlameGame {
  StadiumGame(this.layout, {required this.autopilot});

  final SeatLayout layout;
  final bool autopilot;
  late final BookingFeed _feed = BookingFeed(layout);
  final Map<int, SeatBlock> _blocks = {};
  double _t = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final b = layout.bounds;
    camera.viewfinder
      ..position = Vector2(b.center.dx, b.center.dy)
      ..zoom = CameraPose.fitZoom(b, size.toSize());
    final f = fieldRect(layout);
    world.add(SpriteComponent(
      sprite: await Sprite.load('stadium_field.png', images: images),
      position: f.topLeft.toVector2(),
      size: f.size.toVector2(),
      priority: -1,
    ));
    final groups = <int, List<int>>{};
    for (var i = 0; i < layout.n; i++) {
      (groups[layout.section[i]] ??= []).add(i);
    }
    for (final e in groups.entries) {
      final block = SeatBlock(layout, e.value);
      _blocks[e.key] = block;
      world.add(block);
    }
    _feed.start((seat) => _blocks[layout.section[seat]]?.dirty = true);
  }

  @override
  void onRemove() {
    _feed.stop();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!autopilot) return;
    _t += dt;
    final p = CameraPose.at(_t, layout.bounds, size.toSize());
    camera.viewfinder
      ..position = p.center.toVector2()
      ..zoom = p.zoom;
  }

  void panZoom(Offset delta, double scaleRatio, Offset focal) {
    final vf = camera.viewfinder;
    final half = Offset(size.x / 2, size.y / 2);
    final before = vf.position + ((focal - half) / vf.zoom).toVector2();
    vf.zoom = (vf.zoom * scaleRatio).clamp(0.05, 20.0);
    final after = before - ((focal - half) / vf.zoom).toVector2();
    vf.position = after - (delta / vf.zoom).toVector2();
  }
}

/// One stand block: draws all its seats in three batched calls, redraws only
/// when one of its seats changed, skips itself when the camera can't see it,
/// and turns a tap into "the nearest seat".
class SeatBlock extends PositionComponent with TapCallbacks, HasGameReference<StadiumGame> {
  SeatBlock(this.layout, this.seats) {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final i in seats) {
      l = math.min(l, layout.x[i]);
      t = math.min(t, layout.y[i]);
      r = math.max(r, layout.x[i]);
      b = math.max(b, layout.y[i]);
    }
    rect = Rect.fromLTRB(l, t, r + Seat.size, b + Seat.size);
  }

  final SeatLayout layout;
  final List<int> seats;
  late final Rect rect;
  bool dirty = true;
  final List<Float32List> _points = List.filled(3, Float32List(0));

  static final _paints = [
    for (final c in seatColors)
      Paint()
        ..color = c
        ..strokeWidth = Seat.size
        ..strokeCap = StrokeCap.round,
  ];

  void _rebuild() {
    final lists = [<double>[], <double>[], <double>[]];
    for (final i in seats) {
      lists[layout.state[i]]
        ..add(layout.x[i] + Seat.size / 2)
        ..add(layout.y[i] + Seat.size / 2);
    }
    for (var s = 0; s < 3; s++) {
      _points[s] = Float32List.fromList(lists[s]);
    }
    dirty = false;
  }

  @override
  bool containsLocalPoint(Vector2 point) => rect.contains(point.toOffset());

  @override
  void render(ui.Canvas canvas) {
    if (!game.camera.visibleWorldRect.overlaps(rect)) return;
    if (dirty) _rebuild();
    for (var s = 0; s < 3; s++) {
      if (_points[s].isNotEmpty) canvas.drawRawPoints(PointMode.points, _points[s], _paints[s]);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    final p = event.localPosition;
    var best = -1;
    var bestD = Seat.pitch * Seat.pitch;
    for (final i in seats) {
      final dx = layout.x[i] + Seat.size / 2 - p.x, dy = layout.y[i] + Seat.size / 2 - p.y;
      final d = dx * dx + dy * dy;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    if (best >= 0) {
      layout.toggle(best);
      dirty = true;
    }
  }
}
