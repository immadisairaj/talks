import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Seat states.
abstract final class Seat {
  static const available = 0;
  static const selected = 1;
  static const booked = 2;

  static const size = 6.0;
  static const pitch = 8.0;
}

/// An oval stadium: rows of seats in rings, split into 16 sectors with aisles
/// and into tiers every 12 rows. Pure Dart so both modes share it.
class SeatLayout {
  SeatLayout(this.total) {
    final xs = <double>[], ys = <double>[];
    final secs = <int>[], prices = <int>[];
    const sectors = 16;
    const aisle = 0.035; // radians kept empty at each sector edge
    var row = 0;
    var radius = 150.0;
    while (xs.length < total) {
      final tier = row ~/ 12;
      final count = (2 * math.pi * radius * 1.2 / Seat.pitch).floor();
      for (var k = 0; k < count && xs.length < total; k++) {
        final a = 2 * math.pi * k / count;
        final within = a % (2 * math.pi / sectors);
        if (within < aisle || within > 2 * math.pi / sectors - aisle) continue;
        xs.add(math.cos(a) * radius * 1.4);
        ys.add(math.sin(a) * radius);
        secs.add(tier * sectors + (a / (2 * math.pi / sectors)).floor());
        prices.add(tier == 0 ? 2500 : (tier == 1 ? 1500 : 800));
      }
      row++;
      radius += Seat.pitch;
      if (row % 12 == 0) radius += 14; // walkway between tiers
    }
    n = xs.length;
    x = Float32List.fromList(xs);
    y = Float32List.fromList(ys);
    section = Int32List.fromList(secs);
    price = Int32List.fromList(prices);
    state = Uint8List(n);
    sectionCount = secs.isEmpty ? 0 : secs.reduce(math.max) + 1;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < n; i++) {
      minX = math.min(minX, x[i]);
      minY = math.min(minY, y[i]);
      maxX = math.max(maxX, x[i]);
      maxY = math.max(maxY, y[i]);
    }
    bounds = Rect.fromLTRB(minX - 20, minY - 20, maxX + 20 + Seat.size, maxY + 20 + Seat.size);
  }

  final int total;
  late final int n;
  late final Float32List x, y;
  late final Int32List section, price;
  late final Uint8List state;
  late final int sectionCount;
  late final Rect bounds;

  /// Selected seat ids, listened to by the Flutter checkout bar.
  final ValueNotifier<Set<int>> selection = ValueNotifier(<int>{});

  void toggle(int i) {
    if (state[i] == Seat.booked) return;
    final s = {...selection.value};
    if (state[i] == Seat.selected) {
      state[i] = Seat.available;
      s.remove(i);
    } else {
      state[i] = Seat.selected;
      s.add(i);
    }
    selection.value = s;
  }
}

/// Fake "other users booking seats" stream: [rate] bookings per second,
/// seeded so every run books the same seats in the same order.
class BookingFeed {
  BookingFeed(this.layout, {this.rate = 30, int seed = 99}) : _rng = math.Random(seed);

  final SeatLayout layout;
  final int rate;
  final math.Random _rng;
  Timer? _timer;

  void start(void Function(int seat) onBooked) {
    _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ rate), (_) {
      for (var tries = 0; tries < 8; tries++) {
        final i = _rng.nextInt(layout.n);
        if (layout.state[i] == Seat.available) {
          layout.state[i] = Seat.booked;
          onBooked(i);
          return;
        }
      }
    });
  }

  void stop() => _timer?.cancel();
}
