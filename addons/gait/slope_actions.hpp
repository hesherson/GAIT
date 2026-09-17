/*
 * GAIT opt-in sprint locomotion action families.
 *
 * Forward and forward-diagonal states inherit the real native Meva sprint
 * clips. Lateral and backward directions inherit Mrun, matching normal
 * locomotion. All pace selectors inside this opt-in family use these states,
 * so the terrain's Walk request does not replace a held sprint with walking.
 *
 * Only custom states have custom Actions. Vanilla stop, stance, weapon,
 * injury, vault and other action destinations remain inherited.
 *
 * Native state names: https://community.bistudio.com/wiki/Arma_3:_Moves
 * Player selectors: https://github.com/acemod/ACE3/blob/master/addons/dragging/CfgMovesBasic.hpp
 * Native graph weights and lowered-rifle variants:
 * https://github.com/acemod/ACE3/blob/master/addons/movement/CfgMoves.hpp
 * https://github.com/acemod/ACE3/blob/master/addons/advanced_fatigue/CfgMovesMaleSdr.hpp
 *
 * Entry/exit use the animation graph; no instant switchMove is necessary.
 * The numeric edge values match native locomotion weights. They are not
 * advertised as fixed blend times. Live Arma blending still needs testing.
 */
class CfgMovesBasic
{
    class Actions
    {
        class RifleStandActions;
        class GAIT_SlopeRifleRaisedActions: RifleStandActions
        {
            WalkF = "AmovPercMevaSrasWrflDf_GAIT";
            WalkLF = "AmovPercMevaSrasWrflDfl_GAIT";
            WalkL = "AmovPercMrunSrasWrflDl_GAIT";
            WalkLB = "AmovPercMrunSrasWrflDbl_GAIT";
            WalkB = "AmovPercMrunSrasWrflDb_GAIT";
            WalkRB = "AmovPercMrunSrasWrflDbr_GAIT";
            WalkR = "AmovPercMrunSrasWrflDr_GAIT";
            WalkRF = "AmovPercMevaSrasWrflDfr_GAIT";
            PlayerWalkF = "AmovPercMevaSrasWrflDf_GAIT";
            PlayerWalkLF = "AmovPercMevaSrasWrflDfl_GAIT";
            PlayerWalkL = "AmovPercMrunSrasWrflDl_GAIT";
            PlayerWalkLB = "AmovPercMrunSrasWrflDbl_GAIT";
            PlayerWalkB = "AmovPercMrunSrasWrflDb_GAIT";
            PlayerWalkRB = "AmovPercMrunSrasWrflDbr_GAIT";
            PlayerWalkR = "AmovPercMrunSrasWrflDr_GAIT";
            PlayerWalkRF = "AmovPercMevaSrasWrflDfr_GAIT";
            SlowF = "AmovPercMevaSrasWrflDf_GAIT";
            SlowLF = "AmovPercMevaSrasWrflDfl_GAIT";
            SlowL = "AmovPercMrunSrasWrflDl_GAIT";
            SlowLB = "AmovPercMrunSrasWrflDbl_GAIT";
            SlowB = "AmovPercMrunSrasWrflDb_GAIT";
            SlowRB = "AmovPercMrunSrasWrflDbr_GAIT";
            SlowR = "AmovPercMrunSrasWrflDr_GAIT";
            SlowRF = "AmovPercMevaSrasWrflDfr_GAIT";
            PlayerSlowF = "AmovPercMevaSrasWrflDf_GAIT";
            PlayerSlowLF = "AmovPercMevaSrasWrflDfl_GAIT";
            PlayerSlowL = "AmovPercMrunSrasWrflDl_GAIT";
            PlayerSlowLB = "AmovPercMrunSrasWrflDbl_GAIT";
            PlayerSlowB = "AmovPercMrunSrasWrflDb_GAIT";
            PlayerSlowRB = "AmovPercMrunSrasWrflDbr_GAIT";
            PlayerSlowR = "AmovPercMrunSrasWrflDr_GAIT";
            PlayerSlowRF = "AmovPercMevaSrasWrflDfr_GAIT";
            FastF = "AmovPercMevaSrasWrflDf_GAIT";
            FastLF = "AmovPercMevaSrasWrflDfl_GAIT";
            FastL = "AmovPercMrunSrasWrflDl_GAIT";
            FastLB = "AmovPercMrunSrasWrflDbl_GAIT";
            FastB = "AmovPercMrunSrasWrflDb_GAIT";
            FastRB = "AmovPercMrunSrasWrflDbr_GAIT";
            FastR = "AmovPercMrunSrasWrflDr_GAIT";
            FastRF = "AmovPercMevaSrasWrflDfr_GAIT";
            PlayerFastF = "AmovPercMevaSrasWrflDf_GAIT";
            PlayerFastLF = "AmovPercMevaSrasWrflDfl_GAIT";
            PlayerFastL = "AmovPercMrunSrasWrflDl_GAIT";
            PlayerFastLB = "AmovPercMrunSrasWrflDbl_GAIT";
            PlayerFastB = "AmovPercMrunSrasWrflDb_GAIT";
            PlayerFastRB = "AmovPercMrunSrasWrflDbr_GAIT";
            PlayerFastR = "AmovPercMrunSrasWrflDr_GAIT";
            PlayerFastRF = "AmovPercMevaSrasWrflDfr_GAIT";
            TactF = "AmovPercMevaSrasWrflDf_GAIT";
            TactLF = "AmovPercMevaSrasWrflDfl_GAIT";
            TactL = "AmovPercMrunSrasWrflDl_GAIT";
            TactLB = "AmovPercMrunSrasWrflDbl_GAIT";
            TactB = "AmovPercMrunSrasWrflDb_GAIT";
            TactRB = "AmovPercMrunSrasWrflDbr_GAIT";
            TactR = "AmovPercMrunSrasWrflDr_GAIT";
            TactRF = "AmovPercMevaSrasWrflDfr_GAIT";
            PlayerTactF = "AmovPercMevaSrasWrflDf_GAIT";
            PlayerTactLF = "AmovPercMevaSrasWrflDfl_GAIT";
            PlayerTactL = "AmovPercMrunSrasWrflDl_GAIT";
            PlayerTactLB = "AmovPercMrunSrasWrflDbl_GAIT";
            PlayerTactB = "AmovPercMrunSrasWrflDb_GAIT";
            PlayerTactRB = "AmovPercMrunSrasWrflDbr_GAIT";
            PlayerTactR = "AmovPercMrunSrasWrflDr_GAIT";
            PlayerTactRF = "AmovPercMevaSrasWrflDfr_GAIT";
        };

