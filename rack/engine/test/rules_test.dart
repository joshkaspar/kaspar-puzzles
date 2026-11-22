import 'package:rack_engine/rack_engine.dart';
import 'package:test/test.dart';

// Board picture used throughout: route along row 2 with a bend.
//   cells:  r*5+c
//   OSC at 10 (A3), cable 11 12 13 8 (B3 C3 D3 D2), OUT at 3 (D1).
final route = [10, 11, 12, 13, 8, 3];

Day day(List<String> lineup, [String parts = 'KCKCKCKCKCKCKCKC']) => Day(
      route: route,
      lineup: [for (final id in lineup) moduleById(id)],
      parts: [for (final c in parts.split('')) Part.fromCode(c)],
    );

/// A game with modules set straight onto the board: {cell: module id}.
Game rack(Map<int, String> modules, {List<String>? lineup, Map<int, String> parts = const {}}) {
  final g = Game(day(lineup ?? modules.values.toSet().toList(), 'K'));
  modules.forEach((i, id) => g.slots[i] = Slot.ofModule(moduleById(id)));
  parts.forEach((i, p) => g.slots[i] = Slot.ofPart(Part.fromCode(p)));
  return g;
}

int pts(Game g, int cell) => score(g).cellPoints[cell]!;
int line(Game g, String prefix) => score(g).lines.firstWhere((l) => l.label.startsWith(prefix)).points;

