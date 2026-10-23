import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const stickerEmojis = ['🔥', '⭐', '💙', '🎸', '🌴', '🦋', '⚡', '🍕'];

class StickerScreen extends StatefulWidget {
  const StickerScreen({super.key});

  @override
  State<StickerScreen> createState() => _StickerScreenState();
}

class _StickerScreenState extends State<StickerScreen> {
  final StickerGame _game = StickerGame();

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Customise your tee',
      body: GameWidget(game: _game),
      bottom: Material(
        color: Palette.card,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    for (final e in stickerEmojis)
                      IconButton(
                        onPressed: () => _game.addSticker(e),
                        icon: Text(e, style: const TextStyle(fontSize: 32)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove selected',
                onPressed: _game.removeSelected,
                icon: const Icon(Icons.delete_outline, color: Palette.cream),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class StickerGame extends FlameGame {
  Sticker? selected;
  int _count = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async => add(Tee());

  void addSticker(String emoji) {
    final rng = math.Random(_count++);
    final s = Sticker(emoji)
      ..position = size / 2 + Vector2((rng.nextDouble() - 0.5) * 80, (rng.nextDouble() - 0.5) * 80)
      ..scale = Vector2.all(0.2);
    add(s);
    s.add(ScaleEffect.to(Vector2.all(1), EffectController(duration: 0.5, curve: Curves.elasticOut)));
    select(s);
  }

  void select(Sticker? s) {
    selected?.selected = false;
    selected = s;
    s?.selected = true;
  }

  void removeSelected() {
    final s = selected;
    if (s == null) return;
    select(null);
    s.add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2), onComplete: s.removeFromParent));
  }

}

/// A simple vector T-shirt.
class Tee extends PositionComponent with TapCallbacks, HasGameRef<StickerGame> {
  // Fills the game so taps on empty space deselect; stickers sit on top and
  // get their taps first.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size.clone();
  }

  @override
  void onTapUp(TapUpEvent event) => gameRef.select(null);

  static final _paint = Paint()..color = const Color(0xFF3A6EA5);
  static final _shade = Paint()..color = const Color(0x22000000);

  @override
  void render(Canvas canvas) {
    final s = gameRef.size;
    final w = math.min(s.x * 0.85, s.y * 0.8), h = w * 1.05;
    final o = Offset((s.x - w) / 2, (s.y - h) / 2);
    final p = Path()
      ..moveTo(o.dx + w * 0.32, o.dy)
      ..quadraticBezierTo(o.dx + w * 0.5, o.dy + h * 0.1, o.dx + w * 0.68, o.dy)
      ..lineTo(o.dx + w, o.dy + h * 0.16)
      ..lineTo(o.dx + w * 0.88, o.dy + h * 0.36)
      ..lineTo(o.dx + w * 0.78, o.dy + h * 0.3)
      ..lineTo(o.dx + w * 0.78, o.dy + h)
      ..lineTo(o.dx + w * 0.22, o.dy + h)
      ..lineTo(o.dx + w * 0.22, o.dy + h * 0.3)
      ..lineTo(o.dx + w * 0.12, o.dy + h * 0.36)
      ..lineTo(o.dx, o.dy + h * 0.16)
      ..close();
    canvas
      ..drawPath(p.shift(const Offset(0, 6)), _shade)
      ..drawPath(p, _paint);
  }
}

class Sticker extends PositionComponent with DragCallbacks, TapCallbacks, HasGameRef<StickerGame> {
  Sticker(this.emoji) : super(size: Vector2.all(96), anchor: Anchor.center);
  final String emoji;
  bool _selected = false;
  late final TextPainter _tp = TextPainter(
    text: TextSpan(text: emoji, style: const TextStyle(fontSize: 72)),
    textDirection: TextDirection.ltr,
  )..layout();
  static final _outline = Paint()
    ..color = Palette.cream
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  set selected(bool v) {
    _selected = v;
    children.whereType<RotateHandle>().forEach((h) => h.removeFromParent());
    if (v) add(RotateHandle()..position = size.clone());
  }

  @override
  void render(Canvas canvas) {
    _tp.paint(canvas, Offset((size.x - _tp.width) / 2, (size.y - _tp.height) / 2));
    if (_selected) {
      canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)), _outline);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    gameRef.select(this);
    priority = gameRef.children.length;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    gameRef.select(this);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => position += event.canvasDelta;

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    // A little "settle" wiggle when dropped.
    add(SequenceEffect([
      RotateEffect.by(0.08, EffectController(duration: 0.08)),
      RotateEffect.by(-0.16, EffectController(duration: 0.12)),
      RotateEffect.by(0.08, EffectController(duration: 0.08)),
    ]));
  }
}

/// Drag the corner handle to rotate and scale the sticker.
class RotateHandle extends CircleComponent with DragCallbacks, HasGameRef<StickerGame> {
  RotateHandle()
      : super(radius: 14, anchor: Anchor.center, paint: Paint()..color = Palette.flame);

  late Vector2 _from;
  late double _angle0, _scale0;

  Sticker get sticker => parent! as Sticker;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _from = event.canvasPosition - sticker.absoluteCenter;
    _angle0 = sticker.angle;
    _scale0 = sticker.scale.x;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final v = event.canvasEndPosition - sticker.absoluteCenter;
    sticker.angle = _angle0 + math.atan2(v.y, v.x) - math.atan2(_from.y, _from.x);
    sticker.scale = Vector2.all((_scale0 * v.length / _from.length).clamp(0.3, 4.0));
  }
}
