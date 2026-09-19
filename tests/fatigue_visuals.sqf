/* Load fn_fatigueVisuals.sqf first. Real timing and ownership are exercised;
   only engine time, body context, PP handles and the separate ACE bridge are
   mocked. Pixel appearance still requires an Arma client visual check. */
private _failures = [];
private _state = [];
private _pulse = [];
{
    _x params ["_now", "_expected"];
    _pulse = [_state, _now, 1] call GAIT_fnc_stepFatigueVisualPulse;
    _state = _pulse # 0;
    if (abs ((_pulse # 1) - _expected) > 0.0001) then {
        _failures pushBack format ["Pulse at %1: expected %2, got %3", _now, _expected, _pulse # 1];
    };
} forEach [[10,0], [10.2,0.07], [10.4,0.14], [10.65,0.14], [10.975,0.07], [11.31,0], [16.30,0], [16.32,0], [16.52,0.07]];

// A low-fatigue pulse is dimmer and has a longer, wholly clear interval.
_state = ([[],20,0.4] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_pulse = [_state,20.5,0.4] call GAIT_fnc_stepFatigueVisualPulse;
if (abs ((_pulse # 1) - 0.056) > 0.0001) then {_failures pushBack "Low fatigue opacity was not scaled";};
_pulse = [_pulse # 0,21.31,0.4] call GAIT_fnc_stepFatigueVisualPulse;
if (abs (((_pulse # 0) # 1) - 30.51) > 0.0001 || {(_pulse # 1) != 0}) then {_failures pushBack "Low fatigue did not get its 9.2-second clear gap";};

// Bad settings cannot exceed 14% opacity. A late frame completes the expired
// pulse and creates a full fresh off interval; there is no pulse catch-up.
_state = ([[],30,5] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_pulse = [_state,30.5,5] call GAIT_fnc_stepFatigueVisualPulse;
if (abs ((_pulse # 1) - 0.14) > 0.0001) then {_failures pushBack "Opacity clamp failed";};
_pulse = [_state,50,1] call GAIT_fnc_stepFatigueVisualPulse;
if (_pulse isNotEqualTo [[-1,55,0],0]) then {_failures pushBack "Missed frame replayed a pulse or shortened clear gap";};
if (([_state,30.5,0] call GAIT_fnc_stepFatigueVisualPulse) isNotEqualTo [[-1,35.5,0],0]) then {_failures pushBack "Recovery retained a pulse or lost the five-second clear gap";};
_pulse = [_state,29,1] call GAIT_fnc_stepFatigueVisualPulse;
if ((_pulse # 1) != 0 || {((_pulse # 0) # 1) != 34}) then {_failures pushBack "Clock regression retained a visible pulse";};

// A pulse can weaken with recovery but cannot snap darker when effort rises.
_state = ([[],60,0.3] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_pulse = [_state,60.5,1] call GAIT_fnc_stepFatigueVisualPulse;
if (abs ((_pulse # 1) - 0.042) > 0.0001) then {_failures pushBack "Rising fatigue jumped a pulse's snapshotted peak";};

// Brief threshold oscillation must not defeat either a completed pulse's
// existing off interval or a newly interrupted pulse's five-second cooldown.
_state = ([[],70,1] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_state = ([_state,71.31,1] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_state = ([_state,71.5,0] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_pulse = [_state,71.6,1] call GAIT_fnc_stepFatigueVisualPulse;
if ((_pulse # 1) != 0 || {abs (((_pulse # 0) # 1) - 76.31) > 0.0001}) then {_failures pushBack "Zero/rebound erased a completed pulse's clear interval";};
_state = ([[],80,1] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_state = ([_state,80.5,0] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_state = ([_state,80.6,0] call GAIT_fnc_stepFatigueVisualPulse) # 0;
_pulse = [_state,80.7,1] call GAIT_fnc_stepFatigueVisualPulse;
if (_pulse isNotEqualTo [[-1,85.5,0],0]) then {_failures pushBack "Brief recovery restarted a pulse or moved the fixed clear deadline";};

if ([objNull] call GAIT_fnc_fatigueVisualContextEligible) then {_failures pushBack "Null player passed production context";};
GAIT_testVisualTime = 100;
GAIT_testVisualContext = true;
GAIT_testVisualNextHandle = 411;
GAIT_testVisualCreateCount = 0;
GAIT_testVisualWrites = [];
GAIT_testVisualDestroyed = [];
GAIT_testVisualBridgeUpdates = 0;
GAIT_testVisualBridgeReleases = 0;
GAIT_fnc_fatigueVisualClock = {GAIT_testVisualTime};
GAIT_fnc_fatigueVisualContextEligible = {
    params ["_unit"];
    !isNull _unit && GAIT_testVisualContext
};
GAIT_fnc_createFatigueVignette = {
    GAIT_testVisualCreateCount = GAIT_testVisualCreateCount + 1;
    GAIT_testVisualNextHandle
};
GAIT_fnc_writeFatigueVignette = {GAIT_testVisualWrites pushBack +_this;};
GAIT_fnc_destroyFatigueVignette = {GAIT_testVisualDestroyed pushBack (_this # 0);};
GAIT_fnc_updateACEFatigueVisualOwnership = {GAIT_testVisualBridgeUpdates = GAIT_testVisualBridgeUpdates + 1;};
GAIT_fnc_releaseACEFatigueVisualOwnership = {GAIT_testVisualBridgeReleases = GAIT_testVisualBridgeReleases + 1;};
[] call GAIT_fnc_releaseFatigueVisuals;
private _unit = player;
[_unit,1] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_fatigueVisualFrame;
if (GAIT_testVisualCreateCount != 0) then {_failures pushBack "Zero-alpha pulse start created an effect";};
GAIT_testVisualTime = 100.2;
[] call GAIT_fnc_fatigueVisualFrame;
if (GAIT_testVisualCreateCount != 1 || {abs ((GAIT_testVisualWrites # 0 # 1) - 0.07) > 0.0001}) then {_failures pushBack "Real frame lifecycle did not fade into one owned effect";};
{
    GAIT_testVisualTime = _x;
    [_unit,1] call GAIT_fnc_updateFatigueVisuals;
    [] call GAIT_fnc_fatigueVisualFrame;
} forEach [100.6,100.95,101.31];
if (GAIT_testVisualDestroyed isNotEqualTo [411] || {missionNamespace getVariable ["GAIT_fatigueVignetteHandle",0] != -1}) then {_failures pushBack "Pulse completion did not destroy its effect";};

// Refreshing fatigue while resting does not preserve or recreate a baseline.
{
    GAIT_testVisualTime = _x;
    [_unit,1] call GAIT_fnc_updateFatigueVisuals;
    [] call GAIT_fnc_fatigueVisualFrame;
} forEach [102,103,104,105,106,106.3];
if (GAIT_testVisualCreateCount != 1 || {missionNamespace getVariable ["GAIT_fatigueVignetteAlpha",1] != 0}) then {_failures pushBack "Clear gap had a residual or repeated effect";};
GAIT_testVisualTime = 106.5;
[_unit,1] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_fatigueVisualFrame;
GAIT_testVisualTime = 106.7;
[_unit,1] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_fatigueVisualFrame;
if (GAIT_testVisualCreateCount != 2) then {_failures pushBack "Next fatigue pulse did not start after clear gap";};

// Main loop stalls during a visible pulse. Independent frame lease removes
// both our PP and the ACE suppression lease without another main update.
private _bridgeReleases = GAIT_testVisualBridgeReleases;
GAIT_testVisualTime = 107.451;
[] call GAIT_fnc_fatigueVisualFrame;
if ((count GAIT_testVisualDestroyed) != 2 || {(missionNamespace getVariable ["GAIT_fatigueVisualRequest",[1]]) isNotEqualTo []} || {GAIT_testVisualBridgeReleases <= _bridgeReleases}) then {_failures pushBack "Stalled caller left a PP or ACE visual ownership behind";};

// At zero fatigue we remain a fresh owner of ACE's fatigue-only visual policy,
// while our own cue is fully cleared. Otherwise ACE could toggle each tick.
GAIT_testVisualTime = 110;
[_unit,0] call GAIT_fnc_updateFatigueVisuals;
_bridgeReleases = GAIT_testVisualBridgeReleases;
private _bridgeUpdates = GAIT_testVisualBridgeUpdates;
[] call GAIT_fnc_fatigueVisualFrame;
if (GAIT_testVisualBridgeReleases != _bridgeReleases || {GAIT_testVisualBridgeUpdates != (_bridgeUpdates + 1)} || {missionNamespace getVariable ["GAIT_fatigueVignetteHandle",0] != -1}) then {_failures pushBack "Recovery toggled fatigue policy or kept an effect";};

// A settings/context change is sampled on the very next rendered frame,
// independently of the slower main loop. Repeated cleanup is idempotent.
GAIT_testVisualTime = 120;
[_unit,1] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_fatigueVisualFrame;
GAIT_testVisualTime = 120.2;
[] call GAIT_fnc_fatigueVisualFrame;
private _destroyedBefore = count GAIT_testVisualDestroyed;
GAIT_testVisualContext = false;
[] call GAIT_fnc_fatigueVisualFrame;
[] call GAIT_fnc_releaseFatigueVisuals;
[] call GAIT_fnc_releaseFatigueVisuals;
if ((count GAIT_testVisualDestroyed) != (_destroyedBefore + 1)) then {_failures pushBack "Context loss or repeated release mishandled effect destruction";};

// Replacing the player never lets a prior owner's cue survive. Creation
// failure is inert, with one attempt and a full gap before retrying.
GAIT_testVisualContext = true;
GAIT_testVisualTime = 130;
[_unit,1] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_fatigueVisualFrame;
GAIT_testVisualTime = 130.2;
[] call GAIT_fnc_fatigueVisualFrame;
_destroyedBefore = count GAIT_testVisualDestroyed;
private _replacement = "B_Soldier_F" createVehicle [0,0,0];
[_replacement,1] call GAIT_fnc_updateFatigueVisuals;
if ((count GAIT_testVisualDestroyed) != (_destroyedBefore + 1) || {((missionNamespace getVariable ["GAIT_fatigueVisualPulse",[1]]) # 0) >= 0}) then {_failures pushBack "Player replacement retained old pulse ownership";};
[] call GAIT_fnc_releaseFatigueVisuals;
GAIT_testVisualTime = 140;
GAIT_testVisualNextHandle = -1;
private _createBefore = GAIT_testVisualCreateCount;
[_unit,1] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_fatigueVisualFrame;
{
    GAIT_testVisualTime = _x;
    [_unit,1] call GAIT_fnc_updateFatigueVisuals;
    [] call GAIT_fnc_fatigueVisualFrame;
} forEach [140.2,140.3,140.4];
if (GAIT_testVisualCreateCount != (_createBefore + 1)) then {_failures pushBack "PP creation failure caused per-frame retries";};
if ((GAIT_testVisualDestroyed findIf {_x != 411}) >= 0) then {_failures pushBack "Cleanup touched an unowned PP handle";};
[_unit,0] call GAIT_fnc_updateFatigueVisuals;
[] call GAIT_fnc_releaseFatigueVisuals;

if (_failures isEqualTo []) then {
    diag_log "GAIT fatigue visuals PASS: bounded smooth pulse; 5-12 s zero-effect gaps; low-fatigue scaling; capped opacity; missed-frame recovery; no residual baseline; stalled-caller expiry; zero-strength ACE policy lease; context and player replacement cleanup; idempotent destroy; safe allocation failure.";
} else {
    {diag_log ("GAIT fatigue visuals FAIL: " + _x);} forEach _failures;
    throw "GAIT fatigue visuals regression failed";
};
