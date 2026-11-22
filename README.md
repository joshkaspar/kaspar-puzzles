# kaspar-puzzles

Two daily browser games, played at [puzzles.kaspar.casa](https://puzzles.kaspar.casa):

| Game | URL | Source |
|---|---|---|
| **Train Tracks**: a logic puzzle, three sizes a day | [`/tracks/`](https://puzzles.kaspar.casa/tracks/) | [`tracks/`](tracks/README.md) |
| **Rack & Resonance**: build a modular synth from falling parts, then play it | [`/rack/`](https://puzzles.kaspar.casa/rack/) | [`rack/`](rack/README.md) |

Each game is one self-contained HTML file in `site/`, with no server side and no
libraries. Every day's puzzle is pregenerated and baked into the page, so everyone gets
the same one. Progress is kept in the browser's localStorage (`tracks-play:…` and
`rack-play:…`), so the games must stay on the same host and paths.

## Layout

```
tracks/        Dart generator, solver and tools; playtest/template.html is the page
rack/          Dart engine (rules and scoring, also compiled to JS for the page),
               daily generator, bots, page/template.html, design hand-off
site/          the built pages, committed: site/tracks/index.html, site/rack/index.html
docs/          SPLIT-PLAN.md: how these games moved here from the Puzzle fork
```

## Building

Only the plain [Dart SDK](https://dart.dev/get-dart) is needed (CI uses 3.14.1).

```sh
tracks/build.sh            # a year of puzzles, then site/tracks/index.html (~3 min)
rack/build.sh              # engine tests, a year of patches, then site/rack/index.html (~2 min)
rack/build.sh --page-only  # reuse the generated days; rebuild the engine and page
```

The days depend only on the date and each game's seed version, so a rebuild gives the
same pages. CI rebuilds both from scratch and fails if `site/` differs from what's
committed.

## Deploying

The pages are served from the same nginx image as the [Puzzle](https://github.com/sidhant947/puzzle)
app. [`joshkaspar/puzzle-docker`](https://github.com/joshkaspar/puzzle-docker) builds
the app, then copies this repo's `site/` on top, from the commit pinned in its
Dockerfile as `GAMES_REF`. To release a game change:

1. Rebuild the page, commit and push here.
2. In puzzle-docker, set `GAMES_REF` to the new commit and update the image tag
   (`<puzzle 7>-g<games 7>-n<nginx minor>`), as its README describes. CI builds the image.
3. On the server, set `PUZZLE_TAG` to the new tag and pull. Rolling back is setting the
   old tag again.

## Licence and credits

GPL-3.0, like the Puzzle app these games started in ([LICENSE](LICENSE)). Rack &
Resonance is inspired by *Tiny Towns* by Peter McPherson (AEG). See [AI.md](AI.md) for
how the games were made.
