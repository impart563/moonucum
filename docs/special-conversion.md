# Tangent, spectral and retired-code conversions

UCUM 2.2 §44 defines `100tan`, `hpX`, `hpC`, `hpM`, and `hpQ`. Section 47
defines `sqrt`. The implementation interprets the function name, factor and
proper reference from the unchanged essence document.

| Codes | Proper reference | Forward value from proper ratio r | Inverse ratio from encoded value x |
|---|---|---|---|
| `[p'diop]`, `%[slope]` | `1 rad` | `100 * tan(r)` | `atan(x / 100)` |
| `[hp'_X]` | 1 | `-ln(r) / ln(10)` | `10^(-x)` |
| `[hp'_C]` | 1 | `-ln(r) / ln(100)` | `100^(-x)` |
| `[hp'_M]` | 1 | `-ln(r) / ln(1000)` | `1000^(-x)` |
| `[hp'_Q]` | 1 | `-ln(r) / ln(50000)` | `50000^(-x)` |
| `[m/s2/Hz^(1/2)]` | `m2/s4/Hz` | `sqrt(r)` | `x^2` |

Sources: [UCUM specification](https://ucum.org/ucum), §§44 and 47, tables 18 and
21. The normative table associates the retired primed codes with unity, while
the prose retains historical wording about dilution per liter. MoonUCUM follows
the pinned essence table for their proper reference.

## Domains

Tangent conversion uses the principal interval `-pi/2 < angle < pi/2` to retain
a reversible mapping. Angles outside it, including endpoints, raise `Domain`.
An inverse tangent that rounds to an excluded endpoint raises `NonFinite`.
Conversions between the two tangent codes can rescale measurements directly,
without introducing an intermediate angle.

The spectral mapping converts nonnegative amplitude spectral density to its
corresponding power spectral density, and back. Both zero and positive values
are supported; negative inputs raise `Domain`, including identity conversions.
Its proper reference has dimensions `m2.s-3`. A linear `NormalForm` for the
amplitude code is not provided.

The retired primed codes implement historical encoded functions. Current
unprimed `[hp_X]`, `[hp_C]`, `[hp_M]`, `[hp_Q]` and the corresponding `[kp_*]`
codes remain arbitrary units and return `Unsupported` for numeric operations.

All nonlinear mappings allow dimensionless scalar scaling; dimensional products,
reciprocals and nonidentity powers remain unsupported. Squaring and square-root
paths use logarithmic intermediates where needed to preserve finite final
results. A mathematically positive result that underflows to zero raises
`NonFinite`.

## Verification

Formula and round-trip tests cover all seven codes, tangent branch boundaries,
zero and negative spectral values, scalar factors and extreme finite values.
The NLM comparison adds both conversion directions and composite scalar cases.
The separate consumer and sensor example exercise the tangent and spectral APIs.
