# Minimal schema fixtures

Hermetic schema fixtures for the `+did2` MATLAB test suite. These exist
so unit tests do not depend on a sibling `did-schema` checkout or on
network access. They exercise the schema-cache, document, query and
database machinery; they are not a copy of the V_eta schema set.

## Files

| File | Origin | Purpose |
|---|---|---|
| `base.json` | copied from did-schema's earlier `stable/base.json` (that tree is deleted, did-schema #88) | The root class. Carries `id`, `session_id`, `name`, `datestamp`. |
| `CURIE_lookups_meta.json` | trimmed subset of upstream | CURIE prefix registry. The cache loads this on construction. |
| `demoA.json` | translation of v1's `src/did/example_schema/demo_schema1/database_documents/demoA.json` | Extends `base`. Adds one queryable `value` field. |
| `demoB.json` | translation of v1's `demoB.json` | Extends `demoA`. Adds one `value_b` field. Tests multi-level inheritance (`demoB -> demoA -> base`). |
| `demoC.json` | translation of v1's `demoC.json` | Extends `base`. Declares three `depends_on` entries (`item1`, `item2`, `item3`). Tests dependency declarations. |
| `demoFile.json` | translation of v1's `demoFile.json` | Extends `base`. Declares two `file` attachments. Tests file-record declarations. |
| `demoArray.json` | local to +did2 | Extends `base`. Exercises the `queryable_array_elem` sidecar. |

## Conventions

Superclass references carry only `class_name` (no `schema` path key).
The +did2 cache resolves superclasses by class_name, looking up sibling
JSON files in this directory.

These fixtures live flat (no tier subdirectory) because the cache
points its `schemaPath` at this directory directly. The did-schema
layout uses `stable/` / `draft/` / `deprecated/` tier folders; this
hermetic fixture set is the equivalent of "stable only."

## Refreshing

`base.json` keeps the field shape the database tests were written
against (`base.session_id` and `base.datestamp` as fields); it is not
refreshed from V_eta, whose `base` differs. The `demo*.json` files have
no upstream counterpart; they evolve with the +did2 test suite.
