import 'dart:math' as math;

import 'package:flame/components.dart' hide World;
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

import '../../bench/bench.dart';
import '../../common/demo_scaffold.dart';
import '../../common/palette.dart';

const coinLoads = [50, 150, 400];

/// 5 coins = ₹1, so a full card (40 coins) is a modest ₹8.
String _rupees(int coins) => '₹${coins ~/ 5}';

List<Scenario> rewardsSuite() => [
      for (final n in coinLoads)
        Scenario(
          suite: 'rewards',
          mode: 'flame',
          load: n,
          note: 'coins: auto-scratch, Forge2D coins piling into a bowl',
          build: () => RewardView(benchCoins: n),
        ),
    ];

/// A plain Flutter "savings" screen. The reward is a GameWidget in a dialog.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Savings',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Goal: New laptop', style: TextStyle(color: Palette.muted, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('₹10,000 / ₹10,000',
              style: TextStyle(color: Palette.cream, fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const LinearProgressIndicator(value: 1, minHeight: 10),
          const SizedBox(height: 24),
          Card(
            color: Palette.card,
            child: ListTile(
              leading: const Icon(Icons.emoji_events, color: Palette.gold, size: 36),
              title: const Text('Goal reached!', style: TextStyle(color: Palette.cream)),
              subtitle: const Text('You earned a scratch card', style: TextStyle(color: Palette.muted)),
              trailing: FilledButton(onPressed: () => _claim(context), child: const Text('Claim')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claim(BuildContext context) async {
    final coins = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: Palette.ink,
        child: SizedBox(
          width: 360,
          height: 600,
          child: RewardView(onCollect: (n) => Navigator.of(ctx).pop(n)),
        ),
      ),
    );
    if (coins == null || !context.mounted) return;
    // Back in plain Flutter: a normal bottom sheet with the result.
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.card,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.savings, color: Palette.gold, size: 48),
          const SizedBox(height: 12),
          Text('${_rupees(coins)} cashback',
              style: const TextStyle(color: Palette.cream, fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('$coins coins · 5 coins = ₹1 · added to your savings', style: const TextStyle(color: Palette.muted)),
        ]),
      ),
    );
  }
}

/// GameWidget + Flutter overlays (live total, collect button).
class RewardView extends StatefulWidget {
  const RewardView({super.key, this.onCollect, this.benchCoins});
  final void Function(int coins)? onCollect;
  final int? benchCoins;

  @override
  State<RewardView> createState() => _RewardViewState();
}

class _RewardViewState extends State<RewardView> {
  late final RewardGame _game = RewardGame(benchCoins: widget.benchCoins);

  @override
  void dispose() {
    final w = _game.world.physicsWorld;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (w.isValid) w.destroy();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameWidget<RewardGame>(
      game: _game,
      initialActiveOverlays: const ['total', 'close'],
      overlayBuilderMap: {
        // Flutter widget fed by the physics world, counting up live.
        'total': (_, g) => Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ValueListenableBuilder<int>(
                  valueListenable: g.inBowl,
                  builder: (_, n, _) => Chip(
                    avatar: const Icon(Icons.savings, color: Palette.gold),
                    label: Text(_rupees(n), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
        // Always-available way out.
        'close': (_, g) => Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Palette.muted),
                onPressed: () => widget.onCollect?.call(g.inBowl.value),
              ),
            ),
        'collect': (_, g) => Align(
              alignment: const Alignment(0, -0.35),
              child: FilledButton.icon(
                onPressed: () => widget.onCollect?.call(g.inBowl.value),
                icon: const Icon(Icons.check),
                label: Text('Collect ${_rupees(g.inBowl.value)}'),
              ),
            ),
      },
    );
  }
}

// ---------------------------------------------------------------------------

/// Scratch the card and coins spill out of the scratched area, fall, bounce
/// and pile up in a bowl. Two things at once: you keep scratching while the
/// coins are still falling.
class RewardGame extends Forge2DGame {
  RewardGame({this.benchCoins}) : super(gravity: Vector2(0, 14));

  final int? benchCoins;
  int get totalCoins => benchCoins ?? 40;
  bool get bench => benchCoins != null;

