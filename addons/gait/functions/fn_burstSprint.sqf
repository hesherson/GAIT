// Time is mission simulation time. A paid launch follows its unit through
// a release or dialog, including the interval between two ACE samples.
GAIT_fnc_burstTapPair = {
    params ["_previous", "_now"];
    _previous >= 0 && {_now > _previous} && {_now - _previous <= 0.32}
};

GAIT_fnc_burstStrength = {
    params ["_reserve"];
    private _bar = (_reserve / 0.20) max 0 min 1;
    _bar * _bar * (3 - 2 * _bar)
};

GAIT_fnc_burstInterval = {
    params ["_start", "_stop", "_from", "_to", "_lbs", "_strength", ["_grade", 0]];
    private _boundary = _start + 1;
    private _launchTime = ((_to min _boundary) - (_from max _start)) max 0;
    private _end = [_stop, _to] select (_stop < 0);
    private _runningTime = ((_to min _end) - (_from max _boundary)) max 0;
    private _rate = 0.05 + 0.03 * ((_lbs / 150) max 0 min 1);
    // Keep the launch commitment fixed. Sustained effort uses GAIT's signed
    // travel grade, including the braking cost on very steep descents.
    private _effort = [_grade] call GAIT_fnc_sprintReserveGradeMultiplier;
    // Even while braking on a very steep descent, gravity carries part of
    // the load. Blend the minimum relief in continuously from level ground.
    if (_grade < 0) then {_effort = _effort min (1 - 0.05 * ((-_grade / 13) min 1));};
    _rate = (_rate * _effort) min 0.10;
    private _burstTime = _runningTime * _strength;
    private _interval = _to - _from;
    private _normalShare = 0;
    if (_interval > 0) then {
        _normalShare = (1 - (_launchTime + _burstTime) / _interval) max 0 min 1;
    };
    [0.20 * _launchTime + _rate * _burstTime, _normalShare]
};

GAIT_fnc_accrueBurstCost = {
    params ["_unit", "_now", "_lbs", "_reserve", ["_grade", 0]];
    private _normalShare = 1;
    isNil {
        private _bill = _unit getVariable ["GAIT_burstBill", []];
        if (_bill isNotEqualTo []) then {
            _bill params ["_start", "_stop", "_through"];
            private _due = _unit getVariable ["GAIT_burstDue", 0];
            private _strength = [_reserve - _due] call GAIT_fnc_burstStrength;
            private _charge = [_start, _stop, _through, _now, _lbs, _strength, _grade] call GAIT_fnc_burstInterval;
            _normalShare = _charge select 1;
            _unit setVariable ["GAIT_burstDue", _due + (_charge select 0)];
            _bill set [2, _now];
            if (_stop >= 0 && {_now >= _start + 1}) then {_bill = [];};
            _unit setVariable ["GAIT_burstBill", _bill];
        };
    };
    _normalShare
};

GAIT_fnc_takeBurstCost = {
    params ["_unit"];
    private _due = 0;
    isNil {
        _due = _unit getVariable ["GAIT_burstDue", 0];
        if (_due > 0) then {_unit setVariable ["GAIT_burstDue", 0];};
    };
    _due
};

// Let the owning addon release claims, restore mass and remove its locks.
GAIT_fnc_dropBurstCarry = {
    params ["_unit"];
    private _target = _unit getVariable ["ace_dragging_carriedObject", objNull];
    if (_unit getVariable ["ace_dragging_isCarrying", false] && {!isNull _target} &&
        {!isNil "ace_dragging_fnc_dropObject_carry"}) exitWith {
        private _pickup = _unit getVariable ["MAV_fastCarry_pickupActive", false];
        [_unit, _target, false] call ace_dragging_fnc_dropObject_carry;
        if (_pickup && {!(_unit getVariable ["ace_dragging_isCarrying", false])}) then {
            // The mission's pending lift observes ACE's released state and aborts.
            _unit setVariable ["MAV_fastCarry_pickupActive", false];
        };
        true
    };
    _target = _unit getVariable ["ace_dragging_draggedObject", objNull];
    if (_unit getVariable ["ace_dragging_isDragging", false] && {!isNull _target} &&
        {!isNil "ace_dragging_fnc_dropObject"}) exitWith {
        [_unit, _target] call ace_dragging_fnc_dropObject;
        true
    };
    false
};

