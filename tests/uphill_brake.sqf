// Run after fn_uphillBrake.sqf and fn_traversalHelpers.sqf in SQF-VM or Arma.
private _checks = 0;
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
    _checks = _checks + 1;
};

{
    private _curve = [_x, 1.2, 0.8] call GAIT_fnc_uphillBrakeParameters;
    [(_curve select 0) isEqualTo 0 && {(_curve select 1) isEqualTo 0}, "flat, shallow and downhill grades do not brake"] call _assert;
    [(_curve select 2) isEqualTo 1.2, "no-brake output preserves coefficient"] call _assert;
} forEach [-90, -35, -18, 0, 5, 14.999, 15];

private _previousFactor = 0;
private _previousDuration = 0;
private _previousRamp = 0;
private _previousTarget = 2;
for "_degree" from 15 to 50 step 0.5 do {
    private _curve = [_degree, 1.2, 0.8] call GAIT_fnc_uphillBrakeParameters;
    [(_curve select 0) >= _previousFactor, "steeper uphill grade never reduces braking severity"] call _assert;
    [(_curve select 1) >= _previousDuration, "steeper uphill grade never shortens braking"] call _assert;
    [(_curve select 2) <= _previousTarget, "steeper uphill grade never raises brake target"] call _assert;
    [(_curve select 3) >= _previousRamp, "steeper uphill grade never slows deceleration response"] call _assert;
    _previousFactor = _curve select 0;
    _previousDuration = _curve select 1;
    _previousTarget = _curve select 2;
    _previousRamp = _curve select 3;
};
private _peak = [35, 1.2, 0.8] call GAIT_fnc_uphillBrakeParameters;
[abs ((_peak select 1) - 0.33) < 0.000001, "full-slope duration keeps existing base and extra duration"] call _assert;
[abs ((_peak select 2) - 0.576) < 0.000001, "full-slope dip is relative to walking or slower current coefficient"] call _assert;
[abs ((_peak select 3) - 0.575) < 0.000001, "full slope uses existing brace response"] call _assert;
private _nearStart = [15.01, 1.2, 0.8] call GAIT_fnc_uphillBrakeParameters;
[(_nearStart select 0) < 0.00001 && {abs ((_nearStart select 3) - 0.05) < 0.00001}, "brake force eases in at onset"] call _assert;
[(_nearStart select 1) < 0.00001 && {abs ((_nearStart select 2) - 1.2) < 0.00001}, "brake duration and target continuously vanish at onset"] call _assert;
private _nearPeak = [34.99, 1.2, 0.8] call GAIT_fnc_uphillBrakeParameters;
[abs ((_nearPeak select 2) - (_peak select 2)) < 0.00001, "brake force joins maximum smoothly"] call _assert;

{
    private _current = _x;
    private _curve = [32, _current, 0.8] call GAIT_fnc_uphillBrakeParameters;
    [(_curve select 2) <= _current && {(_curve select 2) >= 0}, "brake target cannot accelerate slow uphill movement"] call _assert;
    private _next = [_current, _curve select 2, _curve select 3, 0.05] call GAIT_fnc_stepSpeedCoefficient;
    [_next <= _current && {_next >= (_curve select 2)}, "brake ramp decelerates without overshoot"] call _assert;
} forEach [0, 0.01, 0.1, 0.4, 0.8, 1.2, 2];

private _state = [];
private _running = [_state, true, true, true, true, 4, 32, 1.2, 0.8, 10] call GAIT_fnc_stepUphillBrake;
[!(_running select 1) && {!(_running select 2)}, "continuing uphill sprint never brakes"] call _assert;
_state = _running select 0;
private _release = [_state, false, false, true, true, 4, 32, 1.2, 0.8, 10.05] call GAIT_fnc_stepUphillBrake;
[(_release select 1) && {_release select 2} && {(_release select 3) > 0.9}, "actual uphill Shift release starts one strong brake"] call _assert;
private _releaseEnd = (_release select 0) select 3;
private _again = [_release select 0, false, false, true, true, 3, 32, 0.9, 0.8, 10.10] call GAIT_fnc_stepUphillBrake;
[(_again select 1) && {!(_again select 2)} && {((_again select 0) select 3) isEqualTo _releaseEnd}, "holding release does not re-trigger or extend brake"] call _assert;
private _expire = [_again select 0, false, false, true, true, 2, 32, 0.7, 0.8, 11] call GAIT_fnc_stepUphillBrake;
[!(_expire select 1) && {!(_expire select 2)}, "brake expires without another input edge"] call _assert;

