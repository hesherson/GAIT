/*
    GAIT traversal helpers.
    Compile once after the legacy helper declarations in fn_initSprintSystem.
    These helpers never force an animation, velocity, stamina or ACE status.
*/

// Pure input resolver, shared by live polling and the regression tests.
GAIT_fnc_resolveMovementInput = {
    params ["_forwardAction", "_backAction", "_leftAction", "_rightAction", "_turboAction", ["_adjust", []]];
    if (_adjust isNotEqualTo []) then {
        _forwardAction = _forwardAction max (_adjust select 0);
        _backAction = _backAction max (_adjust select 1);
        _leftAction = _leftAction max (_adjust select 2);
        _rightAction = _rightAction max (_adjust select 3);
    };
    private _forward = (_forwardAction max 0 min 1) - (_backAction max 0 min 1);
    private _right = (_rightAction max 0 min 1) - (_leftAction max 0 min 1);
    if (abs _forward <= 0.05) then {_forward = 0;};
    if (abs _right <= 0.05) then {_right = 0;};
    private _magnitude = sqrt ((_forward * _forward) + (_right * _right));
    if (_magnitude > 1) then {
        _forward = _forward / _magnitude;
        _right = _right / _magnitude;
    };
    [_forward, _right, _turboAction > 0]
};

GAIT_fnc_canReadTravelAdjustments = {
    params ["_animation", "_turbo", "_sprintHandoff"];
    private _name = toLower _animation;
    if !((_name select [0, 8]) in ["amovperc", "amovpknl"]) exitWith {false};
    private _pace = _name select [8, 4];
    if (_pace isEqualTo "mstp") exitWith {_sprintHandoff};
    if !(_pace in ["mwlk", "mrun", "mtac", "meva", "mspr"]) exitWith {false};
    _sprintHandoff || {(_name find "_gait") >= 0} ||
        {_turbo && {_pace in ["meva", "mspr"]} && {(_name select [12, 8]) in ["sraswrfl", "slowwrfl"]}}
};

GAIT_fnc_getMovementInput = {
    // Bohemia's action table: TurnLeft/Right strafe; MoveLeft/Right rotate.
    // Preserve the existing held-Turbo contract, including remapped bindings.
    private _actions = [inputAction "MoveForward", inputAction "MoveBack", inputAction "TurnLeft", inputAction "TurnRight", inputAction "Turbo"];
    if (!isNull player) then {
        private _sprintHandoff = (player getVariable ["GAIT_sprintReleaseJog", false]) ||
            {(player getVariable ["GAIT_sprintReleasePace", []]) isNotEqualTo []} ||
            {(player getVariable ["GAIT_slopeAttemptLatched", false]) && {player getVariable ["GAIT_turboInputHeld", false]}};
        if ((_sprintHandoff || {player getVariable ["GAIT_movementInputHeld", false]}) &&
            {[animationState player, (_actions select 4) > 0, _sprintHandoff] call GAIT_fnc_canReadTravelAdjustments}) then {
            // Arma can report only the adjustment action during a modifier
            // chord, including while the outgoing sprint gives way to a native clip.
            _actions pushBack [inputAction "AdjustUp", inputAction "AdjustDown",
                inputAction "AdjustLeft", inputAction "AdjustRight"];
        };
    };
    _actions call GAIT_fnc_resolveMovementInput
};

// Stance intent can arrive before animationState or stance changes.
// Arma chooses the transition clip from its own action map before GAIT
// scales its playback.
GAIT_fnc_resolveStanceInput = {
    params ["_crouchAction", "_moveUpAction", "_proneAction", "_moveDownAction"];
    ((_crouchAction max 0) > 0.05) || {((_moveUpAction max 0) > 0.05)} ||
        {((_proneAction max 0) > 0.05)} || {((_moveDownAction max 0) > 0.05)}
};

GAIT_fnc_getStanceInput = {
    [inputAction "Crouch", (inputAction "Stand") max (inputAction "MoveUp"),
        inputAction "Prone", inputAction "MoveDown"]
        call GAIT_fnc_resolveStanceInput
};

GAIT_fnc_crouchToggleHeld = {((inputAction "Crouch") max (inputAction "MoveUp")) > 0.05};

