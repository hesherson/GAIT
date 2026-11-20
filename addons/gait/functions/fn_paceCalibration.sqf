/*
    Passive, session-local animation pace measurements.
    References are observed metres/second per applied animation coefficient,
    scoped to exact clip/config, weapon, surface and a narrow grade band.

    getUnitMovesInfo index 3 is the move blend factor:
    https://community.bistudio.com/wiki/getUnitMovesInfo
*/
GAIT_fnc_paceObservationStep = {
    params ["_state", "_key", "_now", "_reference", "_coefficient", "_valid"];
    if (!_valid || {!(_reference > 0.1 && {_reference < 25})} ||
        {!(_coefficient > 0.05 && {_coefficient < 5})}) exitWith {[[], -1]};
    if ((count _state) != 7) exitWith {[[_key, _now, _now, _reference, _coefficient, [], _now], -1]};
    _state params ["_oldKey", "_start", "_last", "_prior", "_priorCoefficient", "_samples", "_blockStart"];
    private _dt = _now - _last;
    if (_oldKey isNotEqualTo _key || {_dt <= 0} || {_dt > 0.2} ||
        {abs (_reference / _prior - 1) > 0.08} ||
        {abs (_coefficient / _priorCoefficient - 1) > 0.01}) exitWith {
        [[_key, _now, _now, _reference, _coefficient, [], _now], -1]
    };
    private _accepted = -1;
    // Let entry/acceleration settle, then collect at least three spaced samples.
    if (_now - _start >= 0.8 && {_now - _blockStart >= 0.35}) then {
        _samples pushBack _reference;
        _blockStart = _now;
        if ((count _samples) >= 3) then {
            private _sorted = +_samples;
            _sorted sort true;
            private _median = _sorted select 1;
            if (((_sorted select 2) - (_sorted select 0)) / _median <= 0.06) then {_accepted = _median;};
            _samples = [];
        };
    };
    [[_key, _start, _now, _reference, _coefficient, _samples, _blockStart], _accepted]
};

GAIT_fnc_paceReferenceKey = {
    params ["_unit", "_clip"];
    private _cfg = configFile >> "CfgMovesMaleSdr" >> "States" >> _clip;
    [toLower _clip, getText (_cfg >> "file"), getNumber (_cfg >> "speed"),
        typeOf _unit, currentWeapon _unit, surfaceType (getPosATL _unit)]
};

GAIT_fnc_observePaceCalibration = {
    params ["_unit", "_input"];
    if (isNull _unit || {!local _unit} || {!alive _unit}) exitWith {};
    private _now = diag_tickTime;
    if (_now < (_unit getVariable ["GAIT_paceNextSample", 0])) exitWith {};
    _unit setVariable ["GAIT_paceNextSample", _now + 0.05];
    private _clip = toLower animationState _unit;
    if (_clip isEqualTo "") exitWith {_unit setVariable ["GAIT_paceObservation", []];};
    private _base = (_clip splitString "_") select 0;
    private _ordinary = (_base select [0,8]) in ["amovperc", "amovpknl"] &&
        {(_base select [8,4]) in ["mrun", "mwlk", "mtac", "meva", "mspr"]} &&
        {(_base select [12,8]) in ["sraswrfl", "slowwrfl", "sraswpst", "slowwpst", "snonwnon", "sraswlnr", "slowwlnr"]} &&
        {(_base select [20]) in ["df", "dfl", "dfr"]};
    private _info = [_unit] call GAIT_fnc_readPaceMoveInfo;
    private _coefficient = getAnimSpeedCoef _unit;
    private _v = velocity _unit;
    private _speed = sqrt ((_v select 0)^2 + (_v select 1)^2);
    private _grade = missionNamespace getVariable ["GAIT_smoothedSlopeDegrees", 0];
    private _key = [_unit, _clip] call GAIT_fnc_paceReferenceKey;
    private _heading = getDir _unit;
    private _priorHeading = _unit getVariable ["GAIT_pacePriorHeading", _heading];
    _unit setVariable ["GAIT_pacePriorHeading", _heading];
    private _gesture = toLower gestureState _unit;
    private _eligible = _ordinary && {(_clip find "_amov") < 0} &&
        {(_input select 0) > 0.95} && {call GAIT_fnc_modeAllowsMovement} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible} &&
        {isTouchingGround _unit} && {(stance _unit) in ["STAND", "CROUCH"]} &&
        {(_info param [3, 0]) >= 0.99} && {_speed > 0.3} &&
        {abs (((_heading - _priorHeading + 540) mod 360) - 180) < 2} &&
        {(["reload", "melee", "throw"] findIf {(_gesture find _x) >= 0}) < 0} &&
        {!(missionNamespace getVariable ["GAIT_braceActive", false])} &&
        {(missionNamespace getVariable ["GAIT_vegDragFactor", 0]) < 0.01} &&
        {damage _unit < 0.01} && {abs _grade < 70};
    if (_eligible) then {
        private _from = (getPosASL _unit) vectorAdd [0, 0, 0.5];
        private _ahead = _from vectorAdd ((_v vectorMultiply (1 / (_speed max 0.1))) vectorMultiply 1.5);
        if (lineIntersects [_from, _ahead, _unit, objNull]) then {_eligible = false;};
    };
    // Grade is part of the sample identity; never average across a hill crest.
    private _sampleKey = _key + [round (_grade / 2)];
    private _step = [_unit getVariable ["GAIT_paceObservation", []], _sampleKey, _now,
        _speed / (_coefficient max 0.001), _coefficient, _eligible] call GAIT_fnc_paceObservationStep;
    _unit setVariable ["GAIT_paceObservation", _step select 0];
    if ((_step select 1) > 0) then {
        private _cache = _unit getVariable ["GAIT_paceMeasurements", []];
        private _index = _cache findIf {(_x select 0) isEqualTo _key && {abs ((_x select 2) - _grade) <= 2}};
        private _entry = [_key, _step select 1, _grade, _now];
        if (_index < 0) then {_cache pushBack _entry;} else {_cache set [_index, _entry];};
        if ((count _cache) > 48) then {_cache deleteAt 0;};
        _unit setVariable ["GAIT_paceMeasurements", _cache];
    };
};

