/*
    GAIT 1.8.0-alpha1: one owner for the movement speed coefficient.
    Arma handles direction and collision inside the dedicated sprint action family.
*/
// Coefficient ownership can change during an ordinary animation blend.
// Acquiring it must not issue a second body-animation release.
GAIT_fnc_releaseSpeedCoefficient = {
    private _owner = missionNamespace getVariable ["GAIT_nativeOwner", objNull];
    private _written = missionNamespace getVariable ["GAIT_nativeLastWritten", -1];
    if (!isNull _owner && {local _owner} && {_written >= 0}) then {
        if (abs ((getAnimSpeedCoef _owner) - _written) < 0.001) then {
            _owner setAnimSpeedCoef (missionNamespace getVariable ["GAIT_nativePreviousCoef", 1]);
        };
    };
    if (!isNil "ace_advanced_fatigue_setAnimExclusions") then {
        ace_advanced_fatigue_setAnimExclusions = ace_advanced_fatigue_setAnimExclusions - ["GAIT", "GAIT_VEG"];
    };
    missionNamespace setVariable ["GAIT_nativeOwner", objNull];
    missionNamespace setVariable ["GAIT_nativeLastWritten", -1];
    missionNamespace setVariable ["GAIT_nativeMovementActive", false];
    missionNamespace setVariable ["GAIT_vegDragFactor", 0];
};

GAIT_fnc_releaseNativeMovement = {
    // Empty arguments prevent inheriting [unit, coefficient, carry] from the
    // speed writer. The release helper expects an input array in slot two.
    if (!isNil "GAIT_fnc_releaseSlopeLocomotion") then {[] call GAIT_fnc_releaseSlopeLocomotion;};
    [] call GAIT_fnc_releaseSpeedCoefficient;
};

// Fatigue policy ownership is broader than permission to scale this frame's
// animation. Ordinary blends, reload gestures and brief ground-contact loss
// must not let AF repeatedly reinstate its slope restriction.
GAIT_fnc_fatigueMovementContextEligible = {
    params [["_unit", player, [objNull]]];
    if (isNull _unit || {!local _unit} || {_unit isNotEqualTo player} || {!alive _unit}) exitWith {false};
    if (call GAIT_fnc_isSuspendedContext) exitWith {false};
    if (!isNull (objectParent _unit) || {!isNull (attachedTo _unit)}) exitWith {false};
    if ((lifeState _unit) isEqualTo "INCAPACITATED") exitWith {false};
    if (underwater _unit || {missionNamespace getVariable ["ace_advanced_fatigue_isSwimming", false]}) exitWith {false};

    private _restricted = [
        "ACE_isUnconscious",
        "GAIT_isTripping",
        "MAV_fastCarry_pickupActive",
        "ace_dragging_isDragging",
        "ace_dragging_isDragged",
        "ace_dragging_isCarried",
        "ace_dragging_isCarrying",
        "ace_common_isClimbing",
        "ace_medical_treatment_inProgress"
    ] findIf {(_unit getVariable [_x, false]) isEqualTo true};
    if (_restricted >= 0) exitWith {false};
    if ((missionNamespace getVariable ["ace_common_isClimbing", false]) isEqualTo true) exitWith {false};
    if ((missionNamespace getVariable ["ace_medical_treatment_inProgress", false]) isEqualTo true) exitWith {false};
    true
};

GAIT_fnc_ownsFatigueMovementPolicy = {
    params [["_unit", player, [objNull]]];
    (call GAIT_fnc_modeAllowsAceLockClearing) &&
    {call GAIT_fnc_aceAdvancedFatigueActive} &&
    {[_unit] call GAIT_fnc_fatigueMovementContextEligible}
};

GAIT_fnc_clearACEAdvancedFatigueMovementLocks = {
    params [["_unit", player, [objNull]]];
    if (isNil "ace_common_fnc_statusEffect_set") exitWith {};
    if !([_unit] call GAIT_fnc_ownsFatigueMovementPolicy) exitWith {};

    // No angle cutoff: GAIT scales pace continuously on traversable terrain.
    // Never call forceWalk false: ACE combines restrictions by source.
    [_unit, "blockSprint", "ace_advanced_fatigue", false] call ace_common_fnc_statusEffect_set;
    [_unit, "forceWalk", "ace_advanced_fatigue", false] call ace_common_fnc_statusEffect_set;
};

