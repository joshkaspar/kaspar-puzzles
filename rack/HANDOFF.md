# Rack & Resonance: design hand-off

Rack & Resonance is a single-player daily puzzle. You place parts, one at a time, in a 5×5 modular-synth cabinet. When parts match a module's pattern, you build that module. Modules built on the day's pre-laid cable, between the fixed OSC and OUT jacks, score as part of the signal chain. At the end, the rack plays the sound you built.

This file is the starting point for building it. It records every design decision made so far, the version 1 module pool with rules and patterns, the cable and generator constraints, the art direction, and the planned architecture. Version 1 is now built. See [README.md](README.md) for what exists, and for the decisions made while building it.

It is inspired by *Tiny Towns* (Peter McPherson, AEG). Rack & Resonance reuses that game's general mechanics: placing resources on a small grid and swapping a matched pattern for a scoring piece. It does not use Tiny Towns' theme, names, buildings, patterns or rule text. Credit line for the page: **"Inspired by Tiny Towns by Peter McPherson (AEG)."**

## Where the working material lives

These are private claude.ai artifacts in Josh's account. This file is the source of truth if they ever disagree.

| What | Where |
|---|---|
| Plan doc (decisions, open questions) | https://claude.ai/artifact/Aex1RZ86MdGqaFBcVHcSBQ |
| Module pool spreadsheet (parts, patterns, status) | https://claude.ai/artifact/N99ohsTC2d9RAB6Y5iwkuS |
| Design canvas (game screen, result screen, module sheet, route sketches) | https://claude.ai/artifact/5rL2qekXTEe1SUfEGqNEa4 |
| Map-drawing game plan (game 2, later) | https://claude.ai/artifact/TFHQoTdbSeT4GMEQZrwi9o |

Copies of the mockup sources and exported art are in `reference/` (see "Reference files" below).

## Decisions so far

- **Game order.** Rack & Resonance is the first new game. A map-drawing game inspired by Cartographers comes second.
- **Theme.** A retro-analog modular synth rack, with a 1970s studio-wall look.
- **Name.** Rack & Resonance.
- **Daily format.** One puzzle per day for everyone: the same seeded part order, the same module lineup and the same cable route. There are no difficulty tiers yet.
- **Board.** 5×5. Two cells are fixed jacks (OSC and OUT), leaving 23 playable cells.
- **Signal flow, version 1.** One source (OSC) and one output (OUT), joined by a pre-laid cable route of 4–6 cells. Players don't draw cables or rotate modules. Free-form chains, gaps in the cable, module facings and extra sources are listed for later.
- **Sound.** One voice travels down the cable: the source sets the tone, each shaper changes it in cable order, and modulators add movement. It plays after a tap, since browsers only allow audio after a user gesture. **The sound is not tied to the score.** A rack that scores low but sounds great is a happy accident.
- **Par score.** Later.
- **Language.** Dart throughout (see "Architecture").
- **Parts.** There are five: tube, knob, jack, coil and chip. The fifth part is the chip, chosen over a capacitor or a switch.
- **Part amounts.** Leave them as drafted. Playtesting will decide the adjustments.
- **LFO and Clock** share the same three parts (knob, jack, chip) in different shapes. This is deliberate: you place one part at a time, so the shape you build decides which module you get.

## Rules of play (version 1)

1. **Setup.** The day gives you the cable route (OSC jack, OUT jack and the cable cells between them), a lineup of about 7–8 modules, and a seeded part order of about 30–40 parts.
2. **Turn.** The parts bin shows the next three parts. Pick one and place it in any empty cell. Fixed jacks can't hold parts.
3. **Build.** When the parts on the board match a lineup module's pattern (in any rotation or mirror image), you may build it. Building clears every part in the pattern. The module goes into one cell of the pattern, which you choose. Building is optional, and you can build more than one module at once.
4. **The cable.** A module built on a cable cell is *patched*. A raw part sitting on a cable cell blocks it until a module is built there. Shapers and effects score fully only when patched.
5. **Knobs.** A modulator touching a patched module acts as that module's knob. Each modulator's rule says which neighbours count: orthogonal, diagonal or all 8.
6. **End.** The game ends when you can't place the next part and can't build anything. Then the rack is scored, and the patch can be played.
7. **Complete patch.** Every cable cell holds a module.

