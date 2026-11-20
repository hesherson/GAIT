/* Load actual fn_traversalHelpers.sqf and fn_slopeLocomotion.sqf first.
   Exercise release/retap ordering and live movement priority using the same
   pure policies called by Draw3D. This does not simulate engine root motion. */
private _assert = {
    params ["_condition", "_label"];
    if (!_condition) then {throw format ["FAIL: %1", _label];};
};
// A pending stop can still yield to a fresh movement input.
private _stopTarget = "AmovPercMstpSrasWrflDnon";
{
    _x params ["_idle", "_source", "_releaseAge", "_suffix"];
    [([_idle, _source, _releaseAge] call GAIT_fnc_stopAnimationTarget) isEqualTo (_idle + _suffix),
        "stop selects the native rifle lift only when returning raised from sprint"] call _assert;
} forEach [
    ["AmovPercMstpSrasWrflDnon", "AmovPercMevaSrasWrflDfr_GAIT", 999, "_GAITSprintStop"],
    ["AmovPknlMstpSrasWrflDnon", "AmovPknlMevaSrasWrflDf", 999, "_GAITSprintStop"],
    ["AmovPercMstpSrasWrflDnon", "AmovPercMrunSrasWrflDf_GAIT", 0.04, "_GAITSprintStop"],
    ["AmovPercMstpSrasWrflDnon", "AmovPercMstpSrasWrflDnon_GAIT", 0.16, "_GAITSprintStop"],
    ["AmovPercMstpSrasWrflDnon", "AmovPercMrunSrasWrflDf_GAIT", 0.40, ""],
    ["AmovPercMstpSlowWrflDnon", "AmovPercMevaSlowWrflDf_GAIT", 0.04, ""]
];
{
    private _protected = [_x] call GAIT_fnc_preserveLocomotionGesture;
    [(["AmovPercMstpSrasWrflDnon", "AmovPercMevaSrasWrflDf_GAIT", 0, _protected] call
        GAIT_fnc_stopAnimationTarget) isEqualTo _stopTarget, "the stop leaves the rifle gesture in control"] call _assert;
} forEach ["NAVSPECWARGRU2_High_Ready_Position", "NAVSPECWARGRU2_ShoulderTap", "NAVSPECWARGRU2_ThighSqueeze_Hard"];
[!(["NAVSPECWARGRU2_UnrelatedGesture"] call GAIT_fnc_preserveLocomotionGesture), "unlisted gestures retain the normal handoff"] call _assert;
[player] call GAIT_fnc_clearLocomotionInputHistory;
player setVariable ["GAIT_slopeAttemptLatched", true];
[player, [1,0,true]] call GAIT_fnc_observeLocomotionInput;
[player, [0,0,false]] call GAIT_fnc_observeLocomotionInput;
private _stopAge = [player] call GAIT_fnc_stopReleaseAge;
[_stopAge >= 0 && {_stopAge < 0.20},
    "simultaneous Shift and W release records a stop even without a moving taper"] call _assert;
player setVariable ["GAIT_slopeAttemptLatched", false];
[player] call GAIT_fnc_clearLocomotionInputHistory;

private _sfgIdle = "AidlPercMstpSrasWrflDnon_G01_player";
private _sfgSprint = "AmovPercMevaSrasWrflDf_GAIT";
private _sfgBlend = _sfgIdle + "_" + _sfgSprint;
[!([_sfgBlend, _sfgIdle, _sfgSprint] call GAIT_fnc_isStandingLocomotionBlend), "the optional idle route is inactive without 10th SFG"] call _assert;
missionNamespace setVariable ["GAIT_nswg2AnimationsLoaded", true];
[[_sfgBlend, _sfgIdle, _sfgSprint] call GAIT_fnc_isStandingLocomotionBlend, "10th SFG idle can blend into a held sprint"] call _assert;
private _sfgPose = ["rifle", _sfgIdle, ["rifle", "SlowWrfl", "walk", false]] call GAIT_fnc_locomotionPoseSnapshot;
[(_sfgPose select 1) isEqualTo "SrasWrfl", "10th SFG idle records the raised rifle pose"] call _assert;
missionNamespace setVariable ["GAIT_nswg2AnimationsLoaded", false];