  final ValueNotifier<int> inBowl = ValueNotifier(0);
  late final Rect card;
  late final Rect bowlRect;
  late final Body ground;
  final List<Coin> coins = [];
  final List<Offset> _pending = [];
  final _rng = math.Random(11);
  bool revealed = false;
  bool _done = false;
  double _quietFor = 0;
  double _sinceLastSpawn = 0;
  double _spawnAcc = 0;
  int _spawned = 0;

  @override
  Color backgroundColor() => Palette.ink;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final r = camera.visibleWorldRect;
    card = Rect.fromLTRB(r.left + 0.25, r.top + 0.3, r.right - 0.25, r.top + r.height * 0.4);
    // A deliberately small bowl: coins pour from the whole card width, so
    // some of them miss and fall away. Catching them all isn't the point.
    final bowlW = r.width * 0.5;
    bowlRect = Rect.fromLTWH(r.center.dx - bowlW / 2, r.top + r.height * 0.66, bowlW, r.height * 0.18);
    ground = world.createBody(BodyDef());
    // The bowl: the lower half of an ellipse, as static segments.
    final pts = [
      for (var i = 0; i <= 20; i++)
        Vector2(
          bowlRect.center.dx + math.cos(math.pi * i / 20) * bowlRect.width / 2,
          bowlRect.top + math.sin(math.pi * i / 20) * bowlRect.height,
        ),
    ];
    for (var i = 0; i < pts.length - 1; i++) {
      ground.createShape(Segment(point1: pts[i], point2: pts[i + 1]),
          ShapeDef(material: SurfaceMaterial(friction: 0.6, restitution: 0.1)));
    }
    world
      ..add(Bowl(pts, back: true))
      ..add(ScratchCard(card))
      ..add(Bowl(pts, back: false));
  }

  /// Called by the card for every newly scratched cell.
  void scratchedAt(Offset p) {
    if (_spawned + _pending.length < (totalCoins * 0.6).round() && _rng.nextDouble() < 0.6) {
      _pending.add(p);
    }
  }

  void onRevealed() {
    revealed = true;
    // The rest of the coins burst out of the card.
    while (_spawned + _pending.length < totalCoins) {
      _pending.add(Offset(
        card.left + _rng.nextDouble() * card.width,
        card.top + _rng.nextDouble() * card.height,
      ));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Release pending coins at a steady rate so they pour rather than pop.
    _spawnAcc += dt * (revealed ? 30 : 15);
    while (_spawnAcc >= 1 && _pending.isNotEmpty) {
      _spawnAcc -= 1;
      final p = _pending.removeAt(0);
      final c = Coin(p.toVector2(), Vector2((_rng.nextDouble() - 0.5) * 2, -1 - _rng.nextDouble()));
      coins.add(c);
      world.add(c);
      _spawned++;
      _sinceLastSpawn = 0;
    }
    _sinceLastSpawn += dt;
    if (_pending.isEmpty) _spawnAcc = 0;

    // Count what landed in the bowl (Flutter overlay listens).
    var n = 0, moving = 0;
    for (final c in coins) {
      if (!c.isLoaded) continue;
      final p = c.body.position;
      if (p.y > bowlRect.top && p.x > bowlRect.left && p.x < bowlRect.right) n++;
      if (c.body.linearVelocity.length2 > 0.01) moving++;
    }
    if (n != inBowl.value) inBowl.value = n;

    // Done once every coin is out and things have settled (or 3 s passed:
    // coins that missed the bowl fall away and are removed, and a pile can
    // keep jiggling, so don't wait for perfect stillness).
    if (!_done && revealed && _pending.isEmpty && _spawned >= totalCoins) {
      _quietFor = moving == 0 ? _quietFor + dt : 0;
      if ((_quietFor > 0.5 || _sinceLastSpawn > 3) && !bench) {
        _done = true;
        overlays.add('collect');
      }
    }
  }
}

/// Scratch-off in world units: the cover lives in its own layer and the
/// finger's path is erased with BlendMode.clear.
class ScratchCard extends PositionComponent with DragCallbacks, HasGameRef<RewardGame> {
  ScratchCard(this.rect) : super(position: rect.topLeft.toVector2(), size: rect.size.toVector2());

