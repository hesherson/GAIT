/* Load fn_releaseMomentum.sqf. These tests exercise the actual physical
   release plan; Arma remains responsible for animation/terrain simulation. */
private _failures = [];
private _slow = [10, 3, 1.5, 0.5, 0.30, 1.45] call GAIT_fnc_releaseMomentumPlan;
private _fast = [10, 9, 1.5, 0.5, 0.30, 1.45] call GAIT_fnc_releaseMomentumPlan;
if ((count _slow) != 7 || {(count _fast) != 7}) then {
    _failures pushBack "Valid measured release did not create a plan";
};
if !((_slow select 1) < (_fast select 1)) then {
    _failures pushBack "Identical coefficients ignored different measured velocities";
};
if ((_slow select 2) != 3 || {(_fast select 2) != 9}) then {
    _failures pushBack "Plan replaced the measured release velocity";
};
private _light = [10, 9, 1.5, 0.5, 0.765, 1.45] call GAIT_fnc_releaseMomentumPlan;
private _heavy = [10, 9, 1.5, 0.5, 0.978, 1.45] call GAIT_fnc_releaseMomentumPlan;
if !((_light select 1) < (_heavy select 1)) then {
    _failures pushBack "Gear coast duration ordering was lost";
};

{
    private _plan = _x;
    _plan params ["_start", "_duration", "_startMS", "_targetMS", "_startCoef", "_targetCoef"];
    private _first = [_plan, _start] call GAIT_fnc_releaseMomentumSample;
    if (abs ((_first select 0) - _startCoef) > 0.00001 ||
        {abs ((_first select 1) - _startMS) > 0.00001} || {!(_first select 3)}) then {
        _failures pushBack "Release did not begin exactly at its measured snapshot";
    };
    private _previous = _startCoef;
    for "_i" from 0 to 120 do {
        private _sample = [_plan, _start + ((_i / 120) * _duration)] call GAIT_fnc_releaseMomentumSample;
        private _coef = _sample select 0;
        if (_coef > _previous + 0.00001 || {_coef < _targetCoef - 0.00001}) then {
            _failures pushBack "Release curve accelerated or overshot its endpoint";
        };
        if (abs ((_sample select 1) - (_startMS * _coef / _startCoef)) > 0.00001) then {
            _failures pushBack "Rendered coefficient no longer represents same-clip planned metres per second";
        };
        _previous = _coef;
    };
    private _last = [_plan, _start + _duration + 0.001] call GAIT_fnc_releaseMomentumSample;
    if (abs ((_last select 0) - _targetCoef) > 0.00001 ||
        {abs ((_last select 1) - _targetMS) > 0.00001} || {_last select 3}) then {
        _failures pushBack "Coast did not finish at the ordinary endpoint";
    };
    private _late = [_plan, _start + 2] call GAIT_fnc_releaseMomentumSample;
    if !(_last isEqualTo _late) then {_failures pushBack "Delayed ticks extended or restarted the release";};
    private _future = [_plan, _start - 0.01] call GAIT_fnc_releaseMomentumSample;
    if (_future select 3) then {_failures pushBack "A future snapshot authorized coast";};
    // A common absolute timestamp must give the same curve at different
    // render frequencies. It never integrates the previous frame's result.
    private _timestamp = _start + (_duration * 0.5);
    private _direct = [_plan, _timestamp] call GAIT_fnc_releaseMomentumSample;
    {
        private _hz = _x;
        for "_frame" from 0 to floor (_duration * _hz * 0.5) do {
            [_plan, _start + (_frame / _hz)] call GAIT_fnc_releaseMomentumSample;
        };
        if !(([_plan, _timestamp] call GAIT_fnc_releaseMomentumSample) isEqualTo _direct) then {
            _failures pushBack format ["Release depended on render frequency %1", _hz];
        };
    } forEach [20, 30, 60, 144];
} forEach [_slow, _fast, _light, _heavy];

// Repeated Shift taps use the current sample, never the earlier full sprint.
private _partial = [_fast, 10 + ((_fast select 1) * 0.4)] call GAIT_fnc_releaseMomentumSample;
private _retap = [20, _partial select 1, _partial select 0, 0.5, 0.3, 1.45]
    call GAIT_fnc_releaseMomentumPlan;
private _retapStart = [_retap, 20] call GAIT_fnc_releaseMomentumSample;
if (abs ((_retapStart select 0) - (_partial select 0)) > 0.00001 ||
    {abs ((_retapStart select 1) - (_partial select 1)) > 0.00001}) then {
    _failures pushBack "New release resurrected the original full sprint";
};

{
    if !((_x call GAIT_fnc_releaseMomentumPlan) isEqualTo []) then {
        _failures pushBack format ["Invalid or non-excess release accepted: %1", _x];
    };
} forEach [
    [10, 0, 1.5, 0.5, 0.3, 1.45],
    [10, 4, 0, 0.5, 0.3, 1.45],
    [10, 4, 0.4, 0.5, 0.3, 1.45],
    [10, 4, 0.5, 0.5, 0.3, 1.45],
    [10, 0.06, 0.51, 0.5, 0.3, 1.45],
    [10, 4, 1.5, 0.5, 0, 1.45]
];
{
    if ((_x call GAIT_fnc_releaseMomentumSample) select 3) then {
        _failures pushBack format ["Malformed plan authorized release: %1", _x];
    };
} forEach [[[], 10], [[10, 0.3], 10], [[10, 0.3, "bad", 1, 1.5, 0.5, 1.45], 10]];
private _tiny = [10, 1, 0.51, 0.49, 0.3, 1.45] call GAIT_fnc_releaseMomentumPlan;
if ((_tiny select 1) < 0.12 || {(_tiny select 1) > 0.3}) then {
    _failures pushBack "Small release escaped the finite duration bounds";
};

if (_failures isEqualTo []) then {
    diag_log "GAIT release momentum PASS: exact measured launch velocity; slower tier-scaled jog decay; light/heavy order; partial retaps; finite endpoints; monotonic curve; render-rate independence; invalid/future/stale plans.";
} else {
    {diag_log ("FAIL " + _x);} forEach _failures;
};