private _combat = ["SlowWrfl", "Dfl", false, "Perc", true];
[(_combat call GAIT_fnc_nativeOrdinaryMoveName) isEqualTo "AmovPercMtacSlowWrflDfl_ver2", "normal lowered combat uses the original variant"] call _assert;
missionNamespace setVariable ["GAIT_animateWalkLoaded", true];
[(_combat call GAIT_fnc_nativeOrdinaryMoveName) isEqualTo "AmovPercMtacSlowWrflDfl", "Animate lowered combat uses the same native clip as the action map"] call _assert;
missionNamespace setVariable ["GAIT_animateWalkLoaded", false];
[[true,true,true,true,true] call GAIT_fnc_nativeStopDecision,"fresh owned native jogging stop gets short blend"] call _assert;
for "_gate" from 0 to 4 do {
    private _gates = [true,true,true,true,true];
    _gates set [_gate,false];
    [!(_gates call GAIT_fnc_nativeStopDecision),"held stop, foreign pace, prior handoff, idle and unsafe contexts do not issue stop"] call _assert;
};
{
    _x params ["_lease","_now","_weapon","_coefficient","_expected"];
    [([_lease,_now,_weapon,_coefficient] call GAIT_fnc_nativeStopLeaseValid) isEqualTo _expected,"scheduled-to-render stop lease stays scoped to time, weapon and restored coefficient"] call _assert;
} forEach [
    [[10.15,"rifle",1],10.05,"rifle",1,true],
    [[10.15,"rifle",1],10.16,"rifle",1,false],
    [[10.15,"rifle",1],10.05,"pistol",1,false],
    [[10.15,"rifle",1],10.05,"rifle",0.8,false],
    [[],10.05,"rifle",1,false]
];
{
    _x params ["_target","_direction","_expected"];
    [([_target,_direction] call GAIT_fnc_locomotionStopRedirect) isEqualTo _expected,"exit redirect only on changed movement intent"] call _assert;
} forEach [
    [_stopTarget,"Dnon",false],[_stopTarget,"Df",true],[_stopTarget,"Dl",true],[_stopTarget,"Dr",true],
    ["AmovPercMrunSrasWrflDf","Df",false],["AmovPercMrunSrasWrflDf","Dnon",true],
    ["AmovPercMrunSrasWrflDl","Dr",true],["AmovPercMrunSrasWrflDr","Dr",false],["","Df",false]
];