GAIT_fnc_getWeaponSlotInput = {
    (["SwitchPrimary", "SwitchHandgun", "SwitchSecondary", "SwitchWeaponGrp1",
        "SwitchWeaponGrp2", "SwitchWeaponGrp3", "handgun", "switchWeapon"]
        findIf {(inputAction _x) > 0.05}) >= 0
};

GAIT_fnc_readFireInput = {
    params ["_unit"];
    inputAction "DefaultAction" > 0 || {inputAction "Fire" > 0} ||
        {diag_tickTime - (_unit getVariable ["GAIT_firePressedAt",-1]) < 0.16}
};

GAIT_fnc_readAimInput = {
    cameraView isEqualTo "GUNNER" || {(inputAction "Optics") > 0} || {(inputAction "OpticsTemp") > 0}
};

GAIT_fnc_compatibleIdleName = {
    params ["_animation"];
    private _name = toLower _animation;
    if (missionNamespace getVariable ["GAIT_nswg2AnimationsLoaded", false] && {_name in [
        "aidlpercmstpsraswrfldnon_g01_player", "aidlpercmstpsraswrfldnon_g02_player",
        "aidlpercmstpsraswrfldnon_g03_player", "aidlpercmstpsraswrfldnon_g04_player",
        "amovpercmstpsraswrfldnon_turnl", "amovpercmstpsraswrfldnon_turnr"
    ]}) exitWith {"amovpercmstpsraswrfldnon"};
    _name
};

// These masks own the hands and rifle independently of the body locomotion.
GAIT_fnc_rifleGestureFree = {
    params ["_name"];
    if (_name in ["gait_shuffleleftmedium","gait_shufflerightmedium","gait_shuffleleftsteep","gait_shufflerightsteep"]) exitWith {true};
    if (_name in ["","<none>","gestureempty","gesturenone","gait_endsprintgesture","gait_normalbrace","gait_shuffleleft","gait_shuffleright","amovpercmstpsnonwnondnon",
        "amovpercmstpsraswrfldnon","amovpercmstpslowwrfldnon","amovpercmstpsraswpstdnon",
        "amovpercmstpslowwpstdnon","amovpercmstpsraswlnrdnon","amovpercmstpslowwlnrdnon"]) exitWith {true};
    (_name select [0,24]) in ["aidlpercmstpsraswrfldnon","aidlpercmstpsraswpstdnon","aidlpercmstpsraswlnrdnon"] &&
        {(_name select [24]) in ["_g01_player","_g02_player","_g03_player","_g04_player"]}
};

GAIT_fnc_preserveLocomotionGesture = {
    params ["_gesture"];
    (toLower _gesture) in [
        "navspecwargru2_ready", "navspecwargru2_high_ready_position", "navspecwargru2_high_port_position",
        "navspecwargru2_low_compress_position", "navspecwargru2_low_port_position",
        "navspecwargru2_low_ready_position", "navspecwargru2_low_ready_position_2",
        "navspecwargru2_open_door_high", "navspecwargru2_open_door_low", "navspecwargru2_open_door_mid",
        "navspecwargru2_short_stock_over", "navspecwargru2_short_stock_under",
        "navspecwargru2_overhead_shoot", "navspecwargru2_around_shoot", "navspecwargru2_shouldertap",
        "navspecwargru2_thighsqueeze_gentle", "navspecwargru2_thighsqueeze_normal", "navspecwargru2_thighsqueeze_hard"
    ]
};

GAIT_fnc_stepSpeedCoefficient = {
    params ["_current", "_target", "_ramp", "_dt"];
    private _alpha = 1 - ((1 - (_ramp max 0.001 min 1)) ^ ((_dt max 0 min 0.20) / 0.05));
    _current + ((_target - _current) * _alpha)
};

GAIT_fnc_jogDecelerationRamp = {
    params ["_duration", "_smooth"];
    if (!_smooth) exitWith {1};
    // Remove 95% of the gap over the selected time at any update rate.
    1 - (0.05 ^ (0.05 / (_duration max 0.05)))
};

GAIT_fnc_sprintReleaseSlopeScale = {
    params ["_grade"];
    private _severity = (abs _grade / ([32, 24] select (_grade < 0))) min 1;
    private _ease = _severity * _severity * (3 - 2 * _severity);
    1 + (([-0.60, 0.55] select (_grade < 0)) * _ease)
};

