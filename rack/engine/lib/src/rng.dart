/// Seeded RNG (mulberry32), the same one Train Tracks uses, so days are
/// reproducible from a date string.
library;

class Rng {
  int _s;
  Rng(int seed) : _s = seed & 0xFFFFFFFF;

  static int imul(int a, int b) {
    a &= 0xFFFFFFFF;
    b &= 0xFFFFFFFF;
    final ah = a >> 16, al = a & 0xFFFF;
    return (al * b + (((ah * b) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  int nextU32() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  int nextInt(int n) => nextU32() % n;
  double nextDouble() => nextU32() / 4294967296.0;
  bool nextBool() => nextU32() & 1 == 1;
  T pick<T>(List<T> l) => l[nextInt(l.length)];
  void shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

int fnv1a(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = Rng.imul(h ^ c, 0x01000193);
  }
  return h;
}
