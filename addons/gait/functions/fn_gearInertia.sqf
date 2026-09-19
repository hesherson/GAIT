/*
    Alpha7 gives heavy launch a further 2% rate boost; lighter ordering is preserved.
    Load changes acceleration, never sprint permission or steady pace.
    A released sprint has one short forward-only taper, with no hold and no
    secondary exponential tail. The separate uphill brake has priority.

    Returns [accelerationScale, decelerationScale, coastScale,
             launchDurationScale, originalTierBraceRelief].
*/
GAIT_fnc_gearInertia = {
    params [
        ["_gearLbs", 0, [0]],
        ["_braceRelief", [0.55, 0.35, 0.18, 0], [[]]],
        ["_thresholds", [35, 55, 75], [[]]]
    ];
    if ((count _braceRelief) < 4) then {_braceRelief = [0.55, 0.35, 0.18, 0];};
    if ((count _thresholds) < 3) then {_thresholds = [35, 55, 75];};
    private _lightMax = (_thresholds param [0, 35, [0]]) max 1;
    private _mediumMax = (_thresholds param [1, 55, [0]]) max (_lightMax + 1);
    private _moderateMax = (_thresholds param [2, 75, [0]]) max (_mediumMax + 1);
    private _landmarks = [0, _lightMax, _mediumMax, _moderateMax, _moderateMax + 25, _moderateMax + 50];
    private _acceleration = [1.06, 1.04, 1.02, 1.02, 1.02, 1.02];
    private _coast = [0.90, 0.95, 1, 1.05, 1.10, 1.15];
    private _load = _gearLbs max 0 min (_landmarks select 5);
    private _segment = 0;
    for "_i" from 1 to 4 do {
        if (_load > (_landmarks select _i)) then {_segment = _i;};
    };
    private _fraction = (_load - (_landmarks select _segment)) / ((_landmarks select (_segment + 1)) - (_landmarks select _segment));
    private _accelerationScale = (_acceleration select _segment) + (((_acceleration select (_segment + 1)) - (_acceleration select _segment)) * _fraction);
    private _coastScale = (_coast select _segment) + (((_coast select (_segment + 1)) - (_coast select _segment)) * _fraction);
    private _tier = 3;
    if (_gearLbs <= _lightMax) then {_tier = 0;} else {
        if (_gearLbs <= _mediumMax) then {_tier = 1;} else {
            if (_gearLbs <= _moderateMax) then {_tier = 2;};
        };
    };
    [_accelerationScale, 1, _coastScale, 1, (_braceRelief param [_tier, 0, [0]]) max 0 min 1]
};

GAIT_fnc_scaleInertiaRamp = {
    params [["_baseLerp", 0.05, [0]], ["_rateScale", 1, [0]]];
    _baseLerp = _baseLerp max 0 min 1;
    _rateScale = _rateScale max 0.05 min 3;
    1 - ((1 - _baseLerp) ^ _rateScale)
};

// Keep the stored hold argument for compatibility, but never apply it. Saved
// alpha4 hold settings must not reintroduce input lag. The duration setting is
// a scale: default .85 resolves to .268-.342 seconds across default load tiers.
GAIT_fnc_gearCoastWindow = {
    params [["_holdSeconds", 0, [0]], ["_taperSeconds", 0.85, [0]], ["_durationScale", 1, [0]]];
    [0, ((_taperSeconds max 0.05 min 4) * 0.35 * (_durationScale max 0.9 min 1.15)) max 0.15 min 0.45]
};

// Finite curve applied directly to the coefficient, not filtered a second
// time. Output never exceeds the release value. The caller also limits it
// to the current coefficient, so a rising live walk target cannot add speed.
GAIT_fnc_forwardCoastPace = {
    params ["_start", "_walk", "_elapsed", "_duration", ["_curve", 1.45, [0]]];
    _start = _start max 0;
    _walk = (_walk max 0) min _start;
    private _t = (_elapsed / (_duration max 0.05)) max 0 min 1;
    private _ease = _t * _t * (3 - (2 * _t));
    private _keep = (1 - _ease) ^ (_curve max 1 min 3);
    [_walk + ((_start - _walk) * _keep), _keep, _t < 1]
};

// Keep numeric coast only for the finite curve while W stays held.
// W+A/D are valid forward movement; pure strafe/back/stop are not coasting.
// Compatibility arguments retain old call sites without any residual tail.
GAIT_fnc_gearCoastActive = {
    params [
        ["_enabled", false, [false]], ["_sprinting", false, [false]],
        ["_forward", false, [false]], ["_lateral", false, [false]],
        ["_protected", false, [false]], ["_moving", false, [false]],
        ["_currentCoef", 1, [0]], ["_walkCoef", 1, [0]],
        ["_now", 0, [0]], ["_taperUntil", -999, [0]], ["_taperActive", false, [false]]
    ];
    _enabled && {!_sprinting} && {_forward} && {_moving} &&
    {_taperActive} && {_taperUntil >= 0} && {_now < _taperUntil}
};
