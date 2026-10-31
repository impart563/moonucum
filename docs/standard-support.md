# UCUM 2.2 support

The implementation supports explicit case-sensitive and case-insensitive UCUM
code systems. Atom recognition, syntax acceptance and numeric semantics are
tested separately.

| Standard area | Implementation | Evidence |
|---|---|---|
| §§3–6 lexical rules | ASCII codes, metric prefixes, bracketed atoms, annotations | Upstream validation corpus and local boundary cases |
| §§7–10 syntax | Left-associative `.` and `/`, integer exponents, parentheses | AST and numeric equivalence tests |
| §§16–20 proper units | Definition expansion, seven-coordinate normalization | 250 proper atom codes; NLM comparison |
| §§21–23 special units | All 21 catalog special atoms: affine, logarithmic, tangent and square-root mappings | Temperature cases and independent formula assertions |
| §§24–26 arbitrary units | Recognized but rejected by numeric operations | All 41 arbitrary atom codes checked during acceptance |
| Code modes | Separate Code/CODE atom and prefix tables; sensitive by default | All 312 code-column pairs, 24 prefixes and 21 special functions |
| Tables 1–22 | Unmodified UCUM 2.2 essence document | 312 atom codes, 24 prefixes and recorded SHA-256 |

The parser follows the current §10 rule excluding exponents after a closing
parenthesis. It accepts `1{annotation}` as exercised by the FHIR upstream corpus.
Explicit exponents on pure numeric factors, such as `2+10`, are not supported;
this follows the corpus and BNF factor production, while the prose in §9 gives
such a numeric example. This remains an explicit compatibility boundary.

All special functions in the pinned catalog now have conversion paths. The 18
nonlinear atom codes (15 logarithmic including retired codes, two tangent and
one square-root) have no linear `NormalForm`. They are separate from the 253
linearly normalizable atoms. See [logarithmic-conversion.md](logarithmic-conversion.md)
and [special-conversion.md](special-conversion.md) for definitions and domains.

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

The case-insensitive column has 310 distinct aliases. Numeric semantics cover
271 case-sensitive atom codes or 270 insensitive aliases; 41 arbitrary codes
collapse to 40 insensitive aliases. See [code-modes.md](code-modes.md).
