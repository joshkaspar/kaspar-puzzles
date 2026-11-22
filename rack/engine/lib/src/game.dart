/// A day's setup, the game state, matching, building and the end of the game.
library;

import 'board.dart';
import 'model.dart';

/// How many upcoming parts the parts bin shows.
const int binSize = 3;

/// One day's puzzle: the cable route, the module lineup and the part order.
class Day {
  Day({required this.route, required this.lineup, required this.parts});

  /// OSC jack, the cable cells in signal order, then the OUT jack.
  final List<int> route;
  final List<ModuleType> lineup;
  final List<Part> parts;

  int get osc => route.first;
  int get out => route.last;

  /// The cable cells between the jacks, in signal order.
  List<int> get cable => route.sublist(1, route.length - 1);

  Map<String, Object> toJson() => {
        'route': route,
        'lineup': [for (final m in lineup) m.id],
        'parts': parts.map((p) => p.code).join(),
      };

  factory Day.fromJson(Map<String, dynamic> j) => Day(
        route: [for (final c in j['route'] as List) c as int],
        lineup: [for (final id in j['lineup'] as List) moduleById(id as String)],
        parts: [for (final ch in (j['parts'] as String).split('')) Part.fromCode(ch)],
      );
}

enum SlotKind { empty, part, module, osc, out }

/// What one board cell holds.
class Slot {
  const Slot._(this.kind, [this.part, this.module]);
  static const empty = Slot._(SlotKind.empty);
  static const osc = Slot._(SlotKind.osc);
  static const out = Slot._(SlotKind.out);
  Slot.ofPart(Part p) : this._(SlotKind.part, p);
  Slot.ofModule(ModuleType m) : this._(SlotKind.module, null, m);

  final SlotKind kind;
  final Part? part;
  final ModuleType? module;

  bool get isEmpty => kind == SlotKind.empty;
  bool get isPart => kind == SlotKind.part;
  bool get isModule => kind == SlotKind.module;
  bool get isJack => kind == SlotKind.osc || kind == SlotKind.out;
}

/// A lineup module's pattern found on the board.
class Match {
  Match(this.module, this.cells, this.targets);
  final ModuleType module;

  /// The pattern's cells, sorted.
  final List<int> cells;

  /// Cells the module may go into: any pattern cell for a cable module, only
  /// cells off the cable for modulators and utilities.
  final List<int> targets;

  String get key => '${module.id}:${cells.join(',')}';
}

class Game {
  Game(this.day)
      : slots = List.filled(cellCount, Slot.empty),
        queue = List.of(day.parts),
        cableSet = day.cable.toSet() {
    slots[day.osc] = Slot.osc;
    slots[day.out] = Slot.out;
  }

  /// Replays saved moves from the start. Throws [FormatException] on a bad move.
  factory Game.replay(Day day, Iterable<String> moves) {
    final g = Game(day);
    for (final m in moves) {
      g.apply(m);
    }
    return g;
  }

  /// An independent copy, for trying moves out (the bot).
  Game copy() => Game._copy(this);
  Game._copy(Game o)
      : day = o.day,
        slots = List.of(o.slots),
        queue = List.of(o.queue),
        cableSet = o.cableSet,
        _finished = o._finished {
    moves.addAll(o.moves);
  }

  final Day day;
  final List<Slot> slots;

  /// Parts still to come, the bin's offer first.
  final List<Part> queue;
  final Set<int> cableSet;
  final List<String> moves = [];
  bool _finished = false;

  List<Part> get offer => queue.take(binSize).toList();
  bool get hasEmptyCell => slots.any((s) => s.isEmpty);
  bool get canPlace => queue.isNotEmpty && hasEmptyCell;

  /// The player may end the game once nothing more can be placed, even if
  /// some builds are still possible.
  bool get canFinish => !_finished && !canPlace;
  bool get over => _finished || (!canPlace && matches().isEmpty);

  bool isCable(int i) => cableSet.contains(i);

  /// Every buildable lineup pattern on the board, each found once.
  List<Match> matches() {
    final found = <String, Match>{};
    for (final m in day.lineup) {
      for (final o in m.orients) {
        for (var r = 0; r + o.height <= size; r++) {
          for (var c = 0; c + o.width <= size; c++) {
            if (!o.cells.every((p) => slots[cellAt(r + p.r, c + p.c)].part == p.part)) continue;
            final cells = [for (final p in o.cells) cellAt(r + p.r, c + p.c)]..sort();
            final targets = [for (final i in cells) if (m.onCable || !isCable(i)) i];
            if (targets.isEmpty) continue;
            final match = Match(m, cells, targets);
            found.putIfAbsent(match.key, () => match);
          }
        }
      }
    }
    return found.values.toList();
  }

  /// Places the bin's [offerIndex]th part in empty [cell].
  void place(int offerIndex, int cell) {
    if (over) throw const FormatException('the game is over');
    if (offerIndex < 0 || offerIndex >= offer.length) throw FormatException('no part $offerIndex in the bin');
    if (cell < 0 || cell >= cellCount || !slots[cell].isEmpty) throw FormatException('cell $cell is not empty');
    slots[cell] = Slot.ofPart(queue.removeAt(offerIndex));
    moves.add('p$offerIndex:$cell');
  }

  /// Builds [module] from the pattern at [cells], putting it in [target].
  void build(String module, List<int> cells, int target) {
    if (_finished) throw const FormatException('the game is over');
    final key = '$module:${(List.of(cells)..sort()).join(',')}';
    final m = matches().where((x) => x.key == key).firstOrNull;
    if (m == null) throw FormatException('no $module pattern at $cells');
    if (!m.targets.contains(target)) throw FormatException('${m.module.name} cannot go in cell $target');
    for (final i in m.cells) {
      slots[i] = Slot.empty;
    }
    slots[target] = Slot.ofModule(m.module);
    moves.add('b$key:$target');
  }

  void finish() {
    if (!canFinish) throw const FormatException('parts can still be placed');
    _finished = true;
    moves.add('f');
  }

  /// Applies one move in its saved form: `p<bin>:<cell>`,
  /// `b<module>:<cell,cell,...>:<target>` or `f`.
  void apply(String move) {
    try {
      if (move == 'f') return finish();
      final f = move.substring(1).split(':');
      switch (move[0]) {
        case 'p':
          return place(int.parse(f[0]), int.parse(f[1]));
        case 'b':
          return build(f[0], [for (final s in f[1].split(',')) int.parse(s)], int.parse(f[2]));
      }
    } on RangeError {
      // fall through to the error below
    }
    throw FormatException('bad move "$move"');
  }

  /// Cable cells holding a raw part.
  int get blocking => day.cable.where((i) => slots[i].isPart).length;

  /// Cable cells holding a module.
  int get patchedCount => day.cable.where((i) => slots[i].isModule).length;
  bool get completePatch => patchedCount == day.cable.length;
}