// Exercise the live native fallback and input history with only the engine
// safety and final handoff mocked. Once native is selected, later keypresses
// belong to its action map, with no new body request from this controller.
private _originalAnimation = GAIT_fnc_readLocomotionAnimation;
private _originalFamily = GAIT_fnc_slopeWeaponFamily;
private _originalSafety = GAIT_fnc_nativeLocomotionHandoffSafe;
private _originalRelease = GAIT_fnc_requestMovingLocomotionRelease;
private _originalBeginDirection = GAIT_fnc_beginNativeReleaseDirection;
private _observed = "AmovPercMevaSrasWrflDf";
private _safe = true;
private _targets = [];
GAIT_fnc_modeAllowsMovement = {true};
GAIT_fnc_readLocomotionAnimation = {_observed};
GAIT_fnc_slopeWeaponFamily = {"SrasWrfl"};
GAIT_fnc_nativeLocomotionHandoffSafe = {_safe};
GAIT_fnc_beginNativeReleaseDirection = {
    params ["_unit"];
    [_unit] call GAIT_fnc_clearSlopeLocomotionState;
    _unit setVariable ["GAIT_nativeReleaseOwnsDirection", true];
};
GAIT_fnc_requestMovingLocomotionRelease = {
    params ["_unit", "_family", "_direction", "_walk"];
    _observed = [_family, _direction, _walk] call GAIT_fnc_nativeOrdinaryMoveName;
    _targets pushBack _observed;
    [_unit] call GAIT_fnc_beginNativeReleaseDirection;
    true
};
{
    _x params ["_input", "_walk", "_sprint", "_contextSafe", "_target", "_label", ["_phase", "native"], ["_alreadyBlending", false]];
    _observed = _sprint;
    _safe = _contextSafe;
    _targets = [];
    player setVariable ["GAIT_locomotionPhase", _phase];
    player setVariable ["GAIT_turboInputHeld", true];
    player setVariable ["GAIT_forwardInputHeld", true];
    [player, _input] call GAIT_fnc_observeLocomotionInput;
    private _issued = [player, _input, _walk] call GAIT_fnc_releaseNativeSprint;
    [(_issued isEqualTo (_alreadyBlending || {_target isNotEqualTo ""})) &&
        {_targets isEqualTo ([[], [_target]] select (_target isNotEqualTo ""))}, _label] call _assert;
    [player, [0.707,-0.707,false]] call GAIT_fnc_observeLocomotionInput;
    [!([player, [0.707,-0.707,false], _walk] call GAIT_fnc_releaseNativeSprint),
        "the next frame's diagonal belongs to native actions"] call _assert;
} forEach [
    [[1,0,false],true,"AmovPercMevaSrasWrflDf",true,"AmovPercMwlkSrasWrflDf","walk-selected W hands off to native walk"],
    [[1,0,false],false,"AmovPercMsprSrasWrflDf",true,"AmovPercMrunSrasWrflDf","native sprint uses a forward jog on Shift-up"],
    [[1,0,false],true,"AmovPercMsprSrasWrflDf",true,"AmovPercMwlkSrasWrflDf","a native sprint observed during GAIT entry is released immediately","entering"],
    [[1,0,false],false,"AmovPercMevaSrasWrflDf_AmovPercMrunSrasWrflDf",true,"","an existing native sprint-to-jog blend is allowed to finish","native",true],
    [[0,1,false],false,"AmovPercMevaSrasWrflDf_AmovPercMrunSrasWrflDf",true,"AmovPercMrunSrasWrflDr","a different live direction replaces the existing native target"],
    [[0,1,false],true,"AmovPercMevaSrasWrflDf",true,"AmovPercMwlkSrasWrflDr","pure lateral walk starts on release"],
    [[0,1,false],false,"AmovPercMevaSrasWrflDf",true,"AmovPercMrunSrasWrflDr","pure lateral jog starts on release"],
    [[1,0,false],false,"AmovPercMevaSrasWrflDf",false,"","unsafe medical or gesture context keeps its animation"],
    [[1,0,false],false,"AmovPercMevaSrasWrflDf_AmovPknlMrunSrasWrflDf",true,"","stance transitions cannot be overwritten"]
];
GAIT_fnc_readLocomotionAnimation = _originalAnimation;
GAIT_fnc_slopeWeaponFamily = _originalFamily;
GAIT_fnc_nativeLocomotionHandoffSafe = _originalSafety;
GAIT_fnc_requestMovingLocomotionRelease = _originalRelease;
GAIT_fnc_beginNativeReleaseDirection = _originalBeginDirection;
// The native source may still be visible before Arma exposes the blend.
player setVariable ["GAIT_slopeExitSource", "AmovPercMevaSrasWrflDf"];
player setVariable ["GAIT_slopeExitIssued", true];
player setVariable ["GAIT_slopeExitDeadline", diag_tickTime + 1.5];
[[player, "amovpercmevasraswrfldf"] call GAIT_fnc_isPendingLocomotionExitSource,
    "a pending release keeps its native source until interpolation starts"] call _assert;
[!([player, "amovpercmrunsraswrfldf"] call GAIT_fnc_isPendingLocomotionExitSource),
    "the native jog destination ends ownership"] call _assert;
player setVariable ["GAIT_slopeExitDeadline", diag_tickTime - 1];
[!([player, "amovpercmevasraswrfldf"] call GAIT_fnc_isPendingLocomotionExitSource),
    "an ignored native release expires"] call _assert;
