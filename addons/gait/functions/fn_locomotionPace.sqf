/*
    Physical pace boundary for the existing, tuned coefficient controller.

    Compile after fn_slopePaceModel.sqf. This file performs no movement I/O.
    It does not own brace, launch timing, acceleration, reserve or Shift coast.
    Feed its STEADY targets into those existing stages; never apply its floor
    to an already-ramped coefficient or to a brace/step-off coefficient.

    Profile rows are empirical flat-ground, coefficient-1 references in m/s:
      [weaponFamily, direction, walkMS, jogMS, sprintMS]
    An unmeasured reference is -1. Family and direction matching ignore case.
    Each family/direction must occur at most once. Native clip names are the
    corresponding AmovPerc + Mwlk/Mrun/Meva + family + direction states.
    A reference is applicable only when the selected custom clip retains that
    native clip's root motion/playback configuration. Profiles belong to the
    tested animation/mod configuration; changing it requires recalibration.

    No measured profile is bundled or learned automatically. Runtime callers
    may pass missionNamespace getVariable ["GAIT_locomotionPaceProfiles", []].
    With missing, ambiguous or invalid references, coefficient targets are
    EXACTLY the old model and metric fields are -1 (unknown), not estimates.
    A calibrated target is a model target, not a promise of actual terrain or
    collision-limited speed. No velocity feedback tries to force the target.
*/

GAIT_fnc_paceReferenceValid = {
    params ["_reference"];
    // Positive lower/upper comparisons also reject NaN and infinities.
    (_reference isEqualType 0) &&
        {_reference >= 0.05} && {_reference <= 25}
};

GAIT_fnc_paceCoefficientToMS = {
    params ["_coefficient", "_reference"];
    private _valid = (_coefficient isEqualType 0) &&
        {_coefficient >= 0} && {_coefficient <= 100} &&
        {[_reference] call GAIT_fnc_paceReferenceValid};
    if (!_valid) exitWith {-1};
    _coefficient * _reference
};

GAIT_fnc_paceMSToCoefficient = {
    params ["_speed", "_reference"];
    private _valid = (_speed isEqualType 0) && {_speed >= 0} &&
        {_speed <= 2500} && {[_reference] call GAIT_fnc_paceReferenceValid};
    if (!_valid) exitWith {-1};
    _speed / _reference
};

GAIT_fnc_locomotionPaceReferences = {
    params [
        ["_profiles", [], [[]]],
        ["_family", "", [""]],
        ["_direction", "", [""]],
        ["_gait", "sprint", [""]]
    ];
    _family = toLower _family;
    _direction = toLower _direction;
    _gait = toLower _gait;
    if !(_family in ["sraswrfl", "slowwrfl", "sraswpst", "slowwpst", "snonwnon"]) exitWith {[]};
    if !(_direction in ["df", "dfr", "dr", "dbr", "db", "dbl", "dl", "dfl"]) exitWith {[]};
    private _column = ["walk", "jog", "sprint"] find _gait;
    if (_column < 0) exitWith {[]};
    private _matches = _profiles select {
        (_x isEqualType []) && {(count _x) >= 2} &&
        {(_x select 0) isEqualType ""} && {(_x select 1) isEqualType ""} &&
        {(toLower (_x select 0)) isEqualTo _family} &&
        {(toLower (_x select 1)) isEqualTo _direction}
    };
    // A duplicate must not silently change which measurements are selected.
    if ((count _matches) isNotEqualTo 1) exitWith {[]};
    private _profile = _matches select 0;
    if ((count _profile) isNotEqualTo 5) exitWith {[]};
    private _malformed = (_profile select [2, 3]) findIf {
        _x isNotEqualTo -1 && {!([_x] call GAIT_fnc_paceReferenceValid)}
    };
    if (_malformed >= 0) exitWith {[]};
    private _walk = _profile select 2;
    private _moving = _profile select (_column + 2);
    if (!([_walk] call GAIT_fnc_paceReferenceValid) ||
        {!([_moving] call GAIT_fnc_paceReferenceValid)}) exitWith {[]};
    [_walk, _moving]
};

