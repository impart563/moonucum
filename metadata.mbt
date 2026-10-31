///|
/// Catalog metadata describes an atom, without adding inferred synonyms.
/// Names and properties are decoded from the pinned UCUM XML.
pub struct UnitInfo {
  code : String
  insensitive_code : String
  names : Array[String]
  property : String
  metric : Bool
  arbitrary : Bool
  special : Bool
}

///|
/// Resolve an atom or a prefixed atom to its canonical catalog metadata.
/// Each call returns fresh name storage; prefixes do not alter the atom's names.
pub fn Engine::describe(
  self : Engine,
  code : String,
) -> UnitInfo raise UcumError {
  let (atom, _) = self.resolve(code, 0, self.mode)
  let entry = self.metadata[atom.code]
  { ..entry, names: entry.names.copy(), }
}

///|
/// Case-folded substring search over code, names and property, in code order.
/// This searches catalog atoms, not the unbounded set of prefixed expressions.
pub fn Engine::search(self : Engine, query : String) -> Array[UnitInfo] {
  let needle = query.to_lower()
  let rows = []
  for code in self.codes() {
    let entry = self.describe(code) catch { _ => continue }
    if code.to_lower().contains(needle[:]) ||
      entry.property.to_lower().contains(needle[:]) ||
      entry.names.iter().any(name => name.to_lower().contains(needle[:])) {
      rows.push(entry)
    }
  }
  rows
}