        class RifleLowStandActions;
        class GAIT_SlopeRifleLoweredActions: RifleLowStandActions
        {
            WalkF = "AmovPercMevaSlowWrflDf_GAIT";
            WalkLF = "AmovPercMevaSlowWrflDfl_GAIT";
            WalkL = "AmovPercMrunSlowWrflDl_GAIT";
            WalkLB = "AmovPercMrunSlowWrflDbl_GAIT";
            WalkB = "AmovPercMrunSlowWrflDb_GAIT";
            WalkRB = "AmovPercMrunSlowWrflDbr_GAIT";
            WalkR = "AmovPercMrunSlowWrflDr_GAIT";
            WalkRF = "AmovPercMevaSlowWrflDfr_GAIT";
            PlayerWalkF = "AmovPercMevaSlowWrflDf_GAIT";
            PlayerWalkLF = "AmovPercMevaSlowWrflDfl_GAIT";
            PlayerWalkL = "AmovPercMrunSlowWrflDl_GAIT";
            PlayerWalkLB = "AmovPercMrunSlowWrflDbl_GAIT";
            PlayerWalkB = "AmovPercMrunSlowWrflDb_GAIT";
            PlayerWalkRB = "AmovPercMrunSlowWrflDbr_GAIT";
            PlayerWalkR = "AmovPercMrunSlowWrflDr_GAIT";
            PlayerWalkRF = "AmovPercMevaSlowWrflDfr_GAIT";
            SlowF = "AmovPercMevaSlowWrflDf_GAIT";
            SlowLF = "AmovPercMevaSlowWrflDfl_GAIT";
            SlowL = "AmovPercMrunSlowWrflDl_GAIT";
            SlowLB = "AmovPercMrunSlowWrflDbl_GAIT";
            SlowB = "AmovPercMrunSlowWrflDb_GAIT";
            SlowRB = "AmovPercMrunSlowWrflDbr_GAIT";
            SlowR = "AmovPercMrunSlowWrflDr_GAIT";
            SlowRF = "AmovPercMevaSlowWrflDfr_GAIT";
            PlayerSlowF = "AmovPercMevaSlowWrflDf_GAIT";
            PlayerSlowLF = "AmovPercMevaSlowWrflDfl_GAIT";
            PlayerSlowL = "AmovPercMrunSlowWrflDl_GAIT";
            PlayerSlowLB = "AmovPercMrunSlowWrflDbl_GAIT";
            PlayerSlowB = "AmovPercMrunSlowWrflDb_GAIT";
            PlayerSlowRB = "AmovPercMrunSlowWrflDbr_GAIT";
            PlayerSlowR = "AmovPercMrunSlowWrflDr_GAIT";
            PlayerSlowRF = "AmovPercMevaSlowWrflDfr_GAIT";
            FastF = "AmovPercMevaSlowWrflDf_GAIT";
            FastLF = "AmovPercMevaSlowWrflDfl_GAIT";
            FastL = "AmovPercMrunSlowWrflDl_GAIT";
            FastLB = "AmovPercMrunSlowWrflDbl_GAIT";
            FastB = "AmovPercMrunSlowWrflDb_GAIT";
            FastRB = "AmovPercMrunSlowWrflDbr_GAIT";
            FastR = "AmovPercMrunSlowWrflDr_GAIT";
            FastRF = "AmovPercMevaSlowWrflDfr_GAIT";
            PlayerFastF = "AmovPercMevaSlowWrflDf_GAIT";
            PlayerFastLF = "AmovPercMevaSlowWrflDfl_GAIT";
            PlayerFastL = "AmovPercMrunSlowWrflDl_GAIT";
            PlayerFastLB = "AmovPercMrunSlowWrflDbl_GAIT";
            PlayerFastB = "AmovPercMrunSlowWrflDb_GAIT";
            PlayerFastRB = "AmovPercMrunSlowWrflDbr_GAIT";
            PlayerFastR = "AmovPercMrunSlowWrflDr_GAIT";
            PlayerFastRF = "AmovPercMevaSlowWrflDfr_GAIT";
            TactF = "AmovPercMevaSlowWrflDf_GAIT";
            TactLF = "AmovPercMevaSlowWrflDfl_GAIT";
            TactL = "AmovPercMrunSlowWrflDl_GAIT";
            TactLB = "AmovPercMrunSlowWrflDbl_GAIT";
            TactB = "AmovPercMrunSlowWrflDb_GAIT";
            TactRB = "AmovPercMrunSlowWrflDbr_GAIT";
            TactR = "AmovPercMrunSlowWrflDr_GAIT";
            TactRF = "AmovPercMevaSlowWrflDfr_GAIT";
            PlayerTactF = "AmovPercMevaSlowWrflDf_GAIT";
            PlayerTactLF = "AmovPercMevaSlowWrflDfl_GAIT";
            PlayerTactL = "AmovPercMrunSlowWrflDl_GAIT";
            PlayerTactLB = "AmovPercMrunSlowWrflDbl_GAIT";
            PlayerTactB = "AmovPercMrunSlowWrflDb_GAIT";
            PlayerTactRB = "AmovPercMrunSlowWrflDbr_GAIT";
            PlayerTactR = "AmovPercMrunSlowWrflDr_GAIT";
            PlayerTactRF = "AmovPercMevaSlowWrflDfr_GAIT";
        };

