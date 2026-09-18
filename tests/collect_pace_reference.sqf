/*
    Optional empirical pace collection. This is not a required gameplay step.

    Saved single-player Eden mission, flat open ground, healthy player:
    disable GAIT and ACE Advanced Fatigue in mission Addon Options and restart
    preview. Disable native stamina for this calibration preview separately:
      player enableStamina false;
    Restart preview after collection to restore the mission's normal state.
    Use the same animation addons that the final profile will target.
    LOCAL EXEC, close console, then move normally for several seconds at each
    desired walking/jogging/sprinting direction without obstacles or turning:

      [120] execVM "collect_pace_reference.sqf";

    Stop early: GAIT_paceReferenceStop = true;
    This collector itself does not change or refill stamina.
    Accepted segments require native standing clips, coefficient 1, nearly
    flat terrain, ground contact, no fatigue/restriction, and a stable clip.
    Each result needs at least two separate one-second movement windows.

    Output: [GAIT_PACE_REFERENCE] records in the RPT, plus diagnostic variable
    GAIT_paceReferenceCandidates. No gameplay profile is installed. Missing
    gait measurements are -1. Review clip/configuration and speed consistency
    before using candidates as GAIT_locomotionPaceProfiles in a TEST mission.
    Collection measures observed unimpeded movement, not decoded RTM data.
    Collision/another addon can still bias a candidate. There is no velocity
    feedback, animation command, coefficient/position/stamina/settings write.
*/

params [["_duration", 120, [0]]];
_duration = _duration max 10 min 300;
private _report = {
    params ["_message"];
    diag_log ("[GAIT_PACE_REFERENCE] " + _message);
    systemChat ("GAIT pace collection: " + _message);
};
if (!hasInterface || {!is3DENPreview} || {isMultiplayer} || {!canSuspend}) exitWith {
    ["Use execVM in a single-player Eden preview."] call _report;
};
if ((missionNamespace getVariable ["GAIT_paceReferenceBusyUntil", -1]) > diag_tickTime) exitWith {
    ["Already collecting. Set GAIT_paceReferenceStop = true to stop."] call _report;
};
if ((missionNamespace getVariable ["GAIT_ss_enabled", true]) ||
    {missionNamespace getVariable ["ace_advanced_fatigue_enabled", false]}) exitWith {
    ["Disable GAIT and ACE Advanced Fatigue in mission options, then restart preview first."] call _report;
};
private _unit = player;
if (isNull _unit || {!local _unit} || {!alive _unit}) exitWith {
    ["A live local player is required."] call _report;
};
if (isStaminaEnabled _unit) exitWith {
    ["Disable native stamina in this calibration preview first: player enableStamina false. Restart preview after collection."] call _report;
};

private _clips = [];
{
    private _family = _x;
    {
        private _direction = _x;
        {
            private _clip = "AmovPerc" + _x + _family + _direction;
            private _cfg = configFile >> "CfgMovesMaleSdr" >> "States" >> _clip;
            if (isClass _cfg && {(getText (_cfg >> "file")) isNotEqualTo ""}) then {
                // name, family, direction, gait column, block speeds, RTM,
                // config speed. Retain exact metadata alongside the result.
                _clips pushBack [toLower _clip, _family, _direction,
                    _forEachIndex + 2, [], getText (_cfg >> "file"), getNumber (_cfg >> "speed")];
            };
        } forEach ["Mwlk", "Mrun", "Meva"];
    } forEach ["Df", "Dfr", "Dr", "Dbr", "Db", "Dbl", "Dl", "Dfl"];
} forEach ["SrasWrfl", "SlowWrfl", "SrasWpst", "SnonWnon"];

private _deadline = diag_tickTime + _duration;
missionNamespace setVariable ["GAIT_paceReferenceBusyUntil", _deadline + 1];
missionNamespace setVariable ["GAIT_paceReferenceStop", false];
private _priorTime = diag_tickTime;
private _priorPosition = getPosASL _unit;
private _priorHeading = getDir _unit;
private _stableClip = -1;
private _stableSince = _priorTime;
private _blockTime = 0;
private _blockDistance = 0;
private _reason = "time limit";
diag_log format ["[GAIT_PACE_REFERENCE] START version=%1 duration=%2 loadAbs=%3", productVersion, _duration, loadAbs _unit];
[format ["Collecting for %1 seconds. Walk, jog and sprint on flat unobstructed ground; keep each direction steady.", _duration]] call _report;

