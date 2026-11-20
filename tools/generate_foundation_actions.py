"""Generate GAIT's opt-in action family without rewriting native move classes.

Run without arguments from the source package to update its graph.  --check
checks for generator drift without writing.  --output selects another target.
"""

from argparse import ArgumentParser
from pathlib import Path


DEFAULT_OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "addons/gait/slope_actions.hpp"
)
FAMILIES = (
    ("SrasWrfl", "GAIT_SlopeRifleRaisedActions", "GAIT_SlopeRifleRaisedJogActions", "GAIT_SlopeRifleRaisedSprintActions", "RifleStandActions"),
    ("SlowWrfl", "GAIT_SlopeRifleLoweredActions", "GAIT_SlopeRifleLoweredJogActions", "GAIT_SlopeRifleLoweredSprintActions", "RifleLowStandActions"),
    ("SrasWpst", "GAIT_SlopePistolActions", "GAIT_SlopePistolJogActions", "GAIT_SlopePistolSprintActions", "PistolStandActions"),
    ("SlowWpst", "GAIT_SlopePistolLowActions", "GAIT_SlopePistolLowJogActions", "GAIT_SlopePistolLowSprintActions", "PistolLowStandActions"),
    ("SnonWnon", "GAIT_SlopeUnarmedActions", "GAIT_SlopeUnarmedJogActions", "GAIT_SlopeUnarmedSprintActions", "CivilStandActions"),
    ("SrasWlnr", "GAIT_SlopeLauncherActions", "GAIT_SlopeLauncherJogActions", "GAIT_SlopeLauncherSprintActions", "LauncherStandActions"),
)
CROUCH_ACTIONS = (
    "RifleKneelActions", "RifleKneelLowActions", "PistolKneelActions",
    "PistolLowKneelActions", "CivilKneelActions", "LauncherKneelActions",
)
OTHER_WEAPON_POSE = {
    "SrasWrfl": "SlowWrfl", "SlowWrfl": "SrasWrfl",
    "SrasWpst": "SlowWpst", "SlowWpst": "SrasWpst",
}
AIMING_WALK_FAMILIES = {
    "SrasWrfl": "SrasWrfl", "SlowWrfl": "SrasWrfl",
    "SrasWpst": "SrasWpst", "SlowWpst": "SrasWpst",
    "SrasWlnr": "SrasWlnr",
}
DIRECTIONS = ("Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr")
SELECTORS = ("F", "LF", "L", "LB", "B", "RB", "R", "RF")
FORWARD = {"Df", "Dfl", "Dfr"}
FORWARD_SPRINT_DIRECTIONS = ("Df", "Dfl", "Dfr")
PACES = (
    "Walk", "PlayerWalk", "Slow", "PlayerSlow",
    "Fast", "PlayerFast", "Tact", "PlayerTact",
)
IDLE_SELECTORS = (
    "Default", "Stop", "StopRelaxed", "TurnL", "TurnR",
    "TurnLRelaxed", "TurnRRelaxed",
)


