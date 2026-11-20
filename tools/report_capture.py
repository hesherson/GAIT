"""Summarize GAIT captures, interruption stalls, and comparable pace windows."""

import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import re
import statistics


RECORD = re.compile(
    r'^([0-9:]+) "\[GAIT_FOUNDATION\] \[(\d+),(\d+),""(\w+)"",(\d+),(\d+),""(.*)""\]"$'
)


def read_capture(path):
    chunks = defaultdict(dict)
    headers = {}
    # Mission restarts in one RPT can reuse both capture ID and sequence.
    generation = Counter()
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig", errors="replace").splitlines(), 1):
        match = RECORD.match(line)
        if match is None:
            continue
        wall, capture, sequence, kind, part, total, payload = match.groups()
        if kind == "START" and int(part) == 0:
            generation[capture] += 1
        key = (int(capture) + max(0, generation[capture] - 1) * 1000000, int(sequence), kind)
        chunks[key][int(part)] = payload
        if int(part) == 0:
            headers[key] = (wall, line_number, int(total))
    records = []
    incomplete = 0
    for key, (wall, line, total) in headers.items():
        if set(chunks[key]) != set(range(total)):
            incomplete += 1
            continue
        payload = "".join(chunks[key][index] for index in range(total))
        try:
            data = json.loads(payload.replace('""""', '"'))
        except json.JSONDecodeError:
            incomplete += 1
            continue
        records.append((key, line, data))
    return sorted(records, key=lambda record: record[1]), incomplete


def distance_trial(rows, trial):
    """Time from first movement input at rest to horizontal displacement along a straight run."""
    result = {"requested": trial, "status": "no launch from rest", "markers": {}}
    start = previous = None
    burst = False
    held_sprint = False
    brace = None
    for row in rows:
        tick, _, _, inputs = row[:4]
        pos = row[21][3][:2]
        reserve = row[22][1]
        if start is None:
            if previous and 0 < tick - previous[0] <= 0.3 and previous[7][1] < 0.25 and previous[3][0] <= 0.05 and inputs[0] > 0.05:
                start = previous
                start_time, origin = start[0], start[21][3][:2]
                for frame in row[23] if len(row) > 23 else []:
                    if frame[8] and start_time <= frame[0] <= tick:
                        start_time, origin = frame[0], frame[8][:2]
                        break
                result.update(status="incomplete", kit_lb=row[10][0], start_reserve=start[22][1])
                if len(row[7]) > 10:
                    result["weapon"] = row[7][10]
                last_distance = 0
            else:
                previous = row
                continue
        if tick - previous[0] > 0.3 or row[21][2] != start[21][2] or not row[6][0] or inputs[0] <= 0.05:
            break
        if (tick - start_time > 0.6 and not inputs[2]) or abs(row[10][0] - result["kit_lb"]) > 1:
            result["status"] = "input or kit changed"
            break
        if "weapon" in result and row[7][10] != result["weapon"]:
            result["status"] = "weapon changed"
            break
        distance = math.dist(origin, pos)
        if math.dist(previous[21][3][:2], pos) > 12 * (tick - previous[0]) + 0.25:
            break
        if row[22][0] and not burst:
            brace = row[22][3]
        burst |= row[22][0]
        if brace is None and row[8][0]:
            brace = row[8][2]
        held_sprint |= inputs[2]
        for marker in (10, 30):
            if last_distance < marker <= distance and str(marker) not in result["markers"]:
                fraction = (marker - last_distance) / (distance - last_distance)
                crossing = previous[0] + fraction * (tick - previous[0])
                at_reserve = previous[22][1] + fraction * (reserve - previous[22][1])
                result["markers"][str(marker)] = {"seconds": round(crossing - start_time, 2),
                    "reserve_spent_pct": round(100 * (start[22][1] - at_reserve), 1)}
        if "30" in result["markers"]:
            result["status"] = "complete" if held_sprint and burst == (trial == "burst") else "input mismatch"
            break
        last_distance = distance
        previous = row
    result.update(burst_observed=burst, configured_brace_s=brace)
    return result


def input_responses(rows):
    """Match frame-observed input edges to body motion, retaining superseded presses."""
    results = []
    pending = {}
    prior = None
    last_side = 0
    last_side_time = 0
    for row in rows:
        if len(row) <= 23:
            continue
        for tick, side, crouch, lateral, moving_crouch, stance, valid, turbo, _ in row[23]:
            if prior is None or not valid or not prior[3] or tick - prior[0] > 0.25:
                pending.clear()
                last_side = 0
            else:
                direction = int(side > 0.05) - int(side < -0.05)
                edges = []
                if direction:
                    if not turbo and last_side == -direction and tick - last_side_time <= 0.3:
                        edges.append(("strafe", direction))
                    last_side, last_side_time = direction, tick
                if not turbo and crouch and not prior[1] and prior[2] == "STAND":
                    edges.append(("crouch", 0))
                for kind, target in edges:
                    if kind in pending:
                        pending[kind]["status"] = "superseded"
                    event = {"kind": kind, "phase": row[21][6], "at": tick, "target": target, "status": "unresolved"}
                    results.append(event)
                    pending[kind] = event
                for kind, event in list(pending.items()):
                    if tick - event["at"] > 1.5:
                        del pending[kind]
                    elif kind == "strafe" and direction != event["target"]:
                        event["status"] = "released"
                        del pending[kind]
                    elif (kind == "strafe" and lateral * event["target"] > 0.15) or (kind == "crouch" and moving_crouch):
                        event.update(status="observed", ms=round(1000 * (tick - event["at"])))
                        del pending[kind]
            prior = (tick, crouch, stance, valid)
    return results


