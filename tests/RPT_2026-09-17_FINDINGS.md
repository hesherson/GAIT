# GAIT slope investigation: recorded findings

Evidence: `Arma3_x64_2026-09-17_01-23-11.rpt`, Arma 3
2.22.154049 profiling, GAIT 1.7.0-rc3, ACE 3.21.2.113, Stratis.
Times below are `diag_tickTime` seconds. Grades are directional, signed angles;
surface steepness and GAIT's smoothed display are separate measurements.

## What the recording establishes

The decoded RPT contains 2,953 samples in run 1, 1,102 in run 2 and 2,560 in
run 3. All emitted chunks decoded without errors or incomplete chunk groups.
This does not mean every preview was captured completely: run 1 reached the
6,000-line recording limit after approximately 31 seconds, despite requesting
90 seconds. Only run 1 completed its configuration flush. Runs 2 and 3 have
no capture END marker.

The normal GAIT run loses its custom animation well before 32 degrees:

| Tick | Observed state | Facing grade | Terrain sample grade |
| --- | --- | --- | --- |
| 104.407 | Custom forward sprint | -13.13° | -12.30° |
| 105.579 | Native standing idle | -15.19° | — |
| 105.831 | Native forward sprint | — | — |
| 106.131 | GAIT entry-failure latch set | — | — |
| 115.381 | Native jog changes to walk | +31.03° | +30.72° |
| 121.242 | Sustained native walk | +33.02° | +33.18° |

W and Turbo remained held through the early custom-to-idle escape. Ground
contact and GAIT movement eligibility remain true throughout run 1. These
samples do not implicate either guard. Sprint/walk restriction flags are clear
at the recorded jog-to-walk transition; an ACE restriction appears in the next
sample. The observations do not establish an exact negative-32-degree cutoff.

The isolated custom trial also escapes before that boundary. In the successful
single-player trial, the custom sprint appears at 372.681, facing -11.16°, then
native idle at 373.152, facing -13.41°, approximately 0.471 seconds later.
GAIT's controller and ACE Advanced Fatigue are disabled for this trial. The
trial issues one entry request and no native exit command. This reproduces the
escape independently of GAIT's normal controller.

However, native stamina remains enabled: at the idle transition, stamina is
already 0.322 and fatigue 0.740. Native sprint resumes at 373.404, followed by
exhausted native jogging at 373.806. Later stamina reaches zero and fatigue
one. Consequently, the later walk transition near a +31.63° sampled grade
does not isolate terrain from exhaustion. The earlier multiplayer trial was
refused; no native comparison trial ran.

The configuration dump confirms that native and custom forward sprint use
the same real sprint RTM, `amovpercmsprslowwrfldf.rtm`, and the same configured
speed, 1.60971. That configuration speed is not a measured speed in metres
per second.

## Confirmed integration defect and next experiment

The RPT rejects GAIT's attempted replacement of ACE's final `handleEffects`
function. GAIT nevertheless marks its bridge installed. Run 1 records 22 ACE
sprint-block pulses, recurring every 0.999–1.011 seconds and lasting
0.056–0.484 seconds, mean 0.195 seconds. The first begins at 107.355 near
-20.12°; native jogging follows in the next frame.

The integration correction uses ACE's public status event after ACE's own
handlers, clearing only the Advanced Fatigue source while preserving other
restriction owners. It does not preemptively veto status requests.

Animate Rewrite is also loaded. A competing animation-speed writer remains
possible, but its involvement in the graph escape is unproven. The graph's
escape is not fixed or explained by repairing the ACE bridge. The next focused
experiment requests one `switchMove` from Draw3D to test command timing, with
stamina controlled and entry events recorded. No evidence yet demonstrates
that a DLL or private engine hook is necessary.