# Root travel in metres per cycle from the native Arma 3 BMTR headers.
# Each row follows DIRECTIONS (forward sprint uses FORWARD_SPRINT_DIRECTIONS).
# A clip name alongside the distance identifies an RTM shared by native states.
ROOT_TRAVEL = {
    ("Perc", "SrasWrfl", "Mrun"): (
        5.7437,
        5.5357,
        3.8696,
        3.4569,
        3.4569,
        3.4569,
        3.6793,
        5.5357,
    ),
    ("Perc", "SrasWrfl", "Mwlk"): (
        1.6245,
        1.6235,
        2.684,
        2.1952,
        2.1952,
        2.1952,
        3.0454,
        1.6248,
    ),
    ("Perc", "SrasWrfl", "Meva"): (
        (3.1387, "amovpercmsprslowwrfldf.rtm"),
        (3.1387, "amovpercmsprslowwrfldfl.rtm"),
        (3.1387, "amovpercmsprslowwrfldfr.rtm"),
    ),
    ("Perc", "SlowWrfl", "Mrun"): (
        5.2529,
        5.2529,
        3.8696,
        3.4569,
        3.4569,
        3.4569,
        3.6793,
        5.2529,
    ),
    ("Perc", "SlowWrfl", "Mwlk"): (
        4.8158,
        4.8158,
        4.8684,
        4.358,
        4.358,
        4.358,
        5.6645,
        4.8158,
    ),
    ("Perc", "SlowWrfl", "Meva"): (
        (3.1387, "amovpercmsprslowwrfldf.rtm"),
        (3.1387, "amovpercmsprslowwrfldfl.rtm"),
        (3.1387, "amovpercmsprslowwrfldfr.rtm"),
    ),
    ("Perc", "SrasWpst", "Mrun"): (
        (5.1251, "amovpercmrunslowwpstdf.rtm"),
        (5.1251, "amovpercmrunslowwpstdfl.rtm"),
        (2.1459, "amovpercmrunslowwpstdl.rtm"),
        (3.3818, "amovpercmrunslowwpstdbl.rtm"),
        (3.3818, "amovpercmrunslowwpstdb.rtm"),
        (3.3818, "amovpercmrunslowwpstdbr.rtm"),
        (2.0693, "amovpercmrunslowwpstdr.rtm"),
        (5.1251, "amovpercmrunslowwpstdfr.rtm"),
    ),
    ("Perc", "SrasWpst", "Mwlk"): (
        3.0009,
        3.0009,
        2.7524,
        1.1933,
        1.1933,
        1.1933,
        2.7031,
        3.0009,
    ),
    ("Perc", "SrasWpst", "Meva"): (
        (3.085, "amovpercmsprslowwpstdf.rtm"),
        (3.085, "amovpercmsprslowwpstdfl.rtm"),
        (3.085, "amovpercmsprslowwpstdfr.rtm"),
    ),
    ("Perc", "SlowWpst", "Mrun"): (
        5.1251,
        5.1251,
        2.1459,
        3.3818,
        3.3818,
        3.3818,
        2.0693,
        5.1251,
    ),
    ("Perc", "SlowWpst", "Mwlk"): (
        3.3836,
        3.3836,
        1.6747,
        1.4176,
        1.4176,
        1.4176,
        1.698,
        3.3836,
    ),
    ("Perc", "SlowWpst", "Meva"): (
        (3.085, "amovpercmsprslowwpstdf.rtm"),
        (3.085, "amovpercmsprslowwpstdfl.rtm"),
        (3.085, "amovpercmsprslowwpstdfr.rtm"),
    ),
    ("Perc", "SnonWnon", "Mrun"): (
        3.1762,
        3.1762,
        5.2477,
        4.5893,
        4.5933,
        4.584,
        5.4963,
        3.1762,
    ),
    ("Perc", "SnonWnon", "Mwlk"): (
        5.6426,
        5.1145,
        3.2668,
        4.4121,
        4.4121,
        4.4121,
        3.2524,
        5.1145,
    ),
    ("Perc", "SnonWnon", "Meva"): (
        (3.4122, "amovpercmsprsnonwnondf.rtm"),
        (3.4122, "amovpercmsprsnonwnondfl.rtm"),
        (3.4122, "amovpercmsprsnonwnondfr.rtm"),
    ),
    ("Pknl", "SrasWrfl", "Mrun"): (
        4.8891,
        4.8891,
        3.7752,
        3.0747,
        3.0747,
        3.0747,
        3.8558,
        4.8891,
    ),
    ("Pknl", "SrasWrfl", "Mwlk"): (
        3.0833,
        3.083,
        1.6088,
        2.5482,
        2.5482,
        2.5482,
        1.5531,
        3.083,
    ),
    ("Pknl", "SrasWrfl", "Meva"): (
        (3.1669, "amovpknlmsprslowwrfldf.rtm"),
        (3.1665, "amovpknlmsprslowwrfldfl.rtm"),
        (3.1665, "amovpknlmsprslowwrfldfr.rtm"),
    ),
    ("Pknl", "SlowWrfl", "Mrun"): (
        4.5747,
        4.5747,
        3.6161,
        3.0769,
        3.0769,
        3.0769,
        2.9996,
        4.5747,
    ),
    ("Pknl", "SlowWrfl", "Mwlk"): (
        2.8963,
        2.8963,
        1.2881,
        1.8941,
        1.8941,
        1.8941,
        1.2524,
        2.8963,
    ),
    ("Pknl", "SlowWrfl", "Meva"): (
        (3.1669, "amovpknlmsprslowwrfldf.rtm"),
        (3.1665, "amovpknlmsprslowwrfldfl.rtm"),
        (3.1665, "amovpknlmsprslowwrfldfr.rtm"),
    ),
    ("Pknl", "SrasWpst", "Mrun"): (
        (5.2394, "amovpknlmrunslowwpstdf.rtm"),
        (5.2394, "amovpknlmrunslowwpstdfl.rtm"),
        (2.0048, "amovpknlmrunslowwpstdl.rtm"),
        (3.0388, "amovpknlmrunslowwpstdbl.rtm"),
        (3.0388, "amovpknlmrunslowwpstdb.rtm"),
        (3.0388, "amovpknlmrunslowwpstdbr.rtm"),
        (2.13, "amovpknlmrunslowwpstdr.rtm"),
        (5.2394, "amovpknlmrunslowwpstdfr.rtm"),
    ),
    ("Pknl", "SrasWpst", "Mwlk"): (
        3.0848,
        3.0848,
        2.8048,
        2.4058,
        2.4058,
        2.4058,
        2.9174,
        3.0848,
    ),
    ("Pknl", "SrasWpst", "Meva"): (
        (3.0305, "amovpknlmsprslowwpstdf.rtm"),
        (3.0305, "amovpknlmsprslowwpstdfl.rtm"),
        (3.0305, "amovpknlmsprslowwpstdfr.rtm"),
    ),
    ("Pknl", "SlowWpst", "Mrun"): (
        5.2394,
        5.2394,
        2.0048,
        3.0388,
        3.0388,
        3.0388,
        2.13,
        5.2394,
    ),
    ("Pknl", "SlowWpst", "Mwlk"): (
        3.0805,
        3.0848,
        2.8048,
        2.4059,
        2.4059,
        2.3982,
        2.9174,
        3.0805,
    ),
    ("Pknl", "SnonWnon", "Mrun"): (
        4.8625,
        4.8625,
        4.9235,
        3.3334,
        3.3334,
        3.3334,
        5.003,
        4.8625,
    ),
    ("Pknl", "SnonWnon", "Mwlk"): (
        2.5225,
        2.5225,
        1.9891,
        2.3239,
        2.3239,
        2.3239,
        2.1825,
        2.5225,
    ),
    ("Pknl", "SnonWnon", "Meva"): (
        3.4128,
        3.4128,
        3.4128,
    ),
    ("Perc", "SrasWrfl", "Mtac"): (
        (3.8665, "amovpercmtacsraswrfldf.rtm"),
        (3.8665, "amovpercmtacsraswrfldfl.rtm"),
        (3.1926, "amovpercmtacsraswrfldl.rtm"),
        (2.9425, "amovpercmtacsraswrfldbl.rtm"),
        (2.9425, "amovpercmtacsraswrfldb.rtm"),
        (2.9425, "amovpercmtacsraswrfldbr.rtm"),
        (3.532, "amovpercmtacsraswrfldr.rtm"),
        (3.8664, "amovpercmtacsraswrfldfr.rtm"),
    ),
    ("Perc", "SlowWrfl", "Mtac"): (
        (4.8399, "amovpercmtacslowwrfldf_ver2.rtm"),
        (4.8399, "amovpercmtacslowwrfldfl_ver2.rtm"),
        (2.17, "amovpercmtacslowwrfldl_ver2.rtm"),
        (5.481, "amovpercmtacslowwrfldbl_ver2.rtm"),
        (5.4827, "amovpercmtacslowwrfldb_ver2.rtm"),
        (5.4838, "amovpercmtacslowwrfldbr_ver2.rtm"),
        (3.721, "amovpercmtacslowwrfldr_ver2.rtm"),
        (4.8399, "amovpercmtacslowwrfldfr_ver2.rtm"),
    ),
    ("Perc", "SrasWpst", "Mtac"): (
        (3.4149, "amovpercmtacsraswpstdf.rtm"),
        (3.4149, "amovpercmtacsraswpstdfl.rtm"),
        (1.4518, "amovpercmtacsraswpstdl.rtm"),
        (2.6023, "amovpercmtacsraswpstdbl.rtm"),
        (2.6023, "amovpercmtacsraswpstdb.rtm"),
        (2.6023, "amovpercmtacsraswpstdbr.rtm"),
        (1.6664, "amovpercmtacsraswpstdr.rtm"),
        (3.4149, "amovpercmtacsraswpstdfr.rtm"),
    ),
    ("Perc", "SlowWpst", "Mtac"): (
        (3.3836, "amovpercmtacslowwpstdf.rtm"),
        (3.3836, "amovpercmtacslowwpstdfl.rtm"),
        (1.6747, "amovpercmtacslowwpstdl.rtm"),
        (1.4176, "amovpercmtacslowwpstdbl.rtm"),
        (1.4176, "amovpercmtacslowwpstdb.rtm"),
        (1.4176, "amovpercmtacslowwpstdbr.rtm"),
        (1.698, "amovpercmtacslowwpstdr.rtm"),
        (3.3836, "amovpercmtacslowwpstdfr.rtm"),
    ),
    ("Pknl", "SrasWrfl", "Mtac"): (
        (4.1343, "amovpknlmtacsraswrfldf.rtm"),
        (4.1343, "amovpknlmtacsraswrfldfl.rtm"),
        (3.2898, "amovpknlmtacsraswrfldl.rtm"),
        (3.0379, "amovpknlmtacsraswrfldbl.rtm"),
        (3.0379, "amovpknlmtacsraswrfldb.rtm"),
        (3.0379, "amovpknlmtacsraswrfldbr.rtm"),
        (3.1918, "amovpknlmtacsraswrfldr.rtm"),
        (4.1343, "amovpknlmtacsraswrfldfr.rtm"),
    ),
    ("Pknl", "SlowWrfl", "Mtac"): (
        (1.7243, "amovpknlmtacslowwrfldf.rtm"),
        (1.7243, "amovpknlmtacslowwrfldfl.rtm"),
        (1.7487, "amovpknlmtacslowwrfldl.rtm"),
        (1.2696, "amovpknlmtacslowwrfldbl.rtm"),
        (1.2696, "amovpknlmtacslowwrfldb.rtm"),
        (1.2696, "amovpknlmtacslowwrfldbr.rtm"),
        (1.5436, "amovpknlmtacslowwrfldr.rtm"),
        (1.7243, "amovpknlmtacslowwrfldfr.rtm"),
    ),
    ("Pknl", "SrasWpst", "Mtac"): (
        (3.4575, "amovpknlmtacsraswpstdf.rtm"),
        (3.4575, "amovpknlmtacsraswpstdfl.rtm"),
        (1.4185, "amovpknlmtacsraswpstdl.rtm"),
        (2.9351, "amovpknlmtacsraswpstdbl.rtm"),
        (2.9351, "amovpknlmtacsraswpstdb.rtm"),
        (2.9351, "amovpknlmtacsraswpstdbr.rtm"),
        (1.5143, "amovpknlmtacsraswpstdr.rtm"),
        (3.4575, "amovpknlmtacsraswpstdfr.rtm"),
    ),
    ("Pknl", "SlowWpst", "Mtac"): (
        (3.0805, "amovpknlmtacslowwpstdf.rtm"),
        (3.0848, "amovpknlmtacslowwpstdfl.rtm"),
        (2.8048, "amovpknlmtacslowwpstdl.rtm"),
        (2.4059, "amovpknlmtacslowwpstdbl.rtm"),
        (2.4059, "amovpknlmtacslowwpstdb.rtm"),
        (2.3982, "amovpknlmtacslowwpstdbr.rtm"),
        (2.9174, "amovpknlmtacslowwpstdr.rtm"),
        (3.0805, "amovpknlmtacslowwpstdfr.rtm"),
    ),
}

