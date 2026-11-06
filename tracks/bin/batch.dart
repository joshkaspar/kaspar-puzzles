import 'package:tracks_proto/tracks.dart';

/// Quick in-memory run: dart run bin/batch.dart <size> <level> <n>
void main(List<String> args) {
  final size = int.parse(args[0]), level = int.parse(args[1]), n = int.parse(args[2]);
  var attempts = 0, walks = 0, notUnique = 0, mismatch = 0, hintSum = 0, maxMs = 0;
  final sw = Stopwatch()..start();
  for (var seed = 1; seed <= n; seed++) {
    final st = GenStats();
    final t0 = sw.elapsedMilliseconds;
    final p = generate(Rng(seed), size, size, level, stats: st, endgame: args.length > 3 ? double.parse(args[3]) : 0.15);
    final ms = sw.elapsedMilliseconds - t0;
    if (ms > maxMs) maxMs = ms;
    attempts += st.attempts;
    walks += st.walks;
    hintSum += p.hints.length;
    final m = Solver(level, endgame: args.length > 3 ? double.parse(args[3]) : 0.15).solve(p).board.masks();
    if (!Iterable.generate(m.length).every((i) => m[i] == p.solution![i])) mismatch++;
    if (size <= 8 && countSolutions(p) != 1) notUnique++;
  }
  print('${size}x$size L$level n=$n: ${(sw.elapsedMilliseconds / n).toStringAsFixed(0)}ms avg '
      '(max $maxMs), attempts ${(attempts / n).toStringAsFixed(1)}, '
      'walks/attempt ${(walks / attempts).toStringAsFixed(1)}, hints ${(hintSum / n).toStringAsFixed(1)}, '
      'solver!=path $mismatch${size <= 8 ? ', not unique $notUnique' : ''}');
}
