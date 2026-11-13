#!/usr/bin/env python3

from pathlib import Path
from datetime import datetime
import argparse
import csv
import os
import re

# --------------------------------------------------
# Configuration
# --------------------------------------------------

HOME = Path.home() / "hpl-benchmark"
RESULTS = HOME / "results"

# HPL performance table
result_re = re.compile(
    r"^\s*(W\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)"
    r"\s+([0-9.eE+-]+)\s+([0-9.eE+-]+)\s*$",
    re.MULTILINE
)

# Numerical correctness check
check_re = re.compile(
    r"\)\s*=\s*([0-9.eE+-]+)\s+\.{3,}\s+(PASSED|FAILED)"
)

COLUMNS = [
    "System", "Date", "Experiment", "JobID", "Repeat",
    "N", "NB", "P", "Q",
    "Time_s", "Gflops", "Residual", "Status",
    "Output_file"
]


# --------------------------------------------------
# Find results on the selected system
# --------------------------------------------------

def get_result_files(system):
    user = os.environ["USER"]

    if system == "Aire":
        scratch = Path(
            os.environ.get("SCRATCH", f"/mnt/scratch/{user}")
        )
    else:
        scratch = Path(f"/scratch-calder/users/{user}")

    root = scratch / "hpl-benchmark" / system

    # New experiment folders on Scratch
    files = list(root.rglob("hpl_*.out")) if root.exists() else []

    # Include earlier baseline tests in bin/
    old = HOME / "hpl-2.3" / "bin" / system
    if old.exists():
        files.extend(old.glob("hpl_*.out"))

    return sorted(set(files))


# --------------------------------------------------
# Read one HPL output
# --------------------------------------------------

def parse_output(path, system):
    text = path.read_text(errors="replace")

    results = result_re.findall(text)
    checks = check_re.findall(text)

    # Identify Slurm job and array task
    match = re.search(
        r"_(\d+)(?:_(\d+))?\.out$", path.name
    )

    jobid = match.group(1) if match else ""
    repeat = match.group(2) or "" if match else ""

    # Experiment name and date
    experiment = path.parent.name

    if experiment == system:
        experiment = "original_baseline"

    date_match = re.match(r"(\d{4}-\d{2}-\d{2})", experiment)

    if date_match:
        date = date_match.group(1)
    else:
        date = datetime.fromtimestamp(
            path.stat().st_mtime
        ).strftime("%Y-%m-%d")

    common = {
        "System": system,
        "Date": date,
        "Experiment": experiment,
        "JobID": jobid,
        "Repeat": repeat,
        "Output_file": str(path)
    }

    # Record failed/empty outputs as well
    if not results:
        return [{
            **common,
            "N": "", "NB": "", "P": "", "Q": "",
            "Time_s": "", "Gflops": "",
            "Residual": "", "Status": "NO_RESULT"
        }]

    rows = []

    for i, result in enumerate(results):
        _, N, NB, P, Q, timing, gflops = result

        residual = ""
        status = "NO_CHECK"

        if i < len(checks):
            residual, status = checks[i]

        rows.append({
            **common,
            "Repeat": repeat or str(i + 1),
            "N": N,
            "NB": NB,
            "P": P,
            "Q": Q,
            "Time_s": timing,
            "Gflops": gflops,
            "Residual": residual,
            "Status": status
        })

    return rows


# --------------------------------------------------
# Collect and save CSV
# --------------------------------------------------

def collect(system):
    files = get_result_files(system)

    if not files:
        print(f"No HPL output files found for {system}")
        return

    rows = []

    for path in files:
        rows.extend(parse_output(path, system))

    RESULTS.mkdir(parents=True, exist_ok=True)
    output = RESULTS / f"hpl_results_{system}.csv"

    with output.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)

    passed = sum(r["Status"] == "PASSED" for r in rows)
    failed = sum(r["Status"] != "PASSED" for r in rows)

    print(f"System: {system}")
    print(f"Output files: {len(files)}")
    print(f"Records: {len(rows)}")
    print(f"Passed: {passed}")
    print(f"Other/failed: {failed}")
    print(f"Saved: {output}")


# --------------------------------------------------
# Main
# --------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "system", choices=["Aire", "Calder"]
    )

    args = parser.parse_args()
    collect(args.system)

