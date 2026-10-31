///|
/// UCUM 2.2 §44: inverse 100tan is atan(x/100), in radians.
test "prism diopter and slope use the principal angle" {
  let e = @ucum.Engine::new()
  for code in ["[p'diop]", "%[slope]"] {
    assert_true(e.convert(100.0, code, "rad").is_close(0.7853981633974483))
    assert_true(e.convert(45.0, "deg", code).is_close(100.0))
    assert_true(e.convert(-45.0, "deg", code).is_close(-100.0))
    assert_true(e.convert(0.0, code, "rad").is_close(0.0))
    for angle in [-1.0, -0.5, 0.0, 0.5, 1.0] {
      assert_true(
        e
        .convert(e.convert(angle, "rad", code), code, "rad")
        .is_close(angle, absolute_tolerance=1.0e-12),
      )
    }
  }
  assert_true(e.equivalent("[p'diop]", "%[slope]"))
  assert_true(e.compatible("%[slope]", "deg"))
  assert_false(e.compatible("%[slope]", "%"))
  assert_true(e.convert(50.0, "2.%[slope]", "deg").is_close(45.0))
}

///|
test "tangent branch endpoints and finite precision are explicit errors" {
  let e = @ucum.Engine::new()
  for angle in [-180.0, -90.0, 90.0, 180.0] {
    let domain = try {
      ignore(e.convert(angle, "deg", "%[slope]"))
      false
    } catch {
      @ucum.Domain(_) => true
      _ => false
    }
    assert_true(domain)
  }
  for angle in [-1.5707963267948966, 1.5707963267948966] {
    let domain = try {
      ignore(e.convert(angle, "rad", "[p'diop]"))
      false
    } catch {
      @ucum.Domain(_) => true
      _ => false
    }
    assert_true(domain)
  }
  let precision = try {
    ignore(e.convert(1.0e308, "%[slope]", "rad"))
    false
  } catch {
    @ucum.NonFinite => true
    _ => false
  }
  assert_true(precision)
  assert_true(e.convert(1.0e308, "%[slope]", "[p'diop]").is_close(1.0e308))
}

///|
/// UCUM 2.2 §44 retains hpX/hpC/hpM/hpQ for the retired primed codes.
test "retired dilution functions use their recorded bases" {
  let e = @ucum.Engine::new()
  for
    (code, expected) in [
      ("[hp'_X]", 0.1),
      ("[hp'_C]", 0.01),
      ("[hp'_M]", 0.001),
      ("[hp'_Q]", 0.00002),
    ] {
    assert_true(
      e
      .convert(1.0, code, "1")
      .is_close(expected, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
      msg=code,
    )
    assert_true(e.convert(expected, "1", code).is_close(1.0), msg=code)
    assert_true(e.convert(0.0, code, "1").is_close(1.0), msg=code)
    let domain = try {
      ignore(e.convert(0.0, "1", code))
      false
    } catch {
      @ucum.Domain(_) => true
      _ => false
    }
    assert_true(domain)
  }
  assert_true(e.convert(4.0, "[hp'_X]", "[hp'_C]").is_close(2.0))
  assert_true(e.convert(1.0, "[hp'_C]", "[hp'_M]").is_close(2.0 / 3.0))
}

///|
test "current procedure-defined codes stay arbitrary" {
  let e = @ucum.Engine::new()
  for
    code in [
      "[hp_X]", "[hp_C]", "[hp_M]", "[hp_Q]", "[kp_X]", "[kp_C]", "[kp_M]", "[kp_Q]",
    ] {
    e.validate(code)
    let unsupported = try {
      ignore(e.converter(code, code))
      false
    } catch {
      @ucum.Unsupported(_) => true
      _ => false
    }
    assert_true(unsupported, msg=code)
  }
}

///|
/// UCUM §47: ASD's corresponding proper quantity is PSD in m2/s4/Hz.
test "spectral density uses the nonnegative square root branch" {
  let e = @ucum.Engine::new()
  let code = "[m/s2/Hz^(1/2)]"
  assert_true(e.convert(3.0, code, "m2/s4/Hz").is_close(9.0))
  assert_true(e.convert(16.0, "m2/s3", code).is_close(4.0))
  assert_true(e.convert(0.0, code, "m2/s3").is_close(0.0))
  assert_true(e.convert(0.0, "m2/s3", code).is_close(0.0))
  assert_true(e.compatible(code, "m2/s3"))
  assert_false(e.compatible(code, "m/s2"))
  for value in [0.0, 0.1, 1.0, 10.0, 1000.0] {
    assert_true(
      e
      .convert(e.convert(value, code, "m2/s3"), "m2/s3", code)
      .is_close(value, absolute_tolerance=1.0e-12),
    )
  }
  for (source, target) in [(code, "m2/s3"), ("m2/s3", code), (code, code)] {
    let domain = try {
      ignore(e.convert(-1.0, source, target))
      false
    } catch {
      @ucum.Domain(_) => true
      _ => false
    }
    assert_true(domain)
  }
}

///|
test "spectral density scaling preserves finite extreme results" {
  let e = @ucum.Engine::new()
  let code = "[m/s2/Hz^(1/2)]"
  assert_true(e.convert(2.0, "3." + code, "m2/s3").is_close(36.0))
  assert_true(e.convert(4.0, code + "/2", "m2/s3").is_close(4.0))
  assert_true(
    e
    .convert(1.0e200, code, "10*300.m2/s3")
    .is_close(1.0e100, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
  )
  assert_true(
    e
    .convert(1.0e-200, code, "10*-300.m2/s3")
    .is_close(1.0e-100, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
  )
  assert_true(
    e
    .convert(1.0e200, "10*300.m2/s3", code)
    .is_close(1.0e250, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
  )
  assert_true(
    e
    .convert(1.0e-300, "10*200." + code, "10*-200." + code)
    .is_close(1.0e100, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
  )
  for value in [1.0e200, 1.0e-200] {
    let range = try {
      ignore(e.convert(value, code, "m2/s3"))
      false
    } catch {
      @ucum.NonFinite => true
      _ => false
    }
    assert_true(range)
    assert_true(
      e
      .converter(code, code)
      .apply(value)
      .is_close(value, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
    )
  }
}

///|
test "new special mappings preserve composition and normalization boundaries" {
  let e = @ucum.Engine::new()
  for
    code in [
      "%[slope]", "[p'diop]", "[hp'_X]", "[hp'_C]", "[hp'_M]", "[hp'_Q]", "[m/s2/Hz^(1/2)]",
    ] {
    assert_true(e.equivalent(code, code))
    for expression in [code, code + ".s", "/" + code, code + "2"] {
      let unsupported = try {
        ignore(e.normalize(expression))
        false
      } catch {
        @ucum.Unsupported(_) => true
        _ => false
      }
      assert_true(unsupported, msg=expression)
    }
    let rejected = try {
      ignore(e.converter(code + ".s", code + ".s"))
      false
    } catch {
      @ucum.Unsupported(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}
