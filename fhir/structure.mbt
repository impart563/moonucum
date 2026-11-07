///|
fn read_quantity(
  engine : @ucum.Engine,
  quantity : Json,
) -> (Map[String, Json], Double, String) raise QuantityError {
  if engine.code_mode() != @ucum.CaseSensitive {
    raise Input("FHIR UCUM quantities require case-sensitive codes.")
  }
  match quantity {
    Object(fields) =>
      match quantity {
        {
          "system": "http://unitsofmeasure.org",
          "code": String(code),
          "value": Number(value, ..),
          ..
        } if !code.is_empty() => {
          match fields.get("unit") {
            None | Some(String(_)) => ()
            _ =>
              raise Input(
                "Quantity unit display must be a string when present.",
              )
          }
          (fields, value, code)
        }
        _ =>
          raise Input(
            "A numeric value and an explicit UCUM system/code are required.",
          )
      }
    _ => raise Input("Expected a FHIR Quantity object.")
  }
}

///|
fn require_point(fields : Map[String, Json]) -> Unit raise QuantityError {
  if fields.contains("comparator") || fields.contains("_comparator") {
    raise Input(
      "This operation requires point quantities without a comparator.",
    )
  }
}
