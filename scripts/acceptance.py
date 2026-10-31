#!/usr/bin/env python3
"""Run reproducible library, catalog, CLI, packaging and consumer checks."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
TARGETS = ("wasm", "wasm-gc", "js", "native")
ENV = dict(os.environ, PYTHONUTF8="1", MOON_WORK="off")
MOON = shutil.which("moon")
COMMANDS = []


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def run(args, cwd=ROOT, env=ENV):
    completed = subprocess.run(
        [str(arg) for arg in args], cwd=str(cwd), env=env,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        encoding="utf-8", errors="replace", timeout=180,
    )
    if completed.returncode:
        raise RuntimeError("Command failed: " + str(args[0]) + "\n" + completed.stdout + completed.stderr)
    # Public evidence uses logical directories and executable names only.
    display = [Path(str(args[0])).name] + [str(arg) for arg in args[1:]]
    COMMANDS.append({"command": display, "directory": "project" if cwd == ROOT else "independent-consumer", "exit_code": 0})
    return completed.stdout


def cli(target, *args):
    output = run([MOON, "run", "--target", target, "cmd/ucum", "--"] + list(args))
    return [json.loads(line) for line in output.splitlines() if line.strip()]


def source_digest():
    digest = hashlib.sha256()
    count = 0
    excluded = {".git", "_build", "target", "node_modules", ".mooncakes", "__pycache__", "validation"}
    files = []
    for directory, directories, names in os.walk(str(ROOT)):
        directories[:] = [name for name in directories if name not in excluded]
        files.extend(Path(directory) / name for name in names)
    for path in sorted(files, key=lambda item: item.relative_to(ROOT).as_posix()):
        relative = path.relative_to(ROOT).as_posix()
        content = path.read_bytes()
        if relative.startswith("standards/"):
            normalized = content
        else:
            normalized = content.replace(b"\r\n", b"\n")
        digest.update(relative.encode("utf-8") + b"\0" + normalized + b"\0")
        count += 1
    return {"sha256": digest.hexdigest(), "files": count, "excludes": sorted(excluded)}


def verify_sources():
    manifest = json.loads((ROOT / "standards/sources.json").read_text(encoding="utf-8"))
    for entry in manifest:
        data = (ROOT / "standards" / entry["file"]).read_bytes()
        require(hashlib.sha256(data).hexdigest() == entry["sha256"], "upstream file changed: " + entry["file"])
    run([sys.executable, "scripts/embed_catalog.py", "--check"])
    run([sys.executable, "scripts/generate_upstream_tests.py", "--check"])
    require((ROOT / "README.md").read_bytes() == (ROOT / "README.mbt.md").read_bytes(), "README copies differ")
    require((ROOT / "LICENSE").is_file(), "project license is missing")
    return manifest


def verify_catalog():
    catalog = cli("wasm", "catalog")[0]
    xml = ET.parse(ROOT / "standards/ucum-essence.xml").getroot()
    atoms = xml.findall("{*}base-unit") + xml.findall("{*}unit")
    require(catalog["ucum_version"] == xml.get("version"), "catalog version mismatch")
    require(sorted(item.get("Code") for item in atoms) == sorted(item["code"] for item in catalog["units"]), "catalog symbols differ from XML")
    numeric = arbitrary = special = logarithmic = 0
    by_code = {item["code"]: item["normalization"] for item in catalog["units"]}
    convertible = {item["code"]: item["conversion_supported"] for item in catalog["units"]}
    logarithmic_codes = {"Np", "B", "B[SPL]", "B[V]", "B[mV]", "B[uV]", "B[10.nV]", "B[W]", "B[kW]", "bit_s", "[pH]"}
    for atom in atoms:
        result = by_code[atom.get("Code")]
        if atom.get("isArbitrary") == "yes":
            require(not result["ok"] and result["error"] == "unsupported", "arbitrary atom was numerically interpreted")
            arbitrary += 1
            require(not convertible[atom.get("Code")], "arbitrary atom has a converter")
        elif atom.get("Code") in logarithmic_codes:
            require(not result["ok"] and result["error"] == "unsupported", "logarithmic atom has a linear normalization")
            require(convertible[atom.get("Code")], "logarithmic converter missing")
            logarithmic += 1
        elif atom.get("isSpecial") == "yes" and atom.get("Code") not in ("Cel", "[degF]", "[degRe]"):
            require(not result["ok"] and result["error"] == "unsupported", "unimplemented special atom was interpreted")
            special += 1
            require(not convertible[atom.get("Code")], "unimplemented special atom has a converter")
        else:
            require(result["ok"], "numeric atom failed: " + atom.get("Code"))
            numeric += 1
            require(convertible[atom.get("Code")], "linear converter missing")
    require((len(atoms), numeric, logarithmic, arbitrary, special) == (312, 253, 11, 41, 7), "support counts changed")
    return {"version": xml.get("version"), "atoms": len(atoms), "prefixes": len(xml.findall("{*}prefix")), "numeric_atoms": numeric + logarithmic, "linear_normalization_atoms": numeric, "logarithmic_atoms": logarithmic, "arbitrary_atoms": arbitrary, "unimplemented_special_atoms": special}


def verify_target(target):
    output = run([MOON, "test", "--target", target, "--deny-warn"])
    match = re.search(r"Total tests: (\d+), passed: (\d+), failed: (\d+)", output)
    require(match and match[1] == match[2] and match[3] == "0", "missing successful test summary")
    requests = [
        {"op": "convert", "value": 12, "source": "mg/dL", "target": "g/L"},
        {"op": "convert", "value": 90, "source": "mg/dL", "target": "mmol/L"},
        {"op": "normalize", "unit": "[IU]"},
        {"op": "validate", "unit": "m/"},
        {"op": "validate", "unit": "m/unknown"},
        {"op": "equivalent", "source": "N", "target": "kg.m/s2"},
    ]
    rows = cli(target, "batch", *[json.dumps(item, separators=(",", ":")) for item in requests])
    require(len(rows) == 6 and rows[0]["ok"] and abs(rows[0]["value"] - 0.12) < 1e-12, "CLI conversion failed")
    require([row.get("error") for row in rows[1:5]] == ["incompatible", "unsupported", "syntax", "unknown_unit"], "CLI error classification failed")
    require(rows[3]["offset"] == 2 and rows[4]["offset"] == 2 and rows[5]["equivalent"], "CLI diagnostics failed")
    malformed = cli(target, "batch", "{", json.dumps({"op": "other"}))
    require([item["error"] for item in malformed] == ["json", "request"], "request error handling failed")
    nonlinear = cli(target, "batch", *[json.dumps(item) for item in [
        {"op": "convert", "value": 7, "source": "[pH]", "target": "mol/L"},
        {"op": "convert", "value": 30, "source": "dB[W]", "target": "W"},
        {"op": "convert", "value": 0, "source": "W", "target": "dB[W]"},
        {"op": "convert", "value": 10000, "source": "dB", "target": "B"},
        {"op": "normalize", "unit": "B"},
    ]])
    require(len(nonlinear) == 5 and nonlinear[0]["ok"] and abs(nonlinear[0]["value"] - 1e-7) < 1e-18, "pH conversion failed")
    require(nonlinear[1]["ok"] and abs(nonlinear[1]["value"] - 1000) < 1e-8, "level conversion failed")
    require(nonlinear[2].get("error") == "domain" and nonlinear[3]["ok"] and abs(nonlinear[3]["value"] - 1000) < 1e-8 and nonlinear[4].get("error") == "unsupported", "nonlinear range/domain contract failed")
    fhir = [json.loads(line) for line in run([MOON, "run", "--target", target, "examples/fhir"]).splitlines()]
    require([item["result"]["status"] for item in fhir] == ["converted", "converted", "rejected", "converted", "rejected"], "FHIR example failed")
    require(abs(fhir[3]["result"]["value"] - 1e-7) < 1e-18, "FHIR acidity conversion failed")
    sensors = [json.loads(line) for line in run([MOON, "run", "--target", target, "examples/sensor"]).splitlines()]
    require([item["value"] for item in sensors[:4]] == [20, 20, 101.325, 65536] and len(sensors) == 5 and abs(sensors[4]["value"] - 1000) < 1e-8, "sensor example failed")
    return {"tests": int(match[1]), "passed": int(match[2]), "upstream_validation_cases": 529, "cli_checks": 13, "fhir_rows": 5, "sensor_rows": 5}


def verify_packaged_consumer():
    run([MOON, "package"])
    version = re.search(r'^version\s*=\s*"([^"]+)"', (ROOT / "moon.mod").read_text(encoding="utf-8"), re.M).group(1)
    archives = list((ROOT / "_build/publish").glob("impart563-moonucum-" + version + ".zip"))
    require(len(archives) == 1, "expected one package archive")
    archive = archives[0]
    with tempfile.TemporaryDirectory(prefix="moonucum consumer ") as temporary:
        base = Path(temporary)
        module = base / "module"
        module.mkdir()
        with ZipFile(archive) as packed:
            for name in packed.namelist():
                relative = Path(name.replace("\\", "/"))
                require(not relative.is_absolute() and ".." not in relative.parts and ":" not in str(relative), "unsafe archive member")
                require(not any(part in ("node_modules", ".git", "__pycache__") for part in relative.parts), "private build content in archive")
            packed.extractall(module)
        require(hashlib.sha256((module / "standards/ucum-essence.xml").read_bytes()).hexdigest() == json.loads((ROOT / "standards/sources.json").read_text(encoding="utf-8"))[0]["sha256"], "archive changed catalog bytes")
        consumer = base / "consumer"
        shutil.copytree(str(ROOT / "examples/consumer"), str(consumer))
        workspace = base / "moon.work"
        workspace.write_text('members = ["module", "consumer"]\n', encoding="utf-8")
        env = dict(ENV, MOON_WORK=str(workspace))
        for target in TARGETS:
            output = run([MOON, "run", "--target", target, "."], cwd=consumer, env=env)
            require("Independent consumer passed" in output, "independent consumer failed")
            require("Logarithmic batch passed" in output, "independent logarithmic consumer failed")
    return {"source": "extracted package archive", "targets": list(TARGETS), "registry_install": "not performed", "archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--with-reference", action="store_true")
    parser.add_argument("--record", default="validation/acceptance-results.json")
    args = parser.parse_args()
    require(MOON is not None, "moon executable is required")
    verify_sources()
    run([MOON, "fmt", "--check"])
    run([MOON, "check", "--deny-warn"])
    interfaces = {path.relative_to(ROOT).as_posix(): path.read_bytes() for path in ROOT.rglob("pkg.generated.mbti") if "_build" not in path.parts and ".mooncakes" not in path.parts}
    run([MOON, "info"])
    require(all((ROOT / name).read_bytes() == content for name, content in interfaces.items()), "generated interfaces were stale")
    catalog = verify_catalog()
    targets = {target: verify_target(target) for target in TARGETS}
    consumer = verify_packaged_consumer()
    reference = {"executed": False, "command": "npm ci --ignore-scripts && python scripts/acceptance.py --with-reference"}
    if args.with_reference:
        npm = shutil.which("npm.cmd") or shutil.which("npm")
        require(npm is not None, "npm is required for reference checks")
        run([npm, "test"])
        report = json.loads((ROOT / "validation/differential-results.json").read_text(encoding="utf-8"))
        require(not report["failures"], "unexpected reference differences")
        reference = {"executed": True, "implementation": report["reference"], "cases": report["cases"], "matched": report["matched"], "reviewed_standard_differences": report["reviewed_standard_differences"], "unexpected_differences": len(report["failures"])}
    report = {"status": "passed", "command": "python scripts/acceptance.py" + (" --with-reference" if args.with_reference else ""), "platform": {"system": platform.system(), "machine": platform.machine()}, "toolchain": run([MOON, "version"]).strip(), "source": source_digest(), "catalog": catalog, "backends": targets, "packaged_consumer": consumer, "reference_comparison": reference, "commands": COMMANDS}
    destination = ROOT / args.record
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("status", "catalog", "backends", "packaged_consumer", "reference_comparison")}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
