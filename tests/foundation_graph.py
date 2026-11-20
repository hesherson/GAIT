"""Check the foundation graph's input, continuity and native-exit contracts.

This parses the shipped config independently of its generator.  It checks the
known RPT escape at native idle and direction reversal paths; it cannot prove
engine behavior, animation blending, or movement above a terrain threshold.
"""

from pathlib import Path
import re
import unittest


CONFIG = Path(__file__).resolve().parents[1] / "addons/gait/slope_actions.hpp"
FAMILIES = {
    "SrasWrfl": ("GAIT_SlopeRifleRaisedActions", "GAIT_SlopeRifleRaisedJogActions", "GAIT_SlopeRifleRaisedSprintActions", "RifleStandActions"),
    "SlowWrfl": ("GAIT_SlopeRifleLoweredActions", "GAIT_SlopeRifleLoweredJogActions", "GAIT_SlopeRifleLoweredSprintActions", "RifleLowStandActions"),
    "SrasWpst": ("GAIT_SlopePistolActions", "GAIT_SlopePistolJogActions", "GAIT_SlopePistolSprintActions", "PistolStandActions"),
    "SlowWpst": ("GAIT_SlopePistolLowActions", "GAIT_SlopePistolLowJogActions", "GAIT_SlopePistolLowSprintActions", "PistolLowStandActions"),
    "SnonWnon": ("GAIT_SlopeUnarmedActions", "GAIT_SlopeUnarmedJogActions", "GAIT_SlopeUnarmedSprintActions", "CivilStandActions"),
    "SrasWlnr": ("GAIT_SlopeLauncherActions", "GAIT_SlopeLauncherJogActions", "GAIT_SlopeLauncherSprintActions", "LauncherStandActions"),
}
DIRECTIONS = {"Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"}
SELECTOR_DIRECTIONS = dict(zip(
    ("F", "LF", "L", "LB", "B", "RB", "R", "RF"),
    ("Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"),
))
FORWARD = {"Df", "Dfl", "Dfr"}
STOP_SELECTORS = {"Default", "Stop", "StopRelaxed", "TurnL", "TurnR", "TurnLRelaxed", "TurnRRelaxed"}
STANCE_SELECTORS = {"Perc": {"Up", "PlayerCrouch", "Crouch"}, "Pknl": {"Up", "PlayerStand"}}
CROUCH_ACTIONS = dict(zip(FAMILIES, (
    "RifleKneelActions", "RifleKneelLowActions", "PistolKneelActions",
    "PistolLowKneelActions", "CivilKneelActions", "LauncherKneelActions",
)))


def pose_families():
    for family, (neutral, jog, sprint, parent) in FAMILIES.items():
        yield "Perc", family, neutral, jog, sprint, parent
        yield "Pknl", family, neutral + "Crouch", jog + "Crouch", sprint + "Crouch", CROUCH_ACTIONS[family]


def sprint_pace(pose, family, direction):
    return "Meva" if direction in FORWARD and (pose, family) != ("Pknl", "SlowWpst") else "Mrun"


def properties(body):
    return dict(re.findall(r'^\s*(\w+)\s*=\s*"([^"]*)";', body, re.M))


def edges(body, field):
    match = re.search(rf"\b{field}\[\]\s*\+=\s*\{{(.*?)\}};", body, re.S)
    if not match:
        raise AssertionError(f"Missing additive {field} array")
    values = re.findall(r'"([^\"]+)"\s*,\s*([0-9.]+)', match.group(1))
    return [(name, float(weight)) for name, weight in values]


