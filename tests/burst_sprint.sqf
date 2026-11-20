private _check = {params ["_arg", "_message"]; if (!_arg) then {throw ("FAIL " + _message);};};
private _near = {params ["_actual", "_want", "_label"]; [abs (_actual - _want) < 0.0001, _label] call _check;};
GAIT_fnc_modeAllowsMovement = {true};
GAIT_fnc_aceAdvancedFatigueActive = {true};
GAIT_fnc_fatigueMovementContextEligible = {true};

// A cadence mismatch must converge without ever moving the arm clock directly.
{
    private _step = _x;
    private _arm = 0.98;
    private _leg = 0.01;
    private _band = -1;
    private _rates = [0.62,0.84,1.00,1.06,1.15,1.27,1.41,1.56,1.72];
    for "_i" from 1 to 240 do {
        private _pace = [1.035,1.49] select (_i > 100);
        _band = [_pace,_leg,_arm,_band] call GAIT_fnc_runCadenceBand;
        _arm = (_arm + (_rates select _band)*1.61*_step) mod 1;
        _leg = (_leg + _pace*1.61*_step) mod 1;
        [abs (((_leg-_arm+1.5) mod 1)-0.5) < 0.04,"arm phase tracks a changing stride across wrap"] call _check;
    };
} forEach [0.025,0.12];

[!([-1, 0] call GAIT_fnc_burstTapPair), "first press"] call _check;
[[2, 2.30] call GAIT_fnc_burstTapPair, "paired edges"] call _check;
[!([2, 2.35] call GAIT_fnc_burstTapPair), "slow retap"] call _check;
{
    _x params ["_lbs", "_rate"];
    {
        private _step = _x;
        private _cost = 0;
        for "_i" from 1 to (round (5 / _step)) do {
            _cost = _cost + (([0,-1,(_i - 1) * _step,_i * _step,_lbs,1] call GAIT_fnc_burstInterval) select 0);
        };
        [_cost, 0.20 + 4 * _rate, "five-second burst cost"] call _near;
    } forEach [0.05,0.25,1];
    [([0,0.12,0,4,_lbs,1] call GAIT_fnc_burstInterval) select 0,0.20,"early stop charges full segment"] call _near;
} forEach [[0,0.05],[60,0.062],[150,0.08],[300,0.08]];

{
    _x params ["_reserve", "_want"];
    private _strength = [_reserve] call GAIT_fnc_burstStrength;
    [_strength, _want, "reserve sets sustained strength"] call _near;
    private _interval = [0,-1,2,3,60,_strength] call GAIT_fnc_burstInterval;
    [_interval select 0, 0.062 * _want, "weight-scaled burst share"] call _near;
    [_interval select 1, 1 - _want, "ordinary sprint receives the rest"] call _near;
} forEach [[1,1],[0.60,1],[0.20,1],[0.10,0.5],[0.01,0.00725],[0,0]];
[[0.20] call GAIT_fnc_burstStrength,1,"short paid launch at minimum reserve"] call _near;
private _crossing = [0,-1,0.90,1.10,0,0.5] call GAIT_fnc_burstInterval;
[_crossing select 0,0.0225,"sample spanning launch and taper"] call _near;
[_crossing select 1,0.25,"ordinary share at boundary"] call _near;
player setVariable ["ace_movement_totalLoad",600];
{
    private _weight = _x;
    [] call GAIT_fnc_clearAceSprintEffort;
    [player,"sprint",0.25,12,0,0,_weight] call GAIT_fnc_accumulateAceSprintEffort;
    private _pending = missionNamespace getVariable "GAIT_pendingAceSprintEffort";
    private _rate = [60, [12] call GAIT_fnc_sprintReserveGradeMultiplier] call GAIT_fnc_sprintReserveDrainRate;
    [_pending select 1, 0.25 * _weight * _rate, "ACE weights actual uphill effort"] call _near;
    [_pending select 3, 0.25, "ACE counts elapsed time once"] call _near;
    private _fallback = [9,"sprint",0.25 * _weight,60,60,_rate] call GAIT_fnc_stepFallbackSprintReserve;
    [_fallback, [9,60,(_pending select 1)/60] call GAIT_fnc_spendSprintReserve, "fallback uses same uphill effort"] call _near;
} forEach [0,0.5,1];
[] call GAIT_fnc_clearAceSprintEffort;

