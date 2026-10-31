///|
fn symbols(expression : Expr, result : Array[(String, Int)]) -> Unit {
  match expression {
    Symbol(code, offset) => result.push((code, offset))
    Product(a, b) | Quotient(a, b) => {
      symbols(a, result)
      symbols(b, result)
    }
    Power(a, _) | Annotation(a, _) => symbols(a, result)
    Number(_) => ()
  }
}

///|
/// Translate standard atom and prefix codes while preserving operators,
/// exponents, parentheses and annotation text. This is not case folding.
/// Arbitrary codes can be translated without assigning them numeric semantics.
pub fn Engine::translate(
  self : Engine,
  input : String,
  target_mode : CodeMode,
) -> String raise UcumError {
  let tree = parse_expression(input)
  self.validate_tree(tree)
  let tokens = []
  symbols(tree, tokens)
  let pieces = []
  let mut cursor = 0
  for (code, offset) in tokens {
    let (atom, factor) = self.resolve(code, offset, self.mode)
    let target_atom = match target_mode {
      CaseSensitive => atom.code
      CaseInsensitive => self.metadata[atom.code].insensitive_code
    }
    let mut prefix = ""
    if factor != 1.0 {
      for i in 0..<self.prefixes.length() {
        if self.prefixes[i].multiplier == factor {
          prefix = match target_mode {
            CaseSensitive => self.prefixes[i].code
            CaseInsensitive => self.insensitive_prefixes[i].code
          }
          break
        }
      }
    }
    pieces.push(input.view(start_offset=cursor, end_offset=offset).to_owned())
    pieces.push(prefix + target_atom)
    cursor = offset + code.length()
  }
  pieces.push(input.view(start_offset=cursor).to_owned())
  let output = pieces.join("")
  // Longer aliases must still satisfy the public parser's resource limits.
  ignore(parse_expression(output))
  output
}