        class PistolStandActions;
        class GAIT_SlopePistolActions: PistolStandActions
        {
            WalkF = "AmovPercMevaSrasWpstDf_GAIT";
            WalkLF = "AmovPercMevaSrasWpstDfl_GAIT";
            WalkL = "AmovPercMrunSrasWpstDl_GAIT";
            WalkLB = "AmovPercMrunSrasWpstDbl_GAIT";
            WalkB = "AmovPercMrunSrasWpstDb_GAIT";
            WalkRB = "AmovPercMrunSrasWpstDbr_GAIT";
            WalkR = "AmovPercMrunSrasWpstDr_GAIT";
            WalkRF = "AmovPercMevaSrasWpstDfr_GAIT";
            PlayerWalkF = "AmovPercMevaSrasWpstDf_GAIT";
            PlayerWalkLF = "AmovPercMevaSrasWpstDfl_GAIT";
            PlayerWalkL = "AmovPercMrunSrasWpstDl_GAIT";
            PlayerWalkLB = "AmovPercMrunSrasWpstDbl_GAIT";
            PlayerWalkB = "AmovPercMrunSrasWpstDb_GAIT";
            PlayerWalkRB = "AmovPercMrunSrasWpstDbr_GAIT";
            PlayerWalkR = "AmovPercMrunSrasWpstDr_GAIT";
            PlayerWalkRF = "AmovPercMevaSrasWpstDfr_GAIT";
            SlowF = "AmovPercMevaSrasWpstDf_GAIT";
            SlowLF = "AmovPercMevaSrasWpstDfl_GAIT";
            SlowL = "AmovPercMrunSrasWpstDl_GAIT";
            SlowLB = "AmovPercMrunSrasWpstDbl_GAIT";
            SlowB = "AmovPercMrunSrasWpstDb_GAIT";
            SlowRB = "AmovPercMrunSrasWpstDbr_GAIT";
            SlowR = "AmovPercMrunSrasWpstDr_GAIT";
            SlowRF = "AmovPercMevaSrasWpstDfr_GAIT";
            PlayerSlowF = "AmovPercMevaSrasWpstDf_GAIT";
            PlayerSlowLF = "AmovPercMevaSrasWpstDfl_GAIT";
            PlayerSlowL = "AmovPercMrunSrasWpstDl_GAIT";
            PlayerSlowLB = "AmovPercMrunSrasWpstDbl_GAIT";
            PlayerSlowB = "AmovPercMrunSrasWpstDb_GAIT";
            PlayerSlowRB = "AmovPercMrunSrasWpstDbr_GAIT";
            PlayerSlowR = "AmovPercMrunSrasWpstDr_GAIT";
            PlayerSlowRF = "AmovPercMevaSrasWpstDfr_GAIT";
            FastF = "AmovPercMevaSrasWpstDf_GAIT";
            FastLF = "AmovPercMevaSrasWpstDfl_GAIT";
            FastL = "AmovPercMrunSrasWpstDl_GAIT";
            FastLB = "AmovPercMrunSrasWpstDbl_GAIT";
            FastB = "AmovPercMrunSrasWpstDb_GAIT";
            FastRB = "AmovPercMrunSrasWpstDbr_GAIT";
            FastR = "AmovPercMrunSrasWpstDr_GAIT";
            FastRF = "AmovPercMevaSrasWpstDfr_GAIT";
            PlayerFastF = "AmovPercMevaSrasWpstDf_GAIT";
            PlayerFastLF = "AmovPercMevaSrasWpstDfl_GAIT";
            PlayerFastL = "AmovPercMrunSrasWpstDl_GAIT";
            PlayerFastLB = "AmovPercMrunSrasWpstDbl_GAIT";
            PlayerFastB = "AmovPercMrunSrasWpstDb_GAIT";
            PlayerFastRB = "AmovPercMrunSrasWpstDbr_GAIT";
            PlayerFastR = "AmovPercMrunSrasWpstDr_GAIT";
            PlayerFastRF = "AmovPercMevaSrasWpstDfr_GAIT";
            TactF = "AmovPercMevaSrasWpstDf_GAIT";
            TactLF = "AmovPercMevaSrasWpstDfl_GAIT";
            TactL = "AmovPercMrunSrasWpstDl_GAIT";
            TactLB = "AmovPercMrunSrasWpstDbl_GAIT";
            TactB = "AmovPercMrunSrasWpstDb_GAIT";
            TactRB = "AmovPercMrunSrasWpstDbr_GAIT";
            TactR = "AmovPercMrunSrasWpstDr_GAIT";
            TactRF = "AmovPercMevaSrasWpstDfr_GAIT";
            PlayerTactF = "AmovPercMevaSrasWpstDf_GAIT";
            PlayerTactLF = "AmovPercMevaSrasWpstDfl_GAIT";
            PlayerTactL = "AmovPercMrunSrasWpstDl_GAIT";
            PlayerTactLB = "AmovPercMrunSrasWpstDbl_GAIT";
            PlayerTactB = "AmovPercMrunSrasWpstDb_GAIT";
            PlayerTactRB = "AmovPercMrunSrasWpstDbr_GAIT";
            PlayerTactR = "AmovPercMrunSrasWpstDr_GAIT";
            PlayerTactRF = "AmovPercMevaSrasWpstDfr_GAIT";
        };

