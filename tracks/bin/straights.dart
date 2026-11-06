import 'dart:convert';
import 'dart:io';
import 'package:tracks_proto/tracks.dart';

/// Longest straight run, full lines, hint mix per slot.
void main(List<String> args) {
  final data = jsonDecode(File(args[0]).readAsStringSync());
  final dates = (data['puzzles'] as Map).keys.toList()..sort();
  for (var slot = 0; slot < 3; slot++) {
    final longest = <int>[];
    var full = 0, hc = 0, hs = 0, runs5 = 0;
    for (final d in dates) {
      final p = decode((data['puzzles'][d] as List)[slot] as String);
      final m = Solver(3).solve(p).board.masks();
      final path = tracePath(p, m)!;
      var run = 0, best = 0;
      for (final c in path) {
        run = isCorner(m[c]) ? 0 : run + 1;
        if (run > best) best = run;
      }
      longest.add(best);
      if (best >= 5) runs5++;
      if (p.rows.contains(p.w) || p.cols.contains(p.h)) full++;
      for (final v in p.hints.values) { isCorner(v) ? hc++ : hs++; }
    }
    longest.sort();
    final n = longest.length;
    print('slot $slot: longest straight median ${longest[n ~/ 2]}, '
        'p90 ${longest[(n * 0.9).floor()]}, >=5: ${(100 * runs5 / n).round()}%; '
        'full line ${(100 * full / n).round()}%; hints curve ${(100 * hc / (hc + hs)).round()}%');
  }
}
