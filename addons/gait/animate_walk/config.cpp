class CfgPatches
{
    class gait_animate_walk
    {
        addonRootClass = "gait";
        requiredAddons[] = {"gait", "tsp_animate_walk"};
        skipWhenMissingDependencies = 1;
        units[] = {};
        weapons[] = {};
    };
};

// Animate selects the unsuffixed standing lowered-rifle combat clips.
// Pair each native RTM with its measured root travel in metres per cycle.
#define GAIT_ANIMATE_COMBAT(NATIVE, WRAPPER, DISTANCE, RTM) \
    class NATIVE; \
    class WRAPPER: NATIVE \
    { \
        GAIT_nativeState = #NATIVE; \
        GAIT_rootTravel[] = {DISTANCE, RTM}; \
    }

class CfgMovesBasic;
class CfgMovesMaleSdr: CfgMovesBasic
{
    class States
    {
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDf,AmovPercMtacSlowWrflDf_GAIT,2.0279,"amovpercmtacslowwrfldf.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDfl,AmovPercMtacSlowWrflDfl_GAIT,2.0279,"amovpercmtacslowwrfldfl.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDl,AmovPercMtacSlowWrflDl_GAIT,1.7873,"amovpercmtacslowwrfldl.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDbl,AmovPercMtacSlowWrflDbl_GAIT,1.3831,"amovpercmtacslowwrfldbl.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDb,AmovPercMtacSlowWrflDb_GAIT,1.3831,"amovpercmtacslowwrfldb.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDbr,AmovPercMtacSlowWrflDbr_GAIT,1.3831,"amovpercmtacslowwrfldbr.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDr,AmovPercMtacSlowWrflDr_GAIT,1.7379,"amovpercmtacslowwrfldr.rtm");
        GAIT_ANIMATE_COMBAT(AmovPercMtacSlowWrflDfr,AmovPercMtacSlowWrflDfr_GAIT,2.0279,"amovpercmtacslowwrfldfr.rtm");
    };
};

#undef GAIT_ANIMATE_COMBAT
