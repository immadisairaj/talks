import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:material_ui/material_ui.dart';

import '../common/theme.dart';
import 'payment_success.dart';

/// A normal Flutter product page. A transparent Flame layer on top handles
/// the "fly into the cart" moment; Flutter owns everything else.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();
  final GlobalKey _cartKey = GlobalKey();
  late final MomentsGame _fx = MomentsGame(onArrive: _onArrive);
  int _cart = 0;
  int _bump = 0;

  void _onArrive() => setState(() {
        _cart++;
        _bump++;
      });

  Rect _rectOf(GlobalKey k) {
    final box = k.currentContext!.findRenderObject()! as RenderBox;
    final stack = _stackKey.currentContext!.findRenderObject()! as RenderBox;
    final tl = stack.globalToLocal(box.localToGlobal(Offset.zero));
    return tl & box.size;
  }

  void _addToCart() => _fx.flyToCart(_rectOf(_imageKey), _rectOf(_cartKey).center);

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _stackKey,
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Audio'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(clipBehavior: Clip.none, children: [
                  IconButton(key: _cartKey, onPressed: () {}, icon: const Icon(Icons.shopping_bag_outlined)),
                  if (_cart > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_bump),
                        tween: Tween(begin: 1.6, end: 1),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.elasticOut,
                        builder: (_, s, child) => Transform.scale(scale: s, child: child),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Pal.gold, borderRadius: BorderRadius.circular(10)),
                          child: Text('$_cart',
                              style: const TextStyle(color: Color(0xFF111114), fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset('assets/images/product_headphones.png', key: _imageKey, height: 320, fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              const Text('Studio Wireless',
                  style: TextStyle(color: Pal.text, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Over-ear · Active noise cancelling · 40 h battery',
                  style: TextStyle(color: Pal.muted, fontSize: 14)),
              const SizedBox(height: 14),
              const Row(children: [
                Text('₹4,999', style: TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
                SizedBox(width: 10),
                Text('₹7,999',
                    style: TextStyle(color: Pal.muted, fontSize: 16, decoration: TextDecoration.lineThrough)),
                SizedBox(width: 10),
                Text('37% off', style: TextStyle(color: Pal.green, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              const Text('Pay now and get 50 cashback coins',
                  style: TextStyle(color: Pal.gold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Pal.text,
                      side: const BorderSide(color: Pal.line),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _addToCart,
                    child: const Text('Add to cart', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => const PaymentSuccessScreen())),
                    child: const Text('Pay ₹4,999'),
                  ),
                ),
              ]),
            ],
          ),
        ),
        // The Flame layer: transparent, never blocks touches.
        Positioned.fill(child: IgnorePointer(child: GameWidget(game: _fx))),
      ],
    );
  }
}

/// Transparent effects layer drawn over the Flutter page, in screen pixels.
class MomentsGame extends FlameGame {
  MomentsGame({required this.onArrive});
  final VoidCallback onArrive;
  final _rng = math.Random(5);

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() => images.loadAll(['product_headphones.png', 'coin.png']);

  void flyToCart(Rect from, Offset to) {
    const start = 140.0;
    final img = images.fromCache('product_headphones.png');
    final p0 = from.center;
    final ctrl = Offset((p0.dx + to.dx) / 2 + 60, math.min(p0.dy, to.dy) - 160);
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    final flyer = _Flyer(Sprite(img), size: Vector2.all(start), position: p0.toVector2());
    flyer.addAll([
      MoveAlongPathEffect(path, EffectController(duration: 0.75, curve: Curves.easeInOutCubic), absolute: true),
      ScaleEffect.to(Vector2.all(0.16), EffectController(duration: 0.75, curve: Curves.easeInCubic)),
      RotateEffect.by(0.6, EffectController(duration: 0.75)),
      OpacityEffect.to(0.85, EffectController(duration: 0.75), onComplete: () {
        flyer.removeFromParent();
        _burst(to);
        onArrive();
      }),
    ]);
    add(flyer);
  }

  void _burst(Offset at) {
    add(ParticleSystemComponent(
      position: at.toVector2(),
      particle: Particle.generate(
        count: 18,
        lifespan: 0.55,
        generator: (i) {
          final a = i / 18 * 2 * math.pi;
          return AcceleratedParticle(
            speed: Vector2(math.cos(a), math.sin(a)) * (120 + _rng.nextDouble() * 80),
            acceleration: Vector2(0, 260),
            child: ComputedParticle(
              renderer: (c, p) => c.drawCircle(
                Offset.zero,
                3.2 * (1 - p.progress),
                Paint()..color = Pal.gold.withValues(alpha: 1 - p.progress),
              ),
            ),
          );
        },
      ),
    ));
  }
}

/// The flying product leaves a short golden trail behind it.
class _Flyer extends SpriteComponent {
  _Flyer(Sprite sprite, {required super.size, required super.position})
      : super(sprite: sprite, anchor: Anchor.center, priority: 10);
  double _acc = 0;
  static final _rng = math.Random(9);

  @override
  void update(double dt) {
    super.update(dt);
    _acc += dt;
    while (_acc > 0.016) {
      _acc -= 0.016;
      parent?.add(ParticleSystemComponent(
        position: position.clone() + (Vector2.random(_rng) - Vector2.all(0.5)) * 10 * scale.x,
        particle: ComputedParticle(
          lifespan: 0.35,
          renderer: (c, p) => c.drawCircle(
            Offset.zero,
            4 * (1 - p.progress),
            Paint()..color = Pal.gold.withValues(alpha: 0.8 * (1 - p.progress)),
          ),
        ),
      ));
    }
  }

  @override
  void render(ui.Canvas canvas) {
    // Rounded clip so the product reads as a thumbnail while flying.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(size.toRect(), Radius.circular(size.x * 0.2)));
    super.render(canvas);
    canvas.restore();
  }
}
