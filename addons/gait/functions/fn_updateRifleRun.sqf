/*
    Called only for the owning player's dead sprint, and once at its end.
    Leave other gestures alone, including ones introduced by unknown addons.
*/
params ["_unit", "_burst", ["_load",0], ["_reserve",1], ["_grade",0], ["_speed",0], ["_lateral",0], ["_allowCatch",false], ["_fatigueCatch",false]];
if (isNull _unit || {!local _unit}) exitWith {false};
private _gesture = toLower gestureState _unit;
private _owned = _gesture find "gait_riflerun_" == 0;
private _state = _unit getVariable ["GAIT_rifleRunState", []];
if (!_burst) exitWith {
    private _end = _unit getVariable ["GAIT_runCatchEnd",-1];
    private _fitInfo = _unit getVariable ["GAIT_rifleRunFit",[]];
    private _rifle = (_fitInfo param [2,""]) in ["compact","standard","roomy"];
    if (_allowCatch && {_owned} && {_rifle} && {currentWeapon _unit == _fitInfo select 0} &&
        {!([_unit getVariable ["NAVSPECWARGRU2_CQB_ReadyAnim",""]] call GAIT_fnc_preserveLocomotionGesture)}) then {
        if (_end < 0 && {_state isNotEqualTo []}) then {
            private _from = [_state select 1,(getUnitMovesInfo _unit) select 5] call GAIT_fnc_runCatchPose;
            private _landing = "";
            if (_fatigueCatch) then {
                private _quarter = (round (4*((getUnitMovesInfo _unit) select 0))) mod 4;
                _landing = format ["GAIT_RifleRun_%1_gather_%2_%3",_fitInfo select 2,_from,_quarter];
                _end = time + 0.76;
            } else {
                _landing = format ["GAIT_RifleRun_%1_catch_%2",_fitInfo select 2,_from];
                _end = time + 0.43;
            };
            _unit switchGesture [_landing,0,0,false];
            _unit setVariable ["GAIT_runCatchEnd",_end];
        };
    } else {_end = -1};
    if (_end >= 0 && {time < _end}) exitWith {true};
    if (_owned) then {_unit playActionNow "GAIT_EndSprintGesture"};
    _unit setVariable ["GAIT_runCatchEnd",nil];
    _unit setVariable ["GAIT_rifleRunState",nil];
    false
};
if ((_unit getVariable ["GAIT_runCatchEnd",-1]) >= 0) then {
    _unit setVariable ["GAIT_runCatchEnd",nil];
    _unit setVariable ["GAIT_rifleRunState",nil];
    _state = [];
};
// A foreign gesture, even a brief hand signal, gets the rest of this burst.
if (!_owned && {_state isNotEqualTo [] || {!([_gesture] call GAIT_fnc_rifleGestureFree)}} ||
    {[_unit getVariable ["NAVSPECWARGRU2_CQB_ReadyAnim",""]] call GAIT_fnc_preserveLocomotionGesture} ||
    {[_unit] call GAIT_fnc_readFireInput}) exitWith {
    if (_owned) then {_unit playActionNow "GAIT_EndSprintGesture"};
    false
};
private _body = toLower animationState _unit;
private _eligible = (_body select [0,8]) == "amovperc" && {(_body select [8,4]) in ["mspr","meva"]} &&
    {(_body select [12,8]) in ["sraswrfl","slowwrfl","sraswpst","slowwpst","sraswlnr","slowwlnr"]} &&
    {(_body select [20]) in ["df","dfl","dfr","df_gait","dfl_gait","dfr_gait","df_gaitsprint","dfl_gaitsprint","dfr_gaitsprint"]};
