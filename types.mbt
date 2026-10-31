///|
/// Errors preserve the input offset for syntax and symbol lookup failures.
pub suberror UcumError {
  Syntax(Int, String)
  UnknownUnit(Int, String)
  Unsupported(String)
  Incompatible(String, String)
  Limit(String)
  NonFinite
} derive(Debug, Eq)

///|
pub fn UcumError::message(self : UcumError) -> String {
  match self {
    Syntax(offset, reason) =>
      "Syntax error at position " + offset.to_string() + ": " + reason
    UnknownUnit(offset, code) =>
      "Unknown UCUM code at position " + offset.to_string() + ": " + code
    Unsupported(reason) => reason
    Incompatible(source, target) =>
      "Incompatible units: " + source + " and " + target
    Limit(reason) => "Resource limit: " + reason
    NonFinite =>
      "Input or result is outside the supported finite numeric range."
  }
}

///|
/// Syntax tree. Offsets are zero-based ASCII character positions.
pub(all) enum Expr {
  Number(Int)
  Symbol(String, Int)
  Product(Expr, Expr)
  Quotient(Expr, Expr)
  Power(Expr, Int)
  Annotation(Expr, String)
} derive(Debug, Eq)

///|
/// Coordinates follow UCUM's m, s, g, rad, K, C, cd basis, not the SI basis.
pub struct NormalForm {
  priv scale : Double
  priv offset : Double
  priv dimensions : Array[Int]
  priv affine : Bool
} derive(Debug)

///|
pub fn NormalForm::exponents(self : NormalForm) -> Array[Int] {
  self.dimensions.copy()
}

///|
pub fn NormalForm::factor(self : NormalForm) -> Double {
  self.scale
}

///|
pub fn NormalForm::origin(self : NormalForm) -> Double {
  self.offset
}

///|
pub fn NormalForm::is_affine(self : NormalForm) -> Bool {
  self.affine
}

///|
pub fn NormalForm::basis(self : NormalForm) -> String {
  let names = ["m", "s", "g", "rad", "K", "C", "cd"]
  let terms : Array[String] = []
  for i in 0..<7 {
    let n = self.dimensions[i]
    if n != 0 {
      terms.push(if n == 1 { names[i] } else { names[i] + n.to_string() })
    }
  }
  if terms.is_empty() {
    "1"
  } else {
    terms.join(".")
  }
}

///|
fn unity() -> NormalForm {
  { scale: 1.0, offset: 0.0, dimensions: Array::make(7, 0), affine: false, }
}

///|
fn finite(value : Double) -> Bool {
  !value.is_nan() && !value.is_inf()
}

///|
pub extend UcumError with @debug.Debug::{to_repr}

///|
pub extend UcumError with Eq::{equal, not_equal}

///|
pub extend Expr with @debug.Debug::{to_repr}

///|
pub extend Expr with Eq::{equal, not_equal}

///|
pub extend NormalForm with @debug.Debug::{to_repr}
