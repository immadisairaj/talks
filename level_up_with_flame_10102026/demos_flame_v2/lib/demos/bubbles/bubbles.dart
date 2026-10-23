import 'dart:math' as math;

import 'package:flame/extensions.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const topics = [
  'Flutter', 'Dart', 'Games', 'Design', 'Music', 'Cricket', 'Travel', 'Food', 'Movies', 'AI',
  'Startups', 'Photography', 'Fitness', 'Books', 'Art', 'Space', 'Coffee', 'Open source', 'Anime', 'Dance',
  'Chess', 'Podcasts', 'Cooking', 'Hiking', 'Robotics', 'Finance', 'Fashion', 'Gaming', 'Science', 'History',
];

const bubbleCounts = [30, 100, 300];

List<Scenario> bubblesSuite() => [
      for (final n in bubbleCounts)
        Scenario(suite: 'bubbles', mode: 'flame', load: n, note: 'forge2d + shake every 1.5 s',
            build: () => BubblesView(count: n, autopilot: true)),
    ];

class BubblesScreen extends StatefulWidget {
  const BubblesScreen({super.key});

  @override
  State<BubblesScreen> createState() => _BubblesScreenState();
}

class _BubblesScreenState extends State<BubblesScreen> {
  bool _flame = true;
  final ValueNotifier<Set<String>> _selected = ValueNotifier({});

  @override
  void dispose() {
    _selected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Pick your interests',
      controls: SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('Flutter: Wrap of chips')),
          ButtonSegment(value: true, label: Text('Flame + Forge2D')),
        ],
        selected: {_flame},
        onSelectionChanged: (s) => setState(() => _flame = s.first),
      ),
      body: _flame
          ? BubblesView(count: topics.length, selected: _selected)
          : _ChipsView(selected: _selected),
      bottom: _ContinueBar(selected: _selected),
    );
  }
}

/// The "before": perfectly fine, perfectly static.
class _ChipsView extends StatelessWidget {
  const _ChipsView({required this.selected});
  final ValueNotifier<Set<String>> selected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: selected,
      builder: (context, sel, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in topics)
              FilterChip(
                label: Text(t),
                selected: sel.contains(t),
                onSelected: (v) => selected.value = v ? {...sel, t} : ({...sel}..remove(t)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.selected});
  final ValueNotifier<Set<String>> selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: selected,
            builder: (context, sel, _) => Row(
              children: [
                Expanded(
                  child: Text(
                    sel.length < 3 ? 'Pick at least 3 (${sel.length}/3)' : sel.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Palette.cream, fontSize: 15),
                  ),
                ),
                FilledButton(onPressed: sel.length < 3 ? null : () {}, child: const Text('Continue')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class BubblesView extends StatefulWidget {
  const BubblesView({super.key, required this.count, this.selected, this.autopilot = false});
  final int count;
  final ValueNotifier<Set<String>>? selected;
  final bool autopilot;

  @override
  State<BubblesView> createState() => _BubblesViewState();
}

class _BubblesViewState extends State<BubblesView> {
  late final BubblesGame _game = BubblesGame(
    count: widget.count,
    selected: widget.selected ?? ValueNotifier({}),
    autopilot: widget.autopilot,
  );

  @override
  void dispose() {
    // Box2D worlds hold native memory and are capped in number, so free the
    // world once the game has been torn down.
    final w = _game.world.physicsWorld;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (w.isValid) w.destroy();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}

class BubblesGame extends Forge2DGame {
  BubblesGame({required this.count, required this.selected, required this.autopilot})
      : super(gravity: Vector2.zero());

  final int count;
  final ValueNotifier<Set<String>> selected;
  final bool autopilot;
  late final Body ground;
  double _t = 0;
  final _rng = math.Random(3);

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    ground = world.createBody(BodyDef());
    final r = camera.visibleWorldRect;
    // Walls around the visible area.
    final corners = [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];
    for (var i = 0; i < 4; i++) {
      ground.createShape(
        Segment(point1: corners[i].toVector2(), point2: corners[(i + 1) % 4].toVector2()),
      );
    }
    final area = r.width * r.height;
    // Scale radii so the bubbles fill about half the screen at any count.
    final base = math.sqrt(area * 0.5 / (count * math.pi));
    for (var i = 0; i < count; i++) {
      final label = topics[i % topics.length];
      world.add(Bubble(
        label: count <= topics.length ? label : '',
        radius: base * (0.8 + _rng.nextDouble() * 0.4),
        position: Vector2(
          r.left + _rng.nextDouble() * r.width,
          r.top + _rng.nextDouble() * r.height,
        ),
        color: Palette.dots[i % Palette.dots.length],
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!autopilot) return;
    _t += dt;
    if (_t > 1.5) {
      _t = 0;
      for (final b in world.children.whereType<Bubble>()) {
        b.body.applyLinearImpulse(
          (Vector2.random(_rng) - Vector2.all(0.5)) * 8 * b.body.mass,
        );
      }
    }
  }

  void toggle(String label) {
    final s = {...selected.value};
    s.contains(label) ? s.remove(label) : s.add(label);
    selected.value = s;
  }
}

class Bubble extends BodyComponent<BubblesGame> with TapCallbacks, DragCallbacks {
  Bubble({required this.label, required this.radius, required Vector2 position, required Color color})
      : _start = position,
        super(paint: Paint()..color = color, renderBody: false);

  final String label;
  final double radius;
  final Vector2 _start;
  double _shownRadius = 0;
  MouseJoint? _drag;
  TextPainter? _tp;

  bool get selected => gameRef.selected.value.contains(label);
  double get _targetRadius => selected ? radius * 1.35 : radius;

  @override
  Body createBody() {
    final body = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: _start,
      linearDamping: 2,
      angularDamping: 2,
    ));
    _setShape(body, radius);
    return body;
  }

  void _setShape(Body body, double r) {
    for (final s in body.shapes) {
      s.destroy();
    }
    body.createShape(
      Circle(radius: r),
      ShapeDef(material: SurfaceMaterial(restitution: 0.3, friction: 0.2)),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Pull everything gently toward the centre of the screen.
    final toCenter = gameRef.camera.viewfinder.position - body.position;
    body.applyForce(toCenter * 3 * body.mass);
    _shownRadius += (_targetRadius - _shownRadius) * math.min(1, dt * 10);
  }

  @override
  void render(Canvas canvas) {
    final sel = selected;
    paint.color = paint.color.withValues(alpha: sel ? 1 : 0.75);
    canvas.drawCircle(Offset.zero, _shownRadius, paint);
    if (sel) {
      canvas.drawCircle(
        Offset.zero,
        _shownRadius,
        Paint()
          ..color = Palette.cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05,
      );
    }
    if (label.isEmpty) return;
    // Text is laid out in pixels, so draw it un-zoomed and counter-rotated.
    final m2p = gameRef.metersToPixels;
    _tp ??= TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF1C1411), fontSize: 15, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas
      ..save()
      ..rotate(-body.angle)
      ..scale(1 / m2p);
    _tp!.paint(canvas, Offset(-_tp!.width / 2, -_tp!.height / 2));
    canvas.restore();
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (label.isEmpty) return;
    gameRef.toggle(label);
    _setShape(body, _targetRadius);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _drag = world.physicsWorld.createMouseJoint(MouseJointDef(
      bodyA: gameRef.ground,
      bodyB: body,
      target: gameRef.screenToWorld(event.canvasPosition),
      maxForce: 1000 * body.mass,
      hertz: 6,
    ));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _drag?.target = gameRef.screenToWorld(event.canvasEndPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _drag?.destroy();
    _drag = null;
  }
}
