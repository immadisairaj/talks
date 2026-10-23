import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// A simulated home, as a robot vacuum's app would receive it after mapping:
/// rooms, walls, furniture and a dock. 1 world unit = 2.5 cm (400 × 600 = 10 m × 15 m).
/// The plan is sketched landscape below and transposed to portrait for phones.
///
/// Everything here is plain Dart data plus a few grid algorithms
/// (A* path planning, line of sight, lawnmower coverage). No Flame, no widgets.
class Room {
  const Room(this.name, this.rect, this.tint);
  final String name;
  final Rect rect;
  final Color tint;
}

class Furniture {
  const Furniture(this.label, this.rect);
  final String label;
  final Rect rect;
}

class HomeMap {
  HomeMap() {
    _buildWalls();
    _rasterize();
  }

  static const width = 400.0;
  static const height = 600.0;
  static const cell = 5.0;
  static const cols = 80; // width / cell
  static const rows = 120; // height / cell
  static const robotRadius = 12.0;
  static const metersPerUnit = 0.025;
  static const wallThickness = 6.0;

  static Rect _tr(Rect r) => Rect.fromLTRB(r.top, r.left, r.bottom, r.right);

  final List<Room> rooms = [
    for (final r in _roomsSketch) Room(r.name, _tr(r.rect), r.tint),
  ];

  final List<Furniture> furniture = [
    for (final f in _furnitureSketch) Furniture(f.label, _tr(f.rect)),
  ];

  static const _roomsSketch = [
    Room('Living room', Rect.fromLTRB(0, 0, 340, 240), Color(0xFF1B1D27)),
    Room('Kitchen', Rect.fromLTRB(340, 0, 600, 180), Color(0xFF1A2124)),
    Room('Bedroom', Rect.fromLTRB(340, 180, 600, 400), Color(0xFF211C26)),
    Room('Study', Rect.fromLTRB(0, 240, 180, 400), Color(0xFF1F1F1A)),
    Room('Hallway', Rect.fromLTRB(180, 240, 340, 400), Color(0xFF1A1A20)),
  ];

  static const _furnitureSketch = [
    Furniture('Sofa', Rect.fromLTRB(40, 172, 190, 206)),
    Furniture('Table', Rect.fromLTRB(85, 95, 160, 135)),
    Furniture('TV', Rect.fromLTRB(110, 6, 230, 20)),
    Furniture('Counter', Rect.fromLTRB(352, 6, 594, 30)),
    Furniture('Island', Rect.fromLTRB(420, 80, 530, 118)),
    Furniture('Bed', Rect.fromLTRB(455, 245, 594, 375)),
    Furniture('Wardrobe', Rect.fromLTRB(380, 372, 450, 394)),
    Furniture('Desk', Rect.fromLTRB(6, 335, 110, 394)),
    Furniture('Shoe rack', Rect.fromLTRB(186, 376, 250, 394)),
  ];

  /// Where the robot charges, against the hallway wall.
  final dock = const Offset(382, 300);

  /// The way the robot faces when docked (radians, 0 = +x).
  static const dockHeading = math.pi;

  final walls = <Rect>[];

  /// Cells covered by walls or furniture (what the lidar sees).
  final solid = Uint8List(cols * rows);

  /// Cells inside a user-drawn no-go zone.
  final noGo = Uint8List(cols * rows);

  /// Cells the robot's centre cannot enter (solid grown by the robot radius).
  final blocked = Uint8List(cols * rows);

  /// Which room each cell belongs to (-1 = none).
  final roomOf = Int8List(cols * rows);

  final zones = <Rect>[];

  // -- building ------------------------------------------------------------

  void _buildWalls() {
    const t = wallThickness / 2;
    // A wall from a to b along one axis, with door gaps (start, end) on that axis.
    void hWall(double y, double x0, double x1, [List<(double, double)> doors = const []]) {
      var x = x0;
      for (final (d0, d1) in doors) {
        walls.add(Rect.fromLTRB(x, y - t, d0, y + t));
        x = d1;
      }
      walls.add(Rect.fromLTRB(x, y - t, x1, y + t));
    }

    void vWall(double x, double y0, double y1, [List<(double, double)> doors = const []]) {
      var y = y0;
      for (final (d0, d1) in doors) {
        walls.add(Rect.fromLTRB(x - t, y, x + t, d0));
        y = d1;
      }
      walls.add(Rect.fromLTRB(x - t, y, x + t, y1));
    }

    // Outer shell.
    hWall(t, 0, 600);
    hWall(400 - t, 0, 600);
    vWall(t, 0, 400);
    vWall(600 - t, 0, 400);
    // Interior, with doorways.
    vWall(340, 0, 400, [(80, 140), (285, 345)]); // living↔kitchen, hallway↔bedroom
    hWall(180, 340, 600, [(430, 490)]); // kitchen↔bedroom
    hWall(240, 0, 340, [(60, 120), (215, 305)]); // living↔study, living↔hallway
    vWall(180, 240, 400, [(290, 350)]); // study↔hallway
    for (var i = 0; i < walls.length; i++) {
      walls[i] = _tr(walls[i]);
    }
  }