def native(family, direction, sprinting=True, pose="Perc", walk=False, combat=False):
    pace = "Mrun"
    if direction == "Dnon":
        pace = "Mstp"
    elif walk:
        pace = "Mwlk"
    elif combat:
        pace = "Mtac"
    elif sprinting and direction in FORWARD and (pose, family) != ("Pknl", "SlowWpst"):
        pace = "Meva"
    variant = "_ver2" if (pose, pace, family) == ("Perc", "Mtac", "SlowWrfl") else ""
    if pace == "Meva" and family == "SrasWlnr":
        family = "SlowWlnr"
    return f"Amov{pose}{pace}{family}{direction}{variant}"


def custom(family, direction, sprinting=True, pose="Perc", walk=False, combat=False):
    base = native(family, direction, sprinting, pose, walk, combat).removesuffix("_ver2")
    if family == "SrasWlnr":
        base = base.replace("SlowWlnr", family)
    if sprinting and base[8:12] == "Mrun":
        return base + "_GAITSprint"
    return base + "_GAIT"


def rifle_sprint_stop_target(pose):
    return native("SrasWrfl", "Dnon", pose=pose) + "_GAITSprintStop"


def ordinary_states(family, pose):
    """Existing entry/release endpoints, not destinations for held-sprint input.

    Keep the RC3 native walk/run/sprint endpoints.  The lowered-rifle variant
    names also occur in ACE's movement config.  Lowered pistol movement feeds
    the same pistol sprint family; omitting it causes a native detour on entry.
    Do not add unarmed/pistol tactical variants or special action transitions.
    """
    states = [native(family, "Dnon", pose=pose)]
    states += [
        f"Amov{pose}{pace}{family}{direction}"
        for pace in ("Mrun", "Mwlk") for direction in DIRECTIONS
    ]
    states += [
        native(family, direction, pose=pose) for direction in FORWARD_SPRINT_DIRECTIONS
        if (pose, family) != ("Pknl", "SlowWpst")
    ]
    if family != "SnonWnon":
        states += [native(family, direction, False, pose, combat=True) for direction in DIRECTIONS]
    if family == "SlowWrfl" and pose == "Perc":
        states += [f"AmovPercMwlk{family}{direction}_ver2" for direction in DIRECTIONS]
        states += [f"AmovPercMtac{family}{direction}" for direction in DIRECTIONS]
    if family == "SrasWlnr" and pose == "Perc":
        states += ["AmovPercMstpSlowWlnrDnon"]
        states += [f"AmovPerc{pace}SlowWlnr{direction}" for pace in ("Mrun", "Mwlk") for direction in DIRECTIONS]
    return list(dict.fromkeys(states))


