///|
/// Input-shape failures remain distinct from unit-semantic failures.
pub suberror QuantityError {
  Input(String)
  UnitConversion(@ucum.UcumError)
} derive(Debug)

///|
pub extend QuantityError with @debug.Debug::{to_repr}

///|
pub fn QuantityError::message(self : QuantityError) -> String {
  match self {
    Input(message) => message
    UnitConversion(error) => error.message()
  }
}

///|
/// Convert a populated, explicitly UCUM-coded FHIR R4 Quantity JSON object.
/// Preserve unrelated object members, update value/code/display unit, and keep
/// affine comparators. Nonlinear comparator sets and primitive extensions on
/// changed fields require application-specific handling and are rejected.
pub fn convert_quantity(
  engine : @ucum.Engine,
  quantity : Json,
  target : String,
) -> Json raise QuantityError {
  let (fields, value, code) = read_quantity(engine, quantity)
  if target.is_empty() {
    raise Input("A nonempty target code is required; use 1 for unity.")
  }
  for key in ["_value", "_unit", "_code", "_system", "_comparator"] {
    if fields.contains(key) {
      raise Input(
        "Primitive extensions on converted fields require explicit handling: " +
        key,
      )
    }
  }
  let comparator = match fields.get("comparator") {
    None => None
    Some(String("<" | "<=" | ">" | ">=" as comparison)) => Some(comparison)
    _ => raise Input("Expected a FHIR R4 comparator: <, <=, > or >=.")
  }
  let converter = engine.converter(code, target) catch {
    error => raise UnitConversion(error)
  }
  if comparator is Some(_) && !converter.is_affine() {
    raise Input(
      "Nonlinear comparator quantities require an explicit bounded domain.",
    )
  }
  let converted = converter.apply(value) catch {
    error => raise UnitConversion(error)
  }
  let output = fields.copy()
  output["value"] = converted.to_json()
  output["code"] = target.to_json()
  output["unit"] = target.to_json()
  output.to_json()
}
