/*
    Read-only local diagnostic for the reported +/-32 degree boundary.
    Copy this file into an Eden mission folder; run in that mission's LOCAL
    debug console, on foot on unobstructed terrain:

      [90, "RC3 rifle uphill"] execVM "slope_threshold_probe.sqf";

    Hold forward+sprint across the boundary, then test W+A -> W+D and a
    downhill pass. Repeat with GAIT disabled as a separate labelled capture.
    Starting again removes the previous probe. Cancel at any time:

      GAIT_thresholdProbeEnabled = false;

    One EachFrame handler samples every rendered frame, retaining up to 0.5 s
    / 120 frames before a change and logging 0.75 s afterwards. Quiet periods
    log at 1 Hz. Trigger fields include animation, grounded/eligible/lock
    flags, input direction, GAIT ownership/pending flags and 32-degree bands.
    Duration is clamped to 10..180 s; 6000 physical sample/event lines is a hard
    capture limit. Up to 4000 configuration lines are emitted after cleanup.
    Cleanup runs on cancellation, timeout or that limit.
    Player replacement/respawn is recorded and handled automatically.

    This changes only its own missionNamespace bookkeeping and event handler.
    It does not issue movement commands or alter GAIT, ACE, fatigue or input.
    It works without GAIT/ACE; unavailable GAIT function results use -1.

    All RPT lines start [GAIT32]. Payloads are SQF arrays, not CSV.
    SCHEMA lists the positions in SAMPLE rows. Their seq/frame/tick values
    establish order; EVENT can precede an older buffered SAMPLE in the RPT.
    Each SAMPLE is printed at most once. Large records use
    CHUNK [recordId, kind, partIndex, totalParts, payloadString] (0-based);
    concatenate payloadString fragments to recover str(originalData). Payloads
    are limited to 400 characters so individual RPT lines remain bounded.
    Configuration names are collected on first sight; bulk config is read
    and emitted after STOP to avoid a burst of configuration reads and log
    writes during the movement test. STATE records resolved config and
    action destinations for the animation classes observed in the capture.
    CONFIG records effective inherited properties for that state, its native
    parent marker, and GAIT's pending entry source/target. Arrays are emitted
    in 24-item chunks with their total length, capped at 240 items/property;
    a truncation field identifies incomplete arrays. At most 24 distinct
    states receive CONFIG dumps, keeping the log bounded. Scalar action
    properties are logged with STATE. Unknown properties are marked missing.
    This samples once per frame; events occurring between samples can share
    one observed transition. It cannot prove the ordering of code producers
    within that frame. GAIT32_trialLabel, if present, labels graph experiments.

    Slope group: [surfaceNormal, unsignedSteepness, signedFacingGrade,
      signedRightGrade, signedInputGrade, signedVelocityGrade,
      terrainSampleGrade, gaitSmoothedGrade, feetHeightAboveTerrain].
    Normal grades come from the terrain plane; terrainSampleGrade uses a
    +/-2 m height sample in the intended direction (velocity/facing fallback).
    Terrain measurements do not describe buildings, bridges or model ramps.
    A HUD angle alone cannot establish the engine's own slope measurement.

    Engine group: [sprintAllowed, forcedWalk, grounded, stance, lifeState,
      alive, local, onFoot, unattached, aceBlockSprintMask, aceForceWalkMask,
      nativeStamina, nativeFatigue, nativeStaminaEnabled].
    GAIT group: [eligibleNoCarry, eligibleAllowCarry, suspended, modeAllows,
      ownerIsPlayer, ownerText, activeGlobal, activeUnit, attemptLatched,
      failureReported, exitPending, entryDeadline, cancelDeadline,
      entrySource, entryTarget, attemptFamily, attemptWeapon, expectedBlend].
    Context group: [aceUnconscious, gaitTripping, carryPickup, dragging,
      beingDragged, beingCarried, carrying, climbingUnit, climbingMission,
      treatmentUnit, treatmentMission, cameraIsPlayer, currentWeapon,
      weaponLowered, display312Open].
    Velocity group: [worldVelocity, horizontalMS, terrainTangentMS,
      actualForwardMS, actualRightMS, animationSpeedCoef].
    Settings group: [slopeHandling, slopeLocomotion, ACE AF enabled,
      walkTargetCoef, sprintTargetCoef, loadAbs, gaitLoadAbsPerLb].
    Effective settings remain available in the addon config; this probe
    intentionally avoids changing them to force a result.
*/

