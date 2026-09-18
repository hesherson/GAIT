/*
    GAIT: isolated entry-command comparison, using the unchanged RC3 graph.

    Install this file in a saved single-player Eden mission. Disable GAIT's
    master switch and ACE Advanced Fatigue in MISSION Addon Options, then
    restart preview. Use a healthy standing player, open terrain and no other
    movement mod. Start slope_threshold_probe.sqf first to capture the hill.

    LOCAL EXEC, then close the console and hold Turbo + forward:
      ["switch", 30] execVM "slope_entry_trial.sqf";

    Only if a controlled comparison is needed, repeat from a fresh preview:
      ["play", 30] execVM "slope_entry_trial.sqf";

    Both variants enter the SAME custom Meva state once, in Draw3D. "switch"
    uses STRING switchMove, which resets animation phase and aiming/gesture
    state. It deliberately does not append playMoveNow. "play" uses only
    playMoveNow, which replaces the scripted move queue and uses graph blending.
    This compares the commands, not a phase-preserving production solution.
    Draw3D avoids the camera-glitch context reported for scheduled switchMove.
    It does not establish that all camera or animation artifacts are fixed.

    The trial temporarily disables VANILLA stamina, saving its enabled flag
    and restoring that flag on ordinary completion or abort.
    It never writes legacy enableFatigue, ACE physiology, numeric fatigue or
    stamina values, speed, position, velocity, GAIT settings or ownership. The
    enabled flag is restored; an engine side effect of disabling stamina is
    not reversible by this script. Restart preview after every run for a clean comparison.

    Hold Turbo throughout; try forward diagonals and pure A/D on the same hill.
    Entry waits at most 15 seconds; observation lasts at most 30 seconds. No
    state is reasserted if Arma leaves the graph. Release Turbo or cancel with:
      GAIT32_entryTrialCancel = true;
    Wait for STOP. Do not terminate the script: termination bypasses cleanup.

    Context loss also stops the trial. At most one guarded native exit is sent,
    only from its custom state or exact entry blend while normal locomotion
    remains safe. Falls, medical actions, vehicles, death and other body actions
    retain control. No addon rebuild or Git deployment is required.

    [GAIT32_ENTRY] logs entry, state changes, flags and outcome to the RPT.
    GAIT32_trialLabel connects this trial to the separate boundary recorder.
*/

params [["_variant", "switch", [""]], ["_duration", 30, [0]]];
_variant = toLower _variant;
_duration = _duration max 5 min 30;

private _report = {
    params ["_message"];
    diag_log ("[GAIT32_ENTRY] " + _message);
    systemChat ("GAIT entry trial: " + _message);
};
if (!hasInterface || {!is3DENPreview} || {isMultiplayer} || {!canSuspend}) exitWith {
    ["Refused: use execVM in a single-player Eden preview."] call _report;
};
if !(_variant in ["play", "switch"]) exitWith {
    ["Refused: variant must be play or switch."] call _report;
};
if ((missionNamespace getVariable ["GAIT32_trialBusyUntil", -1]) > diag_tickTime) exitWith {
    ["A trial is active. Release Turbo or set GAIT32_entryTrialCancel = true, then wait for STOP."] call _report;
};
private _helpers = [
    "GAIT_fnc_getMovementInput", "GAIT_fnc_slopeDirection",
    "GAIT_fnc_slopeStateName", "GAIT_fnc_slopeWeaponFamily",
    "GAIT_fnc_isSlopeLocomotionState", "GAIT_fnc_isStandingLocomotionBlend"
];
if ((_helpers findIf {isNil {missionNamespace getVariable _x}}) >= 0) exitWith {
    ["Refused: load GAIT RC3 or RC4 and wait for initialization."] call _report;
};
private _unit = player;
private _weapon = currentWeapon _unit;

