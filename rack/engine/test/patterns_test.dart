// Port of reference/check_patterns.py: no two patterns may be the same, and no
// smaller pattern may hide inside a larger one.
import 'package:rack_engine/rack_engine.dart';
import 'package:test/test.dart';

/// Whether some orientation of [small] fits inside [big]'s own cells with
/// matching parts (one placement would complete both).
bool hidesInside(ModuleType big, ModuleType small) {
  final b = {for (final p in big.cells) (p.r, p.c): p.part};
  for (final o in small.orients) {
    for (final (br, bc) in b.keys) {
      for (final s in o.cells) {
        final dr = br - s.r, dc = bc - s.c;
        if (o.cells.every((p) => b[(p.r + dr, p.c + dc)] == p.part)) return true;
      }
    }
  }
  return false;
}

void main() {
  test('16 modules with unique ids', () {
    expect(pool.length, 16);
    expect(poolById.length, 16);
  });

  test('no duplicate patterns', () {
    for (final a in pool) {
      for (final b in pool) {
        if (a == b || a.size != b.size) continue;
        final ka = a.orients.map((o) => o.key).toSet();
        final kb = b.orients.map((o) => o.key).toSet();
        expect(ka.intersection(kb), isEmpty, reason: '${a.name} = ${b.name}');
      }
    }
  });

  test('no hidden patterns', () {
    for (final a in pool) {
      for (final b in pool) {
        if (a.size > b.size) expect(hidesInside(a, b), isFalse, reason: '${b.name} hides inside ${a.name}');
      }
    }
  });

  test('banned neighbours never sit side by side inside larger patterns', () {
    const banned = [(Part.knob, Part.coil), (Part.chip, Part.chip), (Part.tube, Part.jack)];
    for (final m in pool.where((m) => m.size > 2)) {
      final at = {for (final p in m.cells) (p.r, p.c): p.part};
      for (final p in m.cells) {
        for (final (dr, dc) in [(0, 1), (1, 0)]) {
          final q = at[(p.r + dr, p.c + dc)];
          if (q == null) continue;
          for (final (x, y) in banned) {
            expect((p.part == x && q == y) || (p.part == y && q == x), isFalse,
                reason: '${m.name} has ${x.label} next to ${y.label}');
          }
        }
      }
    }
  });

  test('part totals are 8/11/13/8/12 (52)', () {
    final n = {for (final p in Part.values) p: 0};
    for (final m in pool) {
      for (final c in m.cells) {
        n[c.part] = n[c.part]! + 1;
      }
    }
    expect(n, {Part.tube: 8, Part.knob: 11, Part.jack: 13, Part.coil: 8, Part.chip: 12});
  });

  test('orientation counts', () {
    expect(moduleById('vcf').orients.length, 4); // a domino: 2 directions × 2 orders
    expect(moduleById('random').orients.length, 2); // HH reads the same both ways
    expect(moduleById('delay').orients.length, 8);
  });
}