GAIT_fnc_locomotionPaceTargets = {
    params [
        ["_flatWalkCoefficient", 1.6, [0]],
        ["_flatSprintCoefficient", 6.2, [0]],
        ["_walkSlopeMultiplier", 1, [0]],
        ["_sprintSlopeMultiplier", 1, [0]],
        ["_loadMultiplier", 1, [0]],
        ["_minimumSprintRatio", 1.20, [0]],
        ["_profiles", [], [[]]],
        ["_family", "", [""]],
        ["_direction", "", [""]],
        ["_selectedGait", "sprint", [""]]
    ];
    private _modelArgs = [_flatWalkCoefficient, _flatSprintCoefficient,
        _walkSlopeMultiplier, _sprintSlopeMultiplier, _loadMultiplier,
        _minimumSprintRatio];
    private _references = [_profiles, _family, _direction, _selectedGait]
        call GAIT_fnc_locomotionPaceReferences;
    if (_references isEqualTo []) exitWith {
        private _legacy = _modelArgs call GAIT_fnc_slopePaceModel;
        [_legacy select 0, _legacy select 1, -1, -1, false]
    };
    _references params ["_walkReference", "_movingReference"];
    // Keep the old model's input clamps in COEFFICIENT units. Reusing its
    // fixed 0.01 input minimum after conversion would alter very slow clips.
    private _load = _loadMultiplier max 0.001;
    private _walkCoefficient = (_flatWalkCoefficient max 0.01) *
        (_walkSlopeMultiplier max 0.001) * _load;
    private _candidateCoefficient = (_flatSprintCoefficient max 0) *
        (_sprintSlopeMultiplier max 0.001) * _load;
    private _walkMS = [_walkCoefficient, _walkReference] call GAIT_fnc_paceCoefficientToMS;
    private _candidateMS = [_candidateCoefficient, _movingReference] call GAIT_fnc_paceCoefficientToMS;
    if (_walkMS < 0 || {_candidateMS < 0}) exitWith {
        private _legacy = _modelArgs call GAIT_fnc_slopePaceModel;
        [_legacy select 0, _legacy select 1, -1, -1, false]
    };
    // Comparing coefficients of different clips does not compare speeds.
    // Apply the floor once, to the common physical steady targets only.
    private _movingMS = _candidateMS max (_walkMS * (_minimumSprintRatio max 1.01));
    private _movingCoefficient = [_movingMS, _movingReference] call GAIT_fnc_paceMSToCoefficient;
    if (_movingCoefficient < 0 || {_movingCoefficient > 100}) exitWith {
        private _legacy = _modelArgs call GAIT_fnc_slopePaceModel;
        [_legacy select 0, _legacy select 1, -1, -1, false]
    };
    [_walkCoefficient, _movingCoefficient, _walkMS, _movingMS, true]
};

// Arm one burst when a fully rested sprint starts. Recovery during a held
// sprint cannot restart an expired burst, and letting go cancels it.
GAIT_fnc_stepDeadSprint = {
    params ["_elapsed", "_sprinting", "_wasSprinting", "_reserve", "_dt"];
    if (!_sprinting) exitWith {-1};
    if (!_wasSprinting) exitWith {[-1, 0] select (_reserve >= 0.999)};
    if (_elapsed < 0 || {_reserve <= 0.50}) exitWith {-1};
    _elapsed = _elapsed + (_dt max 0);
    [_elapsed, -1] select (_elapsed >= 5.70)
};

// Hold the peak target through acceleration, then ease out over three
// seconds. If reserve drains quickly, finish tapering by half reserve.
GAIT_fnc_deadSprintStrength = {
    params ["_elapsed", "_reserve"];
    if (_elapsed < 0) exitWith {0};
    private _time = ((5.70 - _elapsed) / 3) max 0 min 1;
    private _remaining = ((_reserve - 0.50) / 0.25) max 0 min 1;
    private _strength = _time min _remaining;
    _strength * _strength * (3 - (2 * _strength))
};

// Normal sprint pace holds after the rested burst until the final fifth,
// then tapers toward the load-scaled floor.
GAIT_fnc_sprintReservePace = {
    params ["_fresh", "_normalRun", "_reserve", ["_gearLbs", 0, [0]],
        ["_uphillMinimum", 0, [0]], ["_exhaustedRunPace", 0.70, [0]],
        ["_flatGround", false, [false]], ["_flatPeak", 1.10, [0]], ["_deadSprintStrength", 0, [0]]];
    private _loadFraction = (_gearLbs / 100) max 0 min 1;
    private _exhaustedRatio = ((_exhaustedRunPace + 0.05) - (0.10 * _loadFraction)) max 0 min 1;
    private _floor = (_normalRun * _exhaustedRatio) max _uphillMinimum;
    private _normalTarget = _fresh max _floor;
    if (_flatGround && {_reserve > 0.50} && {_deadSprintStrength > 0}) exitWith {
        private _mass = _gearLbs max 0;
        private _burstLoadScale = 1 - (0.8 * (_mass / (_mass + 110)));
        private _bonus = ((_flatPeak - 1) max 0) * (_deadSprintStrength min 1) * _burstLoadScale;
        (_fresh * (1 + _bonus)) max _floor
    };
    if (_reserve >= 0.20) exitWith {_normalTarget};
    private _remaining = (_reserve / 0.20) max 0;
    private _effort = _remaining * _remaining * (3 - (2 * _remaining));
    _floor + ((_normalTarget - _floor) * _effort)
};

GAIT_fnc_uphillSprintFloor = {
    params ["_walk", "_jog", "_walkReference", "_jogReference", "_sprintReference"];
    // Use conservative clip ratios until matching measurements are available.
    private _walkToSprint = 0.30;
    private _jogToSprint = 0.75;
    if (_sprintReference > 0) then {
        if (_walkReference > 0) then {_walkToSprint = _walkReference / _sprintReference;};
        if (_jogReference > 0) then {_jogToSprint = _jogReference / _sprintReference;};
    };
    private _walkOnSprintClip = _walk * _walkToSprint;
    // Ordinary jog already has a 6% floor over walking in the pace adapter.
    ((_walkOnSprintClip * 1.06) max (_jog * _jogToSprint)) * 1.08
};
