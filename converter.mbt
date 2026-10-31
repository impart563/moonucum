///|
priv enum Mapping {
  Linear(NormalForm)
  // Base quantity = reference.scale * exp(coefficient * measurement).
  Logarithmic(NormalForm, Double)
  Tangent(NormalForm, Double)
  SquareRoot(NormalForm, Double)
}

///|
fn Mapping::reference(self : Mapping) -> NormalForm {
  match self {
    Linear(form)
    | Logarithmic(form, _)
    | Tangent(form, _)
    | SquareRoot(form, _) => form
  }
}

///|
/// A parsed, dimension-checked conversion reusable across a batch of values.
pub struct Converter {
  priv source : Mapping
  priv target : Mapping
}

///|
fn special_definition(definition : String) -> (String, Double, String) {
  let opening = definition.find("(").unwrap()
  let name = definition.view(end_offset=opening).to_owned()
  let payload = definition
    .view(start_offset=opening + 1, end_offset=definition.length() - 1)
    .to_owned()
  let separator = payload.find(" ").unwrap()
  let factor = try! @string.parse_double(payload.view(end_offset=separator))
  (name, factor, payload.view(start_offset=separator + 1).to_owned())
}

///|
fn logarithmic_coefficient(name : String) -> Double? {
  match name {
    "ln" => Some(1.0)
    "lg" => Some(@math.ln(10.0))
    "2lg" => Some(@math.ln(10.0) / 2.0)
    "ld" => Some(@math.ln(2.0))
    "pH" | "hpX" => Some(-@math.ln(10.0))
    "hpC" => Some(-@math.ln(100.0))
    "hpM" => Some(-@math.ln(1000.0))
    "hpQ" => Some(-@math.ln(50000.0))
    _ => None
  }
}

///|
fn Mapping::scaled(self : Mapping, factor : Double) -> Mapping raise UcumError {
  match self {
    Linear(form) => Linear(multiply(form, { ..unity(), scale: factor, }, false))
    Logarithmic(reference, coefficient) => {
      let scaled = coefficient * factor
      if !finite(scaled) || scaled == 0.0 {
        raise NonFinite
      }
      Logarithmic(reference, scaled)
    }
    Tangent(reference, scalar) | SquareRoot(reference, scalar) => {
      let scaled = scalar * factor
      if !finite(scaled) || scaled <= 0.0 {
        raise NonFinite
      }
      match self {
        Tangent(_, _) => Tangent(reference, scaled)
        _ => SquareRoot(reference, scaled)
      }
    }
  }
}

///|
fn combine_mappings(
  a : Mapping,
  b : Mapping,
  divide : Bool,
) -> Mapping raise UcumError {
  match (a, b) {
    (Linear(first), Linear(second)) => Linear(multiply(first, second, divide))
    (_, Linear(second)) if dimensionless(second) =>
      a.scaled(if divide { 1.0 / second.scale } else { second.scale })
    (Linear(first), _) if !divide && dimensionless(first) =>
      b.scaled(first.scale)
    _ =>
      raise Unsupported(
        "special units allow scalar scaling, not dimensional products or reciprocals",
      )
  }
}

///|
fn Engine::map_expression(
  self : Engine,
  expression : Expr,
  depth : Int,
  mode : CodeMode,
) -> Mapping raise UcumError {
  if depth > 64 {
    raise Limit("unit definition recursion exceeds 64")
  }
  match expression {
    Number(n) => Linear({ ..unity(), scale: n.to_double(), })
    Symbol(code, position) => {
      let (atom, prefix) = self.resolve(code, position, mode)
      if atom.special {
        let (name, factor, proper) = special_definition(atom.definition)
        if logarithmic_coefficient(name) is Some(coefficient) {
          let reference = self.evaluate(parse_expression(proper), depth + 1)
          let reference = multiply(
            reference,
            { ..unity(), scale: factor, },
            false,
          )
          return Logarithmic(reference, coefficient).scaled(prefix)
        }
        if name == "100tan" || name == "sqrt" {
          let reference = multiply(
            self.evaluate(parse_expression(proper), depth + 1),
            { ..unity(), scale: factor, },
            false,
          )
          return (if name == "100tan" {
            Tangent(reference, 1.0)
          } else {
            SquareRoot(reference, 1.0)
          }).scaled(prefix)
        }
      }
      Linear(self.atom_form(atom, depth)).scaled(prefix)
    }
    Product(a, b) =>
      combine_mappings(
        self.map_expression(a, depth, mode),
        self.map_expression(b, depth, mode),
        false,
      )
    Quotient(a, b) =>
      combine_mappings(
        self.map_expression(a, depth, mode),
        self.map_expression(b, depth, mode),
        true,
      )
    Power(a, n) => {
      let mapping = self.map_expression(a, depth, mode)
      match mapping {
        Linear(form) => Linear(power(form, n))
        _ if n == 1 => mapping
        _ => raise Unsupported("exponentiation of a special unit")
      }
    }
    Annotation(a, _) => self.map_expression(a, depth, mode)
  }
}

