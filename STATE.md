# STATE: where the project stands

Read this right after `CLAUDE.md`. It is the memory that survives clearing a
chat, shared by the Claudes of Eric, Willy and Maximo. Keep it SHORT (about
90 lines). Details live in `docs/`; the GDD stays the reference for design.

**How to keep it true (draft, needs the team's agreement):**
- At the end of every task, update the section that concerns your change.
- Three people edit this file, so: change only your own line in
  "In progress" and the lines your pull request really touches. Merge
  `main` before opening the pull request and read the diff (Git rule 3).
- Do not copy the playtest list here: it stays in `docs/playtest_todo.md`.

Last updated: 2026-10-30 (after PR #14, start menu and pause menu).

## Where we are
- Game: arcade 3D racing game, **Godot 4.7**, GDScript (names and comments
  in French).
- Playable scenes: `scenes/circuit_01.tscn` (the real circuit, about
  14.5 km), `scenes/circuit_essai.tscn` (small test circuit),
  `scenes/main.tscn` (endless straight, speed test). The start screen is
  `scenes/menu_principal.tscn`.
- Built and working: driving with drift and boost, Circuit 1 (underground
  start, canyon, drop, bridge, climb, plateau, crevasse jump, crater),
  half-pipe turns, haze and city glows, 4 camera views, start menu,
  graphics settings (Low / High), pause menu, track map, controls guide,
  controller button styles, text size, English in-game text.
- Experiments that exist but are NOT decided: "Slide handling (test)"
  (`conduite_glisse`), boost stretch (`etirement_boost`), `effet_pente` 0.5.

## To-do / pending (top first)
1. The team plays `docs/playtest_todo.md` (38 lines, no result yet) and
   decides on the experiments above.
2. Check the crevasse jump (about 8.4 km) at full throttle without boost:
   after the "car stays on the road" fix it loses more speed on the climb.
3. Real boost gauge: the gauge is hidden and the boost is infinite
   (`boost_infini` on the Vehicule) while the cars are being tested.
4. Not built (see the GDD for the full list): more circuits, opponents,
   race rules (laps, positions), real cars and art, sound and music.

## In progress (one line per person, remove when merged)
- Eric: (write your branch and what is left)
- Willy: (write your branch and what is left)
- Maximo: nothing open. Next branch starts from `main` at `b0570d9`.

## Tuning values agreed with the team (do not change silently)
- Top speed about 306 km/h (`vitesse_max` 85), boost about 525 km/h
  (75% of the original boost), reverse gear at most about 50 km/h.
- Everything else tunable is an `@export` on the Vehicule, the camera or the
  circuit data file in `circuits/`.

## Where things are
| What | Where |
|---|---|
| Rules | `CLAUDE.md`, `CONVENTIONS.md` |
| Game design (GDD, ideas, session reports) | Google Drive « Projet jeu Eric & Willy » |
| What to test by hand | `docs/playtest_todo.md` |
| Recipes (how to do X) | `docs/howto/` |
| The check before every pull request | `outils/verifier.sh` / `outils\verifier.ps1` |
| Circuit data and relief | `circuits/` (`circuit_01.gd`, `circuit_01_relief.png`) |
| Driving | `scripts/vehicule.gd` |

## How-to cards (`docs/howto/`)
- `harness.md`: measure a "does it reach / does it stay on the road" question
  with a throwaway headless script before tuning it.

## Gotchas that cost time before
- Open the project only with Godot 4.7: another version rewrites files.
- Commit the `.uid` files Godot creates next to scripts.
- A branch older than `main` makes Git show other people's changes as
  "removed": read your pull request diff before asking to merge.
- The check on Windows needs the "console" build of Godot in `GODOT`.
