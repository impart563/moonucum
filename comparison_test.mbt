///|
test "quantity comparison uses explicit units and caller tolerances" {
  let e = @ucum.Engine::new()
  assert_eq(
    e.compare_quantities(
      (12.0, "mg/dL"),
      (0.12, "g/L"),
      "g/L",
      relative_tolerance=1.0e-12,
    ),
    @ucum.Same,
  )
  assert_eq(
    e.compare_quantities((36.0, "Cel"), (310.15, "K"), "K"),
    @ucum.Lower,
  )
  assert_eq(
    e.compare_quantities(
      (1.0, "m"),
      (100.05, "cm"),
      "cm",
      absolute_tolerance=0.1,
    ),
    @ucum.Same,
  )
  assert_eq(e.compare_quantities((1.0, "m"), (100.05, "cm"), "cm"), @ucum.Lower)
  assert_eq(
    e.compare_quantities(
      (1.0, "m"),
      (1.0005, "m"),
      "m",
      relative_tolerance=0.001,
    ),
    @ucum.Same,
  )
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  assert_eq(
    ci.compare_quantities((1.0, "KPAL"), (999.0, "PAL"), "PAL"),
    @ucum.Higher,
  )
}

///|
test "comparison handles finite extremes and nonlinear coordinate direction" {
  let e = @ucum.Engine::new()
  assert_eq(
    e.compare_quantities(
      (1.0e308, "m"),
      (-1.0e308, "m"),
      "m",
      relative_tolerance=1.0,
    ),
    @ucum.Higher,
  )
  assert_eq(
    e.compare_quantities(
      (1.0e308, "m"),
      (1.001e308, "m"),
      "m",
      relative_tolerance=0.01,
    ),
    @ucum.Same,
  )
  assert_eq(
    e.compare_quantities((6.0, "[pH]"), (8.0, "[pH]"), "mol/L"),
    @ucum.Higher,
  )
  assert_eq(
    e.compare_quantities((6.0, "[pH]"), (8.0, "[pH]"), "[pH]"),
    @ucum.Lower,
  )
  for tolerance in [-1.0, 1.0 / 0.0, 0.0 / 0.0] {
    let rejected = try {
      ignore(
        e.compare_quantities(
          (1.0, "m"),
          (1.0, "m"),
          "m",
          relative_tolerance=tolerance,
        ),
      )
      false
    } catch {
      @ucum.Domain(_) => true
      _ => false
    }
    assert_true(rejected)
  }
  let mismatch = try {
    ignore(e.compare_quantities((1.0, "m"), (1.0, "s"), "m"))
    false
  } catch {
    @ucum.Incompatible(_, _) => true
    _ => false
  }
  assert_true(mismatch)
}

///|
test "interval membership respects both open boundaries and conversion errors" {
  let e = @ucum.Engine::new()
  let converter = e.converter("cm", "m")
  let interval = @ucum.Interval::new(
    1.0,
    2.0,
    lower_closed=false,
    upper_closed=false,
  )
  assert_eq(converter.classify(100.0, interval), @ucum.Below)
  assert_eq(converter.classify(150.0, interval), @ucum.Within)
  assert_eq(converter.classify(200.0, interval), @ucum.Above)
  assert_eq(
    converter.classify(100.0, @ucum.Interval::new(1.0, 1.0)),
    @ucum.Within,
  )
  assert_eq(
    e
    .converter("[pH]", "mol/L")
    .classify(7.0, @ucum.Interval::new(1.0e-8, 1.0e-6)),
    @ucum.Within,
  )
  let domain = try {
    ignore(
      e.converter("W", "dB[W]").classify(0.0, @ucum.Interval::new(0.0, 20.0)),
    )
    false
  } catch {
    @ucum.Domain(_) => true
    _ => false
  }
  assert_true(domain)
}
