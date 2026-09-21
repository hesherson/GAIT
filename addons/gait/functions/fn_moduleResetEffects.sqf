/*
    GAIT_fnc_moduleResetEffects
    Zeus module function. Resets GAIT client-side effects on synchronized player units.
    If nothing is synchronized, all players are reset.
*/

params [
    ["_logic", objNull, [objNull]],
    ["_units", [], [[]]],
    ["_activated", true, [true]]
];

if (!_activated) exitWith {};
if (!isServer) exitWith {};

private _targets = _units select { _x isKindOf "CAManBase" };
_targets = _targets select { isPlayer _x };

if (_targets isEqualTo []) then {
    _targets = allPlayers;
};

{
    ["GAIT_resetEffects", ["zeus_module"], _x] call CBA_fnc_targetEvent;
} forEach _targets;

diag_log format ["[GAIT] Zeus reset module activated for %1 player(s).", count _targets];

if (!isNull _logic) then {
    deleteVehicle _logic;
};
