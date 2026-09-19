#!/usr/bin/env python3
"""Run GAIT SQF regressions against the actual helper sources in this checkout.

Example:
  python tools/run_regressions.py --sqfvm /path/to/sqfvm --output /tmp/gait-tests

SQF-VM is supplied by the caller, not bundled. Each suite gets an isolated VM.
Combined source, complete logs, source hashes and results are retained in the
output directory. No parser-only dummy commands are registered; the suites
do not simulate Arma's animation engine or physical movement.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


SUITES = {
    "uphill_brake": ("traversalHelpers", "uphillBrake"),
    "uphill_brake_handoff": ("slopeLocomotion",),
    "brace_momentum": ("braceMomentum",),
    "downhill_pace": ("slopePaceModel", "downhillPace"),
    "downhill_trip": ("downhillPace",),
    "locomotion_state_machine": ("traversalHelpers", "slopeLocomotion", "nativeController"),
    "locomotion_handoff": ("traversalHelpers", "slopeLocomotion"),
    "release_and_blend": ("traversalHelpers", "slopeLocomotion", "nativeController"),
    "input_and_ramp": ("traversalHelpers",),
    "ace_status_bridge": ("nativeController",),
    "native_stamina_ownership": ("nativeController",),
    "fatigue_visuals": ("fatigueVisuals",),
    "ace_fatigue_visual_bridge": ("aceFatigueVisualBridge",),
    "slope_direction": ("slopeLocomotion",),
    "slope_state_selection": ("slopeLocomotion",),
    "locomotion_pace": ("slopePaceModel", "locomotionPace"),
    "release_momentum": ("releaseMomentum",),
    "release_runtime": ("releaseMomentum", "slopeLocomotion", "nativeController"),
    "gear_inertia": ("gearInertia", "traversalHelpers", "uphillBrake"),
    "locomotion_coast": ("traversalHelpers", "slopeLocomotion"),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_suite(root: Path, executable: Path, output: Path,
              name: str, helpers: tuple[str, ...]) -> dict:
    paths = [root / "addons/gait/functions" / f"fn_{helper}.sqf" for helper in helpers]
    paths.append(root / "tests" / f"{name}.sqf")
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(path)
    sentinel = f"GAIT_REGRESSION_DONE {name}"
    combined = output / f"{name}.sqf"
    combined.write_text("\n".join(path.read_text(encoding="utf-8-sig") for path in paths)
                        + f'\ndiag_log "{sentinel}";\n', encoding="utf-8")
    command = [str(executable), "--automated", "--suppress-welcome", "--no-execute-print",
               "--no-work-print",
               "--max-runtime", "20000", "--input-sqf", str(combined)]
    try:
        result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=30, check=False)
        log = result.stdout
        returncode = result.returncode
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or b""
        log = raw.decode(errors="replace") if isinstance(raw, bytes) else raw
        log += "\nFAIL runner timeout\n"
        returncode = -1
    log_path = output / f"{name}.log"
    log_path.write_text(log, encoding="utf-8")
    diag_lines = [line for line in log.splitlines() if "[DIAG_LOG]" in line]
    evidence = [line for line in diag_lines if "PASS" in line]
    done = any(sentinel in line for line in diag_lines)
    errors = [line for line in log.splitlines()
              if re.search(r"\[(?:ERR|FAT|WRN)\]|\bFAIL(?:ED)?\b", line)]
    passed = returncode == 0 and done and bool(evidence) and not errors
    return {
        "suite": name, "status": "PASS" if passed else "FAIL",
        "returncode": returncode, "completion_seen": done, "evidence": evidence,
        "diagnostics": errors, "log": str(log_path), "combined": str(combined),
        "sources": {str(path.relative_to(root)): sha256(path) for path in paths},
        "command": command,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--sqfvm", default=os.environ.get("SQFVM", "sqfvm"))
    parser.add_argument("--output", type=Path,
                        help="Evidence directory; defaults to a new temporary directory")
    parser.add_argument("--suite", action="append", help="Run only named suite; may repeat")
    parser.add_argument("--extra-suite", action="append", default=[], metavar="NAME:HELPER,HELPER",
                        help="Additional suite and helper stems, e.g. gear_inertia:gearInertia,traversalHelpers")
    args = parser.parse_args()
    root = args.root.resolve()
    executable = shutil.which(args.sqfvm)
    if executable is None:
        parser.error("SQF-VM not found. Pass --sqfvm /path/to/sqfvm or set SQFVM.")
    suites = dict(SUITES)
    for specification in args.extra_suite:
        try:
            name, helper_list = specification.split(":", 1)
            helpers = tuple(helper_list.split(","))
        except ValueError:
            parser.error(f"Invalid extra suite: {specification}")
        if not re.fullmatch(r"[a-z_0-9]+", name) or any(
                not re.fullmatch(r"[A-Za-z_0-9]+", helper) for helper in helpers):
            parser.error(f"Invalid extra suite: {specification}")
        suites[name] = helpers
    names = args.suite or list(suites)
    if any(name not in suites for name in names):
        parser.error("Unknown suite; use --extra-suite to declare its dependencies.")
    output = args.output.resolve() if args.output else Path(tempfile.mkdtemp(prefix="gait-regressions-"))
    output.mkdir(parents=True, exist_ok=True)
    results = []
    for name in names:
        try:
            result = run_suite(root, Path(executable).resolve(), output, name, suites[name])
        except (OSError, ValueError) as error:
            result = {"suite": name, "status": "FAIL", "diagnostics": [str(error)]}
        results.append(result)
        print(f"{result['status']} {name}")
        if result["status"] != "PASS":
            for diagnostic in result.get("diagnostics", []):
                print("  " + diagnostic)
    report = output / "regression_report.json"
    report.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    print(f"Evidence: {report}")
    return int(any(result["status"] != "PASS" for result in results))


if __name__ == "__main__":
    sys.exit(main())