        class CivilStandActions;
        class GAIT_SlopeUnarmedActions: CivilStandActions
        {
            WalkF = "AmovPercMevaSnonWnonDf_GAIT";
            WalkLF = "AmovPercMevaSnonWnonDfl_GAIT";
            WalkL = "AmovPercMrunSnonWnonDl_GAIT";
            WalkLB = "AmovPercMrunSnonWnonDbl_GAIT";
            WalkB = "AmovPercMrunSnonWnonDb_GAIT";
            WalkRB = "AmovPercMrunSnonWnonDbr_GAIT";
            WalkR = "AmovPercMrunSnonWnonDr_GAIT";
            WalkRF = "AmovPercMevaSnonWnonDfr_GAIT";
            PlayerWalkF = "AmovPercMevaSnonWnonDf_GAIT";
            PlayerWalkLF = "AmovPercMevaSnonWnonDfl_GAIT";
            PlayerWalkL = "AmovPercMrunSnonWnonDl_GAIT";
            PlayerWalkLB = "AmovPercMrunSnonWnonDbl_GAIT";
            PlayerWalkB = "AmovPercMrunSnonWnonDb_GAIT";
            PlayerWalkRB = "AmovPercMrunSnonWnonDbr_GAIT";
            PlayerWalkR = "AmovPercMrunSnonWnonDr_GAIT";
            PlayerWalkRF = "AmovPercMevaSnonWnonDfr_GAIT";
            SlowF = "AmovPercMevaSnonWnonDf_GAIT";
            SlowLF = "AmovPercMevaSnonWnonDfl_GAIT";
            SlowL = "AmovPercMrunSnonWnonDl_GAIT";
            SlowLB = "AmovPercMrunSnonWnonDbl_GAIT";
            SlowB = "AmovPercMrunSnonWnonDb_GAIT";
            SlowRB = "AmovPercMrunSnonWnonDbr_GAIT";
            SlowR = "AmovPercMrunSnonWnonDr_GAIT";
            SlowRF = "AmovPercMevaSnonWnonDfr_GAIT";
            PlayerSlowF = "AmovPercMevaSnonWnonDf_GAIT";
            PlayerSlowLF = "AmovPercMevaSnonWnonDfl_GAIT";
            PlayerSlowL = "AmovPercMrunSnonWnonDl_GAIT";
            PlayerSlowLB = "AmovPercMrunSnonWnonDbl_GAIT";
            PlayerSlowB = "AmovPercMrunSnonWnonDb_GAIT";
            PlayerSlowRB = "AmovPercMrunSnonWnonDbr_GAIT";
            PlayerSlowR = "AmovPercMrunSnonWnonDr_GAIT";
            PlayerSlowRF = "AmovPercMevaSnonWnonDfr_GAIT";
            FastF = "AmovPercMevaSnonWnonDf_GAIT";
            FastLF = "AmovPercMevaSnonWnonDfl_GAIT";
            FastL = "AmovPercMrunSnonWnonDl_GAIT";
            FastLB = "AmovPercMrunSnonWnonDbl_GAIT";
            FastB = "AmovPercMrunSnonWnonDb_GAIT";
            FastRB = "AmovPercMrunSnonWnonDbr_GAIT";
            FastR = "AmovPercMrunSnonWnonDr_GAIT";
            FastRF = "AmovPercMevaSnonWnonDfr_GAIT";
            PlayerFastF = "AmovPercMevaSnonWnonDf_GAIT";
            PlayerFastLF = "AmovPercMevaSnonWnonDfl_GAIT";
            PlayerFastL = "AmovPercMrunSnonWnonDl_GAIT";
            PlayerFastLB = "AmovPercMrunSnonWnonDbl_GAIT";
            PlayerFastB = "AmovPercMrunSnonWnonDb_GAIT";
            PlayerFastRB = "AmovPercMrunSnonWnonDbr_GAIT";
            PlayerFastR = "AmovPercMrunSnonWnonDr_GAIT";
            PlayerFastRF = "AmovPercMevaSnonWnonDfr_GAIT";
            TactF = "AmovPercMevaSnonWnonDf_GAIT";
            TactLF = "AmovPercMevaSnonWnonDfl_GAIT";
            TactL = "AmovPercMrunSnonWnonDl_GAIT";
            TactLB = "AmovPercMrunSnonWnonDbl_GAIT";
            TactB = "AmovPercMrunSnonWnonDb_GAIT";
            TactRB = "AmovPercMrunSnonWnonDbr_GAIT";
            TactR = "AmovPercMrunSnonWnonDr_GAIT";
            TactRF = "AmovPercMevaSnonWnonDfr_GAIT";
            PlayerTactF = "AmovPercMevaSnonWnonDf_GAIT";
            PlayerTactLF = "AmovPercMevaSnonWnonDfl_GAIT";
            PlayerTactL = "AmovPercMrunSnonWnonDl_GAIT";
            PlayerTactLB = "AmovPercMrunSnonWnonDbl_GAIT";
            PlayerTactB = "AmovPercMrunSnonWnonDb_GAIT";
            PlayerTactRB = "AmovPercMrunSnonWnonDbr_GAIT";
            PlayerTactR = "AmovPercMrunSnonWnonDr_GAIT";
            PlayerTactRF = "AmovPercMevaSnonWnonDfr_GAIT";
        };

    };
};

