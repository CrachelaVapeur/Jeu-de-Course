# Playtest list

Things to try by hand in the game. Each Claude adds a line when its change
can be felt; the person who plays writes the result. Remove a line once it
is validated and its result is recorded in the GDD or a session report.

Controls: Z / ↑ accelerate, S / ↓ brake, Q D / ← → steer, Shift boost,
Space drift, R restart, C change view (gamepad: Y).

| # | Scene | What to try | What should happen | Result (who, date) |
|---|-------|-------------|--------------------|--------------------|
| 1 | `circuit_01` (F5) | Hold Shift on a straight | The car pushes at once up to about 525 km/h (75% of the original boost); the screen effects are clearly there but you can still see the road | |
| 2 | `circuit_01` | Release Shift during a boost | The boost stops quickly and the speed drops back to about 306 km/h (the new top speed) | |
| 3 | `circuit_01` | Above 100 km/h, tap Space (or lift off the throttle) in a turn, then steer | The rear slides, smoke comes from the rear wheels, steering adjusts the arc without jumping from one side to the other | |
| 4 | `circuit_01` | Drive the whole circuit (about 14.5 km) | Road wide enough everywhere, open tunnel entrance, no rock or block on the road | |
| 5 | `circuit_01` | Hit walls hard, drive into the monster in the crater | The car never ends up under the road; if it gets stuck, it reappears on the road within 2 s | |
| 6 | `circuit_01` | Look at the cities and the pyramid | Cities far from the road, hazy silhouettes, lit floors as soft lines, no flicker | |
| 7 | `circuit_01` | Drive past both cities, look far away | Blade Runner haze: distant hills and cities melt into a thick grey-blue haze, each city has a glow above it (warm for city 1, cold for city 2); the road ahead stays easy to read, even with the boost | |
| 8 | `circuit_01` | Look at the pyramid for a few seconds | Its 4 light beams slowly sweep the sky by a few degrees, each at its own pace (they never spin like the lighthouse) | |
| 9 | `circuit_01` | Watch the frame rate (in the Godot editor: Debugger panel, Monitors tab, FPS) | No drop compared with before: the haze uses no volumetric fog | |
| 10 | `circuit_01` | Start the race | You start underground, with a wall behind you; the road climbs inside the tunnel for about 1.8 km, up to the hairpin | |
| 11 | `circuit_01` | Leave the tunnel and keep going | A short canyon, then a steep drop of about 120 m with city 1 and the pyramid below you | |
| 12 | `circuit_01` | In the 5 half-pipe turns (tunnel hairpin, the big S after the drop, the plateau, city 2 twice), keep full throttle at 306 km/h and let go of the steering | The road becomes a U with a much higher outer wall (14 m). The car stays glued to it, climbs higher the faster it goes, and the wall turns it: it gets through without losing speed | |
| 13 | `circuit_01` | After the bridge | A long climb up to 200 m, a plateau with banked turns, a jump over a crevasse, then a steep drop into the crater | |
| 14 | `circuit_01` | Watch the road surface under the lights, in turns too | One smooth ribbon: turns are round (not polygons), the asphalt is one grey (no lighter or darker slabs) | |
| 15 | `circuit_01` | Take a half-pipe in boost, then slowly (about 150 km/h) | In boost the car rides the very top and slides along it without being thrown out; slowly it stays near the bottom | |
| 16 | `circuit_01` | Drive a half-pipe with the chase camera | The camera leans with the car on the wall; the wall looks SF (dark metal, neon lines, arrows running forward) | |
| 17 | `circuit_01` | Full throttle on a long straight, no boost | Top speed about 306 km/h | |
| 18 | `circuit_01` | Stop, keep holding the brake | The car backs up slowly (about 50 km/h at most); accelerating stops it first, then drives forward | |
| 19 | `circuit_01` | Press C (gamepad Y) while driving, three times | Cockpit view (driver's seat), then hood view (on the nose, the car is hidden), then back to the chase camera; both follow slopes and the half-pipe walls | |

Note: the boost gauge is hidden and the boost is infinite for now (car
testing phase, `boost_infini` on the Vehicule node).
