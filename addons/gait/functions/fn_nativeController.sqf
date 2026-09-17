/*
    GAIT 1.7.0-rc3: one owner for the movement speed coefficient.
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

GAIT_fnc_clearACEAdvancedFatigueMovementLocks = {
    params [["_unit", player, [objNull]]];
    if !(call GAIT_fnc_modeAllowsAceLockClearing) exitWith {};
    if !(call GAIT_fnc_aceAdvancedFatigueActive) exitWith {};
    if (isNil "ace_common_fnc_statusEffect_set") exitWith {};
    if !([_unit] call GAIT_fnc_nativeMovementEligible) exitWith {};

    // No angle cutoff: GAIT scales pace continuously on traversable terrain.
    // Never call forceWalk false: ACE combines restrictions by source.
    [_unit, "blockSprint", "ace_advanced_fatigue", false] call ace_common_fnc_statusEffect_set;
    [_unit, "forceWalk", "ace_advanced_fatigue", false] call ace_common_fnc_statusEffect_set;
};

GAIT_fnc_installNativeAceBridge = {
    if (missionNamespace getVariable ["GAIT_nativeAceBridgeInstalled", false]) exitWith {};
    if (isNil "ace_advanced_fatigue_fnc_handleEffects") exitWith {};
    GAIT_nativeOriginalAceHandleEffects = ace_advanced_fatigue_fnc_handleEffects;
    ace_advanced_fatigue_fnc_handleEffects = {
        _this call GAIT_nativeOriginalAceHandleEffects;
        // ACE's mainLoop resolves handleEffects dynamically. Remove only its
        // movement restriction in the same call; all physiology/effects ran.
        [_this param [0, objNull]] call GAIT_fnc_clearACEAdvancedFatigueMovementLocks;
    };
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
