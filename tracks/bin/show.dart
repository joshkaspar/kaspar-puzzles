import 'dart:convert';
import 'dart:io';
import 'package:tracks_proto/tracks.dart';

/// dart run bin/show.dart <date> [file]  - print that day's puzzles + solutions
void main(List<String> args) {
  final file = args.length > 1 ? args[1] : 'build/tracks_daily.json';
  final data = jsonDecode(File(file).readAsStringSync());
  final levels = [for (final s in data['slots'] as List) '${s['name']} ${s['size']}x${s['size']}'];
  final day = (data['puzzles'][args[0]] as List).cast<String>();
  for (var i = 0; i < day.length; i++) {
    final p = decode(day[i]);
    final sol = Solver(3).solve(p).board.masks();
    final a = render(p).split('\n'), b = render(p, masks: sol).split('\n');
    print('${args[0]}  ${levels[i]}  (${p.hints.length} hints)');
    for (var k = 0; k < a.length; k++) {
      print('${a[k].padRight(3 * p.w + 8)}   ${b[k]}');
    }
  }
}