  final Rect rect;
  final Path _path = Path();
  static const _grid = 14;
  final Set<int> _cleared = {};
  double _fade = 1;
  double _auto = 0;

  final Paint _erase = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 0.42;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = event.localPosition.toOffset();
    _path.moveTo(p.dx, p.dy);
    _mark(p);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => _lineTo(event.localEndPosition.toOffset());

  void _lineTo(Offset p) {
    _path.lineTo(p.dx, p.dy);
    _mark(p);
  }

  void _mark(Offset p) {
    final cw = size.x / _grid, ch = size.y / _grid;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final q = p + Offset(dx * 0.14, dy * 0.14);
        if (q.dx < 0 || q.dy < 0 || q.dx >= size.x || q.dy >= size.y) continue;
        final gx = (q.dx / cw).floor(), gy = (q.dy / ch).floor();
        if (_cleared.add(gy * _grid + gx)) {
          gameRef.scratchedAt(rect.topLeft + Offset((gx + 0.5) * cw, (gy + 0.5) * ch));
        }
      }
    }
    if (!gameRef.revealed && _cleared.length > _grid * _grid * 0.6) gameRef.onRevealed();
  }

  @override
  void update(double dt) {
    if (gameRef.revealed) _fade = math.max(0, _fade - dt * 2);
    if (gameRef.bench && !gameRef.revealed) {
      // Autopilot: a zigzag "finger" over the card.
      _auto += dt;
      final x = (math.sin(_auto * 9) * 0.5 + 0.5) * size.x;
      final y = (_auto / 2.5).clamp(0.0, 1.0) * size.y;
      if (_auto < 0.02) _path.moveTo(x, y);
      _lineTo(Offset(x, y));
    }
  }

  @override
  void render(Canvas canvas) {
    final r = size.toRect();
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(0.2));
    canvas.drawRRect(rr, Paint()..color = Palette.card);
    _text(canvas, '5 coins = ₹1\ncatch them in the bowl', r.center, 15, Palette.gold);
    if (_fade <= 0) return;
    canvas.saveLayer(r, Paint()..color = Color.fromRGBO(255, 255, 255, _fade));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFBFC3C7), Color(0xFF8E9399), Color(0xFFD9DCDF)])
            .createShader(r),
    );
    _text(canvas, 'Scratch here', r.center, 22, const Color(0xFF3A3F45));
    canvas.drawPath(_path, _erase);
    canvas.restore();
  }

  void _text(Canvas canvas, String s, Offset center, double px, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: px, fontWeight: FontWeight.w700)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    final m2p = gameRef.metersToPixels;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1 / m2p);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
}

class Coin extends BodyComponent<RewardGame> {
  Coin(this._start, this._v) : super(renderBody: false, priority: 1);
  final Vector2 _start, _v;
  static const r = 0.12;
  static final _face = Paint()..color = Palette.gold;
  static final _rim = Paint()
    ..color = const Color(0xFFB8860B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.025;
  static final TextPainter _rupee = TextPainter(
    text: const TextSpan(
      text: '₹',
      style: TextStyle(color: Color(0xFF8A5A00), fontSize: 16, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  Body createBody() {
    final b = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: _start,
      linearVelocity: _v,
      angularVelocity: (_v.x) * 4,
    ));
    b.createShape(Circle(radius: r), ShapeDef(material: SurfaceMaterial(restitution: 0.35, friction: 0.5)));
    return b;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (body.position.y > 20) {
      gameRef.coins.remove(this);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas
      ..drawCircle(Offset.zero, r, _face)
      ..drawCircle(Offset.zero, r * 0.78, _rim)
      ..save()
      ..scale(1 / gameRef.metersToPixels);
    _rupee.paint(canvas, Offset(-_rupee.width / 2, -_rupee.height / 2));
    canvas.restore();
  }
}

/// The bowl is drawn in two halves so coins sit inside it.
class Bowl extends Component {
  Bowl(this.pts, {required this.back}) : super(priority: back ? -1 : 2);
  final List<Vector2> pts;
  final bool back;

  @override
  void render(Canvas canvas) {
    final path = Path()..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    if (back) {
      canvas.drawPath(path..close(), Paint()..color = const Color(0xFF2B201B));
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = Palette.flame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}
