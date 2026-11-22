import 'dart:convert';
import 'dart:io';
import 'package:rack_engine/rack_engine.dart';

/// Searches for a high-scoring game on one day: a beam search that keeps the
/// [width] best positions (by the bot's evaluation) after every placement.
/// It isn't guaranteed to find the best possible game, only a strong one.
/// Prints the score to stderr and the moves (page save format) to stdout.
/// dart run bin/best.dart [--date=2026-11-22] [--width=150] [--data=build/rack_daily.json]
void main(List<String> args) {
  final o = {for (final a in args) a.replaceFirst('--', '').split('=')[0]: a.split('=').last};
  final date = o['date'] ?? DateTime.now().toIso8601String().substring(0, 10);
  final width = int.parse(o['width'] ?? '150');
  final data = jsonDecode(File(o['data'] ?? 'build/rack_daily.json').readAsStringSync()) as Map<String, dynamic>;
  final day = Day.fromJson((data['days'] as Map<String, dynamic>)[date] as Map<String, dynamic>);

  Game finished(Game g) {
    g = buildGreedily(g);
    if (!g.over) g.finish();
    return g;
  }

  var beam = [Game(day)];
  Game? best;
  var bestScore = -1 << 30;
  void consider(Game g) {
    final f = finished(g.copy());
    final s = score(f).total;
    if (s > bestScore) {
      bestScore = s;
      best = f;
    }
  }

  final sw = Stopwatch()..start();
  while (beam.isNotEmpty) {
    final next = <String, (Game, double)>{};
    for (final g in beam) {
      if (!g.canPlace) {
        consider(g);
        continue;
      }
      final offer = g.offer;
      for (var k = 0; k < offer.length; k++) {
        if (offer.indexOf(offer[k]) != k) continue;
        for (var i = 0; i < cellCount; i++) {
          if (!g.slots[i].isEmpty) continue;
          final n = buildGreedily(g.copy()..place(k, i));
          // Same board and same parts to come: keep one.
          final sig = '${n.slots.map((s) => s.part?.code ?? s.module?.id ?? s.kind.name[0]).join(',')}|${n.queue.length}|${n.queue.take(3).map((p) => p.code).join()}';
          final v = evaluate(n);
          if ((next[sig]?.$2 ?? double.negativeInfinity) < v) next[sig] = (n, v);
        }
      }
    }
    final ranked = next.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    beam = [for (final e in ranked.take(width)) e.$1];
  }
  final g = best!;
  final s = score(g);
  stderr.writeln('$date: best found ${s.total} (width $width, ${sw.elapsed.inSeconds}s), cable ${g.patchedCount}/${day.cable.length}');
  for (final l in s.lines) {
    stderr.writeln('  ${l.label.padRight(36)} ${l.points}');
  }
  stdout.writeln(jsonEncode(g.moves));
}
