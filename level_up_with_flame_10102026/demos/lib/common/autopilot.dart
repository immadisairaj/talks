import 'dart:math' as math;
import 'dart:ui';

/// Scripted camera path used by benchmarks so every mode sees exactly the
/// same pan/zoom motion. Zoom goes 1× → 3× → 1× (relative to "fit") every
/// 8 s while the centre circles the content.
class CameraPose {
  const CameraPose(this.center, this.zoom);
  final Offset center;
  final double zoom;

  static double fitZoom(Rect content, Size view) =>
      0.95 * math.min(view.width / content.width, view.height / content.height);

  static CameraPose at(double t, Rect content, Size view) {
    final fit = fitZoom(content, view);
    final z = fit * (1 + 2 * (0.5 - 0.5 * math.cos(2 * math.pi * t / 8)));
    final c = content.center +
        Offset(
          math.cos(2 * math.pi * t / 5) * content.width * 0.25,
          math.sin(2 * math.pi * t / 5) * content.height * 0.25,
        );
    return CameraPose(c, z);
  }
}
