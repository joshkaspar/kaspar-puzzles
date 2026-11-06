// Train Tracks prototype: PRNG, puzzle model, logic solver, generator,
// brute-force solution enumerator, ASCII rendering.
//
// The track enters through port A (a border edge of a border cell) and leaves
// through port B. A piece is a bitmask of the sides it connects: N=1 E=2 S=4
// W=8.

const int N = 1, E = 2, S = 4, W = 8;
const List<int> dirs = [N, E, S, W];
int opp(int d) => d == N ? S : d == S ? N : d == E ? W : E;
int dRow(int d) => d == N ? -1 : d == S ? 1 : 0;
int dCol(int d) => d == W ? -1 : d == E ? 1 : 0;
int bits(int m) => (m & 1) + (m >> 1 & 1) + (m >> 2 & 1) + (m >> 3 & 1);
const dirLetter = {N: 'N', E: 'E', S: 'S', W: 'W'};
bool isCorner(int m) => m != 0 && m != (N | S) && m != (E | W);

const glyph = {
  N | S: '│', E | W: '─', N | E: '└', N | W: '┘', S | E: '┌', S | W: '┐', //
};

// ---------------------------------------------------------------- PRNG ----
// mulberry32, kept inside 32 bits at every step (identical on VM and web).
class Rng {
  int _s;
  Rng(int seed) : _s = seed & 0xFFFFFFFF;