private _forward = [1,0,false];
{
    [player,[1,0,_x],5] call GAIT_fnc_observeLocomotionInput;
} forEach [true,true,false];
[player getVariable ["GAIT_burstRequest", []] isEqualTo [], "hold did not queue a burst"] call _check;
[player,[1,0,true],5.15] call GAIT_fnc_observeLocomotionInput;
private _press = player getVariable ["GAIT_turboPressSerial",0];
private _req = player getVariable ["GAIT_burstRequest",[]];
[_req isNotEqualTo [], "second actual edge queued"] call _check;
[!([player,true,0.19,_press,"rifle"] call GAIT_fnc_updateBurst), "insufficient reserve"] call _check;
player setVariable ["GAIT_burstRequest",_req];
[[player,true,0.20,_press,"rifle"] call GAIT_fnc_updateBurst, "one segment starts burst"] call _check;
[player,_forward] call GAIT_fnc_observeLocomotionInput;
[player,time + 1.1,100,1] call GAIT_fnc_accrueBurstCost;
[[2300,2300,player] call GAIT_fnc_filterAceSprintReserve,1840,"one full ACE segment"] call _near;
[[1840,1840,player] call GAIT_fnc_filterAceSprintReserve,1840,"no double charge"] call _near;
player setVariable ["GAIT_burstBill",[0,0.1,0]];
[player,1,0,1] call GAIT_fnc_accrueBurstCost;
[60 - 60 * ([player] call GAIT_fnc_takeBurstCost),48,"one full fallback segment"] call _near;
player setVariable ["GAIT_burstBill",[time,-1,time]];
player setVariable ["GAIT_burstWeapon","rifle"];
[!([player,false,0.70,_press,"pistol"] call GAIT_fnc_updateBurst), "weapon or context interrupts"] call _check;
player setVariable ["GAIT_burstBill",[time,-1,time]];
player setVariable ["GAIT_burstDue",0.07];
[!([player,true,0.06,_press,"rifle"] call GAIT_fnc_updateBurst), "unpublished ACE cost exhausts burst"] call _check;
player setVariable ["GAIT_burstDue",0];
player setVariable ["GAIT_burstBill",[time-2,-1,time]];
[[player,true,0.001,_press,"rifle"] call GAIT_fnc_updateBurst, "last tick still active"] call _check;
[!([player,true,0,_press,"rifle"] call GAIT_fnc_updateBurst), "handoff on empty"] call _check;
[player,time+0.1,60,0.15] call GAIT_fnc_accrueBurstCost;
[!([player,true,0.70,_press,"rifle"] call GAIT_fnc_updateBurst), "held key cannot start a second burst after handoff"] call _check;
player setVariable ["GAIT_burstResumeKeys",[6.32,42,false]];
[player,[1,0,true],6.10] call GAIT_fnc_observeLocomotionInput;
[_press + 1 isEqualTo ((player getVariable "GAIT_burstRequest") select 0), "raw tap pair survives a missed render edge"] call _check;
[(player getVariable "GAIT_burstResumeKeys") isEqualTo [], "raw pair consumed once"] call _check;
{
    _x params ["_grade","_rate"];
    [([0,-1,1,2,150,1,_grade] call GAIT_fnc_burstInterval) select 0,_rate,"terrain cost and cap"] call _near;
    [([0,0.1,0,1,150,1,_grade] call GAIT_fnc_burstInterval) select 0,0.20,"launch cost fixed"] call _near;
} forEach [[-45,0.076],[-13,0.064],[0,0.08],[35,0.10]];
{
    private _ordinary = _x;
    [[_ordinary,1,5,25.2,0] call GAIT_fnc_burstPace,1.4,"same full target across ordinary terrain rates"] call _near;
    [[_ordinary,0,5,25.2,0] call GAIT_fnc_burstPace,_ordinary,"depletion is ordinary pace"] call _near;
} forEach [0.65,1,1.15];
[[12,1] call GAIT_fnc_burstGravity,0,"climbing cannot bank overspeed"] call _near;
[[-32,0] call GAIT_fnc_burstGravity,0,"fresh downhill tap earns no speed"] call _near;
[[20,0,0,19] call GAIT_fnc_burstTargetKmh,20,"no instant launch premium"] call _near;
[[20,0.7,0,19] call GAIT_fnc_burstTargetKmh,20.9,"gradual acceleration"] call _near;
[[20,2,0,19] call GAIT_fnc_burstTargetKmh,21.8,"short peak relative to normal sprint"] call _near;
[[20,5,0,19] call GAIT_fnc_burstTargetKmh,20.7,"settles under held sprint"] call _near;
[[16,2,0,15] call GAIT_fnc_burstTargetKmh,17.44,"scales with the equipped stride"] call _near;
[[-32,1] call GAIT_fnc_burstGravity,1,"sustained descent"] call _near;
[[1,1,5,32,1] call GAIT_fnc_burstPace,30.8/18,"brief downhill headroom"] call _near;
[[1,1,5,32,0] call GAIT_fnc_burstPace,30/18,"overspeed expires"] call _near;
private _ramp = [1.35,true] call GAIT_fnc_jogDecelerationRamp;
private _target = "B_Soldier_F" createVehicle [0,0,0];
ace_dragging_fnc_dropObject_carry = {
    params ["_carrier","_object","_loadIntoVehicle"];
    _carrier setVariable ["testDropped",[_object,_loadIntoVehicle]];
    _carrier setVariable ["ace_dragging_isCarrying",false];
};
player setVariable ["ace_dragging_isCarrying",true];
player setVariable ["ace_dragging_carriedObject",_target];
player setVariable ["MAV_fastCarry_pickupActive",true];
[[player] call GAIT_fnc_dropBurstCarry, "carry drop submitted"] call _check;
[(player getVariable "testDropped") isEqualTo [_target,false] && {!(player getVariable "MAV_fastCarry_pickupActive")}, "drop actual patient and cancel pickup"] call _check;
ace_dragging_fnc_dropObject = {(_this select 0) setVariable ["testDragDrop",_this select 1];};
player setVariable ["ace_dragging_isDragging",true];
player setVariable ["ace_dragging_draggedObject",_target];
[[player] call GAIT_fnc_dropBurstCarry && {(player getVariable "testDragDrop") isEqualTo _target}, "drag drop routes through ACE"] call _check;
private _pace = 0;
for "_i" from 1 to 5 do {_pace = [_pace,1,_ramp,0.05] call GAIT_fnc_stepSpeedCoefficient;};
[_pace > 0.30 && {_pace < 0.55}, "first steps remain below full pace"] call _check;
for "_i" from 6 to 28 do {_pace = [_pace,1,_ramp,0.05] call GAIT_fnc_stepSpeedCoefficient;};
[_pace > 0.95 && {_pace < 1}, "reaches full stride progressively"] call _check;
diag_log "GAIT TEST PASS: paired input, committed segment, bounded tariffs, speed and release";
{
    _x params ["_input","_expected"];
    [(_input call GAIT_fnc_rifleMotion) == _expected, "rifle motion " + str _input] call _check;
} forEach [
    [["",1,10,0,0.18,2,false],"drive"],
    [["drive",1,10,0,1,7,false],"travel"],
    [["travel",1,10,-12,3,6,false],"descent"],
    [["descent",1,10,-7,3,6,false],"descent"],
    [["travel",1,10,-7,3,6,true],"turn"],
    [["travel",0.4,140,0,3,6,false],"tired"],
    [["travel",0.4,10,0,3,6,false],"travel"],
    [["travel",0.1,10,0,3,6,false],"tired"]
];
{[!([_x] call GAIT_fnc_rifleGestureFree),"foreign gesture owns slot " + _x] call _check}
    forEach ["acre_radio","tsp_animate_ready","some_future_addon","aidlperc_custom"];

