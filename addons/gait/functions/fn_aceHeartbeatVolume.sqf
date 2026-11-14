/*
    Local heartbeat playback for ACE Medical Feedback and ACM.
    Their feedback handler starts this function and owns the player's heart
    rate. The fast/slow thresholds and scheduling mirror their heartbeat
    handlers. GAIT changes the gain of only the heartbeat sample.
*/
if (!hasInterface) exitWith {};
private _unit = missionNamespace getVariable ["ace_player", player];
private _heartRate = _unit getVariable ["ace_medical_heartRate", 80];
if (missionNamespace getVariable ["ace_common_OldIsCamera", false] || {_heartRate <= 0}) exitWith {
    ace_medical_feedback_heartBeatEffectRunning = false;
};

private _acm = isClass (configFile >> "CfgPatches" >> "gait_acm_heartbeat");
private _fastThreshold = [160, 140] select _acm;
private _fast = _heartRate > _fastThreshold;
if (!_fast && {_heartRate >= 60}) exitWith {
    ace_medical_feedback_heartBeatEffectRunning = false;
};

private _percentage = (missionNamespace getVariable ["GAIT_ss_aceHeartbeatVolume", 10]) max 0 min 100;
if (isGameFocused && {_percentage > 0}) then {
    private _sound = if (_fast) then {"ACE_heartbeat_fast_1"} else {
        selectRandom ["ACE_heartbeat_slow_1", "ACE_heartbeat_slow_2"]
    };
    if (_acm) then {
        private _gain = if (_fast) then {
            linearConversion [140, 190, _heartRate, 0.1, 1, true]
        } else {
            linearConversion [60, 45, _heartRate, 0.1, 1, true]
        };
        playSoundUI [_sound, _gain * (_percentage / 100)];
    } else {
        if (_percentage isEqualTo 100) then {
            playSound _sound;
        } else {
            private _sample = getArray (configFile >> "CfgSounds" >> _sound >> "sound");
            private _path = _sample param [0, "", [""]];
            private _gain = _sample param [1, 1, [0, ""]];
            private _pitch = _sample param [2, 1, [0]];
            if (_gain isEqualType "") then {
                _gain = if ((toLower (_gain select [0, 2])) isEqualTo "db") then {
                    10 ^ ((parseNumber (_gain select [2])) / 20)
                } else {1};
            };
            if (_path isNotEqualTo "") then {
                playSoundUI [_path, _gain * (_percentage / 100), _pitch, true];
            } else {
                playSoundUI [_sound, _percentage / 100, 1, true];
            };
        };
    };
};

[ace_medical_feedback_fnc_effectHeartBeat, [], 60 / _heartRate] call CBA_fnc_waitAndExecute;