### Scoring sketch (values to be set in playtesting)

- Each patched module: base points, then its own rule.
- Different shaper types along the cable: a variety bonus.
- Modulators touching the cable: their rule, with a cap per module so a single module can't stack them up.
- A complete patch: a large bonus.
- Modules off the cable: little or nothing, unless their rule says otherwise.
- Each empty cell and each leftover raw part: −1.

## Parts

| Part | Code | What it means on the board | Total in the v1 pool |
|---|---|---|---|
| Tube | TU / `T` | Analog warmth and drive | 8 |
| Knob | KN / `K` | Control | 11 |
| Jack | JK / `J` | Routing and inputs/outputs | 13 |
| Coil | CO / `C` | Filtering and tone | 8 |
| Chip | CH / `H` | Logic and timing | 12 |

That's 52 parts across the 16 version 1 modules, about 3.25 per module. Jacks are the highest, so if playtests show too many, trim jacks first.

## Module pool, version 1

There are three faceplate finishes, and each one marks a category:

- **Black:** on the cable (shapers, effects, dynamics).
- **Brushed aluminum:** modulators, off the cable.
- **Terracotta:** utilities, off the cable.

The fixed OSC and OUT jacks are **sage green**.

**Pattern grids.** Each row is a line of the shape, and `··` is an empty cell. Rotations and mirror images all count as the same pattern.

### On the cable (black)

| Module | Parts | Pattern | Rule |
|---|---|---|---|
| VCF | 2 | `KN CO` | Flat, reliable points: the safe filler. |
| Overdrive | 3 | `CO TU` / `TU ··` | More points the closer it is to OUT. |
| Phaser | 3 | `CH KN` / `CO ··` | Bonus if neither cable neighbour is a shaper or effect. |
| Reverb | 3 | `TU CO` / `CO ··` | Bonus if it's the last module before OUT. (It competes with Overdrive.) |
| Bitcrusher | 3 | `CH JK CH` | High base score, −1 for every other shaper on the cable. |
| Wavefolder | 4 | `TU KN` / `CO JK` | Bonus for every different module type earlier on the cable. |
| Comb Filter | 4 | `TU CO ··` / `·· CO JK` | Points for every built module in its row. |
| VCA | 4 | `JK ··` / `KN TU` / `JK ··` | 0 on its own; a big score if it touches both an Envelope and an LFO. |
| Delay | 5 | `CH TU ··` / `·· CH JK` / `·· ·· KN` | Re-triggers the *finished* score of the module just before it on the cable (never another Delay). |

### Off the cable

| Module | Finish | Parts | Pattern | Rule |
|---|---|---|---|---|
| Random Generator | Aluminum | 2 | `CH CH` | +1 to +8 for empty neighbours (all 8 count). |
| LFO | Aluminum | 3 | `KN JK` / `CH ··` | Points for each orthogonally adjacent patched module. |
| Envelope | Aluminum | 3 | `JK KN` / `KN ··` | Points for each diagonally adjacent patched module. |
| Sample & Hold | Aluminum | 4 | `JK ··` / `CH KN` / `JK ··` | Scales with how many unique module types surround it. |
| Oscilloscope | Terracotta | 2 | `TU JK` | +1 for each patched module next to it. Its screen shows that signal. |
| Clock | Terracotta | 3 | `KN CH JK` | +1 for every modulator anywhere in the rack. |
| Quantizer | Terracotta | 4 | `CH ··` / `KN ··` / `CH JK` | Points for every module in its column. |

**"Modules with knobs".** Some rules refer to modules with knobs. That means modules on the cable. Off-cable modules don't count as having knobs.

