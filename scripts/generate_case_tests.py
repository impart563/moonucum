#!/usr/bin/env python3
"""Generate code-mode cases directly from both normative XML code columns."""
from pathlib import Path
import json
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
xml = ET.parse(ROOT / "standards/ucum-essence.xml").getroot()
atoms = xml.findall("{*}base-unit") + xml.findall("{*}unit")
lines = [
    "// Generated from UCUM 2.2 Code/CODE columns; see standards/sources.json.",
    "// The standard data retains standards/UCUM-LICENSE.md.",
    "",
    "///|",
    'test "all catalog atom aliases in the case-insensitive code system" {',
    "  let cs = @ucum.Engine::new()",
    "  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)",
    "  let cases : Array[(String, String)] = [",
]
for atom in atoms:
    lines.append("    (" + json.dumps(atom.get("Code")) + ", " + json.dumps(atom.get("CODE")) + "),")
lines += [
    "  ]",
    "  for (canonical, single) in cases {",
    "    ci.validate(single)",
    "    ci.validate(single.to_upper())",
    "    ci.validate(single.to_lower())",
    "    let baseline = Some(cs.normalize(canonical)) catch {",
    "      @ucum.Unsupported(_) => None",
    "      error => raise error",
    "    }",
    "    if baseline is Some(baseline) {",
    "      let actual = ci.normalize(single)",
    "      assert_eq(actual.exponents(), baseline.exponents(), msg=canonical)",
    "      assert_true(",
    "        actual",
    "        .factor()",
    "        .is_close(",
    "          baseline.factor(),",
    "          relative_tolerance=1.0e-12,",
    "          absolute_tolerance=0.0,",
    "        ),",
    "        msg=canonical,",
    "      )",
    "      assert_eq(actual.origin(), baseline.origin(), msg=canonical)",
    "    }",
    "  }",
    "}",
    "",
    "///|",
    'test "all case-insensitive prefixes use the standard prefix factors" {',
    "  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)",
    "  let cases : Array[(String, Double)] = [",
]
for prefix in xml.findall("{*}prefix"):
    factor = repr(float(prefix.find("{*}value").get("value")))
    factor = re.sub(r"^(-?\d+)(e)", r"\1.0\2", factor)
    lines.append("    (" + json.dumps(prefix.get("CODE") + "M") + ", " + factor + "),")
lines += [
    "  ]",
    "  for (code, factor) in cases {",
    "    assert_true(",
    "      ci",
    '      .convert(1.0, code, "M")',
    "      .is_close(factor, relative_tolerance=1.0e-12, absolute_tolerance=0.0),",
    "      msg=code,",
    "    )",
    "  }",
    "}",
]
lines += [
    "",
    "///|",
    'test "all special atom functions preserve semantics in both code systems" {',
    "  let cs = @ucum.Engine::new()",
    "  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)",
    "  let cases : Array[(String, String, String, String)] = [",
]
for atom in atoms:
    if atom.get("isSpecial") != "yes":
        continue
    value = atom.find("{*}value")
    def proper(definition):
        return definition.split("(", 1)[1][:-1].split(" ", 1)[1]
    row = [atom.get("Code"), atom.get("CODE"), proper(value.get("Unit")), proper(value.get("UNIT"))]
    lines.append("    (" + ", ".join(json.dumps(item) for item in row) + "),")
lines += [
    "  ]",
    "  for (source, single, target, single_target) in cases {",
    "    let expected = cs.convert(1.0, source, target)",
    "    let actual = ci.convert(1.0, single, single_target)",
    "    assert_true(",
    "      actual.is_close(",
    "        expected,",
    "        relative_tolerance=1.0e-12,",
    "        absolute_tolerance=0.0,",
    "      ),",
    "      msg=source,",
    "    )",
    "  }",
    "}",
]
content = "\n".join(lines) + "\n"
path = ROOT / "case_catalog_test.mbt"
if "--check" in sys.argv:
    assert path.read_text(encoding="utf-8") == content, "code mode cases are stale"
else:
    path.write_bytes(content.encode("utf-8"))
