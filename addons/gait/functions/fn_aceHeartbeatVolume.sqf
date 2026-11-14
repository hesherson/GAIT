/*
    ACE Medical Feedback owns the timing and sound selection. Before CBA
    caches its heartbeat function, substitute only its two playback calls.
    Unknown source layouts leave the original ACE function in use.
*/
private _aceFunction = "ace_medical_feedback_fnc_effectHeartBeat";
if (!isNil {uiNamespace getVariable _aceFunction}) exitWith {};

// ACM and ACM Extended declare their own heartbeat function with a different
// trigger threshold and gain curve. Keep that source when it is installed.
private _override = getText (configFile >> "CfgFunctions" >> "overwrite_medical_feedback" >>
    "ace_medical_feedback" >> "effectHeartBeat" >> "file");
private _sourcePath = ["\z\ace\addons\medical_feedback\functions\fnc_effectHeartBeat.sqf", _override] select (_override isNotEqualTo "");
private _source = preprocessFileLineNumbers _sourcePath;
private _focus = '(\bisGameFocused\s*\)?\s*then\s*\{\s*)';
private _fastSound = '([''"]ACE_heartbeat_fast_1[''"])';
private _slowSound = '(\(\s*selectRandom\s*\[\s*[''"]ACE_heartbeat_slow_1[''"]\s*,\s*[''"]ACE_heartbeat_slow_2[''"]\s*\]\s*\))';
private _fast = _focus + 'playSound\s+' + _fastSound + '\s*;/g';
private _slow = _focus + 'playSound\s+' + _slowSound + '\s*;/g';
if (_override isNotEqualTo "") then {
    private _uiGain = '\s*,\s*(\(\s*linearConversion\s*\[[^\]\r\n]+\]\s*\))\s*\]\s*;/g';
    _fast = _focus + 'playSoundUI\s*\[\s*' + _fastSound + _uiGain;
    _slow = _focus + 'playSoundUI\s*\[\s*' + _slowSound + _uiGain;
};
if (count (_source regexFind [_fast]) isNotEqualTo 1 ||
    {count (_source regexFind [_slow]) isNotEqualTo 1}) exitWith {
    diag_log "[GAIT] ACE heartbeat volume unavailable: the installed ACE playback source differs from the supported layout.";
};

uiNamespace setVariable ["GAIT_fnc_playAceHeartbeat", compileFinal {
    params ["_soundClass", ["_uiGain", -1, [0]]];
    private _percentage = missionNamespace getVariable ["GAIT_ss_aceHeartbeatVolume", 10];
    if (_percentage <= 0) exitWith {};
    if (_uiGain >= 0) exitWith {
        playSoundUI [_soundClass, _uiGain * ((_percentage min 100) / 100)];
    };
    if (_percentage >= 100) exitWith {playSound _soundClass;};

    private _sound = getArray (configFile >> "CfgSounds" >> _soundClass >> "sound");
    private _sample = _sound param [0, "", [""]];
    private _gain = _sound param [1, 1, [0, ""]];
    private _pitch = _sound param [2, 1, [0]];
    if (_sample isEqualTo "") exitWith {playSound _soundClass;};
    if (_gain isEqualType "") then {
        _gain = if ((toLower (_gain select [0, 2])) isEqualTo "db") then {
            10 ^ ((parseNumber (_gain select [2])) / 20)
        } else {
            1
        };
    };
    playSoundUI [_sample, _gain * (_percentage / 100), _pitch, true];
}];

private _arguments = ['$2', '$2, $3'] select (_override isNotEqualTo "");
private _playback = '$1[' + _arguments + '] call (uiNamespace getVariable "GAIT_fnc_playAceHeartbeat");';
_source = _source regexReplace [_fast, _playback];
_source = _source regexReplace [_slow, _playback];
uiNamespace setVariable [_aceFunction, compileFinal _source];
