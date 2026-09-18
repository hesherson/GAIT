/*
    GAIT 32-degree investigation: one animation entry, then engine control.

    Copy this file into an Eden test mission. In MISSION Addon Options, disable
    GAIT's master switch and ACE Advanced Fatigue, then restart the preview.
    Use a healthy standing player on unobstructed terrain with no other movement
    mod. Start the read-only slope_threshold_probe.sqf before this experiment.

    LOCAL debug console (close the console, then hold Turbo + forward):
      _h = ["native", 30] execVM "slope_graph_trial.sqf";
      _h = ["custom", 30] execVM "slope_graph_trial.sqf";

    Run these separately, with the same hill, heading, weapon, kit and starting
    stamina. Prefer a fresh preview for each comparison. While Turbo remains
    held, try forward diagonals and pure A/D. One playMoveNow requests entry;
    this script never reasserts it or writes speed, position, velocity, fatigue,
    settings, ACE effects or GAIT ownership. Native stamina remains as configured.
    A fatigue/stamina change can affect the result; record it with the probe.

    Release Turbo to finish, or use this instead of terminating the script:
      GAIT32_trialCancel = true;

    A trial waits at most 15 seconds for entry input and runs for 5..30 seconds.
    Context interruption or loss of ground contact also ends it. A guarded
    native exit is sent at most once, only from a custom state or the precise
    requested entry blend, while still safely in ordinary locomotion. It does
    not cancel a fall, medical action, death, vehicle entry or other body action.

    [GAIT32_TRIAL] logs the requested state, observed state changes and outcome.
    GAIT32_trialLabel is available to the separate read-only boundary probe.
    This isolates the existing RC3 graph from GAIT's runtime controller and ACE
    AF. GAIT's terrainSpeedCoef config and any other loaded addons still apply.
    A rejected custom entry by itself does NOT establish a hardcoded limit.
    A ground-contact stop identifies a contact/context interruption and does
    not establish an engine sprint clamp. Repeat on continuous open terrain.
*/

params [["_variant", "custom", [""]], ["_duration", 30, [0]]];
_variant = toLower _variant;
_duration = _duration max 5 min 30;

private _report = {
    params ["_message"];
    diag_log ("[GAIT32_TRIAL] " + _message);
    systemChat ("GAIT slope trial: " + _message);
};

if (!hasInterface || {!is3DENPreview} || {isMultiplayer} || {!canSuspend}) exitWith {
    ["Refused: run with execVM in a single-player Eden preview."] call _report;
};
if !(_variant in ["native", "custom"]) exitWith {
    ["Refused: variant must be native or custom."] call _report;
};
if ((missionNamespace getVariable ["GAIT32_trialBusyUntil", -1]) > diag_tickTime) exitWith {
    ["A trial is already active. Release Turbo or set GAIT32_trialCancel = true, then wait for STOP before retrying."] call _report;
};

private _requiredHelpers = [
    "GAIT_fnc_getMovementInput", "GAIT_fnc_slopeDirection",
    "GAIT_fnc_slopeStateName", "GAIT_fnc_slopeWeaponFamily",
    "GAIT_fnc_isSlopeLocomotionState", "GAIT_fnc_isStandingLocomotionBlend"
];
if ((_requiredHelpers findIf {isNil {missionNamespace getVariable _x}}) >= 0) exitWith {
    ["Refused: load GAIT RC3 and allow initialization to finish first."] call _report;
};

private _unit = player;
private _weapon = currentWeapon _unit;
private _source = "";
private _target = "";
private _family = "";

