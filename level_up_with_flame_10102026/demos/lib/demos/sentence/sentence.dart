import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:material_ui/material_ui.dart';

import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const sentence = ['Flutter', 'and', 'Flame', 'work', 'hand', 'in', 'hand'];

class SentenceScreen extends StatefulWidget {
  const SentenceScreen({super.key});

  @override
  State<SentenceScreen> createState() => _SentenceScreenState();
}

class _SentenceScreenState extends State<SentenceScreen> {
  int _round = 0;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Build the sentence',
      body: GameWidget<SentenceGame>(
        key: ValueKey(_round),
        game: SentenceGame(),
        overlayBuilderMap: {
          'hud': (_, g) => _Hud(g),
          'done': (_, g) => Center(
                child: Card(
                  color: Palette.card,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('Well done!',
                          style: TextStyle(color: Palette.cream, fontSize: 26, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text('${g.elapsed.toStringAsFixed(1)} s · ${g.mistakes} mistakes',
                          style: const TextStyle(color: Palette.muted)),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => setState(() => _round++), child: const Text('Play again')),
                    ]),
                  ),
                ),
              ),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}

/// Score and timer live in Flutter, in the app's own theme.
class _Hud extends StatelessWidget {
  const _Hud(this.g);
  final SentenceGame g;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<int>(
          valueListenable: g.placed,
          builder: (_, p, _) => LinearProgressIndicator(value: p / sentence.length, minHeight: 10),
        ),
      ),
    );
  }
}

class SentenceGame extends FlameGame {
  final ValueNotifier<int> placed = ValueNotifier(0);
  final List<Slot> slots = [];
  int mistakes = 0;
  double elapsed = 0;
  bool _done = false;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    final rng = math.Random(DateTime.now().millisecondsSinceEpoch);
    const w = 96.0, gap = 8.0;
    final perRow = math.max(1, ((size.x - 24) / (w + gap)).floor());
    for (var i = 0; i < sentence.length; i++) {
      final row = i ~/ perRow, col = i % perRow;
      final inRow = math.min(perRow, sentence.length - row * perRow);
      final x0 = (size.x - inRow * (w + gap) + gap) / 2;
      final s = Slot(i)..position = Vector2(x0 + col * (w + gap), 40 + row * 60.0);
      slots.add(s);
      add(s);
    }
    final order = List.generate(sentence.length, (i) => i)..shuffle(rng);
    for (var k = 0; k < order.length; k++) {
      final home = Vector2(
        30 + rng.nextDouble() * (size.x - 140),
        size.y * 0.45 + rng.nextDouble() * (size.y * 0.4 - 50),
      );
      add(Tile(sentence[order[k]], home)..position = home.clone());
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_done) elapsed += dt;
  }

  void onPlaced(Tile t) {
    placed.value++;
    add(ParticleSystemComponent(
      position: t.absoluteCenter,
      particle: Particle.generate(
        count: 16,
        lifespan: 0.6,
        generator: (i) => AcceleratedParticle(
          speed: Vector2(math.cos(i / 16 * 2 * math.pi), math.sin(i / 16 * 2 * math.pi)) * 160,
          acceleration: Vector2(0, 200),
          child: CircleParticle(radius: 3, paint: Paint()..color = Palette.gold),
        ),
      ),
    ));
    if (placed.value == sentence.length) {
      _done = true;
      overlays.add('done');
    }
  }
}

class Slot extends PositionComponent {
  Slot(this.index) : super(size: Vector2(96, 44));
  final int index;
  Tile? filled;
  static final _paint = Paint()
    ..color = const Color(0x55F7EFE4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) =>
      canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)), _paint);
}

class Tile extends PositionComponent with DragCallbacks, HasGameReference<SentenceGame> {
  Tile(this.word, this.home) : super(size: Vector2(96, 44));
  final String word;
  final Vector2 home;
  bool locked = false;
  double _t = math.Random().nextDouble() * 10;
  late final TextPainter _tp = TextPainter(
    text: TextSpan(text: word, style: const TextStyle(color: Palette.ink, fontSize: 18, fontWeight: FontWeight.w700)),
    textDirection: TextDirection.ltr,
  )..layout();
  final Paint _fill = Paint()..color = Palette.cream;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    // Idle float while waiting to be picked.
    if (!locked && !isDragged && children.whereType<Effect>().isEmpty) {
      position.y = home.y + math.sin(_t * 2) * 4;
    }
  }

  @override
  void render(Canvas canvas) {
    _fill.color = locked ? Palette.gold : Palette.cream;
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)), _fill);
    _tp.paint(canvas, Offset((size.x - _tp.width) / 2, (size.y - _tp.height) / 2));
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (locked) return;
    super.onDragStart(event);
    priority = 100;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!locked) position += event.canvasDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (locked) return;
    priority = 0;
    final c = absoluteCenter;
    Slot? target;
    for (final s in game.slots) {
      if (s.filled == null && s.toRect().inflate(20).contains(c.toOffset())) target = s;
    }
    if (target != null && sentence[target.index] == word) {
      locked = true;
      target.filled = this;
      add(MoveToEffect(target.position, EffectController(duration: 0.2, curve: Curves.easeOut),
          onComplete: () => game.onPlaced(this)));
    } else {
      if (target != null) game.mistakes++;
      add(SequenceEffect([
        MoveByEffect(Vector2(8, 0), EffectController(duration: 0.05, alternate: true, repeatCount: 3)),
        MoveToEffect(home, EffectController(duration: 0.5, curve: Curves.elasticOut)),
      ]));
    }
  }
}
