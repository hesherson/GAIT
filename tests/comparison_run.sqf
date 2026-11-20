/*
    Copy beside foundation_capture.sqf in a test mission.
    LOCAL EXEC on each participating client:
      ["light rifle raised", serverTime + 15] execVM "comparison_run.sqf";
    Use the same future serverTime on all clients for a synchronized run.
    Repeat with light, medium and heavy kit, then each weapon pose.
    The script records and gives keyboard cues. Players supply all movement.
    It does not change loadout, reserve, position, animation, or input.
*/
if (!hasInterface || {!canSuspend} || {isNull player}) exitWith {};
params [["_label", "current kit and weapon", [""]], ["_start", serverTime + 10, [0]], ["_trial", "interruptions", [""]]];
if !(_trial in ["interruptions", "ordinary", "burst"]) exitWith {systemChat "Use interruptions, ordinary or burst for the trial."};
if (missionNamespace getVariable ["GAIT_comparisonRunning", false]) exitWith {
    systemChat "GAIT comparison already running.";
};
if (!fileExists "foundation_capture.sqf") exitWith {
    systemChat "Copy foundation_capture.sqf beside comparison_run.sqf first.";
};
missionNamespace setVariable ["GAIT_comparisonRunning", true];
private _unit = player;
private _phases = [
    [2, "idle", "Release movement and sprint."],
    [8, "sprint from idle", "Hold Shift+W and keep the current weapon pose."],
    [1, "wind-down", "Release Shift and keep W held."],
    [1.5, "strafe reversal", "Keep W held and alternate A and D immediately."],
    [6, "sprint from jog", "Hold Shift+W again."],
    [2.5, "Ctrl wind-down", "Release Shift, keep Ctrl+W held and alternate A and D."],
    [5, "sprint before crouch", "Release Ctrl and hold Shift+W."],
    [1.5, "crouch interruption", "Release Shift, keep W and immediately press crouch."],
    [5, "sprint before aim", "Hold Shift+W."],
    [1.5, "aim interruption", "Release Shift, keep W and immediately aim down sights."],
    [5, "sprint before pistol", "Release aim and hold Shift+W."],
    [2, "pistol interruption", "Release Shift, keep W and immediately select your pistol."],
    [5, "sprint before launcher", "Hold Shift+W."],
    [2, "launcher interruption", "Release Shift, keep W and immediately select your launcher if equipped."],
    [4, "sprint before stop", "Hold Shift+W."],
    [3, "full stop", "Release Shift and all movement. Check that fresh A or D responds immediately."]
];
if (_trial isNotEqualTo "interruptions") then {
    private _cue = ["From rest hold W and sprint together.", "From rest hold W, double-tap sprint and hold the second press."] select (_trial isEqualTo "burst");
    _phases = [[2,"idle","Stand still with full reserve."],[18,"distance " + _trial,_cue + " Keep going straight through the 30 m mark."]];
};
systemChat format ["GAIT comparison %1 starts in %2 seconds. Use open ground.", _label, ceil ((_start - serverTime) max 0)];
waitUntil {uiSleep 0.1; serverTime >= _start || {player isNotEqualTo _unit} || {!alive _unit}};
if (player isNotEqualTo _unit || {!alive _unit}) exitWith {
    missionNamespace setVariable ["GAIT_comparisonRunning", false];
};
[80, "comparison " + _label] execVM "foundation_capture.sqf";
{
    _x params ["_seconds", "_phase", "_instruction"];
    if (!(missionNamespace getVariable ["GAIT_comparisonRunning", false]) ||
        {player isNotEqualTo _unit} || {!alive _unit}) exitWith {};
    missionNamespace setVariable ["GAIT_comparisonPhase", _phase];
    systemChat format ["GAIT %1 (%2 s) - %3", _phase, _seconds, _instruction];
    private _deadline = serverTime + _seconds;
    waitUntil {
        uiSleep 0.05;
        serverTime >= _deadline || {player isNotEqualTo _unit} || {!alive _unit} ||
            {!(missionNamespace getVariable ["GAIT_comparisonRunning", false])}
    };
} forEach _phases;
missionNamespace setVariable ["GAIT_foundationCaptureEnabled", false];
missionNamespace setVariable ["GAIT_comparisonRunning", false];
missionNamespace setVariable ["GAIT_comparisonPhase", "free movement"];
systemChat "GAIT comparison finished. Repeat with the next kit or weapon pose.";
