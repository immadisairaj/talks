import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show PointMode;

import 'package:flame/components.dart' hide Matrix4;
import 'package:flame/events.dart';
import 'package:flame/game.dart' hide Matrix4;
import 'package:material_ui/material_ui.dart';

import '../common/theme.dart';
import 'home_map.dart';

enum RobotState { idle, cleaning, returning, charging }

@immutable
class RobotStatus {
  const RobotStatus({
    required this.state,
    required this.room,
    required this.battery,
    required this.areaM2,
    required this.roomDone,
    required this.minutes,
  });

  final RobotState state;
  final String? room;
  final double battery;
  final double areaM2;
  final List<double> roomDone; // 0..1 per room
  final double minutes; // simulated cleaning time
}

const _cleanedColor = Color(0xFF1E3B45);
const _scanColor = Color(0xFF6FE3FF);
const _zoneColor = Color(0xFFFF5D6C);

/// Robot vacuum companion app, as a Flame game inside a Flutter screen.
///
/// Flame owns everything that moves or reacts every frame: the robot driving
/// its plan with dt, the coverage it paints, the lidar sweep, the camera, and
/// taps/drags in map coordinates. Flutter owns the controls and the status.
class RobotGame extends FlameGame {
  RobotGame();

  final map = HomeMap();
  final status = ValueNotifier<RobotStatus>(_initialStatus);

  /// Simulation speed multiplier (a real robot drives ~0.3 m/s).
  double speed = 4;
  bool follow = false;
  bool zoneMode = false;

  late final Robot robot;
  late final Coverage coverage;
  late final InputLayer input;

  RobotState state = RobotState.idle;
  final _targets = <(Offset, int)>[]; // (point, room) ; room -1 = dock
  int _ti = 0;
  List<Offset> leg = [];
  int? currentRoom;
  double battery = 100;
  double _minutes = 0;
  double _statusClock = 0;

  static const baseSpeed = 30.0; // world units / s at 1×

  static final _initialStatus = RobotStatus(
    state: RobotState.idle,
    room: null,
    battery: 100,
    areaM2: 0,
    roomDone: List.filled(5, 0),
    minutes: 0,
  );

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.center;
    _fit(snap: true);
    world.addAll([
      FloorPlan(map),
      coverage = Coverage(map),
      ZonesLayer(),
      Walls(map),
      Sensors(),
      robot = Robot(Vector2(map.dock.dx, map.dock.dy)),
      input = InputLayer(),
    ]);
  }

  // -- commands from Flutter ----------------------------------------------

  void cleanRooms(List<int> rooms) {
    coverage.lift();
    _targets
      ..clear()
      ..addAll([
        for (final r in rooms)
          for (final p in map.lawnmower(r)) (p, r),
      ]);
    _ti = 0;
    state = RobotState.cleaning;
    _nextLeg();
  }

  void cleanAll() => cleanRooms(List.generate(map.rooms.length, (i) => i));

  void goToDock() {
    coverage.lift();
    _targets
      ..clear()
      ..add((map.dock, -1));
    _ti = 0;
    state = RobotState.returning;
    currentRoom = null;
    _nextLeg();
  }

  void pause() {
    coverage.lift();
    state = RobotState.idle;
    leg = [];
    currentRoom = null;
  }

  void addZone(Rect r) {
    map.addZone(r);
    _replan();
  }

  void clearZones() {
    map.clearZones();
    _replan();
  }

  // -- planning ------------------------------------------------------------

  void _replan() {
    if (state == RobotState.cleaning || state == RobotState.returning) _nextLeg();
  }

  void legDone() {
    _ti++;
    _nextLeg();
  }

  void _nextLeg() {
    final from = robot.position.toOffset();
    while (_ti < _targets.length) {
      final (p, room) = _targets[_ti];
      // Skip stripes that a new no-go zone now covers.
      if (room >= 0 && !map.isFree(p)) {
        _ti++;
        continue;
      }
      final path = map.plan(from, p);
      if (path == null) {
        _ti++;
        continue;
      }
      leg = path;
      currentRoom = room >= 0 ? room : null;
      return;
    }
    leg = [];
    currentRoom = null;
    if (state == RobotState.cleaning) {
      goToDock();
    } else if (state == RobotState.returning) {
      state = RobotState.charging;
    }
  }

  // -- loop -----------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    final simDt = dt * speed;
    if (state == RobotState.cleaning) _minutes += simDt / 60;
    if (state == RobotState.charging) battery = math.min(100, battery + simDt * 0.5);
    _fit();
    _statusClock += dt;
    if (_statusClock > 0.1) {
      _statusClock = 0;
      status.value = RobotStatus(
        state: state,
        room: currentRoom == null ? null : map.rooms[currentRoom!].name,
        battery: battery,
        areaM2: coverage.areaM2,
        roomDone: [
          for (var k = 0; k < map.rooms.length; k++)
            math.min(1.0, coverage.cleanedPerRoom[k] / math.max(1, map.cleanableCells[k])),
        ],
        minutes: _minutes,
      );
    }
  }

  /// Fit the whole home, or glide after the robot when following.
  void _fit({bool snap = false}) {
    if (size.x == 0) return;
    final vf = camera.viewfinder;
    final fitZoom = math.min(size.x / (HomeMap.width + 24), size.y / (HomeMap.height + 24));
    final targetZoom = follow ? fitZoom * 2.4 : fitZoom;
    final targetPos = follow && isLoaded
        ? robot.position
        : Vector2(HomeMap.width / 2, HomeMap.height / 2);
    if (snap) {
      vf
        ..zoom = targetZoom
        ..position = targetPos.clone();
      return;
    }
    const k = 0.08;
    vf.zoom += (targetZoom - vf.zoom) * k;
    vf.position += (targetPos - vf.position) * k;
  }
}

