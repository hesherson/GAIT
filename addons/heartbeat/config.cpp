// GAIT 1.8.0-alpha8: reduce ACE heartbeat playback gain by exactly half.
// ACE owns the playback loop, heart rate, sound selection and every other sound.
// This optional addon is skipped when ACE Medical Feedback is not installed.
class CfgPatches
{
    class gait_heartbeat
    {
        name = "GAIT ACE Heartbeat Volume";
        author = "mavis";
        requiredVersion = 2.18;
        requiredAddons[] = {"ace_medical_feedback"};
        skipWhenMissingDependencies = 1;
        units[] = {};
        weapons[] = {};
    };
};

// ACE's original gain is "db+1", or 10^(1/20) = 1.122018454.
// Half amplitude is 0.561009227, equivalent to approximately -5.0206 dB.
// Paths and pitch match ACE Medical Feedback; other class fields stay inherited.
// Reference: acemod/ACE3 addons/medical_feedback/CfgSounds.hpp
class CfgSounds
{
    class ACE_heartbeat_fast_1
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\fast_1.wav", 0.561009227, 1};
    };
    class ACE_heartbeat_fast_2
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\fast_2.wav", 0.561009227, 1};
    };
    class ACE_heartbeat_fast_3
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\fast_3.wav", 0.561009227, 1};
    };
    class ACE_heartbeat_norm_1
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\norm_1.wav", 0.561009227, 1};
    };
    class ACE_heartbeat_norm_2
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\norm_2.wav", 0.561009227, 1};
    };
    class ACE_heartbeat_slow_1
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\slow_1.wav", 0.561009227, 1};
    };
    class ACE_heartbeat_slow_2
    {
        sound[] = {"\z\ace\addons\medical_feedback\sounds\slow_2.wav", 0.561009227, 1};
    };
};
