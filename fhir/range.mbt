///|
/// Convert populated FHIR R4 Range bounds. Missing bounds remain unknown.
/// Require matching input system/code/display and no endpoint comparators.
/// A decreasing mapping exchanges whole endpoint objects, including metadata.
pub fn convert_range(
  engine : @ucum.Engine,
  range : Json,
  target : String,
) -> Json raise QuantityError {
  if target.is_empty() {
    raise Input("A nonempty target code is required; use 1 for unity.")
  }
  let fields = match range {
    Object(fields) => fields
    _ => raise Input("Expected a FHIR Range object.")
  }
  let low = fields.get("low")
  let high = fields.get("high")
  let mut original_low : Double? = None
  let mut original_high : Double? = None
  let mut source : String? = None
  let mut display : Json? = None
  let bounds : Array[(String, Json, String)] = []
  for (name, bound) in [("low", low), ("high", high)] {
    if bound is Some(quantity) {
      let (bound_fields, value, code) = read_quantity(engine, quantity)
      require_point(bound_fields)
      if source is Some(previous) {
        if previous != code || display != bound_fields.get("unit") {
          raise Input(
            "Range boundaries must use matching code, system and display unit.",
          )
        }
      } else {
        source = Some(code)
        display = bound_fields.get("unit")
      }
      if name == "low" {
        original_low = Some(value)
      } else {
        original_high = Some(value)
      }
      bounds.push((name, quantity, code))
    }
  }
  if source is None {
    raise Input(
      "Range conversion requires at least one populated numeric boundary.",
    )
  }
  if (original_low, original_high) is (Some(low), Some(high)) && low > high {
    raise Input("Range low must not exceed high.")
  }
  let output = fields.copy()
  output.remove("low")
  output.remove("high")
  for (name, quantity, code) in bounds {
    let converter = engine.converter(code, target) catch {
      error => raise UnitConversion(error)
    }
    let destination = if converter.is_increasing() {
      name
    } else if name == "low" {
      "high"
    } else {
      "low"
    }
    output[destination] = convert_quantity(engine, quantity, target)
  }
  output.to_json()
}
