///|
/// Convert a homogeneous batch, preserving positions and individual errors.
/// A failed value does not discard later results. The input array is unchanged.
pub fn Converter::apply_all(
  self : Converter,
  values : Array[Double],
) -> Array[Result[Double, UcumError]] {
  values.map(value => Ok(self.apply(value)) catch { error => Err(error) })
}

///|
/// Convert heterogeneous rows. Each distinct source/target pair is parsed once
/// per call, including failed pairs. Results correspond to input row indices.
pub fn Engine::convert_many(
  self : Engine,
  rows : Array[(Double, String, String)],
) -> Array[Result[Double, UcumError]] {
  let converters : Map[(String, String), Result[Converter, UcumError]] = Map([])
  rows.map(row => {
    let (value, source, target) = row
    let key = (source, target)
    let converter = match converters.get(key) {
      Some(cached) => cached
      None => {
        let compiled = Ok(self.converter(source, target)) catch {
          error => Err(error)
        }
        converters[key] = compiled
        compiled
      }
    }
    match converter {
      Ok(compiled) => Ok(compiled.apply(value)) catch { error => Err(error) }
      Err(error) => Err(error)
    }
  })
}