[["amovpercmstpsnonwnondnon"] call GAIT_fnc_rifleGestureFree,"FTX default empty gesture"] call _check;

{
    _x params ["_inputs","_rate"];
    [_inputs call GAIT_fnc_runBreathRate,_rate,"dead-sprint breathing cadence"] call _near;
} forEach [[[0,1,0],0],[[24,1,0],24],[[90,1,0],75],[[-1,0.5,1],33],[[-1,-1,0.5],32]];

{[[_x] call GAIT_fnc_rifleGestureFree,"native equipped idle " + _x] call _check}
    forEach ["aidlpercmstpsraswpstdnon_g02_player","amovpercmstpsraswlnrdnon"];
[!(["amovpercmstpsraswpstdnon_amovpercmstpsraswlnrdnon_end"] call GAIT_fnc_rifleGestureFree),"weapon draw owns the hands"] call _check;

{
    _x params ["_args","_expected"];
    [(_args call GAIT_fnc_runFatigueTransition) isEqualTo _expected,"continuous fatigue handoff"] call _check;
} forEach [
    [["travel","tired",0.5,true],["travel",true]],
    [["travel","tired",0.02,true],["fatigue_blend",true]],
    [["fatigue_blend","tired",0.7,true],["tired",false]],
    [["tired","travel",0.75,true],["fatigue_return",true]],
    [["fatigue_return","travel",0.98,true],["travel",false]],
    [["travel","tired",0.5,false],["tired",false]]
];

{
    _x params ["_reserve","_level"];
    [([_reserve] call GAIT_fnc_runHandLevel) == _level,"reserve selects the free-hand pose"] call _check;
} forEach [[1,0],[0.95,0],[0.66,1],[0.50,3],[0.34,5],[0.05,6],[0,6]];
{
    _x params ["_args","_expected"];
    [(_args call GAIT_fnc_runUprightTransition) isEqualTo _expected,"upright carry handoff"] call _check;
} forEach [
    [["","travel",0.97,true,0],["upright",false]],
    [["","travel",0.85,false,0],["travel",false]],
    [["upright","drive",0.80,true,0.4],["upright",false]],
    [["upright","travel",0.70,true,0.4],["upright",true]],
    [["upright","travel",0.70,true,0.98],["upright",true]],
    [["upright","travel",0.70,true,0.02],["lower",true]],
    [["lower","travel",0.65,true,0.4],["lower",true]],
    [["lower","travel",0.65,true,0.72],["lower",true]],
    [["lower","tired",0.08,true,0.90],["travel",false]],
    [["lower","travel",0.65,true,1.0],["travel",false]],
    [["travel","travel",1,true,0.4],["travel",false]]
];

{
    _x params ["_pose","_phase","_expected"];
    [([_pose,_phase] call GAIT_fnc_runCatchPose) == _expected,"catch starts from the current carry"] call _check;
} forEach [["upright",0.5,"upright"],["lower",0.1,"upright"],["lower",0.435,"lower"],
    ["lower",0.72,"travel"],["lower",0.99,"travel"],["travel",0.9,"travel"],["fatigue_return",0,"tired"],["tired",0,"tired"]];

