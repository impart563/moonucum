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
  println("Independent consumer passed: clinical and sensor quantities")
}
