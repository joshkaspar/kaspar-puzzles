# Plan: move the games out of the fork

Status (2026-11-22): carried out. This repo is the result of phase 1. The paths below
are the old ones, from the Puzzle fork (`tools/…`, `web/…`).

Train Tracks and Rack & Resonance are their own games. They share nothing with the
Puzzle app except the hosting: Flutter's web build copies `web/`, so `/tracks/` and
`/rack/` ride along in the app's image. This plan gives them a repo of their own. The
URLs stay the same, and so does every player's saved progress.

## Goals and constraints

- **Same URLs, same origin.** Progress is in each browser's localStorage, which is tied
  to `https://puzzles.kaspar.casa`. `/tracks/` and `/rack/` must keep being served from
  that host at those paths, or every player loses their saved games. (The keys are
  `tracks-play:…` and `rack-play:…`.)
- **No tunnel changes.** The Cloudflare tunnel's routing isn't recorded in git
  (dashboard-managed), so the plan keeps one container on one port.
- **Keep the history.** All 8 game commits (e546bf4 … bb9da4b) touch only `tools/` and
  `web/tracks|rack`, so they can be extracted cleanly.
- **Every phase is deployable and reversible.** A deploy is a tag bump on zuul, and
  rolling back means setting the old tag again.
- **Proof at each step:** the served `tracks/index.html` and `rack/index.html` stay
  byte-identical (compare md5s before and after each deploy).

## Recommended shape

One image, two sources. `puzzle-docker` keeps building the Flutter app from the fork,
and a new small stage copies the game pages in from the new repo at a pinned commit.

```
joshkaspar/kaspar-puzzles (new)        joshkaspar/Puzzle (fork, back to a mirror)
  tracks/   generator, solver, page      main = upstream, untouched
  rack/     engine, tools, page               │
  site/tracks/index.html  (built)            │ PUZZLE_REF
  site/rack/index.html    (built)            ▼
        │ GAMES_REF                 puzzle-docker: Flutter stage ─┐
        └──────────────────────────▶ games stage (git, no build) ─┴▶ nginx image
```

I rejected a second container for the games, which would need path routing in the
tunnel or a proxy: it adds a moving part outside git for no gain. The pages are
prebuilt static files, so copying them in is enough.

Decided 2026-11-22: the repo is `joshkaspar/kaspar-puzzles`, licensed GPL-3.0 like the fork.

## Phase 0: prerequisites

1. ~~Settle the uncommitted work in the fork.~~ Done 2026-11-22: committed as c5115c8
   (FORK.md and the Train Tracks README/build.sh notes), on `train-tracks`.
2. Install `git-filter-repo` (`pipx install git-filter-repo` or `apt install git-filter-repo`).
3. ~~Decide the new repo's name and licence.~~ Decided: `kaspar-puzzles`, GPL-3.0. Nothing
   changes for licensing, since the code is already GPL-3.0 in the fork.

## Phase 1: create the games repo, with history

1. Make a fresh clone of the fork (never filter the working copy), then:
   ```sh
   git filter-repo \
     --path tools/tracks --path web/tracks --path tools/rack --path web/rack \
     --path-rename tools/tracks/:tracks/ --path-rename tools/rack/:rack/ \
     --path-rename web/tracks/:site/tracks/ --path-rename web/rack/:site/rack/
   ```
   Check that `git log` shows the 8 game commits and nothing from upstream.
2. Fix paths for the new layout:
   - Both `build.sh` scripts write `../../web/<game>/index.html`; change that to
     `../site/<game>/index.html`.
   - Update the READMEs' mentions of `tools/…`, `web/…` and FORK.md.
   - Update `rack/HANDOFF.md`'s architecture section.
