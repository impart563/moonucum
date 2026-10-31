///|
test "seeded corpus checks 5000 proportional expressions in both code systems" {
  let cs = @ucum.Engine::new()
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  let atoms = ["m", "g", "s", "Pa", "L", "J", "N", "W", "C", "K"]
  let prefixes = [("k", 1000.0), ("m", 0.001), ("u", 0.000001), ("c", 0.01)]
  let mut seed = 563
  for index in 0..<5000 {
    seed = (seed * 251 + 17) % 65521
    let atom = atoms[seed % atoms.length()]
    let (prefix, scale) = prefixes[seed / 10 % prefixes.length()]
    let exponent = seed % 3 + 1
    let coefficient = seed % 9999 + 1
    let suffix = exponent.to_string() + "/s" + (seed % 5 + 1).to_string()
    let source = coefficient.to_string() +
      "." +
      prefix +
      atom +
      exponent.to_string() +
      "{sample" +
      index.to_string() +
      "}/s" +
      (seed % 5 + 1).to_string()
    let target = atom + suffix
    let input = (seed % 20001 - 10000).to_double() / 100.0
    let expected = input *
      coefficient.to_double() *
      @math.pow(scale, exponent.to_double())
    let actual = cs.convert(input, source, target)
    assert_true(
      actual.is_close(
        expected,
        relative_tolerance=1.0e-10,
        absolute_tolerance=0.0,
      ),
      msg=source,
    )
    assert_true(
      cs
      .convert(actual, target, source)
      .is_close(input, relative_tolerance=1.0e-10, absolute_tolerance=0.0),
    )
    assert_true(
      ci
      .convert(
        input,
        cs.translate(source, @ucum.CaseInsensitive),
        cs.translate(target, @ucum.CaseInsensitive),
      )
      .is_close(expected, relative_tolerance=1.0e-10, absolute_tolerance=0.0),
    )
  }
}

///|
test "seeded malformed corpus rejects 1000 incomplete operators" {
  let e = @ucum.Engine::new()
  for index in 1..<=1000 {
    let expression = index.to_string() + ".m{sample}/"
    let rejected = try {
      e.validate(expression)
      false
    } catch {
      @ucum.Syntax(_, _) => true
      _ => false
    }
    assert_true(rejected)
  }
}
