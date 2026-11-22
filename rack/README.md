# Rack & Resonance

A daily puzzle. You place synth parts one at a time on a 5×5 cabinet. Matching a
blueprint's pattern builds that module in one of the pattern's cells. Modules built on
the day's cable, between the OSC and OUT jacks, score as the signal chain. At the end
the rack is scored, and you can play the sound you built. Served at `/rack/`, next to
Train Tracks.

The design and the rules are in [HANDOFF.md](HANDOFF.md). This file covers what is
built and how to work on it.

## Layout

| Path | What |
|---|---|
| `engine/` | Pure Dart package `rack_engine`: parts, the 16 modules, pattern orientations, matching, building, cable state, scoring, the sound recipe, the day generator and a greedy bot. |
| `engine/test/` | `patterns_test.dart` (port of `reference/check_patterns.py`) and `rules_test.dart` (one test per rule). |
| `bin/pregen.dart` | Writes `build/rack_daily.json`: 365 seeded days. |
| `bin/play.dart` | Text-mode game for playtesting. |
| `bin/bot.dart`, `bin/stats.dart` | The bot plays one day (prints its moves), or N random days (balance numbers). |
| `page/main.dart` | Compiles the engine to JS and exposes `rackView(dayJson, movesJson)`. |
| `page/template.html` | The page: HTML/SVG art, layout, input, result screen and Web Audio. |
| `bin/page.dart` | Inlines the compiled engine and the data into the template. |
| `build.sh` | Tests, pregen, compile, page. Writes `web/rack/index.html`. |

## Setup and building

This needs only the plain Dart SDK, no Flutter. The SDK is installed at
`~/.local/share/dart-sdk`, so put `~/.local/share/dart-sdk/bin` on `PATH`.

```sh
tools/rack/build.sh               # tests, 365 days from 2026-11-01 (~2 min), engine, page
tools/rack/build.sh --page-only   # keep the days; recompile the engine and rebuild the page
cd tools/rack/engine && dart test
cd tools/rack && dart run bin/play.dart --date=2026-11-22
```

The output `web/rack/index.html` is committed, like Train Tracks, so the Docker build
never runs Dart. Deploying works the same as Train Tracks (see FORK.md).

Days depend only on the date and the seed version (`rack:v1`) in `bin/pregen.dart`.
Changing the generator or the version changes them, and that breaks games saved in
browsers, because saved games are lists of moves.

## How a day is made

1. **Route:** pick a cable length of 4, 5 or 6 cells (equal odds), then one of the
   2,072 routes that pass the version 1 rules: jacks on edges and not touching, at least
   one bend, never more than two cells along an edge, no cell boxed in, and the cable
   never touches itself.
2. **Lineup:** 4 cable modules, 2 modulators and 1–2 utilities. VCA needs an Envelope
   and an LFO, Clock needs a modulator, and at most two of Overdrive, Reverb and Delay
   (they all want the last slot before OUT).
3. **Part order:** 36 parts in proportion to what the lineup's patterns use. Each part
   that's used appears at least 3 times; unused parts never appear. Shuffled until no
   type appears three in a row, or more than twice its share in any 9.
4. **Screen:** the greedy bot plays the day. If it can't get within two modules of a
   complete patch, or the route and lineup repeat an earlier day, the day is re-rolled
   (60 of 365 were). The bot's median score is 25.

## Rules as built (decisions made while building)

- **Who goes where:** black modules can go in any cell of their pattern, but score only
  on the cable. Modulators and utilities can't be built on a cable cell. A pattern that
  lies entirely on the cable can't be built as a modulator.
- **Ending:** the game ends by itself when no part can be placed and nothing can be
  built. Once nothing can be placed, FINISH ends it even if builds remain.
- **Points** are placeholders, all in `Points` in `engine/lib/src/scoring.dart`. The
  knob cap is 6 points per patched module, across all its modulators.
- **Running score:** the score bar leaves out the empty-slot penalty until the end, so a
  new game doesn't start at −23.
- **An open patch plays what it has:** a raw part on the cable makes the signal crackle,
  and an empty cable slot thins it out. In-game PLAY needs a complete patch; the result
  screen's PLAY PATCH always works.
- **Undo** works at any time, even after the end.

## The page

- One view call per move. The page keeps the move list (`p<bin>:<cell>`,
  `b<module>:<cells>:<target>`, `f`), and the engine replays it and returns the board,
  the bin, buildable matches, the score lines and the sound recipe. Undo drops the last
  move. Saved games that no longer replay are cut back to the last good move.
- **Saved in localStorage:** `rack-play:v1:<date>` holds the moves, the time and whether
  the result has been shown. `rack-howto:seen` records that the how-to sheet opened
  once.
- `?date=YYYY-MM-DD` opens another day (for testing). The patch number counts from the
  data's start date.
- **Art:** the part and jack art is copied from `reference/mockups/Main.dc.html`. Module
  faces are drawn from small helpers (panel, knob, nut, LED, fader, CRT), one layout per
  module.
- **Sound** (Web Audio, in the template's JS): a seeded 32-step tune on a saw
  oscillator. Each cable slot is a stage in order, and LFO, Envelope, Random, S&H, Clock
  and Quantizer touching the cable change the tune or its movement. The result scope
  plots the live signal while it plays.