GAIT_fnc_sprintWalkProgress = {
    params ["_start", "_now", ["_slopeScale", 1]];
    private _duration = (missionNamespace getVariable ["GAIT_ss_sprintWalkTaperDuration", 2.7]) max 2.3 min 2.9;
    ((_now - _start) / ((_duration * _slopeScale) max 0.05)) max 0 min 1
};

GAIT_fnc_sprintReleaseInterimJog = {
    params ["_mode", "_speed", "_slopeScale"];
    _speed > 0 && {_mode in ["walk", "combat"]}
};

GAIT_fnc_sprintReleaseUsesSlowerPace = {
    params ["_progress", "_requested", "_observed", "_coefficient", "_destination",
        ["_speedMS", -1], ["_destinationMS", -1]];
    // Let a tired or uphill jog step down early, before its cadence stalls.
    // Once the destination has been requested, it owns pace through the taper.
    if ((toLower _requested select [8, 4]) isEqualTo _destination) exitWith {true};
    // Select a walking or tactical stride only when its native cadence can
    // carry the remaining travel speed with at most a small playback increase.
    if (_speedMS >= 0 && {_destinationMS > 0}) exitWith {_speedMS <= _destinationMS * 1.15};
    _progress >= 0.85 ||
        {(toLower _observed select [8, 4]) isEqualTo "mrun" && {_coefficient <= 0.60}}
};

GAIT_fnc_stanceAnimationDepth = {
    params ["_animation", ["_blending", false]];
    private _poses = ["perc", "pknl", "ppne"];
    private _states = ((toLower _animation) splitString "_") select {
        (_x select [0, 4]) in ["amov", "aadj"] && {(_x select [4, 4]) in _poses}
    };
    if (_states isEqualTo []) exitWith {0};
    private _from = _states select 0;
    private _to = _states select ((count _states) - 1);
    private _fromPose = _from select [4, 4];
    private _toPose = _to select [4, 4];
    private _adjusting = (_states findIf {(_x select [0, 4]) isEqualTo "aadj" &&
        {(_x select [20]) in ["dup", "ddown", "dleft", "dright"]}}) >= 0;
    if (_fromPose isEqualTo _toPose && {!(_adjusting && {_blending || {_from isNotEqualTo _to}})}) exitWith {0};
    [0.72, 0.85, 1] select ((_poses find _fromPose) max (_poses find _toPose))
};

GAIT_fnc_isSuspendedContext = {
    if (isNull player || {!local player} || {!alive player}) exitWith {true};
    if (player getVariable ["ACE_isUnconscious", false]) exitWith {true};
    if (!isNull (findDisplay 312)) exitWith {true};
    if (!isNull (player getVariable ["bis_fnc_moduleRemoteControl_unit", objNull])) exitWith {true};

    // Keep exitWith at function scope. Inside a nested then-block its return
    // value was discarded and a spectator camera incorrectly returned false.
    private _camera = cameraOn;
    private _foreignCamera = !isNull _camera && {_camera != player} && {_camera != vehicle player};
    if (_foreignCamera) exitWith {true};
    false
};

GAIT_fnc_locomotionInputSuspended = {
    dialog || {isNull (findDisplay 46)} || {call GAIT_fnc_isSuspendedContext}
};