[player] call GAIT_fnc_clearSlopeLocomotionState;
{
    [_x call GAIT_fnc_ownsNativeReleaseDirection, "side, backward and forward input stay native for this movement segment"] call _assert;
} forEach [[true,[0,-1,false]], [true,[-1,0,false]], [true,[1,0,false]]];
[!([true,[0,0,false]] call GAIT_fnc_ownsNativeReleaseDirection), "a stop ends native direction ownership"] call _assert;
[!([true,[1,0,true]] call GAIT_fnc_ownsNativeReleaseDirection), "a new sprint can take ownership again"] call _assert;
[!([false,[1,0,false]] call GAIT_fnc_ownsNativeReleaseDirection), "ordinary slope jog can still acquire without a prior sprint release"] call _assert;
// W+D sprint release enters the jog map. W+A, W-only and pure D stay
// in that map regardless of how long the player has been jogging.
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_sprintReleaseJogIntent) isEqualTo _expected, _label] call _assert;
} forEach [
    [[true,true,false,false,"release"],true,"sprint release enters the directional jog map"],
    [[true,true,false,true,""],true,"a new direction keeps the jog map after the blend"],
    [[true,true,false,false,""],false,"ordinary jog does not acquire sprint release ownership"],
    [[true,true,true,true,"sprint"],false,"a sprint retap immediately ends the jog handoff"],
    [[true,false,false,true,""],false,"releasing all movement input ends the jog handoff"],
    [[false,true,false,true,""],false,"walk selection or a movement lock ends the jog handoff"]
];
private _sprintRight = "AmovPercMevaSrasWrflDfr_GAIT";
private _jogRight = "AmovPercMrunSrasWrflDfr_GAIT";
private _jogLeft = "AmovPercMrunSrasWrflDfl_GAIT";
private _releaseBlend = _sprintRight + "_" + _jogRight;
private _turnBlend = _jogRight + "_" + _jogLeft;
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_releaseJogRedirectNeeded) isEqualTo _expected, _label] call _assert;
} forEach [
    [[_releaseBlend,_sprintRight,_jogRight,true,_jogLeft],true,"W+A redirects the sprint-to-W+D blend"],
    [[_jogRight,_sprintRight,_jogRight,false,_jogLeft],true,"W+A redirects the established jog after the entry deadline"],
    [[_jogRight,_jogRight,_jogLeft,true,_jogRight],true,"W+D cancels a pending W+A turn before the blend appears"],
    [[_turnBlend,_jogRight,_jogLeft,true,_jogRight],true,"W+D redirects the in-flight W+A turn"],
    [[_turnBlend,_jogRight,_jogLeft,true,_jogLeft],false,"an observed blend already aimed at W+A continues"],
    [[_jogRight,_jogRight,_jogLeft,false,_jogRight],false,"an expired W+A request does not restart a matching W+D jog"]
];
private _crouchRight = ["SrasWrfl","Dfr",true,"Pknl"] call GAIT_fnc_slopeStateName;
[ (["STAND", "CROUCH"] call GAIT_fnc_crouchInputTarget) isEqualTo "CROUCH" &&
    {(["CROUCH", "STAND"] call GAIT_fnc_crouchInputTarget) isEqualTo "STAND"} &&
    {(["PRONE", "STAND"] call GAIT_fnc_crouchInputTarget) isEqualTo ""},
    "MoveUp remains directed at the pre-input target after Arma begins the transition"] call _assert;
{
    _x params ["_animation", "_fallback", "_expected"];
    [([_animation, _fallback] call GAIT_fnc_movingStanceRifleFamily) isEqualTo _expected,
        "moving crouch preserves the current or explicitly transitioning rifle pose"] call _assert;
} forEach [
    ["AmovPercMrunSlowWrflDf_GAIT", "SrasWrfl", "SlowWrfl"],
    ["AmovPercMtacSrasWrflDf_GAIT", "SlowWrfl", "SrasWrfl"],
    ["AmovPercMrunSlowWrflDf_AmovPercMrunSrasWrflDf", "SlowWrfl", "SrasWrfl"],
    ["AmovPercMevaSrasWrflDf_GAIT", "SlowWrfl", "SlowWrfl"]
];
[([ "mtac", false, "jog"] call GAIT_fnc_movingStanceMode) isEqualTo "combat" &&
    {([ "mrun", false, "combat"] call GAIT_fnc_movingStanceMode) isEqualTo "combat"} &&
    {([ "mwlk", false, "jog"] call GAIT_fnc_movingStanceMode) isEqualTo "walk"},
    "the selected gait survives crouch even through an interim jog"] call _assert;
{
    _x params ["_animation", "_direction", "_expected"];
    [([_animation, _direction] call GAIT_fnc_movingAimTarget) isEqualTo _expected, "moving optics preserve stance and direction"] call _assert;
} forEach [
    ["AmovPercMwlkSlowWrflDf_ver2", "Dfr", "AmovPercMwlkSrasWrflDfr"],
    ["AmovPknlMwlkSlowWpstDfl_GAIT", "Dl", "AmovPknlMwlkSrasWpstDl"],
    ["AmovPercMwlkSrasWrflDf_GAIT", "Df", "AmovPercMwlkSrasWrflDf"],
    ["AmovPercMrunSlowWrflDf_GAIT", "Dfr", "AmovPercMtacSrasWrflDfr"],
    ["AmovPknlMrunSrasWpstDfl", "Dl", "AmovPknlMtacSrasWpstDl"],
    ["AmovPercMtacSlowWrflDf_ver2", "Dfl", "AmovPercMtacSrasWrflDfl"],
    ["AmovPercMwlkSlowWlnrDf", "Df", "AmovPercMwlkSrasWlnrDf"],
    ["AmovPercMevaSlowWrflDf_GAIT", "Df", ""]
];
{
    _x params ["_state","_direction","_expected"];
    [([_state,_direction,true] call GAIT_fnc_movingAimTarget) isEqualTo _expected,"release to native fire-ready pose"] call _assert;
} forEach [
    ["AmovPercMevaSlowWrflDf_GAIT","Dfr","AmovPercMtacSrasWrflDfr"],
    ["AmovPknlMrunSrasWpstDf_GAIT","Dnon","AmovPknlMstpSrasWpstDnon"],
    ["AmovPercMstpSrasWrflDnon_GAITSprintStop","Dnon","AmovPercMstpSrasWrflDnon"],
    ["AmovPercMstpSnonWnonDnon","Dnon",""]
];
private _crouchJog = ["SrasWrfl","Dfr","Pknl","jog"] call GAIT_fnc_sprintReturnClip;
private _crouchWalk = ["SrasWrfl","Dfl",false,"Pknl",true] call GAIT_fnc_slopeStateName;
[_crouchRight isEqualTo "AmovPknlMevaSrasWrflDfr_GAIT", "crouched W+D uses the native crouch sprint"] call _assert;
[_crouchJog isEqualTo "AmovPknlMrunSrasWrflDfr_GAIT", "crouched release uses the standard jog pose"] call _assert;
[_crouchWalk isEqualTo "AmovPknlMwlkSrasWrflDfl_GAIT", "settled release walks crouched in the live direction"] call _assert;
private _crouchBlend = _crouchRight + "_" + _crouchJog;
[[ _crouchBlend, _crouchRight, _crouchJog] call GAIT_fnc_isStandingLocomotionBlend,
    "a same-stance crouch sprint release blend retains movement eligibility"] call _assert;