GAIT_fnc_cancelBurstAction = {
    params ["_unit"];
    private _handoff = [_unit] call GAIT_fnc_dropBurstCarry;
    if (_unit getVariable ["ace_cargo_isDeploying", false] && {!isNil "ace_cargo_fnc_deployCancel"}) then {
        [_unit] call ace_cargo_fnc_deployCancel;
        _handoff = true;
    };
    if (missionNamespace getVariable ["ace_explosives_pfeh_running", false] &&
        {!isNil "ace_explosives_fnc_cancelPlacement"}) then {
        [_unit, 1] call ace_explosives_fnc_cancelPlacement;
        _handoff = true;
    };
    private _display = uiNamespace getVariable ["ace_common_dlgProgress", displayNull];
    if (!isNull _display && {!isNull (uiNamespace getVariable ["ace_common_ctrlProgressBar", controlNull])}) then {
        if (dialog) then {
            if ((allDisplays select -1) isEqualTo _display) then {
                _display closeDisplay 2;
                _handoff = true;
            };
        } else {
            "ace_common_progressBarDisplay" cutText ["", "PLAIN"];
            ["ace_common_progressBarKeyHandler", "keydown"] call CBA_fnc_removeKeyHandler;
            _handoff = true;
        };
    };
    _handoff
};

// A modal ACE bar or a pickup can suppress Arma's logical Turbo action.
// Listen without consuming either key. Only the owning UI/action is canceled.
// Actual movement still requires live gameplay input after the handoff.
GAIT_fnc_watchBurstKeys = {
    private _game = findDisplay 46;
    private _bar = uiNamespace getVariable ["ace_common_dlgProgress", displayNull];
    {
        if (!isNull _x && {!(_x getVariable ["GAIT_burstKeysInstalled", false])}) then {
            _x setVariable ["GAIT_burstKeysInstalled", true];
            _x displayAddEventHandler ["KeyUp", {
                params ["_display", "_dik"];
                {
                    if (!isNull _x) then {
                        _x setVariable ["GAIT_burstKeysHeld", (_x getVariable ["GAIT_burstKeysHeld", []]) - [_dik]];
                    };
                } forEach [_display, findDisplay 46];
                private _resume = player getVariable ["GAIT_burstResumeKeys", []];
                if (_resume isNotEqualTo [] && {_dik isEqualTo (_resume select 1) || {_dik in actionKeys "MoveForward"}}) then {
                    player setVariable ["GAIT_burstResumeKeys", []];
                };
                false
            }];
            _x displayAddEventHandler ["KeyDown", {
                params ["_display", "_dik"];
                private _forward = actionKeys "MoveForward";
                private _turbo = actionKeys "Turbo";
                if !(_dik in (_forward + _turbo)) exitWith {false};
                private _held = _display getVariable ["GAIT_burstKeysHeld", []];
                if (_dik in _held) exitWith {false};
                _held pushBack _dik;
                _display setVariable ["GAIT_burstKeysHeld", _held];
                if !(_dik in _turbo) exitWith {false};
                private _first = _display getVariable ["GAIT_burstKeyAt", -1];
                private _paired = [_first, diag_tickTime] call GAIT_fnc_burstTapPair;
                _display setVariable ["GAIT_burstKeyAt", [diag_tickTime, -1] select _paired];
                if (!_paired) exitWith {false};
                private _gameHeld = (findDisplay 46) getVariable ["GAIT_burstKeysHeld", []];
                if (((_held + _gameHeld) arrayIntersect _forward) isEqualTo [] && {inputAction "MoveForward" <= 0.05}) exitWith {false};
                if (dialog && {_display isNotEqualTo (uiNamespace getVariable ["ace_common_dlgProgress", displayNull])}) exitWith {false};
                if (!(call GAIT_fnc_modeAllowsMovement) || {call GAIT_fnc_isSuspendedContext} ||
                    {!isNull objectParent player} || {!isNull attachedTo player} || {!isTouchingGround player} ||
                    {lifeState player isEqualTo "INCAPACITATED"} || {player getVariable ["GAIT_isTripping", false]} ||
                    {(player getVariable ["GAIT_burstBill", []]) isNotEqualTo []}) exitWith {false};
                private _budget = missionNamespace getVariable ["GAIT_observedReserveRatio", 0];
                if (_budget - (player getVariable ["GAIT_burstDue", 0]) < 0.20) exitWith {false};
                private _handoff = [player] call GAIT_fnc_cancelBurstAction;
                player setVariable ["GAIT_burstResumeKeys", [diag_tickTime + ([0.32,1.25] select _handoff), _dik, _handoff]];
                false
            }];
        };
    } forEach [_game, _bar];
};

