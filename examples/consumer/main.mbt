///|
fn main {
  let e = @ucum.Engine::new()
  e.validate("mg/dL") catch {
    error => abort(error.message())
  }
  let concentration = e.convert(12.0, "mg/dL", "g/L") catch {
    error => abort(error.message())
  }
  let speed = e.convert(72.0, "km/h", "m/s") catch {
    error => abort(error.message())
  }
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
  if !rejected {
    abort("Consumer dimensional check failed")
  }
  let logarithmic = e.converter("dB[W]", "W") catch {
    error => abort(error.message())
  }
  for (value, expected) in [(0.0, 1.0), (10.0, 10.0), (20.0, 100.0)] {
    let actual = logarithmic.apply(value) catch {
      error => abort(error.message())
    }
    if !actual.is_close(expected) {
      abort("Consumer logarithmic batch failed")
    }
  }
  let domain = try {
    ignore(e.convert(0.0, "mol/L", "[pH]"))
    false
  } catch {
    @ucum.Domain(_) => true
    _ => false
  }
  if !domain {
    abort("Consumer logarithmic domain check failed")
  }
  println("Independent consumer passed: clinical and sensor quantities")
  println("Logarithmic batch passed: reusable converter and domain error")
  let angle = e.convert(100.0, "%[slope]", "deg") catch {
    error => abort(error.message())
  }
  let spectral = e.convert(3.0, "[m/s2/Hz^(1/2)]", "m2/s3") catch {
    error => abort(error.message())
  }
  if !angle.is_close(45.0) || !spectral.is_close(9.0) {
    abort("Consumer special conversion failed")
  }
  println("Special functions passed: principal angle and spectral density")
  let ci = @ucum.Engine::new(mode=@ucum.CaseInsensitive)
  let pressure = ci.convert(1.0, "PaL", "KPAL") catch {
    error => abort(error.message())
  }
  let current = ci.convert(1.0, "PA", "A") catch {
    error => abort(error.message())
  }
  if !pressure.is_close(0.001) ||
    !current.is_close(
      1.0e-12,
      relative_tolerance=1.0e-12,
      absolute_tolerance=0.0,
    ) {
    abort("Consumer code mode check failed")
  }
  println(
    "Code modes passed: isolated tables and canonical definition expansion",
  )
  let info = e.describe("kPa") catch { error => abort(error.message()) }
  if info.code != "Pa" || e.search("pressure").is_empty() {
    abort("Consumer catalog discovery failed")
  }
  let translated = e.translate("MPa{Reading}", @ucum.CaseInsensitive) catch {
    error => abort(error.message())
  }
  if translated != "MAPAL{Reading}" {
    abort("Consumer code translation failed")
  }
  let batch = e.convert_many([(12.0, "mg/dL", "g/L"), (1.0, "m", "s")])
  match (batch[0], batch[1]) {
    (Ok(value), Err(@ucum.Incompatible(_, _))) if value.is_close(0.12) => ()
    _ => abort("Consumer batch results failed")
  }
  let interval = e
    .converter("[pH]", "mol/L")
    .apply_interval(@ucum.Interval::new(6.0, 8.0)) catch {
      error => abort(error.message())
    }
  if !interval.lower.is_close(
      1.0e-8,
      relative_tolerance=1.0e-12,
      absolute_tolerance=0.0,
    ) {
    abort("Consumer interval failed")
  }
  let quantity = @fhir.convert_quantity(
    e,
    {
      "value": 12,
      "system": "http://unitsofmeasure.org",
      "code": "mg/dL",
      "comparator": "<",
    },
    "g/L",
  ) catch {
    error => abort(error.message())
  }
  match quantity {
    { "code": "g/L", "comparator": "<", "value": Number(value, ..), .. } if value.is_close(
        0.12,
      ) => ()
    _ => abort("Consumer FHIR adapter failed")
  }
  println(
    "Data integration passed: catalog, translation, batches, intervals and FHIR adapter",
  )
  let order = e.compare_quantities(
    (12.0, "mg/dL"),
    (0.12, "g/L"),
    "g/L",
    relative_tolerance=1.0e-12,
  ) catch {
    error => abort(error.message())
  }
  if order != @ucum.Same {
    abort("Consumer quantity comparison failed")
  }
  let position = e
    .converter("cm", "m")
    .classify(100.0, @ucum.Interval::new(1.0, 2.0, lower_closed=false)) catch {
      error => abort(error.message())
    }
  if position != @ucum.Below {
    abort("Consumer interval membership failed")
  }
  let range = @fhir.convert_range(
    e,
    {
      "low": {
        "value": 6,
        "code": "[pH]",
        "system": "http://unitsofmeasure.org",
        "id": "pH-six",
      },
      "high": {
        "value": 8,
        "code": "[pH]",
        "system": "http://unitsofmeasure.org",
        "id": "pH-eight",
      },
    },
    "mol/L",
  ) catch {
    error => abort(error.message())
  }
  if !(range
    is { "low": { "id": "pH-eight", .. }, "high": { "id": "pH-six", .. }, .. }) {
    abort("Consumer FHIR Range failed")
  }
  let ratio = @fhir.convert_ratio(
    e,
    {
      "numerator": {
        "value": 5,
        "code": "mg",
        "system": "http://unitsofmeasure.org",
      },
      "denominator": {
        "value": 10,
        "code": "mL",
        "system": "http://unitsofmeasure.org",
      },
    },
    "g",
    "L",
  ) catch {
    error => abort(error.message())
  }
  match ratio {
    {
      "numerator": { "value": Number(numerator, ..), "code": "g", .. },
      "denominator": { "value": Number(denominator, ..), "code": "L", .. },
      ..
    } if numerator.is_close(0.005) && denominator.is_close(0.01) => ()
    _ => abort("Consumer FHIR Ratio failed")
  }
  println(
    "Structured quantities passed: comparison, membership, FHIR Range and Ratio",
  )
}
