///|
/// UCUM 2.2 §§45, 46, 48 and table 20. Expected values come from the
/// published inverse functions, independently of the implementation dispatch.
test "all logarithmic atom reference quantities" {
  let e = @ucum.Engine::new()
  let cases = [
    ("Np", 1.0, "1", 2.718281828459045),
    ("B", 2.0, "1", 100.0),
    ("bit_s", 8.0, "1", 256.0),
    ("B[SPL]", 0.0, "Pa", 0.00002),
    ("B[V]", 2.0, "V", 10.0),
    ("B[mV]", 2.0, "V", 0.01),
    ("B[uV]", 2.0, "V", 0.00001),
    ("B[10.nV]", 2.0, "V", 0.0000001),
    ("B[W]", 2.0, "W", 100.0),
    ("B[kW]", 1.0, "W", 10000.0),
    ("[pH]", 7.0, "mol/L", 0.0000001),
  ]
  for (source, value, target, expected) in cases {
    assert_true(
      e
      .convert(value, source, target)
      .is_close(expected, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
      msg=source,
    )
    assert_true(
      e
      .convert(expected, target, source)
      .is_close(value, relative_tolerance=1.0e-12, absolute_tolerance=1.0e-12),
      msg=source,
    )
  }
}

///|
test "level prefixes and scalar factors scale the measurement before the function" {
  let e = @ucum.Engine::new()
  assert_true(e.convert(20.0, "dB", "1").is_close(100.0))
  assert_true(e.convert(20.0, "dB[V]", "V").is_close(10.0))
  assert_true(e.convert(30.0, "dB[W]", "W").is_close(1000.0))
  assert_true(e.convert(1000.0, "mNp", "1").is_close(2.718281828459045))
  assert_true(e.convert(1.0, "2.B", "1").is_close(100.0))
  assert_true(e.convert(2.0, "B/2", "1").is_close(10.0))
  assert_true(e.convert(2.0, "%.B", "1").is_close(1.0471285480508996))
  assert_true(e.equivalent("10.dB", "B"))
  assert_true(e.equivalent("B{x}", "B{y}"))
}

///|
test "logarithmic reference shifts and compatible dimensions" {
  let e = @ucum.Engine::new()
  assert_true(
    e.convert(30.0, "dB[W]", "dB[kW]").is_close(0.0, absolute_tolerance=1.0e-12),
  )
  assert_true(e.convert(0.0, "B[V]", "B[mV]").is_close(6.0))
  assert_true(e.convert(1000.0, "mNp", "Np").is_close(1.0))
  assert_true(e.compatible("dB[SPL]", "kPa"))
  assert_true(e.compatible("[pH]", "umol/L"))
  assert_false(e.compatible("B[V]", "B[W]"))
  assert_false(e.equivalent("B[V]", "B[mV]"))
  assert_false(e.equivalent("B", "1"))
  assert_false(e.equivalent("B", "Np"))
}

///|
test "pH standard encoding supports positive concentration and negative logarithmic values" {
  let e = @ucum.Engine::new()
  assert_true(e.convert(-1.0, "[pH]", "mol/L").is_close(10.0))
  assert_true(e.convert(7.4, "[pH]", "umol/L").is_close(0.039810717055349734))
  assert_true(e.convert(1.0, "mmol/L", "[pH]").is_close(3.0))
  let incompatible = try {
    ignore(e.convert(7.0, "[pH]", "mg/dL"))
    false
  } catch {
    @ucum.Incompatible(_, _) => true
    _ => false
  }
  assert_true(incompatible)
}

///|
test "compiled converter reuses parsed expressions across values" {
  let e = @ucum.Engine::new()
  let converter = e.converter("dB[W]", "W")
  for
    (value, expected) in [
      (0.0, 1.0),
      (10.0, 10.0),
      (20.0, 100.0),
      (30.0, 1000.0),
    ] {
    assert_true(converter.apply(value).is_close(expected))
  }
  let linear = e.converter("mg/dL", "g/L")
  assert_true(linear.apply(12.0).is_close(0.12))
  assert_true(e.converter("Cel", "[degF]").apply(100.0).is_close(212.0))
  let identity = e.converter("dB", "dB")
  assert_true(identity.apply(10000.0).is_close(10000.0))
  assert_true(e.convert(10000.0, "dB", "B").is_close(1000.0))
}

///|
test "nonpositive quantities have a distinct logarithmic domain error" {
  let e = @ucum.Engine::new()
  for (source, target) in [("W", "dB[W]"), ("1", "Np"), ("mol/L", "[pH]")] {
    let converter = e.converter(source, target)
    for value in [-1.0, 0.0, -0.0] {
      let domain = try {
        ignore(converter.apply(value))
        false
      } catch {
        @ucum.Domain(_) => true
        _ => false
      }
      assert_true(domain, msg=target)
    }
    assert_true(converter.apply(1.0).is_close(e.convert(1.0, source, target)))
  }
}

///|
test "logarithmic numeric ranges avoid invalid intermediates and reject underflow" {
  let e = @ucum.Engine::new()
  for value in [10000.0, -10000.0] {
    let rejected = try {
      ignore(e.convert(value, "dB", "1"))
      false
    } catch {
      @ucum.NonFinite => true
      _ => false
    }
    assert_true(rejected)
  }
  assert_true(e.convert(1.0e300, "dB", "dB").is_close(1.0e300))
  assert_true(e.convert(1.0e308, "B", "B").is_close(1.0e308))
  assert_true(e.convert(1.0e300, "Ymol/L", "[pH]").is_close(-324.0))
  let nonfinite = try {
    ignore(e.converter("dB", "B").apply(0.0 / 0.0))
    false
  } catch {
    @ucum.NonFinite => true
    _ => false
  }
  assert_true(nonfinite)
}

///|
test "logarithmic constructions and linear normalization boundaries" {
  let e = @ucum.Engine::new()
  for input in ["B/s", "/B", "B2", "B.B", "Cel.B", "[pH].L"] {
    let unsupported = try {
      ignore(e.converter(input, input))
      false
    } catch {
      @ucum.Unsupported(_) => true
      _ => false
    }
    assert_true(unsupported, msg=input)
  }
  for input in ["B", "dB", "[pH]"] {
    let unsupported = try {
      ignore(e.normalize(input))
      false
    } catch {
      @ucum.Unsupported(_) => true
      _ => false
    }
    assert_true(unsupported, msg=input)
  }
  for input in ["[IU]", "[p'diop]", "[hp'_X]", "[m/s2/Hz^(1/2)]"] {
    let unsupported = try {
      ignore(e.converter(input, input))
      false
    } catch {
      @ucum.Unsupported(_) => true
      _ => false
    }
    assert_true(unsupported, msg=input)
  }
}
