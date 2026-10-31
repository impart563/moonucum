# Development guide

- Keep the root library independent of file access, networking and clinical rules.
- Implement UCUM semantics against the pinned specification and unchanged catalog.
- Separate invalid expressions, unknown codes, unsupported semantics and incompatible units.
- Never convert arbitrary units by treating them as dimensionless numbers.
- Add independent tests for parser and semantic changes. Preserve upstream expectations.
- Use `///|`, `moon fmt`, `moon info`, and run `python scripts/acceptance.py`.
- Keep examples synthetic and document numeric precision and standard coverage.
