/*
    GAIT_fnc_applyPreset
    Applies readable runtime presets through CBA's settings resolver.
    CBA Addon Options remain available; choose Custom to stop preset rewrites.
*/

params [
    ["_preset", "Custom", ["", 0]]
];

if (_preset isEqualType 0) then {
    private _names = ["Custom", "Balanced", "Realistic", "Arcade", "Training", "Light Infantry", "Heavy Infantry"];
    _preset = _names param [_preset, "Custom"];
};

if (_preset isEqualTo "Custom") exitWith {
    missionNamespace setVariable ["GAIT_lastPresetApplied", _preset];
    diag_log "[GAIT] Preset: Custom selected. No runtime values changed.";
};

// CBA is a required dependency. If initialization has not finished yet, leave
// GAIT_lastPresetApplied unchanged so the main loop retries once it is ready.
// Never fall back to raw runtime writes: that bypasses forced mission/server
// settings and leaves Addon Options displaying a different effective value.
if (isNil "CBA_settings_fnc_set") exitWith {};

private _set = {
    params ["_name", "_value"];
    // Older presets retain entries for retired options. Only registered,
    // initialized settings participate in the current build.
    if (isNil {missionNamespace getVariable _name}) exitWith {};

    // Verified CBA settings API: setting, value, priority, source, store.
    // A non-forcing client preference keeps CBA's mission/server precedence;
    // CBA refreshes the effective runtime value and the Addon Options UI.
    // Do not persist every preset value to the player's profile.
    [_name, _value, 0, "client", false] call CBA_settings_fnc_set;
};