private _contextReason = {
    params ["_unit", "_weapon"];
    if (missionNamespace getVariable ["GAIT_ss_enabled", true]) exitWith {"GAIT must be disabled in mission Addon Options; restart preview"};
    if (missionNamespace getVariable ["ace_advanced_fatigue_enabled", true]) exitWith {"ACE Advanced Fatigue must be disabled in mission Addon Options; restart preview"};
    if (!isNull (missionNamespace getVariable ["GAIT_nativeOwner", objNull]) || {!isNull (missionNamespace getVariable ["GAIT_slopeOwner", objNull])}) exitWith {"GAIT still owns movement; allow cleanup or restart preview"};
    if ((missionNamespace getVariable ["GAIT_nativeMovementActive", false]) || {missionNamespace getVariable ["GAIT_slopeLocomotionActive", false]}) exitWith {"GAIT movement control is still active; restart preview"};
    if (isNull _unit || {!local _unit} || {_unit isNotEqualTo player} || {!alive _unit}) exitWith {"player context changed"};
    if (!isNull (objectParent _unit) || {!isNull (attachedTo _unit)}) exitWith {"vehicle or attachment context"};
    if (!isTouchingGround _unit) exitWith {"ground contact lost"};
    if ((stance _unit) isNotEqualTo "STAND") exitWith {"standing stance ended"};
    if ((lifeState _unit) isNotEqualTo "HEALTHY" || {damage _unit > 0.001} || {_unit getVariable ["ACE_isUnconscious", false]}) exitWith {"healthy player required"};
    if ((currentWeapon _unit) isNotEqualTo _weapon) exitWith {"equipped weapon changed"};
    if (!isNull (findDisplay 312) || {!isNull (_unit getVariable ["bis_fnc_moduleRemoteControl_unit", objNull])}) exitWith {"remote control context"};
    if (!isNull cameraOn && {cameraOn isNotEqualTo _unit} && {cameraOn isNotEqualTo vehicle _unit}) exitWith {"camera context changed"};
    private _bodyFlags = ["GAIT_isTripping", "MAV_fastCarry_pickupActive", "ace_dragging_isDragging", "ace_dragging_isDragged", "ace_dragging_isCarried", "ace_dragging_isCarrying", "ace_common_isClimbing", "ace_medical_treatment_inProgress", "ace_medical_isLimping"];
    if ((_bodyFlags findIf {_unit getVariable [_x, false]}) >= 0) exitWith {"medical, carry, climb or trip context"};
    if ((missionNamespace getVariable ["ace_common_isClimbing", false]) || {missionNamespace getVariable ["ace_medical_treatment_inProgress", false]}) exitWith {"mission medical or climb action"};
    if ((_unit getVariable ["ace_common_effect_blockSprint", 0]) > 0 || {(_unit getVariable ["ace_common_effect_forceWalk", 0]) > 0}) exitWith {"an ACE movement restriction is active"};
    // Native sprint flags are observed during the run. The entry callback
    // separately refuses an existing explicit native restriction.
    private _parts = ((toLower (animationState _unit)) splitString "_") - ["gait", "ver2"];
    if !((count _parts) in [1, 2]) exitWith {"non-locomotion body state"};
    private _invalid = _parts findIf {
        ((_x select [0, 8]) isNotEqualTo "amovperc") ||
        {!((_x select [8, 4]) in ["mstp", "mwlk", "mrun", "mtac", "meva", "mspr"])} ||
        {!((_x select [12, 8]) in ["sraswrfl", "slowwrfl", "sraswpst", "snonwnon"])} ||
        {!((_x select [20]) in ["dnon", "df", "dfl", "dl", "dbl", "db", "dbr", "dr", "dfr"])}
    };
    if (_invalid >= 0) exitWith {"non-locomotion body action"};
    private _gesture = toLower (gestureState _unit);
    if ((["reload", "melee", "throw", "medic", "climb"] findIf {(_gesture find _x) >= 0}) >= 0) exitWith {"upper-body action"};
    ""
};


