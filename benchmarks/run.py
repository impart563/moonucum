#!/usr/bin/env python3
"""Build once and measure released JavaScript operations, excluding compilation."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def command(args, env):
    return subprocess.check_output(args, cwd=str(ROOT), env=env, encoding="utf-8", errors="replace", timeout=180)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=20000)
    parser.add_argument("--repeats", type=int, default=5)
    args = parser.parse_args()
    if not 1000 <= args.iterations <= 1000000 or not 3 <= args.repeats <= 30:
        parser.error("iterations: 1000..1000000; repeats: 3..30")
    env = dict(os.environ, MOON_WORK="off", UCUM_BENCH_ITERATIONS=str(args.iterations))
    moon, node = shutil.which("moon"), shutil.which("node")
    if not moon or not node:
        raise SystemExit("MoonBit and Node.js are required")
    command([moon, "build", "--target", "js", "--release", "benchmarks"], env)
    executable = ROOT / "_build/js/release/build/benchmarks/benchmarks.js"
    run = lambda: json.loads(command([node, str(executable)], env))
    run()  # Untimed process warm-up; each recorded sample is a fresh process.
    samples = [run() for _ in range(args.repeats)]
    summaries = []
    for index, first in enumerate(samples[0]):
        rows = [sample[index] for sample in samples]
        if not all(row["name"] == first["name"] and row["operations"] == first["operations"] and row["checksum"] == first["checksum"] for row in rows):
            raise AssertionError("Inconsistent benchmark output")
        if any(row["elapsed_us"] <= 0 for row in rows):
            raise AssertionError("Timer resolution is insufficient")
        elapsed = statistics.median(row["elapsed_us"] for row in rows)
        summaries.append({"name": first["name"], "operations": first["operations"], "median_us": elapsed, "operations_per_second": first["operations"] * 1e6 / elapsed, "checksum": first["checksum"]})
    by_name = {row["name"]: row for row in summaries}
    if by_name["convert_reparse"]["checksum"] != by_name["converter_apply"]["checksum"]:
        raise AssertionError("Compiled and reparsed conversions differ")
    report = {
        "command": "python benchmarks/run.py --iterations {} --repeats {}".format(args.iterations, args.repeats),
        "environment": {"os": platform.system(), "architecture": platform.machine(), "processor": platform.processor(), "python": platform.python_version(), "node": command([node, "--version"], env).strip(), "moon": command([moon, "version"], env).strip()},
        "method": "JavaScript release; compilation excluded; one discarded process; fresh process per sample; internal monotonic microsecond timer; no performance pass threshold",
        "corpus": {"seed": 563, "proportional_expressions": 5000, "malformed_expressions": 1000, "test_command": "moon test --target all --filter '*corpus*'"},
        "samples": samples, "summary": summaries,
    }
    destination = ROOT / "benchmarks/results.json"
    destination.write_bytes((json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
    print(json.dumps(summaries, indent=2))


if __name__ == "__main__":
    main()
