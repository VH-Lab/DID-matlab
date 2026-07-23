# V_delta test fixtures

Hermetic schema fixtures for the `+did2` MATLAB test suite. These exist
so unit tests do not depend on a sibling `did-schema` checkout or on
network access.

## Files

| File | Origin | Purpose |
|---|---|---|
| `base.json` | copied from [`Waltham-Data-Science/did-schema/schemas/V_delta/stable/base.json`](https://github.com/Waltham-Data-Science/did-schema/blob/main/schemas/V_delta/stable/base.json) | The root V_delta class. Carries `id`, `session_id`, `name`, `datestamp`. |
| `CURIE_lookups_meta.json` | trimmed subset of upstream | CURIE prefix registry. The cache loads this on construction. |
| `demoA.json` | V_delta translation of v1's `src/did/example_schema/demo_schema1/database_documents/demoA.json` | Extends `base`. Adds one queryable `value` field. |
| `demoB.json` | V_delta translation of v1's `demoB.json` | Extends `demoA`. Adds one `value_b` field. Tests multi-level inheritance (`demoB -> demoA -> base`). |
| `demoC.json` | V_delta translation of v1's `demoC.json` | Extends `base`. Declares three `depends_on` entries (`item1`, `item2`, `item3`). Tests dependency declarations. |
| `demoFile.json` | V_delta translation of v1's `demoFile.json` | Extends `base`. Declares two `file` attachments. Tests file-record declarations. |
| `demoArray.json` | local to +did2 | Extends `base`. Exercises the `queryable_array_elem` sidecar. |

## Conventions

Superclass references in V_delta carry only `class_name` (no `schema`
path key). The +did2 cache resolves superclasses by class_name,
looking up sibling JSON files in this directory.

These fixtures live flat (no tier subdirectory) because the cache
points its `schemaPath` at this directory directly. The upstream
V_delta layout uses `stable/` / `draft/` / `deprecated/` tier folders;
this hermetic fixture set is the equivalent of "stable only."

## Refreshing

If `base.json` or `CURIE_lookups_meta.json` change upstream, re-copy
them from the same paths above. The `demo*.json` files are
V_delta-only fixtures with no upstream counterpart; they evolve with
the +did2 test suite.