///|
fn Engine::mapping(self : Engine, input : String) -> Mapping raise UcumError {
  let expression = parse_expression(input)
  self.validate_tree(expression)
  self.map_expression(expression, 0, self.mode)
}

///|
/// Parse source and target once. Unsupported semantics and dimensional mismatches
/// are reported here; value-specific domain and range errors are reported by apply.
pub fn Engine::converter(
  self : Engine,
  source : String,
  target : String,
) -> Converter raise UcumError {
  let a = self.mapping(source)
  let b = self.mapping(target)
  if a.reference().dimensions != b.reference().dimensions {
    raise Incompatible(source, target)
  }
  { source: a, target: b, }
}

///|
fn checked_exponential(exponent : Double) -> Double raise UcumError {
  let result = @math.exp(exponent)
  if !finite(result) || result == 0.0 {
    raise NonFinite
  }
  result
}

///|
/// Convert a finite value. Logarithmic targets require positive proper quantities.
/// Log-to-log conversion stays in logarithmic space to avoid intermediate overflow.
pub fn Converter::apply(
  self : Converter,
  value : Double,
) -> Double raise UcumError {
  if !finite(value) {
    raise NonFinite
  }
  let result = match (self.source, self.target) {
    (Linear(a), Linear(b)) => (value * a.scale + a.offset - b.offset) / b.scale
    (Logarithmic(a, coefficient), Linear(b)) =>
      if b.offset == 0.0 {
        checked_exponential(
          @math.ln(a.scale) - @math.ln(b.scale) + coefficient * value,
        )
      } else {
        (
          checked_exponential(@math.ln(a.scale) + coefficient * value) -
          b.offset
        ) /
        b.scale
      }
    (Linear(a), Logarithmic(b, coefficient)) =>
      if a.offset == 0.0 {
        if value <= 0.0 {
          raise Domain("Logarithmic conversion requires a positive quantity.")
        }
        (@math.ln(value) + @math.ln(a.scale) - @math.ln(b.scale)) / coefficient
      } else {
        let proper = value * a.scale + a.offset
        if !finite(proper) {
          raise NonFinite
        }
        if proper <= 0.0 {
          raise Domain("Logarithmic conversion requires a positive quantity.")
        }
        (@math.ln(proper) - @math.ln(b.scale)) / coefficient
      }
    (Logarithmic(a, first), Logarithmic(b, second)) =>
      (@math.ln(a.scale) - @math.ln(b.scale)) / second + first / second * value
    (Tangent(a, first), Tangent(b, second)) if forms_equivalent(a, b) =>
      rescale_positive(value, first, second)
    (SquareRoot(a, first), SquareRoot(b, second)) if forms_equivalent(a, b) => {
      require_nonnegative(value)
      rescale_positive(value, first, second)
    }
    (SquareRoot(a, scalar), Linear(b)) if b.offset == 0.0 => {
      require_nonnegative(value)
      if value == 0.0 {
        0.0
      } else {
        checked_exponential(
          @math.ln(a.scale) -
          @math.ln(b.scale) +
          2.0 * (@math.ln(value) + @math.ln(scalar)),
        )
      }
    }
    (Linear(a), SquareRoot(b, scalar)) if a.offset == 0.0 => {
      require_nonnegative(value)
      if value == 0.0 {
        0.0
      } else {
        checked_exponential(
          0.5 * (@math.ln(value) + @math.ln(a.scale) - @math.ln(b.scale)) -
          @math.ln(scalar),
        )
      }
    }
    _ => self.target.from_proper(self.source.to_proper(value))
  }
  if !finite(result) {
    raise NonFinite
  }
  result
}

///|
fn forms_equivalent(a : NormalForm, b : NormalForm) -> Bool {
  a.dimensions == b.dimensions &&
  a.scale.is_close(b.scale, relative_tolerance=1.0e-12, absolute_tolerance=0.0) &&
  a.offset.is_close(
    b.offset,
    relative_tolerance=1.0e-12,
    absolute_tolerance=0.0,
  )
}
