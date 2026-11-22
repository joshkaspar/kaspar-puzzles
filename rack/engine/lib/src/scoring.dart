/// Scoring the rack (HANDOFF.md, "Scoring sketch"). Every number here is a
/// placeholder to be tuned in playtests; they're all in [Points].
library;

import 'board.dart';
import 'game.dart';
import 'model.dart';

abstract final class Points {
  static const vcf = 5;
  static const driveBase = 2; // +1 per cable slot from OSC
  static const phaserBase = 4, phaserAlone = 4;
  static const reverbBase = 4, reverbLast = 5;
  static const crushBase = 8, crushPerOther = 1;
  static const foldBase = 3, foldPerType = 2;
  static const combBase = 2, combPerModule = 2;
  static const vcaBoth = 12;

  /// Per different cable-module type beyond the first.
  static const variety = 2;
  static const lfoPerTarget = 2, envPerTarget = 3;

  /// Most knob points one patched module can take from all its modulators.
  static const knobCap = 6;
  static const completePatch = 10;
  static const emptyCell = -1, leftoverPart = -1;
}

/// Sample & Hold: points for 0, 1, 2, … different module types around it.
int shPoints(int types) => types * (types + 1) ~/ 2;

class ScoreLine {
  ScoreLine(this.label, this.points);
  final String label;
  final int points;
  Map<String, Object> toJson() => {'label': label, 'points': points};
}

class Score {
  Score(this.lines, this.cellPoints, this.lit);
  final List<ScoreLine> lines;

  /// Points earned by the module in each cell (knob points go to the modulator).
  final Map<int, int> cellPoints;

  /// Module cells whose LED is lit: patched, or a modulator/utility touching
  /// the cable in the way its rule counts.
  final Set<int> lit;
  int get total => lines.fold(0, (a, l) => a + l.points);
}

Score score(Game g) {
  final slots = g.slots;
  final cable = g.day.cable;
  ModuleType? mod(int i) => slots[i].module;
  bool patched(int i) => g.isCable(i) && slots[i].isModule && mod(i)!.onCable;

  final cellPoints = <int, int>{};
  final lit = <int>{};

  // Cable modules, in signal order. Delay copies its predecessor, so it goes last.
  final ownScore = <int, int>{};
  final patchedCells = [for (final i in cable) if (patched(i)) i];
  for (var k = 0; k < cable.length; k++) {
    final i = cable[k];
    if (!patched(i)) continue;
    final prev = k == 0 ? null : mod(cable[k - 1]);
    final next = k == cable.length - 1 ? null : mod(cable[k + 1]);
    ownScore[i] = switch (mod(i)!.id) {
      'vcf' => Points.vcf,
      'drive' => Points.driveBase + k + 1,
      'phaser' => Points.phaserBase + ((prev?.onCable ?? false) || (next?.onCable ?? false) ? 0 : Points.phaserAlone),
      'reverb' => Points.reverbBase + (k == cable.length - 1 ? Points.reverbLast : 0),
      'crush' => Points.crushBase - Points.crushPerOther * (patchedCells.length - 1),
      'fold' => Points.foldBase +
          Points.foldPerType * {for (final j in cable.take(k)) if (slots[j].isModule) mod(j)!.id}.length,
      'comb' => Points.combBase +
          Points.combPerModule *
              [for (var c = 0; c < size; c++) cellAt(rowOf(i), c)].where((j) => j != i && slots[j].isModule).length,
      'vca' => _touches(g, i, 'env') && _touches(g, i, 'lfo') ? Points.vcaBoth : 0,
      _ => 0, // delay, below
    };
  }
  for (var k = 0; k < cable.length; k++) {
    final i = cable[k];
    if (!patched(i) || mod(i)!.id != 'delay') continue;
    final p = k == 0 ? null : cable[k - 1];
    ownScore[i] = p != null && patched(p) && mod(p)!.id != 'delay' ? ownScore[p]! : 0;
  }
  for (final i in patchedCells) {
    cellPoints[i] = ownScore[i]!;
    lit.add(i);
  }
  final patchedTotal = ownScore.values.fold(0, (a, b) => a + b);

  final types = {for (final i in patchedCells) mod(i)!.id}.length;
  final variety = types > 1 ? Points.variety * (types - 1) : 0;

  // Knobs: LFOs and Envelopes add points to the patched modules they touch,
  // up to knobCap per module. Each patched module fills its cap from the
  // modulators in board order.
  final received = <int, int>{};
  var knobs = 0;
  final modules = [for (var i = 0; i < cellCount; i++) if (slots[i].isModule) i];
  for (final i in modules) {
    final m = mod(i)!;
    final (List<int> reach, int each) = switch (m.id) {
      'lfo' => (orthNeighbours(i), Points.lfoPerTarget),
      'env' => (diagNeighbours(i), Points.envPerTarget),
      _ => (const <int>[], 0),
    };
    if (g.isCable(i)) continue; // modulators can't be built on the cable
    var mine = 0;
    for (final t in reach) {
      if (!patched(t)) continue;
      final room = Points.knobCap - (received[t] ?? 0);
      final add = each < room ? each : room;
      if (add <= 0) continue;
      received[t] = (received[t] ?? 0) + add;
      mine += add;
    }
    if (reach.any(g.isCable)) lit.add(i);
    if (reach.isNotEmpty) {
      cellPoints[i] = mine;
      knobs += mine;
    }
  }

  // Other modulators, utilities, and cable modules left off the cable.
  var modulators = 0, utilities = 0;
  for (final i in modules) {
    final m = mod(i)!;
    if (g.isCable(i) && m.onCable) continue;
    int? pts;
    switch (m.id) {
      case 'random':
        pts = allNeighbours(i).where((j) => slots[j].isEmpty).length;
        modulators += pts;
      case 'sh':
        pts = shPoints({for (final j in allNeighbours(i)) if (slots[j].isModule) mod(j)!.id}.length);
        modulators += pts;
      case 'scope':
        pts = orthNeighbours(i).where(patched).length;
        utilities += pts;
      case 'clock':
        pts = modules.where((j) => mod(j)!.isModulator).length;
        utilities += pts;
      case 'quant':
        pts = [for (var r = 0; r < size; r++) cellAt(r, colOf(i))].where((j) => j != i && slots[j].isModule).length;
        utilities += pts;
      case 'lfo' || 'env':
        break;
      default:
        pts = 0; // a cable module built off the cable
    }
    if (pts != null) cellPoints[i] = pts;
    if (!m.onCable && m.id != 'lfo' && m.id != 'env' && allNeighbours(i).any(g.isCable)) lit.add(i);
  }

  final empty = slots.where((s) => s.isEmpty).length;
  final parts = slots.where((s) => s.isPart).length;
  return Score([
    ScoreLine('Patched modules · ${patchedCells.length}', patchedTotal),
    ScoreLine('Shaper variety', variety),
    ScoreLine('Knobs · modulators on the cable', knobs),
    if (modulators != 0) ScoreLine('Other modulators', modulators),
    ScoreLine('Utilities', utilities),
    ScoreLine('Complete patch', g.completePatch ? Points.completePatch : 0),
    ScoreLine('Empty slots · $empty', Points.emptyCell * empty),
    ScoreLine('Leftover parts · $parts', Points.leftoverPart * parts),
  ], cellPoints, lit);
}

/// Whether a module of type [id] sits in any of the 8 cells around [i].
bool _touches(Game g, int i, String id) => allNeighbours(i).any((j) => g.slots[j].module?.id == id);