private _refusal = [_unit, _weapon] call _contextReason;
if (_refusal isNotEqualTo "") exitWith {[_refusal] call _report;};
if ([animationState _unit] call GAIT_fnc_isSlopeLocomotionState ||
    {_unit getVariable ["GAIT_slopeAttemptLatched", false]} ||
    {_unit getVariable ["GAIT_slopeExitPending", false]}) exitWith {
    ["Refused: a custom state or GAIT transition remains active. Restart preview."] call _report;
};
private _family = [_unit] call GAIT_fnc_slopeWeaponFamily;
if (_family isEqualTo "") exitWith {["Refused: use a rifle, pistol or unarmed pose."] call _report;};
private _states = configFile >> "CfgMovesMaleSdr" >> "States";
private _forward = [_family, "Df"] call GAIT_fnc_slopeStateName;
if (!isClass (_states >> _forward) ||
    {(getNumber (_states >> _forward >> "GAIT_slopeState")) isNotEqualTo 1} ||
    {((toLower _forward) find "amovpercmeva") isNotEqualTo 0}) exitWith {
    ["Refused: the RC3 custom Meva family is unavailable."] call _report;
};

private _savedStaminaEnabled = isStaminaEnabled _unit;
private _serial = (missionNamespace getVariable ["GAIT32_entrySerial", 0]) + 1;
missionNamespace setVariable ["GAIT32_entrySerial", _serial];
missionNamespace setVariable ["GAIT32_trialBusyUntil", diag_tickTime + 15 + _duration + 5];
missionNamespace setVariable ["GAIT32_entryTrialCancel", false];
missionNamespace setVariable ["GAIT32_trialLabel", "entry-" + _variant + ":armed"];

// Shared record only bridges scheduled observation and the unscheduled Draw3D
// callback. This is diagnostic state, not GAIT's production ownership state.
// 0 serial, 1 unit, 2 weapon, 3 family, 4 variant, 5 arm deadline, 6 guard,
// 7 status, 8 reason, 9 source, 10 target, 11 entry time, 12 Draw3D handler.
private _trial = [_serial, _unit, _weapon, _family, _variant, diag_tickTime + 15,
    _contextReason, "armed", "", "", "", -1, -1];
missionNamespace setVariable ["GAIT32_entryTrial", _trial];
_unit enableStamina false;
diag_log format ["[GAIT32_ENTRY] ARM_FLAGS savedStaminaEnabled=%1 staminaEnabled=%2 stamina=%3 fatigue=%4 legacyFatigueUnchanged=true", _savedStaminaEnabled, isStaminaEnabled _unit, getStamina _unit, getFatigue _unit];

