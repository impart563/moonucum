///|
test "UCUM quantities participate in LunarUnits arithmetic" {
  let e = @ucum.Engine::new()
  let distance = @bridge.to_quantity(e, 72.0, "km")
  let duration = @bridge.to_quantity(e, 1.0, "h")
  let speed = distance.div(duration)
  assert_true(@bridge.from_quantity(e, speed, "m/s").is_close(20.0))
  let one_kg = @bridge.to_quantity(e, 1000.0, "g")
    .checked_to(@si.kilogram)
    .unwrap()
  assert_true(one_kg.value().is_close(1.0))
  let force = @bridge.to_unit(e, "N")
  assert_true(
    force.is_compatible(@si.kilogram.mul(@si.meter).div(@si.second.pow(2))),
  )
  assert_true(force.scale().is_close(1.0))
}

///|
test "bridge preserves charge angle and count semantics" {
  let e = @ucum.Engine::new()
  assert_true(@bridge.to_unit(e, "C").is_compatible(@si.ampere.mul(@si.second)))
  assert_false(@bridge.to_unit(e, "rad").is_compatible(@bridge.to_unit(e, "1")))
  assert_false(@bridge.to_unit(e, "mol").is_compatible(@si.mole))
  assert_true(@bridge.to_unit(e, "mol").dimension().is_dimensionless())
  assert_true(@bridge.to_unit(e, "K").is_compatible(@si.kelvin))
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  assert_true(
    @bridge.from_quantity(ci, @bridge.to_quantity(ci, 1000.0, "MM"), "M").is_close(
      1.0,
    ),
  )
}

///|
test "bridge rejects points nonlinear arbitrary and mismatched quantities" {
  let e = @ucum.Engine::new()
  for code in ["Cel", "[degF]", "[pH]", "dB", "[IU]"] {
    let rejected = try {
      ignore(@bridge.to_unit(e, code))
      false
    } catch {
      _ => true
    }
    assert_true(rejected, msg=code)
  }
  let mismatch = try {
    ignore(@bridge.from_quantity(e, @bridge.to_quantity(e, 1.0, "m"), "s"))
    false
  } catch {
    @bridge.Incompatible(_) => true
    _ => false
  }
  assert_true(mismatch)
  let invalid = try {
    ignore(@bridge.to_quantity(e, 1.0 / 0.0, "m"))
    false
  } catch {
    @bridge.NonFinite => true
    _ => false
  }
  assert_true(invalid)
}
