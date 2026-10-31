///|
fn main {
  let engine = @ucum.Engine::new()
  let readings = [
    ("ambient-temperature", 68.0, "[degF]", "Cel"),
    ("vehicle-speed", 72.0, "km/h", "m/s"),
    ("air-pressure", 1013.25, "hPa", "kPa"),
    ("payload-size", 64.0, "KiBy", "By"),
    ("power-level", 30.0, "dB[W]", "W"),
    ("surface-slope", 100.0, "%[slope]", "deg"),
    ("vibration-density", 3.0, "[m/s2/Hz^(1/2)]", "m2/s3"),
  ]
  for (sensor, value, source, target) in readings {
    try {
      let converted = engine.convert(value, source, target)
      println(
        (
          {
            "sensor": sensor,
            "original_value": value,
            "original_unit": source,
            "value": converted,
            "unit": target,
          } : Json).stringify(),
      )
    } catch {
      error =>
        println(
          ({ "sensor": sensor, "error": error.message() } : Json).stringify(),
        )
    }
  }
}