def summarize(paths):
    runs = []
    windows = defaultdict(list)
    stalls = []
    versions = Counter()
    identities = set()
    raw_samples = 0
    trials, responses = [], []
    for path in paths:
        records, incomplete = read_capture(path)
        labels = {}
        samples = 0
        previous = {}
        stopped = {}
        segments = {}
        captures = defaultdict(list)
        for (capture, sequence, kind), line, row in records:
            if kind == "START":
                labels[capture] = row[0]
                versions[row[1]] += 1
                continue
            if kind != "SAMPLE" or len(row) < 14:
                continue
            samples += 1
            if len(row) > 22:
                captures[capture].append(row)
            tick, frame, phase, inputs, animation, gesture, engine, pace = row[:8]
            moving = max(abs(inputs[0]), abs(inputs[1])) > 0.05
            ordinary = animation.lower().startswith(("amovperc", "amovpknl"))
            eligible = engine[0] and engine[6] == "HEALTHY" and not engine[7] and ordinary
            if len(row) > 19:
                raw_samples += 1
            if len(row) > 21:
                network = row[21]
                identities.add((network[1], network[2]))
                label = network[6]
            else:
                label = labels.get(capture, "unlabelled")
            prior = previous.get(capture)
            consecutive = prior is not None and 0 < tick - prior[0] <= 0.3
            stalled = moving and eligible and pace[1] < 0.15
            if stalled:
                start = stopped.get(capture, (tick, line))
                if not consecutive:
                    start = (tick, line)
                stopped[capture] = start
                if tick - start[0] >= 0.75:
                    stall = {
                        "file": str(path), "capture": capture, "line": start[1],
                        "seconds": round(tick - start[0], 2), "animation": animation,
                        "input": inputs,
                        "adjust_actions": row[19][5:9] if len(row) > 19 else None,
                    }
                    key = (str(path), capture, start[1])
                    if stalls and stalls[-1]["key"] == key:
                        stalls[-1] = {"key": key, **stall}
                    else:
                        stalls.append({"key": key, **stall})
            else:
                stopped.pop(capture, None)
            if moving and eligible and consecutive and pace[1] > 0.3 and abs(pace[0] - prior[1]) < 0.015:
                scope = (
                    str(path), capture, label, engine[1], animation.split("_")[0],
                    round(row[10][0] / 5) * 5, round(pace[2] / 2) * 2,
                    round(row[9][3] * 10) / 10,
                )
                prior_scope, segment = segments.get(capture, (None, 0))
                if scope != prior_scope:
                    segment += 1
                segments[capture] = (scope, segment)
                windows[scope + (segment,)].append((tick, pace[1]))
            else:
                prior_scope, segment = segments.get(capture, (None, 0))
                segments[capture] = (None, segment)
            previous[capture] = (tick, pace[0])
        for capture, rows in captures.items():
            context = {"file": str(path), "capture": capture, "label": labels.get(capture, "")}
            responses.extend({**context, **event} for event in input_responses(rows))
            for mode in ("ordinary", "burst"):
                trial_rows = [row for row in rows if row[21][6] == "distance " + mode]
                if trial_rows:
                    first = rows.index(trial_rows[0])
                    trials.append({**context, **distance_trial(rows[max(0,first-1):first] + trial_rows, mode)})
        runs.append({"file": str(path), "samples": samples, "incomplete_records": incomplete})
    pace_windows = []
    for key, values in windows.items():
        if len(values) < 10 or values[-1][0] - values[0][0] < 0.9:
            continue
        file, capture, label, stance, animation, mass, grade, reserve, segment = key
        pace_windows.append({
            "file": file, "capture": capture, "phase": label, "stance": stance,
            "animation": animation, "load_band_lb": mass, "grade_band_deg": grade,
            "reserve_band": reserve, "samples": len(values),
            "median_ms": round(statistics.median(value[1] for value in values), 3),
        })
    return {
        "runs": runs, "versions": dict(versions), "clients_observed": len(identities),
        "samples_with_raw_actions": raw_samples,
        "possible_input_stalls": [{key: value for key, value in stall.items() if key != "key"} for stall in stalls],
        "pace_windows": pace_windows,
        "distance_trials": trials, "input_responses": responses,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rpt", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, help="Write the complete JSON report")
    args = parser.parse_args()
    report = summarize(args.rpt)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    for run in report["runs"]:
        print(f'{Path(run["file"]).name}: {run["samples"]} samples, {run["incomplete_records"]} incomplete records')
    print(f'Builds {report["versions"]}')
    print(f'Clients observed {report["clients_observed"]}, raw-action samples {report["samples_with_raw_actions"]}')
    for trial in report["distance_trials"]:
        print(f'{trial["label"]} {trial["requested"]}: {trial["status"]}, brace {trial["configured_brace_s"]} s, markers {trial["markers"]}')
    for event in report["input_responses"]:
        print(f'{event["label"]} {event["phase"]} {event["kind"]}: {event.get("ms", event["status"])}' +
              (" ms" if event["status"] == "observed" else ""))
    print("Possible input stalls are observations that need in-game confirmation.")
    for stall in report["possible_input_stalls"][:20]:
        print(f'  {Path(stall["file"]).name} line {stall["line"]}: {stall["seconds"]} s, {stall["animation"]}, input {stall["input"]}')
    print(f'{len(report["pace_windows"])} pace windows available for matching route, pose, load, grade and reserve comparisons.')
    for window in report["pace_windows"][:30]:
        print(f'  {window["phase"]}: {window["animation"]}, {window["load_band_lb"]} lb, '
              f'{window["grade_band_deg"]} deg, reserve {window["reserve_band"]:.1f}, '
              f'{window["median_ms"]:.3f} m/s ({window["samples"]} samples)')


if __name__ == "__main__":
    main()
