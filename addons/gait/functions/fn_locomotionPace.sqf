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

GAIT_fnc_sprintWalkPace = {
    params ["_startMS", "_walkMS", "_progress"];
    // Smoothstep starts braking immediately and eases into the walk endpoint.
    private _t = _progress max 0 min 1;
    private _weight = _t * _t * (3 - 2 * _t);
    private _initial = _startMS max _walkMS;
    _initial + (_walkMS - _initial) * _weight
};

GAIT_fnc_sprintReleaseSpeed = {
    params ["_release", "_destinationMS", "_progress"];
    private _startMS = _release select 1;
    private _anchor = _release param [3, -1];
    if (_anchor < 0) exitWith {[_startMS, _destinationMS, _progress] call GAIT_fnc_sprintWalkPace};
    private _remaining = [1, 0, _progress] call GAIT_fnc_sprintWalkPace;
    private _initialRemaining = [1, 0, _anchor] call GAIT_fnc_sprintWalkPace;
    private _weight = (_remaining / (_initialRemaining max 0.000001)) max 0 min 1;
    _destinationMS + ((_startMS - _destinationMS) * _weight)
};

GAIT_fnc_rebaseSprintRelease = {
    params ["_release", "_now", "_speed", "_intoCrouch"];
    _release params ["_start", "_previousSpeed", "_scale", ["_oldAnchor", -1], ["_shortened", false]];
    private _progress = [_start, _now, _scale] call GAIT_fnc_sprintWalkProgress;
    if (_intoCrouch && {!_shortened}) then {
        // Keep the position on the original ease curve, with 25% less
        // remaining time. Repeated stance changes never restart the taper.
        _start = _now - ((_now - _start) * 0.75);
        _scale = _scale * 0.75;
        _shortened = true;
    };
    [_start, _speed, _scale, _progress, _shortened]
};

GAIT_fnc_stepSprintReleaseSample = {
    params ["_previous", "_press", "_now", "_speed", "_applied", "_target"];
    // A high playback rate left over from the previous gait can briefly
    // overspeed a new sprint. That excess is never earned release momentum.
    private _bounded = _speed * ((_target / (_applied max 0.05)) max 0 min 1);
    _previous params [["_oldPress", -1], ["_since", _now], ["_last", -1], ["_pace", 0]];
    if (_press isNotEqualTo _oldPress || {_now - _last > 0.20}) exitWith {[_press, _now, _now, _bounded]};
    private _sample = [_pace, _bounded, 0.30, _now - _last] call GAIT_fnc_stepSpeedCoefficient;
    [_press, _since, _now, _sample]
};

GAIT_fnc_sprintReleaseStartSpeed = {
    params ["_sample", "_press", "_now"];
    _sample params [["_oldPress", -1], ["_since", _now], ["_last", -1], ["_pace", 0]];
    if (_oldPress isNotEqualTo _press || {_last - _since < 0.24} ||
        {_now - _last > 0.20}) exitWith {0};
    _pace
};

GAIT_fnc_releaseClipReference = {
    params ["_unit", "_clip", "_grade"];
    private _name = toLower _clip;
    private _divider = _name find "_amov";
    if (_divider >= 0) then {_name = _name select [_divider + 1];};
    private _base = (_name splitString "_") param [0, ""];
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _state = _states >> _name;
    private _reference = [_unit, _name, _grade] call GAIT_fnc_lookupUnitPaceReference;
    if (_reference > 0) exitWith {_reference};
    private _root = getArray (_state >> "GAIT_rootTravel");
    if (_root isEqualTo []) then {_root = getArray (_states >> (_base + "_GAIT") >> "GAIT_rootTravel");};
    private _distance = _root param [0, 0];
    private _rtm = _root param [1, ""];
    private _file = (toLower getText (_state >> "file")) splitString "/\";
    private _rate = getNumber (_state >> "speed");
    if (_distance > 0 && {_rtm isNotEqualTo ""} && {(_file param [(count _file) - 1, ""]) isEqualTo _rtm} &&
        {abs _rate > 0.001}) exitWith {
        _distance * (if (_rate < 0) then {1 / abs _rate} else {_rate})
    };

    // Animation replacements with a different RTM use a bounded estimate
    // until a matching passive measurement is available.
    private _crouched = (_base select [4, 4]) isEqualTo "pknl";
    private _sideways = (_base select [20]) in ["dl", "dbl", "db", "dbr", "dr"];
    switch (_base select [8, 4]) do {
        case "mwlk": {([1.42, 1.10] select _crouched) * ([1, 0.76] select _sideways)};
        case "meva";
        case "mspr": {[5.1, 4.65] select _crouched};
        default {([3.9, 3.15] select _crouched) * ([1, 0.73] select _sideways)};
    }
};

