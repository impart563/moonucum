///|
test "catalog discovery resolves prefixes and keeps decoded names" {
  let e = @ucum.Engine::new()
  let pressure = e.describe("kPa")
  assert_eq(pressure.code, "Pa")
  assert_eq(pressure.insensitive_code, "PAL")
  assert_eq(pressure.property, "pressure")
  assert_true(e.describe("A").names.contains("ampère"))
  assert_true(e.describe("[IU]").arbitrary)
  assert_true(e.describe("[pH]").special)
  let names = e.describe("m").names
  names.clear()
  assert_true(e.describe("m").names.contains("meter"))
}

///|
test "catalog search uses the selected code table and stable order" {
  let cs = @ucum.Engine::new()
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  assert_eq(cs.search("").length(), 312)
  assert_eq(ci.search("").length(), 310)
  assert_true(cs.search("PRESSURE").iter().any(row => row.code == "Pa"))
  assert_true(ci.search("PAL").iter().any(row => row.code == "Pa"))
  assert_eq(ci.describe("kpal").code, "Pa")
  assert_eq(cs.search("unit-that-does-not-exist").length(), 0)
  let unknown = try {
    ignore(cs.describe("m/s"))
    false
  } catch {
    @ucum.UnknownUnit(_, _) => true
    _ => false
  }
  assert_true(unknown)
}
