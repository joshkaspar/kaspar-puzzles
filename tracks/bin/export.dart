import 'dart:convert';
import 'dart:io';
import 'package:tracks_proto/tracks.dart';

/// Playtest data: each puzzle as [encoding, solution] where the solution is
/// one hex digit (piece mask) per cell, row by row.
/// dart run bin/export.dart <in.json> <out.json>
void main(List<String> args) {
  final data = jsonDecode(File(args[0]).readAsStringSync());
  final out = {
    'version': data['version'],
    'slots': data['slots'],
    'puzzles': {
      for (final e in (data['puzzles'] as Map).entries)
        e.key: [
          for (final s in e.value as List)
            () {
              final p = decode(s as String);
              final r = Solver(3).solve(p);
              if (!r.board.complete) throw StateError('unsolved ${e.key}');
              return [s, r.board.masks().map((m) => m.toRadixString(16)).join()];
            }()
        ]
    }
  };
  File(args[1]).writeAsStringSync(jsonEncode(out));
}