**Pattern sizes** were set by how big a rule's payoff can get against how hard it is to set up. Shape choices:

- Corners suit Reverb and Overdrive, which both want the cramped last cell before OUT.
- Delay's staircase works against an edge.
- Bitcrusher's straight line is the hardest 3-part shape to place.
- VCA's T keeps the tube away from the jacks.
- Wavefolder's square puts both banned pairs (below) on diagonals.

### Saved for later

- Sub-Oscillator and Noise Generator: possible daily source types, or extra sources.
- Chorus, Frequency Shifter, Crossfader, Router: the last two make more sense once there are multiple sources.
- Function Generator: links to modules with knobs; its parts are tentatively a knob, a jack and a chip.
- Sequencer.

## Pattern rules

- **No duplicates.** No two patterns may match in any rotation or mirror image.
- **No hidden patterns.** No smaller pattern may fit inside a larger one with matching parts. Otherwise one placement completes two modules and building becomes ambiguous.
- **Banned neighbours.** The three dominoes mean these pairs must never sit next to each other inside a larger pattern: knob next to coil (VCF), chip next to chip (Random Generator), tube next to jack (Oscilloscope).
- **Checker.** `reference/check_patterns.py` checks every pair. It currently reports no duplicates or hidden patterns, and part totals of 8/11/13/8/12. Port it to Dart as a unit test before changing any pattern.
- **Off-cable shapes** can be bulkier (T, square). On-cable shapes should be compact and extend in one direction, because cable cells next to edges and jacks have fewer open neighbours.

## Cable routes and the daily generator

**Route constraints, version 1:**

- Both jacks sit on board edges, and they're never next to each other.
- The cable is 4–6 cells long, with at least one bend. A straight route on a 5-wide board is only 3 cells, so it's tutorial-only.
- The cable never runs more than two cells along an edge.
- No cable cell is completely surrounded by other cable cells or jacks.
- A "boxed-in" variant with OUT in the middle of the board could be a hard day later.

**Sample routes** (from the route sketches). "Touching" counts cells next to the cable (the modulator zone). "Far" counts cells two or more steps away (the utility zone).

| Route | Cable cells | Touching | Far |
|---|---|---|---|
| Straight across | 3 | 6 | 14 |
| One step | 4 | 6 | 13 |
| Corner | 5 | 9 | 9 |
| S-curve | 5 | 8 | 10 |
| Hook (both jacks on one edge) | 5 | 8 | 10 |
| Long run (from a corner jack) | 6 | 9 | 8 |
| Boxed-in OUT | 5 | 6 | 12 |

The shape of the route is the main difficulty dial, alongside the module lineup.

**Daily content.** Each day is generated ahead of time and inserted into the page, the same way Train Tracks does it:

- **Seeded part order:** 30–40 parts long. Building clears cells, so a game runs longer than 23 turns. Keep each part type's count balanced, and don't let one type clump.
- **Lineup:** about 7–8 modules, with a mix of on-cable, modulator and utility modules.
- **Lineup feasibility.** VCA needs an Envelope and an LFO in the same lineup. Clock needs modulators.
- **Screening.** Reject days with unbuildable lineups, clumped part orders or degenerate routes.
- **Variety.** With 3–4 options in each of 4 categories, there are 81–256 lineup combinations, and route shape and part order multiply that. One year of dailies is easily covered.

## Art direction

**Overall.** Tactile skeuomorphism: a heavy, physical instrument, not a flat diagram. Think Teenage Engineering meets 1970s Bell Labs and studio modular hardware. Every knob, screw and switch casts a soft drop shadow.

**Cabinet:**

- An open walnut case with visible wood grain and a satin sheen. The interior is a dark recessed cavity.
- Each row of the board hangs on its own pair of horizontal **slotted aluminum rails**, one at the top and one at the bottom. Panels screw into the rails. An empty slot shows the rails and the dark cavity between them.

**Column cues (no drawn grid lines):**

