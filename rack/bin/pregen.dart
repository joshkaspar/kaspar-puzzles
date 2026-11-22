import 'dart:convert';
import 'dart:io';
import 'package:rack_engine/rack_engine.dart';

/// Pre-generates the daily patches.
/// dart run bin/pregen.dart [--from=2026-11-01] [--days=365] [--out=build/rack_daily.json]
///
/// Each day is seeded from its date (`rack:v1:<date>:<attempt>`), so the same
/// dates always give the same days. A day is rejected and re-rolled if the
/// greedy bot can't get within two modules of a complete patch, or if its
/// route and lineup repeat an earlier day.
const version = 1;

void main(List<String> args) {
  final o = {for (final a in args) a.replaceFirst('--', '').split('=')[0]: a.split('=').last};
  final from = o['from'] ?? '2026-11-01';
  var d = DateTime.parse('${from}T00:00:00Z'); // UTC: local dates repeat across DST
  final n = int.parse(o['days'] ?? '365');
  final out = o['out'] ?? 'build/rack_daily.json';
  final days = <String, Object>{};
  final seen = <String>{};
  final botScores = <int>[];
  var rejected = 0;
  final sw = Stopwatch()..start();
  for (var k = 0; k < n; k++, d = d.add(const Duration(days: 1))) {
    final date = d.toIso8601String().substring(0, 10);
    for (var attempt = 0;; attempt++) {
      final day = generateDay(Rng(fnv1a('rack:v$version:$date:$attempt')));
      final key = '${day.route}|${day.lineup.map((m) => m.id).toList()..sort()}';
      final g = playGreedy(day);
      if (seen.contains(key) || g.patchedCount < day.cable.length - 2) {
        rejected++;
        continue;
      }
      seen.add(key);
      botScores.add(score(g).total);
      days[date] = day.toJson();
      break;
    }
  }
  File(out)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({'version': version, 'start': from, 'days': days}));
  botScores.sort();
  stdout.writeln('wrote $out: ${days.length} days ($rejected re-rolled) in ${sw.elapsed.inSeconds}s, '
      'bot score median ${botScores[botScores.length ~/ 2]}, ${File(out).lengthSync()} bytes');
}