[!([_sprintRight + "_" + _crouchJog, _sprintRight, _crouchJog] call GAIT_fnc_isStandingLocomotionBlend),
    "a standing-to-crouch transition stays with native stance control"] call _assert;
[[ _crouchJog, _crouchRight, _crouchJog, false, _crouchWalk] call GAIT_fnc_releaseJogRedirectNeeded,
    "the live crouched diagonal can take the walk destination after the taper"] call _assert;
private _lowered = ["rifle", "AmovPercMwlkSlowWrflDf_ver2", [], true] call GAIT_fnc_locomotionPoseSnapshot;
[_lowered isEqualTo ["rifle","SlowWrfl","walk",true], "capture lowered walk before sprint"] call _assert;
[([ "rifle", "AmovPercMevaSrasWrflDf_GAIT", _lowered] call GAIT_fnc_locomotionPoseSnapshot) isEqualTo _lowered,
    "even a raised-looking sprint does not overwrite the lowered walk"] call _assert;
[([ "pistol", "AmovPercMevaSrasWpstDf_GAIT", _lowered] call GAIT_fnc_locomotionPoseSnapshot) isEqualTo [],
    "a different weapon drops the previous pose"] call _assert;
{
    _x params ["_args", "_expected"];
    [(_args call GAIT_fnc_sprintReturnMode) isEqualTo _expected, "native intent restores " + _expected] call _assert;
} forEach [
    [[true,"Toggle","jog","SlowWrfl"],"walk"],
    [[false,"Toggle","jog","SrasWrfl"],"combat"],
    [[false,"None","combat","SrasWrfl"],"jog"],
    [[false,"","combat","SlowWrfl"],"combat"],
    [[false,"None","walk","SlowWrfl",false],"walk"],
    [[false,"None","walk","SlowWrfl",true],"jog"],
    [[false,"Toggle","jog","SnonWnon"],"walk"]
];
[([ "SlowWrfl","Dr","Perc","combat"] call GAIT_fnc_sprintReturnClip) isEqualTo "AmovPercMtacSlowWrflDr_GAIT",
    "combat return respects lowered posture and freshly pressed D"] call _assert;
