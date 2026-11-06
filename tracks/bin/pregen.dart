import 'dart:convert';
import 'dart:io';
import 'package:tracks_proto/tracks.dart';

/// The daily set: difficulty comes from grid size plus rule level.
const slots = [
  (name: 'easy', size: 8, level: 1),
  (name: 'medium', size: 8, level: 2),
  (name: 'hard', size: 12, level: 3),
];

/// Build step: pre-generate daily puzzles.
/// dart run bin/pregen.dart [--from=2026-11-01] [--days=730] [--out=build/tracks_daily.json] [--straight=0.5]
/// 8x8 puzzles are also brute-force checked for uniqueness; 12x12 is too slow
/// for that and relies on the solver's soundness (checked by bin/fuzz.dart).
void main(List<String> args) {
  final o = {for (final a in args) a.replaceFirst('--', '').split('=')[0]: a.split('=').last};
  var d = DateTime.parse('${o['from'] ?? '2026-11-01'}T00:00:00Z'); // UTC: local dates repeat across DST
  final days = int.parse(o['days'] ?? '730');
  final straight = double.parse(o['straight'] ?? '0.5');
  final out = o['out'] ?? 'build/tracks_daily.json';
  final puzzles = <String, List<String>>{};
  final seen = <String>{};
  final sw = Stopwatch()..start();
  for (var i = 0; i < days; i++, d = d.add(const Duration(days: 1))) {
    final date = d.toIso8601String().substring(0, 10);
    puzzles[date] = [
      for (final s in slots)
        () {
          final rng = Rng(fnv1a('tracks:v4:$date:${s.name}'));
          while (true) {
            final p = generate(rng, s.size, s.size, s.level, straight: straight);
            if (!seen.add(p.encode())) continue; // never repeat a puzzle
            if (s.size <= 8 && countSolutions(p) != 1) {
              throw StateError('not unique: $date ${s.name}');
            }
            return p.encode();
          }
        }()
    ];
  }
  File(out).writeAsStringSync(jsonEncode({
    'version': 4,
    'slots': [for (final s in slots) {'name': s.name, 'size': s.size, 'level': s.level}],
    'puzzles': puzzles,
  }));
  stdout.writeln('wrote $out: ${puzzles.length} days x ${slots.length} puzzles in '
      '${sw.elapsed.inSeconds}s, ${File(out).lengthSync()} bytes');
}
