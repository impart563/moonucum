///|
fn checked_form(form : NormalForm) -> NormalForm raise UcumError {
  if !finite(form.scale) || form.scale == 0.0 || !finite(form.offset) {
    raise NonFinite
  }
  for n in form.dimensions {
    if n > 10000 || n < -10000 {
      raise Limit("dimension exponent exceeds 10000")
    }
  }
  form
}

///|
fn dimensionless(form : NormalForm) -> Bool {
  !form.affine && form.dimensions.all(n => n == 0)
}

///|
fn multiply(
  a : NormalForm,
  b : NormalForm,
  divide : Bool,
) -> NormalForm raise UcumError {
  if a.affine || b.affine {
    if a.affine && dimensionless(b) {
      return checked_form({
        ..a,
        scale: if divide {
          a.scale / b.scale
        } else {
          a.scale * b.scale
        },
      })
    }
    if !divide && b.affine && dimensionless(a) {
      return checked_form({ ..b, scale: b.scale * a.scale, })
    }
    raise Unsupported(
      "special units cannot participate in dimensional products or reciprocals",
    )
  }
  let dimensions = Array::makei(7, i => {
    if divide {
      a.dimensions[i] - b.dimensions[i]
    } else {
      a.dimensions[i] + b.dimensions[i]
    }
  })
  checked_form({
    scale: if divide {
      a.scale / b.scale
    } else {
      a.scale * b.scale
    },
    offset: 0.0,
    dimensions,
    affine: false,
  })
}

///|
fn power(form : NormalForm, exponent : Int) -> NormalForm raise UcumError {
  if exponent == 1 {
    return form
  }
  if form.affine {
    raise Unsupported("exponentiation of a special unit")
  }
  let mut factor = 1.0
  let mut base = form.scale
  let mut n = if exponent < 0 { -exponent } else { exponent }
  while n > 0 {
    if n % 2 == 1 {
      factor *= base
    }
    n /= 2
    if n > 0 {
      base *= base
    }
  }
  checked_form({
    scale: if exponent < 0 {
      1.0 / factor
    } else {
      factor
    },
    offset: 0.0,
    dimensions: form.dimensions.map(x => x * exponent),
    affine: false,
  })
}

///|
fn Engine::atom_form(
  self : Engine,
  atom : Atom,
  depth : Int,
) -> NormalForm raise UcumError {
  if depth > 64 {
    raise Limit("unit definition recursion exceeds 64")
  }
  if self.cache.get(atom.code) is Some(form) {
    return form
  }
  if atom.arbitrary {
    raise Unsupported(
      "arbitrary unit has no general conversion semantics: " + atom.code,
    )
  }
  let form = if atom.base >= 0 {
    let dimensions = Array::make(7, 0)
    dimensions[atom.base] = 1
    { ..unity(), dimensions, }
  } else if atom.special {
    let dimensions = Array::make(7, 0)
    dimensions[4] = 1
    match atom.code {
      "Cel" => { scale: 1.0, offset: 273.15, dimensions, affine: true, }
      "[degF]" =>
        {
          scale: 5.0 / 9.0,
          offset: 273.15 - 32.0 * 5.0 / 9.0,
          dimensions,
          affine: true,
        }
      "[degRe]" => { scale: 1.25, offset: 273.15, dimensions, affine: true, }
      _ => raise Unsupported("special conversion function: " + atom.code)
    }
  } else {
    let base = self.evaluate(parse_expression(atom.definition), depth + 1)
    multiply(base, { ..unity(), scale: atom.multiplier, }, false)
  }
  let form = checked_form(form)
  self.cache[atom.code] = form
  form
}

///|
fn Engine::evaluate(
  self : Engine,
  expression : Expr,
  depth : Int,
) -> NormalForm raise UcumError {
  match self.map_expression(expression, depth) {
    Linear(form) => form
    Logarithmic(_, _) =>
      raise Unsupported(
        "Logarithmic units have no linear NormalForm; use converter or convert.",
      )
  }
}

///|
/// Normalize supported expressions into y = x * scale + offset in UCUM base units.
pub fn Engine::normalize(
  self : Engine,
  input : String,
) -> NormalForm raise UcumError {
  let expression = parse_expression(input)
  self.validate_tree(expression)
  self.evaluate(expression, 0)
}

///|
/// Test commensurability; unsupported semantics remain typed errors.
pub fn Engine::compatible(
  self : Engine,
  first : String,
  second : String,
) -> Bool raise UcumError {
  self.mapping(first).reference().dimensions ==
  self.mapping(second).reference().dimensions
}

///|
/// Semantic equivalence uses relative tolerance 1e-12 for binary64 factors.
pub fn Engine::equivalent(
  self : Engine,
  first : String,
  second : String,
) -> Bool raise UcumError {
  match (self.mapping(first), self.mapping(second)) {
    (Linear(a), Linear(b)) => forms_equivalent(a, b)
    (Logarithmic(a, first), Logarithmic(b, second)) =>
      forms_equivalent(a, b) &&
      first.is_close(second, relative_tolerance=1.0e-12, absolute_tolerance=0.0)
    _ => false
  }
}

///|
pub fn Engine::convert(
  self : Engine,
  value : Double,
  source : String,
  target : String,
) -> Double raise UcumError {
  self.converter(source, target).apply(value)
}
