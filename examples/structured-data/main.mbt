///|
// Synthetic coded data; no patient or device records are read here.
fn main {
  let engine = @ucum.Engine::new()
  let range = @fhir.convert_range(
    engine,
    {
      "id": "synthetic-acidity-range",
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
  println(
    ({ "example": "decreasing range", "result": range } : Json).stringify(),
  )
  let ratio = @fhir.convert_ratio(
    engine,
    {
      "id": "synthetic-concentration-ratio",
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
  println(
    ({ "example": "preserved ratio", "result": ratio } : Json).stringify(),
  )
  let position = engine
    .converter("cm", "m")
    .classify(150.0, @ucum.Interval::new(1.0, 2.0, upper_closed=false)) catch {
      error => abort(error.message())
    }
  println(
    (
      { "example": "interval membership", "within": position == @ucum.Within } :
      Json).stringify(),
  )
}