class CfgMovesMaleSdr: CfgMovesBasic
{
    class States
    {
        class AmovPercMevaSrasWrflDf;
        class AmovPercMevaSrasWrflDfl;
        class AmovPercMrunSrasWrflDl;
        class AmovPercMrunSrasWrflDbl;
        class AmovPercMrunSrasWrflDb;
        class AmovPercMrunSrasWrflDbr;
        class AmovPercMrunSrasWrflDr;
        class AmovPercMevaSrasWrflDfr;

        class AmovPercMevaSrasWrflDf_GAIT: AmovPercMevaSrasWrflDf
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSrasWrflDf";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMevaSrasWrflDfl_GAIT: AmovPercMevaSrasWrflDfl
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSrasWrflDfl";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMrunSrasWrflDl_GAIT: AmovPercMrunSrasWrflDl
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWrflDl";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMrunSrasWrflDbl_GAIT: AmovPercMrunSrasWrflDbl
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWrflDbl";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMrunSrasWrflDb_GAIT: AmovPercMrunSrasWrflDb
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWrflDb";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMrunSrasWrflDbr_GAIT: AmovPercMrunSrasWrflDbr
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWrflDbr";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMrunSrasWrflDr_GAIT: AmovPercMrunSrasWrflDr
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWrflDr";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMevaSrasWrflDfr_GAIT", 0.025,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMevaSrasWrflDfr_GAIT: AmovPercMevaSrasWrflDfr
        {
            actions = "GAIT_SlopeRifleRaisedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSrasWrflDfr";
            GAIT_slopeFamily = "SrasWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWrflDf_GAIT", 0.025,
                "AmovPercMevaSrasWrflDfl_GAIT", 0.025,
                "AmovPercMrunSrasWrflDl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbl_GAIT", 0.02,
                "AmovPercMrunSrasWrflDb_GAIT", 0.02,
                "AmovPercMrunSrasWrflDbr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDr_GAIT", 0.02,
                "AmovPercMrunSrasWrflDf", 0.02,
                "AmovPercMrunSrasWrflDfl", 0.02,
                "AmovPercMrunSrasWrflDl", 0.02,
                "AmovPercMrunSrasWrflDbl", 0.02,
                "AmovPercMrunSrasWrflDb", 0.02,
                "AmovPercMrunSrasWrflDbr", 0.02,
                "AmovPercMrunSrasWrflDr", 0.02,
                "AmovPercMrunSrasWrflDfr", 0.02,
                "AmovPercMwlkSrasWrflDf", 0.02,
                "AmovPercMwlkSrasWrflDfl", 0.02,
                "AmovPercMwlkSrasWrflDl", 0.02,
                "AmovPercMwlkSrasWrflDbl", 0.02,
                "AmovPercMwlkSrasWrflDb", 0.02,
                "AmovPercMwlkSrasWrflDbr", 0.02,
                "AmovPercMwlkSrasWrflDr", 0.02,
                "AmovPercMwlkSrasWrflDfr", 0.02,
                "AmovPercMstpSrasWrflDnon", 0.02,
                "AmovPercMevaSrasWrflDf", 0.025,
                "AmovPercMevaSrasWrflDfl", 0.025,
                "AmovPercMevaSrasWrflDfr", 0.025
            };
        };

