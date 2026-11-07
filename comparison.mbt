///|
/// Ordering of two quantities after conversion to an explicit comparison unit.
pub(all) enum QuantityOrder {
  Lower
  Same
  Higher
} derive(Eq, Debug)

///|
pub extend QuantityOrder with Eq::{equal, not_equal}

///|
pub extend QuantityOrder with @debug.Debug::{to_repr}

///|
pub(all) enum RangePosition {
  Below
  Within
  Above
} derive(Eq, Debug)

///|
pub extend RangePosition with Eq::{equal, not_equal}

///|
pub extend RangePosition with @debug.Debug::{to_repr}

///|
/// Compare in the caller's chosen coordinate. Absolute tolerance is measured in
/// that unit; relative tolerance uses max(abs(left), abs(right)). Defaults are
/// exact binary64 comparison. Tolerant equality is not a sorting relation.
pub fn Engine::compare_quantities(
  self : Engine,
  left : (Double, String),
  right : (Double, String),
  unit : String,
  absolute_tolerance? : Double = 0.0,
  relative_tolerance? : Double = 0.0,
) -> QuantityOrder raise UcumError {
  if !finite(absolute_tolerance) ||
    !finite(relative_tolerance) ||
    absolute_tolerance < 0.0 ||
    relative_tolerance < 0.0 {
    raise Domain("Comparison tolerances must be finite and nonnegative.")
  }
  let (left_value, left_unit) = left
  let (right_value, right_unit) = right
  let a = self.convert(left_value, left_unit, unit)
  let b = self.convert(right_value, right_unit, unit)
  if a == b || (a - b).abs() <= absolute_tolerance {
    return Same
  }
  if relative_tolerance > 0.0 {
    let scale = if a.abs() > b.abs() { a.abs() } else { b.abs() }
    // Normalize before subtracting so opposite finite extremes cannot overflow.
    if (a / scale - b / scale).abs() <= relative_tolerance {
      return Same
    }
  }
  if a < b {
    Lower
  } else {
    Higher
  }
}

///|
/// Locate a source value in an interval expressed in the converter's target
/// unit. Membership uses exact binary64 comparisons and endpoint inclusion.
pub fn Converter::classify(
  self : Converter,
  value : Double,
  interval : Interval,
) -> RangePosition raise UcumError {
  let converted = self.apply(value)
  if converted < interval.lower ||
    (converted == interval.lower && !interval.lower_closed) {
    Below
  } else if converted > interval.upper ||
    (converted == interval.upper && !interval.upper_closed) {
    Above
  } else {
    Within
  }
}
