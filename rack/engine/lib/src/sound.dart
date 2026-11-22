/// The patch's sound, as a recipe the page turns into Web Audio nodes.
///
/// One voice runs down the cable: OSC sets the tone, each cable slot in order
/// changes it, and modulators touching the cable add movement. The sound is
/// deliberately not tied to the score.
library;

import 'game.dart';
import 'rng.dart';
import 'scoring.dart';

/// The day's starting voice: waveform, scale, tempo, rhythm and register.
/// Seeded from the day, so everyone's OSC sounds the same that day.
class Source {
  Source._(this.wave, this.scale, this.bpm, this.rhythm, this.octave, this.root);

  /// Waveforms the page knows how to make, with their panel abbreviations.
  static const waves = {'saw': 'SAW', 'square': 'SQR', 'triangle': 'TRI', 'supersaw': '2×SAW', 'pulse': 'PULSE'};

  /// Scales as semitones above the root, with their panel abbreviations.
  static const scales = {
    'minor pentatonic': ('PENT', [0, 3, 5, 7, 10]),
    'dorian': ('DORIAN', [0, 2, 3, 5, 7, 9, 10]),
    'major': ('MAJOR', [0, 2, 4, 5, 7, 9, 11]),
    'phrygian': ('PHRYG', [0, 1, 3, 5, 7, 8, 10]),
    'whole-tone': ('WHOLE', [0, 2, 4, 6, 8, 10]),
  };

  final String wave;
  final String scale;
  final int bpm;

  /// 16 steps, 'x' a note and '.' a rest; the tune loops it.
  final String rhythm;

  /// 0 bass, 1 middle, 2 high.
  final int octave;

  /// Root frequency in Hz, register included.
  final double root;

  factory Source.of(Day day) {
    final rng = Rng(fnv1a('source|${day.route.join(',')}|${day.parts.map((p) => p.code).join()}'));
    final wave = waves.keys.elementAt(rng.nextInt(waves.length));
    // Weighted: whole-tone is the strangest, so it's the rarest.
    const scaleBag = ['minor pentatonic', 'minor pentatonic', 'minor pentatonic', 'dorian', 'dorian', 'dorian',
        'major', 'major', 'phrygian', 'phrygian', 'whole-tone'];
    final scale = scaleBag[rng.nextInt(scaleBag.length)];
    final bpm = 80 + 4 * rng.nextInt(14); // 80–132
    final hits = 9 + rng.nextInt(5); // 9–13 notes in 16 steps
    final rhythm = _euclid(hits, 16, rng.nextInt(16));
    var octave = const [0, 1, 1, 2][rng.nextInt(4)];
    // A triangle has almost no overtones, so in the bass a phone speaker barely plays it.
    if (wave == 'triangle' && octave == 0) octave = 1;
    const roots = [98.0, 110.0, 116.54, 130.81]; // G2, A2, B♭2, C3
    final root = roots[rng.nextInt(roots.length)] * const [0.5, 1.0, 2.0][octave];
    return Source._(wave, scale, bpm, rhythm, octave, root);
  }

  /// Short engraving for the OSC panel, e.g. "SAW · DORIAN · 112".
  String get label => '${waves[wave]} · ${scales[scale]!.$1} · $bpm';

  Map<String, Object> toJson() => {
        'wave': wave,
        'scale': scale,
        'steps': scales[scale]!.$2,
        'bpm': bpm,
        'rhythm': rhythm,
        'octave': octave,
        'root': root,
        'label': label,
      };
}

/// [hits] notes spread as evenly as possible over [steps], rotated by [rotate].
String _euclid(int hits, int steps, int rotate) {
  final out = [for (var k = 0; k < steps; k++) (k * hits) % steps < hits ? 'x' : '.'];
  return [for (var k = 0; k < steps; k++) out[(k + rotate) % steps]].join();
}

Map<String, Object> soundRecipe(Game g, Score s) {
  final chain = <String>[
    for (final i in g.day.cable)
      switch (g.slots[i]) {
        final x when x.isModule => x.module!.id,
        final x when x.isPart => 'blocked',
        _ => 'empty',
      },
  ];
  // Lit off-cable modules are the ones touching the cable; each type counts once.
  final mods = <String>{
    for (final i in s.lit)
      if (!g.slots[i].module!.onCable) g.slots[i].module!.id,
  }.toList()
    ..sort();
  // Melody seed: same day, same tune.
  final seed = fnv1a('${g.day.route.join(',')}|${g.day.parts.map((p) => p.code).join()}');
  return {
    'chain': chain,
    'mods': mods,
    'seed': seed,
    'complete': g.completePatch,
    'source': Source.of(g.day).toJson(),
  };
}
