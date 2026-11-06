import 'package:tracks_proto/tracks.dart';

/// dart run bin/tracks.dart <size> <level> <seed>  - generate and print one puzzle
void main(List<String> args) {
  final size = int.parse(args[0]), level = int.parse(args[1]);
  final p = generate(Rng(int.parse(args[2])), size, size, level);
  print(p.encode());
  print(render(p));
  print(render(p, masks: p.solution));
}
