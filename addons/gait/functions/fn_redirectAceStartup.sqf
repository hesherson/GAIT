/*
    Preserve ACE startup and CBA compilation. Replace one function's source
    path before CBA creates its final function. Both startup phases use this
    path so CBA development recompilation behaves the same way.
*/
params ["_startupPath", "_functionPath", "_replacementPath"];
private _source = preprocessFileLineNumbers _startupPath;
private _start = (toLower _source) find (toLower _functionPath);
if (_start < 0) exitWith {
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT] ACE startup skipped GAIT source %1: %2 does not reference the expected ACE function.", _replacementPath, _startupPath];
    };
    call compileScript [_startupPath];
};
private _remainder = _source select [_start + count _functionPath];
if (((toLower _remainder) find (toLower _functionPath)) >= 0) exitWith {
    if (missionNamespace getVariable ["GAIT_ss_debugHudEnabled", false]) then {
        diag_log format ["[GAIT] ACE startup skipped GAIT source %1: %2 references the ACE function more than once.", _replacementPath, _startupPath];
    };
    call compileScript [_startupPath];
};
private _redirected = (_source select [0, _start]) + _replacementPath + _remainder;
call compile _redirected;