// Publish the handler ID without a scheduled pause between registration and
// record update. Draw3D must never observe an uninitialized handler ID.
isNil {
    private _drawHandler = addMissionEventHandler ["Draw3D", {
        private _trial = missionNamespace getVariable ["GAIT32_entryTrial", []];
        if ((count _trial) isNotEqualTo 13) exitWith {
            removeMissionEventHandler ["Draw3D", _thisEventHandler];
        };
        // An obsolete handler must never act on a later trial's shared record.
        if ((_trial select 12) isNotEqualTo _thisEventHandler ||
            {(_trial select 7) isNotEqualTo "armed"}) exitWith {
            removeMissionEventHandler ["Draw3D", _thisEventHandler];
        };
        _trial params ["_serial", "_unit", "_weapon", "_family", "_variant", "_armDeadline", "_contextReason"];
        private _reason = [_unit, _weapon] call _contextReason;
        if (missionNamespace getVariable ["GAIT32_entryTrialCancel", false]) then {_reason = "cancel requested";};
        if (diag_tickTime >= _armDeadline) then {_reason = "entry input timeout";};
        if (isStaminaEnabled _unit) then {_reason = "vanilla stamina was re-enabled externally";};
        if (!isSprintAllowed _unit || {isForcedWalk _unit}) then {_reason = "native sprint restriction is active before entry";};
        if (_reason isNotEqualTo "") exitWith {
            _trial set [7, "aborted"];
            _trial set [8, _reason];
            _trial set [12, -1];
            removeMissionEventHandler ["Draw3D", _thisEventHandler];
        };
        private _input = [] call GAIT_fnc_getMovementInput;
        if (!(_input select 2) || {(_input select 0) <= 0.05} ||
            {((toLower (animationState _unit)) find "_amov") >= 0}) exitWith {};
        private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
        private _target = [_family, _direction] call GAIT_fnc_slopeStateName;
        private _stateConfig = configFile >> "CfgMovesMaleSdr" >> "States" >> _target;
        if (!isClass _stateConfig || {(getText (_stateConfig >> "file")) isEqualTo ""} ||
            {(getNumber (_stateConfig >> "GAIT_slopeState")) isNotEqualTo 1}) exitWith {
            _trial set [7, "aborted"];
            _trial set [8, "requested custom animation missing"];
            _trial set [12, -1];
            removeMissionEventHandler ["Draw3D", _thisEventHandler];
        };
        // Everything through the command runs without scheduler suspension. Claim
        // the entry and remove the callback BEFORE changing animation, so nested
        // events cannot cause a second entry or leave a stale callback armed.
        private _source = animationState _unit;
        _trial set [7, "entered"];
        _trial set [9, _source];
        _trial set [10, _target];
        _trial set [11, diag_tickTime];
        _trial set [12, -1];
        removeMissionEventHandler ["Draw3D", _thisEventHandler];
        missionNamespace setVariable ["GAIT32_trialLabel", "entry-" + _variant + ":active"];
        diag_log format ["[GAIT32_ENTRY] ENTRY variant=%1 context=Draw3D source=%2 target=%3 sprintAllowed=%4 forcedWalk=%5 stamina=%6 fatigue=%7 coef=%8 staminaEnabled=%9", _variant, _source, _target, isSprintAllowed _unit, isForcedWalk _unit, getStamina _unit, getFatigue _unit, getAnimSpeedCoef _unit, isStaminaEnabled _unit];
        if (_variant isEqualTo "switch") then {
            _unit switchMove _target;
        } else {
            _unit playMoveNow _target;
        };
    }];
    _trial set [12, _drawHandler];
};
[format ["ARM %1 for %2 seconds. Close console and hold Turbo + forward within 15 seconds.", _variant, _duration]] call _report;

private _reason = "";
private _sawTarget = false;
private _sawCustom = false;
private _lastState = animationState _unit;
private _lastMovementTime = diag_tickTime;
waitUntil {
    uiSleep 0.01;
    _reason = _trial select 8;
    if (_reason isEqualTo "") then {_reason = [_unit, _weapon] call _contextReason;};
    if (_reason isEqualTo "" && {isStaminaEnabled _unit}) then {
        _reason = "vanilla stamina was re-enabled externally";
    };
    if (missionNamespace getVariable ["GAIT32_entryTrialCancel", false]) then {_reason = "cancel requested";};
    if ((_trial select 7) isEqualTo "armed") then {
        if (diag_tickTime >= (_trial select 5)) then {_reason = "entry input timeout";};
    };
    if ((_trial select 7) isEqualTo "entered") then {
        _lastMovementTime = _lastMovementTime max (_trial select 11);
        private _input = [] call GAIT_fnc_getMovementInput;
        private _state = animationState _unit;
        _sawTarget = _sawTarget || {(toLower _state) isEqualTo (toLower (_trial select 10))};
        _sawCustom = _sawCustom || {[_state] call GAIT_fnc_isSlopeLocomotionState};
        if (_state isNotEqualTo _lastState) then {
            diag_log format ["[GAIT32_ENTRY] STATE elapsed=%1 state=%2 input=%3 sprintAllowed=%4 forcedWalk=%5 grounded=%6 staminaEnabled=%7 stamina=%8 fatigue=%9", diag_tickTime - (_trial select 11), _state, _input, isSprintAllowed _unit, isForcedWalk _unit, isTouchingGround _unit, isStaminaEnabled _unit, getStamina _unit, getFatigue _unit];
            _lastState = _state;
        };
        if (abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05}) then {_lastMovementTime = diag_tickTime;};
        if (_reason isEqualTo "" && {!(_input select 2)}) then {_reason = "Turbo released";};
        if (_reason isEqualTo "" && {diag_tickTime - _lastMovementTime > 0.35}) then {_reason = "movement input absent";};
        if (_reason isEqualTo "" && {diag_tickTime - (_trial select 11) >= _duration}) then {_reason = "time limit";};
    };
    _reason isNotEqualTo ""
};

