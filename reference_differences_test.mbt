///|
/// UCUM 2.2 §§28-30: mole is a count, not an additional independent dimension.
test "standard basis and definition factors differ from NLM semantic guards" {
  let e = @ucum.Engine::new()
  assert_true(e.convert(1.0, "mol", "1").is_close(6.02214076e23))
  assert_true(e.convert(1.0, "eq", "mol").is_close(1.0))
  assert_true(e.convert(1.0, "osm", "mol").is_close(1.0))
  assert_true(e.convert(1.0, "kat", "s-1").is_close(6.02214076e23))
  assert_true(e.convert(1.0, "U", "s-1").is_close(6.02214076e23 / 60000000.0))
  assert_true(e.convert(1.0, "Bd", "s-1").is_close(1.0))
  assert_true(e.convert(1.0, "[diop]", "m-1").is_close(1.0))
  assert_true(e.convert(1.0, "[mesh_i]", "m-1").is_close(1.0 / 0.0254))
}

///|
/// UCUM 2.2 tables 18 and 21, and §43 formula for degree Réaumur.
test "standard table values and Reaumur origin" {
  let e = @ucum.Engine::new()
  assert_true(e.convert(1.0, "[LPF]", "1").is_close(100.0))
  assert_true(e.convert(1.0, "[NTU]", "1").is_close(1.0))
  assert_true(e.convert(1.0, "[FNU]", "1").is_close(1.0))
  assert_true(e.convert(0.0, "[degRe]", "K").is_close(273.15))
  assert_true(e.convert(80.0, "[degRe]", "K").is_close(373.15))
}

///|
test "resource bounds and cache encapsulation" {
  let e = @ucum.Engine::new()
  let long = "m.".repeat(256) + "m"
  let deep = "(".repeat(33) + "m" + ")".repeat(33)
  for input in [long, deep, "m".repeat(4097)] {
    let limited = try {
      e.validate(input)
      false
    } catch {
      @ucum.Limit(_) => true
      _ => false
    }
    assert_true(limited)
  }
  let copy = e.normalize("m").exponents()
  copy[0] = 99
  assert_eq(e.normalize("m").basis(), "m")
  for input in ["(m.s)2", "(m){x}"] {
    let invalid = try {
      e.validate(input)
      false
    } catch {
      @ucum.Syntax(_, _) => true
      _ => false
    }
    assert_true(invalid)
  }
}
