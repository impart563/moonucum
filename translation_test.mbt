///|
test "translation preserves expression structure and annotation case" {
  let cs = @ucum.Engine::new()
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  for
    (source, expected) in [
      ("MPa{Patient A}/(kg.m-2)", "MAPAL{Patient A}/(KG.M-2)"),
      ("KiBy/s", "KIBBY/S"),
      ("10*3/uL", "10*3/UL"),
      ("[IU]{Assay}", "[IU]{Assay}"),
      ("", ""),
      ("/s", "/S"),
    ] {
    assert_eq(cs.translate(source, @ucum.CaseInsensitive), expected)
    ci.validate(expected)
  }
  assert_eq(ci.translate("mAm{Mixed}", @ucum.CaseSensitive), "Mm{Mixed}")
  assert_eq(cs.translate("Pa", @ucum.CaseInsensitive), "PAL")
  assert_eq(ci.translate("PA", @ucum.CaseSensitive), "pA")
  assert_eq(cs.translate("PA", @ucum.CaseInsensitive), "PTA")
}

///|
test "every catalog atom translates and round trips semantically" {
  let cs = @ucum.Engine::new()
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  for code in cs.codes() {
    let translated = cs.translate(code, @ucum.CaseInsensitive)
    let canonical = ci.translate(translated, @ucum.CaseSensitive)
    assert_eq(
      ci.describe(translated).insensitive_code,
      cs.describe(code).insensitive_code,
    )
    cs.validate(canonical)
    if !cs.describe(code).arbitrary {
      assert_true(cs.convert(1.0, code, canonical).is_close(1.0))
    }
  }
  let unknown = try {
    ignore(cs.translate("m/noSuch", @ucum.CaseInsensitive))
    false
  } catch {
    @ucum.UnknownUnit(offset, _) => offset == 2
    _ => false
  }
  assert_true(unknown)
}