GAIT_fnc_prepareBurst = {
    params ["_unit", "_reserve"];
    private _request = _unit getVariable ["GAIT_burstRequest", []];
    if (count _request != 2 || {time > (_request select 1)} ||
        {(_unit getVariable ["GAIT_burstBill", []]) isNotEqualTo []} ||
        {_reserve - (_unit getVariable ["GAIT_burstDue", 0]) < 0.20}) exitWith {};
    private _input = call GAIT_fnc_getMovementInput;
    if (!(_input select 2) || {(_input select 0) <= 0.05} ||
        {!isNull objectParent _unit} || {!isNull attachedTo _unit} || {!isTouchingGround _unit} ||
        {lifeState _unit isEqualTo "INCAPACITATED"} || {_unit getVariable ["GAIT_isTripping", false]}) exitWith {};
    // Mark this press before calling any synchronous third-party callbacks.
    _request pushBack true;
    _unit setVariable ["GAIT_burstRequest", _request];
    private _handoff = [_unit] call GAIT_fnc_cancelBurstAction;
    // Cancel GAIT's own queued stance/exit immediately on an ordinary moving
    // body. Never turn a remote claim or an injury into a generic unlock.
    if (_unit getVariable ["GAIT_slopeExitPending", false] ||
        {_unit getVariable ["GAIT_sprintReleaseJog", false]} ||
        {(_unit getVariable ["GAIT_stanceTravel", []]) isNotEqualTo []}) then {
        _request pushBack true;
        _handoff = true;
    };
    // ACE can restore the weapon asynchronously after dropping a patient.
    // The release edge expires the request immediately even during this grace.
    if (_handoff && {((_unit getVariable ["GAIT_burstRequest", []]) param [0,-1]) isEqualTo (_request select 0)}) then {
        _request set [1, time + 1.25];
        _unit setVariable ["GAIT_burstRequest", _request];
    };
};

GAIT_fnc_endBurst = {
    params ["_unit"];
    if (isNull _unit) exitWith {};
    private _bill = _unit getVariable ["GAIT_burstBill", []];
    if (_bill isEqualTo [] || {(_bill select 1) >= 0}) exitWith {};
    _bill set [1, time];
    _unit setVariable ["GAIT_burstBill", _bill];
};

GAIT_fnc_updateBurst = {
    params ["_unit", "_eligible", "_reserve", "_press", "_weapon"];
    private _bill = _unit getVariable ["GAIT_burstBill", []];
    private _request = _unit getVariable ["GAIT_burstRequest", []];
    private _spendable = _reserve - (_unit getVariable ["GAIT_burstDue", 0]);
    if (_request isNotEqualTo [] && {_eligible || {time > (_request select 1)}}) then {
        _unit setVariable ["GAIT_burstRequest", []];
        if (_eligible && {_bill isEqualTo []} && {_spendable >= 0.20} &&
            {_press isEqualTo (_request select 0)} && {time <= (_request select 1)}) then {
            _bill = [time, -1, time];
            _unit setVariable ["GAIT_burstBill", _bill];
            _unit setVariable ["GAIT_burstWeapon", _weapon];
            _unit setVariable ["GAIT_burstHighStart",_spendable >= 0.95];
        };
    };
    if (_bill isEqualTo [] || {(_bill select 1) >= 0}) exitWith {false};
    if (!_eligible || {_spendable <= 0} ||
        {_weapon isNotEqualTo (_unit getVariable ["GAIT_burstWeapon", ""])}) exitWith {
        [_unit] call GAIT_fnc_endBurst;
        false
    };
    true
};

// The base target is horizontal speed in km/h. A sustained descent can
// contribute downhill momentum, with a short allowance above the ordinary limit.
GAIT_fnc_burstGravity = {
    params ["_grade", "_momentum"];
    private _descent = ((-_grade - 8) / 24) max 0 min 1;
    _descent * (_momentum max 0 min 1) ^ 2
};

GAIT_fnc_burstTargetKmh = {
    params ["_flatPeakKmh", "_age", "_gravity", "_ordinaryKmh"];
    // Briefly exceed the runner's own fresh single-tap peak. Build the
    // premium over several steps, hold it, then settle while Shift is held.
    private _rise = (_age / 1.4) max 0 min 1;
    private _settle = ((_age - 2.8) / 1.4) max 0 min 1;
    private _bonus = _rise^2 * (3 - 2*_rise) * (0.09 - 0.055*_settle^2*(3 - 2*_settle));
    private _level = _flatPeakKmh * (1 + _bonus);
    (_level + 7 * _gravity) max (_ordinaryKmh * (1 + 0.027 * _gravity))
};

GAIT_fnc_burstPace = {
    params ["_ordinary", "_strength", "_stride", "_earnedKmh", "_allowance"];
    private _kmh = _earnedKmh min (30 + 0.8 * (_allowance max 0 min 1));
    private _full = _kmh / (3.6 * _stride);
    _ordinary + (_full - _ordinary) * (_strength max 0 min 1)
};

