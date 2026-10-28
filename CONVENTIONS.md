# Conventions

How the code and the project are organised. Short on purpose; add a rule
only when the team agrees.

## Godot

- **Godot 4.7** for everyone (Forward+ renderer). Do not open the project
  with another version: it rewrites files.
- **Commit the `.uid` files** that Godot creates next to scripts and shaders
  (`*.gd.uid`, `*.gdshader.uid`). Without them, other people's projects show
  broken links.
- Never commit the `.godot/` folder (it is in `.gitignore`).
- Edit scenes (`.tscn`) in the Godot editor when possible. When a scene must
  be edited as text, change only the lines needed.

## Code

- GDScript with **static types** (`var vitesse: float`, `func f() -> void`).
  When Godot cannot guess a type (values read from a Dictionary, for
  example), write it explicitly.
- Names and comments in **French**, like the existing code, with `##`
  comments on exported settings so they show up in the Inspector.
- Keep files readable: split a file that grows past roughly 600 lines.
- **Tuning numbers live in one place:** `@export` settings on nodes (car,
  camera, circuit) or the circuit data files in `circuits/`. Do not scatter
  magic numbers in the code.

## Project layout

- `scenes/`: playable scenes. `main.tscn` is the endless test straight,
  `circuit_essai.tscn` the small test circuit, `circuit_01.tscn` the first
  real circuit (run with F5).
- `scripts/`: game code. `vehicule.gd` (driving, boost, drift),
  `circuit_trace.gd` (builds a circuit from a data file), and the scripts it
  uses (`villes.gd`, `cratere.gd`, `reperes.gd`, `terrain_carte.gd`…).
- `circuits/`: one data file per circuit (track points, obstacles, colours by
  zone), plus its relief map.
- `shaders/`, `models/`, `textures/`: visuals.
- `outils/`: tools (the check script, map-reading scripts).
- `docs/`: screenshots, reference images and `playtest_todo.md`.
