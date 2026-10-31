# Logarithmic conversion

`Engine::converter(source, target)` resolves expressions and dimensions once and
returns a `Converter`. `Converter::apply(value)` performs each numeric conversion.
`Engine::convert` provides the same behavior for a single value.

## Supported functions

UCUM 2.2 §§21–23 define special units through paired functions and corresponding
proper units. The implementation reads function names, numeric factors and
reference-unit expressions from the unchanged catalog.

| Codes | Proper reference | Inverse function from special value x |
|---|---|---|
| `Np` | 1 | `exp(x)` |
| `B` | 1 | `10^x` |
| `bit_s` | 1 | `2^x` |
| `B[SPL]` | `2 * 10^-5 Pa` | `10^(x/2)` |
| `B[V]`, `B[mV]`, `B[uV]`, `B[10.nV]` | `1 V`, `1 mV`, `1 uV`, `10 nV` respectively | `10^(x/2)` |
| `B[W]`, `B[kW]` | `1 W`, `1 kW` respectively | `10^x` |
| `[pH]` | `1 mol/L` | `10^(-x)` |

The resulting proper quantity is the reference multiplied by the inverse
function. A metric prefix or dimensionless scalar scales x before that function.
For example, `20 dB[V]` corresponds to `10 V`, while `20 dB[W]` corresponds to
`100 W`. `30 dB[W]` and `0 dB[kW]` represent the same proper power quantity.

Sources: [UCUM specification](https://ucum.org/ucum), §§22, 45, 46, 48 and table 20.
The exact catalog revision is recorded in [sources.json](../standards/sources.json).

## API behavior and numeric limits

- `compatible` compares corresponding dimensions for both linear and supported
  logarithmic units.
- `equivalent` compares mapping types, reference quantities and function scaling.
  A linear unit and logarithmic unit are not equivalent mappings.
- `normalize` continues to return only `y = factor * x + offset`. A logarithmic
  unit returns `Unsupported` because it has no such linear representation.
- `convert` and compiled converters support both directions, including
  logarithmic-to-logarithmic reference shifts.
- A logarithmic target requires a strictly positive proper quantity. Zero,
  negative values and negative zero raise `Domain`. Invalid finite ranges raise
  `NonFinite`, including exponential overflow and underflow to zero.
- Negative logarithmic measurements are valid inputs. Their interpretation
  follows the standard function rather than a fixed clinical range.
- Products with dimensioned quantities, reciprocals and nonidentity powers of
  logarithmic units return `Unsupported`. Prefixes and dimensionless scalar
  scaling are supported.

Log-to-log conversion is performed in logarithmic space, so a finite level can
be converted without first expanding a potentially overflowing proper value.
Linear-to-log conversion with zero offset uses logarithms of separate factors
to avoid multiplying an unnecessarily large or small intermediate quantity.

The `[pH]` path implements UCUM's encoded concentration relationship. Identifying
the measured chemical quantity remains part of the consumer's data model.

## Verification

Independent formula tests cover all 11 atom codes, prefixes and scalar factors,
reference shifts, positive-domain errors, nonlinear range limits, compiled
converters and precision at extreme values. The FHIR and sensor examples include
encoded acidity and a power level. The separate consumer runs a batch through
one compiled converter and checks the public `Domain` error.

The NLM comparison includes both directions of all 11 atom codes and composite
level expressions. Differences are described in
[reference-differences.md](reference-differences.md).