3. Add a top-level README (what the repo is, which game is at which URL, how a page
   gets built and deployed), a `LICENSE` (the GPL-3.0 text, copied from the fork's), and a short AI note: built with Claude Code.
   Keep the Tiny Towns credit in Rack's README and page.
4. **CI** (GitHub Actions, Dart only, about a minute):
   - `dart test` in `rack/engine`.
   - Run `rack/build.sh --page-only`, then `git diff --exit-code site/`, so a committed
     page can't drift from its template and engine.
   - Train Tracks has no test suite. Run `bin/fuzz.dart` on a small grid as a smoke check.
5. **Verify:** `rack/build.sh --page-only` and the Train Tracks page rebuild give md5s
   identical to the current `web/*/index.html`. Push to GitHub.

## Phase 2: puzzle-docker builds from both repos

1. Dockerfile: add a stage that only fetches files, and make the games an optional
   last layer. The app-only image becomes a stage of its own (`app`), and the default
   (last) stage adds the games on top of it:
   ```dockerfile
   FROM ${FLUTTER_IMAGE} AS build          # unchanged: builds the app from PUZZLE_REPO@PUZZLE_REF
   ...

   FROM alpine/git:<pinned> AS games       # fetches the prebuilt pages, builds nothing
   ARG GAMES_REPO=https://github.com/joshkaspar/kaspar-puzzles.git
   ARG GAMES_REF=<full commit>
   WORKDIR /src
   RUN git init -q . && git remote add origin "$GAMES_REPO" \
    && git fetch -q --depth 1 origin "$GAMES_REF" && git checkout -q FETCH_HEAD

   FROM nginx:1.30-alpine AS app           # the app alone: labels, nginx.conf, healthcheck
   COPY nginx.conf /etc/nginx/conf.d/default.conf
   COPY --from=build /src/build/web /usr/share/nginx/html
   ...

   FROM app                                # default target: the app plus the games
   COPY --from=games /src/site/ /usr/share/nginx/html/
   ```
   - The games are copied last, so they win over any stale copy from the fork.
   - `docker build --target app` never runs the games stage. BuildKit skips stages the
     target doesn't need, so an app-only build doesn't even fetch the games repo.
   - The nginx no-cache rule for `tracks/` and `rack/` can stay in the shared
     `nginx.conf`. In an app-only image it just matches nothing.
   - Give the default stage its own `org.opencontainers.image.description` ("…plus
     Train Tracks and Rack & Resonance"), so the label says what's in each image.
2. **App-only builds, documented** (puzzle-docker README, a new section "Building the
   app without the extra games"). Anyone can build the original app, with no fork code
   at all:
   ```sh
   docker build --target app -t puzzle \
     --build-arg PUZZLE_REPO=https://github.com/sidhant947/puzzle.git \
     --build-arg PUZZLE_REF=main \
     https://github.com/joshkaspar/puzzle-docker.git
   ```
   The README should also say:
   - `PUZZLE_REF` takes a branch, a tag or a full commit hash.
   - The build pulls the multi-GB Flutter image, so it needs that much disk.
   - To run it, set `image: puzzle` (their local tag) in `docker-compose.yml`.

   CI only publishes the full image, because publishing an app-only image as well
   would double the CI work for no current user. If one is ever wanted, a second
   build-push step with `target: app` and a `-app` tag suffix would cover it.
3. **Faster game releases:** add `cache-from: type=gha` and `cache-to: type=gha,mode=max`
   to the build-push step. When only `GAMES_REF` changes, the Flutter stage comes from
   cache, so a game release takes about a minute instead of a full Flutter build.
4. **Tag scheme:** `<puzzle 7>-g<games 7>-n<nginx minor>`, for example
   `f8a968b-g1a2b3c4-n1.30`. Update the "Compute image tag" step, `docker-compose.yml`,
   `.env.example` and the README's release steps. A new tag for either source keeps old
   tags for rollback.
5. **Release and deploy, with the fork unchanged:** the games now arrive twice (fork and
   games repo) with identical bytes, so nothing visible changes. Verify the md5s on
   `https://puzzles.kaspar.casa/tracks/` and `/rack/`.

## Phase 3: take the games out of the fork

1. **Decide what the fork pins:**
   - **Recommended:** pin plain `main` (upstream) commits, and retire `train-tracks` as
     the deploy branch. FORK.md's content moves to puzzle-docker's README, and the fork
     goes back to being a pure mirror. It's kept for upstream PRs, and as insurance if
     upstream rewrites or deletes history.
   - **Alternative:** keep a `deploy` branch (main + FORK.md). Only worth it if app
     patches are ever needed.
2. Don't delete `train-tracks` or the game commits from the fork. Old image tags were
   built from them, and keeping them keeps those tags reproducible.
3. Bump `PUZZLE_REF` to the chosen commit, release and deploy. Verify the md5s again,
   and that the app itself still loads at `/`.
   Also build once with `--target app` and check that it serves the app with no
   `/tracks/` or `/rack/`. Before this phase the fork still carried the games, so this
   is the first point where app-only builds are really clean.
4. If upstream ever adds its own `/tracks/` or `/rack/`, the games stage would silently
   override it. Note this in puzzle-docker's README.

## Phase 4: tidy the records

- **zuul-unraid:** `apps/puzzle/README.md` (the sources are now two repos) and the day's
  changelog. The tag on zuul works as usual: back up `.env`, set `PUZZLE_TAG`, pull,
  `up -d`.
- **puzzle-docker README:** what it builds from, how to release a game-only change
  (bump `GAMES_REF`) and an app change (bump `PUZZLE_REF`), and the app-only build from
  phase 2.
- **Claude memory:** `build-via-puzzle-docker` and `dart-sdk-local` (new repo path,
  two refs).
- **Change notes:** new work in the games repo goes to
  `~/.claude/learning/notes/<new-repo>.md`; the old notes stay in `Puzzle.md`.

## Rollback at any phase

On zuul, set `PUZZLE_TAG` to the previous tag and run `docker compose -p puzzle up -d`.
Nothing in this plan changes storage, the tunnel, ports or the compose stack, so a tag
is the whole state.

## Effort

About half a day, most of it phase 1 (restructuring paths, READMEs and CI). Phases 2–3
are two small releases, each a normal deploy.
