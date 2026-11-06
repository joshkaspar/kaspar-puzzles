import 'package:tracks_proto/tracks.dart';

/// Soundness test: on small random puzzles (usually with many solutions),
/// enumerate every solution and check that nothing the solver deduced, at any
/// level, contradicts any of them. Look-ahead is allowed everywhere here.
void main(List<String> args) {
  final n = args.isEmpty ? 3000 : int.parse(args[0]);
  final rng = Rng(12345);
  var bad = 0, sols = 0, maxSols = 0, multi = 0;
  for (var i = 0; i < n; i++) {
    final size = 5 + rng.nextInt(3);
    (List<int>, Port, Port)? walk;
    while (walk == null) {
      walk = randomWalk(rng, size, size, (size * size * 0.3).round());
    }
    final (path, a, b) = walk;
    final g = Geo(size, size);
    final sol = List.filled(size * size, 0);
    for (var k = 0; k < path.length; k++) {
      int to(int x, int y) => dirs.firstWhere((d) => g.neighbour(x, d) == y);
      sol[path[k]] = (k == 0 ? a.dir : to(path[k], path[k - 1])) |
          (k == path.length - 1 ? b.dir : to(path[k], path[k + 1]));
    }
    final rows = List.filled(size, 0), cols = List.filled(size, 0);
    for (final c in path) {
      rows[c ~/ size]++;
      cols[c % size]++;
    }
    final hints = <int, int>{};
    for (var k = rng.nextInt(10) < 7 ? 0 : 1 + rng.nextInt(2); k > 0; k--) {
      final c = rng.pick(path);
      hints[c] = sol[c];
    }
    final p = Puzzle(size, size, a, b, rows, cols, hints);
    final all = allSolutions(p, limit: 1 << 20);
    sols += all.length;
    if (all.length > 1) multi++;
    if (all.length > maxSols) maxSols = all.length;
    for (final level in [1, 2, 3]) {
      final board = Board.start(p);
      try {
        Solver(level, endgame: 1.0).propagate(board);
      } on Contradiction {
        bad++;
        print('contradiction on a solvable puzzle (L$level): ${p.encode()}');
        continue;
      }
      for (final s in all) {
        final has = List.filled(g.nEdges, false);
        for (var c = 0; c < s.length; c++) {
          for (final d in dirs) {
            if (s[c] & d != 0) has[g.edge(c, d)] = true;
          }
        }
        var wrong = false;
        for (var e = 0; e < g.nEdges; e++) {
          if (board.edges[e] == YES && !has[e]) wrong = true;
          if (board.edges[e] == NO && has[e]) wrong = true;
        }
        for (var c = 0; c < s.length; c++) {
          if (board.cells[c] == TRACK && s[c] == 0) wrong = true;
          if (board.cells[c] == EMPTY && s[c] != 0) wrong = true;
        }
        if (wrong) {
          bad++;
          print('L$level ruled out a real solution: ${p.encode()}');
          break;
        }
      }
    }
  }
  print('$n random puzzles (5x5-7x7), ${sols} solutions checked '
      '($multi puzzles had several, max $maxSols), unsound deductions: $bad');
}
