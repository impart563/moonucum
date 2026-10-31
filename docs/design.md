# Design and ecosystem role

MoonUCUM provides the UCUM standard code layer for applications that exchange
measurements. Its public interface takes in-memory strings and values; the
library performs no network or file operations.

## Processing

1. A bounded recursive-descent parser produces an `Expr` with source offsets.
2. Symbol resolution uses the pinned UCUM atom and prefix tables.
3. Definitions expand recursively into a seven-coordinate base representation.
4. Semantic operations compare dimensions, linear factors, temperature origins
   and supported logarithmic mappings. A compiled `Converter` reuses these mappings
   for each batch value.
5. Consumers retain responsibility for identifying the measured substance or
   phenomenon and deciding which measurement records can be compared.

`Engine` owns the atom catalog and a normalization cache. Internal maps and
dimension arrays remain private; accessors return copies where mutation would
otherwise affect later operations. A batch can reuse one engine.

The bundled XML string preserves the original essence document. Runtime readers
interpret its known structure; they do not expose a general XML parser or accept
external XML. The source manifest pins upstream commits and byte-level hashes.
The embedding and test generators are checked during acceptance.

## Errors

`Syntax` and `UnknownUnit` contain zero-based offsets into the ASCII input.
`Unsupported` reports recognized codes or constructions without implemented
numeric semantics. `Incompatible` separates dimensional mismatch from invalid
input. `Domain` distinguishes nonpositive quantities for logarithmic targets.
`Limit` and `NonFinite` report bounded resource and binary64 limitations.

## Existing MoonBit libraries

[LunarUnits](https://github.com/FrozenLemonTee/LunarUnits) provides general
physical quantities, dimensional arithmetic, expression parsing and conversion.
MoonUCUM concentrates on UCUM 2.2 code interpretation, the standard's particular
base system, annotation semantics, standard catalog provenance, and reproducible
compatibility evidence. It does not expose a new general-purpose physical
quantity arithmetic framework.

Future integration can translate supported normalized expressions through an
adapter. The base systems must be mapped explicitly: UCUM treats mole as a count
and radian as an independent coordinate, which matters when adapting SI-based
quantity representations.

## Consumers

- `examples/fhir`: synthetic coded quantities, unit normalization and rejection
  of display-only labels or incompatible quantities. This example implements a
  small Quantity workflow, not a complete FHIR resource validator.
- `examples/sensor`: temperature, velocity, atmospheric pressure and data volume.
- `examples/consumer`: a separate module using the root package's public API.
- `cmd/ucum`: JSON command results and batched JSON requests on all four stable
  target backends.
