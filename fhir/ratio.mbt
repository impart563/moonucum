///|
/// Convert both components of a populated FHIR R4 Ratio independently.
/// Preserve the denominator quantity and metadata; never cancel components or
/// replace the Ratio with a scalar. Only proportional point units are accepted.
pub fn convert_ratio(
  engine : @ucum.Engine,
  ratio : Json,
  numerator_target : String,
  denominator_target : String,
) -> Json raise QuantityError {
  if numerator_target.is_empty() || denominator_target.is_empty() {
    raise Input("Ratio target codes must be nonempty; use 1 for unity.")
  }
  let (fields, numerator, denominator) = match ratio {
    Object(fields) =>
      match (fields.get("numerator"), fields.get("denominator")) {
        (Some(numerator), Some(denominator)) => (fields, numerator, denominator)
        _ =>
          raise Input(
            "Ratio conversion requires populated numerator and denominator quantities.",
          )
      }
    _ => raise Input("Expected a FHIR Ratio object.")
  }
  let (numerator_fields, _, numerator_code) = read_quantity(engine, numerator)
  let (denominator_fields, denominator_value, denominator_code) = read_quantity(
    engine, denominator,
  )
  require_point(numerator_fields)
  require_point(denominator_fields)
  if denominator_value == 0.0 {
    raise Input("Ratio conversion requires a nonzero denominator.")
  }
  for
    code in [
      numerator_code, denominator_code, numerator_target, denominator_target,
    ] {
    let form = engine.normalize(code) catch {
      error => raise UnitConversion(error)
    }
    if form.is_affine() {
      raise Input(
        "Ratio conversion requires proportional units, not affine points.",
      )
    }
  }
  let converted_numerator = convert_quantity(
    engine, numerator, numerator_target,
  )
  let converted_denominator = convert_quantity(
    engine, denominator, denominator_target,
  )
  let (_, value, _) = read_quantity(engine, converted_denominator)
  if value == 0.0 {
    raise Input("Converted denominator is zero at binary64 precision.")
  }
  let output = fields.copy()
  output["numerator"] = converted_numerator
  output["denominator"] = converted_denominator
  output.to_json()
}
