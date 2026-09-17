/* Run after fn_slopeLocomotion.sqf. Tests only the shared pure selector. */
private _failures = [];
{
    _x params ["_forward", "_right", "_expected"];
    private _actual = [_forward, _right] call GAIT_fnc_slopeDirection;
    if !(_actual isEqualTo _expected) then {
        _failures pushBack format ["[%1,%2]: expected %3, got %4", _forward, _right, _expected, _actual];
    };
} forEach [
    [1, 0, "Df"], [1, 1, "Dfr"], [0, 1, "Dr"], [-1, 1, "Dbr"],
    [-1, 0, "Db"], [-1, -1, "Dbl"], [0, -1, "Dl"], [1, -1, "Dfl"],
    [0, 0, "Dnon"], [0.05, -0.05, "Dnon"],
    [0, 0.06, "Dr"], [0, -0.06, "Dl"],
    [1, 0.40, "Df"], [1, 0.42, "Dfr"],
    [1, -0.40, "Df"], [1, -0.42, "Dfl"]
];
// Reversing A -> D or releasing W while D stays held must select the live
// direction directly. No remembered forward fallback may leak into release.
private _sequence = [[1, -1], [1, 1], [0, 1], [0, -1], [0, 0]] apply {_x call GAIT_fnc_slopeDirection};
if !(_sequence isEqualTo ["Dfl", "Dfr", "Dr", "Dl", "Dnon"]) then {
    _failures pushBack format ["Direction release sequence: %1", _sequence];
};
if (_failures isEqualTo []) then {
    diag_log "GAIT slope direction tests PASS (16 selections and reversal/release sequence).";
} else {
    {diag_log ("GAIT slope direction tests FAIL: " + _x);} forEach _failures;
    throw "GAIT slope direction regression failed";
};