GAIT_fnc_capSprintPace = {
    params ["_candidate", "_reference", "_clipScale", "_terrain", "_loadScale"];
    // Bound both fast native weapon clips and an unmeasured animation set.
    // The downhill envelope still allows the existing 30 km/h ceiling.
    private _gradeScale = _terrain max 1;
    private _bonus = _loadScale max 1 min 1.02;
    private _limited = _candidate min (1.10 * _clipScale * _gradeScale * _bonus);
    if ([_reference] call GAIT_fnc_paceReferenceValid) then {
        _limited = _limited min (((6 * _gradeScale * _bonus) min (30 / 3.6)) / _reference);
    };
    _limited
};

GAIT_fnc_weaponStrideScale = {
    params ["_standardReference", "_weaponReference", ["_fallback", 1]];
    if (!([_standardReference] call GAIT_fnc_paceReferenceValid) ||
        {!([_weaponReference] call GAIT_fnc_paceReferenceValid)}) exitWith {_fallback};
    (_standardReference / _weaponReference) max 0.35 min 1.35
};

GAIT_fnc_blendedStrideReference = {
    params ["_source", "_target", "_weight"];
    private _t = _weight max 0 min 1;
    _source + ((_target - _source) * _t)
};

GAIT_fnc_releaseStrideReference = {
    params ["_unit", "_animation", "_grade"];
    private _reference = [_unit, _animation, _grade] call GAIT_fnc_releaseClipReference;
    private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
    private _target = _unit getVariable ["GAIT_slopeEntryTarget", ""];
    if (_source isEqualTo "" || {_target isEqualTo ""} ||
        {!([_animation, _source, _target] call GAIT_fnc_isLocomotionHandoffBlend)}) exitWith {_reference};
    private _from = [_unit, _source, _grade] call GAIT_fnc_releaseClipReference;
    private _to = [_unit, _target, _grade] call GAIT_fnc_releaseClipReference;
    [_from, _to, (([_unit] call GAIT_fnc_readPaceMoveInfo) param [3, 1])]
        call GAIT_fnc_blendedStrideReference
};

GAIT_fnc_releasePlanValid = {
    params ["_plan", "_now", "_start", "_weapon", "_destination"];
    (count _plan) isEqualTo 9 && {_now >= (_plan select 0)} && {_now - (_plan select 0) <= 0.20} &&
        {_start isEqualTo (_plan select 1)} && {_weapon isEqualTo (_plan select 2)} &&
        {toLower _destination isEqualTo toLower (_plan select 3)}
};

GAIT_fnc_releasePlaybackRate = {
    params ["_speed", "_reference", "_animation"];
    private _name = toLower _animation;
    private _divider = _name find "_amov";
    if (_divider >= 0) then {_name = _name select [_divider + 1];};
    private _pace = _name select [8, 4];
    private _minimum = 0.2;
    private _maximum = [1.20, 1.15] select (_pace in ["mwlk", "mtac"]);
    (_speed / (_reference max 0.1)) max _minimum min _maximum
};

GAIT_fnc_sprintReleaseCoefficient = {
    params ["_unit", "_release", "_animation", "_destinationClip", "_grade", "_destinationCoefficient",
        ["_reference", -1, [0]], ["_plannedSpeed", -1, [0]]];
    _release params ["_start", "_startMS", ["_slopeScale", 1]];
    private _progress = [_start, diag_tickTime, _slopeScale] call GAIT_fnc_sprintWalkProgress;
    private _destinationReference = [_unit, _destinationClip, _grade] call GAIT_fnc_releaseClipReference;
    private _paceMS = _plannedSpeed;
    if (_paceMS < 0) then {
        _paceMS = [_release, _destinationCoefficient * _destinationReference, _progress] call GAIT_fnc_sprintReleaseSpeed;
    };
    if (_reference <= 0) then {
        _reference = [_unit, _animation, _grade] call GAIT_fnc_releaseStrideReference;
    };
    // The new clip's root motion can start before its pose blend ends.
    // In that interval using the outgoing reference underdrives the walk.
    [_paceMS, _reference, _animation] call GAIT_fnc_releasePlaybackRate
};

GAIT_fnc_limitStanceTravelSpeed = {
    params ["_now", "_weapon", "_speed", "_limit"];
    _limit params [["_until", -1], ["_sameWeapon", ""], ["_previousSpeed", 0]];
    if (_now <= _until && {_weapon isEqualTo _sameWeapon}) exitWith {_speed min _previousSpeed};
    _speed
};

