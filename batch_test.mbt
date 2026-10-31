///|
test "bulk values retain row errors and preserve input" {
  let converter = @ucum.Engine::new().converter("W", "dB[W]")
  let values = [1.0, 0.0, 100.0, 0.0 / 0.0, 10.0]
  let rows = converter.apply_all(values)
  assert_eq(rows.length(), 5)
  assert_true(rows[0].unwrap().is_close(0.0, absolute_tolerance=1.0e-12))
  assert_true(rows[2].unwrap().is_close(20.0))
  assert_true(rows[4].unwrap().is_close(10.0))
  assert_true(rows[1] is Err(@ucum.Domain(_)))
  assert_true(rows[3] is Err(@ucum.NonFinite))
  assert_eq(values[2], 100.0)
  assert_eq(converter.apply_all([]).length(), 0)
}

///|
test "mixed batches cache pairs and report dimensional and lookup failures" {
  let engine = @ucum.Engine::new()
  let output = engine.convert_many([
    (12.0, "mg/dL", "g/L"),
    (1.0, "m", "s"),
    (1.0, "unknown", "m"),
    (24.0, "mg/dL", "g/L"),
    (2.0, "m", "s"),
    (0.0, "W", "dB[W]"),
    (100.0, "W", "dB[W]"),
  ])
  assert_true(output[0].unwrap().is_close(0.12))
  assert_true(output[3].unwrap().is_close(0.24))
  assert_true(output[1] is Err(@ucum.Incompatible("m", "s")))
  assert_eq(output[4], output[1])
  assert_true(output[2] is Err(@ucum.UnknownUnit(0, "unknown")))
  assert_true(output[5] is Err(@ucum.Domain(_)))
  assert_true(output[6].unwrap().is_close(20.0))
  assert_eq(engine.convert_many([]).length(), 0)
}