private _entered = false;
private _stateAtStop = "";
private _exitSent = false;
// Invalidate entry and capture its final state atomically. A scheduled pause
// must not let a pending Draw3D entry run between the snapshot and cancellation.
isNil {
    _trial set [7, "stopped"];
    private _pendingHandler = _trial select 12;
    _trial set [12, -1];
    if (_pendingHandler >= 0) then {removeMissionEventHandler ["Draw3D", _pendingHandler];};
    _entered = (_trial select 11) >= 0;
    _stateAtStop = animationState _unit;
    if (((missionNamespace getVariable ["GAIT32_entryTrial", []]) param [0, -1]) isEqualTo _serial) then {
        missionNamespace setVariable ["GAIT32_entryTrial", nil];
    };
};

// Recheck the body context and issue a native exit without a scheduler pause.
isNil {
    if (_entered && {([_unit, _weapon] call _contextReason) isEqualTo ""}) then {
        private _stateForExit = animationState _unit;
        private _inCustom = [_stateForExit] call GAIT_fnc_isSlopeLocomotionState;
        private _blendNames = [_stateForExit, _trial select 9, _trial select 10] apply {
            (((toLower _x) splitString "_") - ["ver2"]) joinString "_"
        };
        private _expectedBlend = _blendNames call GAIT_fnc_isStandingLocomotionBlend;
        if (_inCustom || {_expectedBlend}) then {
            private _input = [] call GAIT_fnc_getMovementInput;
            private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
            private _pace = ["Mrun", "Mwlk"] select (isForcedWalk _unit);
            if (isSprintAllowed _unit && {!isForcedWalk _unit} && {_input select 2} && {_direction in ["Df", "Dfl", "Dfr"]}) then {_pace = "Meva";};
            if (_direction isEqualTo "Dnon") then {_pace = "Mstp";};
            private _nativeExit = "AmovPerc" + _pace + _family + _direction;
            if (!isClass (_states >> _nativeExit)) then {_nativeExit = "AmovPercMstp" + _family + "Dnon";};
            if (isClass (_states >> _nativeExit)) then {
                diag_log format ["[GAIT32_ENTRY] EXIT source=%1 target=%2", _stateForExit, _nativeExit];
                _unit playMoveNow _nativeExit;
                _exitSent = true;
            };
        };
    };
};

// Restore the flag on the original unit even if the player object changed or
// died. The single-player/locality guard prevents writing a remote replacement.
private _flagsRestored = !isNull _unit && {local _unit};
if (_flagsRestored) then {
    _unit enableStamina _savedStaminaEnabled;
};
missionNamespace setVariable ["GAIT32_trialLabel", "entry-" + _variant + ":stopped:" + _reason];
missionNamespace setVariable ["GAIT32_trialBusyUntil", -1];
diag_log format ["[GAIT32_ENTRY] OUTCOME variant=%1 reason=%2 entrySent=%3 requestedStateObserved=%4 customStateObserved=%5 elapsed=%6 finalState=%7 nativeExitSent=%8 staminaFlagRestored=%9 staminaEnabled=%10 stamina=%11 fatigue=%12", _variant, _reason, _entered, _sawTarget, _sawCustom, [0, diag_tickTime - (_trial select 11)] select _entered, _stateAtStop, _exitSent, _flagsRestored, isStaminaEnabled _unit, getStamina _unit, getFatigue _unit];
[format ["STOP %1: %2. Entry observed=%3; custom observed=%4; stamina enabled flag restored=%5. Send the RPT and restart preview.", _variant, _reason, _sawTarget, _sawCustom, _flagsRestored]] call _report;