def pose_families():
    for family, neutral, jog, sprint, parent in FAMILIES:
        yield "Perc", family, neutral, jog, sprint, parent
    for (family, neutral, jog, sprint, _), parent in zip(FAMILIES, CROUCH_ACTIONS):
        yield "Pknl", family, neutral + "Crouch", jog + "Crouch", sprint + "Crouch", parent


def keep_moving_selectors(lines, target):
    for selector in IDLE_SELECTORS:
        lines.append(f'            {selector} = "{target}";')


def moving_stance_selectors(lines, pose, target):
    # X (MoveUp) and direct stance binds must keep the current stride. The
    # inherited idle map otherwise inserts a stationary state before Draw3D.
    selectors = ("Up", "PlayerCrouch", "Crouch") if pose == "Perc" else ("Up", "PlayerStand")
    for selector in selectors:
        lines.append(f'            {selector} = "{target}";')


def root_travel(pose, family, base, direction):
    pace = base[8:12]
    refs = ROOT_TRAVEL.get((pose, family, pace))
    if refs is None:
        return []
    directions = FORWARD_SPRINT_DIRECTIONS if pace == "Meva" else DIRECTIONS
    offset = refs[directions.index(direction)]
    distance, rtm = offset if isinstance(offset, tuple) else (offset, base.lower() + ".rtm")
    return [f'            GAIT_rootTravel[] = {{{distance}, "{rtm}"}};']


