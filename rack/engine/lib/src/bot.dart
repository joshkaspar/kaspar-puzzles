/// A greedy player, for screening generated days and quick balance numbers.
/// It isn't meant to play well, only to show that a day is playable.
library;

import 'board.dart';
import 'game.dart';
import 'scoring.dart';

/// The bot's guess at a position's worth: the score if the game ended now,
/// plus a little for half-built patterns.
double evaluate(Game g) {
  var v = score(g).total.toDouble();
  for (final m in g.day.lineup) {
    final worth = m.onCable ? 5.0 : 2.5;
    for (final o in m.orients) {
      for (var r = 0; r + o.height <= size; r++) {
        for (var c = 0; c + o.width <= size; c++) {
          var have = 0, onCable = false, ok = true;
          for (final p in o.cells) {
            final i = cellAt(r + p.r, c + p.c);
            final s = g.slots[i];
            if (s.part == p.part) {
              have++;
            } else if (!s.isEmpty) {
              ok = false;
              break;
            }
            if (g.isCable(i)) onCable = true;
          }
          if (!ok || have == 0 || have == o.cells.length) continue;
          if (m.onCable && !onCable) continue; // only cable modules on the cable are worth chasing
          final f = have / o.cells.length;
          v += worth * f * f * 0.5;
        }
      }
    }
  }
  return v;
}

/// Builds while a build raises [evaluate]; returns the improved game.
Game buildGreedily(Game g) {
  var cur = g, curV = evaluate(g);
  while (true) {
    Game? best;
    var bestV = curV;
    for (final m in cur.matches()) {
      for (final t in m.targets) {
        final n = cur.copy()..build(m.module.id, m.cells, t);
        final v = evaluate(n);
        if (v > bestV) {
          best = n;
          bestV = v;
        }
      }
    }
    if (best == null) return cur;
    cur = best;
    curV = bestV;
  }
}

/// Plays a whole day and returns the finished game.
Game playGreedy(Day day) {
  var g = Game(day);
  while (!g.over) {
    if (!g.canPlace) {
      g = buildGreedily(g);
      if (!g.over) g.finish();
      break;
    }
    Game? best;
    var bestV = double.negativeInfinity;
    final offer = g.offer;
    for (var k = 0; k < offer.length; k++) {
      if (offer.indexOf(offer[k]) != k) continue; // same part twice in the bin
      for (var i = 0; i < cellCount; i++) {
        if (!g.slots[i].isEmpty) continue;
        final n = buildGreedily(g.copy()..place(k, i));
        final v = evaluate(n);
        if (v > bestV) {
          best = n;
          bestV = v;
        }
      }
    }
    g = best!;
  }
  return g;
}
