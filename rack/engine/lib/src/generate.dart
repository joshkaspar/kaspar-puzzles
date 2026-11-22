/// Daily content: cable routes, module lineups and part orders
/// (HANDOFF.md, "Cable routes and the daily generator").
library;

import 'board.dart';
import 'game.dart';
import 'model.dart';
import 'rng.dart';

const int minCable = 4, maxCable = 6;
const int partsLength = 36;

/// Every route allowed by the version 1 constraints, as OSC, cable cells, OUT.
final List<List<int>> allRoutes = _enumerateRoutes();

List<List<int>> _enumerateRoutes() {
  final out = <List<int>>[];
  void walk(List<int> path) {
    final cableLen = path.length - 1; // all but OSC so far
    if (cableLen >= minCable && onEdge(path.last)) {
      // Treat the last cell as OUT: the cable is everything between.
      final route = [...path];
      if (route.length - 2 >= minCable && routeAllowed(route)) out.add(route);
    }
    if (path.length - 1 > maxCable) return;
    for (final n in orthNeighbours(path.last)) {
      if (path.contains(n)) continue;
      // The cable never touches itself, except the cell it just came from.
      if (orthNeighbours(n).any((x) => x != path.last && path.contains(x))) continue;
      walk([...path, n]);
    }
  }

  for (var i = 0; i < cellCount; i++) {
    if (onEdge(i)) walk([i]);
  }
  return out;
}

/// The version 1 route rules for a full route (OSC, cable…, OUT).
bool routeAllowed(List<int> route) {
  final osc = route.first, out = route.last;
  final cable = route.sublist(1, route.length - 1);
  if (cable.length < minCable || cable.length > maxCable) return false;
  // Jacks on edges, never next to each other (diagonals included).
  if (!onEdge(osc) || !onEdge(out)) return false;
  if ((rowOf(osc) - rowOf(out)).abs() <= 1 && (colOf(osc) - colOf(out)).abs() <= 1) return false;
  // At least one bend.
  final rows = route.map(rowOf).toSet(), cols = route.map(colOf).toSet();
  if (rows.length == 1 || cols.length == 1) return false;
  // Never more than two cable cells in a row along an edge.
  for (var k = 0; k + 2 < cable.length; k++) {
    final three = cable.sublist(k, k + 3);
    for (final line in [(rowOf, 0), (rowOf, size - 1), (colOf, 0), (colOf, size - 1)]) {
      if (three.every((i) => line.$1(i) == line.$2)) return false;
    }
  }
  // No cable cell completely surrounded by cable and jacks.
  final taken = route.toSet();
  for (final i in cable) {
    if (orthNeighbours(i).every(taken.contains)) return false;
  }
  // Jacks only touch the cable at its ends.
  if (orthNeighbours(osc).where(taken.contains).length != 1) return false;
  if (orthNeighbours(out).where(taken.contains).length != 1) return false;
  return true;
}

/// Picks a lineup: 4 cable modules, 2 modulators and 1–2 utilities, with the
/// feasibility rules (VCA needs an Envelope and an LFO; at most two of the
/// modules that want the last slot before OUT).
List<ModuleType> pickLineup(Rng rng) {
  final black = pool.where((m) => m.onCable).toList();
  final mods = pool.where((m) => m.isModulator).toList();
  final utils = pool.where((m) => m.isUtility).toList();
  while (true) {
    rng.shuffle(black);
    rng.shuffle(mods);
    rng.shuffle(utils);
    final lineup = [
      ...black.take(4),
      ...mods.take(2),
      ...utils.take(1 + rng.nextInt(2)),
    ];
    if (lineupAllowed(lineup)) return lineup;
  }
}

bool lineupAllowed(List<ModuleType> lineup) {
  final ids = lineup.map((m) => m.id).toSet();
  if (ids.contains('vca') && !(ids.contains('env') && ids.contains('lfo'))) return false;
  if (ids.contains('clock') && !lineup.any((m) => m.isModulator)) return false;
  if (ids.intersection({'drive', 'reverb', 'delay'}).length > 2) return false;
  return true;
}

/// How many of each part the lineup's patterns use.
Map<Part, int> demand(List<ModuleType> lineup) {
  final d = {for (final p in Part.values) p: 0};
  for (final m in lineup) {
    for (final c in m.cells) {
      d[c.part] = d[c.part]! + 1;
    }
  }
  return d;
}

/// A part order of [length] parts in proportion to the lineup's demand
/// (each used part at least 3 times, unused parts never), shuffled so no type
/// clumps: no three in a row, and no type more than twice its share in any
/// window of 9.
List<Part> partOrder(Rng rng, List<ModuleType> lineup, {int length = partsLength}) {
  final d = demand(lineup);
  final used = Part.values.where((p) => d[p]! > 0).toList();
  final total = used.fold(0, (a, p) => a + d[p]!);
  // Largest-remainder rounding, with a floor of 3.
  final counts = {for (final p in used) p: 3};
  var left = length - 3 * used.length;
  final share = {for (final p in used) p: left * d[p]! / total};
  for (final p in used) {
    counts[p] = counts[p]! + share[p]!.floor();
  }
  left = length - counts.values.fold(0, (a, b) => a + b);
  final byRemainder = [...used]..sort((a, b) => (share[b]! % 1).compareTo(share[a]! % 1));
  for (var k = 0; k < left; k++) {
    counts[byRemainder[k % byRemainder.length]] = counts[byRemainder[k % byRemainder.length]]! + 1;
  }
  final bag = [for (final p in used) for (var k = 0; k < counts[p]!; k++) p];
  while (true) {
    rng.shuffle(bag);
    if (!clumped(bag, counts)) return List.of(bag);
  }
}

bool clumped(List<Part> order, Map<Part, int> counts) {
  for (var k = 0; k + 2 < order.length; k++) {
    if (order[k] == order[k + 1] && order[k] == order[k + 2]) return true;
  }
  const w = 9;
  for (var k = 0; k + w <= order.length; k++) {
    final win = order.sublist(k, k + w);
    for (final p in counts.keys) {
      final expected = counts[p]! * w / order.length;
      if (win.where((x) => x == p).length > 2 * expected + 0.5) return true;
    }
  }
  return false;
}

/// One unscreened day.
Day generateDay(Rng rng) {
  // Pick the cable length first, so the many 6-cell routes don't crowd out the rest.
  final len = minCable + rng.nextInt(maxCable - minCable + 1);
  final routes = allRoutes.where((r) => r.length - 2 == len).toList();
  final route = routes[rng.nextInt(routes.length)];
  final lineup = pickLineup(rng);
  return Day(route: route, lineup: lineup, parts: partOrder(rng, lineup));
}
