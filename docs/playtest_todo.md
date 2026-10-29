# Playtest list

Things to try by hand in the game. Each Claude adds a line when its change
can be felt; the person who plays writes the result. Remove a line once it
is validated and its result is recorded in the GDD or a session report.

Controls: W / ↑ accelerate, S / ↓ brake, A D / ← → steer, Shift boost,
Space drift, R restart, C change view, Esc back to the menu (gamepad: Y).

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
| 20 | start screen (F5) | Launch the game | A menu opens with Circuit 1, Test circuit, Speed test, Settings and Quit; each race button loads its scene (keyboard Enter, mouse, touch, or the gamepad's bottom face button; the right one goes back); "Main menu" in the pause menu comes back to it. On Android there is no Quit button (leave with Home) | |
| 21 | start screen > Settings | Choose Low, start Circuit 1, compare with High | Low: lower 3D resolution, no shadows, no glow, no speed lines or tunnel vision; frame rate clearly higher on a weak laptop. High looks like before. Settings are remembered after restarting | |
| 22 | start screen > Settings | Tick "Show FPS counter", start a race | A green FPS number shows at the top left, the controls guide moves just under it | |
| 23 | any race | Read the controls guide and the lap timer | Everything is in English | |
| 24 | any race | Look at the top-left corner, press the buttons, switch between keyboard and gamepad | A controls guide in two columns (left hand / right hand): gamepad buttons with Xbox colours (Nintendo names on a Nintendo pad), or keycaps for the keyboard; each button lights up while held; it switches when you touch the other device and fades after a minute. Settings > "Controls guide" turns it off | |
| 25 | `circuit_01` | Drive the climbs and crests at full speed, watch the wheels | The car stays on the road instead of floating a few centimetres above it (it used to hop off the ground about a third of the time on climbs); steering feels firmer on climbs. Real jumps still fly | |
| 26 | `circuit_01` | Full throttle, no boost, up the long climb to the crevasse jump (about 8.4 km) | Check you still clear the crevasse: the car now loses the climb's full speed (the hops used to hide part of it), and the test autopilot sometimes fell short at about 270 km/h. If it is too hard, `effet_pente` or the climb need a team decision | |
| 27 | any circuit, Settings > "Slide handling (test)" ON | At speed, push the stick fully to one side without any button, then boost while sliding | The rear lets go by itself and the car slides at about 40° without losing speed; boosting pulls the car toward where its nose points and plants it again, so you can aim and boost out of the slide. OFF = the original handling | |
| 28 | `circuit_01` | Chase camera on the tunnel climb, over crests, and down the steep drop into the crater (about 8.7 km) | The camera tilts with the road (a little late, smoothly): uphill it stays above the car and looks up the road instead of into the hill; on the drop it rises behind and looks down the descent instead of sinking into the crest. It never goes under the road or through the tunnel ceiling | |
| 29 | any race | Gamepad D-pad (keyboard 1 to 4) | Up: far chase (higher, further back), Right: near chase (the usual one), Left: cockpit, Down: hood. Y / C still cycles: near, far, cockpit, hood. The view you pick is kept for the next race | |
| 30 | any race | Look at the controls guide | A "Views" line with a D-pad icon (keyboard: 1-4); the pressed arrow lights up | |
| 31 | any race | Press Start (keyboard Esc) | The game freezes under a dark "PAUSED" menu: Resume, Restart, Handling, Controls guide, Main menu. Start, Esc or B close it. Restart puts you back at the start with the timer reset (keyboard R still restarts directly) | |
| 32 | any race, pause menu | Switch "Handling" between Classic and Slide, resume and drive | The change works at once, without restarting the race, and is remembered (same setting as Settings > Slide handling in the start screen) | |
| 33 | `circuit_01` or the test circuit | Press Select (keyboard M) while driving, then again | A map of the whole track opens over the race (which keeps going): the start line in cyan, your car as a yellow arrow pointing where you go. The speed test says it has no map | |
| 34 | AYN Thor | Leave the game with Home, then tap its icon again; also start a race and come back to the start screen | The game always opens again from its icon (the old Quit button killed it and the Thor launcher could not reopen it) | |
| 35 | start screen > Settings > "Controller buttons" (also in the pause menu) | Try Auto, Xbox, Nintendo, PlayStation, then start a race | The controls guide, the pause menu text, the map and the start screen help name the buttons of the chosen pad (Nintendo: B / A / Y / X, ZL / ZR, L / R, + / − in Super Nintendo colours; PlayStation: drawn ✕ ○ □ △, L1 / R1, L2 / R2). Auto guesses from the pad's name (Xbox if unknown). The controls never move: the bottom button always confirms and boosts, the right one goes back | |
| 36 | any race | Boost on a straight, watch the car (chase view, then a side view if you can) | Redline-style: the car stretches backwards (about 35 % longer, a little thinner) while the boost builds, nose staying in place and wheels on the road, then snaps back when the boost ends. Cockpit and hood views stay steady. `etirement_boost` = 0 on the Vehicule turns it off | |
| 37 | AYN Thor (or any gamepad) | In the start screen, move with the D-pad / stick and press the bottom face button; in Settings or the pause menu press the right face button | The bottom button confirms (A Xbox, B Nintendo, ✕ PlayStation), the right one goes back / closes the pause menu. (Godot gives no gamepad button to its menus by default; before this fix nothing confirmed on the Thor) | |
| 38 | start screen > Settings > "Text size" (also in the pause menu) | Try Normal, Large, Extra large, on the PC and on the Thor | All menus and the HUD grow; the Thor starts on Large, the PC on Normal. The settings and the pause menu scroll if they no longer fit; the controls guide grows less than the rest so it does not hide the road. At the usual 1600×900 window, Normal looks exactly as before | |

Note: the boost gauge is hidden and the boost is infinite for now (car
testing phase, `boost_infini` on the Vehicule node).
