/* Run after fn_slopeLocomotion.sqf. These selections guard the RC2 regression:
   a held sprint must enter a Meva clip, including either forward diagonal. */
private _failures = [];
{
    private _family = _x;
    {
        _x params ["_direction", "_expectedPace"];
        private _state = [_family, _direction] call GAIT_fnc_slopeStateName;
        if ((_state select [8, 4]) isNotEqualTo _expectedPace) then {
            _failures pushBack format ["%1 %2 entered %3 instead of %4", _family, _direction, _state, _expectedPace];
        };
        if ((_state select [12, 8]) isNotEqualTo _family) then {
            _failures pushBack format ["Pose changed in %1", _state];
        };
    } forEach [
        ["Df", "Meva"], ["Dfl", "Meva"], ["Dfr", "Meva"],
        ["Dl", "Mrun"], ["Dr", "Mrun"], ["Dbl", "Mrun"],
        ["Db", "Mrun"], ["Dbr", "Mrun"]
    ];
} forEach ["SrasWrfl", "SlowWrfl", "SrasWpst", "SnonWnon"];

// Ordinary slope movement must use Mrun even when the engine asks for Walk/Slow.
{
    private _family = _x;
    {
        private _state = [_family, _x, false] call GAIT_fnc_slopeStateName;
        if ((_state select [8,4]) isNotEqualTo "Mrun") then {
            _failures pushBack format ["Ordinary slope %1/%2 selected walking/sprint state %3", _family, _x, _state];
        };
    } forEach ["Df","Dfl","Dfr"];
} forEach ["SrasWrfl", "SlowWrfl", "SrasWpst", "SnonWnon"];

if (_failures isEqualTo []) then {
    diag_log "GAIT slope state selection tests PASS: sprint forward states plus ordinary forward/diagonal Mrun jog states preserve their weapon family.";
} else {
    {diag_log ("GAIT sprint state selection tests FAIL: " + _x);} forEach _failures;
    throw "GAIT sprint state selection regression failed";
};
