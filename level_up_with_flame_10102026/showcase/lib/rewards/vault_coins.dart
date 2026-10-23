import 'dart:ui' as ui;

import 'package:flame/components.dart' hide World;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

/// A gold coin: a Forge2D circle body drawn with the coin sprite.
/// Shared by the rewards vault and the checkout cashback rain.
class Coin extends BodyComponent {
  Coin(this._start, this._velocity, this.image, {this.radius = 0.12}) : super(renderBody: false, priority: 1);

  final Vector2 _start, _velocity;
  final ui.Image image;
  final double radius;
  late final Rect _src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  late final Rect _dst = Rect.fromCircle(center: Offset.zero, radius: radius);
  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Called when the coin has fallen far below the screen.
  VoidCallback? onLost;

  @override
  Body createBody() {
    final b = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: _start,
      linearVelocity: _velocity,
      angularVelocity: _velocity.x * 4,
    ));
    b.createShape(Circle(radius: radius), ShapeDef(material: SurfaceMaterial(restitution: 0.35, friction: 0.5)));
    return b;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (body.position.y > 30) {
      onLost?.call();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) => canvas.drawImageRect(image, _src, _dst, _paint);
}

/// Draws [image] stretched into [rect] (world units).
class ImageRectComponent extends Component {
  ImageRectComponent(this.image, this.rect, {super.priority});
  final ui.Image image;
  final Rect rect;
  late final Rect _src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void render(Canvas canvas) => canvas.drawImageRect(image, _src, rect, _paint);
}
