# GAIT movement comparison

Use alpha52 with the existing CBA, ACE and animation preset. The local build is
F:\GAIT\.hemttout\build. Copy foundation_capture.sqf and comparison_run.sqf
beside mission.sqm in a saved test mission.

## Local runs

Choose flat, open ground and keep the route and character constant. Prepare
light, medium and heavy kits near 20, 60 and 110 lb. The recorder writes the
actual carried weight, so comparison uses the measured load.

For each kit, use the same straight level lane and weapon pose. Start each run
standing still at full reserve. Run these separately, resting and returning
to the start between trials.

```sqf
["20 lb rifle", serverTime + 10, "ordinary"] execVM "comparison_run.sqf";
["20 lb rifle", serverTime + 10, "burst"] execVM "comparison_run.sqf";
```

Use the kit's label for each pair. Follow the cue and run straight for the full
18 seconds. Run `python tools/report_capture.py "<RPT path>" --output comparison.json`
to see elapsed time and reserve spent at 10 m and 30 m. Distances are horizontal
displacement from the start. Marker times interpolate between position samples.
The report identifies the observed burst and distinguishes incomplete trials.
The ordinary interruption sequence below also measures A/D reversal to lateral
motion and crouch input to a moving crouch at the recorder's frame resolution.

For each kit, begin with full reserve and repeat the same route with rifle
raised, rifle lowered, combat pace, pistol, launcher and unarmed. Walking and
combat pace keep their selected native poses. The sprint and ordinary jog
targets compensate for different weapon strides.

Run this using local execution in the pause-menu debug console, then close
the menu. The capture and instructions start after ten seconds.

```sqf
["light rifle raised", serverTime + 10] execVM "comparison_run.sqf";
```

The script gives cues for sprint from idle, Shift release, A/D reversals,
sprint from a jog, Ctrl during release, crouch, ADS, weapon switching and a
full stop. Supply the keyboard inputs at each cue. Repeat on an incline and
descent after the flat-ground comparisons.

Check that the rifle pose stays consistent, the legs follow the torso, the
final walking cadence looks natural and fresh movement works after a full
stop. Compare actual movement speed between weapon poses at matched load,
reserve, grade and phase.

Stop early with these local commands.

```sqf
GAIT_comparisonRunning = false;
GAIT_foundationCaptureEnabled = false;
```

## Multiplayer run

Use the same mod versions on the server and all three clients. Give one
player each kit and use adjacent lanes on the same open route. Match weapon
pose and reserve, with one player watching the others during a separate
observer pass.

Copy both scripts into the multiplayer test mission. Pick a future serverTime
and pass that same numeric start time on all three clients. For example,
when the shared serverTime is near 1000, use 1020.

```sqf
["flat rifle raised", 1020] execVM "comparison_run.sqf";
```

Each client captures its own input and movement. The network fields include
serverTime, client owner, unit net ID and position for matching the three
RPTs. Confirm how stride, stance and weapon transitions appear to the other
clients, then repeat with kit assignments swapped.

## Report captures

```powershell
python F:\GAIT\tools\report_capture.py 'C:\path\first.rpt' 'C:\path\second.rpt' 'C:\path\third.rpt' --output F:\GAIT\.hemttout\comparison.json
```

The report lists contiguous pace windows with similar grade, reserve, load
and animation, plus periods of commanded movement with near-zero speed.
Collision, brace timing and legitimate actions can also cause a low-speed
period. Confirm flagged periods in-game before attributing a cause.
Historical captures without the new raw-action fields remain readable.