// This pure policy handles Turbo intent irrespective of the speed ramp.
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_locomotionIntent) isEqualTo _expected, _label] call _assert;
} forEach [
    [[true,false,true],false,"Turbo release clears direct sprint intent while W remains held"],
    [[true,true,false],false,"no movement key means no sprint animation"],
    [[true,true,true],true,"raw Turbo accepts forward and lateral movement"],
    [[false,true,true],false,"context gate still prevents entry"]
];
// With both keys up, or W released during a pending jog, a stop replaces
// the moving clip immediately. A live A/D direction still gets a blend.
private _originalMove = GAIT_fnc_requestLocomotionMove;
private _originalStop = GAIT_fnc_switchToLocomotionIdle;
private _exitRequests = [];
GAIT_fnc_releaseSpeedCoefficient = {_exitRequests pushBack "coefficient released";};
GAIT_fnc_requestLocomotionMove = {_exitRequests pushBack ["blend", _this select 1];};
GAIT_fnc_switchToLocomotionIdle = {
    params ["_unit", "_target"];
    _exitRequests pushBack ["idle", _target, _unit getVariable ["GAIT_locomotionPhase", ""],
        _unit getVariable ["GAIT_slopeExitPending", true]];
};
private _lateralJog = "AmovPercMrunSrasWrflDr";
player setVariable ["GAIT_locomotionPhase", "exiting"];
player setVariable ["GAIT_slopeExitPending", true];
[player, _lateralJog] call GAIT_fnc_requestLocomotionMove;
[player, _stopTarget] call GAIT_fnc_requestLocomotionStop;
[_exitRequests isEqualTo [["blend", _lateralJog], "coefficient released", ["idle", _stopTarget, "native", false]],
    "a full stop releases pace and the pending exit before switching to native idle"] call _assert;
GAIT_fnc_requestLocomotionMove = _originalMove;
GAIT_fnc_switchToLocomotionIdle = _originalStop;
{
    _x params ["_args", "_expected", "_label"];
    [(_args call GAIT_fnc_locomotionResumeDecision) isEqualTo _expected, _label] call _assert;
} forEach [
    [["exiting",true,true,true,true,true],true,"fresh Turbo edge reverses known safe exit"],
    [["entering",true,true,true,true,true],false,"pending entry is never replayed"],
    [["active",true,true,true,true,true],false,"active clip is never restarted"],
    [["exiting",false,true,true,true,true],false,"held Turbo is not a reassertion loop"],
    [["exiting",true,false,true,true,true],false,"unissued safety deferral cannot be overtaken"],
    [["exiting",true,true,false,true,true],false,"missing live direction or context prevents resume"],
    [["exiting",true,true,true,false,true],false,"medical and stance handoffs retain priority"],
    [["exiting",true,true,true,true,false],false,"unrelated native animation is never overwritten"]
];
// One release edge, one reverse edge, then held input cannot send a second
// request because the live helper latches phase=entering before its command.
private _phase = "exiting";
private _resumes = 0;
{
    private _resume = [_phase,_x,true,true,true,true] call GAIT_fnc_locomotionResumeDecision;
    if (_resume) then {_resumes = _resumes + 1; _phase = "entering";};
} forEach [true,false,false,true];
[_resumes isEqualTo 1,"one interrupted-exit request cannot turn into animation restarting"] call _assert;
{
    _x params ["_args","_expected","_label"];
    [(_args call GAIT_fnc_locomotionExitOwnsObservation) isEqualTo _expected,_label] call _assert;
} forEach [
    [[true,false,false,false,false],true,"observed custom state always needs native exit"],
    [[false,true,true,false,false],true,"known slow entry blend keeps cleanup ownership"],
    [[false,false,true,true,true],true,"release before entry appears cancels pending command"],
    [[false,false,true,true,false],false,"expired unseen entry cannot retain native body"],
    [[false,false,true,false,true],false,"medical/native takeover clears pending entry"],
    [[false,false,false,true,true],false,"issued exit observed at source completes cleanup"]
];
// Exercise the real render dispatcher with exit service deliberately deferred.
// A new fresh sprint submission cannot reach entry handling while cleanup
// owns an unobserved entry. Read-only input observation must still record W
// and Turbo edges during that safe deferral.
private _actualExitService = GAIT_fnc_serviceLocomotionExit;
private _actualInput = GAIT_fnc_getMovementInput;
private _actualStanceInput = GAIT_fnc_getStanceInput;
private _actualAnimation = GAIT_fnc_readLocomotionAnimation;
private _actualStance = GAIT_fnc_readLocomotionStance;
private _actualForcedWalk = GAIT_fnc_readLocomotionForcedWalk;
private _actualWalkToggle = GAIT_fnc_readLocomotionWalkToggle;
private _actualSprintAllowed = GAIT_fnc_readLocomotionSprintAllowed;
private _actualNativeWalkRequested = missionNamespace getVariable ["GAIT_fnc_nativeWalkRequested", {false}];
private _actualDecision = GAIT_fnc_locomotionDecision;
private _actualInputSuspended = GAIT_fnc_locomotionInputSuspended;
private _uiOpen = false;
GAIT_fnc_locomotionInputSuspended = {_uiOpen};
private _exitCalls = 0;
GAIT_fnc_serviceLocomotionExit = {_exitCalls = _exitCalls + 1; false};
GAIT_fnc_getMovementInput = {[0,0,false]};
GAIT_fnc_getStanceInput = {false};
GAIT_fnc_readAimInput = {false};
GAIT_fnc_readFireInput = {false};
GAIT_fnc_readLocomotionAnimation = {"AmovPercMrunSrasWrflDf_GAIT"};
GAIT_fnc_readLocomotionStance = {"STAND"};
GAIT_fnc_readLocomotionForcedWalk = {false};
GAIT_fnc_readLocomotionWalkToggle = {false};
GAIT_fnc_readLocomotionSprintAllowed = {true};
GAIT_fnc_nativeWalkRequested = {false};
GAIT_fnc_locomotionDecision = {throw "Deferred exit was overtaken by movement/entry handling";};
missionNamespace setVariable ["GAIT_slopeOwner",player];
missionNamespace setVariable ["GAIT_locomotionRequest",[player,true,false,diag_tickTime]];
player setVariable ["GAIT_locomotionPhase","exiting"];
player setVariable ["GAIT_forwardInputHeld",true];
private _releaseSerial = player getVariable ["GAIT_forwardReleaseSerial",0];
[] call GAIT_fnc_tickLocomotion;
[] call GAIT_fnc_tickLocomotion;
[_exitCalls isEqualTo 2,"render dispatcher services each deferred exit frame"] call _assert;
[(player getVariable ["GAIT_locomotionPhase",""]) isEqualTo "exiting","native source cannot discard deferred entry cancellation"] call _assert;
[(player getVariable ["GAIT_forwardReleaseSerial",0]) isEqualTo (_releaseSerial+1),"deferred cleanup still observes W release exactly once"] call _assert;

