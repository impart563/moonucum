///|
test "FHIR adapter preserves comparator and unrelated metadata" {
  let source : Json = {
    "value": 12.0,
    "system": "http://unitsofmeasure.org",
    "code": "mg/dL",
    "unit": "milligrams per decilitre",
    "comparator": "<",
    "id": "synthetic-1",
    "extension": [
      { "url": "https://example.org/source", "valueString": "synthetic" },
    ],
  }
  let converted = @fhir.convert_quantity(@ucum.Engine::new(), source, "g/L")
  match converted {
    {
      "value": Number(value, ..),
      "code": "g/L",
      "unit": "g/L",
      "comparator": "<",
      "id": "synthetic-1",
      "extension": Array([_, ..]),
      ..
    } => assert_true(value.is_close(0.12))
    _ => fail("Quantity metadata or converted fields differ")
  }
  assert_true(source is { "value": Number(12.0, ..), "code": "mg/dL", .. })
}

///|
test "FHIR adapter separates shape and unit failures" {
  let e = @ucum.Engine::new()
  for
    source in [
      ({ "value": 1, "unit": "mg/dL" } : Json),
      { "value": 1, "system": "other", "code": "m" },
      {
        "value": 1,
        "system": "http://unitsofmeasure.org",
        "code": "m",
        "comparator": "=",
      },
      {
        "value": 1,
        "system": "http://unitsofmeasure.org",
        "code": "m",
        "_value": {},
      },
    ] {
    let rejected = try {
      ignore(@fhir.convert_quantity(e, source, "m"))
      false
    } catch {
      @fhir.Input(_) => true
      _ => false
    }
    assert_true(rejected)
  }
  let mismatch = try {
    ignore(
      @fhir.convert_quantity(
        e,
        { "value": 1, "system": "http://unitsofmeasure.org", "code": "m" },
        "s",
      ),
    )
    false
  } catch {
    @fhir.UnitConversion(@ucum.Incompatible(_, _)) => true
    _ => false
  }
  assert_true(mismatch)
}

///|
test "FHIR point quantities allow pH but nonlinear comparators need a domain" {
  let e = @ucum.Engine::new()
  let output = @fhir.convert_quantity(
    e,
    { "value": 7, "system": "http://unitsofmeasure.org", "code": "[pH]" },
    "mol/L",
  )
  match output {
    { "value": Number(value, ..), .. } =>
      assert_true(
        value.is_close(
          1.0e-7,
          relative_tolerance=1.0e-12,
          absolute_tolerance=0.0,
        ),
      )
    _ => fail("pH point conversion failed")
  }
  let rejected = try {
    ignore(
      @fhir.convert_quantity(
        e,
        {
          "value": 7,
          "system": "http://unitsofmeasure.org",
          "code": "[pH]",
          "comparator": ">",
        },
        "mol/L",
      ),
    )
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(rejected)
  let ci = try {
    ignore(
      @fhir.convert_quantity(
        @ucum.Engine::new(mode=@ucum.CaseInsensitive),
        { "value": 1, "system": "http://unitsofmeasure.org", "code": "M" },
        "M",
      ),
    )
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(ci)
}
