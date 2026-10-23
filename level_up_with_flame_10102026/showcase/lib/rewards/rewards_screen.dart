import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart' hide World;
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

import '../common/theme.dart';
import 'vault_coins.dart';

/// 5 coins = ₹1, so a full card (40 coins) is a modest ₹8.
String rupees(int coins) => '₹${coins ~/ 5}';

/// A plain Flutter savings screen. The reward is a Flame game in a dialog.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GOAL · NEW LAPTOP',
                  style: TextStyle(color: Pal.muted, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text('₹50,000', style: TextStyle(color: Pal.text, fontSize: 34, fontWeight: FontWeight.w800)),
              const Text('of ₹50,000 saved', style: TextStyle(color: Pal.muted, fontSize: 14)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(height: 10, decoration: const BoxDecoration(gradient: Pal.goldGradient)),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Panel(
            child: Row(children: [
              Image.asset('assets/images/coin.png', width: 48, height: 48),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Goal reached!', style: TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 2),
                  Text('You earned a scratch card', style: TextStyle(color: Pal.muted, fontSize: 13)),
                ]),
              ),
              FilledButton(onPressed: () => _claim(context), child: const Text('Claim')),
            ]),
          ),
          const SizedBox(height: 16),
          for (final (t, a) in const [('Auto-save · Every Monday', '+₹2,000'), ('Round-ups · This week', '+₹186')])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(children: [
                  Expanded(child: Text(t, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w500))),
                  Text(a, style: const TextStyle(color: Pal.green, fontWeight: FontWeight.w700)),
                ]),
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
      barrierColor: const Color(0xCC000000),
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        backgroundColor: Pal.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Pal.line)),
        child: SizedBox(width: 360, height: 620, child: RewardView(onCollect: (n) => Navigator.of(ctx).pop(n))),
      ),
    );
    if (coins == null || !context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Pal.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/images/success_tick.png', width: 72, height: 72),
          const SizedBox(height: 16),
          Text('${rupees(coins)} cashback added',
              style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('$coins coins in the vault · 5 coins = ₹1', style: const TextStyle(color: Pal.muted)),
        ]),
      ),
    );
  }
}

/// GameWidget + Flutter overlays (live total, collect, close).
class RewardView extends StatefulWidget {
  const RewardView({super.key, this.onCollect});
  final void Function(int coins)? onCollect;

  @override
  State<RewardView> createState() => _RewardViewState();
}

class _RewardViewState extends State<RewardView> {
  late final RewardGame _game = RewardGame();

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
        'total': (_, g) => Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: ValueListenableBuilder<int>(
                  valueListenable: g.inBowl,
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
                        Text('$n coins · ${rupees(n)}',
                            style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        'close': (_, g) => Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close, color: Pal.muted),
                onPressed: () => widget.onCollect?.call(g.inBowl.value),
              ),
            ),
        'collect': (_, g) => Align(
              alignment: const Alignment(0, -0.3),
              child: FilledButton(
                onPressed: () => widget.onCollect?.call(g.inBowl.value),
                child: Text('Collect ${rupees(g.inBowl.value)}'),
              ),
            ),
      },
    );
  }
}

// ---------------------------------------------------------------------------

/// Scratch the card and coins spill out of the scratched area, fall with
/// physics, bounce and pile up in a small vault. Some miss: that's the fun.
class RewardGame extends Forge2DGame {
  RewardGame() : super(gravity: Vector2(0, 14));

  static const totalCoins = 40;
  final ValueNotifier<int> inBowl = ValueNotifier(0);
  late final Rect card;
  late final Rect vault;
  late final Body ground;
  late final ui.Image coinImage;
  final List<Coin> coins = [];
  final List<Offset> _pending = [];
  final _rng = math.Random(11);
  bool revealed = false;
  bool _done = false;
  int _spawned = 0;
  double _spawnAcc = 0, _sinceLastSpawn = 0, _quietFor = 0;

