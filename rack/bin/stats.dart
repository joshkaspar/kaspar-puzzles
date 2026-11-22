import 'package:rack_engine/rack_engine.dart';

/// Balance numbers: the greedy bot plays N generated days.
/// dart run bin/stats.dart [N]
void main(List<String> args) {
  final n = args.isEmpty ? 40 : int.parse(args[0]);
  print('${allRoutes.length} routes; cable lengths: ${{
    for (final l in [4, 5, 6]) l: allRoutes.where((r) => r.length - 2 == l).length
  }}');
  final sw = Stopwatch()..start();
  final scores = <int>[];
  var complete = 0;
  final patched = <int>[];
  final built = <String, int>{};
  for (var k = 0; k < n; k++) {
    final day = generateDay(Rng(fnv1a('stats:$k')));
    final g = playGreedy(day);
    final s = score(g);
    scores.add(s.total);
    patched.add(g.patchedCount - day.cable.length);
    if (g.completePatch) complete++;
    for (final sl in g.slots.where((s) => s.isModule)) {
      built[sl.module!.id] = (built[sl.module!.id] ?? 0) + 1;
    }
  }
  scores.sort();
  print('$n games in ${sw.elapsedMilliseconds} ms');
  print('scores: min ${scores.first} median ${scores[n ~/ 2]} max ${scores.last}');
  print('complete patches: $complete/$n; patched minus cable length: ${patched..sort()}');
  print('built: $built');
}
