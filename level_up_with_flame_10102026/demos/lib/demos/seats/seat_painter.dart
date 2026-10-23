import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/scheduler.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:material_ui/material_ui.dart';

import '../../common/autopilot.dart';
import 'seat_layout.dart';
import 'seat_views.dart';

// ---------------------------------------------------------------------------
// CustomPainter: fast drawing, but camera, pan/zoom maths, tap hit-testing
// and change tracking are all written by hand.

class SeatMapPainterView extends StatefulWidget {
  const SeatMapPainterView({super.key, required this.layout, required this.autopilot, required this.bookings});
  final SeatLayout layout;
  final bool autopilot;
  final bool bookings;

  @override
  State<SeatMapPainterView> createState() => _SeatMapPainterViewState();
}

class _SeatMapPainterViewState extends State<SeatMapPainterView> with SingleTickerProviderStateMixin {
  late final BookingFeed _feed = BookingFeed(widget.layout);
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  Ticker? _ticker;
  Size _view = Size.zero;
  Offset? _center;
  double? _zoom;
  double _lastScale = 1;
  bool _dirty = true;
  final List<Float32List> _points = [Float32List(0), Float32List(0), Float32List(0)];

  SeatLayout get _l => widget.layout;

  @override
  void initState() {
    super.initState();
    if (widget.bookings) {
      _feed.start((_) {
        _dirty = true;
        _repaint.value++;
      });
    }
    if (widget.autopilot) {
      _ticker = createTicker((e) {
        if (_view.isEmpty) return;
        final p = CameraPose.at(e.inMicroseconds / 1e6, _l.bounds, _view);
        _center = p.center;
        _zoom = p.zoom;
        _repaint.value++;
      })
        ..start();
    }
  }

  @override
  void dispose() {
    _feed.stop();
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _rebuildPoints() {
    final lists = [<double>[], <double>[], <double>[]];
    for (var i = 0; i < _l.n; i++) {
      lists[_l.state[i]]
        ..add(_l.x[i] + Seat.size / 2)
        ..add(_l.y[i] + Seat.size / 2);
    }
    for (var s = 0; s < 3; s++) {
      _points[s] = Float32List.fromList(lists[s]);
    }
    _dirty = false;
  }

  Offset _toWorld(Offset local) => _center! + (local - _view.center(Offset.zero)) / _zoom!;

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final ratio = d.scale / _lastScale;
    _lastScale = d.scale;
    final before = _toWorld(d.localFocalPoint);
    _zoom = (_zoom! * ratio).clamp(0.05, 20.0);
    final after = _toWorld(d.localFocalPoint);
    _center = _center! + (before - after) - d.focalPointDelta / _zoom!;
    _repaint.value++;
  }

  void _onTapUp(TapUpDetails d) {
    final w = _toWorld(d.localPosition);
    var best = -1;
    var bestD = Seat.pitch * Seat.pitch;
    for (var i = 0; i < _l.n; i++) {
      final dx = _l.x[i] + Seat.size / 2 - w.dx, dy = _l.y[i] + Seat.size / 2 - w.dy;
      final dd = dx * dx + dy * dy;
      if (dd < bestD) {
        bestD = dd;
        best = i;
      }
    }
    if (best >= 0) {
      _l.toggle(best);
      _dirty = true;
      _repaint.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      _view = c.biggest;
      _center ??= _l.bounds.center;
      _zoom ??= CameraPose.fitZoom(_l.bounds, _view);
      return Listener(
        // Mouse wheel zoom for desktop.
        onPointerSignal: (e) {
          if (e is PointerScrollEvent) {
            _lastScale = 1;
            _onScaleUpdate(ScaleUpdateDetails(
              localFocalPoint: e.localPosition,
              focalPoint: e.position,
              scale: math.exp(-e.scrollDelta.dy / 300),
            ));
          }
        },
        child: GestureDetector(
        onScaleStart: (_) => _lastScale = 1,
        onScaleUpdate: _onScaleUpdate,
        onTapUp: _onTapUp,
        child: CustomPaint(
          size: c.biggest,
          painter: _SeatPainter(this, _repaint),
        ),
        ),
      );
    });
  }
}

class _SeatPainter extends CustomPainter {
  _SeatPainter(this.s, Listenable repaint) : super(repaint: repaint);
  final _SeatMapPainterViewState s;

  static final _paints = [
    for (final c in seatColors)
      Paint()
        ..color = c
        ..strokeWidth = Seat.size
        ..strokeCap = StrokeCap.square,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (s._dirty) s._rebuildPoints();
    final z = s._zoom!;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(z)
      ..translate(-s._center!.dx, -s._center!.dy);
    for (var k = 0; k < 3; k++) {
      if (s._points[k].isNotEmpty) canvas.drawRawPoints(PointMode.points, s._points[k], _paints[k]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeatPainter old) => true;
}

