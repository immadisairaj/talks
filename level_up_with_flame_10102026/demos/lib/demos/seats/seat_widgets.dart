import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/autopilot.dart';
import 'seat_layout.dart';
import 'seat_views.dart';

// ---------------------------------------------------------------------------
// Flutter only: InteractiveViewer + one widget per seat.

class SeatMapWidgets extends StatefulWidget {
  const SeatMapWidgets({super.key, required this.layout, required this.autopilot, required this.bookings});
  final SeatLayout layout;
  final bool autopilot;
  final bool bookings;

  @override
  State<SeatMapWidgets> createState() => _SeatMapWidgetsState();
}

class _SeatMapWidgetsState extends State<SeatMapWidgets> with SingleTickerProviderStateMixin {
  final TransformationController _tc = TransformationController();
  late final BookingFeed _feed = BookingFeed(widget.layout);
  Ticker? _ticker;
  Size _view = Size.zero;
  bool _fitted = false;

  SeatLayout get _l => widget.layout;

  @override
  void initState() {
    super.initState();
    if (widget.bookings) _feed.start((_) => setState(() {}));
    if (widget.autopilot) {
      _ticker = createTicker((e) {
        if (_view.isEmpty) return;
        _tc.value = _matrix(CameraPose.at(e.inMicroseconds / 1e6, _l.bounds, _view));
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
          if (mounted) {
            _tc.value = _matrix(CameraPose(_l.bounds.center, CameraPose.fitZoom(_l.bounds, _view)));
          }
        });
      }
      final b = _l.bounds;
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
              for (var i = 0; i < _l.n; i++)
                Positioned(
                  left: _l.x[i] - b.left,
                  top: _l.y[i] - b.top,
                  width: Seat.size,
                  height: Seat.size,
                  child: _SeatTile(
                    color: seatColors[_l.state[i]],
                    onTap: () => setState(() => _l.toggle(i)),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _SeatTile extends StatelessWidget {
  const _SeatTile({required this.color, required this.onTap});
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: ColoredBox(color: color));
}