GAIT_fnc_installNativeAceBridge = {
    if (missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false]) exitWith {};
    // Keep our handler IDs across GAIT resets/recompilation. The callbacks
    // resolve GAIT's helper at dispatch time, so reinstalling would duplicate them.
    if ((missionNamespace getVariable ["GAIT_nativeAceBridgeHandlers", []]) isNotEqualTo []) exitWith {
        missionNamespace setVariable ["GAIT_nativeAceBridgeInstalled", true];
    };
    if (isNil "CBA_fnc_addEventHandler" || {isNil "ace_common_fnc_statusEffect_set"}) exitWith {};
    // ACE sets this after registering its own movement event handlers. CBA
    // appends handlers in order; ours must run after ACE applies the new mask.
    if !(missionNamespace getVariable ["ace_common_commonPostInited", false]) exitWith {};

    private _handlers = [];
    {
        private _id = [_x, {
            params [["_unit", objNull, [objNull]], ["_mask", 0, [0]]];
            // Clearing the last source emits a nested zero-mask event. Stop
            // there; positive masks may still belong to another ACE component.
            if (_mask <= 0) exitWith {};
            [_unit] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
        }] call CBA_fnc_addEventHandler;
        _handlers pushBack [_x, _id];
    } forEach ["ace_common_blockSprint", "ace_common_forceWalk"];

    // ACE's local status events are synchronous. Clear only its AF owner in
    // that dispatch, before the scheduled GAIT loop can observe a lasting lock.
    // ACE owns all event application and keeps other reasons in its bitmask.
    // Its compiled-final effects function and physiology are left intact.
    missionNamespace setVariable ["GAIT_nativeAceBridgeHandlers", _handlers];
    missionNamespace setVariable ["GAIT_nativeAceBridgeInstalled", true];
};

GAIT_fnc_applyNativeMovement = {
    params [["_unit", player, [objNull]], ["_coefficient", 1, [0]], ["_allowCarry", false, [false]]];
    if !([_unit, _allowCarry] call GAIT_fnc_nativeMovementEligible) exitWith {
        [] call GAIT_fnc_releaseNativeMovement;
    };
    private _owner = missionNamespace getVariable ["GAIT_nativeOwner", objNull];
    if (_owner != _unit) then {
        [] call GAIT_fnc_releaseSpeedCoefficient;
        missionNamespace setVariable ["GAIT_nativeOwner", _unit];
        missionNamespace setVariable ["GAIT_nativePreviousCoef", getAnimSpeedCoef _unit];
    };

    // Vegetation contributes to this same write, never a second speed loop.
    private _drag = 0;
    if (missionNamespace getVariable ["GAIT_ss_vegetationDragEnabled", true]) then {
        if (time >= (missionNamespace getVariable ["GAIT_vegNextCheck", -1])) then {
            private _radius = (missionNamespace getVariable ["GAIT_ss_vegetationDragRadius", 2.5]) max 0.5 min 8;
            private _maxDrag = (missionNamespace getVariable ["GAIT_ss_vegetationDragMax", 0.18]) max 0 min 0.75;
            {
                private _weight = 1 - ((_unit distance2D _x) / _radius) min 1;
                _drag = _drag + (_maxDrag * 0.55 * _weight);
            } forEach (nearestTerrainObjects [_unit, ["BUSH"], _radius, false, true]);
            missionNamespace setVariable ["GAIT_vegDragFactor", _drag min _maxDrag];
            missionNamespace setVariable ["GAIT_vegNextCheck", time + 0.4];
        };
        _drag = missionNamespace getVariable ["GAIT_vegDragFactor", 0];
    } else {
        missionNamespace setVariable ["GAIT_vegDragFactor", 0];
    };
    if (missionNamespace getVariable ["GAIT_ss_registerAceAnimExclusion", true]) then {
        if (!isNil "ace_advanced_fatigue_setAnimExclusions") then {
            ace_advanced_fatigue_setAnimExclusions pushBackUnique "GAIT";
        };
    } else {
        if (!isNil "ace_advanced_fatigue_setAnimExclusions") then {
            ace_advanced_fatigue_setAnimExclusions = ace_advanced_fatigue_setAnimExclusions - ["GAIT"];
        };
    };
    private _final = (_coefficient * (1 - _drag)) max 0.000001;
    _unit setAnimSpeedCoef _final;
    missionNamespace setVariable ["GAIT_nativeLastWritten", _final];
    missionNamespace setVariable ["GAIT_nativeMovementActive", true];
};
