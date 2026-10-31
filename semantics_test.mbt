///|
test "catalog version and size" {
  let e = @ucum.Engine::new()
  assert_eq(e.atom_count(), 312)
  assert_eq(e.prefix_count(), 24)
}

///|
test "UCUM grammar and prefix boundaries" {
  let e = @ucum.Engine::new()
  for code in ["", "1", "/s", "kg.m/s2", "10*3/uL", "(mg/dL)", "m[H2O]", "mm[Hg]", "mL{specimen}", "{count}", "KiBy", "dam", "cm2", "s/m/g"] {
    e.validate(code)
  }
  for code in ["m/", "m..s", "mmHg", "m s", "碌g", "k[in_i]", "m{s", "{x}m", "[m", "m+", "g/12h", "MOL", "0.m"] {
    let rejected = try { e.validate(code); false } catch { _ => true }
    assert_true(rejected, msg=code)
  }
}

///|
test "AST preserves annotation while semantics ignores it" {
  assert_eq(@ucum.parse_expression("mg{x}"), @ucum.Annotation(@ucum.Symbol("mg", 0), "x"))
  assert_true(@ucum.Engine::new().equivalent("mg{x}", "mg{y}"))
}

///|
test "equivalence differs from commensurability" {
  let e = @ucum.Engine::new()
  assert_true(e.equivalent("N", "kg.m/s2"))
  assert_true(e.equivalent("mg/dL", "10.mg/L"))
  assert_true(e.compatible("mg/dL", "g/L"))
  assert_false(e.equivalent("mg/dL", "g/L"))
  assert_false(e.compatible("mg/dL", "mmol/L"))
  assert_false(e.compatible("rad", "1"))
}

///|
test "proportional conversion and left associative division" {
  let e = @ucum.Engine::new()
  assert_true(e.convert(12.0, "mg/dL", "g/L").is_close(0.12))
  assert_true(e.convert(1.0, "[in_i]", "cm").is_close(2.54))
  assert_true(e.convert(1.0, "KiBy", "bit").is_close(8192.0))
  assert_true(e.equivalent("s/m.g", "s.g/m"))
  assert_true(e.equivalent("s/m/g", "s/(m.g)"))
  assert_true(e.convert(120.0, "mm[Hg]", "kPa").is_close(15.99864, relative_tolerance=1.0e-10))
}

///|
test "temperature origin and prefix scaling" {
  let e = @ucum.Engine::new()
  assert_true(e.convert(0.0, "Cel", "K").is_close(273.15))
  assert_true(e.convert(32.0, "[degF]", "Cel").is_close(0.0, absolute_tolerance=1.0e-10))
  assert_true(e.convert(100.0, "Cel", "[degF]").is_close(212.0))
  assert_true(e.convert(1000.0, "mCel", "K").is_close(274.15))
  assert_true(e.convert(1.0, "2.Cel", "K").is_close(275.15))
  assert_true(e.convert(1.0, "Cel/2", "K").is_close(273.65))
}

///|
test "arbitrary and special units remain valid but cannot be silently normalized" {
  let e = @ucum.Engine::new()
  for code in ["[IU]", "[arb'U]", "[pH]", "dB", "Cel/s"] {
    e.validate(code)
    let unsupported = try { ignore(e.normalize(code)); false } catch { @ucum.Unsupported(_) => true; _ => false }
    assert_true(unsupported, msg=code)
  }
}

///|
test "incompatibility and diagnostic offsets" {
  let e = @ucum.Engine::new()
  let incompatible = try { ignore(e.convert(1.0, "mg", "s")); false } catch { @ucum.Incompatible("mg", "s") => true; _ => false }
  assert_true(incompatible)
  let unknown = try { e.validate("m/unknown"); false } catch { @ucum.UnknownUnit(2, "unknown") => true; _ => false }
  assert_true(unknown)
  let syntax = try { e.validate("m/"); false } catch { @ucum.Syntax(2, _) => true; _ => false }
  assert_true(syntax)
}

///|
test "limits and numeric overflow" {
  let e = @ucum.Engine::new()
  for code in ["m10001", "10*10000", "m10000.m", "m-10000/m"] {
    let rejected = try { ignore(e.normalize(code)); false } catch { _ => true }
    assert_true(rejected, msg=code)
  }
  let finite = try { ignore(e.convert(1.0 / 0.0, "m", "m")); false } catch { @ucum.NonFinite => true; _ => false }
  assert_true(finite)
}

///|
test "conversion round trips across measurement families" {
  let e = @ucum.Engine::new()
  for (a, b) in [("mm", "[in_i]"), ("mg/dL", "g/L"), ("Cel", "[degF]"), ("mm[Hg]", "Pa"), ("km/h", "m/s"), ("J", "cal_th"), ("KiBy", "bit")] {
    for x in [-40.0, 0.0, 1.0, 12.5, 1000.0] {
      let actual = e.convert(e.convert(x, a, b), b, a)
      assert_true(actual.is_close(x, relative_tolerance=1.0e-10, absolute_tolerance=1.0e-9), msg=a + " -> " + b)
    }
  }
}
