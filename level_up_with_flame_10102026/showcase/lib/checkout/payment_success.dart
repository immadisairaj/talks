import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Transform;
import 'package:material_ui/material_ui.dart' hide Matrix4;

import '../common/theme.dart';
import '../rewards/vault_coins.dart';

/// Payment success: Flutter content on top, Flame + Forge2D behind it raining
/// cashback coins that pile up at the bottom of the screen.
class PaymentSuccessScreen extends StatefulWidget {
  const PaymentSuccessScreen({super.key});

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  late final CashbackRain _rain = CashbackRain();

  @override
  void dispose() {
    final w = _rain.world.physicsWorld;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (w.isValid) w.destroy();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: GameWidget(game: _rain)),
        SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Image.asset('assets/images/success_tick.png', width: 110, height: 110),
              ),
              const SizedBox(height: 22),
              const Text('Payment successful',
                  style: TextStyle(color: Pal.text, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('₹4,999 paid · Studio Wireless', style: TextStyle(color: Pal.muted, fontSize: 15)),
              const SizedBox(height: 18),
              ValueListenableBuilder<int>(
                valueListenable: _rain.landed,
                builder: (_, n, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: Pal.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Pal.gold.withValues(alpha: 0.5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Image.asset('assets/images/coin.png', width: 22, height: 22),
                      const SizedBox(width: 8),
                      Text('+$n cashback coins',
                          style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
            ]),
          ),
        ),
      ]),
    );
  }
}

class CashbackRain extends Forge2DGame {
  CashbackRain() : super(gravity: Vector2(0, 12));

  static const total = 50;
  final ValueNotifier<int> landed = ValueNotifier(0);
  final List<Coin> _coins = [];
  final _rng = math.Random(17);
  late final Rect _r;
  double _acc = 0;
  int _spawned = 0;

  @override
  Color backgroundColor() => Pal.bg;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.load('coin.png');
    _r = camera.visibleWorldRect;
    final ground = world.createBody(BodyDef());
    final bl = Vector2(_r.left, _r.bottom - 0.02), br = Vector2(_r.right, _r.bottom - 0.02);
    ground
      ..createShape(Segment(point1: bl, point2: br))
      ..createShape(Segment(point1: Vector2(_r.left, _r.top - 3), point2: bl))
      ..createShape(Segment(point1: Vector2(_r.right, _r.top - 3), point2: br));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _acc += dt * 35;
    while (_acc >= 1 && _spawned < total) {
      _acc -= 1;
      _spawned++;
      final c = Coin(
        Vector2(_r.left + 0.3 + _rng.nextDouble() * (_r.width - 0.6), _r.top - 0.3 - _rng.nextDouble()),
        Vector2((_rng.nextDouble() - 0.5) * 1.5, 0),
        images.fromCache('coin.png'),
        radius: 0.16,
      );
      _coins.add(c);
      world.add(c);
    }
    var n = 0;
    for (final c in _coins) {
      if (c.isLoaded && c.body.position.y > _r.bottom - 1.2) n++;
    }
    if (n != landed.value) landed.value = n;
  }
}
