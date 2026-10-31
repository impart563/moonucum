# Changelog

## 0.4.0

- Add an explicit `CodeMode` option with separate UCUM atom and prefix tables.
- Preserve case-sensitive defaults and canonical definition expansion.
- Add `--case-insensitive` to the portable CLI and include code mode in catalog output.
- Check all 312 code-column pairs, 24 prefix factors and 21 special functions
  across both code systems, including alias counts and preserved diagnostics.

## 0.3.0

- Implement tangent mappings for prism diopter and percent slope, with an
  explicit invertible principal branch.
- Implement the spectral square/square-root mapping and the four retired-code
  dilution functions, retaining the current arbitrary-unit restrictions.
- Extend scalar rescaling and numerical-range checks for finite extreme values.
- Cover every special function in the pinned UCUM 2.2 catalog; numeric semantics
  now include 271 atom codes, with 41 arbitrary codes kept separate.
- Expand independent numerical comparisons to 741 cases.

## 0.2.0

- Add conversion for 11 logarithmic and pH atom codes, including metric prefixes
  and dimensionless scalar scaling.
- Add reusable `Converter` values through `Engine::converter` and value-domain
  failures through the new `Domain` error variant.
- Extend commensurability and equivalence checks to supported logarithmic units;
  retain the linear-only meaning of `NormalForm`.
- Expand numerical comparisons to 669 cases and use relative tolerance for
  nonzero results, exposing and documenting older reference-catalog constants.
- Extend the CLI, FHIR/sensor examples and extracted-package consumer checks.

Consumers with exhaustive `UcumError` matches must handle `Domain` in this version.

## 0.1.0

- Add bounded UCUM expression parsing with ASTs and source offsets.
- Load the UCUM 2.2 catalog with 312 atom codes and 24 prefixes.
- Normalize proper units and implement proportional and affine temperature conversions.
- Separate syntax, symbol, unsupported-semantics, dimensional and numeric errors.
- Provide a portable JSON CLI and FHIR and sensor examples.
- Add upstream validation cases, independent numerical comparisons and a separate consumer module.
