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
} forEach [[0,1.08], [35,1.02], [55,0.97], [75,0.92], [125,0.92/1.18], [175,0.92/1.36], [250,0.92/1.63]];
{
    private _left = [_x - 0.001] call GAIT_fnc_continuousLoadMultiplier;
    private _right = [_x + 0.001] call GAIT_fnc_continuousLoadMultiplier;
    [abs (_left - _right) < 0.00001, "pace is continuous across configured mass anchors"] call _assert;
} forEach [35,55,75];

// Uphill reference angle is a calibration point, not a penalty cap.
[[5,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier, 1, "grade curve begins at start"] call _almostEqual;
[[35,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier, 0.6, "reference grade keeps configured penalty"] call _almostEqual;
[[65,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier, 0.36, "penalty continues above reference grade"] call _almostEqual;
[([89,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier) < ([80,5,35,0.4] call GAIT_fnc_uphillPaceMultiplier), "steepest model grades keep slowing"] call _assert;

// The exact same model supplies both the walking reference and sprint target.
// Sample grades and pounds through the traversable range, including the load
// anchors and low sprint coefficients that invoke the floor. A floor built
// from an unweighted walk speed would fail the monotonic-load checks.
private _checks = 0;
private _loads = [];
for "_weight" from 0 to 250 do {_loads pushBack ([_weight] call GAIT_fnc_continuousLoadMultiplier);};
private _grades = [];
for "_grade" from 0 to 89 do {_grades pushBack ([_grade,15,40,0.32] call GAIT_fnc_uphillPaceMultiplier);};
{
    private _reserve = _x;
    private _flatSprint = 4.2 + ((6.2 - 4.2) * _reserve);
    private _effectiveRatio = 1.20 + (0.20 * _reserve);
    {
        private _candidateBase = _x;
        private _priorAtGrade = [];
        for "_weight" from 0 to 250 step 5 do {
            private _load = _loads select _weight;
            private _lastWalk = 1e10;
            private _lastSprint = 1e10;
            for "_grade" from 0 to 88 step 4 do {
                private _walkGrade = _grades select _grade;
                private _sprintGrade = [_grade,2,35,0.40] call GAIT_fnc_uphillPaceMultiplier;
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

// Reference-unit invariance: converting every base speed m/s -> km/h must
// produce the same conversion in the pair, including when the floor is active.
private _ms = [1.6,0.5,0.4,0.2,0.75,1.2] call GAIT_fnc_slopePaceModel;
private _kmh = [1.6*3.6,0.5*3.6,0.4,0.2,0.75,1.2] call GAIT_fnc_slopePaceModel;
[(_ms select 0)*3.6,_kmh select 0,"walking common-reference units"] call _almostEqual;
[(_ms select 1)*3.6,_kmh select 1,"sprint common-reference units"] call _almostEqual;
diag_log format ["GAIT TEST PASS: slope/load pace model, %1 grade-load-reserve combinations; sprint floor, monotonic grade/load, heavy-pack tail and common-reference units",_checks];
