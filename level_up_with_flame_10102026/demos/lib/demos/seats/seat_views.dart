import 'package:material_ui/material_ui.dart';

import 'seat_flame.dart';
import 'seat_layout.dart';
import 'seat_painter.dart';
import 'seat_widgets.dart';

enum SeatMode {
  widgets('Widgets'),
  painter('CustomPainter'),
  flame('Flame · seat comps'),
  flameSections('Flame · sections');

  const SeatMode(this.label);
  final String label;
}

const seatColors = [Color(0xFF5AA9E6), Color(0xFFFF7A2E), Color(0xFF4A3B33)];

Widget buildSeatMap(SeatMode mode, SeatLayout layout, {bool autopilot = false, bool bookings = true}) =>
    switch (mode) {
      SeatMode.widgets => SeatMapWidgets(layout: layout, autopilot: autopilot, bookings: bookings),
      SeatMode.painter => SeatMapPainterView(layout: layout, autopilot: autopilot, bookings: bookings),
      SeatMode.flame || SeatMode.flameSections => SeatMapFlameView(
          layout: layout,
          sections: mode == SeatMode.flameSections,
          autopilot: autopilot,
          bookings: bookings,
        ),
    };
