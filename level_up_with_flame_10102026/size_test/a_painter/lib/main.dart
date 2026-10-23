// Baseline: plain Flutter with an animated CustomPainter (no Flame).
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: Scaffold(body: Dots())));

class Dots extends StatefulWidget {
  const Dots({super.key});
  @override
  State<Dots> createState() => _DotsState();
}

class _DotsState extends State<Dots> with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _t = ValueNotifier(0);
  late final Ticker _ticker = createTicker((e) => _t.value = e.inMicroseconds / 1e6)..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _P(_t), size: Size.infinite);
}

class _P extends CustomPainter {
  _P(this.t) : super(repaint: t);
  final ValueNotifier<double> t;
  @override
  void paint(Canvas c, Size s) =>
      c.drawCircle(Offset(s.width / 2 + 100 * (t.value % 1), s.height / 2), 20, Paint()..color = Colors.orange);
  @override
  bool shouldRepaint(_P o) => true;
}
