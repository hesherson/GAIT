"""Exercise chunked old/new RPT records and the comparison report."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("report_capture", ROOT / "tools/report_capture.py")
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)


def record(sequence, kind, value):
    payload = json.dumps(value, separators=(",", ":")).replace('"', '""""')
    pieces = [payload[start:start + 400] for start in range(0, len(payload), 400)]
    return "\n".join(
        f'12:00:00 "[GAIT_FOUNDATION] [1,{sequence},""{kind}"",{index},{len(pieces)},""{piece}""]"'
        for index, piece in enumerate(pieces)
    )


def sample(tick, raw=False, speed=4):
    row = [tick, 100, "active", [1, 0, False], "amovpercmrunslowwrfldf_gait", "<none>",
           [True, "STAND", True, False, 0, 0, "HEALTHY", False],
           [1, speed, 0], [], [True, True, True, 1], [20], [], [], [], []]
    if raw:
        row += [[], [], [], [], [0, 0, 0, 0, 0, 1, 0, 0, 0],
                [tick, 0, "rifle", "walk", 2, 1.4, 3.9, 0.51, 0.3],
                [tick, 3, "3:1", [0, 0, 0], "STAND", 1, "wind-down"]]
    return row


class CaptureReporting(unittest.TestCase):
    def test_markers_reserve_and_burst_identity(self):
        rows = []
        for i in range(66):
            t = i / 10
            r = sample(t, raw=True, speed=5 if i else 0)
            r[3] = [int(i > 0), 0, i > 0]
            r[8] = [i == 1, 0.15, 0.07]
            r[21][3] = [5*t,0,0]
            r[21][6] = "distance burst"
            r.append([i > 0, 1-0.05*t, 1, 0.07])
            rows.append(r)
        result = REPORT.distance_trial(rows, "burst")
        self.assertEqual(result["status"], "complete")
        self.assertEqual(result["markers"]["10"], {"seconds":2.0,"reserve_spent_pct":10.0})
        self.assertEqual(result["markers"]["30"]["seconds"], 6.0)
        self.assertEqual(REPORT.distance_trial(rows,"ordinary")["status"], "input mismatch")
        self.assertEqual(REPORT.distance_trial(rows[:5]+rows[12:],"burst")["status"], "incomplete")

    def test_reversal_and_crouch_on_sprint_release(self):
        row = sample(1, raw=True)
        frames = [[0,1,False,1,False,"STAND",True,True,[]],
                  [.02,1,False,1,False,"STAND",True,True,[]],
                  [.04,-1,True,.5,False,"STAND",True,False,[]],
                  [.06,-1,False,-.6,False,"CROUCH",True,False,[]],
                  [.10,-1,False,-1,True,"CROUCH",True,False,[]]]
        row.extend([[],frames])
        events = REPORT.input_responses([row])
        self.assertEqual([(e["kind"],e["ms"]) for e in events], [("strafe",20),("crouch",60)])

    def report(self, rows):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.rpt"
            path.write_text("\n".join(rows), encoding="utf-8")
            return REPORT.summarize([path])

    def test_old_schema_remains_readable(self):
        report = self.report([record(0, "START", ["old", "alpha44"])] +
                             [record(i + 1, "SAMPLE", sample(i / 10)) for i in range(12)])
        self.assertEqual(report["runs"][0]["samples"], 12)
        self.assertEqual(report["runs"][0]["incomplete_records"], 0)
        self.assertEqual(report["samples_with_raw_actions"], 0)
        self.assertEqual(len(report["pace_windows"]), 1)

    def test_new_schema_tracks_ctrl_stall_and_client(self):
        report = self.report([record(0, "START", ["new", "alpha47"])] +
                             [record(i + 1, "SAMPLE", sample(i / 10, raw=True, speed=0)) for i in range(15)])
        self.assertEqual(report["samples_with_raw_actions"], 15)
        self.assertEqual(report["clients_observed"], 1)
        self.assertEqual(len(report["possible_input_stalls"]), 1)
        self.assertEqual(report["possible_input_stalls"][0]["adjust_actions"], [1, 0, 0, 0])
        self.assertAlmostEqual(report["possible_input_stalls"][0]["seconds"], 1.4)

    def test_incomplete_record_does_not_create_a_sample(self):
        row = sample(1, raw=True)
        row[21][6] = "phase" * 100
        report = self.report([record(0, "START", ["new", "alpha47"]),
                              record(1, "SAMPLE", row).splitlines()[0]])
        self.assertEqual(report["runs"][0]["samples"], 0)
        self.assertEqual(report["runs"][0]["incomplete_records"], 1)

    def test_distant_fragments_do_not_count_as_a_contiguous_pace_window(self):
        report = self.report([record(i + 1, "SAMPLE", sample(i * 2)) for i in range(15)])
        self.assertEqual(report["pace_windows"], [])


if __name__ == "__main__":
    unittest.main()