// ---------------------------------------------------------------------------

/// Rooms, walls, furniture, dust and the dock. Static, so it is recorded into
/// a Picture once and replayed every frame.
class FloorPlan extends Component {
  FloorPlan(this.map) : super(priority: 0);
  final HomeMap map;
  late final ui.Picture _picture = _record();

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (final r in map.rooms) {
      c.drawRect(r.rect, Paint()..color = r.tint);
    }
    // Dust: what the robot will clean up.
    final rnd = math.Random(7);
    final dust = <double>[];
    for (var i = 0; i < 2600; i++) {
      final p = Offset(rnd.nextDouble() * HomeMap.width, rnd.nextDouble() * HomeMap.height);
      if (!map.isSolid(p)) dust.addAll([p.dx, p.dy]);
    }
    c.drawRawPoints(
      PointMode.points,
      Float32List.fromList(dust),
      Paint()
        ..color = const Color(0x55A39A8A)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    // Dock.
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: map.dock + const Offset(12, 0), width: 8, height: 34), const Radius.circular(3)),
      Paint()..color = const Color(0xFF3A3D4A),
    );
    c.drawCircle(map.dock + const Offset(10, 0), 2.2, Paint()..color = Pal.green);
    return rec.endRecording();
  }

  static void _text(Canvas c, String s, Offset at, double size, Color color, {FontWeight w = FontWeight.w600, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Inter', fontSize: size, color: color, fontWeight: w, letterSpacing: 0.6)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  @override
  void render(Canvas canvas) => canvas.drawPicture(_picture);
}

/// Walls, furniture and room names drawn above the coverage so stripes tuck underneath.
class Walls extends Component {
  Walls(this.map) : super(priority: 3);
  final HomeMap map;
  late final ui.Picture _picture = () {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final furn = Paint()..color = const Color(0xFF2C2E3A);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF3D4050);
    for (final f in map.furniture) {
      final rr = RRect.fromRectAndRadius(f.rect, const Radius.circular(5));
      c
        ..drawRRect(rr, furn)
        ..drawRRect(rr, edge);
      if (f.rect.shortestSide > 18) {
        FloorPlan._text(c, f.label, f.rect.center, 7.5, const Color(0xFF8B8E9C), center: true);
      }
    }
    for (final r in map.rooms) {
      FloorPlan._text(c, r.name.toUpperCase(), r.rect.topLeft + const Offset(12, 12), 9, const Color(0xFF8B8E9C),
          w: FontWeight.w700);
    }
    final wall = Paint()..color = const Color(0xFFD9DBE3);
    for (final w in map.walls) {
      c.drawRect(w, wall);
    }
    return rec.endRecording();
  }();

  @override
  void render(Canvas canvas) => canvas.drawPicture(_picture);
}

