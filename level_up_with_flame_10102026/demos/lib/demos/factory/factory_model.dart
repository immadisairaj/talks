import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';


/// A floor plan of machines with a duct from each machine up to a main duct,
/// plus a seeded fake sensor feed. Pure Dart, shared by both modes.
class Factory {
  Factory(this.count, {int seed = 5}) : _rng = math.Random(seed) {
    final cols = math.max(4, math.sqrt(count * 1.6).ceil());
    final rows = (count / cols).ceil();
    const cellW = 130.0, cellH = 110.0;
    for (var i = 0; i < count; i++) {
      final c = i % cols, r = i ~/ cols;
      machines.add(Machine(
        id: i,
        name: 'M-${(i + 1).toString().padLeft(3, '0')}',
        rect: Rect.fromLTWH(40 + c * cellW, 140 + r * cellH, 90, 56),
        temp: 50 + _rng.nextDouble() * 20,
        power: 0.3 + _rng.nextDouble() * 0.5,
      ));
    }
    size = Size(80 + cols * cellW, 180 + rows * cellH);
  }

  final int count;
  final math.Random _rng;
  final List<Machine> machines = [];
  late final Size size;
  static const mainDuctY = 60.0;

  Rect get bounds => Offset.zero & size;

  /// Updates every machine [hz] times per second.
  Timer startFeed({int hz = 20, required VoidCallback onTick}) {
    return Timer.periodic(Duration(microseconds: 1000000 ~/ hz), (_) {
      for (final m in machines) {
        m.temp = (m.temp + (_rng.nextDouble() - 0.48) * 1.6).clamp(35.0, 99.0);
        m.power = (m.power + (_rng.nextDouble() - 0.5) * 0.06).clamp(0.05, 1.0);
      }
      onTick();
    });
  }

  /// Duct from the top centre of a machine up to the main duct.
  static (Offset, Offset) duct(Machine m) =>
      (Offset(m.rect.center.dx, m.rect.top), Offset(m.rect.center.dx, mainDuctY));
}

class Machine {
  Machine({required this.id, required this.name, required this.rect, required this.temp, required this.power});
  final int id;
  final String name;
  final Rect rect;
  double temp;
  double power;

  bool get alarm => temp > 90;
}

/// Blue (cool) → orange → red (hot).
Color tempColor(double t) {
  final x = ((t - 40) / 55).clamp(0.0, 1.0);
  return x < 0.5
      ? Color.lerp(const Color(0xFF5AA9E6), const Color(0xFFFF7A2E), x * 2)!
      : Color.lerp(const Color(0xFFFF7A2E), const Color(0xFFE5383B), (x - 0.5) * 2)!;
}

/// Shows live details for one machine: a plain Flutter bottom sheet.
typedef MachineTap = void Function(Machine m);