if (!hasInterface) exitWith {};
params [["_duration", 90, [0]], ["_label", "unlabelled", [""]]];
_duration = _duration max 10 min 180;

private _oldHandler = missionNamespace getVariable ["GAIT_thresholdProbeHandler", -1];
if (_oldHandler >= 0) then {
    missionNamespace setVariable ["GAIT_thresholdProbeEnabled", false];
    private _restartDeadline = diag_tickTime + 1;
    waitUntil {
        uiSleep 0.01;
        (missionNamespace getVariable ["GAIT_thresholdProbeHandler", -1]) < 0 || {diag_tickTime >= _restartDeadline}
    };
    if ((missionNamespace getVariable ["GAIT_thresholdProbeHandler", -1]) >= 0) then {
        removeMissionEventHandler ["EachFrame", _oldHandler];
        diag_log "[GAIT32] STOP restart_timeout; previous configuration references were not dumped";
    };
};
missionNamespace setVariable ["GAIT_thresholdProbeEnabled", true];
missionNamespace setVariable ["GAIT_thresholdProbeState", createHashMapFromArray [
    ["label", _label], ["deadline", diag_tickTime + _duration],
    ["seq", 0], ["logged", createHashMap], ["lines", 0], ["recordId", 0],
    ["buffer", []], ["signature", []], ["postUntil", -1],
    ["heartbeat", -1], ["lineLimitReached", false],
    ["configStates", createHashMap], ["configCount", 0], ["configRefs", []]
]];

diag_log format ["[GAIT32] START %1", [_label, _duration, productVersion, worldName, missionNamespace getVariable ["GAIT_versionString", "unavailable"]]];
diag_log '[GAIT32] SCHEMA [seq,frame,tick,missionTime,label,unit,positionASL,slope,input,rawInput,animation,actions,gesture,engine,gait,context,velocity,settings,trialLabel]';
diag_log '[GAIT32] EVENT_SCHEMA [seq,tick,changedSignatureFields]';
diag_log '[GAIT32] STATE_SCHEMA [moves,animation,classExists,actions,actionsExist,nativeState,customMarker,animationFile,animationConfigSpeed,selectorDestinations,actionProperties]';
diag_log '[GAIT32] CONFIG_SCHEMA [moves,state,classExists,parentClass,scalarProperties]; CONFIG_ARRAY_SCHEMA [moves,state,property,totalItems,chunkOffset,truncated,items]';

