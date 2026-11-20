/*
    Live carried mass controls acceleration and launch brace relief.
    Returns [accelerationScale, braceRelief].
*/
GAIT_fnc_gearWeightAnchors = {
    params ["_thresholds"];
    private _first = (_thresholds param [0, 35, [0]]) max 1;
    private _second = (_thresholds param [1, 55, [0]]) max (_first + 1);
    private _third = (_thresholds param [2, 75, [0]]) max (_second + 1);
    [0, _first, _second, _third]
};

GAIT_fnc_patientBurden = {
    params ["_patientGearLb", "_dragging"];
    // Effective effort, in kit-equivalent lb. Ground support reduces drag effort.
    (150 + (_patientGearLb max 0 min 200)) * ([0.45,0.20] select _dragging)
};

GAIT_fnc_effectiveTravelLoad = {
    params ["_unit", "_patient", "_dragging", "_dt"];
    private _base = (_unit getVariable ["ace_movement_totalLoad", loadAbs _unit]) / 10;
    private _target = 0;
    if (!isNull _patient && {_patient isKindOf "CAManBase"} && {attachedTo _patient isEqualTo _unit}) then {
        private _patientKit = (_patient getVariable ["ace_movement_totalLoad", loadAbs _patient]) / 10;
        _target = [_patientKit, _dragging] call GAIT_fnc_patientBurden;
    };
    private _previous = _unit getVariable ["GAIT_patientBurdenLb", 0];
    private _next = _target + (_previous - _target) * exp (-6 * (_dt max 0 min 0.25));
    if (abs (_next - _target) < 0.05) then {_next = _target;};
    _unit setVariable ["GAIT_patientBurdenLb", _next];
    _base + _next
};

GAIT_fnc_gearInertia = {
    params [
        ["_gearLbs", 0, [0]],
        ["_braceRelief", [0.55, 0.35, 0.18, 0], [[]]],
        ["_thresholds", [35, 55, 75], [[]]]
    ];
    if ((count _braceRelief) < 4) then {_braceRelief = [0.55, 0.35, 0.18, 0];};
    private _landmarks = [_thresholds] call GAIT_fnc_gearWeightAnchors;
    private _heavyAnchor = _landmarks select 3;
    _landmarks append [_heavyAnchor + 25, _heavyAnchor + 50];
    private _acceleration = [1.12, 1.02, 0.93, 0.84, 0.77, 0.72];
    private _load = _gearLbs max 0 min (_landmarks select 5);
    private _segment = 0;
    for "_i" from 1 to 4 do {
        if (_load > (_landmarks select _i)) then {_segment = _i;};
    };
    private _fraction = (_load - (_landmarks select _segment)) / ((_landmarks select (_segment + 1)) - (_landmarks select _segment));
    private _accelerationScale = (_acceleration select _segment) + (((_acceleration select (_segment + 1)) - (_acceleration select _segment)) * _fraction);
    private _reliefFrom = (_braceRelief param [_segment min 3, 0, [0]]) max 0 min 1;
    private _reliefTo = (_braceRelief param [(_segment + 1) min 3, 0, [0]]) max 0 min 1;
    [_accelerationScale, _reliefFrom + ((_reliefTo - _reliefFrom) * _fraction)]
};

GAIT_fnc_scaleInertiaRamp = {
    params [["_baseLerp", 0.05, [0]], ["_rateScale", 1, [0]]];
    _baseLerp = _baseLerp max 0 min 1;
    _rateScale = _rateScale max 0.05 min 3;
    1 - ((1 - _baseLerp) ^ _rateScale)
};

// Sprint acceleration alone uses a slower convergence than general movement.
// 0.70 makes default 0.05 smoothing reach ~95% in about 4.1 s instead of
// ~2.9 s, before the continuous load adjustment.
GAIT_fnc_sprintAccelerationRamp = {
    params [
        ["_baseLerp", 0.05, [0]],
        ["_gearScale", 1, [0]],
        ["_sprintScale", 0.70, [0]]
    ];
    [_baseLerp, (_gearScale max 0.05 min 3) * (_sprintScale max 0.25 min 1)]
        call GAIT_fnc_scaleInertiaRamp
};

// Full kit retains a deliberate stance change when rested and reaches the
// slowest allowable cadence only when its reserve is depleted.
GAIT_fnc_stancePaceCoefficient = {
    params ["_gearLbs", "_reserve", "_depth"];
    private _load = ((_gearLbs / 150) max 0 min 1) ^ 1.15;
    private _fatigue = (1 - (_reserve max 0 min 1)) ^ 1.6;
    (1 - ((_depth max 0 min 1) * ((0.18 * _load) + ((0.03 + 0.14 * _load) * _fatigue)))) max 0.65
};
