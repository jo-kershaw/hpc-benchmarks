#!/usr/bin/env python3
"""Collect Calder NVIDIA HPL GPU results into a reproducible CSV.

Run on Calder (no third-party Python packages required). Reads all slurm-*.out
files below the GPU runs directory; one CSV row per HPL test, including tests
within a single sweep job. Startup failures are retained as NO_RESULT rows.
Running again rebuilds the CSV without adding duplicate rows.
"""

import argparse
import csv
import getpass
import re
from pathlib import Path

FLOAT = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?"
# NVIDIA's WC0 rows have the standard HPL columns: N NB P Q Time Gflops.
RESULT = re.compile(
    rf"^\s*(?P<variant>W\S+)\s+(?P<N>\d+)\s+(?P<NB>\d+)\s+"
    rf"(?P<P>\d+)\s+(?P<Q>\d+)\s+(?P<time>{FLOAT})\s+"
    rf"(?P<gflops>{FLOAT})(?=\s|$)"
)
RESIDUAL = re.compile(
    rf"^\s*\|\|Ax-b\|\|_oo/.*?=\s*(?P<residual>{FLOAT})"
    rf"\s+\.+\s*(?P<status>PASSED|FAILED)\b"
)
JOB_ID = re.compile(r"slurm-(\d+)(?:_\d+)?\.out$")
DATE = re.compile(r"^(\d{4}-\d{2}-\d{2})")
NODE = re.compile(r"^Node:\s*(.+)$")
ERROR = re.compile(
    r"(error while loading shared libraries|Lmod has detected|"
    r"^\s*(?:ERROR:|srun: error:|bash: .*not found|Traceback))",
    re.IGNORECASE,
)
COLUMNS = [
    "System", "Date", "Experiment", "JobID", "Test", "GPUs", "Node",
    "N", "NB", "P", "Q", "Time_s", "Gflops", "Gflops_per_GPU",
    "Linear_56GPU_PFLOPS", "Residual", "Status", "Output_file",
    "Input_file", "Error",
]


def collect_log(log):
    run = log.parent
    job_match = JOB_ID.fullmatch(log.name)
    date_match = DATE.match(run.name)
    base = {key: "" for key in COLUMNS}
    base.update({
        "System": "Calder",
        "Date": date_match.group(1) if date_match else "",
        "Experiment": run.name,
        "JobID": job_match.group(1) if job_match else "",
        "Output_file": str(log),
        "Input_file": str(run / "HPL.dat") if (run / "HPL.dat").is_file() else "",
    })
    rows = []
    error = ""
    active = None

    with log.open(encoding="utf-8", errors="replace") as source:
        for line in source:
            line = line.strip()
            node = NODE.match(line)
            if node:
                base["Node"] = node.group(1)

            if not error and ERROR.search(line):
                error = line[:300]

            result = RESULT.match(line)
            if result:
                values = result.groupdict()
                gpus = int(values["P"]) * int(values["Q"])
                gflops = float(values["gflops"])
                active = base.copy()
                active.update({
                    "Test": len(rows) + 1,
                    "GPUs": gpus,  # One MPI process per GPU in these benchmarks
                    "N": values["N"],  # Actual N reported by HPL (not requested N)
                    "NB": values["NB"],
                    "P": values["P"],
                    "Q": values["Q"],
                    "Time_s": values["time"],
                    "Gflops": values["gflops"],
                    "Gflops_per_GPU": f"{gflops / gpus:.5f}",
                    # An ideal projection, never a measured system Rmax
                    "Linear_56GPU_PFLOPS": f"{gflops / gpus * 56 / 1_000_000:.6f}",
                    "Status": "NO_RESIDUAL",
                })
                rows.append(active)
                continue

            check = RESIDUAL.match(line)
            if check and active is not None and active["Status"] == "NO_RESIDUAL":
                active["Residual"] = check.group("residual")
                active["Status"] = check.group("status")
                active = None

    for row in rows:
        row["Node"] = base["Node"]
        if row["Status"] != "PASSED":
            row["Error"] = error

    if not rows:
        missing = base.copy()
        missing["Status"] = "NO_RESULT"
        missing["Error"] = error or "No HPL result row found in log"
        rows.append(missing)
    return rows


def main():
    user = getpass.getuser()
    default_runs = Path(f"/scratch-calder/users/{user}/hpl-benchmark/Calder/GPU/runs")
    default_output = Path.home() / "hpl-benchmark/results/gpu/hpl_gpu_results_Calder.csv"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=Path, default=default_runs, help="GPU runs directory")
    parser.add_argument("--output", type=Path, default=default_output, help="Destination CSV")
    args = parser.parse_args()

    if not args.runs.is_dir():
        parser.error(f"Runs directory not found: {args.runs}")

    logs = sorted(args.runs.rglob("slurm-*.out"))
    if not logs:
        parser.error(f"No slurm-*.out files found under: {args.runs}")

    records = []
    for log in logs:
        records.extend(collect_log(log))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    tmp_output = args.output.with_name(args.output.name + ".tmp")
    with tmp_output.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(records)
    tmp_output.replace(args.output)

    passed = sum(record["Status"] == "PASSED" for record in records)
    other = len(records) - passed
    missing_logs = [d for d in sorted(args.runs.iterdir())
                    if d.is_dir() and (d / "HPL.dat").is_file()
                    and not list(d.glob("slurm-*.out"))]
    print(f"GPU job output files: {len(logs)}")
    print(f"CSV records: {len(records)} (passed: {passed}, other: {other})")
    print(f"Run directories with HPL.dat but no Slurm log: {len(missing_logs)}")
    for directory in missing_logs:
        print(f"  Missing log: {directory.name}")
    print(f"Saved: {args.output}")


if __name__ == "__main__":
    main()