class FoundationGraph(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = CONFIG.read_text()
        blocks = re.findall(
            r"^        class (\w+): (\w+)\s*\{(.*?)^        \};",
            cls.text, re.M | re.S,
        )
        cls.states = {name: (base, body) for name, base, body in blocks
                      if name.endswith("_GAIT") or name.endswith("_GAITSprint")}
        cls.shoulder_stops = {name: (base, body) for name, base, body in blocks if name.endswith("_GAITSprintStop")}
        cls.actions = {name: (base, body) for name, base, body in blocks if name.startswith("GAIT_Slope")}

    def test_real_native_clip_parents_and_controller_markers(self):
        self.assertEqual(len(self.states), 380)
        counts = {"idle": 0, "sprint": 0, "run": 0, "walk": 0, "combat": 0}
        for name, (parent, body) in self.states.items():
            with self.subTest(state=name):
                p = properties(body)
                match = re.fullmatch(r"Amov(Perc|Pknl)(Mstp|Mrun|Meva|Mwlk|Mtac)(\w{8})(Dnon|Df|Dfl|Dl|Dbl|Db|Dbr|Dr|Dfr)_(GAIT|GAITSprint)", name)
                self.assertIsNotNone(match)
                pose, pace, family, direction, suffix = match.groups()
                self.assertIn(family, FAMILIES)
                variant = "_ver2" if (pose, pace, family) == ("Perc", "Mtac", "SlowWrfl") else ""
                native_family = "SlowWlnr" if (family, pace) == ("SrasWlnr", "Meva") else family
                self.assertEqual(parent, f"Amov{pose}{pace}{native_family}{direction}{variant}")
                self.assertEqual(p["GAIT_nativeState"], parent)
                self.assertEqual(p["GAIT_slopeFamily"], family)
                neutral_actions, jog_actions, sprint_actions, _ = FAMILIES[family]
                if pose == "Pknl":
                    neutral_actions += "Crouch"
                    jog_actions += "Crouch"
                    sprint_actions += "Crouch"
                sprint_owned = pace == "Meva" or suffix == "GAITSprint"
                expected_actions = neutral_actions if pace == "Mstp" else sprint_actions if sprint_owned else jog_actions
                if direction != "Dnon":
                    expected_actions += direction
                if pace == "Mwlk":
                    expected_actions = neutral_actions + "Walk" + direction
                if pace == "Mtac":
                    expected_actions = neutral_actions + "Combat" + direction
                self.assertEqual(p["actions"], expected_actions)
                self.assertRegex(body, r"\bGAIT_slopeState\s*=\s*1;")
                self.assertRegex(body, r"\blooped\s*=\s*1;")
                self.assertEqual(p["equivalentTo"], "")
                role = "idle" if direction == "Dnon" else "move"
                self.assertEqual(p["GAIT_locomotionRole"], role)
                if direction == "Dnon":
                    self.assertEqual(pace, "Mstp")
                elif pace == "Meva":
                    self.assertIn(direction, FORWARD)
                else:
                    self.assertIn(pace, ("Mrun", "Mwlk", "Mtac"))
                counts[{"Mstp": "idle", "Meva": "sprint", "Mrun": "run", "Mwlk": "walk", "Mtac": "combat"}[pace]] += 1
                if pace != "Mstp" and family != "SrasWlnr":
                    self.assertRegex(body, r'GAIT_rootTravel\[\] = \{[0-9.]+, "[^"]+\.rtm"\};')
                # Root motion, clip speed, brace timing and pose properties
                # remain inherited; this graph must not retune those values.
                self.assertNotRegex(body, r"\b(?:file|speed|duty|stamina|headBobStrength)\s*=")
                fire_ready_jog = pace == "Mrun" and name.endswith("_GAIT") and family in ("SrasWrfl","SrasWpst")
                for flag in ("disableWeapons","disableWeaponsLong"):
                    self.assertEqual(re.findall(rf"\b{flag}\s*=\s*(\d+);", body), ["0"] if fire_ready_jog else [])
        self.assertEqual(counts, {"idle": 12, "sprint": 33, "run": 159, "walk": 96, "combat": 80})

    def test_sprint_preserves_forward_and_exposes_native_lateral_release(self):
        for pose, family, neutral_actions, jog_actions, sprint_actions, native_actions in pose_families():
            idle = f"Amov{pose}Mstp{family}Dnon_GAIT"
            policies = [
                (neutral_actions, "neutral"),
                (jog_actions, "jog"),
                (sprint_actions, "sprint"),
                (neutral_actions + "Walk", "walk"),
            ]
            if family != "SnonWnon":
                policies.append((neutral_actions + "Combat", "combat"))
            for actions, policy in policies:
                parent, body = self.actions[actions]
                p = properties(body)
                self.assertEqual(parent, native_actions)
                for selector in ("Default", "Stop", "StopRelaxed", "TurnL", "TurnR", "TurnLRelaxed", "TurnRRelaxed"):
                    self.assertEqual(p[selector], idle)
                for pace in ("Walk", "PlayerWalk", "Slow", "PlayerSlow", "Fast", "PlayerFast", "Tact", "PlayerTact"):
                    for selector, direction in SELECTOR_DIRECTIONS.items():
                        if policy == "sprint":
                            sprinting = True
                        elif policy in ("jog", "walk", "combat"):
                            sprinting = False
                        else:
                            sprinting = pace in ("Fast", "PlayerFast")
                        expected_pace = sprint_pace(pose, family, direction) if sprinting else "Mrun"
                        if policy == "walk":
                            expected_pace = "Mwlk"
                        if policy == "combat":
                            expected_pace = "Mtac"
                        suffix = "_GAITSprint" if sprinting and expected_pace == "Mrun" else "_GAIT"
                        if policy == "sprint" and direction not in FORWARD and pace not in ("Fast", "PlayerFast"):
                            suffix = ""
                        self.assertEqual(p[pace + selector], f"Amov{pose}{expected_pace}{family}{direction}{suffix}")
                adjust = {k: v for k, v in p.items() if k.startswith("Adjust")}
                if policy == "neutral":
                    self.assertEqual(adjust, {})
                else:
                    self.assertEqual(adjust, {
                        "Adjust" + selector: p["Fast" + selector]
                        for selector in SELECTOR_DIRECTIONS
                    })
                # Other stance, medical, weapon and vehicle selectors remain inherited.
                self.assertEqual(len(p), 71 + len(adjust))

    def test_stops_link_directly_to_native_idle(self):
        self.assertNotIn("_GAITStop", self.text)
        for pose, family, _, _, _, _ in pose_families():
            native_idle = f"Amov{pose}Mstp{family}Dnon"
            for name, (_, move_body) in self.states.items():
                if name[4:8] != pose or properties(move_body)["GAIT_slopeFamily"] != family:
                    continue
                self.assertIn(native_idle, dict(edges(move_body, "InterpolateTo")))
                self.assertIn(native_idle, dict(edges(move_body, "InterpolateFrom")))

    def test_wind_down_crouch_links_to_native_moving_stance(self):
        for name, (_, body) in self.states.items():
            family = properties(body)["GAIT_slopeFamily"]
            destination = "Pknl" if name[4:8] == "Perc" else "Perc"
            exits = dict(edges(body, "InterpolateTo"))
            self.assertIn(f"Amov{destination}Mstp{family}Dnon", exits)
            paces = ("Mrun", "Mwlk") if family == "SnonWnon" else ("Mrun", "Mwlk", "Mtac")
            for pace in paces:
                suffix = "_ver2" if (destination, pace, family) == ("Perc", "Mtac", "SlowWrfl") else ""
                for direction in DIRECTIONS:
                    self.assertIn(f"Amov{destination}{pace}{family}{direction}{suffix}", exits)
            if family in ("SrasWrfl", "SlowWrfl"):
                self.assertIn(f"Amov{destination}MrunSlowWrflDf", exits)
                self.assertIn(f"Amov{destination}MrunSrasWrflDf", exits)
            for direction in FORWARD:
                pace = sprint_pace(destination, family, direction)
                suffix = "GAIT" if pace == "Meva" else "GAITSprint"
                self.assertIn(f"Amov{destination}{pace}{family}{direction}_{suffix}", exits)
            if name[8:12] == "Meva":
                self.assertIn(f"Amov{destination}Mstp{family}Dnon", dict(edges(body, "InterpolateFrom")))
        source = (CONFIG.parent / "functions/fn_slopeLocomotion.sqf").read_text()
        crouch = source.split('if (_crouchToggle) exitWith {', 1)[1].split('\n    };', 1)[0]
        self.assertIn("(_progress max 0 min 1) mod 1, 0.22", crouch)
        self.assertIn("call GAIT_fnc_blendNativeLocomotion", crouch)
        self.assertNotIn("call GAIT_fnc_requestLocomotionMove", crouch)
        helpers = (CONFIG.parent / "functions/fn_traversalHelpers.sqf").read_text()
        binding = helpers.split('GAIT_fnc_crouchToggleHeld = {', 1)[1].split('};', 1)[0]
        self.assertIn('inputAction "MoveUp"', binding)
        self.assertIn('inputAction "Crouch"', binding)

    def test_stance_input_selects_a_moving_clip_in_the_same_direction(self):
        for name, (_, body) in self.states.items():
            if name[8:12] == "Mstp":
                continue
            with self.subTest(state=name):
                pose, pace = name[4:8], name[8:12]
                destination = "Pknl" if pose == "Perc" else "Perc"
                family, direction = name[12:20], name[20:].split("_")[0]
                if pace == "Meva" or name.endswith("_GAITSprint"):
                    pace = sprint_pace(destination, family, direction)
                    suffix = "_GAIT" if pace == "Meva" else "_GAITSprint"
                else:
                    suffix = "_ver2" if (destination, pace, family) == ("Perc", "Mtac", "SlowWrfl") else ""
                target = f"Amov{destination}{pace}{family}{direction}{suffix}"
                selectors = properties(self.actions[properties(body)["actions"]][1])
                for action in STANCE_SELECTORS[pose]:
                    self.assertEqual(selectors[action], target)
                self.assertIn(target, dict(edges(body, "InterpolateTo")))

    def test_nswg2_idle_and_turn_extensions_keep_the_original_parent(self):
        compat = (CONFIG.parent / "nswg2_animations/config.cpp").read_text()
        macro = compat.split("#define GAIT_NSWG2_IDLE", 1)[1].split("class CfgMovesBasic;", 1)[0]
        self.assertIn("class CLASS: BASE", macro)
        self.assertIn("InterpolateTo[] +=", macro)
        expected_parents = {
            **{f"AidlPercMstpSrasWrflDnon_G0{variant}_player": "AidlPercMstpSrasWrflDnon_G04"
               for variant in range(1, 5)},
            **{f"AmovPercMstpSrasWrflDnon_turn{side}": "AidlPercMstpSrasWrflDnon_G0S"
               for side in ("L", "R")},
        }
        declarations = re.findall(r"GAIT_NSWG2_IDLE\((\w+),\s*(\w+)\);", compat)
        self.assertCountEqual(declarations, expected_parents.items())

    def test_rifle_sprint_stop_shoulders_with_native_movement_available(self):
        self.assertEqual(len(self.shoulder_stops), 2)
        for pose, actions in (("Perc", "RifleStandActions"), ("Pknl", "RifleKneelActions")):
            idle = f"Amov{pose}MstpSrasWrflDnon"
            parent, body = self.shoulder_stops[idle + "_GAITSprintStop"]
            self.assertEqual(parent, f"Amov{pose}MstpSlowWrflDnon_{idle}")
            self.assertEqual(properties(body)["actions"], actions)
            self.assertRegex(body, r"\bminPlayTime\s*=\s*0;")
            self.assertRegex(body, r"\blooped\s*=\s*0;")
            self.assertIn(f'ConnectTo[] = {{"{idle}", 0.02}};', body)
            entry = dict(edges(body, "InterpolateFrom"))
            exit = dict(edges(body, "InterpolateTo"))
            for direction in FORWARD:
                self.assertIn(f"Amov{pose}MevaSrasWrfl{direction}_GAIT", entry)
                self.assertIn(f"Amov{pose}MevaSlowWrfl{direction}_GAIT", entry)
            for direction in DIRECTIONS:
                self.assertIn(f"Amov{pose}MrunSrasWrfl{direction}", exit)

    def test_engine_stop_selectors_continue_the_current_forward_sprint(self):
        for pose, family, _, _, sprint_actions, _ in pose_families():
            for direction in FORWARD:
                with self.subTest(family=family, direction=direction):
                    pace = sprint_pace(pose, family, direction)
                    suffix = "GAIT" if pace == "Meva" else "GAITSprint"
                    sprint = f"Amov{pose}{pace}{family}{direction}_{suffix}"
                    _, state_body = self.states[sprint]
                    action_name = properties(state_body)["actions"]
                    parent, action_body = self.actions[action_name]
                    self.assertEqual(parent, sprint_actions)
                    selectors = properties(action_body)
                    self.assertEqual(set(selectors) - STANCE_SELECTORS[pose] - {"Stand", "Combat"}, STOP_SELECTORS)
                    self.assertTrue(all(selectors[key] == sprint for key in STOP_SELECTORS))
                    outgoing = dict(edges(state_body, "InterpolateTo"))
                    self.assertIn(f"Amov{pose}Mstp{family}Dnon", outgoing)
                    if family in ("SrasWrfl", "SlowWrfl"):
                        opposite = "SlowWrfl" if family == "SrasWrfl" else "SrasWrfl"
                        target = f"Amov{pose}Meva{opposite}{direction}_GAIT"
                        self.assertEqual(selectors["Stand"], target)
                        self.assertEqual(selectors["Combat"], f"Amov{pose}MevaSrasWrfl{direction}_GAIT")
                        self.assertIn(target, outgoing)
                    else:
                        self.assertEqual(set(selectors) - STANCE_SELECTORS[pose], STOP_SELECTORS)

    def test_idle_recovery_and_direction_reversals_have_direct_edges(self):
        for pose, family, *_ in pose_families():
            members = {name for name, (_, body) in self.states.items()
                       if name[4:8] == pose and properties(body)["GAIT_slopeFamily"] == family}
            self.assertEqual(len(members), 25 if family == "SnonWnon" else 33)
            for source in members:
                pairs = edges(self.states[source][1], "InterpolateTo")
                names = [name for name, _ in pairs]
                self.assertEqual(len(names), len(set(names)))
                internal = {name for name in names
                            if name[4:8] == pose and name.endswith(("_GAIT", "_GAITSprint"))}
                expected = members - {source}
                if family in ("SrasWrfl", "SlowWrfl") and source[8:12] == "Meva":
                    opposite = "SlowWrfl" if family == "SrasWrfl" else "SrasWrfl"
                    expected.add(source.replace(family, opposite))
                self.assertEqual(internal, expected)
                for target, weight in pairs:
                    self.assertGreater(weight, 0)
                    self.assertLessEqual(weight, 0.025)
                    if target.endswith("_GAIT") or target.endswith("_GAITSprint"):
                        self.assertIn(target, self.states)

    def test_return_clips_inherit_native_aiming_and_allow_same_weapon_pose_restore(self):
        for pose in ("Perc", "Pknl"):
            target = f"Amov{pose}MtacSlowWrflDf_GAIT"
            _, body = self.states[target]
            self.assertNotRegex(body, r"\baiming(?:Body)?\s*=")
            self.assertIn(f"Amov{pose}MevaSrasWrflDf_GAIT", dict(edges(body, "InterpolateFrom")))
        self.assertFalse(any("_GAITShoulder" in line for line in self.text.splitlines()))

    def test_release_jog_ignores_engine_stop_selectors_while_input_is_held(self):
        for pose, family, _, jog_actions, *_ in pose_families():
            for direction in DIRECTIONS:
                jog = f"Amov{pose}Mrun{family}{direction}_GAIT"
                actions = properties(self.states[jog][1])["actions"]
                parent, body = self.actions[actions]
                self.assertEqual(parent, jog_actions)
                selectors = properties(body)
                for selector in STOP_SELECTORS:
                    self.assertEqual(selectors[selector], jog)

    def test_release_walk_ignores_engine_stop_selectors_while_input_is_held(self):
        for pose, family, neutral_actions, *_ in pose_families():
            for direction in DIRECTIONS:
                walk = f"Amov{pose}Mwlk{family}{direction}_GAIT"
                actions = properties(self.states[walk][1])["actions"]
                walk_map, body = self.actions[actions]
                self.assertEqual(walk_map, neutral_actions + "Walk")
                selectors = properties(body)
                if family != "SnonWnon":
                    raised = family.replace("Slow", "Sras")
                    target = f"Amov{pose}Mwlk{raised}{direction}"
                    self.assertEqual(selectors.pop("Combat"), target)
                    if family != raised:
                        self.assertIn(target, dict(edges(self.states[walk][1], "InterpolateTo")))
                    elif family != "SrasWlnr":
                        optics = 1 if family == "SrasWrfl" else 2
                        self.assertIn(f"enableOptics = {optics};", self.states[walk][1])
                self.assertEqual(set(selectors) - STANCE_SELECTORS[pose], STOP_SELECTORS)
                self.assertTrue(all(selectors[key] == walk for key in STOP_SELECTORS))

    def test_moving_release_hands_direction_back_with_a_blend(self):
        source = (CONFIG.parent / "functions/fn_slopeLocomotion.sqf").read_text()
        code = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)
        self.assertEqual(len(re.findall(r"\bplayMoveNow\b", code)), 1)
        release = code.split("GAIT_fnc_requestMovingLocomotionRelease = {", 1)[1].split("\n};", 1)[0]
        self.assertIn('call GAIT_fnc_nativeOrdinaryMoveName', release)
        self.assertIn('isClass', release)
        self.assertIn('call GAIT_fnc_readPaceMoveInfo', release)
        self.assertLess(release.index('call GAIT_fnc_beginNativeReleaseDirection'),
                        release.index('call GAIT_fnc_blendNativeLocomotion'))
        self.assertNotIn('call GAIT_fnc_requestLocomotionMove', release)
        self.assertIn('(_progress max 0 min 1) mod 1, 0.25', release)
        self.assertNotIn('call GAIT_fnc_requestLocomotionStop', release)
        self.assertEqual(len(re.findall(r"\bswitchMove\b", code)), 1)
        stop = code.split("GAIT_fnc_switchToLocomotionIdle = {", 1)[1].split("\n};", 1)[0]
        self.assertIn('[_unit, _target, 0, 0] call GAIT_fnc_blendNativeLocomotion', stop)
        blend = code.split("GAIT_fnc_blendNativeLocomotion = {", 1)[1].split("\n};", 1)[0]
        self.assertIn('switchMove [_target, _progress, _blend, false]', blend)
        self.assertEqual(code.count('call GAIT_fnc_switchToLocomotionIdle'), 1)
        self.assertNotIn("_GAITRelease", self.text)
        self.assertNotIn("GAIT_fnc_braceLocomotionDecision", code)
        self.assertNotIn("GAIT_slopeBraceStage", code)

    def test_release_jog_keeps_live_redirects_after_entry(self):
        source = (CONFIG.parent / "functions/fn_slopeLocomotion.sqf").read_text()
        tick = source.split("GAIT_fnc_tickLocomotion = {", 1)[1].split("\n};", 1)[0]
        self.assertRegex(tick, r'if \(_requested && \{_eligible\} &&\s*'
                         r'\{\[_unit, _input, _gaitIntent, _returnMode, _modeChanged\] call GAIT_fnc_redirectLocomotionEntryDirection\}\)')
        redirect = source.split("GAIT_fnc_redirectLocomotionEntryDirection = {", 1)[1].split("\n};", 1)[0]
        self.assertIn('GAIT_directionChangedThisFrame', redirect)
        self.assertIn('call GAIT_fnc_releaseJogRedirectNeeded', redirect)
        self.assertIn('[_unit, _target] call GAIT_fnc_requestLocomotionMove', redirect)

    def test_entry_release_and_native_action_compatibility(self):
        for name, (_, body) in self.states.items():
            family = properties(body)["GAIT_slopeFamily"]
            pose = name[4:8]
            incoming = {target for target, _ in edges(body, "InterpolateFrom")}
            outgoing = {target for target, _ in edges(body, "InterpolateTo")}
            required = {f"Amov{pose}Mstp{family}Dnon"}
            required |= {f"Amov{pose}{pace}{family}{direction}" for pace in ("Mwlk", "Mrun") for direction in DIRECTIONS}
            if (pose, family) != ("Pknl", "SlowWpst"):
                sprint_family = "SlowWlnr" if family == "SrasWlnr" else family
                required |= {f"Amov{pose}Meva{sprint_family}{direction}" for direction in FORWARD}
            self.assertTrue(required <= incoming, name)
            self.assertTrue(required <= outgoing, name)
            if (pose, family) == ("Perc", "SlowWrfl"):
                variants = {f"AmovPerc{pace}{family}{direction}_ver2" for pace in ("Mwlk", "Mtac") for direction in DIRECTIONS}
                self.assertTrue(variants <= incoming)
                self.assertTrue(variants <= outgoing)
                animate_combat = {f"AmovPercMtac{family}{direction}" for direction in DIRECTIONS}
                self.assertTrue(animate_combat <= incoming)
                self.assertTrue(animate_combat <= outgoing)
            # Keep inherited medical/weapon/stance routes; do not replace the
            # unknown full native arrays or force an idle ConnectTo self-loop.
            self.assertNotRegex(body, r"\b(?:InterpolateTo|InterpolateFrom|ConnectTo|ConnectFrom)\[\]\s*=")
            self.assertNotRegex(body, r"\bConnectTo\[")
            for field in ("variantsPlayer", "variantsAI"):
                self.assertRegex(body, rf"\b{field}\[\]\s*=\s*\{{\s*\}};")

    def test_lowered_pistol_is_first_class_family(self):
        low_members = {
            name for name, (_, body) in self.states.items()
            if properties(body)["GAIT_slopeFamily"] == "SlowWpst"
        }
        raised_members = {
            name for name, (_, body) in self.states.items()
            if properties(body)["GAIT_slopeFamily"] == "SrasWpst"
        }
        self.assertEqual(len(low_members), 66)
        self.assertEqual(len(raised_members), 66)
        self.assertTrue(all("SlowWpst" in name for name in low_members))
        self.assertTrue(all("SrasWpst" in name for name in raised_members))
        self.assertFalse(low_members & raised_members)
        self.assertIn("AmovPercMevaSlowWpstDf_GAIT", low_members)
        self.assertIn("AmovPercMrunSlowWpstDl_GAITSprint", low_members)
        self.assertIn("AmovPercMrunSlowWpstDf_GAIT", low_members)
        self.assertIn("AmovPercMstpSlowWpstDnon", dict(edges(self.states["AmovPercMevaSlowWpstDf_GAIT"][1], "InterpolateTo")))
        self.assertIn("AmovPknlMrunSlowWpstDf_GAITSprint", low_members)
        self.assertIn("AmovPknlMevaSrasWpstDf_GAIT", raised_members)
        self.assertIn("AmovPknlMwlkSlowWpstDf_GAIT", low_members)



if __name__ == "__main__":
    unittest.main(verbosity=2)
