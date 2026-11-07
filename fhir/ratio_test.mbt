///|
fn ratio_point(
  value : Double,
  code : String,
  id? : String = "component",
) -> Json {
  {
    "value": value,
    "code": code,
    "system": "http://unitsofmeasure.org",
    "id": id,
  }
}

///|
test "FHIR Ratio preserves significant denominator and component metadata" {
  let source : Json = {
    "id": "synthetic-ratio",
    "extension": [
      { "url": "https://example.org/ratio", "valueString": "synthetic" },
    ],
    "numerator": ratio_point(5.0, "mg", id="mass"),
    "denominator": ratio_point(10.0, "mL", id="volume"),
  }
  let output = @fhir.convert_ratio(@ucum.Engine::new(), source, "g", "L")
  match output {
    {
      "id": "synthetic-ratio",
      "extension": Array([_, ..]),
      "numerator": {
        "value": Number(numerator, ..),
        "code": "g",
        "id": "mass",
        ..
      },
      "denominator": {
        "value": Number(denominator, ..),
        "code": "L",
        "id": "volume",
        ..
      },
      ..
    } => {
      assert_true(numerator.is_close(0.005))
      assert_true(denominator.is_close(0.01))
    }
    _ => fail("Ratio must preserve both quantities and metadata")
  }
  assert_true(
    source
    is { "denominator": { "value": Number(10.0, ..), "code": "mL", .. }, .. },
  )
}

///|
test "FHIR Ratio does not cancel matching dimensionless components" {
  let output = @fhir.convert_ratio(
    @ucum.Engine::new(),
    {
      "numerator": ratio_point(1.0, "1"),
      "denominator": ratio_point(128.0, "1"),
    },
    "1",
    "1",
  )
  assert_true(
    output
    is {
      "numerator": { "value": Number(1.0, ..), .. },
      "denominator": { "value": Number(128.0, ..), .. },
      ..
    },
  )
  let zero = @fhir.convert_ratio(
    @ucum.Engine::new(),
    {
      "numerator": ratio_point(0.0, "g"),
      "denominator": ratio_point(-2.0, "mL"),
    },
    "mg",
    "L",
  )
  assert_true(
    zero
    is {
      "numerator": { "value": Number(0.0, ..), .. },
      "denominator": { "value": Number(value, ..), .. },
      ..
    } &&
    value < 0.0,
  )
}

///|
test "FHIR Ratio requires both numeric components and a representable denominator" {
  let e = @ucum.Engine::new()
  for
    source in [
      ({ "numerator": ratio_point(1.0, "g") } : Json),
      { "denominator": ratio_point(1.0, "mL") },
      { "extension": [{ "url": "https://example.org/absent" }] },
      {
        "numerator": ratio_point(1.0, "g"),
        "denominator": ratio_point(0.0, "g"),
      },
      {
        "numerator": ratio_point(1.0, "g"),
        "denominator": ratio_point(1.0e-320, "g"),
      },
    ] {
    let rejected = try {
      ignore(@fhir.convert_ratio(e, source, "g", "Gg"))
      false
    } catch {
      @fhir.Input(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "FHIR Ratio rejects comparators affine points and nonlinear units" {
  let e = @ucum.Engine::new()
  let comparator = try {
    ignore(
      @fhir.convert_ratio(
        e,
        {
          "numerator": {
            "value": 1,
            "code": "g",
            "system": "http://unitsofmeasure.org",
            "comparator": "<",
          },
          "denominator": ratio_point(1.0, "mL"),
        },
        "mg",
        "L",
      ),
    )
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(comparator)
  let affine = try {
    ignore(
      @fhir.convert_ratio(
        e,
        {
          "numerator": ratio_point(37.0, "Cel"),
          "denominator": ratio_point(1.0, "1"),
        },
        "K",
        "1",
      ),
    )
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(affine)
  for code in ["[pH]", "dB", "[IU]"] {
    let rejected = try {
      ignore(
        @fhir.convert_ratio(
          e,
          {
            "numerator": ratio_point(1.0, code),
            "denominator": ratio_point(1.0, "1"),
          },
          code,
          "1",
        ),
      )
      false
    } catch {
      @fhir.UnitConversion(@ucum.Unsupported(_)) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "FHIR Ratio keeps unit errors and code-mode restrictions" {
  let source : Json = {
    "numerator": ratio_point(1.0, "g"),
    "denominator": ratio_point(2.0, "mL"),
  }
  let e = @ucum.Engine::new()
  let mismatch = try {
    ignore(@fhir.convert_ratio(e, source, "m", "L"))
    false
  } catch {
    @fhir.UnitConversion(@ucum.Incompatible(_, _)) => true
    _ => false
  }
  assert_true(mismatch)
  let ci = try {
    ignore(
      @fhir.convert_ratio(
        @ucum.Engine::new(mode=@ucum.CaseInsensitive),
        source,
        "G",
        "L",
      ),
    )
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(ci)
  let target = try {
    ignore(@fhir.convert_ratio(e, source, "g", ""))
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(target)
}
