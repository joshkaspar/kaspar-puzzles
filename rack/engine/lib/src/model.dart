/// Parts, module types and their patterns.
library;

/// The five raw parts. [code] is the one-letter code used in patterns and
/// part orders (H is chip, so C can be coil).
enum Part {
  tube('T', 'Tube'),
  knob('K', 'Knob'),
  jack('J', 'Jack'),
  coil('C', 'Coil'),
  chip('H', 'Chip');

  const Part(this.code, this.label);
  final String code;
  final String label;

  static Part fromCode(String c) =>
      values.firstWhere((p) => p.code == c, orElse: () => throw FormatException('bad part code "$c"'));
}

/// Faceplate finish, which is also the module's category.
enum Finish {
  /// On the cable: shapers, effects, dynamics.
  black,

  /// Modulators, off the cable.
  aluminum,

  /// Utilities, off the cable.
  terracotta,
}

/// One cell of a pattern: a row/column offset and the part that must be there.
typedef PatternCell = ({int r, int c, Part part});

/// A pattern in one orientation, normalised so its smallest row and column are 0.
/// Cells are sorted, so two equal shapes have equal [key]s.
class Orientation {
  Orientation(List<PatternCell> cells)
      : cells = List.unmodifiable(_normalise(cells)),
        key = _normalise(cells).map((p) => '${p.r},${p.c}${p.part.code}').join(' ');

  final List<PatternCell> cells;
  final String key;

  int get height => cells.map((p) => p.r).reduce((a, b) => a > b ? a : b) + 1;
  int get width => cells.map((p) => p.c).reduce((a, b) => a > b ? a : b) + 1;

  static List<PatternCell> _normalise(List<PatternCell> cells) {
    final mr = cells.map((p) => p.r).reduce((a, b) => a < b ? a : b);
    final mc = cells.map((p) => p.c).reduce((a, b) => a < b ? a : b);
    final out = [for (final p in cells) (r: p.r - mr, c: p.c - mc, part: p.part)];
    out.sort((a, b) => a.r != b.r ? a.r - b.r : a.c - b.c);
    return out;
  }
}

/// Parses pattern rows like `['CT', 'T.']` ('.' is no cell).
List<PatternCell> parsePattern(List<String> rows) => [
      for (var r = 0; r < rows.length; r++)
        for (var c = 0; c < rows[r].length; c++)
          if (rows[r][c] != '.') (r: r, c: c, part: Part.fromCode(rows[r][c])),
    ];

/// Every distinct rotation and mirror image of a pattern (1 to 8 of them).
List<Orientation> orientations(List<PatternCell> cells) {
  final seen = <String, Orientation>{};
  for (final flip in [false, true]) {
    var cur = [for (final p in cells) (r: p.r, c: flip ? -p.c : p.c, part: p.part)];
    for (var i = 0; i < 4; i++) {
      cur = [for (final p in cur) (r: p.c, c: -p.r, part: p.part)]; // rotate 90°
      final o = Orientation(cur);
      seen.putIfAbsent(o.key, () => o);
    }
  }
  return seen.values.toList();
}

class ModuleType {
  ModuleType(this.id, this.name, this.label, this.finish, this.rows, this.rule)
      : cells = parsePattern(rows) {
    orients = orientations(cells);
  }

  /// Short stable id used in day data and saved moves.
  final String id;
  final String name;

  /// Engraved panel label (short caps).
  final String label;
  final Finish finish;
  final List<String> rows;
  final String rule;
  final List<PatternCell> cells;
  late final List<Orientation> orients;

  bool get onCable => finish == Finish.black;
  bool get isModulator => finish == Finish.aluminum;
  bool get isUtility => finish == Finish.terracotta;
  int get size => cells.length;
}

/// The version 1 module pool (HANDOFF.md, "Module pool, version 1").
/// Point values in the rules are placeholders until playtesting.
final List<ModuleType> pool = [
  // On the cable (black).
  ModuleType('vcf', 'VCF', 'VCF', Finish.black, ['KC'], 'Flat 5 points when patched. The safe filler.'),
  ModuleType('drive', 'Overdrive', 'DRIVE', Finish.black, ['CT', 'T.'],
      'Patched: 2 points, +1 for each cable slot it sits from OSC, so it scores most right before OUT.'),
  ModuleType('phaser', 'Phaser', 'PHASER', Finish.black, ['HK', 'C.'],
      'Patched: 4 points, +4 if neither cable neighbour is another cable module.'),
  ModuleType('reverb', 'Reverb', 'REVERB', Finish.black, ['TC', 'C.'],
      'Patched: 4 points, +5 if it is the last module before OUT.'),
  ModuleType('crush', 'Bitcrusher', 'CRUSH', Finish.black, ['HJH'],
      'Patched: 8 points, −1 for every other cable module.'),
  ModuleType('fold', 'Wavefolder', 'FOLD', Finish.black, ['TK', 'CJ'],
      'Patched: 3 points, +2 for every different module type earlier on the cable.'),
  ModuleType('comb', 'Comb Filter', 'COMB', Finish.black, ['TC.', '.CJ'],
      'Patched: 2 points, +2 for every other module in its row.'),
  ModuleType('vca', 'VCA', 'VCA', Finish.black, ['J.', 'KT', 'J.'],
      'Patched: 0 points, or 12 if it touches both an Envelope and an LFO (all 8 neighbours count).'),
  ModuleType('delay', 'Delay', 'DELAY', Finish.black, ['HT.', '.HJ', '..K'],
      'Patched: scores the same as the cable module just before it (never another Delay).'),
  // Modulators (brushed aluminum).
  ModuleType('random', 'Random Generator', 'RANDOM', Finish.aluminum, ['HH'],
      '+1 for each empty neighbouring slot at the end (all 8 count).'),
  ModuleType('lfo', 'LFO', 'LFO', Finish.aluminum, ['KJ', 'H.'],
      'Knob: +2 for each patched module next to it (up, down, left, right).'),
  ModuleType('env', 'Envelope', 'ENV', Finish.aluminum, ['JK', 'K.'],
      'Knob: +3 for each patched module diagonally next to it.'),
  ModuleType('sh', 'Sample & Hold', 'S&H', Finish.aluminum, ['J.', 'HK', 'J.'],
      'Scores 1, 3, 6, 10… for 1, 2, 3, 4… different module types around it (all 8 count).'),
  // Utilities (terracotta).
  ModuleType('scope', 'Oscilloscope', 'SCOPE', Finish.terracotta, ['TJ'],
      '+1 for each patched module next to it (up, down, left, right).'),
  ModuleType('clock', 'Clock', 'CLOCK', Finish.terracotta, ['KHJ'], '+1 for every modulator anywhere in the rack.'),
  ModuleType('quant', 'Quantizer', 'QUANT', Finish.terracotta, ['H.', 'K.', 'HJ'],
      '+1 for every other module in its column.'),
];

final Map<String, ModuleType> poolById = {for (final m in pool) m.id: m};

ModuleType moduleById(String id) => poolById[id] ?? (throw FormatException('unknown module "$id"'));
