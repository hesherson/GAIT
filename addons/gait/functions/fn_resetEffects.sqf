/*
    GAIT_fnc_resetEffects
    Local safety reset for movement speed, hearing, tinnitus, and post-process effects.
    Intended for respawn, spectator transitions, Zeus reset module, and admin recovery.
*/

params [
    ["_reason", "manual", [""]]
];

if (!hasInterface) exitWith {};

if (!isNil "GAIT_fnc_releaseFatigueVisuals") then {[] call GAIT_fnc_releaseFatigueVisuals;};

if (!isNil "GAIT_fnc_releaseNativeStaminaOwnership") then {
    [] call GAIT_fnc_releaseNativeStaminaOwnership;
};

// Release the actual unit whose movement GAIT owns before clearing state.
// This also handles respawn/player replacement without applying old movement
// values to the new player or overwriting another system's animation speed.
if (!isNil "GAIT_fnc_releaseNativeMovement") then {
    [] call GAIT_fnc_releaseNativeMovement;
};

missionNamespace setVariable ["GAIT_resetRequested", time];
missionNamespace setVariable ["GAIT_coastUnit", objNull];
missionNamespace setVariable ["GAIT_coastActive", false];
missionNamespace setVariable ["GAIT_coastReadyUntil", -1];
missionNamespace setVariable ["GAIT_exhaustionLevel", 0];
missionNamespace setVariable ["GAIT_tinnitusTargetVolume", 0];
missionNamespace setVariable ["GAIT_tinnitusCurrentVolume", 0];
missionNamespace setVariable ["GAIT_shiftHeld", false];
missionNamespace setVariable ["GAIT_lastShiftRelease", time];
missionNamespace setVariable ["GAIT_slopeDegrees", 0];
missionNamespace setVariable ["GAIT_slopeSpeedMultiplier", 1];
missionNamespace setVariable ["GAIT_lastTripTime", -999];

// Movement transients must not survive a manual/Zeus/player-context reset.
missionNamespace setVariable ["GAIT_braceActive", false];
missionNamespace setVariable ["GAIT_braceEndTime", -1];
missionNamespace setVariable ["GAIT_uphillBrakeActive", false];
missionNamespace setVariable ["GAIT_uphillBrakeEndTime", -1];
missionNamespace setVariable ["GAIT_uphillBrakeReadyUntil", -1];
missionNamespace setVariable ["GAIT_uphillBrakeUnit", objNull];
missionNamespace setVariable ["GAIT_uphillBrakeSeverity", 0];
missionNamespace setVariable ["GAIT_uphillBrakeTarget", 0];
missionNamespace setVariable ["GAIT_slopeJogOverride", false];
missionNamespace setVariable ["GAIT_downhillMomentum", 0];
missionNamespace setVariable ["GAIT_downhillGravityTargetKmh", 0];
missionNamespace setVariable ["GAIT_walkStartBraceActive", false];
missionNamespace setVariable ["GAIT_walkStartBraceFactor", 1];
missionNamespace setVariable ["GAIT_walkStartBraceTier", -1];

if (!isNull player) then {
    player setVariable ["GAIT_isTripping", false, false];
    if (!isNil "GAIT_fnc_clearLocomotionInputHistory") then {
        [player] call GAIT_fnc_clearLocomotionInputHistory;
    };
};

if (!isNil "GAIT_fnc_stopTinnitusSound") then {
    [] call GAIT_fnc_stopTinnitusSound;
};

if (!isNil "GAIT_fnc_setSprintHearing") then {
    [1, 0.15, false] call GAIT_fnc_setSprintHearing;
};

if (!isNil "GAIT_fnc_setTunnelVisionFX") then {
    [0, true] call GAIT_fnc_setTunnelVisionFX;
};

if (!isNil "GAIT_fnc_clearOldExhaustionVignette") then {
    [] call GAIT_fnc_clearOldExhaustionVignette;
};

diag_log format ["[GAIT] Effects reset (%1).", _reason];