  static int imul(int a, int b) {
    a &= 0xFFFFFFFF;
    b &= 0xFFFFFFFF;
    final ah = a >> 16, al = a & 0xFFFF;
    return (al * b + (((ah * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  int nextU32() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  int nextInt(int n) => nextU32() % n;
  double nextDouble() => nextU32() / 4294967296.0;
  bool nextBool() => nextU32() & 1 == 1;
  T pick<T>(List<T> l) => l[nextInt(l.length)];
  void shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

int fnv1a(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = Rng.imul(h ^ c, 0x01000193);
  }
  return h;
}

// -------------------------------------------------------------- Puzzle ----
/// A border edge: [dir] is the side of [cell] that faces outside the grid.
class Port {
  final int cell, dir;
  const Port(this.cell, this.dir);
}

class Puzzle {
  final int w, h;
  final Port a, b;
  final List<int> rows, cols;
  final Map<int, int> hints; // cell index -> piece mask
  final List<int>? solution; // piece mask per cell (generator keeps it)
  late final Geo geo = Geo(w, h);

  Puzzle(this.w, this.h, this.a, this.b, this.rows, this.cols, this.hints,
      [this.solution]);

  int get total => rows.fold(0, (x, y) => x + y);
  int get cells => w * h;

  Puzzle withHints(Map<int, int> hs) =>
      Puzzle(w, h, a, b, rows, cols, Map.of(hs), solution);

  /// Compact text form; numbers in base 36 so 12x12 still fits one char each.
  /// WxH:<A port>.<B port>:<rows>:<cols>:<hints>, port = row col dir.
  String encode() {
    String b36(int n) => n.toRadixString(36);
    String port(Port p) =>
        '${b36(p.cell ~/ w)}${b36(p.cell % w)}${dirLetter[p.dir]}';
    final hs = (hints.keys.toList()..sort())
        .map((c) => '${b36(c ~/ w)}${b36(c % w)}${hints[c]!.toRadixString(16)}')
        .join('.');
    return '${w}x$h:${port(a)}.${port(b)}:${rows.map(b36).join()}:'
        '${cols.map(b36).join()}:$hs';
  }
}

Puzzle decode(String s) {
  final f = s.split(':');
  final wh = f[0].split('x').map(int.parse).toList();
  final w = wh[0];
  int b36(String c) => int.parse(c, radix: 36);
  Port port(String t) => Port(b36(t[0]) * w + b36(t[1]),
      dirLetter.entries.firstWhere((e) => e.value == t[2]).key);
  final ports = f[1].split('.');
  return Puzzle(
    w,
    wh[1],
    port(ports[0]),
    port(ports[1]),
    f[2].split('').map(b36).toList(),
    f[3].split('').map(b36).toList(),
    {
      for (final t in f[4].split('.').where((t) => t.isNotEmpty))
        b36(t[0]) * w + b36(t[1]): int.parse(t.substring(2), radix: 16)
    },
  );
}

/// Edge geometry. Horizontal-adjacency edges (left side of each cell, plus the
/// right border) come first, then vertical-adjacency edges (top side of each
/// cell, plus the bottom border). Outside the grid is cell -1.
class Geo {
  final int w, h;
  late final int hBase = h * (w + 1);
  late final int nEdges = hBase + (h + 1) * w;
  late final List<List<int>> cellEdges; // [cell][N,E,S,W] -> edge
  late final List<List<int>> edgeCells; // [edge] -> [cellA, cellB]

  Geo(this.w, this.h) {
    cellEdges = List.generate(w * h, (i) {
      final r = i ~/ w, c = i % w;
      return [vEdge(r, c), hEdge(r, c + 1), vEdge(r + 1, c), hEdge(r, c)];
    });
    edgeCells = List.generate(nEdges, (e) {
      if (e < hBase) {
        final r = e ~/ (w + 1), c = e % (w + 1);
        return [c > 0 ? r * w + c - 1 : -1, c < w ? r * w + c : -1];
      }
      final k = e - hBase, r = k ~/ w, c = k % w;
      return [r > 0 ? (r - 1) * w + c : -1, r < h ? r * w + c : -1];
    });
  }

  int hEdge(int r, int c) => r * (w + 1) + c;
  int vEdge(int r, int c) => hBase + r * w + c;
  int edge(int cell, int d) => cellEdges[cell][dirs.indexOf(d)];
  int? neighbour(int cell, int d) {
    final r = cell ~/ w + dRow(d), c = cell % w + dCol(d);
    return r < 0 || r >= h || c < 0 || c >= w ? null : r * w + c;
  }

  List<int> borderSides(int cell) {
    final r = cell ~/ w, c = cell % w;
    return [
      if (r == 0) N,
      if (c == w - 1) E,
      if (r == h - 1) S,
      if (c == 0) W,
    ];
  }
}

// --------------------------------------------------------------- Board ----
const int U = 0, YES = 1, NO = 2; // edge states
const int CU = 0, TRACK = 1, EMPTY = 2; // cell states

class Contradiction implements Exception {}

class Board {
  final Puzzle p;
  final List<int> edges, cells;
  Board._(this.p, this.edges, this.cells);

  factory Board.start(Puzzle p) {
    final g = p.geo;
    final b = Board._(p, List.filled(g.nEdges, U), List.filled(p.cells, CU));
    for (var e = 0; e < g.nEdges; e++) {
      if (g.edgeCells[e].contains(-1)) b.edges[e] = NO;
    }
    b.edges[g.edge(p.a.cell, p.a.dir)] = YES;
    b.edges[g.edge(p.b.cell, p.b.dir)] = YES;
    p.hints.forEach((cell, mask) {
      b.setCell(cell, TRACK);
      for (final d in dirs) {
        b.setEdge(g.edge(cell, d), mask & d != 0 ? YES : NO);
      }
    });
    return b;
  }

  Board copy() => Board._(p, List.of(edges), List.of(cells));
  bool get complete => !edges.contains(U);

  /// Cells not fully worked out yet (some side still unknown).
  int get openCells {
    var n = 0;
    for (final es in p.geo.cellEdges) {
      if (es.any((e) => edges[e] == U)) n++;
    }
    return n;
  }

  bool setEdge(int e, int v) {
    if (edges[e] == v) return false;
    if (edges[e] != U) throw Contradiction();
    edges[e] = v;
    return true;
  }

  bool setCell(int i, int v) {
    if (cells[i] == v) return false;
    if (cells[i] != CU) throw Contradiction();
    cells[i] = v;
    return true;
  }

  int mask(int cell) {
    var m = 0;
    for (var k = 0; k < 4; k++) {
      if (edges[p.geo.cellEdges[cell][k]] == YES) m |= dirs[k];
    }
    return m;
  }

  List<int> masks() => List.generate(cells.length, mask);
}

/// The path as an ordered cell list, or null if [m] isn't one path from A to
/// B covering every track cell.
List<int>? tracePath(Puzzle p, List<int> m) {
  var trackCells = 0;
  for (final x in m) {
    final b = bits(x);
    if (b != 0 && b != 2) return null;
    if (b == 2) trackCells++;
  }
  final path = <int>[];
  var cell = p.a.cell, inDir = p.a.dir;
  if (m[cell] & inDir == 0) return null;
  while (true) {
    path.add(cell);
    final out = m[cell] & ~inDir;
    if (cell == p.b.cell && out == p.b.dir) break;
    final next = p.geo.neighbour(cell, out);
    if (next == null || path.length > trackCells) return null;
    cell = next;
    inDir = opp(out);
    if (m[cell] & inDir == 0) return null;
  }
  return path.length == trackCells ? path : null;
}

/// True if [m] is a valid answer to [p]. Independent of how it was found.
bool isValidAnswer(Puzzle p, List<int> m) {
  final rows = List.filled(p.h, 0), cols = List.filled(p.w, 0);
  for (var i = 0; i < m.length; i++) {
    if (m[i] != 0) {
      rows[i ~/ p.w]++;
      cols[i % p.w]++;
    }
  }
  for (var r = 0; r < p.h; r++) {
    if (rows[r] != p.rows[r]) return false;
  }
  for (var c = 0; c < p.w; c++) {
    if (cols[c] != p.cols[c]) return false;
  }
  for (final e in p.hints.entries) {
    if (m[e.key] != e.value) return false;
  }
  return tracePath(p, m) != null;
}

// -------------------------------------------------------------- Solver ----
// Rule levels:
//  1  cell / count / no-loop rules
//  2  + crossing parity, unreachable cells, dead-end pockets (bridges)
//  3  + one-step look-ahead, but only in the endgame (few open cells left)
enum Outcome { solved, stuck, contradiction }

class SolveResult {
  final Outcome outcome;
  final int level; // hardest rule level that made progress
  final Board board;
  SolveResult(this.outcome, this.level, this.board);
}

class Solver {
  final int maxLevel;

  /// Look-ahead is only allowed when at most this share of cells is open.
  final double endgame;
  int _used = 0;
  Solver(this.maxLevel, {this.endgame = 0.15});

  SolveResult solve(Puzzle p) {
    _used = 0;
    final b = Board.start(p);
    try {
      _propagate(b, maxLevel, record: true);
      if (b.complete && !isValidAnswer(p, b.masks())) throw Contradiction();
    } on Contradiction {
      return SolveResult(Outcome.contradiction, _used, b);
    }
    return SolveResult(b.complete ? Outcome.solved : Outcome.stuck, _used, b);
  }

  /// Runs rules to a fixpoint; returns the board (for tests).
  Board propagate(Board b) {
    _propagate(b, maxLevel);
    return b;
  }

  void _propagate(Board b, int level, {bool record = false}) {
    while (true) {
      var lvl = 0;
      if (_basic(b)) {
        lvl = 1;
      } else if (level >= 2 && (_parity(b) || _connectivity(b))) {
        lvl = 2;
      } else if (level >= 3 &&
          b.openCells <= endgame * b.p.cells &&
          _trial(b)) {
        lvl = 3;
      } else {
        return;
      }
      if (record && lvl > _used) _used = lvl;
    }
  }

  bool _basic(Board b) => _cellRule(b) | _lineRule(b) | _loopRule(b);

  bool _cellRule(Board b) {
    final g = b.p.geo;
    var changed = false;
    for (var i = 0; i < b.cells.length; i++) {
      var y = 0, u = 0;
      final es = g.cellEdges[i];
      for (final e in es) {
        if (b.edges[e] == YES) y++;
        if (b.edges[e] == U) u++;
      }
      if (y > 2) throw Contradiction();
      if (y > 0) changed |= b.setCell(i, TRACK);
      if (b.cells[i] == CU && y + u < 2) changed |= b.setCell(i, EMPTY);
      if (u == 0) continue;
      if (b.cells[i] == EMPTY) {
        for (final e in es) {
          if (b.edges[e] == U) changed |= b.setEdge(e, NO);
        }
      } else if (b.cells[i] == TRACK) {
        if (y + u < 2) throw Contradiction();
        final fill = y == 2 ? NO : (y + u == 2 ? YES : U);
        if (fill != U) {
          for (final e in es) {
            if (b.edges[e] == U) changed |= b.setEdge(e, fill);
          }
        }
      }
    }
    return changed;
  }

  bool _lineRule(Board b) {
    final p = b.p;
    var changed = false;
    bool line(List<int> cs, int target) {
      var t = 0, k = 0;
      for (final c in cs) {
        if (b.cells[c] == TRACK) t++;
        if (b.cells[c] == CU) k++;
      }
      if (t > target || t + k < target) throw Contradiction();
      if (k == 0) return false;
      final fill = t == target ? EMPTY : (t + k == target ? TRACK : CU);
      if (fill == CU) return false;
      var ch = false;
      for (final c in cs) {
        if (b.cells[c] == CU) ch |= b.setCell(c, fill);
      }
      return ch;
    }

    for (var r = 0; r < p.h; r++) {
      changed |= line([for (var c = 0; c < p.w; c++) r * p.w + c], p.rows[r]);
    }
    for (var c = 0; c < p.w; c++) {
      changed |= line([for (var r = 0; r < p.h; r++) r * p.w + c], p.cols[c]);
    }
    return changed;
  }

  /// Joining two cells already on the same piece of track closes a loop.
  /// The outside counts as one node joining A and B, so connecting the A-piece
  /// to the B-piece is only allowed if it uses every track cell.
  bool _loopRule(Board b) {
    final p = b.p, g = p.geo, n = p.cells;
    final parent = List.generate(n + 1, (i) => i);
    final size = List.generate(n + 1, (i) => i < n ? 1 : 0);
    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    for (var e = 0; e < g.nEdges; e++) {
      if (b.edges[e] != YES) continue;
      final a = g.edgeCells[e][0], c = g.edgeCells[e][1];
      final ra = find(a < 0 ? n : a), rc = find(c < 0 ? n : c);
      if (ra == rc) {
        if (ra != find(n) || size[ra] != p.total) throw Contradiction();
        continue;
      }
      parent[ra] = rc;
      size[rc] += size[ra];
    }
    var changed = false;
    for (var e = 0; e < g.nEdges; e++) {
      if (b.edges[e] != U) continue;
      final a = g.edgeCells[e][0], c = g.edgeCells[e][1];
      if (a < 0 || c < 0) continue;
      final ra = find(a);
      if (ra != find(c)) continue;
      if (ra == find(n) && size[ra] == p.total) continue; // the final link
      changed |= b.setEdge(e, NO);
    }
    return changed;
  }

  /// The path crosses any straight cut an odd number of times iff A's and B's
  /// cells are on opposite sides of it.
  bool _parity(Board b) {
    final p = b.p, g = p.geo;
    final ar = p.a.cell ~/ p.w, ac = p.a.cell % p.w;
    final br = p.b.cell ~/ p.w, bc = p.b.cell % p.w;
    var changed = false;
    bool cut(List<int> es, bool odd) {
      var y = 0, unknown = -1, u = 0;
      for (final e in es) {
        if (b.edges[e] == YES) y++;
        if (b.edges[e] == U) {
          u++;
          unknown = e;
        }
      }
      if (u == 0 && (y.isOdd != odd)) throw Contradiction();
      if (u != 1) return false;
      return b.setEdge(unknown, (y.isOdd != odd) ? YES : NO);
    }

    for (var c = 0; c < p.w - 1; c++) {
      changed |= cut([for (var r = 0; r < p.h; r++) g.hEdge(r, c + 1)],
          (ac <= c) != (bc <= c));
    }
    for (var r = 0; r < p.h - 1; r++) {
      changed |= cut([for (var c = 0; c < p.w; c++) g.vEdge(r + 1, c)],
          (ar <= r) != (br <= r));
    }
    return changed;
  }

  /// Over the graph of cells/edges that could still be track:
  ///  - cells A can't reach are empty;
  ///  - a bridge (sole link) to a region without B is a dead-end pocket: the
  ///    track could go in but never come back out, so the region is empty;
  ///  - a bridge with A and B on opposite sides must be track.
  bool _connectivity(Board b) {
    final p = b.p, g = p.geo, n = p.cells;
    final tin = List.filled(n, -1), low = List.filled(n, 0);
    final tout = List.filled(n, 0), parentEdge = List.filled(n, -1);
    final parent = List.filled(n, -1), order = <int>[];
    final bridges = <int>[]; // child cell of each bridge tree edge
    var timer = 0;
    final stack = <int>[], idx = <int>[];
    void push(int c) {
      tin[c] = low[c] = timer++;
      order.add(c);
      stack.add(c);
      idx.add(0);
    }

    push(p.a.cell);
    while (stack.isNotEmpty) {
      final c = stack.last, k = idx.last;
      if (k < 4) {
        idx[idx.length - 1] = k + 1;
        final e = g.cellEdges[c][k];
        if (e == parentEdge[c] || b.edges[e] == NO) continue;
        final ec = g.edgeCells[e];
        final o = ec[0] == c ? ec[1] : ec[0];
        if (o < 0 || b.cells[o] == EMPTY) continue;
        if (tin[o] == -1) {
          parentEdge[o] = e;
          parent[o] = c;
          push(o);
        } else if (tin[o] < low[c]) {
          low[c] = tin[o];
        }
      } else {
        stack.removeLast();
        idx.removeLast();
        tout[c] = timer - 1;
        final pc = parent[c];
        if (pc >= 0) {
          if (low[c] < low[pc]) low[pc] = low[c];
          if (low[c] > tin[pc]) bridges.add(c);
        }
      }
    }
    if (tin[p.b.cell] == -1) throw Contradiction();
    var changed = false;
    for (var c = 0; c < n; c++) {
      if (tin[c] == -1 && b.cells[c] != EMPTY) changed |= b.setCell(c, EMPTY);
    }
    final bt = tin[p.b.cell];
    for (final v in bridges) {
      if (tin[v] <= bt && bt <= tout[v]) {
        changed |= b.setEdge(parentEdge[v], YES);
      } else {
        changed |= b.setEdge(parentEdge[v], NO);
        for (var t = tin[v]; t <= tout[v]; t++) {
          changed |= b.setCell(order[t], EMPTY);
        }
      }
    }
    return changed;
  }

  /// One step of look-ahead: assume a value, run levels 1-2; if that breaks,
  /// the opposite value is forced.
  bool _trial(Board b) {
    bool breaks(void Function(Board) assume) {
      final t = b.copy();
      try {
        assume(t);
        _propagate(t, 2);
        if (t.complete && !isValidAnswer(t.p, t.masks())) return true;
      } on Contradiction {
        return true;
      }
      return false;
    }

    for (var i = 0; i < b.cells.length; i++) {
      if (b.cells[i] != CU) continue;
      if (breaks((t) => t.setCell(i, TRACK))) return b.setCell(i, EMPTY);
      if (breaks((t) => t.setCell(i, EMPTY))) return b.setCell(i, TRACK);
    }
    for (var e = 0; e < b.edges.length; e++) {
      if (b.edges[e] != U) continue;
      if (breaks((t) => t.setEdge(e, YES))) return b.setEdge(e, NO);
      if (breaks((t) => t.setEdge(e, NO))) return b.setEdge(e, YES);
    }
    return false;
  }
}

// ----------------------------------------------------------- Generator ----
class GenStats {
  int attempts = 0, walks = 0;
}

/// PuzzleMadness-style path: random walk from a random border port; once it
/// has covered [minLen] cells, the first time it is on the border it leaves.
/// Returns the cell list and ports, or null if the walk got stuck.
///
/// [straight]: chance of carrying straight on when that's possible (a train's
/// momentum); otherwise it turns. 1/3 is a plain random walk.
(List<int>, Port, Port)? randomWalk(Rng rng, int w, int h, int minLen,
    {double straight = 0}) {
  final g = Geo(w, h);
  final side = rng.pick(dirs);
  final along = rng.nextInt(side == N || side == S ? w : h);
  final start = switch (side) {
    N => along,
    S => (h - 1) * w + along,
    W => along * w,
    _ => along * w + w - 1,
  };
  final path = [start];
  final seen = {start};
  var cell = start, heading = opp(side);
  while (true) {
    if (path.length >= minLen) {
      final out = g.borderSides(cell);
      if (out.isNotEmpty) {
        return (path, Port(start, side), Port(cell, rng.pick(out)));
      }
    }
    final free = [
      for (final d in dirs)
        if (g.neighbour(cell, d) case final c? when !seen.contains(c)) d
    ];
    if (free.isEmpty) return null;
    final turns = free.where((d) => d != heading).toList();
    heading = free.contains(heading) &&
            (turns.isEmpty || rng.nextDouble() < straight)
        ? heading
        : rng.pick(turns);
    cell = g.neighbour(cell, heading)!;
    path.add(cell);
    seen.add(cell);
  }
}

/// Deterministic for a given [rng] state. [level] is the exact difficulty
/// wanted: the puzzle must need level-[level] rules and nothing harder.
Puzzle generate(Rng rng, int w, int h, int level,
    {GenStats? stats,
    int maxAttempts = 5000,
    double endgame = 0.15,
    double straight = 0.5}) {
  for (var i = 0; i < maxAttempts; i++) {
    stats?.attempts++;
    final p = _tryGenerate(rng, w, h, level, stats, endgame, straight);
    if (p != null) return p;
  }
  throw StateError('no puzzle after $maxAttempts attempts');
}

Puzzle? _tryGenerate(
    Rng rng, int w, int h, int level, GenStats? stats, double endgame,
    double straight) {
  // 1. Path: random walks until one reaches the coverage target.
  final minLen = (w * h * (0.40 + 0.15 * rng.nextDouble())).round();
  (List<int>, Port, Port)? walk;
  while (walk == null) {
    stats?.walks++;
    walk = randomWalk(rng, w, h, minLen, straight: straight);
  }
  final (path, a, b) = walk;

  // 2. Pieces and counts; no empty or full rows/columns (a full line is a
  // free giveaway, and published sets almost never have one).
  final g = Geo(w, h);
  int dirTo(int from, int to) =>
      dirs.firstWhere((d) => g.neighbour(from, d) == to);
  final sol = List.filled(w * h, 0);
  for (var k = 0; k < path.length; k++) {
    final prev = k == 0 ? a.dir : dirTo(path[k], path[k - 1]);
    final next = k == path.length - 1 ? b.dir : dirTo(path[k], path[k + 1]);
    sol[path[k]] = prev | next;
  }
  final rows = List.filled(h, 0), cols = List.filled(w, 0);
  for (final c in path) {
    rows[c ~/ w]++;
    cols[c % w]++;
  }
  if (rows.contains(0) || cols.contains(0)) return null;
  if (rows.contains(w) || cols.contains(h)) return null;
  final p = Puzzle(w, h, a, b, rows, cols, {}, sol);

  // 3. Add hints until the solver finishes. When stuck, try a few candidate
  // pieces and reveal the one that lets the solver work out the most.
  final solver = Solver(level, endgame: endgame);
  final hints = <int, int>{};
  while (true) {
    final res = solver.solve(p.withHints(hints));
    if (res.outcome == Outcome.solved) break;
    if (res.outcome == Outcome.contradiction) {
      throw StateError('solver contradiction on a valid puzzle: unsound rule');
    }
    final open = [
      for (final c in path)
        if (!hints.containsKey(c) && res.board.mask(c) != sol[c]) c
    ];
    rng.shuffle(open);
    int? best;
    var bestOpen = 1 << 30;
    for (final c in open.take(6)) {
      final r = solver.solve(p.withHints({...hints, c: sol[c]}));
      final left = r.outcome == Outcome.solved ? -1 : r.board.openCells;
      if (left < bestOpen) {
        bestOpen = left;
        best = c;
      }
    }
    hints[best!] = sol[best];
  }

  // 4. Drop unneeded hints: a few random orders, repeat passes until nothing
  // more can go, keep the smallest set.
  Map<int, int>? smallest;
  for (var run = 0; run < 3; run++) {
    final hs = Map.of(hints);
    var removed = true;
    while (removed) {
      removed = false;
      final order = hs.keys.toList();
      rng.shuffle(order);
      for (final c in order) {
        final v = hs.remove(c)!;
        if (solver.solve(p.withHints(hs)).outcome == Outcome.solved) {
          removed = true;
        } else {
          hs[c] = v;
        }
      }
    }
    if (smallest == null || hs.length < smallest.length) smallest = hs;
  }
  final out = p.withHints(smallest!);

  // 5. Exact difficulty: must need this level, not just allow it.
  if (solver.solve(out).level != level) return null;
  return out;
}

// --------------------------------------------------------- Brute force ----
/// All answers (up to [limit]) found by walking every path from A. Shares no
/// code with [Solver], so it independently checks the solver.
List<List<int>> allSolutions(Puzzle p, {int limit = 2}) {
  final w = p.w, h = p.h, total = p.total, g = p.geo;
  final m = List.filled(w * h, 0);
  final ru = List.filled(h, 0), cu = List.filled(w, 0);
  final br = p.b.cell ~/ w, bc = p.b.cell % w;
  final out = <List<int>>[];
  var used = 0, hintsSeen = 0;

  bool countsMatch() {
    for (var r = 0; r < h; r++) {
      if (ru[r] != p.rows[r]) return false;
    }
    for (var c = 0; c < w; c++) {
      if (cu[c] != p.cols[c]) return false;
    }
    return true;
  }

  void enter(int cell, int delta) {
    ru[cell ~/ w] += delta;
    cu[cell % w] += delta;
    used += delta;
    if (p.hints.containsKey(cell)) hintsSeen += delta;
  }

  void dfs(int cell, int inDir) {
    if (out.length >= limit) return;
    final hint = p.hints[cell];
    if (cell == p.b.cell) {
      // B's cell can't be passed through: its piece must use B's port.
      final mm = inDir | p.b.dir;
      if (bits(mm) == 2 && (hint == null || hint == mm)) {
        m[cell] = mm;
        if (hintsSeen == p.hints.length && countsMatch()) out.add(List.of(m));
        m[cell] = 0;
      }
      return;
    }
    for (final d in dirs) {
      if (d == inDir || (hint != null && hint != (inDir | d))) continue;
      final next = g.neighbour(cell, d);
      if (next == null || m[next] != 0 || next == p.a.cell) continue;
      final nr = next ~/ w, nc = next % w;
      if (ru[nr] >= p.rows[nr] || cu[nc] >= p.cols[nc]) continue;
      final nh = p.hints[next];
      if (nh != null && nh & opp(d) == 0) continue;
      if ((nr - br).abs() + (nc - bc).abs() > total - used - 1) continue;
      m[cell] = inDir | d;
      enter(next, 1);
      dfs(next, opp(d));
      enter(next, -1);
      m[cell] = 0;
    }
  }

  final ar = p.a.cell ~/ w, ac = p.a.cell % w;
  if (p.rows[ar] < 1 || p.cols[ac] < 1) return out;
  enter(p.a.cell, 1);
  dfs(p.a.cell, p.a.dir);
  return out;
}

int countSolutions(Puzzle p, {int limit = 2}) =>
    allSolutions(p, limit: limit).length;

// -------------------------------------------------------------- Render ----
String render(Puzzle p, {List<int>? masks}) {
  String mark(int cell, int d) => p.a.cell == cell && p.a.dir == d
      ? 'A'
      : p.b.cell == cell && p.b.dir == d
          ? 'B'
          : ' ';
  String edgeRow(int r, int d) =>
      '   ${[for (var c = 0; c < p.w; c++) mark(r * p.w + c, d).padRight(3)].join()}';
  final sb = StringBuffer('   ${p.cols.map((c) => '$c'.padRight(3)).join()}\n');
  sb.writeln(edgeRow(0, N));
  for (var r = 0; r < p.h; r++) {
    sb.write(' ${mark(r * p.w, W)} ');
    for (var c = 0; c < p.w; c++) {
      final i = r * p.w + c;
      final m = masks != null ? masks[i] : (p.hints[i] ?? 0);
      sb.write(glyph[m] ?? '·');
      sb.write(m & E != 0 && c < p.w - 1 ? '──' : '  ');
    }
    sb.writeln('${mark(r * p.w + p.w - 1, E)} ${p.rows[r]}');
  }
  sb.writeln(edgeRow(p.h - 1, S));
  return sb.toString();
}
