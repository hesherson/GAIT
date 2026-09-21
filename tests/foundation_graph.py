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
    "SrasWrfl": ("GAIT_SlopeRifleRaisedActions", "RifleStandActions"),
    "SlowWrfl": ("GAIT_SlopeRifleLoweredActions", "RifleLowStandActions"),
    "SrasWpst": ("GAIT_SlopePistolActions", "PistolStandActions"),
    "SnonWnon": ("GAIT_SlopeUnarmedActions", "CivilStandActions"),
}
DIRECTIONS = {"Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"}
SELECTOR_DIRECTIONS = dict(zip(
    ("F", "LF", "L", "LB", "B", "RB", "R", "RF"),
    ("Df", "Dfl", "Dl", "Dbl", "Db", "Dbr", "Dr", "Dfr"),
))
FORWARD = {"Df", "Dfl", "Dfr"}


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
        cls.states = {name: (base, body) for name, base, body in blocks if name.endswith("_GAIT")}
        cls.stops = {name: (base, body) for name, base, body in blocks if name.endswith("_GAITStop")}
        cls.actions = {name: (base, body) for name, base, body in blocks if name.startswith("GAIT_Slope")}

    def test_real_native_clip_parents_and_controller_markers(self):
        self.assertEqual(len(self.states), 48)
        counts = {"idle": 0, "sprint": 0, "run": 0}
        for name, (parent, body) in self.states.items():
            with self.subTest(state=name):
                p = properties(body)
                match = re.fullmatch(r"AmovPerc(Mstp|Mrun|Meva)(\w{8})(Dnon|Df|Dfl|Dl|Dbl|Db|Dbr|Dr|Dfr)_GAIT", name)
                self.assertIsNotNone(match)
                pace, family, direction = match.groups()
                self.assertIn(family, FAMILIES)
                self.assertEqual(parent, name.removesuffix("_GAIT"))
                self.assertEqual(p["GAIT_nativeState"], parent)
                self.assertEqual(p["GAIT_slopeFamily"], family)
                expected_actions = FAMILIES[family][0]
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
                    self.assertEqual(pace, "Mrun")
                counts[{"Mstp": "idle", "Meva": "sprint", "Mrun": "run"}[pace]] += 1
                # Root motion, clip speed, brace timing and pose properties
                # remain inherited; this graph must not retune those values.
                self.assertNotRegex(body, r"\b(?:file|speed|duty|stamina|disableWeapons|headBobStrength)\s*=")
        self.assertEqual(counts, {"idle": 4, "sprint": 12, "run": 32})

    def test_default_stop_turn_and_every_direction_remain_in_family(self):
        self.assertEqual(len(self.actions), 4)
        for family, (actions, native_actions) in FAMILIES.items():
            parent, body = self.actions[actions]
            p = properties(body)
            self.assertEqual(parent, native_actions)
            idle = f"AmovPercMstp{family}Dnon_GAIT"
            for selector in ("Default", "Stop", "StopRelaxed", "TurnL", "TurnR", "TurnLRelaxed", "TurnRRelaxed"):
                self.assertEqual(p[selector], idle)
            for pace in ("Walk", "PlayerWalk", "Slow", "PlayerSlow", "Fast", "PlayerFast", "Tact", "PlayerTact"):
                for selector, direction in SELECTOR_DIRECTIONS.items():
                    fast = pace in ("Fast", "PlayerFast")
                    expected_pace = "Meva" if fast and direction in FORWARD else "Mrun"
                    self.assertEqual(p[pace + selector], f"AmovPerc{expected_pace}{family}{direction}_GAIT")
            # Medical, stance, weapon and vehicle selectors remain inherited.
            self.assertEqual(len(p), 71)

    def test_stop_targets_only_accelerate_interpolation(self):
        self.assertEqual(len(self.stops), 4)
        for family, (_, native_actions) in FAMILIES.items():
            native_idle = f"AmovPercMstp{family}Dnon"
            stop = native_idle + "_GAITStop"
            parent, body = self.stops[stop]
            self.assertEqual(parent, native_idle)
            self.assertEqual(properties(body)["actions"], native_actions)
            self.assertRegex(body, r"\binterpolationSpeed\s*=\s*8;")
            self.assertNotRegex(body, r"\b(?:speed|file|GAIT_slopeState|GAIT_slopeFamily)\s*=")
            for name, (_, move_body) in self.states.items():
                if properties(move_body)["GAIT_slopeFamily"] != family:
                    continue
                self.assertIn(stop, dict(edges(move_body, "InterpolateTo")))
                self.assertIn(stop, dict(edges(move_body, "InterpolateFrom")))
                self.assertIn(name, dict(edges(body, "InterpolateTo")))
                self.assertIn(name, dict(edges(body, "InterpolateFrom")))

    def test_idle_recovery_and_direction_reversals_have_direct_edges(self):
        for family in FAMILIES:
            members = {name for name, (_, body) in self.states.items() if properties(body)["GAIT_slopeFamily"] == family}
            self.assertEqual(len(members), 12)
            for source in members:
                pairs = edges(self.states[source][1], "InterpolateTo")
                names = [name for name, _ in pairs]
                self.assertEqual(len(names), len(set(names)))
                internal = {name for name in names if name.endswith("_GAIT")}
                self.assertEqual(internal, members - {source})
                for target, weight in pairs:
                    self.assertGreater(weight, 0)
                    self.assertLessEqual(weight, 0.025)
                    if target.endswith("_GAIT"):
                        self.assertIn(target, self.states)

    def test_live_handoffs_request_graph_without_switch_reset_or_walk_stage(self):
        source = (CONFIG.parent / "functions/fn_slopeLocomotion.sqf").read_text()
        code = re.sub(r"/\*.*?\*/|//[^\n]*", "", source, flags=re.S)
        self.assertNotRegex(code, r"\bswitchMove\b")
        self.assertEqual(len(re.findall(r"\bplayMoveNow\b", code)), 1)
        self.assertNotIn("GAIT_fnc_braceLocomotionDecision", code)
        self.assertNotIn("GAIT_slopeBraceStage", code)
        self.assertNotRegex(self.text, r"class AmovPercMwlk\w+_GAIT")

    def test_entry_release_and_native_action_compatibility(self):
        for name, (_, body) in self.states.items():
            family = properties(body)["GAIT_slopeFamily"]
            incoming = {target for target, _ in edges(body, "InterpolateFrom")}
            outgoing = {target for target, _ in edges(body, "InterpolateTo")}
            required = {f"AmovPercMstp{family}Dnon"}
            required |= {f"AmovPerc{pace}{family}{direction}" for pace in ("Mwlk", "Mrun") for direction in DIRECTIONS}
            required |= {f"AmovPercMeva{family}{direction}" for direction in FORWARD}
            self.assertTrue(required <= incoming, name)
            self.assertTrue(required <= outgoing, name)
            if family == "SlowWrfl":
                variants = {f"AmovPerc{pace}{family}{direction}_ver2" for pace in ("Mwlk", "Mtac") for direction in DIRECTIONS}
                self.assertTrue(variants <= incoming)
                self.assertTrue(variants <= outgoing)
            # Keep inherited medical/weapon/stance routes; do not replace the
            # unknown full native arrays or force an idle ConnectTo self-loop.
            self.assertNotRegex(body, r"\b(?:InterpolateTo|InterpolateFrom|ConnectTo|ConnectFrom)\[\]\s*=")
            self.assertNotRegex(body, r"\bConnectTo\[")
            for field in ("variantsPlayer", "variantsAI"):
                self.assertRegex(body, rf"\b{field}\[\]\s*=\s*\{{\s*\}};")

    def test_lowered_pistol_enters_without_a_native_pose_detour(self):
        lowered = {"AmovPercMstpSlowWpstDnon"}
        lowered |= {f"AmovPerc{pace}SlowWpst{direction}" for pace in ("Mrun", "Mwlk") for direction in DIRECTIONS}
        lowered |= {f"AmovPercMevaSlowWpst{direction}" for direction in FORWARD}
        for name, (_, body) in self.states.items():
            incoming = set(dict(edges(body, "InterpolateFrom")))
            outgoing = set(dict(edges(body, "InterpolateTo")))
            if properties(body)["GAIT_slopeFamily"] == "SrasWpst":
                self.assertTrue(lowered <= incoming, name)
                self.assertTrue(lowered <= outgoing, name)
            else:
                self.assertFalse(lowered & (incoming | outgoing), name)
        stop_body = self.stops["AmovPercMstpSrasWpstDnon_GAITStop"][1]
        self.assertTrue(lowered <= set(dict(edges(stop_body, "InterpolateFrom"))))
        self.assertTrue(lowered <= set(dict(edges(stop_body, "InterpolateTo"))))
        self.assertNotRegex(self.text, r"class AmovPerc\w*SlowWpst\w*_GAIT(?:Stop)?:")


if __name__ == "__main__":
    unittest.main(verbosity=2)
