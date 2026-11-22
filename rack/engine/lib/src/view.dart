/// One JSON call the web page makes after every move: the day plus the saved
/// moves in, everything the page needs to draw out. Replaying from the start
/// keeps undo and saving trivial (drop the last move, store the list).
library;

import 'dart:convert';

import 'board.dart';
import 'game.dart';
import 'model.dart';
import 'scoring.dart';
import 'sound.dart';

Map<String, Object> moduleInfo(ModuleType m) => {
      'id': m.id,
      'name': m.name,
      'label': m.label,
      'finish': m.finish.name,
      'rows': m.rows,
      'rule': m.rule,
    };

Map<String, Object?> view(Day day, List<String> moves) {
  final g = Game(day);
  String? error;
  var applied = 0;
  for (final m in moves) {
    try {
      g.apply(m); // checks everything before changing the board
      applied++;
    } on FormatException catch (e) {
      error = '${e.message} (move ${applied + 1})';
      break;
    }
  }
  final s = score(g);
  final matches = g.over ? <Match>[] : g.matches();
  return {
    'cells': [
      for (var i = 0; i < cellCount; i++)
        {
          'kind': g.slots[i].kind.name,
          if (g.slots[i].isPart) 'part': g.slots[i].part!.code,
          if (g.slots[i].isModule) 'module': g.slots[i].module!.id,
          'cable': g.isCable(i),
          if (s.lit.contains(i)) 'lit': true,
          if (s.cellPoints.containsKey(i)) 'points': s.cellPoints[i],
        },
    ],
    'route': day.route,
    'lineup': [for (final m in day.lineup) moduleInfo(m)],
    'offer': [for (final p in g.offer) p.code],
    'remaining': g.queue.length,
    'matches': [
      for (final m in matches) {'module': m.module.id, 'cells': m.cells, 'targets': m.targets},
    ],
    'canPlace': g.canPlace,
    'canFinish': g.canFinish,
    'over': g.over,
    'moves': g.moves,
    'applied': applied,
    if (error != null) 'error': error,
    'cable': {'length': day.cable.length, 'built': g.patchedCount, 'blocking': g.blocking},
    'complete': g.completePatch,
    'score': {'total': s.total, 'lines': [for (final l in s.lines) l.toJson()]},
    'sound': soundRecipe(g, s),
  };
}

/// String in, string out, for the JavaScript bridge.
String viewJson(String dayJson, String movesJson) => jsonEncode(view(
      Day.fromJson(jsonDecode(dayJson) as Map<String, dynamic>),
      [for (final m in jsonDecode(movesJson) as List) m as String],
    ));
