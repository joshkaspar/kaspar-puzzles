import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:tracks_proto/tracks.dart';

/// Variety/quality report for one slot of a pre-generated file.
/// dart run bin/metrics.dart <file> <slot index>
void main(List<String> args) {
  final data = jsonDecode(File(args[0]).readAsStringSync());
  final slot = int.parse(args[1]);
  final dates = (data['puzzles'] as Map).keys.toList()..sort();
  final ps = <String, List<Puzzle>>{};
  final sets = <String, List<Set<int>>>{};
  late int w, h;
  final heat = <int, int>{};
  final hints = [0, 0, 0];
  final sides = <String, int>{};
  final cornerShare = <double>[], longestCornerRun = <int, int>{}, sd = <double>[];
  var n = 0, fullLines = 0;
  for (final d in dates) {
    ps[d] = [decode((data['puzzles'][d] as List)[slot] as String)];
    sets[d] = [];
    for (final (l, p) in ps[d]!.indexed) {
      w = p.w;
      h = p.h;
      final m = Solver(3).solve(p).board.masks();
      final path = tracePath(p, m)!;
      sets[d]!.add(path.toSet());
      for (final c in path) {
        heat[c] = (heat[c] ?? 0) + 1;
      }
      hints[l] += p.hints.length;
      for (final port in [p.a, p.b]) {
        sides[dirLetter[port.dir]!] = (sides[dirLetter[port.dir]!] ?? 0) + 1;
      }
      final corners = path.where((c) => isCorner(m[c])).length;
      cornerShare.add(corners / path.length);
      var run = 0, best = 0;
      for (final c in path) {
        run = isCorner(m[c]) ? run + 1 : 0;
        best = max(best, run);
      }
      longestCornerRun[best] = (longestCornerRun[best] ?? 0) + 1;
      final counts = [...p.rows, ...p.cols];
      final mean = counts.reduce((a, b) => a + b) / counts.length;
      sd.add(sqrt(counts.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / counts.length));
      if (counts.any((x) => x == w)) fullLines++;
      n++;
    }
  }
  print('${data['slots'][slot]['name']}: ${w}x$h, $n puzzles\n');
  print('% of puzzles with track in each cell:');
  for (var r = 0; r < h; r++) {
    print([for (var c = 0; c < w; c++) (100 * (heat[r * w + c] ?? 0) / n).round().toString().padLeft(4)].join());
  }
  print('\nentry/exit sides: ${sides.entries.map((e) => '${e.key} ${(100 * e.value / (2 * n)).round()}%').join(', ')}');
  cornerShare.sort();
  print('corner pieces: median ${(100 * cornerShare[n ~/ 2]).round()}%, '
      'middle 80% ${(100 * cornerShare[n ~/ 10]).round()}-${(100 * cornerShare[n * 9 ~/ 10]).round()}%');
  final runs = longestCornerRun.keys.toList()..sort();
  print('longest run of consecutive corners: ${runs.map((k) => '$k:${(100 * longestCornerRun[k]! / n).round()}%').join(' ')}');
  sd.sort();
  print('spread of counts (std dev): median ${sd[n ~/ 2].toStringAsFixed(2)}; puzzles with a full row/col: ${(100 * fullLines / n).round()}%');
  print('avg hints: ${(hints[0] / n).toStringAsFixed(1)}');

  double j(Set<int> a, Set<int> b) => a.intersection(b).length / a.union(b).length;
  final buckets = List.filled(11, 0);
  var cnt = 0;
  for (var i = 30; i < dates.length; i++) {
    for (final s in sets[dates[i]]!) {
      var best = 0.0;
      for (var k = i - 30; k < i; k++) {
        for (final t in sets[dates[k]]!) {
          best = max(best, j(s, t));
        }
      }
      buckets[min(9, (best * 10).floor())]++;
      cnt++;
    }
  }
  print('\noverlap with closest puzzle in previous 30 days:');
  for (var b = 0; b < 10; b++) {
    if (buckets[b] > 0) print('  ${b * 10}-${b * 10 + 9}%: ${(100 * buckets[b] / cnt).toStringAsFixed(1)}%');
  }
}
