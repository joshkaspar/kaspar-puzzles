import 'dart:convert';
import 'dart:io';
import 'package:rack_engine/rack_engine.dart';

/// Lets the greedy bot play one day; prints its score and its moves as JSON
/// (the page's saved-game format).
/// dart run bin/bot.dart [--date=2026-11-22] [--data=build/rack_daily.json]
void main(List<String> args) {
  final o = {for (final a in args) a.replaceFirst('--', '').split('=')[0]: a.split('=').last};
  final date = o['date'] ?? DateTime.now().toIso8601String().substring(0, 10);
  final data = jsonDecode(File(o['data'] ?? 'build/rack_daily.json').readAsStringSync()) as Map<String, dynamic>;
  final day = Day.fromJson((data['days'] as Map<String, dynamic>)[date] as Map<String, dynamic>);
  final g = playGreedy(day);
  final s = score(g);
  stderr.writeln('$date: score ${s.total}, cable ${g.patchedCount}/${day.cable.length}');
  for (final l in s.lines) {
    stderr.writeln('  ${l.label.padRight(36)} ${l.points}');
  }
  stdout.writeln(jsonEncode(g.moves));
}