// Only an expected standing locomotion blend may bridge the normal
// transition rejection during the single custom sprint entry request.
GAIT_fnc_isStandingLocomotionBlend = {
    params [["_animation", "", [""]], ["_source", "", [""]], ["_target", "", [""]]];
    // Split at the second state, not every underscore. The native lowered
    // rifle walk/tactical states have a real _ver2 suffix in our graph.
    // Only these exact known variants and the optional GAIT marker qualify.
    private _canonicalState = {
        params ["_state"];
        private _parts = ([_state] call GAIT_fnc_compatibleIdleName) splitString "_";
        if ((count _parts) < 1 || {(count _parts) > 2}) exitWith {""};
        private _base = _parts select 0;
        private _suffix = _parts param [1, ""];
        if !(_suffix in ["", "gait", "gaitsprint", "gaitsprintstop", "ver2"]) exitWith {""};
        if (!((_base select [0, 8]) in ["amovperc", "amovpknl"]) ||
            {!((_base select [8, 4]) in ["mstp", "mwlk", "mrun", "mtac", "meva", "mspr"])} ||
            {!((_base select [12, 8]) in ["sraswrfl", "slowwrfl", "sraswpst", "slowwpst", "snonwnon", "sraswlnr", "slowwlnr"])} ||
            {!((_base select [20]) in ["dnon", "df", "dfl", "dl", "dbl", "db", "dbr", "dr", "dfr"])}) exitWith {""};
        // SlowWpst is now a first-class custom family. The normal canonical
        // suffix handling below accepts its native and GAIT states identically.
        if (_suffix isEqualTo "gaitsprintstop") exitWith {
            if ((_base select [8, 4]) isEqualTo "mstp" && {(_base select [20]) isEqualTo "dnon"}) then {_base + "_" + _suffix} else {""}
        };
        if (_suffix isEqualTo "ver2") exitWith {
            if ((_base select [12, 8]) isEqualTo "slowwrfl" &&
                {(_base select [8, 4]) in ["mwlk", "mtac"]} &&
                {(_base select [20]) isNotEqualTo "dnon"}) then {_base + "_ver2"} else {""}
        };
        _base
    };
    private _name = toLower _animation;
    private _divider = _name find "_amov";
    if (_divider < 0) exitWith {false};
    private _left = [_name select [0, _divider]] call _canonicalState;
    private _right = [_name select [_divider + 1]] call _canonicalState;
    private _expectedLeft = [_source] call _canonicalState;
    private _expectedRight = [_target] call _canonicalState;
    if (_left isEqualTo "" || {_right isEqualTo ""}) exitWith {false};
    if ((_left select [4, 4]) isNotEqualTo (_right select [4, 4])) exitWith {false};
    // Raised/lowered pistol pose is part of locomotion identity. A GAIT body
    // handoff must never introduce SrasWpst <-> SlowWpst on its own; native
    // weapon-pose input may take over outside this exact locomotion lease.
    private _leftFamily = _left select [12, 8];
    private _rightFamily = _right select [12, 8];
    if ((_leftFamily in ["sraswpst", "slowwpst"] || {_rightFamily in ["sraswpst", "slowwpst"]}) &&
        {_leftFamily isNotEqualTo _rightFamily}) exitWith {false};
    _left isNotEqualTo "" && {_right isNotEqualTo ""} &&
        {_left isEqualTo _expectedLeft} && {_right isEqualTo _expectedRight}
};

// ACE uses separate moving clips for shoulder carry and backward drag.
GAIT_fnc_casualtyClip = {
    params ["_animation", "_carrying"];
    private _name = toLower _animation;
    if (!_carrying) exitWith {
        ["", "drag"] select (_name in [
            "acinpknlmwlksraswrfldb", "acinpknlmwlksnonwnondb",
            "ace_dragging_rifle_limpb", "ace_dragging", "ace_dragging_limpb"
        ])
    };
    if ((_name select [0, 8]) isNotEqualTo "acinperc" ||
        {(_name select [12, 9]) isNotEqualTo "snonwnond"} ||
        {!((_name select [21]) in ["f", "fl", "fr", "l", "r", "b", "bl", "br"])}) exitWith {""};
    switch (_name select [8, 4]) do {
        case "mwlk": {"carryWalk"};
        case "mrun";
        case "mtac";
        case "meva";
        case "mspr": {"carryRun"};
        default {""};
    }
};

GAIT_fnc_activeCasualtyClip = {
    params ["_unit", "_patient", "_animation", "_carrying", ["_allowCarryIdle", false]];
    if (isNull _patient || {!(_patient isKindOf "CAManBase")} ||
        {(attachedTo _patient) isNotEqualTo _unit}) exitWith {""};
    if (_allowCarryIdle && {_carrying} && {(toLower _animation) isEqualTo "acinpercmstpsnonwnondnon"}) exitWith {"carryIdle"};
    [_animation, _carrying] call GAIT_fnc_casualtyClip
};

