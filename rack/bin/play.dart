import 'dart:convert';
import 'dart:io';
import 'package:rack_engine/rack_engine.dart';

/// Text-mode game for fast playtesting.
/// dart run bin/play.dart [--date=2026-11-21] [--data=build/rack_daily.json] [--seed=anything]
///
/// Without data or with --seed, the day is generated on the spot.
/// Commands:  <bin 1-3> <cell>    place, e.g. "2 C3"
///            b <cell>            list builds using that cell, then pick one
///            u                   undo     f   finish     s   score     q   quit
void main(List<String> args) {
  final o = {for (final a in args) a.replaceFirst('--', '').split('=')[0]: a.split('=').last};
  final date = o['date'] ?? DateTime.now().toIso8601String().substring(0, 10);
  final dataFile = File(o['data'] ?? 'build/rack_daily.json');
  final Day day;
  if (o['seed'] == null && dataFile.existsSync()) {
    final data = jsonDecode(dataFile.readAsStringSync()) as Map<String, dynamic>;
    day = Day.fromJson((data['days'] as Map<String, dynamic>)[date] as Map<String, dynamic>);
  } else {
    day = generateDay(Rng(fnv1a(o['seed'] ?? 'play:$date')));
  }
  stdout.writeln('Lineup:');
  for (final m in day.lineup) {
    stdout.writeln('  ${m.name.padRight(17)} ${m.finish.name.padRight(10)} ${m.rows.join(' / ')}   ${m.rule}');
  }
  var g = Game(day);
  while (true) {
    stdout.writeln(render(g));
    if (g.over) {
      printScore(g);
      return;
    }
    stdout.write('> ');
    final line = stdin.readLineSync();
    if (line == null || line.trim() == 'q') return;
    final w = line.trim().split(RegExp(r'\s+'));
    try {
      switch (w[0]) {
        case 'u':
          g = Game.replay(day, g.moves.take(g.moves.length - 1));
        case 'f':
          g.finish();
        case 's':
          printScore(g);
        case 'b':
          final cell = parseCell(w[1]);
          final ms = g.matches().where((m) => m.cells.contains(cell)).toList();
          if (ms.isEmpty) {
            stdout.writeln('no build uses ${cellName(cell)}');
            break;
          }
          final options = [for (final m in ms) for (final t in m.targets) (m, t)];
          for (var k = 0; k < options.length; k++) {
            final (m, t) = options[k];
            stdout.writeln('  ${k + 1}. ${m.module.name} into ${cellName(t)} (clears ${m.cells.map(cellName).join(' ')})');
          }
          stdout.write('which? ');
          final k = int.parse(stdin.readLineSync()!.trim()) - 1;
          final (m, t) = options[k];
          g.build(m.module.id, m.cells, t);
        default:
          g.place(int.parse(w[0]) - 1, parseCell(w[1]));
      }
    } on Object catch (e) {
      stdout.writeln('?? $e');
    }
  }
}

String render(Game g) {
  final b = StringBuffer('\n     A    B    C    D    E\n');
  for (var r = 0; r < size; r++) {
    b.write(' ${r + 1} ');
    for (var c = 0; c < size; c++) {
      final i = cellAt(r, c);
      final s = g.slots[i];
      final t = switch (s.kind) {
        SlotKind.osc => 'OSC',
        SlotKind.out => 'OUT',
        SlotKind.empty => g.isCable(i) ? '~~' : '··',
        SlotKind.part => s.part!.code + (g.isCable(i) ? '!' : ''),
        SlotKind.module => s.module!.label.substring(0, s.module!.label.length.clamp(0, 4)),
      };
      b.write(t.padRight(5));
    }
    b.writeln();
  }
  final ms = g.matches();
  b.writeln('cable ${g.patchedCount}/${g.day.cable.length} built, ${g.blocking} blocking · '
      'score ${score(g).total} · ${g.queue.length} parts left');
  if (ms.isNotEmpty) b.writeln('can build: ${ms.map((m) => '${m.module.name} (${m.cells.map(cellName).join(' ')})').join(', ')}');
  b.write('bin: ${[for (var k = 0; k < g.offer.length; k++) '${k + 1}=${g.offer[k].label}'].join('  ')}');
  return b.toString();
}

void printScore(Game g) {
  final s = score(g);
  for (final l in s.lines) {
    stdout.writeln('  ${l.label.padRight(36)} ${l.points}');
  }
  stdout.writeln('  ${'TOTAL'.padRight(36)} ${s.total}');
}