- **Index rail.** A brushed rail runs across the top of the case, with **01–05** etched above each column and small notches at the column edges.
- **Screw holes.** Each column has a cluster of four recessed screw holes on every mounting rail.
- **Power strips.** Five subtle vertical power-bus strips run down the dark backplate, one per column. Each has a small connector header at every row.

**Faceplates:**

- Bevelled edges, fine powder-coat grain or horizontal brushed streaks, and four corner screws with drop shadows.
- Colour meanings are strict: sage for the fixed jacks, black for on-cable modules, brushed aluminum for modulators, terracotta for utilities.
- Sage was chosen for the jacks because cream and brushed aluminum looked alike under warm light. Terracotta clashes with the red cords and the walnut, so it's kept for utilities, which never take a cord.
- Amber/mustard is avoided because the amber LED already means "on the cable."

**Controls:**

- **Knobs:** knurled black bakelite with an aluminum center cap, a white pointer line, and tick marks printed on the panel.
- **Jacks:** recessed hex nuts.
- **Faders** (Envelope): chunky black caps with a white index line.
- **LED:** an amber glow when the module is patched or touching the cable, a dark amber dot otherwise.

**Raw parts** sit physically on a proto-board screwed into the cavity:

- **Tube:** a glass envelope with a glowing filament, in a ceramic socket.
- **Knob:** a loose knurled knob.
- **Jack:** a hex nut with solder lugs.
- **Coil:** a copper winding on a bobbin.
- **Chip:** a black package with 16 silver pins and a notch.

**Cables.** Thick, glossy red patch cords with plugs and a natural sag, casting a soft shadow on the panels below. The cable has three states:

- **Loose:** at the start, the whole route is a matte cord lying in the cavity, under the panels.
- **Patched:** glossy and plugged in at both ends.
- **Blocked:** a raw part sits on the cable cell.

Cords plug into the panel face and drape wherever they need to go, so one jack position works for every route direction. Vertical runs sag downward between rows.

**Screens:**

- Green phosphor CRT text with a glow, scanlines and a glass sheen.
- Used for the score bar, the timer and scope displays.
- The result screen has a large scope showing a wireframe waveform plot of the finished patch, which animates when the patch plays.

**Typography:**

- **Jost** (Google Fonts, open licence, Futura-style) for engraved panel lettering: tracked capitals in weights 500–600. On dark panels it's light with an incised shadow; on light panels it's dark with a highlight. Use it for labels, buttons and headings.
- **VT323** (Google Fonts, open licence) for phosphor screens only.
- A true Gorton look would need an openly licensed Gorton revival, or hand lettering.

**Buttons.** Physical keys with travel: a dark key for Undo, a cream key for Build and Play Patch, and a recessed, disabled Play until the patch is complete.

**Game screen layout,** top to bottom:

1. Phosphor score bar (patch number, timer, score).
2. Brushed-aluminum title plate ("RACK & RESONANCE · DAILY PATCH No. 0142 · NOV 21").
3. Parts bin with three cards: recessed trays, each holding a part on its proto-board, with an amber border on the selected card.
4. The cabinet.
5. A status line ("CABLE · 3 OF 5 SLOTS BUILT · 1 PART BLOCKING").
6. Undo, Build and Play keys.

**Blueprints (not yet mocked up).** The day's module patterns go in a strip of **cyanotype blueprint cards** (white lines on blue) between the parts bin and the cabinet. Tapping a card opens a bottom sheet with its pattern and rule. When a pattern is complete, the matching cells glow and that card lights up.

**Palette (starting values):**

| Use | Hex |
|---|---|
| Walnut case | `#5c381e` |
| Black faceplate | `#2b2b29` → `#121211` |
| Brushed aluminum | `#eeece7` → `#94908a` |
| Sage faceplate | `#a4ae84` → `#6f7a50` |
| Terracotta faceplate (not drawn yet) | try `#b5603a` |
| Rail aluminum | `#e6e3dc` → `#67635c` |
| Cavity | `#25190f` → `#070403` |
| Patch cord | `#c7311d` (shadow `#3e0c05`, highlight `#ffb3a1`) |
| LED amber | `#ffb13b` |
| Phosphor | `#86f7a0` on `#0f2a17` → `#030904` |
| Page background | `#121110` |