void main() {
  group('placing and building', () {
    test('the bin offers three parts and placing takes the chosen one', () {
      final g = Game(day(['vcf'], 'KCHJ'));
      expect(g.offer, [Part.knob, Part.coil, Part.chip]);
      g.place(1, 0);
      expect(g.slots[0].part, Part.coil);
      expect(g.offer, [Part.knob, Part.chip, Part.jack]);
    });

    test('jacks and filled cells cannot take parts', () {
      final g = Game(day(['vcf']));
      expect(() => g.place(0, 10), throwsFormatException);
      g.place(0, 0);
      expect(() => g.place(0, 0), throwsFormatException);
    });

    test('a match is found in any rotation and building clears it', () {
      final g = Game(day(['vcf']));
      g.place(1, 7); // C at C2
      g.place(0, 12); // K at C3 (below): vertical KC, upside down
      final m = g.matches().single;
      expect(m.cells, [7, 12]);
      g.build('vcf', [12, 7], 12);
      expect(g.slots[12].module!.id, 'vcf');
      expect(g.slots[7].isEmpty, isTrue);
      expect(g.matches(), isEmpty);
    });

    test('modulators cannot be built on the cable', () {
      final g = Game(day(['lfo'], 'KJH'));
      g.place(0, 11); // K on cable
      g.place(0, 12); // J on cable
      g.place(0, 16); // H below K
      final m = g.matches().single;
      expect(m.targets, [16]);
      expect(() => g.build('lfo', m.cells, 11), throwsFormatException);
    });

    test('replaying saved moves rebuilds the same board', () {
      final g = Game(day(['vcf']));
      g.place(1, 7);
      g.place(0, 12);
      g.build('vcf', [7, 12], 12);
      final h = Game.replay(g.day, g.moves);
      expect(h.slots[12].module!.id, 'vcf');
      expect(h.queue.length, g.queue.length);
    });

    test('the game ends when nothing can be placed or built; finish is allowed then', () {
      final g = Game(day(['vcf'], 'KC'));
      g.place(0, 0);
      g.place(0, 1);
      expect(g.over, isFalse); // a VCF can still be built
      expect(g.canFinish, isTrue);
      g.finish();
      expect(g.over, isTrue);
    });
  });

  group('cable', () {
    test('a raw part on the cable blocks it; a full cable is a complete patch', () {
      final g = rack({11: 'vcf', 12: 'vcf', 13: 'vcf'}, parts: {8: 'K'});
      expect(g.blocking, 1);
      expect(g.completePatch, isFalse);
      g.slots[8] = Slot.ofModule(moduleById('vcf'));
      expect(g.completePatch, isTrue);
      expect(line(g, 'Complete'), Points.completePatch);
    });
  });

  group('cable module rules', () {
    test('VCF scores flat when patched and 0 off the cable', () {
      final g = rack({11: 'vcf', 0: 'vcf'});
      expect(pts(g, 11), Points.vcf);
      expect(pts(g, 0), 0);
    });

    test('Overdrive scores more nearer OUT', () {
      expect(pts(rack({11: 'drive'}), 11), Points.driveBase + 1);
      expect(pts(rack({8: 'drive'}), 8), Points.driveBase + 4);
    });

    test('Phaser bonus only with no cable-module neighbours', () {
      expect(pts(rack({12: 'phaser'}), 12), Points.phaserBase + Points.phaserAlone);
      expect(pts(rack({12: 'phaser', 13: 'vcf'}), 12), Points.phaserBase);
      expect(pts(rack({11: 'phaser'}), 11), Points.phaserBase + Points.phaserAlone); // OSC isn't a shaper
    });

    test('Reverb bonus only in the last slot', () {
      expect(pts(rack({8: 'reverb'}), 8), Points.reverbBase + Points.reverbLast);
      expect(pts(rack({13: 'reverb'}), 13), Points.reverbBase);
    });

    test('Bitcrusher loses a point per other cable module', () {
      expect(pts(rack({11: 'crush'}), 11), Points.crushBase);
      expect(pts(rack({11: 'crush', 12: 'vcf', 13: 'vcf'}), 11), Points.crushBase - 2);
    });

    test('Wavefolder counts different types earlier on the cable', () {
      expect(pts(rack({11: 'vcf', 12: 'vcf', 13: 'fold'}), 13), Points.foldBase + Points.foldPerType);
      expect(pts(rack({11: 'vcf', 12: 'drive', 13: 'fold'}), 13), Points.foldBase + 2 * Points.foldPerType);
      expect(pts(rack({11: 'fold', 12: 'vcf'}), 11), Points.foldBase);
    });

    test('Comb Filter counts other modules in its row', () {
      expect(pts(rack({12: 'comb', 11: 'vcf', 14: 'lfo'}), 12), Points.combBase + 2 * Points.combPerModule);
    });

    test('VCA scores only touching both an Envelope and an LFO', () {
      expect(pts(rack({12: 'vca', 7: 'lfo'}), 12), 0);
      expect(pts(rack({12: 'vca', 7: 'lfo', 18: 'env'}), 12), Points.vcaBoth);
    });

    test('Delay repeats the module before it, never another Delay', () {
      expect(pts(rack({11: 'reverb', 12: 'delay'}), 12), Points.reverbBase);
      expect(pts(rack({8: 'drive', 13: 'delay'}), 13), 0); // the Drive is after it
      expect(pts(rack({11: 'delay', 12: 'delay'}), 12), 0);
      expect(pts(rack({13: 'delay', 8: 'reverb'}), 13), 0);
    });

    test('variety bonus for different cable module types', () {
      expect(line(rack({11: 'vcf', 12: 'vcf'}), 'Shaper'), 0);
      expect(line(rack({11: 'vcf', 12: 'drive', 13: 'crush'}), 'Shaper'), 2 * Points.variety);
    });
  });

  group('modulators and utilities', () {
    test('LFO: orthogonal patched neighbours', () {
      final g = rack({11: 'vcf', 12: 'vcf', 6: 'lfo', 7: 'lfo'});
      expect(pts(g, 6), Points.lfoPerTarget); // above B3
      expect(line(g, 'Knobs'), 2 * Points.lfoPerTarget);
      expect(score(g).lit, containsAll([6, 7, 11, 12]));
    });

    test('Envelope: diagonal patched neighbours', () {
      final g = rack({11: 'vcf', 13: 'vcf', 17: 'env'});
      expect(pts(g, 17), 2 * Points.envPerTarget);
    });

    test('knob points per patched module are capped', () {
      // B3 (11) touched by LFOs at B2 and B4, and Envelopes at A2... diagonals A4, C4.
      final g = rack({11: 'vcf', 6: 'lfo', 16: 'lfo', 15: 'env', 17: 'env'});
      expect(line(g, 'Knobs'), Points.knobCap);
    });

    test('Random Generator counts empty neighbours', () {
      expect(pts(rack({0: 'random'}), 0), 3);
      expect(pts(rack({0: 'random', 1: 'vcf'}), 0), 2);
    });

    test('Sample & Hold scales with different module types around it', () {
      expect(pts(rack({0: 'sh', 1: 'vcf', 5: 'vcf'}), 0), 1);
      expect(pts(rack({0: 'sh', 1: 'vcf', 5: 'lfo', 6: 'drive'}), 0), 6);
    });

    test('Oscilloscope counts patched modules next to it', () {
      expect(pts(rack({16: 'scope', 11: 'vcf', 15: 'vcf'}), 16), 1);
    });

    test('Clock counts modulators anywhere', () {
      expect(pts(rack({24: 'clock', 0: 'lfo', 4: 'env', 20: 'scope'}), 24), 2);
    });

    test('Quantizer counts other modules in its column', () {
      expect(pts(rack({0: 'quant', 5: 'vcf', 20: 'lfo', 1: 'vcf'}), 0), 2);
    });
  });

  test('empty slots and leftover parts cost a point each', () {
    final g = rack({}, lineup: ['vcf'], parts: {0: 'K', 1: 'C'});
    expect(line(g, 'Empty'), -21); // 25 − 2 jacks − 2 parts
    expect(line(g, 'Leftover'), -2);
  });
}