def append_edges(lines, field, names):
    if len(names) != len(set(names)):
        raise ValueError(f"Duplicate generated {field} endpoint")
    lines.extend([f"            {field}[] +=", "            {"])
    for index, name in enumerate(names):
        weight = "0.025" if "Meva" in name else "0.02"
        comma = "," if index < len(names) - 1 else ""
        lines.append(f'                "{name}", {weight}{comma}')
    lines.append("            };")


def render():
    lines = ['''/*
 * GAIT 1.8 foundation: opt-in standing and crouched locomotion action families.
 * Generated by tools/generate_foundation_actions.py; edit the generator.
 *
 * Standing and crouched families retain their native pose, direction, and
 * movement clips. The game has no lowered-pistol crouch sprint clip, so that
 * family uses the crouch run clip with sprint actions. Ordinary slope movement uses
 * Mrun even when the engine requests Walk/Slow. Moving states use pace-locked
 * action maps: a jog state maps every forward pace selector back to Mrun and
 * a sprint state maps every forward pace selector back to Meva. Other sprint
 * directions keep GAIT ownership on Fast and use native movement on ordinary
 * pace requests. Therefore a forward
 * engine pace-selector threshold cannot switch the body halfway through GAIT's
 * numerical acceleration. Shift input and the controller's single graph request
 * own the jog/sprint handoff instead. The original numerical brace acts inside
 * the selected movement clip from the first frame.
 * Forward sprint and moving jog clips map idle selectors to their current direction.
 * On uneven ground an engine stop request can otherwise select GAIT idle
 * with forward and Turbo held. Draw3D handles actual input release and stops.
 * Draw3D also handles stops for walk and combat clips during the speed taper.
 * The engine controls orientation.
 *
 * Forward Walk requests still point to custom movement on slopes. This policy
 * does not require overwriting Arma's inherited native action maps.
 *
 * Moving states select the matching direction in the other stance.
 * Preserve inherited weapon, injury, medical, vault and vehicle actions.
 * Preserve native transition arrays too:
 * overwriting them from an incomplete config dump would discard valid exits
 * added by the game or ACE. Complete direct custom routes are appended;
 * inherited native routes remain available for actions and controlled release.
 *
 * Custom-state variants are empty to avoid automatic native idle/fidget
 * variants leaving the family. No ConnectTo self-loop is forced. Animation
 * files, speed, duty, collision and other pose properties inherit unchanged.
 * Stops blend directly to native idle. The raised-rifle shoulder transition
 * also uses native actions and ends in native idle. Shift release restores
 * the selected walking, jogging, or combat clip.
 * Transition weights are graph costs, not fixed blend durations in seconds.
 *
 * Sources for native names/selectors and preserving explicit action exits:
 * https://community.bistudio.com/wiki/Arma_3:_Moves
 * https://github.com/acemod/ACE3/blob/master/addons/dragging/CfgMovesBasic.hpp
 * https://github.com/acemod/ACE3/blob/master/addons/movement/CfgMoves.hpp
 */
class CfgMovesBasic
{
    class ManActions
    {
#define GAIT_CATCH_ACTION(NAME) NAME[] = {#NAME,"Gesture"}
''']
    # Preserve registered gesture action names and their historical order.
    for fit in ("compact","standard","roomy"):
        for pose in ("upright","travel","lower","tired"):
            lines.append(f"        GAIT_CATCH_ACTION(GAIT_RifleRun_{fit}_catch_{pose});")
        if fit == "compact":
            lines.append("        GAIT_CATCH_ACTION(GAIT_NormalBrace);")
    for fit in ("standard","compact","roomy"):
        for pose in ("upright","lower","travel","tired"):
            for quarter in range(4):
                lines.append(f"        GAIT_CATCH_ACTION(GAIT_RifleRun_{fit}_gather_{pose}_{quarter});")
    lines += ['''        GAIT_CATCH_ACTION(GAIT_EndSprintGesture);
#undef GAIT_CATCH_ACTION
    };
    class Actions
    {
''']
    for pose, family, neutral_actions, jog_actions, sprint_actions, parent in pose_families():
        walk_actions = neutral_actions + "Walk"
        combat_actions = neutral_actions + "Combat"
        other_pose = "Pknl" if pose == "Perc" else "Perc"
        lines.append(f"        class {parent};")
        policies = [
            (neutral_actions, "neutral"),
            (jog_actions, "jog"),
            (sprint_actions, "sprint"),
            (walk_actions, "walk"),
        ]
        if family != "SnonWnon":
            policies.append((combat_actions, "combat"))
        for actions, policy in policies:
            lines += [f"        class {actions}: {parent}", "        {"]
            lines.append("            // Keep default/stop/turn selection in this opt-in family.")
            for selector in IDLE_SELECTORS:
                lines.append(f'            {selector} = "{custom(family, "Dnon", False, pose)}";')
            for pace in PACES:
                for selector, direction in zip(SELECTORS, DIRECTIONS):
                    if policy == "sprint":
                        sprinting = True
                    elif policy in ("jog", "walk", "combat"):
                        sprinting = False
                    else:
                        sprinting = pace in ("Fast", "PlayerFast")
                    target = custom(family, direction, sprinting, pose, walk=policy == "walk", combat=policy == "combat")
                    if policy == "sprint" and direction not in FORWARD and pace not in ("Fast", "PlayerFast"):
                        target = native(family, direction, False, pose)
                    lines.append(f'            {pace}{selector} = "{target}";')
            if policy != "neutral":
                # Ctrl plus a movement key can invoke Adjust instead of a
                # regular travel selector. Idle still inherits its stance map.
                for selector, direction in zip(SELECTORS, DIRECTIONS):
                    target = custom(family, direction, policy == "sprint", pose,
                                    walk=policy == "walk", combat=policy == "combat")
                    lines.append(f'            Adjust{selector} = "{target}";')
            lines += ["        };", ""]
        for direction in DIRECTIONS:
            actions = sprint_actions + direction
            target = custom(family, direction, pose=pose)
            lines += [f"        class {actions}: {sprint_actions}", "        {"]
            moving_stance_selectors(lines, pose, custom(family, direction, pose=other_pose))
            if direction in FORWARD:
                keep_moving_selectors(lines, target)
                if family in ("SrasWrfl", "SlowWrfl"):
                    other = custom(OTHER_WEAPON_POSE[family], direction, pose=pose)
                    raised = custom("SrasWrfl", direction, pose=pose)
                    lines += [
                        f'            Stand = "{other}";',
                        f'            Combat = "{raised}";',
                    ]
            lines += ["        };", ""]
        for direction in DIRECTIONS:
            lines += [f"        class {jog_actions}{direction}: {jog_actions}", "        {"]
            # A Ctrl chord can make Arma request Stop while direction is
            # still held. Draw3D handles the actual movement-release edge.
            keep_moving_selectors(lines, custom(family, direction, False, pose))
            moving_stance_selectors(lines, pose, native(family, direction, False, other_pose))
            lines += ["        };", ""]
        for direction in DIRECTIONS:
            target = custom(family, direction, False, pose, walk=True)
            lines += [f"        class {walk_actions}{direction}: {walk_actions}", "        {"]
            # Below the native walk playback minimum Arma can request Stop
            # while a key is still held. Only live input may end this walk.
            keep_moving_selectors(lines, target)
            moving_stance_selectors(lines, pose, native(family, direction, False, other_pose, walk=True))
            if family in AIMING_WALK_FAMILIES:
                aim_walk = native(AIMING_WALK_FAMILIES[family], direction, False, pose, walk=True)
                lines.append(f'            Combat = "{aim_walk}";')
            lines += ["        };", ""]
        if family != "SnonWnon":
            for direction in DIRECTIONS:
                target = custom(family, direction, False, pose, combat=True)
                lines += [f"        class {combat_actions}{direction}: {combat_actions}", "        {"]
                keep_moving_selectors(lines, target)
                moving_stance_selectors(lines, pose, native(family, direction, False, other_pose, combat=True))
                lines += ["        };", ""]
    lines += ["    };", "};", "", "class CfgMovesMaleSdr: CfgMovesBasic", "{", "    class States", "    {"]
    for pose, family, neutral_actions, jog_actions, sprint_actions, native_actions in pose_families():
        walk_actions = neutral_actions + "Walk"
        combat_actions = neutral_actions + "Combat"
        state_specs = [("Dnon", False, False, False)]
        state_specs += [(direction, True, False, False) for direction in DIRECTIONS]
        state_specs += [(direction, False, False, False) for direction in DIRECTIONS]
        state_specs += [(direction, False, True, False) for direction in DIRECTIONS]
        if family != "SnonWnon":
            state_specs += [(direction, False, False, True) for direction in DIRECTIONS]
        bases = dict.fromkeys(native(family, d, s, pose, w, c) for d, s, w, c in state_specs)
        lines.extend(f"        class {base};" for base in bases)
        lines.append("")
        native_states = ordinary_states(family, pose)
        ordinary = list(native_states)
        other_pose = "Pknl" if pose == "Perc" else "Perc"
        stance_families = ("SrasWrfl", "SlowWrfl") if family in ("SrasWrfl", "SlowWrfl") else (family,)
        stance_targets = [
            state for stance_family in stance_families
            for state in ordinary_states(stance_family, other_pose)
            if state[8:12] != "Meva"
        ]
        stance_targets += [
            custom(stance_family, direction, pose=other_pose)
            for stance_family in stance_families
            for direction in DIRECTIONS
        ]
        if family == "SrasWrfl":
            ordinary.append(rifle_sprint_stop_target(pose))
        members = [custom(family, d, s, pose, w, c) for d, s, w, c in state_specs]
        other_sprints = []
        if family in OTHER_WEAPON_POSE:
            other = OTHER_WEAPON_POSE[family]
            for direction in FORWARD_SPRINT_DIRECTIONS:
                other_sprints.append(custom(other, direction, True, pose))
                if (pose, other) != ("Pknl", "SlowWpst"):
                    other_sprints.append(native(other, direction, True, pose))
        for direction, sprinting, walk, combat in state_specs:
            name = custom(family, direction, sprinting, pose, walk, combat)
            base = native(family, direction, sprinting, pose, walk, combat)
            role = "idle" if direction == "Dnon" else "move"
            state_actions = neutral_actions if direction == "Dnon" else (sprint_actions if sprinting else jog_actions) + direction
            if walk:
                state_actions = walk_actions + direction
            if combat:
                state_actions = combat_actions + direction
            lines += [
                f"        class {name}: {base}", "        {",
                f'            actions = "{state_actions}";',
                "            GAIT_slopeState = 1;",
                f'            GAIT_nativeState = "{base}";',
                f'            GAIT_slopeFamily = "{family}";',
                f'            GAIT_locomotionRole = "{role}";',
                "            looped = 1;",
                "            equivalentTo = \"\";",
                "            variantsPlayer[] = {};",
                "            variantsAI[] = {};",
            ]
            # The ordinary raised jog can be held on a slope after Shift-up.
            # Its action map cannot rely on Arma selecting native combat pace
            # before the trigger arrives. Sprint and lowered states stay native.
            if not sprinting and base[8:12] == "Mrun" and family in ("SrasWrfl","SrasWpst"):
                lines += ["            disableWeapons = 0;", "            disableWeaponsLong = 0;"]
            lines += root_travel(pose, family, base, direction)
            if walk and family in ("SrasWrfl", "SrasWpst"):
                lines.append(f"            enableOptics = {1 if family == 'SrasWrfl' else 2};")
            lines.append("            // Explicit graph routes let playMoveNow interpolate entry and release.")
            stance_sources = []
            if sprinting and direction in FORWARD:
                stance_sources = [
                    state for stance_family in stance_families
                    for state in ordinary_states(stance_family, other_pose)
                ]
            append_edges(lines, "InterpolateFrom", ordinary + other_sprints + stance_sources)
            lines.append("            // Complete direct idle/direction routes preserve the slope family.")
            internal = [other for other in members if other != name]
            if sprinting and direction in FORWARD and family in ("SrasWrfl", "SlowWrfl"):
                internal.append(custom(OTHER_WEAPON_POSE[family], direction, pose=pose))
            if walk and family in ("SlowWrfl", "SlowWpst"):
                internal += [native(AIMING_WALK_FAMILIES[family], d, False, pose, walk=True) for d in DIRECTIONS]
            append_edges(lines, "InterpolateTo", internal + ordinary + stance_targets)
            lines += ["        };", ""]
        if family == "SrasWrfl":
            idle = native(family, "Dnon", pose=pose)
            shoulder = f"{native('SlowWrfl', 'Dnon', pose=pose)}_{idle}"
            lines += [
                f"        class {shoulder};",
                f"        class {rifle_sprint_stop_target(pose)}: {shoulder}", "        {",
                f'            actions = "{native_actions}";',
                "            interpolationSpeed = 4;",
                "            interpolationRestart = 0;",
                "            minPlayTime = 0;",
                "            looped = 0;",
                "            disableWeapons = 0;",
                "            disableWeaponsLong = 0;",
                '            equivalentTo = "";',
                f'            ConnectTo[] = {{"{idle}", 0.02}};',
            ]
            append_edges(lines, "InterpolateFrom", members + native_states + other_sprints)
            append_edges(lines, "InterpolateTo", members + native_states)
            lines += ["        };", ""]
    lines += ["    };", "};", ""]
    return "\n".join(lines)


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = render()
    if args.check:
        if args.output.read_text() != expected:
            raise SystemExit(f"Generated config differs: {args.output}")
        print("Foundation graph generator matches the checked-in config.")
        return
    args.output.write_text(expected)
    print(f"Wrote standing and crouched locomotion graphs to {args.output}.")


if __name__ == "__main__":
    main()
