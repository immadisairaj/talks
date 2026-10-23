import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:material_ui/material_ui.dart' hide Matrix4;

import '../../common/autopilot.dart';
import 'seat_layout.dart';
import 'seat_views.dart';

// ---------------------------------------------------------------------------
// Flame: camera + either one component per seat, or one per section.

class SeatMapFlameView extends StatefulWidget {
  const SeatMapFlameView({
    super.key,
    required this.layout,
    required this.sections,
    required this.autopilot,
    required this.bookings,
  });
  final SeatLayout layout;
  final bool sections;
  final bool autopilot;
  final bool bookings;

  @override
  State<SeatMapFlameView> createState() => _SeatMapFlameViewState();
}

class _SeatMapFlameViewState extends State<SeatMapFlameView> {
  late final SeatMapGame _game = SeatMapGame(
    layout: widget.layout,
    sections: widget.sections,
    autopilot: widget.autopilot,
    bookings: widget.bookings,
  );
  double _lastScale = 1;

  @override
  Widget build(BuildContext context) {
    // Pan / pinch is handled by a plain Flutter GestureDetector around the
    // game; taps go through to Flame's TapCallbacks components.
    return Listener(
      // Mouse wheel zoom for desktop.
      onPointerSignal: (e) {
        if (e is PointerScrollEvent) {
          _game.panZoom(Offset.zero, math.exp(-e.scrollDelta.dy / 300), e.localPosition);
        }
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

class SeatMapGame extends FlameGame {
  SeatMapGame({required this.layout, required this.sections, required this.autopilot, required this.bookings});

  final SeatLayout layout;
  final bool sections;
  final bool autopilot;
  final bool bookings;
  late final BookingFeed _feed = BookingFeed(layout);
  final List<SectionComponent> _sections = [];
  double _t = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final b = layout.bounds;
    camera.viewfinder
      ..position = Vector2(b.center.dx, b.center.dy)
      ..zoom = CameraPose.fitZoom(b, Size(size.x, size.y));
    if (sections) {
      final groups = List.generate(layout.sectionCount, (_) => <int>[]);
      for (var i = 0; i < layout.n; i++) {
        groups[layout.section[i]].add(i);
      }
      for (final g in groups.where((g) => g.isNotEmpty)) {
        final s = SectionComponent(layout, g);
        _sections.add(s);
        world.add(s);
      }
    } else {
      for (var i = 0; i < layout.n; i++) {
        world.add(SeatComponent(layout, i));
      }
    }
    if (bookings) _feed.start(_markDirty);
  }

  final Map<int, SectionComponent> _bySection = {};

  void _markDirty(int seat) {
    if (!sections) return; // seat components read their state when rendering
    if (_bySection.isEmpty) {
      for (final s in _sections) {
        _bySection[layout.section[s.seats.first]] = s;
      }
    }
    _bySection[layout.section[seat]]?.dirty = true;
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
    final p = CameraPose.at(_t, layout.bounds, Size(size.x, size.y));
    camera.viewfinder
      ..position = Vector2(p.center.dx, p.center.dy)
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

final _paints = [for (final c in seatColors) Paint()..color = c];

/// One component per seat: the simple, idiomatic way.
class SeatComponent extends PositionComponent with TapCallbacks {
  SeatComponent(this.layout, this.i)
      : super(position: Vector2(layout.x[i], layout.y[i]), size: Vector2.all(Seat.size));

  final SeatLayout layout;
  final int i;
  static const _rect = Rect.fromLTWH(0, 0, Seat.size, Seat.size);

  @override
  void render(Canvas canvas) => canvas.drawRect(_rect, _paints[layout.state[i]]);

  @override
  void onTapUp(TapUpEvent event) => layout.toggle(i);
}

/// One component per section that draws all its seats in three
/// drawRawPoints calls, rebuilt only when a seat in it changes, and skipped
/// when the camera can't see it.
class SectionComponent extends PositionComponent with TapCallbacks, HasGameRef<SeatMapGame> {
  SectionComponent(this.layout, this.seats) {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final i in seats) {
      if (layout.x[i] < l) l = layout.x[i];
      if (layout.y[i] < t) t = layout.y[i];
      if (layout.x[i] > r) r = layout.x[i];
      if (layout.y[i] > b) b = layout.y[i];
    }
    rect = Rect.fromLTRB(l, t, r + Seat.size, b + Seat.size);
  }

  final SeatLayout layout;
  final List<int> seats;
  late final Rect rect;
  bool dirty = true;
  final List<Float32List> _points = [Float32List(0), Float32List(0), Float32List(0)];

  static final _pointPaints = [
    for (final c in seatColors)
      Paint()
        ..color = c
        ..strokeWidth = Seat.size
        ..strokeCap = StrokeCap.square,
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
  void render(Canvas canvas) {
    if (!gameRef.camera.visibleWorldRect.overlaps(rect)) return;
    if (dirty) _rebuild();
    for (var s = 0; s < 3; s++) {
      if (_points[s].isNotEmpty) canvas.drawRawPoints(PointMode.points, _points[s], _pointPaints[s]);
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
