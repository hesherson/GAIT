/*
    Pure load-dependent pace response. This shapes the existing scalar speed
    coefficient and launch brace; it never owns movement input or animation.
    A heavy kit takes longer to accelerate and longer to settle from a sprint
    toward walking while forward input remains held. Release/turn intent must
    still reach the locomotion graph immediately. Uphill release braking has
    priority and must use its own original response without these rate scales.

    Input: [displayedGearLbs, [light, medium, moderate, heavy] brace relief,
            [lightMaxLbs, mediumMaxLbs, moderateMaxLbs]].
    Output: [accelerationRateScale, decelerationRateScale, coastDurationScale,
             launchBraceDurationScale, interpolatedBraceRelief].

    Scales modify response, never steady sprint/walk targets. The existing
    brace speed, response and duration settings remain the baseline. Relief
    interpolates from light at zero load to medium/lightMax, moderate/mediumMax
    and heavy/moderateMax; a heavy kit retains its original full brace dip.
    Load beyond moderateMax + 50 lb does not add unbounded response delay.
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
    private _lightRelief = (_braceRelief param [0, 0.55, [0]]) max 0 min 1;
    private _mediumRelief = (_braceRelief param [1, 0.35, [0]]) max 0 min 1;
    private _moderateRelief = (_braceRelief param [2, 0.18, [0]]) max 0 min 1;
    private _heavyRelief = (_braceRelief param [3, 0, [0]]) max 0 min 1;
    private _landmarks = [0, _lightMax, _mediumMax, _moderateMax, _moderateMax + 25, _moderateMax + 50];
    private _responses = [
        [1.20, 1.40, 0.60, 0.90, _lightRelief],
        [1.10, 1.20, 0.80, 0.95, _mediumRelief],
        [1.00, 1.00, 1.00, 1.00, _moderateRelief],
        [0.86, 0.84, 1.15, 1.08, _heavyRelief],
        [0.73, 0.70, 1.30, 1.18, _heavyRelief],
        [0.62, 0.60, 1.45, 1.28, _heavyRelief]
    ];
    private _load = _gearLbs max 0 min (_landmarks select 5);
    private _segment = 0;
    for "_i" from 1 to 4 do {
        if (_load > (_landmarks select _i)) then {_segment = _i;};
    };
    private _lowerLoad = _landmarks select _segment;
    private _upperLoad = _landmarks select (_segment + 1);
    private _fraction = (_load - _lowerLoad) / (_upperLoad - _lowerLoad);
    private _lower = _responses select _segment;
    private _upper = _responses select (_segment + 1);
    private _result = [];
    for "_i" from 0 to 4 do {
        _result pushBack ((_lower select _i) + (((_upper select _i) - (_lower select _i)) * _fraction));
    };
    _result
};

// Preserve the time constant when applying a rate scale to the existing
// exponential 50 ms response. Caller passes this to stepSpeedCoefficient.
GAIT_fnc_scaleInertiaRamp = {
    params [["_baseLerp", 0.05, [0]], ["_rateScale", 1, [0]]];
    _baseLerp = _baseLerp max 0 min 1;
    _rateScale = _rateScale max 0.05 min 3;
    1 - ((1 - _baseLerp) ^ _rateScale)
};

// Resolve once per release and reuse for both the deadline and taper curve.
// The enabled flag remains caller policy. Zero hold remains zero, and the
// original hold/taper caps prevent excessive settings or load causing a coast
// that never settles. Uphill shortening is applied AFTER this calculation.
GAIT_fnc_gearCoastWindow = {
    params [
        ["_holdSeconds", 1, [0]],
        ["_taperSeconds", 0.85, [0]],
        ["_durationScale", 1, [0]]
    ];
    _durationScale = _durationScale max 0.25 min 2;
    [((_holdSeconds max 0 min 3) * _durationScale) min 3,
     ((_taperSeconds max 0.05 min 4) * _durationScale) max 0.05 min 4]
};

// The target reaches walking at the end of its finite taper, but the actual
// scalar response still trails that target. Keep the same movement family
// through this remaining decay so a re-tap does not exit and re-enter sprint.
// Raw turn/stop intent cancels immediately. A six-second upper bound prevents
// tiny custom response settings from retaining the sprint family indefinitely.
GAIT_fnc_gearCoastActive = {
    params [
        ["_enabled", false, [false]],
        ["_sprinting", false, [false]],
        ["_forward", false, [false]],
        ["_lateral", false, [false]],
        ["_protected", false, [false]],
        ["_moving", false, [false]],
        ["_currentCoef", 1, [0]],
        ["_walkCoef", 1, [0]],
        ["_now", 0, [0]],
        ["_taperUntil", -999, [0]],
        ["_taperActive", false, [false]]
    ];
    _enabled && {!_sprinting} && {_forward} && {!_lateral} && {_protected} && {_moving} &&
    {_taperUntil >= 0} && {_now <= (_taperUntil + 6)} &&
    {_taperActive || {_currentCoef > ((_walkCoef max 0) + 0.04)}}
};
