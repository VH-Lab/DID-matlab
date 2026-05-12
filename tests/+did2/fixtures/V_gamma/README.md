# V_gamma test fixtures

Hermetic schema fixtures for the `+did2` MATLAB test suite. These exist
so unit tests do not depend on a sibling `did-schema` checkout or on
network access.

## Files

| File | Origin | Purpose |
|---|---|---|
| `base.json` | copied from [`Waltham-Data-Science/did-schema/schemas/V_gamma/base.json`](https://github.com/Waltham-Data-Science/did-schema/blob/main/schemas/V_gamma/base.json) | The root V_gamma class. Carries `id`, `session_id`, `name`, `datestamp`. |
| `CURIE_lookups_meta.json` | trimmed subset of upstream | CURIE prefix registry. The cache loads this on construction. |
| `demoA.json` | V_gamma translation of v1's `src/did/example_schema/demo_schema1/database_documents/demoA.json` | Extends `base`. Adds one queryable `value` field. |
| `demoB.json` | V_gamma translation of v1's `demoB.json` | Extends `demoA`. Adds one `value_b` field. Tests multi-level inheritance (`demoB -> demoA -> base`). |
| `demoC.json` | V_gamma translation of v1's `demoC.json` | Extends `base`. Declares three `_depends_on` entries (`item1`, `item2`, `item3`). Tests dependency declarations. |
| `demoFile.json` | V_gamma translation of v1's `demoFile.json` | Extends `base`. Declares two `_file` attachments. Tests file-record declarations. |

## Conventions

The `_schema` token in `_superclasses` entries (e.g.
`$DIDSCHEMAPATH/base.json`) is illustrative only — the +did2 cache
resolves superclasses by classname, looking up sibling JSON files in
this directory.

## Refreshing

If `base.json` or `CURIE_lookups_meta.json` change upstream, re-copy
them from the same paths above. The `demo*.json` files are V_gamma-only
fixtures and have no upstream counterpart; they evolve with the +did2
test suite.
