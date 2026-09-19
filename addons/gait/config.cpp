// GAIT 1.8.0-alpha7: slope sprint test build
class CfgPatches
{
    class gait
    {
        name = "GAIT";
        version = 1.8;
        versionStr = "1.8.0-alpha7";
        versionAr[] = {1,8,0,7};
        author = "mavis";
        url = "";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Functions_F", "A3_Modules_F", "A3_Characters_F", "A3_Anims_F", "cba_main", "cba_xeh", "cba_settings", "ace_common", "ace_advanced_fatigue"};
        units[] = {"GAIT_ModuleResetEffects"};
        weapons[] = {};
    };
};

// Documented terrain animation-speed multiplier. This is a config-time
// change while the addon is loaded, not a guarantee of sprinting on all slopes.
class CfgMovesFatigue
{
    terrainSpeedCoef = 1;
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
    class Man;
    class CAManBase: Man
    {
        class CfgMovesFatigue
        {
            terrainSpeedCoef = 1;
        };
    };

    class Logic;

    class Module_F: Logic
    {
        class ArgumentsBaseUnits
        {
            class Units;
        };
        class ModuleDescription
        {
            class AnyBrain;
        };
    };

    class GAIT_ModuleResetEffects: Module_F
    {
        scope = 2;
        scopeCurator = 2;
        displayName = "Reset GAIT Effects";
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
            description = "Resets GAIT movement, hearing, tinnitus, and visual fatigue effects on synchronized players. If no players are synchronized, resets all players.";
        };
    };
};

class CfgSounds
{
    sounds[] = {"GAIT_tinnitus_loop"};

    class GAIT_tinnitus_loop
    {
        name = "GAIT_tinnitus_loop";
        sound[] = {"\gait\sounds\tinnitus_loop.ogg", 1, 1, 5};
        titles[] = {};
    };
};
