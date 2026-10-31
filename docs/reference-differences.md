# Reference implementation differences

The differential suite compares all 253 linearly normalizable atom codes with
`@lhncbc/ucum-lhc@8.0.1` at two values, then adds 55 composite and temperature
cases, plus 108 logarithmic and pH cases. The unchanged UCUM 2.2 catalog and
specification determine MoonUCUM's expected behavior. The NLM implementation provides an independent comparison.

The current 669 cases contain 612 numerical matches and 57 reviewed differences.
The test records both values and checks a specific policy for every reviewed
difference. Any other mismatch fails the command. Reviewed differences are
reported separately from matches.

Nonzero results use relative tolerance `1e-10`; only an expected zero uses
absolute tolerance `1e-10`. This avoids masking catalog differences in very small
physical constants. The initial 0.1.0 comparison used an absolute tolerance floor
for all results; the stricter 0.2.0 comparison exposes 16 additional constant
cases, retained below with their unchanged observations.

| Codes | Cases | Observed difference | MoonUCUM basis |
|---|---:|---|---|
| `mol`, `eq`, `osm`, `kat`, `U` | 10 | NLM rejects conversion to the seven-coordinate base expression | UCUM §28 removes mole from the base system; the catalog defines mole as `6.02214076 * 10*23` and expands the other codes through it |
| `Bd`, `[diop]`, `[mesh_i]` | 6 | NLM rejects the catalog-derived base expression | The catalog definitions are `/s`, `/m`, and `/[in_i]` |
| `[NTU]`, `[FNU]` | 4 | NLM reports unknown codes | UCUM 2.2 adds both codes, defined with factor 1 relative to unity |
| `[LPF]` | 2 | NLM returns factor 1 relative to unity | UCUM table 18 and the pinned essence document specify factor 100 |
| `[degRe]` | 7 | NLM returns `(value + 273.15) * 1.25` | UCUM §43 specifies `1.25 * (value + 218.52)`, equivalent to `value * 1.25 + 273.15` |
| `u`, `eV`, `[G]`, `[e]`, `[h]`, `[k]`, `[m_e]`, `[m_p]` | 16 | NLM uses older physical constants | Pinned UCUM 2.2 table 5 values; both old reference factors and current factors are checked explicitly |
| `[pH]` to/from `mol/L` | 8 | NLM rejects commensurability | UCUM §45 explicitly defines the paired `10^(-x)` and `-log10(x)` transformations |
| `B/2` | 4 | NLM reports an unknown unit | UCUM §22 permits scaling a special unit by a dimensionless quantity; here the inverse is `10^(x/2)` |

Clinical consumers identify the measured substance and measurement procedure
before comparing values. Dimensional compatibility describes the unit
relationship; the consumer retains those data-specific conditions.

Sources:

- [UCUM 2.2 specification](https://ucum.org/ucum), §§22, 28, 30, 43, 45 and tables 5, 18, 21, 22.
- The exact catalog and test-source revisions are recorded in
  [sources.json](../standards/sources.json).
- [NLM UCUM implementation](https://github.com/LHNCBC/ucum-lhc).

Run `npm ci` followed by `npm test` to reproduce
[differential-results.json](../validation/differential-results.json).