GAIT_fnc_stanceTravelReference = {
    params ["_unit", "_animation", "_handoff", "_grade"];
    _handoff params ["_source", "_target"];
    private _from = [_unit, _source, _grade] call GAIT_fnc_releaseClipReference;
    // animationState can still report the source on the first blend frame.
    if ((toLower _animation) isEqualTo (toLower _source)) exitWith {_from};
    private _to = [_unit, _target, _grade] call GAIT_fnc_releaseClipReference;
    private _targetSprint = (toLower _target select [8, 4]) in ["meva", "mspr"] ||
        {"gaitsprint" in (toLower _target splitString "_")};
    if (_targetSprint) exitWith {
        // The faster stride may already drive the mixed state while the pose is still blending.
        if (toLower _animation isEqualTo toLower _target) then {_to} else {_from max _to}
    };
    private _weight = (([_unit] call GAIT_fnc_readPaceMoveInfo) param [3, 1]) max 0 min 1;
    _from + ((_to - _from) * _weight)
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
    if !(_family in ["sraswrfl", "slowwrfl", "sraswpst", "slowwpst", "snonwnon", "sraswlnr"]) exitWith {[]};
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
    [_elapsed, -1] select (_elapsed >= 4.10)
};

// Hold the peak target through acceleration, then ease out over 2.2
// seconds. If reserve drains quickly, finish tapering by half reserve.
GAIT_fnc_deadSprintStrength = {
    params ["_elapsed", "_reserve"];
    if (_elapsed < 0) exitWith {0};
    private _time = ((4.10 - _elapsed) / 2.20) max 0 min 1;
    private _remaining = ((_reserve - 0.50) / 0.25) max 0 min 1;
    private _strength = _time min _remaining;
    _strength * _strength * (3 - (2 * _strength))
};

// Normal sprint pace holds after the rested burst until half reserve,
// then tapers toward the load-scaled floor.
GAIT_fnc_sprintReservePace = {
    params ["_fresh", "_normalRun", "_reserve", ["_gearLbs", 0, [0]],
        ["_sprintMinimum", 0, [0]], ["_exhaustedRunPace", 0.70, [0]],
        ["_flatGround", false, [false]], ["_flatPeak", 1.14, [0]], ["_deadSprintStrength", 0, [0]]];
    private _loadFraction = (_gearLbs / 100) max 0 min 1;
    private _exhaustedRatio = ((_exhaustedRunPace + 0.05) - (0.10 * _loadFraction)) max 0 min 1;
    private _floor = (_normalRun * _exhaustedRatio) max _sprintMinimum;
    private _normalTarget = _fresh max _floor;
    if (_flatGround && {_reserve > 0.50} && {_deadSprintStrength > 0}) exitWith {
        private _mass = _gearLbs max 0;
        private _burstLoadScale = 1 - (0.8 * (_mass / (_mass + 110)));
        private _bonus = ((_flatPeak - 1) max 0) * (_deadSprintStrength min 1) * _burstLoadScale;
        (_fresh * (1 + _bonus)) max _floor
    };
    if (_reserve >= 0.50) exitWith {_normalTarget};
    private _remaining = (_reserve / 0.50) max 0;
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

GAIT_fnc_combatRelativeSprintFloor = {
    params ["_combatCoefficient", "_combatReference", "_sprintReference", "_rawSprintScale", "_gearLbs"];
    private _combatToSprint = 0.74 * _rawSprintScale;
    if (_combatReference > 0 && {_sprintReference > 0}) then {
        _combatToSprint = _combatReference / _sprintReference;
    };
    private _load = (_gearLbs / 150) max 0 min 1;
    // Keep a small margin at every load, even when this floor sets the pace.
    _combatCoefficient * _combatToSprint * (1.08 - (0.03 * _load))
};

GAIT_fnc_ordinaryJogFloor = {
    params ["_walkCoefficient", "_walkReference", "_combatReference", "_jogReference"];
    private _walkToJog = 0.50;
    private _combatToJog = 0.75;
    if (_jogReference > 0) then {
        if (_walkReference > 0) then {_walkToJog = _walkReference / _jogReference;};
        if (_combatReference > 0) then {_combatToJog = _combatReference / _jogReference;};
    };
    // Deliberate walking and combat pace keep their own clips. This floor
    // makes the ordinary jog slightly faster when mass would drop it below.
    ((_walkCoefficient * _walkToJog) max _combatToJog) * 1.04
};