waitUntil {
    uiSleep 0.025;
    private _now = diag_tickTime;
    private _stop = _now >= _deadline;
    if (missionNamespace getVariable ["GAIT_paceReferenceStop", false]) then {_stop = true; _reason = "requested";};
    if (isNull _unit || {_unit isNotEqualTo player} || {!local _unit} || {!alive _unit}) then {_stop = true; _reason = "player changed";};
    if ((missionNamespace getVariable ["GAIT_ss_enabled", true]) ||
        {missionNamespace getVariable ["ace_advanced_fatigue_enabled", false]}) then {_stop = true; _reason = "movement system enabled";};
    if (isStaminaEnabled _unit) then {_stop = true; _reason = "native stamina enabled";};
    if (!_stop) then {
        private _position = getPosASL _unit;
        private _heading = getDir _unit;
        private _elapsed = _now - _priorTime;
        private _animation = toLower (animationState _unit);
        private _clip = _clips findIf {(_x select 0) isEqualTo _animation};
        private _headingChange = abs (((_heading - _priorHeading + 540) mod 360) - 180);
        private _delta = _position vectorDiff _priorPosition;
        private _distance = sqrt (((_delta select 0) ^ 2) + ((_delta select 1) ^ 2));
        private _speed = _distance / (_elapsed max 0.001);
        private _eligible = _clip >= 0 && {_elapsed >= 0.005} && {_elapsed <= 0.15} &&
            {_headingChange <= 1} && {_speed >= 0.05} && {_speed <= 25} &&
            {abs (_delta select 2) <= (_distance * 0.035 + 0.002)} &&
            {((surfaceNormal (getPosATL _unit)) select 2) >= cos 1} &&
            {isTouchingGround _unit} && {(stance _unit) isEqualTo "STAND"} &&
            {isNull (objectParent _unit)} && {isNull (attachedTo _unit)} &&
            {damage _unit <= 0.001} && {(lifeState _unit) isEqualTo "HEALTHY"} &&
            {!(_unit getVariable ["ACE_isUnconscious", false])} &&
            {isSprintAllowed _unit} && {!isForcedWalk _unit} &&
            {(_unit getVariable ["ace_common_effect_blockSprint", 0]) <= 0} &&
            {(_unit getVariable ["ace_common_effect_forceWalk", 0]) <= 0} &&
            {abs ((getAnimSpeedCoef _unit) - 1) < 0.001} &&
            {getFatigue _unit <= 0.05};
        if (!_eligible || {_clip isNotEqualTo _stableClip}) then {
            _stableClip = [-1, _clip] select _eligible;
            _stableSince = _now;
            _blockTime = 0;
            _blockDistance = 0;
        } else {
            if ((_now - _stableSince) >= 0.75) then {
                _blockTime = _blockTime + _elapsed;
                _blockDistance = _blockDistance + _distance;
                if (_blockTime >= 1) then {
                    ((_clips select _clip) select 4) pushBack (_blockDistance / _blockTime);
                    _blockTime = 0;
                    _blockDistance = 0;
                };
            };
        };
        _priorTime = _now;
        _priorPosition = _position;
        _priorHeading = _heading;
    };
    _stop
};

private _candidates = [];
private _accepted = 0;
{
    _x params ["_clip", "_family", "_direction", "_column", "_speeds", "_rtm", "_configSpeed"];
    if ((count _speeds) >= 2) then {
        _speeds sort true;
        private _count = count _speeds;
        private _middle = floor (_count / 2);
        private _median = _speeds select _middle;
        if ((_count mod 2) isEqualTo 0) then {_median = (_median + (_speeds select (_middle - 1))) / 2;};
        private _spread = ((_speeds select (_count - 1)) - (_speeds select 0)) / (_median max 0.05);
        diag_log format ["[GAIT_PACE_REFERENCE] CLIP %1", [_clip, _median, _count, _spread, _rtm, _configSpeed]];
        if (_spread <= 0.10) then {
            private _row = _candidates findIf {(_x select 0) isEqualTo _family && {(_x select 1) isEqualTo _direction}};
            if (_row < 0) then {_row = _candidates pushBack [_family, _direction, -1, -1, -1];};
            (_candidates select _row) set [_column, _median];
            _accepted = _accepted + 1;
        };
    };
} forEach _clips;
missionNamespace setVariable ["GAIT_paceReferenceCandidates", _candidates];
missionNamespace setVariable ["GAIT_paceReferenceBusyUntil", -1];
diag_log format ["[GAIT_PACE_REFERENCE] CANDIDATES %1", _candidates];
[format ["Stopped (%1). %2 stable clip candidates in RPT; none activated. Missing references stay -1.", _reason, _accepted]] call _report;
