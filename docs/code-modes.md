# UCUM code modes

`Engine::new()` uses the case-sensitive code system. Select
`Engine::new(mode=CaseInsensitive)` for UCUM's separate case-insensitive code
system. The mode is fixed for the lifetime of the engine and applies to both
source and target expressions. A compiled converter retains the resolved meaning.

UCUM §3 defines distinct code systems, and §4 defines prefix matching within
the chosen system. MoonUCUM loads the `Code` and `CODE` columns separately,
including the corresponding prefix symbols. ASCII case folding is applied only
to lookup in the case-insensitive table; it does not rewrite the input AST,
annotations or diagnostic symbols.

| Meaning | Case-sensitive code | Case-insensitive code |
|---|---|---|
| Pascal | `Pa` | `PAL` |
| Megameter | `Mm` | `MAM` |
| Millimeter | `mm` | `MM` |
| Gigameter | `Gm` | `GAM` |
| Neper | `Np` | `NEP` |
| Kilobyte with a binary prefix | `KiBy` | `KIBBY` |

The same text can have different meanings in different modes. For example,
`PA` is petaampere in the case-sensitive table and picoampere in the
case-insensitive table. `Pa` in insensitive mode also means picoampere; it does
not mean pascal. Clients select the code system explicitly before parsing data.

## Catalog and definitions

The source catalog contains 312 case-sensitive atom codes. Its case-insensitive
column has 310 distinct aliases: `l` and `L` share `L`, and `[iU]` and `[IU]`
share `[IU]`. `atom_count` and `codes` report the selected code system. Prefix
count remains 24. There are 271 convertible case-sensitive atom codes and 270
convertible insensitive aliases, with arbitrary units kept separate.

Definition expansion always interprets the catalog's canonical case-sensitive
expressions. This keeps symbols inside definitions independent of user input
mode and makes normalization caches safe to reuse. Normal forms use the same
canonical seven-coordinate basis in both modes.

The FHIR example continues to use the default case-sensitive engine.

## CLI

Place `--case-insensitive` before the operation:

```sh
moon run cmd/ucum -- --case-insensitive convert 1 PaL KPAL
moon run cmd/ucum -- --case-insensitive convert 12 MG/DL G/L
moon run cmd/ucum -- --case-insensitive catalog
```

`batch` uses the selected mode for every request. Catalog output includes
`code_mode`, and unknown-code diagnostics retain original input spelling and
zero-based offsets.

## Verification

The generated tests use all 312 `Code`/`CODE` pairs, all 24 prefix factors and
all 21 special atom functions from the unchanged XML. Handwritten cases check
mode-specific meanings, canonical definition expansion, repeated cache use,
arbitrary units and preserved diagnostics. Both modes are also exercised through
the CLI and an independently packaged consumer.

Source: [UCUM specification](https://ucum.org/ucum), §§3–4 and table 1; exact data
revision in [sources.json](../standards/sources.json).
