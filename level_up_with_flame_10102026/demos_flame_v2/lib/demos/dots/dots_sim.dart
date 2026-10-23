import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Plain-Dart bouncing-dot simulation shared by the widget and painter modes,
/// and used to seed the Flame mode, so every mode starts from the same state.
class DotsSim {
  DotsSim(this.n, {this.seed = 42})
      : x = Float32List(n),
        y = Float32List(n),
        vx = Float32List(n),
        vy = Float32List(n);

  final int n;
  final int seed;
  final Float32List x, y, vx, vy;
  Size _size = Size.zero;

  static const radius = 4.0;

  Size get size => _size;

  /// (Re)places the dots when the area size changes.
  void layout(Size size) {
    if (size == _size || size.isEmpty) return;
    _size = size;
    final r = math.Random(seed);
    for (var i = 0; i < n; i++) {
      x[i] = radius + r.nextDouble() * (size.width - 2 * radius);
      y[i] = radius + r.nextDouble() * (size.height - 2 * radius);
      final a = r.nextDouble() * math.pi * 2;
      final speed = 60 + r.nextDouble() * 140;
      vx[i] = math.cos(a) * speed;
      vy[i] = math.sin(a) * speed;
    }
  }

  void step(double dt) {
    final w = _size.width, h = _size.height;
    if (w == 0) return;
    for (var i = 0; i < n; i++) {
      var px = x[i] + vx[i] * dt;
      var py = y[i] + vy[i] * dt;
      if (px < radius || px > w - radius) {
        vx[i] = -vx[i];
        px = px.clamp(radius, w - radius);
      }
      if (py < radius || py > h - radius) {
        vy[i] = -vy[i];
        py = py.clamp(radius, h - radius);
      }
      x[i] = px;
      y[i] = py;
    }
  }
}
