#define GAIT_RUN_ARMS \
"Spine3",1,"Neck",1, \
"LeftShoulder",1,"LeftArm",1,"LeftArmRoll",1,"LeftForeArm",1,"LeftForeArmRoll",1,"LeftHand",1, \
"LeftHandRing",1,"LeftHandRing1",1,"LeftHandRing2",1,"LeftHandRing3",1, \
"LeftHandPinky1",1,"LeftHandPinky2",1,"LeftHandPinky3",1, \
"LeftHandMiddle1",1,"LeftHandMiddle2",1,"LeftHandMiddle3",1, \
"LeftHandIndex1",1,"LeftHandIndex2",1,"LeftHandIndex3",1, \
"LeftHandThumb1",1,"LeftHandThumb2",1,"LeftHandThumb3",1, \
"RightShoulder",1,"RightArm",1,"RightArmRoll",1,"RightForeArm",1,"RightForeArmRoll",1,"RightHand",1, \
"RightHandRing",1,"RightHandRing1",1,"RightHandRing2",1,"RightHandRing3",1, \
"RightHandPinky1",1,"RightHandPinky2",1,"RightHandPinky3",1, \
"RightHandMiddle1",1,"RightHandMiddle2",1,"RightHandMiddle3",1, \
"RightHandIndex1",1,"RightHandIndex2",1,"RightHandIndex3",1, \
"RightHandThumb1",1,"RightHandThumb2",1,"RightHandThumb3",1
class CfgGesturesMale
{
    class Default;
    class BlendAnims
    {
        // Weapon is parented to Spine1. Both arms descend through Spine2.
        // Supply the same chest transform that was used to place the proxy.
        GAIT_RifleRunArm[] = {"Spine2",1,GAIT_RUN_ARMS,"weapon",1};
        GAIT_PistolRunArm[] = {GAIT_RUN_ARMS};
        GAIT_LauncherRunArm[] = {GAIT_RUN_ARMS,"launcher",1};
        GAIT_NormalBraceMask[] = {"Spine1",0.68,"Neck",0.72};
        GAIT_ShuffleLegs[] = {"Pelvis",1,"LeftUpLeg",1,"LeftUpLegRoll",1,"LeftLeg",1,"LeftLegRoll",1,"LeftFoot",1,"LeftToeBase",1,
            "RightUpLeg",1,"RightUpLegRoll",1,"RightLeg",1,"RightLegRoll",1,"RightFoot",1,"RightToeBase",1};
    };
    class States
    {
        class GAIT_NormalBrace: Default
        {
            file = "\gait\data\normal_brace.rtm";
            mask = "GAIT_NormalBraceMask";
            speed = -0.36;
            looped = 0;
            interpolationSpeed = 14;
            disableWeapons = 0;
            enableOptics = 1;
        };
        class GAIT_RifleRunSprint: Default
        {
            file = "\gait\data\rifle_run_standard_travel.rtm";
            mask = "GAIT_RifleRunArm";
            speed = 1.60971;
            looped = 1;
            interpolationSpeed = 3.8;
            disableWeapons = 0;
            enableOptics = 1;
            leftHandIKCurve[] = {0};
            // The weapon supplies the final trigger-hand socket. The authored
            // arm sets the carry and elbow; the native solver seats the palm.
            rightHandIKCurve[] = {1};
        };
        class GAIT_PistolRunSprint: GAIT_RifleRunSprint
        {
            file = "\gait\data\pistol_run_travel.rtm";
            mask = "GAIT_PistolRunArm";
            rightHandIKCurve[] = {1};
        };
        class GAIT_LauncherRunSprint: GAIT_RifleRunSprint
        {
            file = "\gait\data\launcher_run_travel.rtm";
            mask = "GAIT_LauncherRunArm";
            rightHandIKCurve[] = {1};
            leftHandIKCurve[] = {1};
        };
        class GAIT_RifleLower: GAIT_RifleRunSprint
        {
            file = "\gait\data\rifle_run_standard_lower.rtm";
            looped = 0;
        };
        class GAIT_RifleCatch: GAIT_RifleRunSprint
        {
            file = "\gait\data\rifle_run_standard_catch_travel.rtm";
            looped = 0;
            speed = -0.38;
            interpolationSpeed = 11;
            leftHandIKCurve[] = {0,0,0.35,0,0.82,1,1,1};
            rightHandIKCurve[] = {1};
        };
        class GAIT_RifleGather: GAIT_RifleCatch
        {
            speed = -0.72;
            interpolationSpeed = 8;
            leftHandIKCurve[] = {0,0,0.42,0,0.80,1,1,1};
        };
        class GAIT_ShuffleLeft: Default
        {
            file = "\gait\data\downhill_shuffle_left.rtm";
            mask = "GAIT_ShuffleLegs";
            speed = 1;
            looped = 1;
            interpolationSpeed = 7;
            disableWeapons = 0;
            enableOptics = 1;
        };
        class GAIT_ShuffleRight: GAIT_ShuffleLeft {file = "\gait\data\downhill_shuffle_right.rtm";};
        class GAIT_ShuffleLeftMedium: GAIT_ShuffleLeft {file = "\gait\data\downhill_shuffle_left_medium.rtm";};
        class GAIT_ShuffleRightMedium: GAIT_ShuffleLeft {file = "\gait\data\downhill_shuffle_right_medium.rtm";};
        class GAIT_ShuffleLeftSteep: GAIT_ShuffleLeft {file = "\gait\data\downhill_shuffle_left_steep.rtm";};
        class GAIT_ShuffleRightSteep: GAIT_ShuffleLeft {file = "\gait\data\downhill_shuffle_right_steep.rtm";};
        #include "rifle_run_states.hpp"
        // A finite, zero-weight handoff yields the gesture slot after blending.
        // Vanilla GestureEmpty inherits disableWeapons and can stay active.
        class GestureEmpty;
        class GAIT_EndSprintGesture: GestureEmpty
        {
            mask = "empty";
            speed = -0.08;
            looped = 0;
            disableWeapons = 0;
            enableOptics = 1;
        };
    };
};

#undef GAIT_RUN_ARMS