GAIT_fnc_rifleMotion = {
    params ["_previous","_reserve","_load","_grade","_age","_speed","_turn"];
    private _effort = 0.76 * (1 - (_reserve max 0 min 1)) + 0.24 * ((_load / 150) max 0 min 1);
    if (_effort >= ([0.65,0.57] select (_previous == "tired"))) exitWith {"tired"};
    if (_age < 0.6 && {_speed < 6.8}) exitWith {"drive"};
    if (_turn) exitWith {"turn"};
    if (_grade < ([-9,-6] select (_previous == "descent"))) exitWith {"descent"};
    "travel"
};

// Optical animation only. Never write to the medical simulation.
GAIT_fnc_runBreathRate = {
    params ["_medical","_effort","_reserve"];
    if (_medical isEqualType 0 && {_medical >= 0}) exitWith {_medical min 75};
    if (_effort isEqualType 0 && {_effort >= 0}) exitWith {16 + 34*(_effort min 1)};
    20 + 24*(1 - (_reserve max 0 min 1))
};

// Same-phase plateaus of the baked travel-to-fatigued loop. The release,
// weapon and external-gesture checks in the controller always take priority.
GAIT_fnc_runFatigueTransition = {
    params ["_previous","_wanted","_armPhase","_owned"];
    if (!_owned || {_previous == ""}) exitWith {[_wanted,false]};
    private _low = _armPhase <= 0.055 || {_armPhase >= 0.945};
    private _high = abs (_armPhase - 0.75) <= 0.055;
    if (_previous in ["fatigue_blend","fatigue_return"]) exitWith {
        if (_wanted == "tired" && {_high} || {_wanted != "tired" && {_low}}) then {
            [_wanted,false]
        } else {[_previous,true]}
    };
    if (_wanted == "tired" && {_previous != "tired"}) exitWith {
        [[_previous,"fatigue_blend"] select _low,true]
    };
    if (_previous == "tired" && {_wanted != "tired"}) exitWith {
        [["tired","fatigue_return"] select _high,true]
    };
    [_wanted,false]
};

// Tiered native-fist to relaxed-hand bakes share their source stride phase.
GAIT_fnc_runHandLevel = {
    params ["_reserve"];
    private _t = ((0.95 - _reserve)/0.9) max 0 min 1;
    round (6*_t*_t*(3-2*_t))
};
GAIT_fnc_runUprightTransition = {
    params ["_previous","_wanted","_reserve","_freshStart","_clock"];
    if (_previous == "" && {_freshStart} && {_reserve >= 0.76}) exitWith {["upright",false]};
    if (_previous == "upright") exitWith {
        if (_reserve >= 0.76) then {["upright",false]} else {
            [["upright","lower"] select (_clock < 0.15),true]
        }
    };
    if (_previous == "lower") exitWith {
        if (_clock < 0.89) then {["lower",true]} else {["travel",false]}
    };
    [_wanted,false]
};

// Choose the closest launch pose if sprint is released partway through
// lowering the rifle. Neither hand should have to return to the upright pose.
GAIT_fnc_runCatchPose = {
    params ["_pose","_phase"];
    if (_pose == "upright") exitWith {"upright"};
    if (_pose == "lower") exitWith {
        if (_phase < 0.32) exitWith {"upright"};
        if (_phase > 0.64) exitWith {"travel"};
        "lower"
    };
    if (_pose == "fatigue_return") then {_phase = (_phase + 0.75) mod 1};
    if (_pose == "tired" || {_pose in ["fatigue_blend","fatigue_return"] &&
        {_phase > 0.44 && {_phase < 0.9}}}) exitWith {"tired"};
    "travel"
};

// Both clocks wrap at foot contact. Adjust the rate around the native stride
// rate so a small lead or lag is paid back over the next strides.
GAIT_fnc_runCadenceBand = {
    params ["_ratio","_legs","_arms","_lastBand"];
    private _rates = [0.62,0.84,1.00,1.06,1.15,1.27,1.41,1.56,1.72];
    private _lag = ((_legs - _arms + 1.5) mod 1) - 0.5;
    private _wanted = _ratio + ((1.8 * _lag) max -0.14 min 0.14);
    private _band = _rates findIf {_x >= _wanted};
    if (_band < 0) then {_band = count _rates - 1};
    if (_band > 0 && {_wanted - (_rates select (_band-1)) < (_rates select _band) - _wanted}) then {_band = _band - 1};
    if (_lastBand >= 0 && {abs (_wanted - (_rates select _lastBand)) < abs (_wanted - (_rates select _band)) + 0.012}) exitWith {_lastBand};
    _band
};
