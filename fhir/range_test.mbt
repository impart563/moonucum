///|
fn range_bound(value : Double, code : String, id? : String = "bound") -> Json {
  {
    "value": value,
    "system": "http://unitsofmeasure.org",
    "code": code,
    "unit": code,
    "id": id,
  }
}

///|
test "FHIR Range converts inclusive bounds and preserves metadata" {
  let source : Json = {
    "id": "synthetic-range",
    "extension": [
      { "url": "https://example.org/range", "valueString": "synthetic" },
    ],
    "low": range_bound(0.0, "Cel", id="lower"),
    "high": range_bound(100.0, "Cel", id="upper"),
  }
  let converted = @fhir.convert_range(@ucum.Engine::new(), source, "[degF]")
  match converted {
    {
      "id": "synthetic-range",
      "extension": Array([_, ..]),
      "low": { "value": Number(low, ..), "code": "[degF]", "id": "lower", .. },
      "high": { "value": Number(high, ..), "code": "[degF]", "id": "upper", .. },
      ..
    } => {
      assert_true(low.is_close(32.0))
      assert_true(high.is_close(212.0))
    }
    _ => fail("Range conversion lost metadata or units")
  }
  assert_true(source is { "low": { "code": "Cel", .. }, .. })
}

///|
test "FHIR Range exchanges endpoint objects for decreasing mappings" {
  let converted = @fhir.convert_range(
    @ucum.Engine::new(),
    {
      "low": range_bound(6.0, "[pH]", id="pH-six"),
      "high": range_bound(8.0, "[pH]", id="pH-eight"),
    },
    "mol/L",
  )
  match converted {
    {
      "low": { "value": Number(low, ..), "id": "pH-eight", .. },
      "high": { "value": Number(high, ..), "id": "pH-six", .. },
      ..
    } => {
      assert_true(
        low.is_close(1.0e-8, relative_tolerance=1.0e-12, absolute_tolerance=0.0),
      )
      assert_true(
        high.is_close(
          1.0e-6,
          relative_tolerance=1.0e-12,
          absolute_tolerance=0.0,
        ),
      )
    }
    _ => fail("Decreasing Range endpoints were not exchanged")
  }
}

///|
test "FHIR Range keeps absent bounds unknown including reversed coordinates" {
  let e = @ucum.Engine::new()
  let low_only = @fhir.convert_range(
    e,
    { "low": range_bound(100.0, "cm") },
    "m",
  )
  assert_true(low_only is { "low": { "value": Number(1.0, ..), .. }, .. })
  match low_only {
    Object(fields) => assert_false(fields.contains("high"))
    _ => fail("object expected")
  }
  let reversed = @fhir.convert_range(
    e,
    { "low": range_bound(6.0, "[pH]") },
    "mol/L",
  )
  match reversed {
    Object(fields) => {
      assert_false(fields.contains("low"))
      assert_true(fields.contains("high"))
    }
    _ => fail("object expected")
  }
  let high_only = @fhir.convert_range(
    e,
    { "high": range_bound(8.0, "[pH]") },
    "mol/L",
  )
  match high_only {
    Object(fields) => {
      assert_true(fields.contains("low"))
      assert_false(fields.contains("high"))
    }
    _ => fail("object expected")
  }
}

///|
test "FHIR Range rejects mismatched encodings reversed bounds and comparators" {
  let e = @ucum.Engine::new()
  for
    source in [
      ({ "low": range_bound(1.0, "g"), "high": range_bound(2.0, "mg") } : Json),
      { "low": range_bound(2.0, "m"), "high": range_bound(1.0, "m") },
      {
        "low": {
          "value": 1,
          "system": "http://unitsofmeasure.org",
          "code": "m",
          "comparator": "<",
        },
      },
      {
        "low": {
          "value": 1,
          "system": "http://unitsofmeasure.org",
          "code": "m",
          "unit": "metre",
        },
        "high": range_bound(2.0, "m"),
      },
      { "low": Json::null() },
      {},
    ] {
    let rejected = try {
      ignore(@fhir.convert_range(e, source, "m"))
      false
    } catch {
      @fhir.Input(_) => true
      _ => false
    }
    assert_true(rejected)
  }
}

///|
test "FHIR Range preserves core domain and numeric failures" {
  let e = @ucum.Engine::new()
  let domain = try {
    ignore(
      @fhir.convert_range(
        e,
        { "low": range_bound(0.0, "W"), "high": range_bound(1.0, "W") },
        "dB[W]",
      ),
    )
    false
  } catch {
    @fhir.UnitConversion(@ucum.Domain(_)) => true
    _ => false
  }
  assert_true(domain)
  let mismatch = try {
    ignore(@fhir.convert_range(e, { "low": range_bound(1.0, "m") }, "s"))
    false
  } catch {
    @fhir.UnitConversion(@ucum.Incompatible(_, _)) => true
    _ => false
  }
  assert_true(mismatch)
  let empty_target = try {
    ignore(@fhir.convert_range(e, { "low": range_bound(1.0, "1") }, ""))
    false
  } catch {
    @fhir.Input(_) => true
    _ => false
  }
  assert_true(empty_target)
  let invalid = try {
    ignore(
      @fhir.convert_range(
        e,
        {
          "low": {
            "value": Json::number(1.0 / 0.0),
            "code": "m",
            "system": "http://unitsofmeasure.org",
          },
        },
        "m",
      ),
    )
    false
  } catch {
    @fhir.UnitConversion(@ucum.NonFinite) => true
    _ => false
  }
  assert_true(invalid)
}
