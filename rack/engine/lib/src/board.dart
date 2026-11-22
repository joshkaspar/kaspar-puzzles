/// Board geometry: a 5×5 grid, cells numbered `r * 5 + c`.
library;

const int size = 5;
const int cellCount = size * size;

int rowOf(int i) => i ~/ size;
int colOf(int i) => i % size;
int cellAt(int r, int c) => r * size + c;
bool inBoard(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

const _orth = [(-1, 0), (1, 0), (0, -1), (0, 1)];
const _diag = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

List<int> _around(int i, List<(int, int)> ds) => [
      for (final (dr, dc) in ds)
        if (inBoard(rowOf(i) + dr, colOf(i) + dc)) cellAt(rowOf(i) + dr, colOf(i) + dc),
    ];

/// Up, down, left and right.
List<int> orthNeighbours(int i) => _around(i, _orth);

/// The four diagonal cells.
List<int> diagNeighbours(int i) => _around(i, _diag);

/// All 8 surrounding cells.
List<int> allNeighbours(int i) => _around(i, [..._orth, ..._diag]);

bool onEdge(int i) => rowOf(i) == 0 || rowOf(i) == size - 1 || colOf(i) == 0 || colOf(i) == size - 1;

/// "B3"-style name: column letter A–E, row 1–5. Used by the text runner.
String cellName(int i) => '${'ABCDE'[colOf(i)]}${rowOf(i) + 1}';

int parseCell(String s) {
  s = s.trim().toUpperCase();
  if (s.length != 2) throw FormatException('bad cell "$s"');
  final c = 'ABCDE'.indexOf(s[0]);
  final r = int.tryParse(s[1]);
  if (c < 0 || r == null || r < 1 || r > size) throw FormatException('bad cell "$s"');
  return cellAt(r - 1, c);
}
