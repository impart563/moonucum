# UCUM 2.2 support

The implementation targets the case-sensitive UCUM code system. Atom recognition,
syntax acceptance and numeric semantics are tested separately.

| Standard area | Implementation | Evidence |
|---|---|---|
| §§3–6 lexical rules | ASCII codes, metric prefixes, bracketed atoms, annotations | Upstream validation corpus and local boundary cases |
| §§7–10 syntax | Left-associative `.` and `/`, integer exponents, parentheses | AST and numeric equivalence tests |
| §§16–20 proper units | Definition expansion, seven-coordinate normalization | 250 proper atom codes; NLM comparison |
| §§21–23 special units | Affine temperatures and 11 logarithmic/pH codes with scalar scaling | Temperature cases and independent formula assertions |
| §§24–26 arbitrary units | Recognized but rejected by numeric operations | All 41 arbitrary atom codes checked during acceptance |
| Tables 1–22 | Unmodified UCUM 2.2 essence document | 312 atom codes, 24 prefixes and recorded SHA-256 |

The parser follows the current §10 rule excluding exponents after a closing
parenthesis. It accepts `1{annotation}` as exercised by the FHIR upstream corpus.
Explicit exponents on pure numeric factors, such as `2+10`, are not supported;
this follows the corpus and BNF factor production, while the prose in §9 gives
such a numeric example. This remains an explicit compatibility boundary.

The following seven special atom codes have recognized syntax but no implemented
conversion function:

`[p'diop]`, `%[slope]`, `[hp'_X]`, `[hp'_C]`, `[hp'_M]`, `[hp'_Q]`,
`[m/s2/Hz^(1/2)]`.

The 11 logarithmic and pH codes are numerically convertible but have no linear
`NormalForm`. They are counted separately from the 253 linearly normalizable
atom codes. See [logarithmic-conversion.md](logarithmic-conversion.md).

Other expressions involving recognized special codes can also be unsupported.
For example, `Cel/s` passes grammar and code lookup but has no supported numeric
unit semantics. Arbitrary units are never silently reduced to unity, including
when source and target text happen to match.

Binary64 limits precision. Results do not retain decimal significant figures or
measurement uncertainty. The original upstream conversion section includes
significant-figure rounding and older physical constants; it is retained in the
source fixture but is not presented as an executed conversion suite. The 529
validation cases are executed without changing their expectations. Numerical
tests use independent conversion comparisons and direct specification formulas.

The published validation report records supported and unsupported atom counts,
upstream case count, backend results, example results, and independent consumer
results. It does not claim full UCUM conformance or clinical validation.