        class AmovPercMevaSlowWrflDf;
        class AmovPercMevaSlowWrflDfl;
        class AmovPercMrunSlowWrflDl;
        class AmovPercMrunSlowWrflDbl;
        class AmovPercMrunSlowWrflDb;
        class AmovPercMrunSlowWrflDbr;
        class AmovPercMrunSlowWrflDr;
        class AmovPercMevaSlowWrflDfr;

        class AmovPercMevaSlowWrflDf_GAIT: AmovPercMevaSlowWrflDf
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSlowWrflDf";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMevaSlowWrflDfl_GAIT: AmovPercMevaSlowWrflDfl
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSlowWrflDfl";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMrunSlowWrflDl_GAIT: AmovPercMrunSlowWrflDl
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSlowWrflDl";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMrunSlowWrflDbl_GAIT: AmovPercMrunSlowWrflDbl
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSlowWrflDbl";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMrunSlowWrflDb_GAIT: AmovPercMrunSlowWrflDb
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSlowWrflDb";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMrunSlowWrflDbr_GAIT: AmovPercMrunSlowWrflDbr
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSlowWrflDbr";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMrunSlowWrflDr_GAIT: AmovPercMrunSlowWrflDr
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSlowWrflDr";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMevaSlowWrflDfr_GAIT", 0.025,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMevaSlowWrflDfr_GAIT: AmovPercMevaSlowWrflDfr
        {
            actions = "GAIT_SlopeRifleLoweredActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSlowWrflDfr";
            GAIT_slopeFamily = "SlowWrfl";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSlowWrflDf_GAIT", 0.025,
                "AmovPercMevaSlowWrflDfl_GAIT", 0.025,
                "AmovPercMrunSlowWrflDl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbl_GAIT", 0.02,
                "AmovPercMrunSlowWrflDb_GAIT", 0.02,
                "AmovPercMrunSlowWrflDbr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDr_GAIT", 0.02,
                "AmovPercMrunSlowWrflDf", 0.02,
                "AmovPercMrunSlowWrflDfl", 0.02,
                "AmovPercMrunSlowWrflDl", 0.02,
                "AmovPercMrunSlowWrflDbl", 0.02,
                "AmovPercMrunSlowWrflDb", 0.02,
                "AmovPercMrunSlowWrflDbr", 0.02,
                "AmovPercMrunSlowWrflDr", 0.02,
                "AmovPercMrunSlowWrflDfr", 0.02,
                "AmovPercMwlkSlowWrflDf", 0.02,
                "AmovPercMwlkSlowWrflDfl", 0.02,
                "AmovPercMwlkSlowWrflDl", 0.02,
                "AmovPercMwlkSlowWrflDbl", 0.02,
                "AmovPercMwlkSlowWrflDb", 0.02,
                "AmovPercMwlkSlowWrflDbr", 0.02,
                "AmovPercMwlkSlowWrflDr", 0.02,
                "AmovPercMwlkSlowWrflDfr", 0.02,
                "AmovPercMstpSlowWrflDnon", 0.02,
                "AmovPercMevaSlowWrflDf", 0.025,
                "AmovPercMevaSlowWrflDfl", 0.025,
                "AmovPercMevaSlowWrflDfr", 0.025,
                "AmovPercMwlkSlowWrflDf_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbl_ver2", 0.02,
                "AmovPercMwlkSlowWrflDb_ver2", 0.02,
                "AmovPercMwlkSlowWrflDbr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDr_ver2", 0.02,
                "AmovPercMwlkSlowWrflDfr_ver2", 0.02,
                "AmovPercMtacSlowWrflDf_ver2", 0.02,
                "AmovPercMtacSlowWrflDfl_ver2", 0.02,
                "AmovPercMtacSlowWrflDl_ver2", 0.02,
                "AmovPercMtacSlowWrflDbl_ver2", 0.02,
                "AmovPercMtacSlowWrflDb_ver2", 0.02,
                "AmovPercMtacSlowWrflDbr_ver2", 0.02,
                "AmovPercMtacSlowWrflDr_ver2", 0.02,
                "AmovPercMtacSlowWrflDfr_ver2", 0.02
            };
        };

        class AmovPercMevaSrasWpstDf;
        class AmovPercMevaSrasWpstDfl;
        class AmovPercMrunSrasWpstDl;
        class AmovPercMrunSrasWpstDbl;
        class AmovPercMrunSrasWpstDb;
        class AmovPercMrunSrasWpstDbr;
        class AmovPercMrunSrasWpstDr;
        class AmovPercMevaSrasWpstDfr;

        class AmovPercMevaSrasWpstDf_GAIT: AmovPercMevaSrasWpstDf
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSrasWpstDf";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMevaSrasWpstDfl_GAIT: AmovPercMevaSrasWpstDfl
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSrasWpstDfl";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMrunSrasWpstDl_GAIT: AmovPercMrunSrasWpstDl
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWpstDl";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMrunSrasWpstDbl_GAIT: AmovPercMrunSrasWpstDbl
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWpstDbl";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMrunSrasWpstDb_GAIT: AmovPercMrunSrasWpstDb
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWpstDb";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMrunSrasWpstDbr_GAIT: AmovPercMrunSrasWpstDbr
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWpstDbr";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMrunSrasWpstDr_GAIT: AmovPercMrunSrasWpstDr
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSrasWpstDr";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMevaSrasWpstDfr_GAIT", 0.025,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMevaSrasWpstDfr_GAIT: AmovPercMevaSrasWpstDfr
        {
            actions = "GAIT_SlopePistolActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSrasWpstDfr";
            GAIT_slopeFamily = "SrasWpst";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSrasWpstDf_GAIT", 0.025,
                "AmovPercMevaSrasWpstDfl_GAIT", 0.025,
                "AmovPercMrunSrasWpstDl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbl_GAIT", 0.02,
                "AmovPercMrunSrasWpstDb_GAIT", 0.02,
                "AmovPercMrunSrasWpstDbr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDr_GAIT", 0.02,
                "AmovPercMrunSrasWpstDf", 0.02,
                "AmovPercMrunSrasWpstDfl", 0.02,
                "AmovPercMrunSrasWpstDl", 0.02,
                "AmovPercMrunSrasWpstDbl", 0.02,
                "AmovPercMrunSrasWpstDb", 0.02,
                "AmovPercMrunSrasWpstDbr", 0.02,
                "AmovPercMrunSrasWpstDr", 0.02,
                "AmovPercMrunSrasWpstDfr", 0.02,
                "AmovPercMwlkSrasWpstDf", 0.02,
                "AmovPercMwlkSrasWpstDfl", 0.02,
                "AmovPercMwlkSrasWpstDl", 0.02,
                "AmovPercMwlkSrasWpstDbl", 0.02,
                "AmovPercMwlkSrasWpstDb", 0.02,
                "AmovPercMwlkSrasWpstDbr", 0.02,
                "AmovPercMwlkSrasWpstDr", 0.02,
                "AmovPercMwlkSrasWpstDfr", 0.02,
                "AmovPercMstpSrasWpstDnon", 0.02,
                "AmovPercMevaSrasWpstDf", 0.025,
                "AmovPercMevaSrasWpstDfl", 0.025,
                "AmovPercMevaSrasWpstDfr", 0.025
            };
        };

        class AmovPercMevaSnonWnonDf;
        class AmovPercMevaSnonWnonDfl;
        class AmovPercMrunSnonWnonDl;
        class AmovPercMrunSnonWnonDbl;
        class AmovPercMrunSnonWnonDb;
        class AmovPercMrunSnonWnonDbr;
        class AmovPercMrunSnonWnonDr;
        class AmovPercMevaSnonWnonDfr;

        class AmovPercMevaSnonWnonDf_GAIT: AmovPercMevaSnonWnonDf
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSnonWnonDf";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMevaSnonWnonDfl_GAIT: AmovPercMevaSnonWnonDfl
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSnonWnonDfl";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMrunSnonWnonDl_GAIT: AmovPercMrunSnonWnonDl
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSnonWnonDl";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMrunSnonWnonDbl_GAIT: AmovPercMrunSnonWnonDbl
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSnonWnonDbl";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMrunSnonWnonDb_GAIT: AmovPercMrunSnonWnonDb
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSnonWnonDb";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMrunSnonWnonDbr_GAIT: AmovPercMrunSnonWnonDbr
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSnonWnonDbr";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMrunSnonWnonDr_GAIT: AmovPercMrunSnonWnonDr
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMrunSnonWnonDr";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMevaSnonWnonDfr_GAIT", 0.025,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

        class AmovPercMevaSnonWnonDfr_GAIT: AmovPercMevaSnonWnonDfr
        {
            actions = "GAIT_SlopeUnarmedActions";
            GAIT_slopeState = 1;
            GAIT_nativeState = "AmovPercMevaSnonWnonDfr";
            GAIT_slopeFamily = "SnonWnon";
            // Direct native entry edges preserve the graph-based transition.
            InterpolateFrom[] +=
            {
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
            // Keep native exits, add custom direction changes, and provide
            // direct native release destinations for current input.
            InterpolateTo[] +=
            {
                "AmovPercMevaSnonWnonDf_GAIT", 0.025,
                "AmovPercMevaSnonWnonDfl_GAIT", 0.025,
                "AmovPercMrunSnonWnonDl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbl_GAIT", 0.02,
                "AmovPercMrunSnonWnonDb_GAIT", 0.02,
                "AmovPercMrunSnonWnonDbr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDr_GAIT", 0.02,
                "AmovPercMrunSnonWnonDf", 0.02,
                "AmovPercMrunSnonWnonDfl", 0.02,
                "AmovPercMrunSnonWnonDl", 0.02,
                "AmovPercMrunSnonWnonDbl", 0.02,
                "AmovPercMrunSnonWnonDb", 0.02,
                "AmovPercMrunSnonWnonDbr", 0.02,
                "AmovPercMrunSnonWnonDr", 0.02,
                "AmovPercMrunSnonWnonDfr", 0.02,
                "AmovPercMwlkSnonWnonDf", 0.02,
                "AmovPercMwlkSnonWnonDfl", 0.02,
                "AmovPercMwlkSnonWnonDl", 0.02,
                "AmovPercMwlkSnonWnonDbl", 0.02,
                "AmovPercMwlkSnonWnonDb", 0.02,
                "AmovPercMwlkSnonWnonDbr", 0.02,
                "AmovPercMwlkSnonWnonDr", 0.02,
                "AmovPercMwlkSnonWnonDfr", 0.02,
                "AmovPercMstpSnonWnonDnon", 0.02,
                "AmovPercMevaSnonWnonDf", 0.025,
                "AmovPercMevaSnonWnonDfl", 0.025,
                "AmovPercMevaSnonWnonDfr", 0.025
            };
        };

    };
};
