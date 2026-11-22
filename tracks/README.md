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
The output is committed, so the Docker build never runs the generator.

```sh
tracks/build.sh                      # 365 days from 2026-11-01, takes a few minutes
tracks/build.sh --from=2027-11-01    # extra args go to bin/pregen.dart
```

The script writes `site/tracks/index.html` (template plus puzzle data). puzzle-docker
copies `site/` into the served site, so it's at `/tracks/`.

Puzzles depend only on the date, the slot and the seed version (`tracks:v4`) in
`bin/pregen.dart`. Rebuilding the same dates gives the same puzzles, so progress
saved in the playtest page carries over. Changing the generator or the version
changes them.

### Changing only the page

`build.sh` needs Dart. If only `playtest/template.html` changed, the page can be rebuilt
without it: `site/tracks/index.html` is the template with its `/*DATA*/null` marker
replaced by one line, `const DATA = {...};`. Put that line from the current page into
the new template. This is what `bin/playtest.dart` does, and the puzzles stay the same.

## The playtest page

Everything is in `playtest/template.html`: one HTML file with inline CSS and JS, no
libraries.

- **Play:** drag between squares to lay track, drag back along it to remove it, tap to
  mark a square • (track) then ✕ (no track). Undo, Check for mistakes (flashes wrong
  squares red) and Restart (asks twice).
- **Clues** turn grey when a row or column is complete, red when it has too much.
- **Solving:** the track turns green, a train runs from A to B, then a card shows the
  time and number of checks. Copy result gives
  `Train Tracks <date> · <size> · <time>, <n> checks` plus the page link.
- **Tutorial:** a 4×4 practice puzzle that teaches the solving order: dot squares that
  must have track, cross off squares that can't, then draw. It's a list of steps
  (`STEPS`); each one highlights part of the board and moves on when its `done()` check
  passes. It opens on the first visit and again from "How to play".
- **Themes:** light and dark follow the device. Page colours are CSS variables; board
  colours are in `PALETTE`, because SVG attributes can't use CSS variables. Reduced
  motion skips the train and the tutorial's ghost finger.
- **Saved in localStorage**, per browser: `tracks-play:v<version>:<date>:<slot>` holds
  each puzzle's progress, `tracks-tutorial:seen` that the tutorial was finished or
  skipped. The practice puzzle is never saved.

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