// An interrupted handoff must never issue a stop from a dialog's empty
// input. After close, the first real movement press is visible again.
private _bodyReleases = 0;
private _inputReads = 0;
GAIT_fnc_releaseNativeMovement = {_bodyReleases = _bodyReleases + 1;};
GAIT_fnc_getMovementInput = {_inputReads = _inputReads + 1; [1,0,true]};
player setVariable ["GAIT_slopeExitIssued", true];
player setVariable ["GAIT_movementInputHeld", true];
_uiOpen = true;
[] call GAIT_fnc_tickLocomotion;
[] call GAIT_fnc_tickLocomotion;
[_bodyReleases isEqualTo 1 && {_inputReads isEqualTo 0} && {_exitCalls isEqualTo 2},
    "UI focus yields once before sampling movement or servicing the exit"] call _assert;
[!(player getVariable ["GAIT_movementReleasedThisFrame", true]),
    "opening a dialog does not synthesize a stop edge"] call _assert;
_uiOpen = false;
[] call GAIT_fnc_tickLocomotion;
[_inputReads isEqualTo 1 && {player getVariable ["GAIT_forwardInputHeld", false]} &&
    {missionNamespace getVariable ["GAIT_locomotionRequest", [1]] isEqualTo []} &&
    {(player getVariable ["GAIT_locomotionPhase", ""]) isEqualTo "native"},
    "closing the dialog discards the stale handoff and samples fresh movement"] call _assert;

