import 'dart:convert';
import 'dart:io';

import 'package:rack_engine/rack_engine.dart';
import 'package:test/test.dart';

void main() {
  final days = [for (var k = 0; k < 200; k++) generateDay(Rng(fnv1a('sound-test:$k')))];

  test('a day always gets the same source', () {
    for (final d in days.take(20)) {
      expect(Source.of(d).toJson(), Source.of(d).toJson());
    }
  });

  test('sources stay in range', () {
    for (final d in days) {
      final s = Source.of(d);
      expect(Source.waves.keys, contains(s.wave));
      expect(Source.scales.keys, contains(s.scale));
      expect(s.bpm, inInclusiveRange(80, 132));
      expect(s.rhythm.length, 16);
      expect('x'.allMatches(s.rhythm).length, inInclusiveRange(9, 13));
      expect(s.root, inInclusiveRange(49.0, 262.0));
      if (s.wave == 'triangle') expect(s.octave, isNot(0));
    }
  });

  test('sources vary from day to day', () {
    final s = days.map(Source.of).toList();
    expect(s.map((x) => x.wave).toSet().length, Source.waves.length);
    expect(s.map((x) => x.scale).toSet().length, Source.scales.length);
    expect(s.map((x) => x.octave).toSet(), {0, 1, 2});
    expect(s.map((x) => x.bpm).toSet().length, greaterThan(8));
    expect(s.map((x) => x.label).toSet().length, greaterThan(100));
  });

  test('the view carries the source, and it is the same at every move', () {
    final d = days.first;
    final a = view(d, [])['sound'] as Map;
    final b = jsonDecode(viewJson(jsonEncode(d.toJson()), jsonEncode(['p0:0'])))['sound'] as Map;
    expect(jsonEncode(a['source']), jsonEncode(b['source']));
  });

  test('the generated year has varied sources', () {
    final f = File('../build/rack_daily.json');
    if (!f.existsSync()) return; // only after a pregen
    final all = (jsonDecode(f.readAsStringSync())['days'] as Map).values;
    final labels = {for (final j in all) Source.of(Day.fromJson(j as Map<String, dynamic>)).label};
    expect(labels.length, greaterThan(200));
  });
}