GAIT_fnc_nativeMovementEligible = {
    params [
        ["_unit", player, [objNull]],
        ["_allowCarry", false, [false]],
        ["_allowStanceMotion", false, [false]]
    ];
    if (isNull _unit || {!local _unit} || {_unit != player} || {!alive _unit}) exitWith {false};
    if !(call GAIT_fnc_modeAllowsMovement) exitWith {false};
    if (call GAIT_fnc_isSuspendedContext) exitWith {false};
    if (!isNull (objectParent _unit) || {!isNull (attachedTo _unit)} || {!isTouchingGround _unit}) exitWith {false};
    if ((lifeState _unit) isEqualTo "INCAPACITATED") exitWith {false};
    if (_unit getVariable ["ACE_isUnconscious", false]) exitWith {false};
    if (_unit getVariable ["GAIT_isTripping", false]) exitWith {false};
    if (_unit getVariable ["MAV_fastCarry_pickupActive", false]) exitWith {false};
    if (_unit getVariable ["ace_dragging_isDragged", false]) exitWith {false};
    if (_unit getVariable ["ace_dragging_isCarried", false]) exitWith {false};
    private _carrying = _unit getVariable ["ace_dragging_isCarrying", false];
    private _dragging = _unit getVariable ["ace_dragging_isDragging", false];
    if ((_carrying || {_dragging}) && {!_allowCarry}) exitWith {false};
    if ((_unit getVariable ["ace_common_isClimbing", false]) isEqualTo true) exitWith {false};
    if ((missionNamespace getVariable ["ace_common_isClimbing", false]) isEqualTo true) exitWith {false};
    if ((_unit getVariable ["ace_medical_treatment_inProgress", false]) isEqualTo true) exitWith {false};
    if ((missionNamespace getVariable ["ace_medical_treatment_inProgress", false]) isEqualTo true) exitWith {false};

    private _gesture = toLower (gestureState _unit);
    if ((["reload", "melee", "throw"] findIf {(_gesture find _x) >= 0}) >= 0) exitWith {false};
    private _animation = toLower (animationState _unit);
    private _action = ["reload", "medic", "melee", "throw", "climb", "ladder", "putdown", "getin", "getout", "vault", "dive", "diving", "roll", "salute", "surrender", "gear"] findIf {(_animation find _x) >= 0};
    if (_action >= 0) exitWith {false};
    private _carried = _unit getVariable ["ace_dragging_carriedObject", objNull];
    if (_dragging || {_carrying && {_carried isKindOf "CAManBase"}}) exitWith {
        private _patient = if (_dragging) then {_unit getVariable ["ace_dragging_draggedObject", objNull]} else {_carried};
        !_allowStanceMotion && {!underwater _unit} &&
            {([_unit, _patient, _animation, !_dragging] call GAIT_fnc_activeCasualtyClip) isNotEqualTo ""}
    };
    if (_allowStanceMotion) exitWith {(_gesture find "medic") < 0};

    // Accept ordinary locomotion and idle states only. A transition can still
    // report the old stance, so a name joining two animation states must not
    // qualify. Preserve suffix variants such as injured locomotion instead of
    // rejecting every underscore. Full-body actions remain outside the list.
    private _transition = ["_amov", "_acin", "_ainv", "_acts", "_aadj", "_adth", "_awop", "_aswm", "_aovr", "_acrg"] findIf {(_animation find _x) >= 0};
    // Animation speed scales with grade/load. A legitimate slow blend must
    // not be canceled merely because a fixed entry timer expired. Exact
    // source/target matching still excludes every unrelated transition.
    private _expectedBlend = false;
    if (_transition >= 0 && {(_unit getVariable ["GAIT_slopeAttemptLatched", false])} &&
        {!(_unit getVariable ["GAIT_slopeExitPending", false])} &&
        {(stance _unit) in ["STAND", "CROUCH"]}) then {
        _expectedBlend = [_animation, _unit getVariable ["GAIT_slopeEntrySource", ""], _unit getVariable ["GAIT_slopeEntryTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend;
        _expectedBlend = _expectedBlend || {[_animation, _unit getVariable ["GAIT_slopeEntrySource", ""],
            diag_tickTime <= (_unit getVariable ["GAIT_slopeEntryDeadline", -1])] call GAIT_fnc_isLocomotionHandoffSource};
    };
    // Keep coefficient ownership through a recorded native stop blend.
    // This does not admit stance, weapon, medical or unrelated transitions.
    private _exitBlend = _transition >= 0 &&
        {_unit getVariable ["GAIT_slopeExitPending", false]} &&
        {!isNil "GAIT_fnc_isLocomotionHandoffBlend"} &&
        {[_animation, _unit getVariable ["GAIT_slopeExitSource", ""],
            _unit getVariable ["GAIT_slopeExitTarget", ""]] call GAIT_fnc_isLocomotionHandoffBlend};
    private _familyBlend = _transition >= 0 && {!isNil "GAIT_fnc_isSlopeLocomotionBlend"} && {[_animation] call GAIT_fnc_isSlopeLocomotionBlend};
    if (_transition >= 0 && {!_expectedBlend} && {!_familyBlend} && {!_exitBlend}) exitWith {false};
    private _movementName = _animation;
    if (_expectedBlend && {(_animation select [0, 4]) isEqualTo "aidl"}) then {
        _movementName = _animation select [0, _animation find "_amov"];
    };
    _movementName = [_movementName] call GAIT_fnc_compatibleIdleName;
    private _nativePrefix = (_movementName select [0, 4]) isEqualTo "amov";
    private _carryPrefix = _allowCarry && {_carrying} && {(_animation select [0, 4]) isEqualTo "acin"};
    if (!_nativePrefix && {!_carryPrefix}) exitWith {false};
    if !((_movementName select [4, 4]) in ["perc", "pknl", "ppne"]) exitWith {false};
    if !((_movementName select [8, 4]) in ["mstp", "mwlk", "mrun", "mtac", "meva", "mspr"]) exitWith {false};
    // Context only: the caller clears the ACE AF source first, then respects
    // any remaining ACE forceWalk/blockSprint owners. Testing those masks here
    // would prevent releasing GAIT's intended AF movement override.
    true
};

GAIT_fnc_surfaceTravelGrade = {
    params ["_normal", "_direction"];
    private _vertical = _normal select 2;
    if (_vertical < 0.60) exitWith {0};
    atan (-(_normal vectorDotProduct _direction) / _vertical)
};

GAIT_fnc_getTravelSlopeDegrees = {
    params [
        ["_unit", player, [objNull]],
        ["_sampleDistance", 2.0, [0]],
        ["_movementInput", [], [[]]]
    ];
    if (isNull _unit) exitWith {0};
    private _position = getPosASL _unit;
    if ((count _movementInput) < 2) then {
        _movementInput = if (_unit isEqualTo player) then {call GAIT_fnc_getMovementInput} else {[0, 0, false]};
    };
    private _forward = _movementInput param [0, 0, [0]];
    private _right = _movementInput param [1, 0, [0]];
    private _facing = vectorDir _unit;
    _facing set [2, 0];
    private _faceMagnitude = vectorMagnitude _facing;
    if (_faceMagnitude < 0.001) then {
        _facing = [sin (getDir _unit), cos (getDir _unit), 0];
    } else {
        _facing = _facing vectorMultiply (1 / _faceMagnitude);
    };

    // Arma world axes: forward north [0,1] has right east [1,0].
    private _direction = [
        ((_facing select 0) * _forward) + ((_facing select 1) * _right),
        ((_facing select 1) * _forward) - ((_facing select 0) * _right),
        0
    ];
    private _magnitude = vectorMagnitude _direction;
    if (_magnitude < 0.001) then {
        private _velocity = velocity _unit;
        _direction = [_velocity select 0, _velocity select 1, 0];
        _magnitude = vectorMagnitude _direction;
        if (_magnitude < 0.1) then {
            _direction = +_facing;
            _magnitude = 1;
        };
    };
    _direction = _direction vectorMultiply (1 / _magnitude);
    private _contact = [_unit, _position] call GAIT_fnc_readWalkableSurface;
    if (_contact isNotEqualTo []) exitWith {[_contact, _direction] call GAIT_fnc_surfaceTravelGrade};
    if (((_position select 2) - (getTerrainHeightASL _position)) > 0.6) exitWith {0};
    _sampleDistance = (_sampleDistance max 0.25) min 10;
    private _offset = _direction vectorMultiply _sampleDistance;
    private _ahead = _position vectorAdd _offset;
    private _behind = _position vectorDiff _offset;
    private _rise = (getTerrainHeightASL _ahead) - (getTerrainHeightASL _behind);
    atan (_rise / (2 * _sampleDistance))
};