private _actualWindDownYield = GAIT_fnc_yieldWindDownAnimation;
private _actualBeginStanceYield = GAIT_fnc_beginStanceYield;
private _actionHandoffs = [];
private _readSlotInput = false;
private _readStanceInput = true;
GAIT_fnc_readWeaponSwitching = {false};
GAIT_fnc_getWeaponSlotInput = {_readSlotInput};
GAIT_fnc_getStanceInput = {_readStanceInput};
GAIT_fnc_crouchToggleHeld = {true};
GAIT_fnc_getMovementInput = {[1,0,false]};
GAIT_fnc_yieldWindDownAnimation = {
    params ["_unit", "_input", "_nativeWalk", ["_crouchStance", ""]];
    private _crouchToggle = _crouchStance isNotEqualTo "";
    _actionHandoffs pushBack (["native body", "native crouch destination"] select _crouchToggle);
    ["AmovPercMrunSrasWrflDf", "AmovPknlMrunSrasWrflDf"] select _crouchToggle
};
GAIT_fnc_beginStanceYield = {
    params ["_unit"];
    _actionHandoffs pushBack "native stance";
    _unit setVariable ["GAIT_stanceYieldStarted", diag_tickTime];
};
player setVariable ["GAIT_sprintReleaseJog", true];
player setVariable ["GAIT_stanceInputHeld", false];
[] call GAIT_fnc_tickLocomotion;
[_actionHandoffs isEqualTo ["native crouch destination", "native stance"] &&
    {player getVariable ["GAIT_nativeReleaseOwnsDirection", false]},
    "crouch takes the native action map before GAIT can redirect a moving release"] call _assert;

[player] call GAIT_fnc_clearLocomotionInputHistory;
player setVariable ["GAIT_sprintReleaseJog", true];
_readSlotInput = true;
_readStanceInput = false;
[] call GAIT_fnc_tickLocomotion;
[] call GAIT_fnc_tickLocomotion;
[_actionHandoffs isEqualTo ["native crouch destination", "native stance", "native body"] &&
    {[player] call GAIT_fnc_weaponYieldActive} &&
    {!(player getVariable ["GAIT_sprintReleaseJog", true])},
    "a weapon key takes the native body once and stops release redirects"] call _assert;

private _stanceRedirect = [];
GAIT_fnc_readLocomotionStance = {"CROUCH"};
GAIT_fnc_yieldWindDownAnimation = {
    params ["_unit", "_input", "_nativeWalk", "_pose"];
    _stanceRedirect = [_input, _pose];
    "AmovPknlMrunSrasWrflDr"
};
private _now = diag_tickTime;
private _persistingTaper = [_now, 4, 1, 0.3, true];
player setVariable ["GAIT_sprintReleasePace", _persistingTaper];
player setVariable ["GAIT_movementInputHeld", true];
player setVariable ["GAIT_directionChangedThisFrame", true];
private _redirectedCrouch = [player, [0, 1, false], false, false, _now] call GAIT_fnc_continueMovingStance;
[_redirectedCrouch && {_stanceRedirect isEqualTo [[0, 1, false], "CROUCH"]} &&
    {(player getVariable ["GAIT_sprintReleasePace", []]) isEqualTo _persistingTaper},
    "the first strafe edge switches the crouched stride without restarting wind-down"] call _assert;
player setVariable ["GAIT_movementInputHeld", false];
[!([player, [0, 0, false], false, false, _now] call GAIT_fnc_continueMovingStance),
    "a crouch redirect cannot hold a direction after all movement keys are released"] call _assert;

GAIT_fnc_yieldWindDownAnimation = _actualWindDownYield;
GAIT_fnc_beginStanceYield = _actualBeginStanceYield;

GAIT_fnc_serviceLocomotionExit = _actualExitService;
GAIT_fnc_locomotionInputSuspended = _actualInputSuspended;
GAIT_fnc_getMovementInput = _actualInput;
GAIT_fnc_getStanceInput = _actualStanceInput;
GAIT_fnc_readLocomotionAnimation = _actualAnimation;
GAIT_fnc_readLocomotionStance = _actualStance;
GAIT_fnc_readLocomotionForcedWalk = _actualForcedWalk;
GAIT_fnc_readLocomotionWalkToggle = _actualWalkToggle;
GAIT_fnc_readLocomotionSprintAllowed = _actualSprintAllowed;
GAIT_fnc_nativeWalkRequested = _actualNativeWalkRequested;
GAIT_fnc_locomotionDecision = _actualDecision;
[player] call GAIT_fnc_clearSlopeLocomotionState;
missionNamespace setVariable ["GAIT_locomotionRequest",[]];
diag_log "GAIT TEST PASS: prompt graph release/re-tap reversal; immediate stop/strafe priority; bounded pending-entry cancellation";
