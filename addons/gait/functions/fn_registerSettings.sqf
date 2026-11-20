// GAIT options exposed in Eden and in live missions.
if (isNil "CBA_fnc_addSetting") exitWith {};

private _categoryMovement = ["GAIT", "Movement"];
private _categoryPlayer = ["GAIT", "Player preferences"];

private _addCheckbox = {
    params ["_name", "_title", "_tooltip", "_category", "_default", ["_global", true]];
    [_name, "CHECKBOX", [_title, _tooltip], _category, _default, _global, {}, false] call CBA_fnc_addSetting;
};

private _addSlider = {
    params ["_name", "_title", "_tooltip", "_category", "_range", ["_global", true]];
    [_name, "SLIDER", [_title, _tooltip], _category, _range, _global, {}, false] call CBA_fnc_addSetting;
};

["GAIT_ss_enabled", "Enable GAIT movement", "Enables GAIT traversal. Turn off to return movement control to Arma and ACE.",
    _categoryMovement, true] call _addCheckbox;
["GAIT_ss_sprintWalkTaperDuration", "Sprint release taper (seconds)", "Controls how gradually pace eases after releasing sprint on level ground. Terrain still adjusts the duration and direction input remains live.",
    _categoryMovement, [2.3, 2.9, 2.7, 1]] call _addSlider;
["GAIT_ss_masterTripFrequency", "Downhill trip frequency", "Scales how often high-speed downhill trips occur. 0 turns trips off. 1 is the standard rate.",
    _categoryMovement, [0, 1.5, 1, 2]] call _addSlider;
["GAIT_ss_vegetationDragMax", "Maximum brush slowdown", "Limits the speed reduction in dense brush. 0 turns brush slowdown off. 0.18 allows up to 18% slowdown.",
    _categoryMovement, [0, 0.25, 0.18, 2]] call _addSlider;

["GAIT_ss_aceHeartbeatVolume", "ACE heartbeat volume (%)", "Adjusts the local heartbeat volume. 0 mutes it and 100 uses original ACE volume.",
    _categoryPlayer, [0, 100, 10, 0], false] call _addSlider;
["GAIT_ss_debugHudEnabled", "Movement debug HUD", "Shows local movement diagnostics and writes GAIT messages to the Arma RPT while enabled.",
    _categoryPlayer, false, false] call _addCheckbox;
