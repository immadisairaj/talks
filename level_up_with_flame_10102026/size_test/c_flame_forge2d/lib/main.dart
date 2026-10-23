// Flame + Forge2D (Box2D v3 physics): a ball falling onto the ground.
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

void main() => runApp(MaterialApp(home: Scaffold(body: GameWidget(game: PhysicsGame()))));

class PhysicsGame extends Forge2DGame {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.addAll([Ball(), Ground()]);
  }
}

class Ball extends BodyComponent {
  @override
  Body createBody() => world.createBody(BodyDef(type: BodyType.dynamic, position: Vector2(0, -2)))
    ..createShape(Circle(radius: 0.3), ShapeDef(material: SurfaceMaterial(restitution: 0.6)));
}

class Ground extends BodyComponent {
  @override
  Body createBody() => world.createBody(BodyDef())
    ..createShape(Segment(point1: Vector2(-3, 2), point2: Vector2(3, 2)));
}