/// Cleaned floor, painted as a smooth stroke along the robot's track.
///
/// The fresh part of the track is a Path; every ~60 segments it is baked into
/// an image (2.5× resolution) so the per-frame cost stays flat however long
/// the robot cleans. A coarse grid alongside counts m² and % per room.
class Coverage extends Component with HasGameReference<RobotGame> {
  Coverage(this.map) : super(priority: 1);
  final HomeMap map;

  static const _res = 2.5;
  ui.Image? _baked;
  final _pending = Path();
  int _pendingSegments = 0;
  Offset? _last;
  final _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = (HomeMap.robotRadius - 1) * 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _cleanedColor;
  final _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  final _cleaned = Uint8List(HomeMap.cols * HomeMap.rows);
  int _count = 0;
  late final cleanedPerRoom = List<int>.filled(map.rooms.length, 0);

  double get areaM2 => _count * (HomeMap.cell * HomeMap.metersPerUnit) * (HomeMap.cell * HomeMap.metersPerUnit);

  /// The brush left the floor (paused, docking, new task): next point starts a new stroke.
  void lift() => _last = null;

  void brush(Vector2 at, double radius) {
    _mark(at, radius);
    final p = at.toOffset();
    if (_last == null) {
      _pending
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx, p.dy);
    } else if ((p - _last!).distanceSquared > 0.25) {
      _pending.lineTo(p.dx, p.dy);
    } else {
      return;
    }
    _last = p;
    if (++_pendingSegments >= 60) _bake();
  }

  void _bake() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    if (_baked != null) c.drawImage(_baked!, Offset.zero, Paint());
    c
      ..scale(_res)
      ..drawPath(_pending, _stroke);
    final image = rec.endRecording().toImageSync((HomeMap.width * _res).round(), (HomeMap.height * _res).round());
    _baked?.dispose();
    _baked = image;
    _pending.reset();
    _pendingSegments = 0;
    if (_last != null) _pending.moveTo(_last!.dx, _last!.dy);
  }

  void _mark(Vector2 at, double radius) {
    final c0 = HomeMap.colOf(at.x - radius), c1 = HomeMap.colOf(at.x + radius);
    final r0 = HomeMap.rowOf(at.y - radius), r1 = HomeMap.rowOf(at.y + radius);
    final r2 = radius * radius;
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final i = r * HomeMap.cols + c;
        if (_cleaned[i] == 1 || map.solid[i] == 1) continue;
        final p = HomeMap.centerOf(c, r);
        final dx = p.dx - at.x, dy = p.dy - at.y;
        if (dx * dx + dy * dy > r2) continue;
        _cleaned[i] = 1;
        _count++;
        final room = map.roomOf[i];
        if (room >= 0) cleanedPerRoom[room]++;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final b = _baked;
    if (b != null) {
      canvas.drawImageRect(
        b,
        Rect.fromLTWH(0, 0, b.width.toDouble(), b.height.toDouble()),
        const Rect.fromLTWH(0, 0, HomeMap.width, HomeMap.height),
        _imagePaint,
      );
    }
    canvas.drawPath(_pending, _stroke);
  }

  @override
  void onRemove() {
    _baked?.dispose();
    super.onRemove();
  }
}

/// No-go zones the user drew, plus the one being drawn right now.
class ZonesLayer extends Component with HasGameReference<RobotGame> {
  ZonesLayer() : super(priority: 2);
  Rect? draft;