// Shared sane defaults first.
{
    _x call _set;
} forEach [
    ["GAIT_ss_slopeLocomotionEnabled", true],
    ["GAIT_ss_exhaustedRunPace", 0.70],
    ["GAIT_ss_extraHeavyPenaltyPer50Lb", 0.18],
    ["GAIT_ss_normalSpeed", 0.90],
    ["GAIT_ss_sprintFullSpeed", 1.00],
    ["GAIT_ss_flatSprintPeak", 1.14],
    ["GAIT_ss_speedLerp", 0.05],
    ["GAIT_ss_masterTripFrequency", 1.00],
    ["GAIT_ss_wReleaseZeroMomentumDelay", 0.50],
    ["GAIT_ss_shiftReleaseRunTaperEnabled", true],
    ["GAIT_ss_shiftReleaseRunTaperDuration", 1.15],
    ["GAIT_ss_sprintStartBraceDuration", 0.15],
    ["GAIT_ss_sprintStartBraceSpeed", 0.44],
    ["GAIT_ss_sprintStartBraceLerp", 0.575],
    ["GAIT_ss_slopeStopBraceEnabled", true],
    ["GAIT_ss_slopeStopBraceStartDegrees", 15.0],
    ["GAIT_ss_slopeStopBraceMaxDegrees", 35.0],
    ["GAIT_ss_slopeStopBraceExtraDuration", 0.18],
    ["GAIT_ss_slopeStopBraceExtraDip", 0.28],
    ["GAIT_ss_slopeStopBraceMemoryTime", 2.5],
    ["GAIT_ss_braceRequiredWalkTime", 2.0],
    ["GAIT_ss_braceRecentSprintCooldown", 3.0],
    ["GAIT_ss_lightSpeedBonus", 1.08],
    ["GAIT_ss_mediumSpeedBonus", 1.02],
    ["GAIT_ss_moderateSpeedBonus", 0.97],
    ["GAIT_ss_heavySpeedBonus", 0.92],
    ["GAIT_ss_lightBraceRelief", 0.55],
    ["GAIT_ss_mediumBraceRelief", 0.35],
    ["GAIT_ss_moderateBraceRelief", 0.18],
    ["GAIT_ss_heavyBraceRelief", 0.00],
    ["GAIT_ss_slopeHandlingEnabled", true],
    ["GAIT_ss_slopeSampleDistance", 2.0],
    ["GAIT_ss_uphillSlowdownEnabled", true],
    ["GAIT_ss_uphillStartDegrees", 2.0],
    ["GAIT_ss_uphillMaxDegrees", 35.0],
    ["GAIT_ss_uphillMaxPenalty", 0.40],
    ["GAIT_ss_vegetationDragEnabled", true],
    ["GAIT_ss_vegetationDragMax", 0.18],
    ["GAIT_ss_vegetationDragRadius", 2.50],
    ["GAIT_ss_hillWalkSlowdownEnabled", true],
    ["GAIT_ss_hillWalkSlowdownStartDegrees", 15.0],
    ["GAIT_ss_hillWalkSlowdownMaxDegrees", 40.0],
    ["GAIT_ss_hillWalkUphillMaxPenalty", 0.32],
    ["GAIT_ss_hillWalkDownhillMaxPenalty", 0.08],
    ["GAIT_ss_uphillFatigueDrainEnabled", true],
    ["GAIT_ss_uphillFatigueDrainStartDegrees", 10.0],
    ["GAIT_ss_uphillFatigueDrainMaxDegrees", 35.0],
    ["GAIT_ss_uphillFatigueDrainMaxMultiplier", 1.75],
    ["GAIT_ss_downhillBoostEnabled", true],
    ["GAIT_ss_downhillBoostStartDegrees", 0.5],
    ["GAIT_ss_downhillBoostMaxDegrees", 18.0],
    ["GAIT_ss_downhillMaxBoost", 0.03],
    ["GAIT_ss_downhillSustainedExtraBoost", 0.14],
    ["GAIT_ss_downhillMomentumBuildSeconds", 6.5],
    ["GAIT_ss_downhillSprintCapKmh", 30],
    ["GAIT_ss_downhillJogCapKmh", 18],
    ["GAIT_ss_downhillTripEnabled", true],
    ["GAIT_ss_downhillTripThresholdDegrees", 28.0],
    ["GAIT_ss_downhillTripMaxChancePerSecond", 0.10],
    ["GAIT_ss_downhillTripMaxDegrees", 45.0],
    ["GAIT_ss_downhillTripBaseChancePerSecond", 0.005],
    ["GAIT_ss_downhillTripCooldown", 10.0],
    ["GAIT_ss_downhillTripDuration", 1.00],
    ["GAIT_ss_downhillTripMinSpeedKmh", 20.0],
    ["GAIT_ss_downhillTripSpeedMaxKmh", 34.0],
    ["GAIT_ss_downhillTripSpeedInfluence", 1.0],
    ["GAIT_ss_downhillTripWeightInfluence", 1.0],
    ["GAIT_ss_downhillTripRequireSustainedMovement", true],
    ["GAIT_ss_downhillTripMinSprintSeconds", 5.0],
    ["GAIT_ss_downhillTripSustainedSpeedKmh", 20.0],
    ["GAIT_ss_downhillTripSustainedSpeedSeconds", 4.0],
    ["GAIT_ss_downhillTripPostFallImmunity", 10.0],
    ["GAIT_ss_downhillTripGetUpSpeedKmh", 7.0],
    ["GAIT_ss_downhillTripMaxRagdollDuration", 6.0],
    ["GAIT_ss_debugHudEnabled", false],
    ["GAIT_ss_debugHudInterval", 0.10]
];

