///|
const HalfPi : Double = 1.5707963267948966

///|
fn rescale_positive(
  value : Double,
  numerator : Double,
  denominator : Double,
) -> Double raise UcumError {
  if value == 0.0 {
    return value
  }
  let result = value * (numerator / denominator)
  if finite(result) && result != 0.0 {
    return result
  }
  let magnitude = checked_exponential(
    @math.ln(value.abs()) + @math.ln(numerator) - @math.ln(denominator),
  )
  if value < 0.0 {
    -magnitude
  } else {
    magnitude
  }
}

///|
fn require_nonnegative(value : Double) -> Unit raise UcumError {
  if value < 0.0 {
    raise Domain("Square-root conversion requires a nonnegative quantity.")
  }
}

///|
fn Mapping::to_proper(self : Mapping, value : Double) -> Double raise UcumError {
  let result = match self {
    Linear(form) => value * form.scale + form.offset
    Logarithmic(reference, coefficient) =>
      checked_exponential(@math.ln(reference.scale) + coefficient * value)
    Tangent(reference, scalar) => {
      let input = scalar * value
      if !finite(input) {
        raise NonFinite
      }
      let angle = @math.atan(input / 100.0)
      // atan can round to the excluded endpoint for very large finite inputs.
      if angle.abs() >= HalfPi {
        raise NonFinite
      }
      angle * reference.scale
    }
    SquareRoot(reference, scalar) => {
      require_nonnegative(value)
      if value == 0.0 {
        0.0
      } else {
        checked_exponential(
          @math.ln(reference.scale) + 2.0 * (@math.ln(value) + @math.ln(scalar)),
        )
      }
    }
  }
  if !finite(result) {
    raise NonFinite
  }
  result
}

///|
fn Mapping::from_proper(
  self : Mapping,
  proper : Double,
) -> Double raise UcumError {
  let result = match self {
    Linear(form) => (proper - form.offset) / form.scale
    Logarithmic(reference, coefficient) => {
      if proper <= 0.0 {
        raise Domain("Logarithmic conversion requires a positive quantity.")
      }
      (@math.ln(proper) - @math.ln(reference.scale)) / coefficient
    }
    Tangent(reference, scalar) => {
      let angle = proper / reference.scale
      if !finite(angle) {
        raise NonFinite
      }
      if angle.abs() >= HalfPi {
        raise Domain(
          "Tangent conversion requires an angle strictly between -pi/2 and pi/2.",
        )
      }
      100.0 * @math.tan(angle) / scalar
    }
    SquareRoot(reference, scalar) => {
      require_nonnegative(proper)
      if proper == 0.0 {
        0.0
      } else {
        checked_exponential(
          0.5 * (@math.ln(proper) - @math.ln(reference.scale)) -
          @math.ln(scalar),
        )
      }
    }
  }
  if !finite(result) {
    raise NonFinite
  }
  result
}