// Do not use nativeMovementEligible: its master-switch guard correctly returns
// false with GAIT disabled, which would invalidate this isolated experiment.
private _contextReason = {
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
    // isSprintAllowed/isForcedWalk are observed, not used as entry gates: the
    // experiment must expose a possible terrain-dependent change in either.
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

private _refusal = [] call _contextReason;
if (_refusal isNotEqualTo "") exitWith {["Refused: " + _refusal] call _report;};
if ([animationState _unit] call GAIT_fnc_isSlopeLocomotionState) exitWith {
    ["Refused: player is already in a GAIT custom state. Restart preview for a clean comparison."] call _report;
};
if (_unit getVariable ["GAIT_slopeAttemptLatched", false] || {_unit getVariable ["GAIT_slopeExitPending", false]}) exitWith {
    ["Refused: a GAIT animation entry or exit remains pending. Restart preview."] call _report;
};

_family = [_unit] call GAIT_fnc_slopeWeaponFamily;
if (_family isEqualTo "") exitWith {["Refused: use a rifle, pistol or unarmed pose."] call _report;};
private _states = configFile >> "CfgMovesMaleSdr" >> "States";
private _customForward = [_family, "Df"] call GAIT_fnc_slopeStateName;
if (!isClass (_states >> _customForward) || {(getNumber (_states >> _customForward >> "GAIT_slopeState")) isNotEqualTo 1} || {((toLower _customForward) find "amovpercmeva") isNotEqualTo 0}) exitWith {
    ["Refused: the RC3 custom Meva sprint family is unavailable."] call _report;
};

missionNamespace setVariable ["GAIT32_trialBusyUntil", diag_tickTime + 15 + _duration + 5];
missionNamespace setVariable ["GAIT32_trialCancel", false];
missionNamespace setVariable ["GAIT32_trialLabel", _variant + ":armed"];
[format ["ARM %1 for %2 seconds. Close console and hold Turbo + forward within 15 seconds.", _variant, _duration]] call _report;

private _armDeadline = diag_tickTime + 15;
private _reason = "";
private _input = [0, 0, false];
private _ready = false;
waitUntil {
    uiSleep 0.01;
    _reason = [] call _contextReason;
    if (missionNamespace getVariable ["GAIT32_trialCancel", false]) then {_reason = "cancel requested";};
    if (diag_tickTime >= _armDeadline) then {_reason = "entry input timeout";};
    _input = [] call GAIT_fnc_getMovementInput;
    _ready = (_input select 2) && {(_input select 0) > 0.05} && {((toLower (animationState _unit)) find "_amov") < 0};
    _ready || {_reason isNotEqualTo ""}
};

private _entered = false;
private _sawTarget = false;
private _sawCustom = false;
private _entryTime = -1;
private _lastState = animationState _unit;
if (_reason isEqualTo "") then {
    private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
    private _custom = [_family, _direction] call GAIT_fnc_slopeStateName;
    _target = [_custom, getText (_states >> _custom >> "GAIT_nativeState")] select (_variant isEqualTo "native");
    if (!isClass (_states >> _target) || {(getText (_states >> _target >> "file")) isEqualTo ""}) then {
        _reason = "requested animation class or file missing";
    } else {
        _source = animationState _unit;
        _entryTime = diag_tickTime;
        missionNamespace setVariable ["GAIT32_trialLabel", _variant + ":active"];
        diag_log format ["[GAIT32_TRIAL] ENTRY variant=%1 source=%2 target=%3 sprintAllowed=%4 forcedWalk=%5 stamina=%6 fatigue=%7 coef=%8", _variant, _source, _target, isSprintAllowed _unit, isForcedWalk _unit, getStamina _unit, getFatigue _unit, getAnimSpeedCoef _unit];
        _unit playMoveNow _target;
        _entered = true;
        private _endTime = _entryTime + _duration;
        private _lastMovementTime = _entryTime;
        waitUntil {
            uiSleep 0.01;
            _input = [] call GAIT_fnc_getMovementInput;
            if (abs (_input select 0) > 0.05 || {abs (_input select 1) > 0.05}) then {_lastMovementTime = diag_tickTime;};
            private _state = animationState _unit;
            _sawTarget = _sawTarget || {(toLower _state) isEqualTo (toLower _target)};
            _sawCustom = _sawCustom || {[_state] call GAIT_fnc_isSlopeLocomotionState};
            if (_state isNotEqualTo _lastState) then {
                diag_log format ["[GAIT32_TRIAL] STATE elapsed=%1 state=%2 sprintAllowed=%3 forcedWalk=%4 grounded=%5", diag_tickTime - _entryTime, _state, isSprintAllowed _unit, isForcedWalk _unit, isTouchingGround _unit];
                _lastState = _state;
            };
            _reason = [] call _contextReason;
            if (_reason isEqualTo "" && {!(_input select 2)}) then {_reason = "Turbo released";};
            if (_reason isEqualTo "" && {diag_tickTime - _lastMovementTime > 0.35}) then {_reason = "movement input absent";};
            if (_reason isEqualTo "" && {diag_tickTime >= _endTime}) then {_reason = "time limit";};
            if (missionNamespace getVariable ["GAIT32_trialCancel", false]) then {_reason = "cancel requested";};
            _reason isNotEqualTo ""
        };
    };
};

// At most one exit. Re-evaluate context after stopping; a non-locomotion action
// or lost ground contact must retain control, even if an entry was requested.
private _exitSent = false;
private _stateAtStop = animationState _unit;
if (_entered && {_variant isEqualTo "custom"} && {([] call _contextReason) isEqualTo ""}) then {
    private _inCustom = [_stateAtStop] call GAIT_fnc_isSlopeLocomotionState;
    // The lowered walk/tactical native states can have a _ver2 clip suffix.
    // Normalize that known suffix on both endpoints; the strict body guard
    // above and the expected source/target pair still exclude other actions.
    private _blendNames = [_stateAtStop, _source, _target] apply {
        (((toLower _x) splitString "_") - ["ver2"]) joinString "_"
    };
    private _expectedBlend = _blendNames call GAIT_fnc_isStandingLocomotionBlend;
    if (_inCustom || {_expectedBlend}) then {
        _input = [] call GAIT_fnc_getMovementInput;
        private _direction = [_input select 0, _input select 1] call GAIT_fnc_slopeDirection;
        private _pace = ["Mrun", "Mwlk"] select (isForcedWalk _unit);
        if (isSprintAllowed _unit && {!isForcedWalk _unit} && {_input select 2} && {_direction in ["Df", "Dfl", "Dfr"]}) then {_pace = "Meva";};
        if (_direction isEqualTo "Dnon") then {_pace = "Mstp";};
        private _nativeExit = "AmovPerc" + _pace + _family + _direction;
        if (!isClass (_states >> _nativeExit)) then {_nativeExit = "AmovPercMstp" + _family + "Dnon";};
        if (isClass (_states >> _nativeExit)) then {
            diag_log format ["[GAIT32_TRIAL] EXIT source=%1 target=%2", _stateAtStop, _nativeExit];
            _unit playMoveNow _nativeExit;
            _exitSent = true;
        };
    };
};

missionNamespace setVariable ["GAIT32_trialLabel", _variant + ":stopped:" + _reason];
missionNamespace setVariable ["GAIT32_trialBusyUntil", -1];
diag_log format ["[GAIT32_TRIAL] OUTCOME variant=%1 reason=%2 entrySent=%3 requestedStateObserved=%4 customStateObserved=%5 elapsed=%6 finalState=%7 nativeExitSent=%8", _variant, _reason, _entered, _sawTarget, _sawCustom, [0, diag_tickTime - _entryTime] select _entered, _stateAtStop, _exitSent];
[format ["STOP %1: %2. Entry observed=%3; custom state observed=%4. Results are in the RPT. Restart preview for a clean next comparison.", _variant, _reason, _sawTarget, _sawCustom]] call _report;