private _forwardRelease = [_state, false, false, false, true, 4, 0, 1.2, 0.8, 10.05] call GAIT_fnc_stepUphillBrake;
[(_forwardRelease select 2) && {abs ((_forwardRelease select 3) - (_release select 3)) < 0.000001}, "W release retains the last uphill travel grade"] call _assert;
private _retap = [_release select 0, true, true, true, true, 3, 32, 0.9, 0.8, 10.10] call GAIT_fnc_stepUphillBrake;
[!(_retap select 1) && {!(_retap select 2)} && {(_retap select 4) isEqualTo 0.9} && {_retap select 8}, "sprint re-tap cancels braking without another slowdown and reports resume"] call _assert;
private _heldAgain = [_retap select 0, true, true, true, true, 3, 32, 0.9, 0.8, 10.15] call GAIT_fnc_stepUphillBrake;
[!(_heldAgain select 8), "resume indication occurs only once on the retap edge"] call _assert;
private _lateRetap = [_release select 0, true, true, true, true, 3, 32, 0.9, 0.8, 11] call GAIT_fnc_stepUphillBrake;
[!(_lateRetap select 8), "expired brake does not claim a fresh resume"] call _assert;

private _loss = [_state, true, false, true, false, 4, 32, 1.2, 0.8, 10.05] call GAIT_fnc_stepUphillBrake;
[!(_loss select 1) && {!(_loss select 2)}, "eligibility loss with keys held cannot trigger brake"] call _assert;
private _laterRelease = [_loss select 0, false, false, true, true, 4, 32, 1.2, 0.8, 10.1] call GAIT_fnc_stepUphillBrake;
[!(_laterRelease select 2), "release after excluded medical/action context cannot masquerade as sprint release"] call _assert;

{
    private _trial = [_state, false, false, true, _x select 0, _x select 1, 32, 1.2, 0.8, 10.05, _x select 2] call GAIT_fnc_stepUphillBrake;
    [!(_trial select 1) && {!(_trial select 2)}, "unsafe context, stationary body or disabled setting prevents braking"] call _assert;
} forEach [[false, 4, true], [true, 0.25, true], [true, 0, true], [true, 4, false]];
private _zeroDuration = [_state, false, false, true, true, 4, 32, 1.2, 0.8, 10.05, true, [15, 35, 0, 0, 0.28, 0.05, 0.575]] call GAIT_fnc_stepUphillBrake;
[!(_zeroDuration select 1) && {!(_zeroDuration select 2)}, "configured zero duration does not arm an animation phase"] call _assert;

{
    private _grade = _x;
    private _baseline = [[], true, true, true, true, 4, _grade, 1.2, 0.8, 1] call GAIT_fnc_stepUphillBrake;
    private _result = [_baseline select 0, false, false, true, true, 4, _grade, 1.2, 0.8, 1.05] call GAIT_fnc_stepUphillBrake;
    [!(_result select 1) && {!(_result select 2)}, "flat/downhill release keeps existing momentum behavior"] call _assert;
} forEach [0, -18, -32, -75];
private _crest = [_state, false, false, true, true, 4, -5, 1.2, 0.8, 10.05] call GAIT_fnc_stepUphillBrake;
[!(_crest select 2), "Shift release after crest uses current downhill grade rather than stale uphill history"] call _assert;
private _slower = [_release select 0, false, false, true, true, 1, 32, 0.1, 0.8, 10.10] call GAIT_fnc_stepUphillBrake;
[(_slower select 4) <= 0.1, "an active brake cannot reverse another legitimate slowdown"] call _assert;

private _flatCoast = [0, 1, 0.85] call GAIT_fnc_uphillBrakeCoastWindow;
[(_flatCoast select 0) isEqualTo 0 && {abs ((_flatCoast select 1) - 1.85) < 0.00001}, "zero severity preserves original full coast"] call _assert;
private _priorRemaining = 2;
for "_severity" from 0 to 1 step 0.01 do {
    private _window = [_severity, 1, 0.85] call GAIT_fnc_uphillBrakeCoastWindow;
    [(_window select 1) <= _priorRemaining, "steeper release monotonically shortens coast"] call _assert;
    [abs (((_window select 0) + (_window select 1)) - 1.85) < 0.00001, "coast age and remainder share one original clock"] call _assert;
    _priorRemaining = _window select 1;
};
private _tinyCurve = [15.01, 1.2, 0.8] call GAIT_fnc_uphillBrakeParameters;
private _tinyCoast = [_tinyCurve select 0, 1, 0.85] call GAIT_fnc_uphillBrakeCoastWindow;
[abs ((_tinyCoast select 1) - 1.85) < 0.0001, "near-onset brake cannot erase the full release coast"] call _assert;
private _fullCoast = [1, 1, 0.85] call GAIT_fnc_uphillBrakeCoastWindow;
[(_fullCoast select 1) isEqualTo 0, "full uphill brake removes the release hold"] call _assert;
diag_log format ["GAIT TEST PASS: uphill release edge, signed grade, slope strength, re-tap cancellation, continuous coast and bounded braking (%1 checks)", _checks];
