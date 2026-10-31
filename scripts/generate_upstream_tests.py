#!/usr/bin/env python3
"""Translate the unchanged upstream validation cases into black-box tests."""
from pathlib import Path
import json
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
tests = ET.parse(ROOT / "standards/UcumFunctionalTests.xml").getroot()
lines = [
    "// Generated from unchanged FHIR UCUM test cases. See standards/sources.json.",
    "// Upstream BSD license: standards/FHIR-LICENSE.txt.",
    "",
    "///|",
    'test "FHIR upstream UCUM validation corpus" {',
    "  let engine = @ucum.Engine::new()",
    "  let cases : Array[(String, Bool, String)] = [",
]
for index, case in enumerate(tests.find("validation")):
    unit = json.dumps(case.get("unit"), ensure_ascii=False)
    valid = case.get("valid")
    label = json.dumps(str(index) + ":" + case.get("id"))
    lines.append(f"    ({unit}, {valid}, {label}),")
lines += [
    "  ]",
    "  for (unit, expected, id) in cases {",
    "    let actual = try {",
    "      engine.validate(unit)",
    "      true",
    "    } catch {",
    "      _ => false",
    "    }",
    '    assert_true(actual == expected, msg=id + " unit=" + unit)',
    "  }",
    "}",
]
content = "\n".join(lines) + "\n"
path = ROOT / "upstream_test.mbt"
if "--check" in sys.argv:
    assert path.read_text(encoding="utf-8") == content, "upstream tests are stale"
else:
    path.write_bytes(content.encode("utf-8"))
