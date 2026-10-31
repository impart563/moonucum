# Reference implementation differences

The differential suite compares all 253 numerically supported atom codes with
`@lhncbc/ucum-lhc@8.0.1` at two values, then adds 55 composite and temperature
cases. The unchanged UCUM 2.2 catalog and specification determine MoonUCUM's
expected behavior. The NLM implementation provides an independent comparison.

The current 561 cases contain 532 numerical matches and 29 reviewed differences.
The test records both values and checks a specific policy for every reviewed
difference. Any other mismatch fails the command. Reviewed differences are
reported separately from matches.

| Codes | Cases | Observed difference | MoonUCUM basis |
|---|---:|---|---|
| `mol`, `eq`, `osm`, `kat`, `U` | 10 | NLM rejects conversion to the seven-coordinate base expression | UCUM §28 removes mole from the base system; the catalog defines mole as `6.02214076 * 10*23` and expands the other codes through it |
| `Bd`, `[diop]`, `[mesh_i]` | 6 | NLM rejects the catalog-derived base expression | The catalog definitions are `/s`, `/m`, and `/[in_i]` |
| `[NTU]`, `[FNU]` | 4 | NLM reports unknown codes | UCUM 2.2 adds both codes, defined with factor 1 relative to unity |
| `[LPF]` | 2 | NLM returns factor 1 relative to unity | UCUM table 18 and the pinned essence document specify factor 100 |
| `[degRe]` | 7 | NLM returns `(value + 273.15) * 1.25` | UCUM §43 specifies `1.25 * (value + 218.52)`, equivalent to `value * 1.25 + 273.15` |

The first groups concern unit semantics, not permission to interpret different
clinical measurements as equivalent. UCUM dimensions alone cannot establish that
two assays, substances, or measurement procedures are interchangeable.

Sources:

- [UCUM 2.2 specification](https://ucum.org/ucum), §§28, 30, 43 and tables 18, 21, 22.
- The exact catalog and test-source revisions are recorded in
  [sources.json](../standards/sources.json).
- [NLM UCUM implementation](https://github.com/LHNCBC/ucum-lhc).

Run `npm ci` followed by `npm test` to reproduce
[differential-results.json](../validation/differential-results.json).
