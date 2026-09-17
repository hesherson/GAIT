// Execute after functions/fn_slopePaceModel.sqf in SQF-VM or an Arma mission.
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};

private _almostEqual = {
    params ["_actual", "_expected", "_label"];
    [abs (_actual - _expected) < 0.00001, _label] call _assert;
};

// Calibrations and continuity of the progressive pack-weight model.
{
    _x params ["_weight", "_expected"];
    [[_weight] call GAIT_fnc_continuousLoadMultiplier, _expected, "load calibration"] call _almostEqual;
} forEach [[0,1.08], [35,1.05], [55,1.025], [75,1], [125,1/1.18], [175,1/1.36], [250,1/1.63]];
{
    private _left = [_x - 0.001] call GAIT_fnc_continuousLoadMultiplier;
    private _right = [_x + 0.001] call GAIT_fnc_continuousLoadMultiplier;
    [abs (_left - _right) < 0.00001, "gear tier boundary is continuous"] call _assert;
} forEach [35,55,75];

// Uphill reference angle is a calibration point, not a penalty cap.
[[5,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier, 1, "grade curve begins at start"] call _almostEqual;
[[35,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier, 0.6, "reference grade keeps configured penalty"] call _almostEqual;
[[65,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier, 0.36, "penalty continues above reference grade"] call _almostEqual;
[([89,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier) < ([80,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier), "steepest model grades keep slowing"] call _assert;

// The exact same model supplies both the walking reference and sprint target.
// Check every grade and pound, including low sprint coefficients that invoke
// the floor. A floor built from an unweighted or differently graded walk speed
// would fail the monotonic-load checks or the ratio assertions below.
private _checks = 0;
private _loads = [];
for "_weight" from 0 to 250 do {_loads pushBack ([_weight] call GAIT_fnc_continuousLoadMultiplier);};
private _grades = [];
for "_grade" from 0 to 89 do {
    _grades pushBack [
        [_grade,15,40,0.32] call GAIT_fnc_uphillPaceMultiplier,
        [_grade,5,35,0.40] call GAIT_fnc_uphillPaceMultiplier
    ];
};
{
    private _reserve = _x;
    private _flatSprint = 4.2 + ((6.2 - 4.2) * _reserve);
    private _effectiveRatio = 1.20 + (0.20 * _reserve);
    {
        private _candidateBase = _x;
        private _priorAtGrade = [];
        for "_weight" from 0 to 250 do {
            private _load = _loads select _weight;
            private _lastWalk = 1e10;
            private _lastSprint = 1e10;
            for "_grade" from 0 to 89 do {
                (_grades select _grade) params ["_walkGrade", "_sprintGrade"];
                private _pair = [1.6,_candidateBase,_walkGrade,_sprintGrade,_load,_effectiveRatio] call GAIT_fnc_slopePaceModel;
                _pair params ["_walk", "_sprint"];
                if (_walk <= 0 || {_sprint < (_walk * _effectiveRatio) - 0.00001}) then {
                    throw format ["FAIL: sprint floor at grade %1, load %2, reserve %3", _grade, _weight, _reserve];
                };
                if (_walk > _lastWalk + 0.00001 || {_sprint > _lastSprint + 0.00001}) then {
                    throw format ["FAIL: pace rises with grade at grade %1, load %2, reserve %3", _grade, _weight, _reserve];
                };
                if (_weight > 0) then {
                    (_priorAtGrade select _grade) params ["_priorWalk", "_priorSprint"];
                    if (_walk >= _priorWalk || {_sprint >= _priorSprint}) then {
                        throw format ["FAIL: pace does not decrease with added pound at grade %1, load %2, reserve %3", _grade, _weight, _reserve];
                    };
                };
                _priorAtGrade set [_grade,_pair];
                _lastWalk = _walk;
                _lastSprint = _sprint;
                _checks = _checks + 1;
            };
        };
    } forEach [_flatSprint, 0.05 * _flatSprint];
} forEach [0,0.25,0.5,0.75,1];

// Regression for the live coefficient integration: a reserve-independent
// floor made default unarmed fresh and exhausted sprint identical. Its extra
// fresh margin must preserve reserve response even when both candidates are
// below the floor. These are target coefficients, not measured clip speeds.
private _reserveChecks = 0;
{
    private _weight = _x;
    private _load = _loads select _weight;
    private _walkWeightSeverity = ((_weight - 35) / 80) max 0 min 1;
    private _walkPenalty = 0.32 * (0.75 + (0.50 * _walkWeightSeverity));
    for "_grade" from 0 to 89 do {
        private _walkGrade = [_grade,15,40,_walkPenalty] call GAIT_fnc_uphillPaceMultiplier;
        private _sprintGrade = (_grades select _grade) select 1;
        {
            private _normalizer = _x;
            private _priorTarget = -1;
            {
                private _reserve = _x;
                private _candidate = (0.89 + ((1.28 - 0.89) * _reserve)) * _normalizer;
                private _pair = [0.86,_candidate,_walkGrade,_sprintGrade,_load,1.20 + (0.20 * _reserve)] call GAIT_fnc_slopePaceModel;
                private _target = _pair select 1;
                if (_target <= _priorTarget) then {
                    throw format ["FAIL: default reserve response lost at grade %1, load %2, normalizer %3, reserve %4",_grade,_weight,_normalizer,_reserve];
                };
                _priorTarget = _target;
                _reserveChecks = _reserveChecks + 1;
            } forEach [0,0.25,0.5,0.75,1];
        } forEach [1,0.725];
    };
} forEach [0,35,75,100,150,250];

// Reference-unit invariance: converting every base speed m/s -> km/h must
// produce the same conversion in the pair, including when the floor is active.
private _ms = [1.6,0.5,0.4,0.2,0.75,1.2] call GAIT_fnc_slopePaceModel;
private _kmh = [1.6*3.6,0.5*3.6,0.4,0.2,0.75,1.2] call GAIT_fnc_slopePaceModel;
[(_ms select 0)*3.6,_kmh select 0,"walking common-reference units"] call _almostEqual;
[(_ms select 1)*3.6,_kmh select 1,"sprint common-reference units"] call _almostEqual;
diag_log format ["GAIT TEST PASS: slope/load pace model, %1 grade-load-reserve combinations; sprint floor, monotonic grade/load, heavy-pack tail and common-reference units; %2 default armed/unarmed reserve-response samples",_checks,_reserveChecks];