  final _fill = Paint()..color = _zoneColor.withValues(alpha: 0.16);
  final _hatch = Paint()
    ..color = _zoneColor.withValues(alpha: 0.35)
    ..strokeWidth = 1;
  final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = _zoneColor;

  @override
  void render(Canvas canvas) {
    for (final z in [...game.map.zones, ?draft]) {
      canvas
        ..save()
        ..clipRect(z)
        ..drawRect(z, _fill);
      for (var x = z.left - z.height; x < z.right; x += 8) {
        canvas.drawLine(Offset(x, z.bottom), Offset(x + z.height, z.top), _hatch);
      }
      canvas
        ..restore()
        ..drawRect(z, _edge);
    }
  }
}

/// Lidar sweep and the planned route: both recomputed every frame.
class Sensors extends Component with HasGameReference<RobotGame> {
  Sensors() : super(priority: 4);

  static const rays = 120;
  static const range = 150.0;
  final _hits = Float32List(rays * 2);
  int _hitCount = 0;
  final _scan = Path();
  double _sweep = 0;

  final _scanFill = Paint()..color = _scanColor.withValues(alpha: 0.07);
  final _hitPaint = Paint()
    ..color = _scanColor.withValues(alpha: 0.9)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  final _route = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xAAF4F5F7);

  @override
  void update(double dt) {
    _sweep += dt * 2 * math.pi * 0.8;
    final o = game.robot.position;
    _scan.reset();
    _hitCount = 0;
    for (var k = 0; k < rays; k++) {
      final a = k / rays * 2 * math.pi;
      final dx = math.cos(a), dy = math.sin(a);
      var d = HomeMap.robotRadius;
      var hit = false;
      while (d < range) {
        if (game.map.isSolid(Offset(o.x + dx * d, o.y + dy * d))) {
          hit = true;
          break;
        }
        d += 3;
      }
      final x = o.x + dx * d, y = o.y + dy * d;
      k == 0 ? _scan.moveTo(x, y) : _scan.lineTo(x, y);
      if (hit) {
        _hits[_hitCount * 2] = x;
        _hits[_hitCount * 2 + 1] = y;
        _hitCount++;
      }
    }
    _scan.close();
  }

  @override
  void render(Canvas canvas) {
    final o = game.robot.position.toOffset();
    canvas.drawPath(_scan, _scanFill);
    // Rotating sweep wedge.
    canvas
      ..save()
      ..clipPath(_scan)
      ..drawArc(
        Rect.fromCircle(center: o, radius: range),
        _sweep,
        0.6,
        true,
        Paint()
          ..shader = ui.Gradient.sweep(o, [const Color(0x006FE3FF), const Color(0x406FE3FF)], [0, 1], TileMode.clamp,
              _sweep, _sweep + 0.6),
      )
      ..restore();
    canvas.drawRawPoints(PointMode.points, Float32List.sublistView(_hits, 0, _hitCount * 2), _hitPaint);

    final leg = game.leg;
    if (leg.isNotEmpty) {
      final p = Path()..moveTo(o.dx, o.dy);
      for (final q in leg) {
        p.lineTo(q.dx, q.dy);
      }
      _route.color = game.state == RobotState.returning ? Pal.gold : const Color(0x88F4F5F7);
      canvas.drawPath(p, _route);
      canvas.drawCircle(leg.last, 2.5, Paint()..color = _route.color);
    }
  }
}

/// The robot: turns on the spot, then drives each leg of the plan using dt.
class Robot extends PositionComponent with HasGameReference<RobotGame> {
  Robot(Vector2 at)
      : super(
          position: at,
          size: Vector2.all(HomeMap.robotRadius * 2),
          anchor: Anchor.center,
          angle: HomeMap.dockHeading,
          priority: 5,
        );

  double _t = 0;
  static const turnRate = 5.0; // rad/s at 1×

