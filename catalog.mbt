///|
priv struct Atom {
  code : String
  metric : Bool
  base : Int
  definition : String
  multiplier : Double
  special : Bool
  arbitrary : Bool
}

///|
priv struct Prefix {
  code : String
  multiplier : Double
}

///|
/// Reuse one engine for a batch. Definition normalization is cached per engine.
pub struct Engine {
  priv atoms : Map[String, Atom]
  priv prefixes : Array[Prefix]
  priv insensitive_atoms : Map[String, Atom]
  priv insensitive_prefixes : Array[Prefix]
  priv mode : CodeMode
  priv cache : Map[String, NormalForm]
  priv metadata : Map[String, UnitInfo]
}

///|
// These readers handle only the pinned, bundled UCUM essence document.
// They are not an XML API and never accept external XML input.
fn attribute(header : String, key : String) -> String? {
  let marker = key + "=\""
  let start = match header.find(marker[:]) {
    Some(i) => i + marker.length()
    None => return None
  }
  let tail = header.view(start_offset=start).to_owned()
  match tail.find("\"") {
    Some(end) => Some(tail.view(end_offset=end).to_owned())
    None => None
  }
}

///|
fn catalog_blocks(tag : String) -> Array[String] {
  let opening = "<" + tag + " "
  let closing = "</" + tag + ">"
  let parts = Essence.split(opening[:]).to_array()
  let result = []
  for i in 1..<parts.length() {
    let block = parts[i].to_owned()
    let end = block.find(closing[:]).unwrap()
    result.push(block.view(end_offset=end).to_owned())
  }
  result
}

///|
fn definition_value(block : String) -> String {
  block.split("<value ").to_array()[1].to_owned()
}

///|
pub fn Engine::new(mode? : CodeMode = CaseSensitive) -> Engine {
  let atoms : Map[String, Atom] = Map([])
  let insensitive_atoms : Map[String, Atom] = Map([])
  let bases = ["m", "s", "g", "rad", "K", "C", "cd"]
  for i in 0..<bases.length() {
    let code = bases[i]
    atoms[code] = {
      code,
      metric: true,
      base: i,
      definition: "",
      multiplier: 1.0,
      special: false,
      arbitrary: false,
    }
  }
  for block in catalog_blocks("base-unit") {
    let code = attribute(block, "Code").unwrap()
    insensitive_atoms[attribute(block, "CODE").unwrap().to_upper()] = atoms[code]
  }
  for block in catalog_blocks("unit") {
    let header = block.split(">").to_array()[0].to_owned()
    let value = definition_value(block)
    let code = attribute(header, "Code").unwrap()
    let multiplier = match attribute(value, "value") {
      Some(v) => try! @string.parse_double(v[:])
      None => 1.0
    }
    atoms[code] = {
      code,
      metric: attribute(header, "isMetric") == Some("yes"),
      base: -1,
      definition: attribute(value, "Unit").unwrap(),
      multiplier,
      special: attribute(header, "isSpecial") == Some("yes"),
      arbitrary: attribute(header, "isArbitrary") == Some("yes"),
    }
    insensitive_atoms[attribute(header, "CODE").unwrap().to_upper()] = atoms[code]
  }
  let prefixes = []
  let insensitive_prefixes = []
  for block in catalog_blocks("prefix") {
    let multiplier = try! @string.parse_double(
      attribute(definition_value(block), "value").unwrap()[:],
    )
    prefixes.push({ code: attribute(block, "Code").unwrap(), multiplier, })
    insensitive_prefixes.push({
      code: attribute(block, "CODE").unwrap().to_upper(),
      multiplier,
    })
  }
  {
    atoms,
    prefixes,
    insensitive_atoms,
    insensitive_prefixes,
    mode,
    cache: Map([]),
    metadata: Map::from_array(metadata_rows().map(row => (row.code, row))),
  }
}

///|
pub fn Engine::code_mode(self : Engine) -> CodeMode {
  self.mode
}

///|
pub fn Engine::atom_count(self : Engine) -> Int {
  if self.mode == CaseSensitive {
    self.atoms.length()
  } else {
    self.insensitive_atoms.length()
  }
}

///|
pub fn Engine::prefix_count(self : Engine) -> Int {
  self.prefixes.length()
}

///|
/// Return the selected code system's distinct atom codes, sorted in a fresh array.
pub fn Engine::codes(self : Engine) -> Array[String] {
  let atoms = if self.mode == CaseSensitive {
    self.atoms
  } else {
    self.insensitive_atoms
  }
  let codes = atoms.keys().to_array()
  codes.sort()
  codes
}

///|
fn Engine::resolve(
  self : Engine,
  code : String,
  position : Int,
  mode : CodeMode,
) -> (Atom, Double) raise UcumError {
  let (atoms, prefixes, lookup) = match mode {
    CaseSensitive => (self.atoms, self.prefixes, code)
    CaseInsensitive =>
      (self.insensitive_atoms, self.insensitive_prefixes, code.to_upper())
  }
  if atoms.get(lookup) is Some(atom) {
    return (atom, 1.0)
  }
  let mut best : (Atom, Double)? = None
  let mut length = 0
  for prefix in prefixes {
    if lookup.has_prefix(prefix.code[:]) && prefix.code.length() > length {
      let rest = lookup.view(start_offset=prefix.code.length()).to_owned()
      if atoms.get(rest) is Some(atom) {
        if atom.metric {
          best = Some((atom, prefix.multiplier))
          length = prefix.code.length()
        }
      }
    }
  }
  match best {
    Some(value) => value
    None => raise UnknownUnit(position, code)
  }
}

///|
fn Engine::validate_tree(
  self : Engine,
  expression : Expr,
) -> Unit raise UcumError {
  match expression {
    Number(_) => ()
    Symbol(code, pos) => ignore(self.resolve(code, pos, self.mode))
    Product(a, b) | Quotient(a, b) => {
      self.validate_tree(a)
      self.validate_tree(b)
    }
    Power(a, _) | Annotation(a, _) => self.validate_tree(a)
  }
}

///|
/// Validate grammar and standard codes, including recognized special/arbitrary codes.
/// Success does not imply that a numeric conversion exists.
pub fn Engine::validate(self : Engine, input : String) -> Unit raise UcumError {
  self.validate_tree(parse_expression(input))
}
