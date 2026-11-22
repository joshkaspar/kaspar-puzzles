/// The patch's sound, as a recipe the page turns into Web Audio nodes.
///
/// One voice runs down the cable: OSC sets the tone, each cable slot in order
/// changes it, and modulators touching the cable add movement. The sound is
/// deliberately not tied to the score.
library;

import 'game.dart';
import 'rng.dart';
import 'scoring.dart';

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
  return {'chain': chain, 'mods': mods, 'seed': seed, 'complete': g.completePatch};
}