**Keeping it original (IP):**

- No real brand names, module names or product names.
- Don't recreate any one instrument's signature: no curved cabinet sides, no copied panel layouts, no copied printed signal-flow graphics, no copied CRT menu text.
- Wireframe waveform plots and walnut-and-black panels are generic and fine to use.

## Architecture plan

Everything is in Dart, as one pure engine shared by the generator and the page, so the scoring rules can't drift apart between them.

```
tools/rack/
  HANDOFF.md            this file
  engine/               pure Dart package: board, parts, patterns (rotations and mirror images),
                        matching, building, cable state, scoring, game-over
    test/               pattern checker (port of reference/check_patterns.py), rule tests
  bin/                  generator CLI: seeded routes, lineups and part orders, screening, pregen
  page/                 template.html (HTML/SVG art and layout) plus Dart compiled with dart compile js
  build.sh              like tools/tracks/build.sh: pregen, then insert the data, then write web/rack/index.html
  reference/            design references (below)
web/rack/index.html     built page; Flutter's web build copies it to /rack/
```

- **The page** is a thin HTML/SVG front end, matching the mockups, with the game logic compiled from Dart to JavaScript. Audio uses the browser's Web Audio API through `package:web` and `dart:js_interop`.
- **Not a Flutter screen.** The layered textures and shadows would need redrawing in Flutter's own painting system. That can come later if the game joins the app's game list.
- **Deploy** works exactly like Train Tracks: commit to the fork, bump `PUZZLE_REF` and the tag in `puzzle-docker`, then set `PUZZLE_TAG` on zuul and pull.
- **Local setup.** Plain Dart SDK only: a download of about 190 MB, plan on about 1 GB free. No Flutter is needed locally, because the Docker build handles it.

## Suggested first steps

1. Set up the `tools/rack/engine` package: board model, part types, and pattern orientation and matching. Port `check_patterns.py` as a test and make it pass.
2. Implement building, cable state (patched or blocked), the 16 module rules and the scoring sketch, using placeholder numbers. Give each rule its own test.
3. Add a text-mode game runner in `bin/` for fast playtesting, alongside paper playtests.
4. Write the generator: routes under the constraints, lineups with feasibility checks, balanced seeded part orders, screening, and a year of pregenerated days.
5. Build the page from the mockups. Start with the cabinet, parts bin and status line, then the blueprint strip, the result screen and Web Audio.
6. Polish: share text, dark mode (already dark), tutorial, and the credit line. Then playtest and ship through the usual pipeline.

## Open questions

- What does an incomplete patch play: silence, a crackle, or whatever it has?
- Exact point values for base scores, bonuses and caps (to be set in playtests).
- Exact daily lineup size (7 or 8) and the mix of categories.
- Terracotta utility art, and the Oscilloscope's off-cable screen (it isn't drawn yet).
- How the generator handles the end of the cable, where Overdrive, Reverb and Delay all want the last cell before OUT. Check on paper that a lineup with all three doesn't feel impossible.

## Reference files

| Path | What |
|---|---|
| `reference/check_patterns.py` | Prototype pattern checker plus part counts (Python). Port to Dart. |
| `reference/art/*.svg` | Module and part art exported from the mockup at 4× (open in a browser; needs the Jost font). `shaper-scope-OUTDATED.svg` is the old on-cable scope. The Oscilloscope is now an off-cable terracotta utility. |
| `reference/mockups/*.dc.html` | Source of the design canvas artboards (game screen, result screen, module sheet, route sketches, printable routes). They render inside the claude.ai design canvas, not on their own, but the SVG and CSS in them are the art spec. |
