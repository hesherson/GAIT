// GAIT 1.8.0-alpha28: blended sprint release, steep-climb continuity, and grade-based exertion
class CfgPatches
{
    class gait
    {
        name = "GAIT";
        version = 1.8;
        versionStr = "1.8.0-alpha28";
        versionAr[] = {1,8,0,28};
        author = "mavis";
        url = "";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Functions_F", "A3_Modules_F", "A3_Characters_F", "A3_Anims_F", "cba_main", "cba_xeh", "cba_settings", "ace_common", "ace_advanced_fatigue", "ace_medical_feedback"};
        units[] = {"GAIT_ModuleResetEffects"};
        weapons[] = {};
    };
};

class Extended_PreStart_EventHandlers
{
    class ace_advanced_fatigue
    {
        init = "['\z\ace\addons\advanced_fatigue\XEH_preStart.sqf', '\z\ace\addons\advanced_fatigue\functions\fnc_mainLoop.sqf', '\gait\functions\fn_aceSprintReserveHook.sqf'] call compileScript ['\gait\functions\fn_redirectAceStartup.sqf'];";
    };
    class ace_medical_feedback
    {
        init = "['\z\ace\addons\medical_feedback\XEH_preStart.sqf', '\z\ace\addons\medical_feedback\functions\fnc_effectHeartBeat.sqf', '\gait\functions\fn_aceHeartbeatVolume.sqf'] call compileScript ['\gait\functions\fn_redirectAceStartup.sqf'];";
    };
};

#include "slope_actions.hpp"

class CfgFunctions
{
    class GAIT
    {
        class traversal
        {
            file = "\gait\functions";
            // v1.6.0 (FIX 1 - Eden Editor settings): registration is NO LONGER
            // driven by CfgFunctions preInit. CfgFunctions preInit only runs when a
            // real mission enters its preInit phase; the bare 3DEN/Eden editor never
            // runs it, so GAIT's CBA Addon Options never reached the editor's
            // Settings panel. Registration now runs from Extended_PreInit_EventHandlers
            // (CBA XEH preInit) below, which executes in BOTH missions and 3DEN.
            // REVERT: restore "preInit = 1;" here AND delete the
            // Extended_PreInit_EventHandlers block at the bottom of this file.
            class registerSettings {};
            class initSprintSystem
            {
                postInit = 1;
            };
            class applyPreset {};
            class resetEffects {};
            class moduleResetEffects {};
        };
    };
};

// v1.6.0 (FIX 1 - Eden Editor settings): run the CBA Addon Option registration
// from CBA's XEH preInit. Unlike CfgFunctions preInit, Extended_PreInit_EventHandlers
// fires in the 3DEN/Eden editor as well as in live missions, so the options now
// appear under Settings -> Addon Options in the editor. This is the same mechanism
// ACE uses for its editor-visible settings. The settings file only depends on
// CBA_fnc_addSetting (which exists by XEH preInit time) and self-guards if absent.
// REVERT: delete this whole block and restore "preInit = 1;" on class registerSettings.
class Extended_PreInit_EventHandlers
{
    class ace_advanced_fatigue
    {
        init = "['\z\ace\addons\advanced_fatigue\XEH_preInit.sqf', '\z\ace\addons\advanced_fatigue\functions\fnc_mainLoop.sqf', '\gait\functions\fn_aceSprintReserveHook.sqf'] call compileScript ['\gait\functions\fn_redirectAceStartup.sqf'];";
    };
    class ace_medical_feedback
    {
        init = "['\z\ace\addons\medical_feedback\XEH_preInit.sqf', '\z\ace\addons\medical_feedback\functions\fnc_effectHeartBeat.sqf', '\gait\functions\fn_aceHeartbeatVolume.sqf'] call compileScript ['\gait\functions\fn_redirectAceStartup.sqf'];";
    };

    class GAIT
    {
        init = "call compile preprocessFileLineNumbers '\gait\functions\fn_registerSettings.sqf'";
    };
};


class CfgFactionClasses
{
    class NO_CATEGORY;

    class GAIT_Module_Category: NO_CATEGORY
    {
        displayName = "GAIT";
    };
};

class CfgVehicles
{
    class Logic;

    class Module_F: Logic
    {
        class ModuleDescription;
    };

    class GAIT_ModuleResetEffects: Module_F
    {
        scope = 2;
        scopeCurator = 2;
        displayName = "Reset GAIT Movement";
        category = "GAIT_Module_Category";
        function = "GAIT_fnc_moduleResetEffects";
        functionPriority = 1;
        isGlobal = 1;
        isTriggerActivated = 0;
        isDisposable = 0;
        curatorCanAttach = 1;
        icon = "\a3\Modules_F\Data\iconModule_ca.paa";

        class Arguments {};

        class ModuleDescription: ModuleDescription
        {
            description = "Resets GAIT movement on synchronized players. If no players are synchronized, resets all players.";
        };
    };
};
