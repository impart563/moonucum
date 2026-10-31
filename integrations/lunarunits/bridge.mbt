///|
pub suberror BridgeError {
  UnitConversion(@ucum.UcumError)
  Unsupported(String)
  NonFinite
  Incompatible(String)
} derive(Debug)

///|
pub extend BridgeError with @debug.Debug::{to_repr}

///|
/// Preserve UCUM's dimensions in LunarUnits: grams become kilograms, charge
/// becomes ampere-seconds, radians remain an independent custom dimension and
/// mole remains UCUM's count. Affine/nonlinear units need an explicit proper
/// unit conversion before entering multiplicative quantity arithmetic.
pub fn to_unit(
  engine : @ucum.Engine,
  code : String,
) -> @unit.Un raise BridgeError {
  let form = engine.normalize(code) catch {
    error => raise UnitConversion(error)
  }
  if form.is_affine() {
    raise Unsupported(
      "Convert affine points to a proper unit before quantity arithmetic.",
    )
  }
  let n = form.exponents()
  let dimensions = [
    @dimension.Dimension::length(),
    @dimension.Dimension::time(),
    @dimension.Dimension::mass(),
    @dimension.Dimension::custom("ucum:rad"),
    @dimension.Dimension::temperature(),
    @dimension.Dimension::electric_current().mul(@dimension.Dimension::time()),
    @dimension.Dimension::luminous_intensity(),
  ]
  let mut dimension = @dimension.Dimension::dimensionless()
  for i in 0..<7 {
    dimension = dimension.mul(dimensions[i].pow(n[i]))
  }
  let scale = form.factor() * @math.pow(0.001, n[2].to_double())
  if scale <= 0.0 || scale.is_inf() || scale.is_nan() {
    raise NonFinite
  }
  @unit.Un::scaled(code, dimension, scale)
}

///|
pub fn to_quantity(
  engine : @ucum.Engine,
  value : Double,
  code : String,
) -> @quantity.Quantity raise BridgeError {
  if value.is_inf() || value.is_nan() {
    raise NonFinite
  }
  @quantity.Quantity::new(value, to_unit(engine, code))
}

///|
/// Convert back through a checked compatible target, never through display text.
pub fn from_quantity(
  engine : @ucum.Engine,
  quantity : @quantity.Quantity,
  target : String,
) -> Double raise BridgeError {
  let unit = to_unit(engine, target)
  let converted = quantity.checked_to(unit)
  match converted {
    Some(value) => {
      let result = value.value()
      if result.is_inf() || result.is_nan() {
        raise NonFinite
      }
      result
    }
    None => raise Incompatible(target)
  }
}
