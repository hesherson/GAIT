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
        cls.actions = {name: (base, body) for name, base, body in blocks if name.startswith("GAIT_Slope")}

    def test_real_native_clip_parents_and_controller_markers(self):
        self.assertEqual(len(self.states), 36)
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
                self.assertEqual(p["actions"], FAMILIES[family][0])
                self.assertRegex(body, r"\bGAIT_slopeState\s*=\s*1;")
                self.assertRegex(body, r"\blooped\s*=\s*1;")
                self.assertEqual(p["equivalentTo"], "")
                role = "idle" if direction == "Dnon" else "move"
                self.assertEqual(p["GAIT_locomotionRole"], role)
                wanted_pace = "Mstp" if role == "idle" else "Meva" if direction in FORWARD else "Mrun"
                self.assertEqual(pace, wanted_pace)
                counts[{"Mstp": "idle", "Meva": "sprint", "Mrun": "run"}[pace]] += 1
                # Root motion, clip speed, brace timing and pose properties
                # remain inherited; this graph must not retune those values.
                self.assertNotRegex(body, r"\b(?:file|speed|duty|stamina|disableWeapons|headBobStrength)\s*=")
        self.assertEqual(counts, {"idle": 4, "sprint": 12, "run": 20})

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
                    target = p[pace + selector]
                    expected_pace = "Meva" if direction in FORWARD else "Mrun"
                    self.assertEqual(target, f"AmovPerc{expected_pace}{family}{direction}_GAIT")
                    self.assertIn(target, self.states)
            # The opt-in action patch does not override medical, stance,
            # weapon, limping, falling, ladder, or vehicle actions.
            self.assertEqual(len(p), 71)

    def test_idle_recovery_and_direction_reversals_have_direct_edges(self):
        for family in FAMILIES:
            members = {name for name, (_, body) in self.states.items() if properties(body)["GAIT_slopeFamily"] == family}
            self.assertEqual(len(members), 9)
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
