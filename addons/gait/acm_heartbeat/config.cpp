class CfgPatches
{
    class gait_acm_heartbeat
    {
        addonRootClass = "gait";
        requiredAddons[] = {"gait", "ACM_core"};
        skipWhenMissingDependencies = 1;
        units[] = {};
        weapons[] = {};
    };
};

// ACM registers heartbeat through CfgFunctions as well as ACE's CBA route.
// Load after ACM to use the same gain control for whichever route runs first.
class CfgFunctions
{
    class overwrite_medical_feedback
    {
        tag = "ace_medical_feedback";
        class ace_medical_feedback
        {
            class effectHeartBeat
            {
                file = "\gait\functions\fn_aceHeartbeatVolume.sqf";
            };
        };
    };
};
