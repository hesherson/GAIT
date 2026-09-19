/*
    Passive, session-local animation pace measurements and release handoffs.
    References are observed metres/second per applied animation coefficient,
    scoped to exact clip/config, weapon, surface and a narrow grade band.
    No guessed speeds, persisted cross-mod profiles, velocity or input writes.
    Missing evidence keeps the alpha10 release path.

    getUnitMovesInfo indices 0 (normalized phase), 3 (move blend factor):
    https://community.bistudio.com/wiki/getUnitMovesInfo
    Blend compensation is a two-clip root-motion model, not velocity feedback.
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

GAIT_fnc_measuredReleaseTarget = {
    params ["_speed", "_applied", "_ordinary", "_destinationReference"];
    if (!(_speed > 0.05) || {!(_applied > 0.05)} ||
        {!(_ordinary > 0.05)} || {!(_destinationReference > 0.1 && {_destinationReference < 25})}) exitWith {[]};
    private _sourceReference = _speed / _applied;
    private _ratio = _destinationReference / _sourceReference;
    // Refuse implausible/contaminated measurements, including collision stalls.
    if (_ratio < 0.25 || {_ratio > 1.25}) exitWith {[]};
    private _targetMS = (_ordinary * _destinationReference) min _speed;
    [_targetMS / _sourceReference, _sourceReference, _targetMS]
};

GAIT_fnc_paceBlendCoefficient = {
    params ["_sourceReference", "_destinationReference", "_physicalTarget", "_weight"];
    if (!(_sourceReference > 0.1 && {_sourceReference < 25}) ||
        {!(_destinationReference > 0.1 && {_destinationReference < 25})} ||
        {!(_physicalTarget >= 0 && {_physicalTarget < 100})} ||
        {!(_weight >= 0 && {_weight <= 1})}) exitWith {-1};
    _physicalTarget / (_sourceReference + ((_destinationReference - _sourceReference) * _weight))
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
    private _ordinary = (_base select [0,8]) isEqualTo "amovperc" &&
        {(_base select [8,4]) in ["mrun", "mwlk", "meva"]} &&
        {(_base select [12,8]) in ["sraswrfl", "slowwrfl", "sraswpst", "slowwpst", "snonwnon"]} &&
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
        {isTouchingGround _unit} && {(stance _unit) isEqualTo "STAND"} &&
        {(_info param [3, 0]) >= 0.99} && {_speed > 0.3} &&
        {abs (((_heading - _priorHeading + 540) mod 360) - 180) < 2} &&
        {(["reload", "melee", "throw"] findIf {(_gesture find _x) >= 0}) < 0} &&
        {!(_unit getVariable ["GAIT_releaseMomentumActive", false])} &&
        {(_unit getVariable ["GAIT_paceHandoff", []]) isEqualTo []} &&
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

GAIT_fnc_releasePaceMatch = {
    params ["_unit", "_animation", "_family", "_direction", "_speed", "_applied", "_ordinary"];
    private _target = toLower ("AmovPercMrun" + _family + _direction);
    private _key = [_unit, _target] call GAIT_fnc_paceReferenceKey;
    private _grade = missionNamespace getVariable ["GAIT_smoothedSlopeDegrees", 0];
    private _now = diag_tickTime;
    private _cache = _unit getVariable ["GAIT_paceMeasurements", []];
    private _measured = [_cache, _key, _grade, _now] call GAIT_fnc_lookupPaceReference;
    if (_measured < 0 || {damage _unit >= 0.01}) exitWith {[]};
    private _reference = _measured * (1 - (missionNamespace getVariable ["GAIT_vegDragFactor", 0]));
    private _resolved = [_speed, _applied, _ordinary, _reference] call GAIT_fnc_measuredReleaseTarget;
    if (_resolved isEqualTo []) exitWith {[]};
    [_resolved select 0, [toLower _animation, _target, _resolved select 1,
        _reference, _resolved select 2, currentWeapon _unit, _direction, _key select 5, _grade]]
};

GAIT_fnc_beginPaceHandoff = {
    params ["_unit", "_source", "_target"];
    private _candidate = _unit getVariable ["GAIT_paceHandoffCandidate", []];
    _unit setVariable ["GAIT_paceHandoffCandidate", []];
    if ((count _candidate) != 2 || {diag_tickTime > (_candidate select 1)}) exitWith {};
    private _match = _candidate select 0;
    if ((_match select 0) isNotEqualTo toLower _source ||
        {(_match select 1) isNotEqualTo toLower _target}) exitWith {};
    _unit setVariable ["GAIT_paceHandoff", [_match, diag_tickTime + 0.5, false]];
};

GAIT_fnc_clearPaceHandoff = {
    params ["_unit"];
    if (!isNull _unit) then {
        _unit setVariable ["GAIT_paceHandoff", []];
        _unit setVariable ["GAIT_paceHandoffCandidate", []];
        _unit setVariable ["GAIT_releaseResume", []];
    };
};

GAIT_fnc_paceHandoffContext = {
    params ["_unit", "_match", "_deadline"];
    _match params ["_source", "_target", "_sourceReference", "_targetReference", "_targetMS", "_weapon", "_direction", "_surface", "_grade"];
    private _input = [] call GAIT_fnc_getMovementInput;
    private _safe = diag_tickTime <= _deadline && {call GAIT_fnc_modeAllowsMovement} &&
        {missionNamespace getVariable ["GAIT_ss_shiftReleaseRunTaperEnabled", true]} &&
        {missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", true]} &&
        {missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", true]} &&
        {(_input select 0) > 0.05} &&
        {([_input select 0, _input select 1] call GAIT_fnc_slopeDirection) isEqualTo _direction} &&
        {currentWeapon _unit isEqualTo _weapon} && {isTouchingGround _unit} &&
        {isSprintAllowed _unit} && {!isForcedWalk _unit} &&
        {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
        {(_unit getVariable ["ace_common_effect_forceWalk", 0]) <= 0} &&
        {[_unit, false] call GAIT_fnc_nativeMovementEligible} &&
        {_unit isEqualTo (missionNamespace getVariable ["GAIT_nativeOwner", objNull])} &&
        {abs (getAnimSpeedCoef _unit - (missionNamespace getVariable ["GAIT_nativeLastWritten", -1])) < 0.001} &&
        {(surfaceType (getPosATL _unit)) isEqualTo _surface} &&
        {abs ((missionNamespace getVariable ["GAIT_smoothedSlopeDegrees", 0]) - _grade) <= 2};
    [_safe, _input select 2, toLower animationState _unit, [_unit] call GAIT_fnc_readPaceMoveInfo]
};

GAIT_fnc_samplePaceHandoff = {
    params ["_unit", "_coefficient"];
    private _state = _unit getVariable ["GAIT_paceHandoff", []];
    if ((count _state) != 3) exitWith {_coefficient};
    _state params ["_match", "_deadline", "_reversing"];
    _match params ["_source", "_target", "_sourceReference", "_targetReference", "_targetMS", "_weapon", "_direction", "_surface", "_grade"];
    private _context = [_unit, _match, _deadline] call GAIT_fnc_paceHandoffContext;
    _context params ["_safe", "_turbo", "_animation", "_info"];
    if (!_safe) exitWith {[_unit] call GAIT_fnc_clearPaceHandoff; _coefficient};
    if (_turbo isNotEqualTo _reversing) then {
        _reversing = _turbo;
        _state set [2, _reversing];
        _unit setVariable ["GAIT_paceHandoff", _state];
        if (_reversing) then {
            _unit setVariable ["GAIT_releaseResume", [_targetMS / _sourceReference, diag_tickTime]];
        } else {
            _unit setVariable ["GAIT_releaseResume", []];
        };
    };
    private _weight = -1;
    if (_animation isEqualTo _source) then {_weight = 1 - (_info param [3, 1]);};
    if (_animation isEqualTo _target) then {_weight = _info param [3, 1];};
    // Explicit transition clips report their own phase, not a target weight.
    if (_animation isEqualTo (_source + "_" + _target)) then {_weight = _info param [0, -1];};
    if (_animation isEqualTo (_target + "_" + _source)) then {_weight = 1 - (_info param [0, -1]);};
    if (_weight < 0 || {_weight > 1}) exitWith {[_unit] call GAIT_fnc_clearPaceHandoff; _coefficient};
    private _matched = [_sourceReference, _targetReference, _targetMS, _weight] call GAIT_fnc_paceBlendCoefficient;
    if (_matched < 0) exitWith {[_unit] call GAIT_fnc_clearPaceHandoff; _coefficient};
    if ((!_reversing && {_weight >= 0.999}) || {_reversing && {_weight <= 0.001}}) then {
        [_unit] call GAIT_fnc_clearPaceHandoff;
        if (_reversing) then {_unit setVariable ["GAIT_releaseResume", [_matched, diag_tickTime]];};
    };
    _matched
};
