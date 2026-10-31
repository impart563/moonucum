///|
fn diagnostic(error : @lib.UcumError) -> Json {
  match error {
    @lib.Syntax(offset, message) =>
      { "ok": false, "error": "syntax", "offset": offset, "message": message }
    @lib.UnknownUnit(offset, code) =>
      { "ok": false, "error": "unknown_unit", "offset": offset, "code": code }
    @lib.Unsupported(message) =>
      { "ok": false, "error": "unsupported", "message": message }
    @lib.Incompatible(source, target) =>
      {
        "ok": false,
        "error": "incompatible",
        "source": source,
        "target": target,
      }
    @lib.Limit(message) => { "ok": false, "error": "limit", "message": message }
    @lib.Domain(message) =>
      { "ok": false, "error": "domain", "message": message }
    @lib.NonFinite => { "ok": false, "error": "non_finite" }
  }
}

///|
fn normal_json(form : @lib.NormalForm) -> Json {
  {
    "ok": true,
    "factor": form.factor(),
    "offset": form.origin(),
    "basis": form.basis(),
    "dimensions": form.exponents(),
    "affine": form.is_affine(),
  }
}

///|
fn execute(engine : @lib.Engine, input : Json) -> Json {
  try {
    match input {
      { "op": "validate", "unit": String(unit), .. } => {
        engine.validate(unit)
        { "ok": true, "unit": unit }
      }
      { "op": "normalize", "unit": String(unit), .. } =>
        normal_json(engine.normalize(unit))
      {
        "op": "interval",
        "lower": Number(lower, ..),
        "upper": Number(upper, ..),
        "source": String(source),
        "target": String(target),
        ..
      } => {
        let result = engine
          .converter(source, target)
          .apply_interval(@lib.Interval::new(lower, upper))
        {
          "ok": true,
          "lower": result.lower,
          "upper": result.upper,
          "unit": target,
        }
      }
      { "op": "translate", "unit": String(unit), "mode": String(mode), .. } => {
        let target = match mode {
          "case-sensitive" => @lib.CaseSensitive
          "case-insensitive" => @lib.CaseInsensitive
          _ =>
            return {
              "ok": false,
              "error": "request",
              "message": "Unknown target code mode.",
            }
        }
        { "ok": true, "unit": engine.translate(unit, target), "mode": mode }
      }
      {
        "op": "convert",
        "value": Number(value, ..),
        "source": String(source),
        "target": String(target),
        ..
      } => {
        let result = engine.convert(value, source, target)
        { "ok": true, "value": result, "unit": target }
      }
      {
        "op": "equivalent",
        "source": String(source),
        "target": String(target),
        ..
      } =>
        {
          "ok": true,
          "equivalent": engine.equivalent(source, target),
          "compatible": engine.compatible(source, target),
        }
      _ =>
        {
          "ok": false,
          "error": "request",
          "message": "Expected validate/normalize with unit, or convert/equivalent with source and target.",
        }
    }
  } catch {
    error => diagnostic(error)
  }
}

///|
fn parse_request(engine : @lib.Engine, text : String) -> Json {
  let input = @json.parse(text[:]) catch {
    _ =>
      return {
        "ok": false,
        "error": "json",
        "message": "Invalid JSON request.",
      }
  }
  execute(engine, input)
}

///|
// Node includes both its executable and the script in process.argv.
#cfg(target="js")
fn cli_args() -> Array[String] {
  let args = @env.args()
  if args.is_empty() {
    []
  } else {
    args[1:].to_owned()
  }
}

///|
#cfg(not(target="js"))
fn cli_args() -> Array[String] {
  @env.args()
}

///|
fn main {
  let (mode, args) = match cli_args() {
    [program, "--case-insensitive", .. rest] => {
      let arguments = [program]
      for argument in rest {
        arguments.push(argument)
      }
      (@lib.CaseInsensitive, arguments)
    }
    arguments => (@lib.CaseSensitive, arguments)
  }
  let engine = @lib.Engine::new(mode~)
  let output : Json = match args {
    [_, "validate", unit] => execute(engine, { "op": "validate", "unit": unit })
    [_, "normalize", unit] =>
      execute(engine, { "op": "normalize", "unit": unit })
    [_, "translate", unit, mode] =>
      execute(engine, { "op": "translate", "unit": unit, "mode": mode })
    [_, "convert", value, source, target] => {
      let number = @string.parse_double(value[:]) catch {
        _ => {
          println(
            (
              {
                "ok": false,
                "error": "number",
                "message": "Expected a finite decimal number.",
              } : Json).stringify(),
          )
          return
        }
      }
      execute(engine, {
        "op": "convert",
        "value": number,
        "source": source,
        "target": target,
      })
    }
    [_, "equivalent", source, target] =>
      execute(engine, { "op": "equivalent", "source": source, "target": target })
    [_, "batch", .. requests] => {
      for text in requests {
        println(parse_request(engine, text).stringify())
      }
      return
    }
    [_, "catalog"] => {
      let rows = engine
        .codes()
        .map(code => {
          let normalization = normal_json(engine.normalize(code)) catch {
            error => diagnostic(error)
          }
          let conversion_supported = try {
            ignore(engine.converter(code, code))
            true
          } catch {
            _ => false
          }
          (
            {
              "code": code,
              "normalization": normalization,
              "conversion_supported": conversion_supported,
            } : Json)
        })
      {
        "ucum_version": "2.2",
        "code_mode": if mode == @lib.CaseSensitive {
          "case-sensitive"
        } else {
          "case-insensitive"
        },
        "atoms": engine.atom_count(),
        "prefixes": engine.prefix_count(),
        "units": rows,
      }
    }
    _ => {
      println(
        "MoonUCUM 0.4.0 — UCUM 2.2\nOptional leading flag: --case-insensitive\nvalidate UNIT\nnormalize UNIT\nconvert VALUE SOURCE TARGET\nequivalent SOURCE TARGET\ncatalog\nbatch JSON_REQUEST ...\nResults are JSON; inspect the ok field for each operation.",
      )
      return
    }
  }
  println(output.stringify())
}
