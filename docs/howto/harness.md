# How to: measure first, then tune (headless harness)

Rule: when a question is "does the car reach it / stay on the road / clear the
jump", do not tune by guessing and waiting for someone to play. Measure it
first with a throwaway script, then change the code, then measure again.
A human still decides whether it is *fun*; the harness only proves the numbers.

## Good questions for REV LINE
- Does the car clear the crevasse jump (about 8.4 km) at full throttle without
  boost? At what speed does it arrive?
- Does the car stay on the road on climbs and crests (wheels on the ground)?
- Does a half-pipe keep the car inside at 150 km/h, 306 km/h and in boost?
- Does the car ever end up under the road after a hard wall hit?

## The pattern
1. Write a script in `outils/_tmp/` (extends `SceneTree`). Run it with:
   `"$GODOT" --headless --path . --script res://outils/_tmp/essai.gd`
   (on Windows `$GODOT` is the "console" build of Godot 4.7).
2. Load the circuit scene, drive the car with a simple "bot" (full throttle,
   fixed steering), step the physics for a fixed number of frames, and print
   one line per run: the result and **why** it failed (speed too low at the
   edge, left the road, stuck under the road...).
3. Run several bots and several starting conditions (still, full throttle,
   boost, slow), not one lucky run.
4. **Before changing any code**, write the acceptance numbers in the pull
   request (example: "clears the crevasse in 9 runs out of 10 at full
   throttle"). Run the harness on the current code to get the baseline.
5. Change the code, run again, report before and after.
6. Delete `outils/_tmp/`. Do not commit the harness. Then ask a human to
   feel it and add a line to `docs/playtest_todo.md`.

## Traps
- A new `class_name` is invisible until `--import` has run once.
- A parse error in a script the harness uses can make a `while` loop spin
  forever. Always cap the number of frames, and run the scene once first and
  look for `SCRIPT ERROR`.
- Keep a harness under about 2 minutes; run long ones in the background.
- A bot that only goes straight can hide geometry problems: add one that
  steers back to the middle.
- Check the setup before trusting the numbers (a forgotten object in the
  scene once looked like a bug).
- Tuning numbers agreed with the team (speeds, boost) are inputs to measure,
  not things to change silently.