private _handler = addMissionEventHandler ["EachFrame", {
    private _state = missionNamespace getVariable ["GAIT_thresholdProbeState", createHashMap];
    private _now = diag_tickTime;
    private _emit = {
        params ["_kind", "_data", ["_limit", _state getOrDefault ["emitLimit", 6000]]];
        private _payload = str _data;
        private _parts = ceil ((count _payload) / 400);
        _parts = _parts max 1;
        if (((_state get "lines") + _parts) > _limit) exitWith {
            _state set ["lineLimitReached", true];
            false
        };
        private _recordId = (_state get "recordId") + 1;
        _state set ["recordId", _recordId];
        if (_parts isEqualTo 1) then {
            diag_log format ["[GAIT32] %1 %2", _kind, _payload];
        } else {
            for "_part" from 0 to (_parts - 1) do {
                diag_log format ["[GAIT32] CHUNK %1", [_recordId, _kind, _part, _parts, _payload select [_part * 400, 400]]];
            };
        };
        _state set ["lines", (_state get "lines") + _parts];
        true
    };
    private _stop = "";
    if !(missionNamespace getVariable ["GAIT_thresholdProbeEnabled", false]) then {_stop = "cancelled";};
    if (_now >= (_state getOrDefault ["deadline", -1])) then {_stop = "duration";};
    if ((_state getOrDefault ["lines", 0]) >= 6000 || {_state getOrDefault ["lineLimitReached", false]}) then {_stop = "line_limit";};
    if (_stop isNotEqualTo "") exitWith {
        private _id = missionNamespace getVariable ["GAIT_thresholdProbeHandler", -1];
        if (_id >= 0) then {removeMissionEventHandler ["EachFrame", _id];};
        diag_log format ["[GAIT32] STOP %1", [_stop, _state getOrDefault ["seq", 0], _state getOrDefault ["lines", 0]]];
        private _configLimit = (_state getOrDefault ["lines", 0]) + 4000;
        _state set ["emitLimit", _configLimit];
        _state set ["lineLimitReached", false];
        private _configValue = {
            params ["_config", "_property"];
            private _entry = _config >> _property;
            if (isText _entry) exitWith {[_property, "text", getText _entry]};
            if (isNumber _entry) exitWith {[_property, "number", getNumber _entry]};
            if (isArray _entry) exitWith {[_property, "array", getArray _entry]};
            [_property, "missing", ""]
        };
        {
            if ((_state getOrDefault ["lines", 0]) >= _configLimit || {_state getOrDefault ["lineLimitReached", false]}) exitWith {};
            _x params ["_moves", "_animation"];
            private _stateConfig = configFile >> _moves >> "States" >> _animation;
            private _actions = getText (_stateConfig >> "actions");
            private _actionConfig = configFile >> "CfgMovesBasic" >> "Actions" >> _actions;
            private _destinations = [];
            {
                _destinations pushBack [_x, getText (_actionConfig >> _x)];
            } forEach ["Default", "Stop", "StopRelaxed", "TurnL", "TurnR", "WalkF", "PlayerWalkF", "SlowF", "PlayerSlowF", "FastF", "PlayerFastF", "TactF", "PlayerTactF", "PlayerWalkL", "PlayerWalkR", "PlayerSlowL", "PlayerSlowR", "PlayerFastL", "PlayerFastR"];
            private _actionProperties = ["useFastMove", "upDegree"] apply {[_actionConfig, _x] call _configValue};
            ["STATE", [_moves, _animation, isClass _stateConfig, _actions, isClass _actionConfig, getText (_stateConfig >> "GAIT_nativeState"), getNumber (_stateConfig >> "GAIT_slopeState"), getText (_stateConfig >> "file"), getNumber (_stateConfig >> "speed"), _destinations, _actionProperties]] call _emit;
            private _scalarProperties = ["actions", "file", "speed", "duty", "limitGunMovement", "enableDirectControl", "interpolationSpeed", "walkCycles", "variantAfter", "equivalentTo", "looped", "interpolationRestart", "soundOverride", "soundEdge", "legs"] apply {[_stateConfig, _x] call _configValue};
            ["CONFIG", [_moves, _animation, isClass _stateConfig, configName (inheritsFrom _stateConfig), _scalarProperties]] call _emit;
            {
                private _property = _x;
                private _array = getArray (_stateConfig >> _property);
                private _total = count _array;
                if (_total isEqualTo 0) then {
                    ["CONFIG_ARRAY", [_moves, _animation, _property, 0, 0, false, []]] call _emit;
                } else {
                    for "_offset" from 0 to ((_total min 240) - 1) step 24 do {
                        ["CONFIG_ARRAY", [_moves, _animation, _property, _total, _offset, _total > 240, _array select [_offset, 24]]] call _emit;
                    };
                };
            } forEach ["connectTo", "interpolateTo", "interpolateFrom", "variantsPlayer", "variantsAI"];
        } forEach (_state getOrDefault ["configRefs", []]);
        diag_log format ["[GAIT32] END %1", [_state getOrDefault ["lines", 0], "configuration flushed after capture", _state getOrDefault ["lineLimitReached", false]]];
        missionNamespace setVariable ["GAIT_thresholdProbeEnabled", false];
        missionNamespace setVariable ["GAIT_thresholdProbeHandler", -1];
        missionNamespace setVariable ["GAIT_thresholdProbeState", nil];
    };

    private _unit = player;
    if (isNull _unit) exitWith {};
    private _rawInput = [inputAction "MoveForward", inputAction "MoveBack", inputAction "TurnLeft", inputAction "TurnRight", inputAction "Turbo"];
    private _inputF = (_rawInput select 0) - (_rawInput select 1);
    private _inputR = (_rawInput select 3) - (_rawInput select 2);
    if (abs _inputF <= 0.05) then {_inputF = 0;};
    if (abs _inputR <= 0.05) then {_inputR = 0;};
    private _inputMagnitude = sqrt (_inputF * _inputF + _inputR * _inputR);
    if (_inputMagnitude > 1) then {_inputF = _inputF / _inputMagnitude; _inputR = _inputR / _inputMagnitude;};
    private _input = [_inputF, _inputR, (_rawInput select 4) > 0];

    private _position = getPosASL _unit;
    private _normal = surfaceNormal _position;
    private _normalZ = (_normal select 2) max 0.00001;
    private _steepness = acos (((_normal select 2) max -1) min 1);
    private _facing = vectorDir _unit;
    _facing set [2, 0];
    private _magnitude = vectorMagnitude _facing;
    if (_magnitude < 0.001) then {
        _facing = [sin (getDir _unit), cos (getDir _unit), 0];
    } else {_facing = _facing vectorMultiply (1 / _magnitude);};
    private _right = [_facing select 1, -(_facing select 0), 0];
    private _velocity = velocity _unit;
    private _horizontalVelocity = [_velocity select 0, _velocity select 1, 0];
    private _horizontalSpeed = vectorMagnitude _horizontalVelocity;
    private _travel = (_facing vectorMultiply _inputF) vectorAdd (_right vectorMultiply _inputR);
    _magnitude = vectorMagnitude _travel;
    if (_magnitude < 0.001) then {
        _travel = +_horizontalVelocity;
        _magnitude = _horizontalSpeed;
        if (_magnitude < 0.1) then {_travel = +_facing; _magnitude = 1;};
    };
    _travel = _travel vectorMultiply (1 / _magnitude);
    private _facingGrade = atan (-(_normal vectorDotProduct _facing) / _normalZ);
    private _rightGrade = atan (-(_normal vectorDotProduct _right) / _normalZ);
    private _travelGrade = atan (-(_normal vectorDotProduct _travel) / _normalZ);
    private _velocityGrade = 0;
    if (_horizontalSpeed > 0.05) then {
        _velocityGrade = atan (-(_normal vectorDotProduct (_horizontalVelocity vectorMultiply (1 / _horizontalSpeed))) / _normalZ);
    };
    private _offset = _travel vectorMultiply 2;
    private _sampleGrade = atan (((getTerrainHeightASL (_position vectorAdd _offset)) - (getTerrainHeightASL (_position vectorDiff _offset))) / 4);
    private _surfaceVelocity = _velocity vectorDiff (_normal vectorMultiply (_velocity vectorDotProduct _normal));

    private _animation = animationState _unit;
    private _moves = getText (configOf _unit >> "moves");
    if (_moves isEqualTo "") then {_moves = "CfgMovesMaleSdr";};
    private _stateConfig = configFile >> _moves >> "States" >> _animation;
    private _actions = getText (_stateConfig >> "actions");
    private _configCache = _state get "configStates";
    {
        private _name = _x;
        private _key = _moves + ":" + _name;
        if (_name isNotEqualTo "" && {!(_configCache getOrDefault [_key, false])} && {(_state get "configCount") < 24}) then {
            _configCache set [_key, true];
            _state set ["configCount", (_state get "configCount") + 1];
            (_state get "configRefs") pushBack [_moves, _name];
        };
    } forEach [_animation, getText (_stateConfig >> "GAIT_nativeState"), _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""]];

    private _eligible = -1;
    private _eligibleCarry = -1;
    private _suspended = -1;
    private _modeAllows = -1;
    private _expectedBlend = -1;
    if !(isNil "GAIT_fnc_nativeMovementEligible") then {
        _eligible = [_unit, false] call GAIT_fnc_nativeMovementEligible;
        _eligibleCarry = [_unit, true] call GAIT_fnc_nativeMovementEligible;
    };
    if !(isNil "GAIT_fnc_isSuspendedContext") then {_suspended = [] call GAIT_fnc_isSuspendedContext;};
    if !(isNil "GAIT_fnc_modeAllowsMovement") then {_modeAllows = [] call GAIT_fnc_modeAllowsMovement;};
    private _source = _unit getVariable ["GAIT_slopeEntrySource", ""];
    private _target = _unit getVariable ["GAIT_slopeEntryTarget", ""];
    if !(isNil "GAIT_fnc_isStandingLocomotionBlend") then {
        _expectedBlend = [_animation, _source, _target] call GAIT_fnc_isStandingLocomotionBlend;
    };
    private _grounded = isTouchingGround _unit;
    private _sprintAllowed = isSprintAllowed _unit;
    private _forcedWalk = isForcedWalk _unit;
    private _aceSprint = _unit getVariable ["ace_common_effect_blockSprint", 0];
    private _aceWalk = _unit getVariable ["ace_common_effect_forceWalk", 0];
    private _stance = stance _unit;
    private _gesture = gestureState _unit;
    private _owner = missionNamespace getVariable ["GAIT_slopeOwner", objNull];
    private _active = missionNamespace getVariable ["GAIT_slopeLocomotionActive", false];
    private _latched = _unit getVariable ["GAIT_slopeAttemptLatched", false];
    private _failed = _unit getVariable ["GAIT_slopeFailureReported", false];
    private _exitPending = _unit getVariable ["GAIT_slopeExitPending", false];
    private _entryDeadline = _unit getVariable ["GAIT_slopeEntryDeadline", -1];
    private _cancelDeadline = _unit getVariable ["GAIT_slopeCancelDeadline", -1];
    private _seq = (_state get "seq") + 1;
    _state set ["seq", _seq];

    private _slope = [_normal, _steepness, _facingGrade, _rightGrade, _travelGrade, _velocityGrade, _sampleGrade, missionNamespace getVariable ["GAIT_smoothedSlopeDegrees", missionNamespace getVariable ["GAIT_slopeDegrees", -999]], (_position select 2) - (getTerrainHeightASL _position)];
    private _engine = [_sprintAllowed, _forcedWalk, _grounded, _stance, lifeState _unit, alive _unit, local _unit, isNull (objectParent _unit), isNull (attachedTo _unit), _aceSprint, _aceWalk, getStamina _unit, getFatigue _unit, isStaminaEnabled _unit];
    private _gait = [_eligible, _eligibleCarry, _suspended, _modeAllows, _owner isEqualTo _unit, str _owner, _active, _unit getVariable ["GAIT_slopeLocomotionActive", false], _latched, _failed, _exitPending, _entryDeadline, _cancelDeadline, _source, _target, _unit getVariable ["GAIT_slopeAttemptFamily", ""], _unit getVariable ["GAIT_slopeAttemptWeapon", ""], _expectedBlend];
    private _context = [
        _unit getVariable ["ACE_isUnconscious", false], _unit getVariable ["GAIT_isTripping", false],
        _unit getVariable ["MAV_fastCarry_pickupActive", false], _unit getVariable ["ace_dragging_isDragging", false],
        _unit getVariable ["ace_dragging_isDragged", false], _unit getVariable ["ace_dragging_isCarried", false],
        _unit getVariable ["ace_dragging_isCarrying", false], _unit getVariable ["ace_common_isClimbing", false],
        missionNamespace getVariable ["ace_common_isClimbing", false], _unit getVariable ["ace_medical_treatment_inProgress", false],
        missionNamespace getVariable ["ace_medical_treatment_inProgress", false], cameraOn isEqualTo _unit,
        currentWeapon _unit, weaponLowered _unit, !isNull (findDisplay 312)
    ];
    private _movement = [_velocity, _horizontalSpeed, vectorMagnitude _surfaceVelocity, _velocity vectorDotProduct _facing, _velocity vectorDotProduct _right, getAnimSpeedCoef _unit];
    private _settings = [missionNamespace getVariable ["GAIT_ss_slopeHandlingEnabled", -1], missionNamespace getVariable ["GAIT_ss_slopeLocomotionEnabled", -1], missionNamespace getVariable ["ace_advanced_fatigue_enabled", -1], missionNamespace getVariable ["GAIT_walkPaceTarget", -1], missionNamespace getVariable ["GAIT_sprintPaceTarget", -1], loadAbs _unit, missionNamespace getVariable ["GAIT_ss_loadAbsPerLb", -1]];
    private _trialLabel = missionNamespace getVariable ["GAIT32_trialLabel", ""];
    private _row = [_seq, diag_frameNo, _now, time, _state get "label", str _unit, _position, _slope, _input, _rawInput, _animation, _actions, _gesture, _engine, _gait, _context, _movement, _settings, _trialLabel];

    // Sign-only input triggers avoid flooding on tiny analogue-axis changes.
    private _signature = [_unit, _animation, _actions, _gesture, (_engine select [0, 11]) + [_engine select 13], _eligible, _eligibleCarry, _suspended, _modeAllows, _owner, _active, _latched, _failed, _exitPending, _source, _target, _expectedBlend, [_inputF > 0.05, _inputF < -0.05, _inputR > 0.05, _inputR < -0.05, _input select 2], [_steepness >= 32, abs _facingGrade >= 32, abs _travelGrade >= 32, abs _sampleGrade >= 32], _context, _trialLabel];
    private _previous = _state get "signature";
    private _changed = [];
    private _names = ["player", "animation", "actions", "gesture", "engineFlags", "eligible", "eligibleCarry", "suspended", "modeAllows", "owner", "active", "attemptLatched", "failure", "exitPending", "entrySource", "entryTarget", "expectedBlend", "input", "32degreeBands", "context", "trialLabel"];
    {
        if (_forEachIndex >= count _previous || {_x isNotEqualTo (_previous select _forEachIndex)}) then {_changed pushBack (_names select _forEachIndex);};
    } forEach _signature;
    _state set ["signature", _signature];

    private _buffer = _state get "buffer";
    private _logged = _state get "logged";
    _buffer pushBack _row;
    while {(count _buffer) > 120 || {(_now - ((_buffer select 0) select 2)) > 0.5}} do {
        private _expired = _buffer deleteAt 0;
        _logged deleteAt (str (_expired select 0));
    };
    if (_changed isNotEqualTo []) then {
        ["EVENT", [_seq, _now, _changed]] call _emit;
        _state set ["postUntil", _now + 0.75];
    };
    private _toLog = [];
    if (_changed isNotEqualTo []) then {
        _toLog = _buffer select {!(_logged getOrDefault [str (_x select 0), false])};
    } else {
        if (_now < (_state get "postUntil") || {_now >= (_state get "heartbeat")}) then {_toLog = [_row];};
    };
    {
        if ((_state get "lines") >= 6000 || {_state getOrDefault ["lineLimitReached", false]}) exitWith {};
        if (["SAMPLE", _x] call _emit) then {_logged set [str (_x select 0), true];};
        _state set ["heartbeat", _now + 1];
    } forEach _toLog;
}];
missionNamespace setVariable ["GAIT_thresholdProbeHandler", _handler];