  void _rasterize() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = centerOf(c, r);
        final i = r * cols + c;
        roomOf[i] = -1;
        for (var k = 0; k < rooms.length; k++) {
          if (rooms[k].rect.contains(p)) roomOf[i] = k;
        }
        final cellRect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final hit = walls.any((w) => w.overlaps(cellRect)) || furniture.any((f) => f.rect.overlaps(cellRect));
        solid[i] = hit ? 1 : 0;
      }
    }
    _inflate();
  }

  /// Grows obstacles by the robot radius so the planner can treat the robot as a point.
  void _inflate() {
    blocked.fillRange(0, blocked.length, 0);
    const reach = (robotRadius + 2) / cell;
    final rr = reach.ceil();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        if (solid[i] == 0 && noGo[i] == 0) continue;
        // A no-go zone blocks only its own area: the robot may touch its edge.
        final grow = solid[i] == 1 ? rr : 0;
        for (var dr = -grow; dr <= grow; dr++) {
          for (var dc = -grow; dc <= grow; dc++) {
            if (dr * dr + dc * dc > reach * reach) continue;
            final cc = c + dc, rr2 = r + dr;
            if (cc < 0 || rr2 < 0 || cc >= cols || rr2 >= rows) continue;
            blocked[rr2 * cols + cc] = 1;
          }
        }
      }
    }
  }

  void addZone(Rect z) {
    zones.add(z);
    _markZones();
  }

  void clearZones() {
    zones.clear();
    _markZones();
  }

  void _markZones() {
    noGo.fillRange(0, noGo.length, 0);
    for (final z in zones) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (z.contains(centerOf(c, r))) noGo[r * cols + c] = 1;
        }
      }
    }
    _inflate();
  }

  // -- queries -------------------------------------------------------------

  static Offset centerOf(int c, int r) => Offset((c + 0.5) * cell, (r + 0.5) * cell);
  static int colOf(double x) => (x / cell).floor().clamp(0, cols - 1);
  static int rowOf(double y) => (y / cell).floor().clamp(0, rows - 1);
  static int indexOf(Offset p) => rowOf(p.dy) * cols + colOf(p.dx);

  bool isFree(Offset p) =>
      p.dx >= 0 && p.dy >= 0 && p.dx < width && p.dy < height && blocked[indexOf(p)] == 0;

  bool isSolid(Offset p) =>
      p.dx < 0 || p.dy < 0 || p.dx >= width || p.dy >= height || solid[indexOf(p)] == 1;

  int? roomAt(Offset p) {
    for (var k = 0; k < rooms.length; k++) {
      if (rooms[k].rect.contains(p)) return k;
    }
    return null;
  }

  /// Floor cells per room the robot's brush can actually reach (for the % cleaned):
  /// every cell within one brush radius of a spot the robot can stand on.
  late final List<int> cleanableCells = () {
    final reach = Uint8List(cols * rows);
    const rad = 2; // cells ≈ brush radius
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (blocked[r * cols + c] == 1) continue;
        for (var dr = -rad; dr <= rad; dr++) {
          for (var dc = -rad; dc <= rad; dc++) {
            final cc = c + dc, rr = r + dr;
            if (cc < 0 || rr < 0 || cc >= cols || rr >= rows) continue;
            if (solid[rr * cols + cc] == 0) reach[rr * cols + cc] = 1;
          }
        }
      }
    }
    final out = List<int>.filled(rooms.length, 0);
    for (var i = 0; i < roomOf.length; i++) {
      if (roomOf[i] >= 0 && reach[i] == 1) out[roomOf[i]]++;
    }
    return out;
  }();

  bool lineOfSight(Offset a, Offset b) {
    final d = (b - a).distance;
    final steps = math.max(1, (d / (cell * 0.5)).ceil());
    for (var s = 0; s <= steps; s++) {
      if (!isFree(Offset.lerp(a, b, s / steps)!)) return false;
    }
    return true;
  }

  /// 8-way A* on the inflated grid, then string-pulled into a few straight legs.
  List<Offset>? plan(Offset from, Offset to) {
    if (lineOfSight(from, to)) return [to];
    final start = _nearestFree(indexOf(from));
    final goal = _nearestFree(indexOf(to));
    if (start == null || goal == null) return null;

    final n = cols * rows;
    final g = Float64List(n)..fillRange(0, n, double.infinity);
    final parent = Int32List(n)..fillRange(0, n, -1);
    final closed = Uint8List(n);
    final open = _MinHeap();
    final gc = goal % cols, gr = goal ~/ cols;
    double h(int i) {
      final dx = (i % cols - gc).abs(), dy = (i ~/ cols - gr).abs();
      return (dx + dy) + (math.sqrt2 - 2) * math.min(dx, dy);
    }

    g[start] = 0;
    open.push(start, h(start));
    while (open.isNotEmpty) {
      final cur = open.pop();
      if (cur == goal) break;
      if (closed[cur] == 1) continue;
      closed[cur] = 1;
      final cc = cur % cols, cr = cur ~/ cols;
      for (var dr = -1; dr <= 1; dr++) {
        for (var dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          final nc = cc + dc, nr = cr + dr;
          if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
          final ni = nr * cols + nc;
          if (blocked[ni] == 1 || closed[ni] == 1) continue;
          // No corner cutting.
          if (dr != 0 && dc != 0 && (blocked[cr * cols + nc] == 1 || blocked[nr * cols + cc] == 1)) continue;
          final cost = g[cur] + (dr != 0 && dc != 0 ? math.sqrt2 : 1);
          if (cost < g[ni]) {
            g[ni] = cost;
            parent[ni] = cur;
            open.push(ni, cost + h(ni));
          }
        }
      }
    }
    if (parent[goal] == -1 && goal != start) return null;

    final cells = <Offset>[];
    for (var i = goal; i != -1; i = parent[i]) {
      cells.add(centerOf(i % cols, i ~/ cols));
      if (i == start) break;
    }
    final raw = [from, ...cells.reversed.skip(1), to];

    // String pulling: keep only the corners the robot actually needs.
    final out = <Offset>[];
    var anchor = raw.first;
    var k = 1;
    while (k < raw.length) {
      var far = k;
      while (far + 1 < raw.length && lineOfSight(anchor, raw[far + 1])) {
        far++;
      }
      out.add(raw[far]);
      anchor = raw[far];
      k = far + 1;
    }
    return out;
  }

  int? _nearestFree(int i) {
    if (blocked[i] == 0) return i;
    final c0 = i % cols, r0 = i ~/ cols;
    for (var rad = 1; rad < 12; rad++) {
      for (var dr = -rad; dr <= rad; dr++) {
        for (var dc = -rad; dc <= rad; dc++) {
          final c = c0 + dc, r = r0 + dr;
          if (c < 0 || r < 0 || c >= cols || r >= rows) continue;
          if (blocked[r * cols + c] == 0) return r * cols + c;
        }
      }
    }
    return null;
  }

  /// Back-and-forth stripes across a room, one robot-width apart, skipping
  /// points the robot can't stand on. This is how most robot vacuums clean.
  List<Offset> lawnmower(int room) {
    final r = rooms[room].rect.deflate(robotRadius + 4);
    const stripe = robotRadius * 1.7;
    final out = <Offset>[];
    var leftToRight = true;
    for (var y = r.top; y <= r.bottom; y += stripe) {
      final row = <Offset>[];
      // Split each stripe into free runs so furniture breaks it cleanly.
      Offset? runStart;
      Offset? last;
      for (var x = r.left; x <= r.right; x += cell) {
        final p = Offset(x, y);
        if (isFree(p)) {
          runStart ??= p;
          last = p;
        } else if (runStart != null) {
          row
            ..add(runStart)
            ..add(last!);
          runStart = null;
        }
      }
      if (runStart != null) {
        row
          ..add(runStart)
          ..add(last!);
      }
      out.addAll(leftToRight ? row : row.reversed);
      leftToRight = !leftToRight;
    }
    return out;
  }
}

class _MinHeap {
  final _items = <int>[];
  final _keys = <double>[];
  bool get isNotEmpty => _items.isNotEmpty;

  void push(int item, double key) {
    _items.add(item);
    _keys.add(key);
    var i = _items.length - 1;
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_keys[p] <= _keys[i]) break;
      _swap(i, p);
      i = p;
    }
  }

  int pop() {
    final top = _items.first;
    final lastItem = _items.removeLast();
    final lastKey = _keys.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = lastItem;
      _keys[0] = lastKey;
      var i = 0;
      while (true) {
        final l = 2 * i + 1, r = l + 1;
        var m = i;
        if (l < _items.length && _keys[l] < _keys[m]) m = l;
        if (r < _items.length && _keys[r] < _keys[m]) m = r;
        if (m == i) break;
        _swap(i, m);
        i = m;
      }
    }
    return top;
  }

  void _swap(int a, int b) {
    final ti = _items[a];
    _items[a] = _items[b];
    _items[b] = ti;
    final tk = _keys[a];
    _keys[a] = _keys[b];
    _keys[b] = tk;
  }
}
