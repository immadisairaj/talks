// Flame: the same moving dot as a component, plus a tap, a collision and an
// effect, so the commonly used parts of Flame are compiled in.
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(MaterialApp(home: Scaffold(body: GameWidget(game: DotGame()))));

class DotGame extends FlameGame with HasCollisionDetection {
  @override
  Future<void> onLoad() async {
    world.addAll([Dot(), Wall()]);
  }
}

class Dot extends CircleComponent with TapCallbacks, CollisionCallbacks {
  Dot() : super(radius: 20, paint: Paint()..color = Colors.orange, anchor: Anchor.center);

  @override
  Future<void> onLoad() async => add(CircleHitbox());

  @override
  void update(double dt) {
    super.update(dt);
    position.x = (position.x + 100 * dt) % 200 - 100;
  }

  @override
  void onTapUp(TapUpEvent event) => add(ScaleEffect.by(Vector2.all(1.3), EffectController(duration: 0.2, alternate: true)));

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    paint.color = Colors.red;
  }
}

class Wall extends RectangleComponent {
  Wall() : super(position: Vector2(60, -40), size: Vector2(10, 80), paint: Paint()..color = Colors.grey);

  @override
  Future<void> onLoad() async => add(RectangleHitbox());
}
