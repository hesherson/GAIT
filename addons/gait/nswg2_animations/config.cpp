class CfgPatches
{
    class gait_nswg2_animations
    {
        addonRootClass = "gait";
        requiredAddons[] = {"gait", "NAVSPECWARGRU2_Sys_Animations"};
        skipWhenMissingDependencies = 1;
        units[] = {};
        weapons[] = {};
    };
};

// Reopen these states with their original parents. Arma treats a definition
// without a base as removing inheritance, including the idle action map.
#define GAIT_NSWG2_IDLE(CLASS,BASE) \
    class CLASS: BASE \
    { \
        InterpolateTo[] += { \
            "AmovPercMevaSrasWrflDf_GAIT", 0.02, "AmovPercMevaSrasWrflDfl_GAIT", 0.02, "AmovPercMevaSrasWrflDfr_GAIT", 0.02, \
            "AmovPercMrunSrasWrflDf_GAIT", 0.02, "AmovPercMrunSrasWrflDfl_GAIT", 0.02, "AmovPercMrunSrasWrflDl_GAIT", 0.02, \
            "AmovPercMrunSrasWrflDbl_GAIT", 0.02, "AmovPercMrunSrasWrflDb_GAIT", 0.02, "AmovPercMrunSrasWrflDbr_GAIT", 0.02, \
            "AmovPercMrunSrasWrflDr_GAIT", 0.02, "AmovPercMrunSrasWrflDfr_GAIT", 0.02 \
        }; \
    }

class CfgMovesBasic;
class CfgMovesMaleSdr: CfgMovesBasic
{
    class States
    {
        class AidlPercMstpSrasWrflDnon_G04;
        class AidlPercMstpSrasWrflDnon_G0S;
        GAIT_NSWG2_IDLE(AidlPercMstpSrasWrflDnon_G01_player,AidlPercMstpSrasWrflDnon_G04);
        GAIT_NSWG2_IDLE(AidlPercMstpSrasWrflDnon_G02_player,AidlPercMstpSrasWrflDnon_G04);
        GAIT_NSWG2_IDLE(AidlPercMstpSrasWrflDnon_G03_player,AidlPercMstpSrasWrflDnon_G04);
        GAIT_NSWG2_IDLE(AidlPercMstpSrasWrflDnon_G04_player,AidlPercMstpSrasWrflDnon_G04);
        GAIT_NSWG2_IDLE(AmovPercMstpSrasWrflDnon_turnL,AidlPercMstpSrasWrflDnon_G0S);
        GAIT_NSWG2_IDLE(AmovPercMstpSrasWrflDnon_turnR,AidlPercMstpSrasWrflDnon_G0S);
    };
};

#undef GAIT_NSWG2_IDLE
