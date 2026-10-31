///|
/// A finite, nonempty interval. Endpoint flags travel with their endpoints.
pub struct Interval {
  lower : Double
  upper : Double
  lower_closed : Bool
  upper_closed : Bool
}

///|
pub fn Interval::new(
  lower : Double,
  upper : Double,
  lower_closed? : Bool = true,
  upper_closed? : Bool = true,
) -> Interval raise UcumError {
  if !finite(lower) || !finite(upper) {
    raise NonFinite
  }
  if lower > upper || (lower == upper && (!lower_closed || !upper_closed)) {
    raise Domain("An interval must be ordered and nonempty.")
  }
  { lower, upper, lower_closed, upper_closed, }
}

///|
fn Mapping::increasing(self : Mapping) -> Bool {
  match self {
    Logarithmic(_, coefficient) => coefficient > 0.0
    _ => true
  }
}

///|
/// Direction on the conversion's supported connected domain.
pub fn Converter::is_increasing(self : Converter) -> Bool {
  self.source.increasing() == self.target.increasing()
}

///|
/// True for proportional and affine conversions, whose domains include all
/// finite real inputs subject to representable results.
pub fn Converter::is_affine(self : Converter) -> Bool {
  self.source is Linear(_) && self.target is Linear(_)
}

///|
/// Convert a finite interval and reverse endpoints for decreasing mappings.
/// Both endpoints must be convertible, even when an endpoint is open; an
/// unbounded image therefore returns the same domain/range error as apply.
pub fn Converter::apply_interval(
  self : Converter,
  interval : Interval,
) -> Interval raise UcumError {
  let first = self.apply(interval.lower)
  let last = self.apply(interval.upper)
  if self.is_increasing() {
    Interval::new(
      first,
      last,
      lower_closed=interval.lower_closed,
      upper_closed=interval.upper_closed,
    )
  } else {
    Interval::new(
      last,
      first,
      lower_closed=interval.upper_closed,
      upper_closed=interval.lower_closed,
    )
  }
}
