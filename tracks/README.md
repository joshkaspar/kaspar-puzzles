# Train Tracks

A daily Train Tracks puzzle: lay one track from A to B so each row and column has
the number of track squares shown. This folder holds the puzzle generator and
logic solver (plain Dart, no Flutter), plus a standalone playtest page. The page
is served at `/tracks/` until the game is built into the app.

## Puzzles

Puzzles are generated ahead of time, three per day:

| Slot | Size | Solver level needed |
|---|---|---|
| easy | 8×8 | 1: counts, each square's two exits, no loops |
| medium | 8×8 | 2: also crossing parity and connectivity |
| hard | 12×12 | 3: also one-step look-ahead, endgame only |

How a puzzle is made (`lib/tracks.dart`):

1. **Walk.** A random walk with momentum (`straight` = 0.5) goes from a random border
   square until it reaches 40–55% of the grid, then leaves at the next border square.
2. **Reject** walks that leave a row or column empty or completely full.
3. **Add hints** until the logic solver finishes. When it gets stuck, it tries a few
   candidate pieces and reveals the one that lets it work out the most.
4. **Remove** every hint the solver can do without.
5. **Keep** the puzzle only if it needs exactly the slot's solver level.

The solver only makes sound deductions, so a puzzle it finishes has exactly one
solution. `bin/fuzz.dart` checks that by brute force on small grids. `pregen`
also brute-force checks every 8×8 puzzle.

## Building

Rebuilding is only needed when the generator, the page or the date range changes.
The output is committed, so the app's build never runs the generator.

```sh
tools/tracks/build.sh                      # 365 days from 2026-11-01, about 2.5 min
tools/tracks/build.sh --from=2027-11-01    # extra args go to bin/pregen.dart
```

The script writes `web/tracks/index.html` (template plus puzzle data). Flutter's web
build copies it to `build/web/tracks/`.

Puzzles depend only on the date, the slot and the seed version (`tracks:v4`) in
`bin/pregen.dart`. Rebuilding the same dates gives the same puzzles, so progress
saved in the playtest page carries over. Changing the generator or the version
changes them.

## Tools

Run these from this folder with `dart run bin/<name>.dart`.

| Script | What it does |
|---|---|
| `pregen` | Builds the daily set (`--from`, `--days`, `--out`, `--straight`) |
| `export` | Adds solutions to the daily set, for the playtest page |
| `playtest` | Writes the page from `playtest/template.html` and the exported data |
| `show <date>` | Prints a day's puzzles and solutions as text |
| `metrics <file> <slot>` | Variety report: heatmap, corners, lookalikes, hints |
| `straights <file>` | Longest straight runs, full lines, hint mix |
| `fuzz` | Soundness check of the solver against brute force |
| `tracks <size> <level> <seed>` | One puzzle |
| `batch <size> <level> <n>` | Generation speed and hint counts |