GAIT_fnc_lookupPaceReference = {
    params ["_cache", "_key", "_grade", "_now"];
    private _reference = -1;
    private _bestGrade = 3;
    private _newest = -1;
    {
        if ((count _x) isEqualTo 4) then {
            _x params ["_candidateKey", "_candidate", "_candidateGrade", "_sampledAt"];
            private _difference = abs (_candidateGrade - _grade);
            if (_candidateKey isEqualTo _key && {_difference <= 2} &&
                {_now >= _sampledAt} && {_now - _sampledAt <= 600} &&
                {_candidate > 0.1 && {_candidate < 25}} &&
                {_difference < _bestGrade || {_difference isEqualTo _bestGrade && {_sampledAt > _newest}}}) then {
                _reference = _candidate;
                _bestGrade = _difference;
                _newest = _sampledAt;
            };
        };
    } forEach _cache;
    _reference
};

// Reuse the same guarded passive cache for steady physical targets. This is
// historical evidence from stable travel, never the current live velocity.
GAIT_fnc_lookupUnitPaceReference = {
    params [
        ["_unit", objNull, [objNull]],
        ["_clip", "", [""]],
        ["_grade", 0, [0]]
    ];
    if (isNull _unit || {_clip isEqualTo ""}) exitWith {-1};
    private _key = [_unit, toLower _clip] call GAIT_fnc_paceReferenceKey;
    private _cache = _unit getVariable ["GAIT_paceMeasurements", []];
    [_cache, _key, _grade, diag_tickTime] call GAIT_fnc_lookupPaceReference
};

GAIT_fnc_sameClipPaceReference = {
    params ["_reference", "_sourceFile", "_sourceRate", "_targetFile", "_targetRate"];
    if (_reference <= 0 || {_sourceFile isEqualTo ""} ||
        {toLower _sourceFile isNotEqualTo toLower _targetFile} ||
        {abs _sourceRate <= 0.001} || {abs _targetRate <= 0.001} ||
        {(_sourceRate < 0) isNotEqualTo (_targetRate < 0)}) exitWith {-1};
    // Negative config values specify clip durations in seconds.
    private _ratio = [_targetRate / _sourceRate, _sourceRate / _targetRate] select (_sourceRate < 0);
    _reference * _ratio
};

GAIT_fnc_combatPaceReference = {
    params ["_unit", "_family", "_direction", "_grade", "_jogClip", "_jogReference", ["_pose", "Perc"]];
    private _base = "Amov" + _pose + "Mtac" + _family + _direction;
    private _clips = [_base];
    if (_family isEqualTo "SlowWrfl" && {!(_pose isEqualTo "Perc" &&
        {missionNamespace getVariable ["GAIT_animateWalkLoaded", false]})}) then {
        _clips pushBack (_base + "_ver2");
    };
    private _states = configFile >> "CfgMovesMaleSdr" >> "States";
    private _jog = _states >> _jogClip;
    private _reference = -1;
    {
        private _tactical = _states >> _x;
        if (isClass _tactical) then {
            private _observed = [_unit, _x, _grade] call GAIT_fnc_lookupUnitPaceReference;
            if (_observed <= 0 && {_jogReference > 0}) then {
                // ACE lowered tactical jog can use the ordinary jog RTM at a different rate.
                _observed = [_jogReference, getText (_jog >> "file"), getNumber (_jog >> "speed"),
                    getText (_tactical >> "file"), getNumber (_tactical >> "speed")] call GAIT_fnc_sameClipPaceReference;
            };
            _reference = _reference max _observed;
        };
    } forEach _clips;
    _reference
};

// Prefer a complete externally supplied profile when present. Otherwise a
// valid passive reference for the exact moving clip is sufficient to convert a
// physical target without inventing a walk reference or feeding back velocity.
GAIT_fnc_resolveMovingPaceReference = {
    params [
        ["_resolved", [], [[]]],
        ["_passiveReference", -1, [0]]
    ];
    if ((count _resolved) >= 5 && {_resolved select 4} &&
        {(_resolved select 1) > 0} && {(_resolved select 3) > 0}) exitWith {
        (_resolved select 3) / (_resolved select 1)
    };
    if (_passiveReference > 0.1 && {_passiveReference < 25}) exitWith {_passiveReference};
    -1
};
