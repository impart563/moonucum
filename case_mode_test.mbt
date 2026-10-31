///|
test "code systems distinguish both atom and prefix meanings" {
  let cs = @ucum.Engine::new()
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  assert_eq(cs.code_mode(), @ucum.CaseSensitive)
  assert_eq(ci.code_mode(), @ucum.CaseInsensitive)
  assert_eq(cs.atom_count(), 312)
  assert_eq(ci.atom_count(), 310)
  assert_eq(ci.codes().length(), 310)
  assert_eq(ci.prefix_count(), 24)
  assert_true(cs.convert(1.0, "Mm", "m").is_close(1000000.0))
  assert_true(ci.convert(1.0, "Mm", "M").is_close(0.001))
  assert_true(cs.convert(1.0, "PA", "A").is_close(1.0e15))
  assert_true(
    ci
    .convert(1.0, "PA", "A")
    .is_close(1.0e-12, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
  )
  assert_false(ci.compatible("Pa", "PAL"))
  assert_true(ci.convert(1.0, "PaL", "KpAl").is_close(0.001))
  let strict = try {
    cs.validate("PAL")
    false
  } catch {
    @ucum.UnknownUnit(0, "PAL") => true
    _ => false
  }
  assert_true(strict)
}

///|
test "canonical definition expansion remains isolated from the selected input mode" {
  let cs = @ucum.Engine::new()
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  for (code, canonical) in [("PaL", "Pa"), ("V", "V"), ("J", "J"), ("A", "A")] {
    let first = ci.normalize(code)
    let second = cs.normalize(canonical)
    assert_eq(first.exponents(), second.exponents(), msg=code)
    assert_true(
      first
      .factor()
      .is_close(
        second.factor(),
        relative_tolerance=1.0e-12,
        absolute_tolerance=0.0,
      ),
      msg=code,
    )
  }
  assert_true(ci.convert(20.0, "Db[V]", "V").is_close(10.0))
  assert_true(
    ci
    .convert(7.0, "[pH]", "Mol/l")
    .is_close(0.0000001, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
  )
  assert_true(ci.convert(100.0, "[P'DiOp]", "DeG").is_close(45.0))
  assert_true(ci.convert(3.0, "[m/S2/hz^(1/2)]", "M2/S3").is_close(9.0))
  for _ in 0..<3 {
    assert_true(cs.convert(1.0, "PA", "A").is_close(1.0e15))
    assert_true(ci.convert(1.0, "PaL", "PaL").is_close(1.0))
    assert_true(
      ci
      .convert(1.0, "PA", "A")
      .is_close(1.0e-12, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
    )
  }
}

///|
test "case-insensitive diagnostics and annotations preserve input spelling" {
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  let unknown = try {
    ci.validate("M/UnKnOwN")
    false
  } catch {
    @ucum.UnknownUnit(2, "UnKnOwN") => true
    _ => false
  }
  assert_true(unknown)
  assert_eq(
    @ucum.parse_expression("mG{SampleA}"),
    @ucum.Annotation(@ucum.Symbol("mG", 0), "SampleA"),
  )
  assert_true(ci.equivalent("mG{SampleA}", "Mg{sampleB}"))
  for code in ["[iU]", "[Hp_x]"] {
    ci.validate(code)
    let arbitrary = try {
      ignore(ci.convert(1.0, code, code))
      false
    } catch {
      @ucum.Unsupported(_) => true
      _ => false
    }
    assert_true(arbitrary)
  }
}