if (!_eligible) exitWith {
    if (_owned) then {_unit playActionNow "GAIT_EndSprintGesture"};
    // Let the brace reach the native sprint before first acquiring the slot.
    _state isEqualTo []
};
private _now = diag_tickTime;
if (_state isNotEqualTo [] && {_now < _state select 0}) exitWith {true};
private _weapon = currentWeapon _unit;
if (_weapon == "") exitWith {false};
private _vest = vest _unit;
private _equipment = _unit getVariable ["GAIT_rifleRunFit", []];
if (_equipment isEqualTo [] || {_weapon != _equipment select 0} || {_vest != _equipment select 1}) then {
    private _type = ([_weapon] call BIS_fnc_itemType) param [1,""];
    private _fit = "";
    if (_weapon == handgunWeapon _unit && {_type == "Handgun"}) then {_fit = "pistol"};
    if (_weapon == secondaryWeapon _unit && {getNumber (configFile >> "CfgWeapons" >> _weapon >> "type") == 4}) then {_fit = "launcher"};
    if (_weapon == primaryWeapon _unit && {_type in ["AssaultRifle","SniperRifle","Rifle"]}) then {
        private _weapons = configFile >> "CfgWeapons";
        private _length = getNumber (_weapons >> _weapon >> "ACE_barrelLength");
        private _bulk = getNumber (_weapons >> _vest >> "ItemInfo" >> "mass");
        _fit = "roomy";
        if (_length > 0 && {_length < 500} && {_bulk < 100} && {_type != "SniperRifle"}) then {
            _fit = ["standard","compact"] select (_length <= 365);
        };
    };
    _equipment = [_weapon,_vest,_fit];
    _unit setVariable ["GAIT_rifleRunFit",_equipment];
};
private _fit = _equipment select 2;
if (_fit == "") exitWith {false};
private _expected = switch (_fit) do {case "pistol": {"wpst"}; case "launcher": {"wlnr"}; default {"wrfl"}};
if ((_body select [16,4]) != _expected) exitWith {_state isEqualTo []};
private _direction = getDir _unit;
private _change = abs (((_direction - (_state param [3,_direction]) + 540) mod 360) - 180);
private _turn = _change >= 24 || {abs (_lateral - (_state param [4,_lateral])) >= 0.7};
private _age = time - ((_unit getVariable ["GAIT_burstBill",[]]) param [0,time]);
private _wanted = [_state param [7,""], _reserve, _load, _grade, _age, _speed, _turn] call GAIT_fnc_rifleMotion;
private _previous = _state param [1,""];
private _changesFatigue = _previous in ["fatigue_blend","fatigue_return"] || {(_previous == "tired") != (_wanted == "tired")};
private _posture = _wanted;
private _interval = 0.12;
private _previousOffset = [0,0.75] select (_previous in ["tired","fatigue_return"]);
private _pendingSince = -1;
private _isRifle = _fit in ["compact","standard","roomy"];
private _moves = getUnitMovesInfo _unit;
private _gesturePhase = _moves select 5;
private _continuing = _owned && {_state isNotEqualTo []};
private _armPhase = if (_continuing) then {
    (_gesturePhase * ([1,4] select (_previous == "lower")) + _previousOffset) mod 1
} else {_moves select 0};
private _transition = [_wanted,false];
if (_isRifle && {_previous in ["","upright","lower"]}) then {
    private _clock = [_armPhase,_gesturePhase] select (_previous == "lower");
    _transition = [_previous,_wanted,_reserve,_unit getVariable ["GAIT_burstHighStart",false],_clock]
        call GAIT_fnc_runUprightTransition;
} else {
    if (_owned && {_changesFatigue}) then {
        _transition = [_previous,_wanted,_armPhase,true] call GAIT_fnc_runFatigueTransition;
    };
};
_posture = _transition select 0;
if (_transition select 1) then {
    _interval = 0.025;
    _pendingSince = _state param [8,-1];
    if (_pendingSince < 0 || {_previous != _posture}) then {_pendingSince = time};
    if (time - _pendingSince > 2 && {_posture != "lower"}) then {
        _posture = ["lower",_wanted] select (_posture != "upright");
        _pendingSince = time;
    };
};
// Move duration comes from the active locomotion clip; on the local player
// its clock is multiplied by animSpeedCoef. Gesture durations run independently.
private _baseRate = switch (_fit) do {case "pistol": {1.66667}; case "launcher": {0.707401}; default {1.60971}};
private _ratio = getAnimSpeedCoef _unit / (((_moves select 2) max 0.01) * _baseRate);
private _band = [_ratio,_moves select 0,_armPhase,_state param [2,-1]] call GAIT_fnc_runCadenceBand;
// ACME publishes delivered breaths/min on the patient. ACE Advanced Fatigue
// reports normalized respiratory effort on the owning client.
private _medical = _unit getVariable ["ACME_resp_deliveredRR",-1];
if (_medical isEqualTo -1) then {_medical = _unit getVariable ["ACM_breathing_RespirationRate",-1]};
private _effort = if (missionNamespace getVariable ["ace_advanced_fatigue_enabled",false]) then {
    missionNamespace getVariable ["ace_advanced_fatigue_respiratoryRate",-1]
} else {-1};
private _rr = [_medical,_effort,_reserve] call GAIT_fnc_runBreathRate;
private _phase = ((_state param [5,0]) + ((time - (_state param [6,time])) max 0)*_rr/60) mod 1;
private _inhale = _rr > 0 && {_phase < 0.43};
if (_owned && {_fit != "launcher"}) then {
    private _wasInhaling = (_gesture find "_inhale_") >= 0;
    if (_changesFatigue || {_posture == "lower"} || {_previous == "lower"}) then {
        // Keep the same breath shape throughout the lowering or catch.
        _inhale = _wasInhaling;
    } else {
        if (_inhale != _wasInhaling && {_posture == _previous}) then {
            // Arma can display the first key for one frame when switching.
            // Acquire its next breath near that contact, retaining arm phase.
            private _armClock = (getUnitMovesInfo _unit) select 5;
            if (_armClock > 0.065 && {_armClock < 0.935}) then {
                _inhale = _wasInhaling;
                _interval = 0.035;
            };
        };
    };
};
private _motion = [_posture,_posture + "_inhale"] select _inhale;
private _level = if (_fit == "launcher" || {_posture == "upright"}) then {0} else {[_reserve] call GAIT_fnc_runHandLevel};
private _lastLevel = _state param [9,_level];
private _changedAt = _state param [10,time];
if (_owned && {_level != _lastLevel}) then {
    private _clock = (getUnitMovesInfo _unit) select 5;
    if (time-_changedAt < 0.16 || {_posture == "lower"} ||
        {_clock > 0.09 && {_clock < 0.91} && {time-_changedAt < 0.6}}) then {
        _level = _lastLevel;
        _interval = _interval min 0.05;
    } else {
        _level = _lastLevel + ([-1,1] select (_level > _lastLevel));
        _changedAt = time;
    };
};
if (_level > 0) then {_motion = format ["%1_h%2",_motion,_level]};
private _target = format ["gait_riflerun_%1_%2_%3",_fit,_motion,["slow","tired","run","climb","cruise","fast","dash","descent","gravity"] select _band];
private _offset = [0,0.75] select (_posture in ["tired","fatigue_return"]);
// Preserve the displayed arm pose across class changes, including across the
// four-stride lowering clip. An uninterrupted loop never needs a phase seek.
private _seek = (_armPhase - _offset + 1) mod 1;
if (_posture == "lower") then {
    _seek = [_armPhase/4,_gesturePhase] select (_continuing && {_previous == "lower"});
};
if (_target != _gesture) then {
    private _weight = if (_owned) then {_moves select 8} else {0};
    _unit switchGesture [_target,_seek,_weight,false];
};
_unit setVariable ["GAIT_rifleRunState", [_now + _interval,_posture,_band,_direction,_lateral,_phase,time,_wanted,_pendingSince,_level,_changedAt]];
true
