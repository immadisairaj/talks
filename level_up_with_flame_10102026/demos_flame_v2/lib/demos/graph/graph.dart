import 'dart:math' as math;

import 'package:flame/components.dart' hide World;
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const graphSizes = [40, 80, 160];

List<Scenario> graphSuite() => [
      for (final n in graphSizes)
        Scenario(suite: 'graph', mode: 'flame', load: n, note: 'forge2d springs + n² repulsion, kick every 2 s',
            build: () => GraphView(nodes: n, autopilot: true)),
    ];

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  int _n = 80;
  final ValueNotifier<int?> _picked = ValueNotifier(null);

  @override
  void dispose() {
    _picked.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Your network',
      controls: Wrap(spacing: 8, children: [
        for (final n in graphSizes)
          ChoiceChip(label: Text('$n people'), selected: _n == n, onSelected: (_) => setState(() => _n = n)),
      ]),
      body: KeyedSubtree(key: ValueKey(_n), child: GraphView(nodes: _n, picked: _picked)),
      bottom: ValueListenableBuilder<int?>(
        valueListenable: _picked,
        builder: (_, p, _) => Material(
          color: Palette.card,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: p == null ? Palette.muted : Palette.dots[p % Palette.dots.length],
              child: Text(p == null ? '?' : '${p + 1}'),
            ),
            title: Text(p == null ? 'Drag people around · tap one to focus' : 'Person ${p + 1}',
                style: const TextStyle(color: Palette.cream)),
            subtitle: p == null
                ? null
                : Text('${3 + p % 17} mutual connections', style: const TextStyle(color: Palette.muted)),
          ),
        ),
      ),
    );
  }
}

class GraphView extends StatefulWidget {
  const GraphView({super.key, required this.nodes, this.picked, this.autopilot = false});
  final int nodes;
  final ValueNotifier<int?>? picked;
  final bool autopilot;

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> {
  late final GraphGame _game = GraphGame(widget.nodes, picked: widget.picked, autopilot: widget.autopilot);

  @override
  void dispose() {
    final w = _game.world.physicsWorld;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (w.isValid) w.destroy();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}

class GraphGame extends Forge2DGame {
  GraphGame(this.n, {this.picked, required this.autopilot}) : super(gravity: Vector2.zero(), metersToPixels: 60);
  final int n;
  final ValueNotifier<int?>? picked;
  final bool autopilot;
  late final Body ground;
  final List<Person> people = [];
  final List<(int, int)> edges = [];
  final _rng = math.Random(8);
  double _t = 0;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    ground = world.createBody(BodyDef());
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * 2 * math.pi, r = _rng.nextDouble() * 4;
      final p = Person(i, Vector2(math.cos(a) * r, math.sin(a) * r));
      people.add(p);
    }
    world.addAll(people);
    // A random tree plus some extra links.
    for (var i = 1; i < n; i++) {
      edges.add((i, _rng.nextInt(i)));
    }
    for (var k = 0; k < n ~/ 3; k++) {
      final a = _rng.nextInt(n), b = _rng.nextInt(n);
      if (a != b) edges.add((a, b));
    }
    world.add(_Edges(this));
  }

  bool _ready = false;

  /// Joints need every body, so they are created once all people loaded.
  void _makeJoints() {
    for (final (a, b) in edges) {
      world.physicsWorld.createDistanceJoint(DistanceJointDef(
        bodyA: people[a].body,
        bodyB: people[b].body,
        length: 1.4,
        enableSpring: true,
        hertz: 1.5,
        dampingRatio: 0.4,
        collideConnected: true,
      ));
    }
    _ready = true;
  }

  @override
  void update(double dt) {
    if (!_ready) {
      if (people.every((p) => p.isLoaded)) _makeJoints();
      super.update(dt);
      return;
    }
    // Pairwise repulsion + gentle pull to the centre.
    for (var i = 0; i < people.length; i++) {
      final bi = people[i].body;
      final pi = bi.position;
      final f = -pi * 0.4;
      for (var j = 0; j < people.length; j++) {
        if (i == j) continue;
        final d = pi - people[j].body.position;
        final l2 = math.max(d.length2, 0.04);
        if (l2 < 9) f.add(d * (1.2 / l2));
      }
      bi.applyForce(f * bi.mass);
    }
    super.update(dt);
    if (autopilot) {
      _t += dt;
      if (_t > 2) {
        _t = 0;
        people[_rng.nextInt(n)].body.applyLinearImpulse((Vector2.random(_rng) - Vector2.all(0.5)) * 6);
      }
    }
  }

  void focus(int i) {
    picked?.value = i;
    camera.moveTo(people[i].body.position.clone(), speed: 12);
    camera.viewfinder.add(ScaleEffect.to(Vector2.all(1.6), EffectController(duration: 0.5, curve: Curves.easeOut)));
  }
}

class _Edges extends Component {
  _Edges(this.g) : super(priority: -1);
  final GraphGame g;
  final Paint _paint = Paint()
    ..color = const Color(0x66F7EFE4)
    ..strokeWidth = 0.03;

  @override
  void render(Canvas canvas) {
    if (!g._ready) return;
    for (final (a, b) in g.edges) {
      canvas.drawLine(g.people[a].body.position.toOffset(), g.people[b].body.position.toOffset(), _paint);
    }
  }
}

class Person extends BodyComponent<GraphGame> with TapCallbacks, DragCallbacks {
  Person(this.i, this._start) : super(paint: Paint()..color = Palette.dots[i % Palette.dots.length]);
  final int i;
  final Vector2 _start;
  MouseJoint? _drag;
  static const radius = 0.2;

  @override
  Body createBody() {
    final b = world.createBody(BodyDef(type: BodyType.dynamic, position: _start, linearDamping: 3, fixedRotation: true));
    b.createShape(Circle(radius: radius), ShapeDef(material: SurfaceMaterial(restitution: 0.2)));
    return b;
  }

  @override
  void render(Canvas canvas) {
    final sel = gameRef.picked?.value == i;
    canvas.drawCircle(Offset.zero, sel ? radius * 1.5 : radius, paint);
  }

  @override
  void onTapUp(TapUpEvent event) => gameRef.focus(i);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _drag = world.physicsWorld.createMouseJoint(MouseJointDef(
      bodyA: gameRef.ground,
      bodyB: body,
      target: gameRef.screenToWorld(event.canvasPosition),
      maxForce: 2000 * body.mass,
      hertz: 6,
    ));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => _drag?.target = gameRef.screenToWorld(event.canvasEndPosition);

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _drag?.destroy();
    _drag = null;
  }
}
