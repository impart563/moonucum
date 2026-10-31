///|
fn measure(
  name : String,
  count : Int,
  action : (Int) -> Double raise @ucum.UcumError,
) -> Json raise @ucum.UcumError {
  let start = @bench.monotonic_clock_start()
  let mut checksum = 0.0
  for index in 0..<count {
    checksum += action(index)
  }
  {
    "name": name,
    "operations": count,
    "elapsed_us": @bench.monotonic_clock_end(start),
    "checksum": checksum,
  }
}

///|
fn main {
  let iterations = match @env.get_env_var("UCUM_BENCH_ITERATIONS") {
    Some(value) =>
      @string.parse_int(value[:]) catch {
        _ => abort("Invalid iteration count")
      }
    None => 20000
  }
  if iterations < 1000 || iterations > 1000000 {
    abort("Iteration count must be between 1000 and 1000000")
  }
  let engine = @ucum.Engine::new()
  let units = [
    "mg/dL", "kg.m/s2", "kPa", "uL", "m/s", "N.m", "KiBy", "mL{sample}",
  ]
  try {
    let converter = engine.converter("mg/dL", "g/L")
    let results = [
      measure("parse", iterations, i => {
        ignore(@ucum.parse_expression(units[i % units.length()]))
        1.0
      }),
      measure("normalize_warm", iterations, i => {
        engine.normalize(units[i % units.length()]).factor()
      }),
      measure("convert_reparse", iterations, i => {
        engine.convert((i % 101).to_double(), "mg/dL", "g/L")
      }),
      measure("converter_apply", iterations, i => {
        converter.apply((i % 101).to_double())
      }),
      measure("engine_create", 100, _ => {
        @ucum.Engine::new().atom_count().to_double()
      }),
    ]
    println(results.to_json().stringify())
  } catch {
    error => abort(error.message())
  }
}
