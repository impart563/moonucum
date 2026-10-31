///|
fn main {
  let e = @ucum.Engine::new()
  e.validate("mg/dL") catch { error => abort(error.message()) }
  let concentration = e.convert(12.0, "mg/dL", "g/L") catch { error => abort(error.message()) }
  let speed = e.convert(72.0, "km/h", "m/s") catch { error => abort(error.message()) }
  if !concentration.is_close(0.12) || !speed.is_close(20.0) {
    abort("Consumer numeric check failed")
  }
  let rejected = try {
    ignore(e.convert(90.0, "mg/dL", "mmol/L"))
    false
  } catch {
    @ucum.Incompatible(_, _) => true
    _ => false
  }
  if !rejected { abort("Consumer dimensional check failed") }
  let logarithmic = e.converter("dB[W]", "W") catch { error => abort(error.message()) }
  for (value, expected) in [(0.0, 1.0), (10.0, 10.0), (20.0, 100.0)] {
    let actual = logarithmic.apply(value) catch { error => abort(error.message()) }
    if !actual.is_close(expected) { abort("Consumer logarithmic batch failed") }
  }
  let domain = try { ignore(e.convert(0.0, "mol/L", "[pH]")); false } catch {
    @ucum.Domain(_) => true
    _ => false
  }
  if !domain { abort("Consumer logarithmic domain check failed") }
  println("Independent consumer passed: clinical and sensor quantities")
  println("Logarithmic batch passed: reusable converter and domain error")
}
