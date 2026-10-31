///|
priv struct Parser {
  input : String
  mut pos : Int
  mut depth : Int
  mut components : Int
}

///|
fn Parser::at(self : Parser) -> Int {
  match self.input.get(self.pos) {
    Some(c) => c.to_int()
    None => -1
  }
}

///|
fn digit(c : Int) -> Bool {
  c >= 48 && c <= 57
}

///|
fn Parser::integer(self : Parser) -> Int raise UcumError {
  let start = self.pos
  let mut value = 0
  while digit(self.at()) {
    value = value * 10 + self.at() - 48
    if value > 10000 {
      raise Limit("integer or exponent exceeds 10000")
    }
    self.pos += 1
  }
  if self.pos == start {
    raise Syntax(start, "expected decimal digits")
  }
  value
}

///|
fn Parser::component(self : Parser) -> Expr raise UcumError {
  self.components += 1
  if self.components > 256 {
    raise Limit("expression exceeds 256 components")
  }
  let start = self.pos
  let mut value = if self.at() == 40 {
    self.pos += 1
    self.depth += 1
    if self.depth > 32 {
      raise Limit("parenthesis nesting exceeds 32")
    }
    if self.at() == 41 {
      raise Syntax(self.pos, "empty parentheses")
    }
    let inner = self.term()
    if self.at() != 41 {
      raise Syntax(self.pos, "expected closing parenthesis")
    }
    self.pos += 1
    self.depth -= 1
    return inner
  } else if self.at() == 123 {
    Number(1)
  } else if digit(self.at()) {
    let number = self.integer()
    if number == 10 && (self.at() == 42 || self.at() == 94) {
      self.pos += 1
      Symbol(
        self.input.view(start_offset=start, end_offset=self.pos).to_owned(),
        start,
      )
    } else {
      if number <= 0 {
        raise Syntax(start, "numeric factors must be positive")
      }
      Number(number)
    }
  } else {
    let mut bracket = false
    while self.at() != -1 {
      let c = self.at()
      if bracket {
        if c == 91 {
          raise Syntax(self.pos, "nested square bracket")
        }
        if c == 93 {
          bracket = false
        }
        self.pos += 1
      } else if c == 91 {
        bracket = true
        self.pos += 1
      } else if c == 46 ||
        c == 47 ||
        c == 40 ||
        c == 41 ||
        c == 123 ||
        c == 125 ||
        c == 43 ||
        c == 45 ||
        digit(c) {
        break
      } else {
        if c <= 32 || c == 93 || c == 61 || c == 34 {
          raise Syntax(self.pos, "invalid character in unit symbol")
        }
        self.pos += 1
      }
    }
    if bracket {
      raise Syntax(start, "unclosed square bracket")
    }
    if self.pos == start {
      raise Syntax(start, "expected unit component")
    }
    Symbol(
      self.input.view(start_offset=start, end_offset=self.pos).to_owned(),
      start,
    )
  }
  if digit(self.at()) || self.at() == 43 || self.at() == 45 {
    let negative = self.at() == 45
    if self.at() == 43 || self.at() == 45 {
      self.pos += 1
    }
    let n = self.integer()
    // Numeric factors cannot be followed by an exponent without an operator.
    if value is Number(_) {
      raise Syntax(self.pos, "unexpected numeric exponent")
    }
    value = Power(value, if negative { -n } else { n })
  }
  if self.at() == 123 {
    let annotation = self.pos + 1
    self.pos += 1
    while self.at() != 125 {
      if self.at() == -1 {
        raise Syntax(annotation - 1, "unclosed annotation")
      }
      if self.at() == 123 {
        raise Syntax(self.pos, "nested annotation")
      }
      self.pos += 1
    }
    value = Annotation(
      value,
      self.input.view(start_offset=annotation, end_offset=self.pos).to_owned(),
    )
    self.pos += 1
  }
  value
}

///|
fn Parser::term(self : Parser) -> Expr raise UcumError {
  let mut value = if self.at() == 47 { Number(1) } else { self.component() }
  while self.at() == 46 || self.at() == 47 {
    let divide = self.at() == 47
    self.pos += 1
    let rhs = self.component()
    value = if divide { Quotient(value, rhs) } else { Product(value, rhs) }
  }
  value
}

///|
/// Parse UCUM syntax independently of catalog lookup. Empty input denotes unity.
pub fn parse_expression(input : String) -> Expr raise UcumError {
  if input.length() > 4096 {
    raise Limit("expression exceeds 4096 characters")
  }
  for i in 0..<input.length() {
    if input[i].to_int() < 32 || input[i].to_int() > 126 {
      raise Syntax(i, "UCUM expressions require printable ASCII")
    }
  }
  if input.is_empty() {
    return Number(1)
  }
  let parser = { input, pos: 0, depth: 0, components: 0, }
  let value = parser.term()
  if parser.pos != input.length() {
    raise Syntax(parser.pos, "expected '.' or '/' between components")
  }
  value
}