  @override
  Color backgroundColor() => Pal.bg;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.loadAll(['scratch_cover.png', 'scratch_reward.png', 'coin.png', 'vault_back.png', 'vault_front.png']);
    coinImage = images.fromCache('coin.png');
    final r = camera.visibleWorldRect;
    final cardW = r.width - 0.5;
    card = Rect.fromLTWH(r.left + 0.25, r.top + 0.45, cardW, cardW / 1.5);
    final vaultW = r.width * 0.5;
    vault = Rect.fromLTWH(r.center.dx - vaultW / 2, r.top + r.height * 0.62, vaultW, vaultW * 0.6);
    ground = world.createBody(BodyDef());
    final pts = [
      for (var i = 0; i <= 24; i++)
        Vector2(
          vault.center.dx + math.cos(math.pi * i / 24) * vault.width / 2,
          vault.top + math.sin(math.pi * i / 24) * vault.height,
        ),
    ];
    for (var i = 0; i < pts.length - 1; i++) {
      ground.createShape(Segment(point1: pts[i], point2: pts[i + 1]),
          ShapeDef(material: SurfaceMaterial(friction: 0.6, restitution: 0.1)));
    }
    world
      ..add(ImageRectComponent(images.fromCache('vault_back.png'), vault, priority: -1))
      ..add(ScratchCard(card, images.fromCache('scratch_cover.png'), images.fromCache('scratch_reward.png')))
      ..add(ImageRectComponent(images.fromCache('vault_front.png'), vault, priority: 2));
  }

  void scratchedAt(Offset p) {
    if (_spawned + _pending.length < (totalCoins * 0.6).round() && _rng.nextDouble() < 0.6) _pending.add(p);
  }

  void onRevealed() {
    revealed = true;
    while (_spawned + _pending.length < totalCoins) {
      _pending.add(Offset(card.left + _rng.nextDouble() * card.width, card.top + _rng.nextDouble() * card.height));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _spawnAcc += dt * (revealed ? 30 : 15);
    while (_spawnAcc >= 1 && _pending.isNotEmpty) {
      _spawnAcc -= 1;
      final p = _pending.removeAt(0);
      final c = Coin(p.toVector2(), Vector2((_rng.nextDouble() - 0.5) * 2, -1 - _rng.nextDouble()), coinImage)
        ..onLost = null;
      c.onLost = () => coins.remove(c);
      coins.add(c);
      world.add(c);
      _spawned++;
      _sinceLastSpawn = 0;
    }
    if (_pending.isEmpty) _spawnAcc = 0;
    _sinceLastSpawn += dt;

    var n = 0, moving = 0;
    for (final c in coins) {
      if (!c.isLoaded) continue;
      final p = c.body.position;
      if (p.y > vault.top && p.x > vault.left && p.x < vault.right) n++;
      if (c.body.linearVelocity.length2 > 0.01) moving++;
    }
    if (n != inBowl.value) inBowl.value = n;

    if (!_done && revealed && _pending.isEmpty && _spawned >= totalCoins) {
      _quietFor = moving == 0 ? _quietFor + dt : 0;
      if (_quietFor > 0.5 || _sinceLastSpawn > 3) {
        _done = true;
        overlays.add('collect');
      }
    }
  }
}

/// Scratch-off: the cover image lives in its own layer and the finger's path
/// is erased from it with BlendMode.clear.
class ScratchCard extends PositionComponent with DragCallbacks, HasGameReference<RewardGame> {
  ScratchCard(this.rect, this.cover, this.reward)
      : super(position: rect.topLeft.toVector2(), size: rect.size.toVector2());

  final Rect rect;
  final ui.Image cover, reward;
  final Path _path = Path();
  static const _grid = 14;
  final Set<int> _cleared = {};
  double _fade = 1;

  final Paint _erase = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 0.42;
  static final _img = Paint()..filterQuality = FilterQuality.medium;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    final p = event.localPosition.toOffset();
    _path.moveTo(p.dx, p.dy);
    _mark(p);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    final p = event.localEndPosition.toOffset();
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
          game.scratchedAt(rect.topLeft + Offset((gx + 0.5) * cw, (gy + 0.5) * ch));
        }
      }
    }
    if (!game.revealed && _cleared.length > _grid * _grid * 0.6) game.onRevealed();
  }

  @override
  void update(double dt) {
    if (game.revealed) _fade = math.max(0, _fade - dt * 2);
  }

  @override
  void render(Canvas canvas) {
    final r = size.toRect();
    canvas.drawImageRect(reward, _src(reward), r, _img);
    if (_fade <= 0) return;
    canvas.saveLayer(r, Paint()..color = Color.fromRGBO(255, 255, 255, _fade));
    canvas.drawImageRect(cover, _src(cover), r, _img);
    canvas.drawPath(_path, _erase);
    canvas.restore();
  }

  static Rect _src(ui.Image i) => Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble());
}