  @override
  void update(double dt) {
    _t += dt;
    final g = game;
    if (g.state != RobotState.cleaning && g.state != RobotState.returning) return;
    if (g.leg.isEmpty) return;
    final simDt = dt * g.speed;
    var budget = RobotGame.baseSpeed * simDt;
    var turnBudget = turnRate * simDt;

    while (g.leg.isNotEmpty && budget > 0) {
      final next = g.leg.first;
      final to = Vector2(next.dx, next.dy) - position;
      final dist = to.length;
      if (dist < 0.01) {
        g.leg.removeAt(0);
        if (g.leg.isEmpty) g.legDone();
        continue;
      }
      // Turn on the spot first if the heading is off by more than ~15°.
      final want = math.atan2(to.y, to.x);
      final diff = _wrap(want - angle);
      if (diff.abs() > 0.26) {
        final turn = diff.clamp(-turnBudget, turnBudget);
        angle = _wrap(angle + turn);
        turnBudget -= turn.abs();
        if (turnBudget <= 0) break;
        continue;
      }
      angle = want;
      final step = math.min(budget, dist);
      position += to / dist * step;
      budget -= step;
      g.battery = math.max(0, g.battery - step * 0.0045);
      if (g.state == RobotState.cleaning) g.coverage.brush(position, HomeMap.robotRadius - 1);
    }
  }

  static double _wrap(double a) {
    while (a > math.pi) {
      a -= 2 * math.pi;
    }
    while (a < -math.pi) {
      a += 2 * math.pi;
    }
    return a;
  }

  @override
  void render(Canvas canvas) {
    const r = HomeMap.robotRadius;
    final c = Offset(width / 2, height / 2);
    final g = game;
    final active = g.state == RobotState.cleaning;
    if (active || g.state == RobotState.charging) {
      final pulse = (math.sin(_t * 4) + 1) / 2;
      canvas.drawCircle(
        c,
        r + 3 + pulse * 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = (active ? _scanColor : Pal.green).withValues(alpha: 0.5 - pulse * 0.35),
      );
    }
    canvas
      ..drawCircle(c + const Offset(0, 1.5), r, Paint()..color = const Color(0x66000000))
      ..drawCircle(c, r, Paint()..color = const Color(0xFFE9EBF1))
      ..drawCircle(
        c,
        r - 2.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFFB9BCC8),
      )
      // Lidar turret.
      ..drawCircle(c, 4.5, Paint()..color = const Color(0xFF2A2C36))
      ..drawCircle(c + const Offset(2, 0), 1.3, Paint()..color = _scanColor);
    // Front bumper (local +x is forward).
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 0.8),
      -1.1,
      2.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Pal.gold,
    );
    // Side brushes spin while cleaning.
    if (active) {
      for (final side in [-1.0, 1.0]) {
        final hub = c + Offset(r * 0.62, side * r * 0.62);
        for (var k = 0; k < 3; k++) {
          final a = _t * 18 * side + k * 2 * math.pi / 3;
          canvas.drawLine(hub, hub + Offset(math.cos(a), math.sin(a)) * 5.5,
              Paint()
                ..strokeWidth = 0.8
                ..color = const Color(0xFF9A9CA8));
        }
      }
    }
  }
}

/// Covers the whole map and turns taps and drags into map coordinates
/// (the camera transform is already undone for us).
class InputLayer extends PositionComponent with TapCallbacks, DragCallbacks, HasGameReference<RobotGame> {
  InputLayer() : super(size: Vector2(HomeMap.width, HomeMap.height), priority: 10);

  Vector2? _start;
  Vector2? _end;

  ZonesLayer get _zones => game.world.children.whereType<ZonesLayer>().first;

  @override
  void onTapUp(TapUpEvent event) {
    if (game.zoneMode) return;
    final room = game.map.roomAt(event.localPosition.toOffset());
    if (room != null) game.cleanRooms([room]);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!game.zoneMode) return;
    _start = event.localPosition.clone();
    _end = _start!.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_start == null) return;
    _end = _end! + event.localDelta;
    _zones.draft = Rect.fromPoints(_start!.toOffset(), _end!.toOffset());
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final z = _zones.draft;
    _zones.draft = null;
    _start = _end = null;
    if (z != null && z.width > 16 && z.height > 16) game.addZone(z);
  }
}
