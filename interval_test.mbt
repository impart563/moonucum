///|
test "finite intervals preserve affine endpoints and boundary flags" {
  let e = @ucum.Engine::new()
  let input = @ucum.Interval::new(0.0, 100.0, upper_closed=false)
  let converter = e.converter("Cel", "[degF]")
  let result = converter.apply_interval(input)
  assert_true(result.lower.is_close(32.0))
  assert_true(result.upper.is_close(212.0))
  assert_true(result.lower_closed)
  assert_false(result.upper_closed)
  assert_true(converter.is_affine())
  assert_true(converter.is_increasing())
  assert_eq(input.lower, 0.0)
}

///|
test "decreasing pH intervals exchange endpoints and inclusion" {
  let converter = @ucum.Engine::new().converter("[pH]", "mol/L")
  assert_false(converter.is_affine())
  assert_false(converter.is_increasing())
  let result = converter.apply_interval(
    @ucum.Interval::new(6.0, 8.0, lower_closed=false),
  )
  assert_true(
    result.lower.is_close(
      1.0e-8,
      relative_tolerance=1.0e-12,
      absolute_tolerance=0.0,
    ),
  )
  assert_true(
    result.upper.is_close(
      1.0e-6,
      relative_tolerance=1.0e-12,
      absolute_tolerance=0.0,
    ),
  )
  assert_true(result.lower_closed)
  assert_false(result.upper_closed)
  let restored = @ucum.Engine::new()
    .converter("mol/L", "[pH]")
    .apply_interval(result)
  assert_true(restored.lower.is_close(6.0))
  assert_true(restored.upper.is_close(8.0))
  assert_false(restored.lower_closed)
}

///|
test "intervals reject empty reversed nonfinite and undefined endpoints" {
  for
    (lower, upper, closed) in [
      (2.0, 1.0, true),
      (1.0, 1.0, false),
      (0.0, 1.0 / 0.0, true),
    ] {
    let rejected = try {
      ignore(@ucum.Interval::new(lower, upper, lower_closed=closed))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let e = @ucum.Engine::new()
  let invalid = try {
    ignore(
      e
      .converter("W", "dB[W]")
      .apply_interval(@ucum.Interval::new(0.0, 1.0, lower_closed=false)),
    )
    false
  } catch {
    @ucum.Domain(_) => true
    _ => false
  }
  assert_true(invalid)
  let square = e
    .converter("[m/s2/Hz^(1/2)]", "m2/s3")
    .apply_interval(@ucum.Interval::new(0.0, 3.0))
  assert_eq(square.lower, 0.0)
  assert_true(square.upper.is_close(9.0))
  let tangent = e
    .converter("%[slope]", "deg")
    .apply_interval(@ucum.Interval::new(-100.0, 100.0))
  assert_true(tangent.lower.is_close(-45.0))
  assert_true(tangent.upper.is_close(45.0))
}
