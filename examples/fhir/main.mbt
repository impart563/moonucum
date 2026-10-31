///|
// Synthetic FHIR Quantity values. The display label is not used as a code.
fn normalize_quantity(
  engine : @ucum.Engine,
  quantity : Json,
  target : String,
) -> Json {
  match quantity {
    {
      "system": "http://unitsofmeasure.org",
      "code": String(code),
      "value": Number(value, ..),
      ..
    } =>
      {
        "status": "converted",
        "value": engine.convert(value, code, target),
        "code": target,
        "system": "http://unitsofmeasure.org",
      } catch {
        error => { "status": "rejected", "reason": error.message() }
      }
    _ =>
      {
        "status": "rejected",
        "reason": "A numeric value and an explicit UCUM system/code are required.",
      }
  }
}

///|
fn main {
  let engine = @ucum.Engine::new()
  let examples : Array[(String, Json, String)] = [
    (
      "mass concentration",
      {
        "value": 12.0,
        "unit": "mg per dL",
        "system": "http://unitsofmeasure.org",
        "code": "mg/dL",
      },
      "g/L",
    ),
    (
      "body temperature",
      {
        "value": 37.0,
        "unit": "degrees Celsius",
        "system": "http://unitsofmeasure.org",
        "code": "Cel",
      },
      "K",
    ),
    (
      "substance context required",
      { "value": 90.0, "system": "http://unitsofmeasure.org", "code": "mg/dL" },
      "mmol/L",
    ),
    ("display label without code", { "value": 12.0, "unit": "mg/dL" }, "g/L"),
  ]
  for (name, quantity, target) in examples {
    println(
      (
        {
          "example": name,
          "input": quantity,
          "result": normalize_quantity(engine, quantity, target),
        } : Json).stringify(),
    )
  }
}

///|
test "FHIR example requires coded units and rejects incompatible dimensions" {
  let engine = @ucum.Engine::new()
  assert_eq(
    normalize_quantity(engine, { "value": 1.0, "unit": "mg/dL" }, "g/L"),
    {
      "status": "rejected",
      "reason": "A numeric value and an explicit UCUM system/code are required.",
    },
  )
  let result = normalize_quantity(
    engine,
    { "value": 37.0, "system": "http://unitsofmeasure.org", "code": "Cel" },
    "K",
  )
  match result {
    { "status": "converted", "value": Number(value, ..), .. } =>
      assert_true(value.is_close(310.15))
    _ => fail("temperature conversion failed")
  }
}