switch (_preset) do {
    case "Realistic": {
        { _x call _set; } forEach [
            ["GAIT_ss_normalSpeed", 0.84],
            ["GAIT_ss_sprintFullSpeed", 1.18],
            ["GAIT_ss_speedLerp", 0.035],
            ["GAIT_ss_wReleaseZeroMomentumDelay", 0.35],
            ["GAIT_ss_sprintStartBraceDuration", 0.22],
            ["GAIT_ss_sprintStartBraceSpeed", 0.34],
            ["GAIT_ss_braceRequiredWalkTime", 2.4],
            ["GAIT_ss_lightSpeedBonus", 1.04],
            ["GAIT_ss_mediumSpeedBonus", 1.02],
            ["GAIT_ss_moderateSpeedBonus", 1.00],
            ["GAIT_ss_heavySpeedBonus", 0.96],
            ["GAIT_ss_uphillMaxPenalty", 0.45],
            ["GAIT_ss_downhillMaxBoost", 0.02]
        ];
    };

    case "Arcade": {
        { _x call _set; } forEach [
            ["GAIT_ss_normalSpeed", 1.00],
            ["GAIT_ss_sprintFullSpeed", 1.45],
            ["GAIT_ss_speedLerp", 0.12],
            ["GAIT_ss_wReleaseZeroMomentumDelay", 0.75],
            ["GAIT_ss_sprintStartBraceDuration", 0.08],
            ["GAIT_ss_sprintStartBraceSpeed", 0.70],
            ["GAIT_ss_lightBraceRelief", 0.85],
            ["GAIT_ss_mediumBraceRelief", 0.65],
            ["GAIT_ss_moderateBraceRelief", 0.45],
            ["GAIT_ss_heavyBraceRelief", 0.25],
            ["GAIT_ss_uphillMaxPenalty", 0.22],
            ["GAIT_ss_downhillMaxBoost", 0.06]
        ];
    };

    case "Training": {
        { _x call _set; } forEach [
            ["GAIT_ss_normalSpeed", 0.88],
            ["GAIT_ss_sprintFullSpeed", 1.25]
        ];
    };

    case "Light Infantry": {
        { _x call _set; } forEach [
            ["GAIT_ss_normalSpeed", 0.92],
            ["GAIT_ss_sprintFullSpeed", 1.35],
            ["GAIT_ss_lightSpeedBonus", 1.12],
            ["GAIT_ss_mediumSpeedBonus", 1.07],
            ["GAIT_ss_moderateSpeedBonus", 1.03],
            ["GAIT_ss_heavySpeedBonus", 1.00],
            ["GAIT_ss_lightBraceRelief", 0.75],
            ["GAIT_ss_mediumBraceRelief", 0.50],
            ["GAIT_ss_moderateBraceRelief", 0.28],
            ["GAIT_ss_uphillMaxPenalty", 0.30],
            ["GAIT_ss_downhillMaxBoost", 0.04]
        ];
    };

    case "Heavy Infantry": {
        { _x call _set; } forEach [
            ["GAIT_ss_normalSpeed", 0.82],
            ["GAIT_ss_sprintFullSpeed", 1.16],
            ["GAIT_ss_speedLerp", 0.035],
            ["GAIT_ss_wReleaseZeroMomentumDelay", 0.25],
            ["GAIT_ss_sprintStartBraceDuration", 0.25],
            ["GAIT_ss_sprintStartBraceSpeed", 0.30],
            ["GAIT_ss_lightSpeedBonus", 1.04],
            ["GAIT_ss_mediumSpeedBonus", 1.02],
            ["GAIT_ss_moderateSpeedBonus", 0.99],
            ["GAIT_ss_heavySpeedBonus", 0.94],
            ["GAIT_ss_lightBraceRelief", 0.45],
            ["GAIT_ss_mediumBraceRelief", 0.25],
            ["GAIT_ss_moderateBraceRelief", 0.10],
            ["GAIT_ss_heavyBraceRelief", 0.00],
            ["GAIT_ss_uphillMaxPenalty", 0.50],
            ["GAIT_ss_downhillMaxBoost", 0.02]
        ];
    };

    default {
        // Balanced uses the shared sane defaults above.
    };
};

missionNamespace setVariable ["GAIT_lastPresetApplied", _preset];
diag_log format ["[GAIT] Applied preset: %1", _preset];
