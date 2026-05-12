# DID-matlab v2 Plan — V_gamma support

**Status:** living document. Edit freely as decisions are made or revised.

**Scope:** transform DID-matlab so it consumes `did-schema` V_gamma (and later
releases) end-to-end — document model, validation, storage, and queries — while
keeping the current V_alpha-compatible code on a maintenance line for existing
users.

---

## 1. Decisions already made

| # | Decision | Notes |
|---|---|---|
| 1 | Treat v2 as a parallel line, not an in-place upgrade. | New namespace (`+did2`, or rename `+did` → `+did_legacy` then re-introduce `+did` for v2). Downstream packages can import both during transition. |
| 2 | No mixed-version storage. One database file = one schema generation. | Conversion happens via an explicit tool, not at read time. |
| 3 | SQLite + JSON1 is the v2 reference backend. | Verified on MATLAB-bundled `mksqlite` (SQLite 3.39.2): `json_extract`, `json_each`, `EXISTS` over `json_each`, and `STORED` generated columns built from `json_extract` all work. See §6. |
| 4 | Keep the `matlabdumbjsondb` backend. | Useful for tests, trivial deployments, and as a non-SQL reference implementation of the query model. |
| 5 | Validate on insert by default; expose an `unsafe_insert` escape hatch for bulk loads; offer a `revalidate_all` maintenance op. | Schema files are the source of truth for what "valid" means. |
| 6 | Plan lives at `docs/v2/PLAN.md` on the v2 development branch. | This file. |
| 7 | Provisional namespace: `+did2`. | Picked from §10 option A for the scaffold. Revisit before v2 reaches `main`. |
| 8 | Document instances use a top-level `document_class` header plus class-scoped property blocks (one block per class in the chain, keyed by `class_name` verbatim). | See §4.1. Matches V_gamma_SPEC.md "JSON Format: Document Instances" after the SPEC's two-step revision: (i) restore class-scoped blocks; (ii) drop the underscore prefix on all NDI-extension keys. Every key in the wire shape is a plain MATLAB identifier, so the in-memory MATLAB struct is the JSON shape verbatim. |

Open questions are in §10.

---

## 2. Why a clean break (and not a coexistence shim)

The V_gamma document shape is structurally different from the current MATLAB
`document_properties` layout in three ways that compound:

- Top-level keys are snake_case (`id`, `class_version`, `depends_on`) instead of
  the V_alpha `base.*` / `document_class.*` / `<property_list_name>` nesting.
- Several classes bumped to `_class_version: 2.0.0` and collapsed multiple
  coordinated fields into a single named composite (e.g. `probe_location` lost
  `ontology_name`+`name`, gained `location` as an `ontology_term`).
- V_gamma adds named composite types (`ontology_term`, plus SI-dimensioned
  `duration`/`voltage`/`length`/...). A single field carries a fixed sub-field
  layout, e.g. `sample_rate.hertz`, `sample_rate.approximate`,
  `sample_rate.source_unit`, `sample_rate.source_value`.

Mixing both shapes inside one document object, one validator, and one
query compiler doubles the test matrix and forces every API surface to leak
the version distinction. A clean v2 is cheaper to build and far cheaper to
maintain. Users get a one-shot converter (§7).

---

## 3. Storage layout (SQLite + JSON1)

Reference schema for the v2 SQLite backend. All paths below are illustrative;
final column names live in code.

### 3.1 Canonical tables

```sql
CREATE TABLE documents (
    id            TEXT PRIMARY KEY,              -- did_id
    classname     TEXT NOT NULL,
    class_version TEXT NOT NULL,
    session_id    TEXT,
    datestamp     TEXT NOT NULL,                  -- ISO-8601 UTC
    body          TEXT NOT NULL,                  -- full V_gamma JSON
    body_hash     TEXT NOT NULL                   -- content hash for dedup/audit
);
CREATE INDEX documents_classname     ON documents(classname);
CREATE INDEX documents_session_id    ON documents(session_id);
CREATE INDEX documents_datestamp     ON documents(datestamp);

CREATE TABLE superclasses (
    doc_id    TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    classname TEXT NOT NULL,
    PRIMARY KEY (doc_id, classname)
);
CREATE INDEX superclasses_classname  ON superclasses(classname);

CREATE TABLE depends_on (
    doc_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    name   TEXT NOT NULL,
    value  TEXT NOT NULL,
    PRIMARY KEY (doc_id, name)
);
CREATE INDEX depends_on_name_value   ON depends_on(name, value);
```

### 3.2 Queryable scalar paths — generated columns + indexes

Test 4 in the JSON1 probe confirmed that `STORED GENERATED ALWAYS AS
(json_extract(body, '$.foo.bar'))` works with `mksqlite`. So for each scalar
`queryable: true` path declared by the V_gamma schemas, we add a stored
generated column directly on `documents` plus an index on it.

The set of paths is computed at database open by walking the loaded schemas:

```sql
ALTER TABLE documents
  ADD COLUMN q_sample_rate_hertz REAL
  GENERATED ALWAYS AS (json_extract(body, '$.sample_rate.hertz')) STORED;
CREATE INDEX documents_q_sample_rate_hertz ON documents(q_sample_rate_hertz);
```

Column names are mechanically generated (`q_` prefix + dot-path with `_`
separators) so the query compiler can find them without a name registry.

### 3.3 Queryable array-iteration paths — sidecar table

Generated columns can't carry multi-row projections, so `[*]` paths get a
sidecar:

```sql
CREATE TABLE queryable_array_elem (
    doc_id      TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    path        TEXT NOT NULL,            -- e.g. 'axes[*].unit'
    elem_index  INTEGER NOT NULL,
    value_text  TEXT,
    value_num   REAL
);
CREATE INDEX qae_path_text ON queryable_array_elem(path, value_text);
CREATE INDEX qae_path_num  ON queryable_array_elem(path, value_num);
```

Populated at insert time by walking the schema's array-of-structure fields and
their queryable sub-fields. Existential semantics (per `did_query_model.md`)
drop straight out of `EXISTS (SELECT 1 FROM queryable_array_elem WHERE …)`.

### 3.4 Fallback

For paths that are not queryable-indexed (ad-hoc exploration, future fields
before reindex), the query compiler falls back to `json_extract` /
`json_each` against `body` directly. Slower, but always correct.

### 3.5 Optional: FTS5

If full-text search over document bodies is wanted, an `FTS5` virtual table
shadowing `documents.body` can be added later. Not on the critical path.

---

## 4. Document object

A new `+did2/document.m` (or rename) class that:

- Holds the V_gamma JSON shape directly. No translation to/from `base.*`
  nesting.
- Loads, serialises, and validates against `did-schema` V_gamma schema files
  resolved through the schema cache (see §5).
- Exposes a dot-path getter (`doc.get('sample_rate.hertz')`) and array-aware
  iterator that the query layer uses.
- Knows how to construct itself from a classname + values, filling
  `blank_value`s for unset fields.

Validation timing: explicit, deferred. The database layer calls
`doc.validate()` on insert by default; an `unsafe_insert` API skips it for
bulk loads. A `revalidate_all(db)` maintenance op exists for the case where
schemas change.

### 4.1 In-memory document shape

A `did2.document`'s `documentProperties` is a MATLAB struct that mirrors the
V_gamma JSON shape *as specified in V_gamma_SPEC.md, "JSON Format: Document
Instances"*, exactly. After V_gamma's "drop underscore prefixes" pass,
every key in the wire shape is a plain identifier with no leading
underscore, so the MATLAB struct field names match the JSON keys
one-to-one. `jsonencode` / `jsondecode` round-trip without any rewrite.

Top-level keys populated by `did2.schema.cache.buildBlankDocument`:

| Key              | Type         | Contents |
|------------------|--------------|----------|
| `document_class` | struct       | `class_name` (concrete class), `class_version` (semver), `superclasses` (struct array; each entry has `class_name` + `class_version` — the document-instance form). |
| `depends_on`     | struct array | Each entry: `name` (role) and `value` (the referenced document's id). Empty by default. |
| `base`           | struct       | Property block with the four base fields (`id`, `session_id`, `name`, `datestamp`). `id` auto-minted via `did.ido.unique_id`, `datestamp` set to current UTC millisecond ISO-8601 with trailing `Z`. |
| `<class_name>`   | struct       | One property block per class in the chain (root through concrete class). Each populated with `blank_value` for the fields *that class* declares. Empty `{}` if it declares none. |

Field identity is `(declaring_class, name)`. Same-named fields in
different classes of the chain are distinct paths (`base.id` vs.
`<subclass>.id`), not an override.

V_alpha → V_gamma at the document level:

```
V_alpha                                  V_gamma
-------                                  -------
document_class.class_name                document_class.class_name
document_class.class_version             document_class.class_version
document_class.superclasses              document_class.superclasses
document_class.property_list_name        (gone; block key == class_name)
document_class.definition                (gone; schema files own this)
document_class.validation                (gone; schema files own this)
base.id, base.session_id, ...            base.id, base.session_id, ...
<property_list_name>.<field>             <class_name>.<field>
depends_on                               depends_on
```

The converter (§7) is now a thin per-document data migration: strip the
extra `document_class` sub-keys (`property_list_name`, `definition`,
`validation`); rename each property block whose `property_list_name`
differs from its `class_name` so the block key equals the class name;
done. NDI-matlab consumers that already speak the V_alpha class-scoped
layout need no source-code rewrites for the wire shape itself.

---

## 5. Schema cache

A `+did2/+schema/cache.m` (or similar) loads all V_gamma schema files once,
resolves superclass chains, and pre-computes:

- For each classname: the full inherited field list.
- The subset of fields with `queryable: true`, split into scalar paths and
  array-iteration paths.
- The named composite type expansions (`duration` → `.seconds`,
  `.approximate`, `.source_unit`, `.source_value`).
- The CURIE registry from `CURIE_lookups_meta.json` (used for ontology-term
  resolution and warnings on unknown prefixes).

The cache is what drives index-column generation (§3.2), array-sidecar
population (§3.3), and validation (§4). No reflection on runtime values.

---

## 6. Query layer

Re-implement `+did2/query.m` against `did_query_model.md`. Two backends share
one query tree:

1. **SQL compiler** — turns the tree into a single statement against §3.
   - Scalar leaves → indexed lookup on a generated column when the path is in
     the schema's queryable set; `json_extract` fallback otherwise.
   - `[*]` leaves → `EXISTS` against `queryable_array_elem` when indexed;
     `EXISTS` over `json_each` fallback otherwise.
   - `and()` → `INTERSECT` (or chained `EXISTS`); `or()` → `UNION`.
   - `isa` → indexed lookup on `superclasses`.
   - `depends_on` → indexed lookup on `depends_on`.
   - `~` negation → `NOT EXISTS` / negated comparison at the leaf.
2. **In-memory evaluator** — walks the document object directly. Used by
   `matlabdumbjsondb`, by pre-insert validation paths, and as the executable
   spec the SQL compiler is tested against.

Both backends share the same query tree type, so building two backends costs
much less than two query languages.

The model is deliberately small: no correlated `[*]` predicates, no
per-element numeric comparisons, no cross-doc joins. We follow the spec — if
users need correlated semantics, they denormalise to a scalar shadow field.

---

## 7. Conversion from v1 databases

A `+did2/+convert/v1_to_v2.m` tool:

1. Opens the old DB read-only.
2. For each document, calls a per-classname migration function (table-driven;
   the table lives next to the v2 schema package).
3. Renames top-level keys (`base.id` → `id`, etc.), rewrites collapsed fields
   on classes that bumped to `2.0.0` (`probe_location`, `treatment`,
   `ontology_image`, `ontology_label`), and reshapes `ontology` annotations
   to the V_gamma two-key form.
4. Validates against V_gamma. Successful docs insert into the new DB; failures
   land in a `quarantine` table with the original body and a reason string.
   Nothing is silently dropped.

The converter ships in v2, not v1, so v1 users aren't forced to upgrade their
existing read-only workflows.

---

## 8. Backwards compatibility / coexistence

- `release/v1.x` branch holds the V_alpha-compatible line. Critical bug fixes
  only.
- v2 development lives on `v2` (this branch). Downstream packages
  (NDI-matlab, vhlab_vhtools) pin to a v1 tag until they port.
- Once NDI-matlab v2 stabilises, v2 becomes default (`main`) and v1 retires.

---

## 9. Order of work

1. **`+did2/document.m`** — V_gamma document object with load/validate/
   serialise. No DB dependency. Unblocks everything else.
2. **In-memory query evaluator** — port `+did/query.m` operator set; add
   dot-paths and `[*]`. Becomes the executable spec.
3. **SQLite backend, JSON1 fallback only** — `documents`, `superclasses`,
   `depends_on`; query compiler uses `json_extract`/`json_each` for
   everything. Slow but complete.
4. **Indexed scalar paths** — schema-driven generated columns + indexes
   (§3.2). Query compiler routes to them when available.
5. **`queryable_array_elem` sidecar** — schema-driven population, query
   compiler routes `[*]` to it.
6. **v1 → v2 converter** — §7.
7. **NDI-matlab port** on a feature branch; iterate until parity.

Each step is shippable; nothing requires the next step to land first.

---

## 10. Open questions

- Final namespace choice: `+did2` (parallel) vs. rename `+did` → `+did_legacy`
  and reuse `+did` for v2. Parallel is friendlier during the transition,
  the rename is cleaner long-term.
- ALTER TABLE add-column for new queryable paths after the first DB open:
  acceptable for occasional schema bumps, painful for rapid development.
  Decide whether to rebuild the `documents` table on schema-cache mismatch or
  to ALTER incrementally.
- Whether to keep `+did/+implementations/sqldb.m` (Postgres) as a v2 target or
  drop it for now and reintroduce later. The query-compiler split (§6) makes
  re-adding it cheaper than today.
- Migration map completeness: the V_gamma `2.0.0` bumps listed in
  `V_gamma_notes.md` are mechanical, but real v1 databases may carry
  ad-hoc/user-defined classes that need bespoke migration. Probably a
  registration API for site-local migrations.

---

## 11. JSON1 availability — verified

Run `tools/check_json1_support.m` on the target MATLAB to re-verify on new
installs. As of 2026-05-11 on the maintainer's MATLAB:

```
SQLite version: 3.39.2
compile_options: ENABLE_JSON1=0  OMIT_JSON=0  (n=37 total)

[test 1] json_extract on a scalar path                  OK
[test 2] json_each over an array of objects             OK
[test 3] EXISTS over json_each + json_extract           OK
[test 4] generated column using json_extract            OK
```

Note: `ENABLE_JSON1=0` in `compile_options` is **not** a problem on
SQLite 3.38+. Since 3.38 JSON1 is built unconditionally and the flag is a
no-op, so it no longer appears in `compile_options`. The functional tests
(1–4) are the authoritative signal.

Test 4 passing is the decisive simplification: queryable scalar paths can
live as `STORED` generated columns on `documents` with their own indexes
(§3.2), with no separate sidecar table for scalars.

---

## 12. Progress log

### 2026-05-11 — step 1 scaffold

Started step 1 of §9 on branch `claude/start-v2-development-tA41P`.

Added:

- `src/did/+did2/document.m` — V_gamma document object. API surface
  in place (construct from JSON / struct / `(className, values)`,
  `get` / `set` / `iterate`, `toJSON` / `toStruct`, `className` /
  `classVersion`, `validate`, plus static `fromJSON` / `fromStruct` /
  `blank`). Dot-path get/set is implemented in full. The `[*]` array
  iterator is implemented via `iterate(arrayPath)`; the bare `get`
  rejects paths containing `[*]` to keep the scalar/array distinction
  honest. `validate` and `blank` delegate to the schema cache.
- `src/did/+did2/+schema/cache.m` — schema cache class. Singleton
  bootstrap, schema-path resolution (env override
  `DID_SCHEMA_PATH`, or sibling `did-schema/schemas/V_gamma` checkout),
  `getClass`, and `superclasses` traversal are implemented; the
  heavier methods (`fieldsFor`, `queryablePaths`,
  `buildBlankDocument`, `validateDocument`) currently throw
  `did2:notImplemented` and will be filled in next.
- `src/did/+did2/Contents.m` — package overview.
- `tests/+did2/testDocumentScaffold.m` — function-based unit tests
  covering construction, dot-path get/set, iterate, round-trip JSON,
  and the documented error IDs. Tests that depend on the schema cache
  beyond what is implemented are deferred.

Provisional decision (logged in §1 as #7): use `+did2` for the v2
namespace during the scaffold, leaving the §10 rename-vs-parallel
question open for resolution before v2 reaches `main`.

Next up: fill in `did2.schema.cache.fieldsFor`,
`queryablePaths`, and `buildBlankDocument`; then `validateDocument`
against the V_gamma meta-schema; then start the in-memory query
evaluator (step 2).

### 2026-05-12 — class-scoped property blocks, then drop underscores

Two upstream did-schema SPEC revisions landed back-to-back and both
required reworking the +did2 in-memory shape:

1. **Class-scoped property blocks restored** (did-schema commit
   `137f583`). V_gamma was amended to organise document instances
   into per-class property blocks keyed by class name (one per class
   in the chain), instead of the earlier flat namespace. Also moved
   `class_name`/`class_version`/`superclasses` under a top-level
   `document_class` header.
2. **Drop underscore prefixes** (did-schema commit `77c6363`). The
   `_<key>` convention for NDI-extension keys was replaced by plain
   keys (`maturity_level`, `depends_on`, `file`, `fields`,
   `mustBeNonEmpty`, `blank_value`, `ontology`, etc.). The
   authoritative reserved-name list moved to upstream
   `ndi_reserved_keys.json`.

Combined, every key in a V_gamma wire shape is now a plain MATLAB
identifier, so the in-memory MATLAB struct is the JSON shape verbatim
— no `x_<name>` aliasing, no `jsonencode`-time rewrite pass, no
`extractField` underscore-probe helper. Round-tripping a V_gamma
document is `jsondecode` then `jsonencode`.

Implemented in `src/did/+did2/+schema/cache.m`:

- `classChain(className)` — root-first list including the class itself
  (e.g., `demoB -> {base, demoA, demoB}`).
- `ownFields(className)` — the `fields` list the class declares
  directly (no inheritance), via direct `s.fields` access.
- `fieldsFor(className)` — merged inherited fields tagged with their
  declaring class. Returns a struct array
  `{declaringClass, fieldDef}`.
- `superclasses(className)` — walks
  `s.document_class.superclasses[i].class_name` up the chain.
- `buildBlankDocument(className)` — class-scoped V_gamma document:
    `doc.document_class.{class_name, class_version, superclasses}`
    `doc.depends_on` — empty struct array of `{name, value}`
    `doc.<class_name>` for each class in the chain
  Base block has `id` auto-minted via `did.ido.unique_id()` and
  `datestamp` set to current UTC ISO-8601.
- `validateDocument(docOrStruct)` — accepts a `did2.document` or its
  underlying struct, walks the class chain, and validates each
  class's `fields` against its property block. Error messages use
  the qualified `<class>.<name>` form; new error IDs
  `did2:validation:missingClassBlock` and `:badClassBlock`.
- `queryablePaths` stays a stub (belongs to steps 3 and 4).

In `src/did/+did2/document.m`:

- `className` / `classVersion` read
  `documentProperties.document_class.class_name` /
  `documentProperties.document_class.class_version`.
- `toJSON` is a bare `jsonencode` (no rewrite pass). The previous
  `rewriteXUnderscoreKeys` helper is removed.

Fixtures at `tests/+did2/fixtures/V_gamma/` (`base.json`,
`demoA.json`, `demoB.json`, `demoC.json`, `demoFile.json`,
`CURIE_lookups_meta.json`, `README.md`) rewritten to the
plain-key V_gamma shape.

`tests/+did2/testSchemaCache.m` updated: 22 tests assert on the
plain-key shape (`doc.document_class.class_name`, `doc.depends_on`,
etc.) and check that a V_gamma document round-trips through
`toJSON`/`fromJSON` unchanged.

Step 1 is complete to the level the rest of the plan needs.
`queryablePaths` is the only intentional stub left in the cache;
detailed per-named-composite validation and dependency-value checks
are deferred to focused follow-ups. Next up: step 2 — the in-memory
query evaluator over the class-qualified dot-paths.

### 2026-05-12 — step 2 in-memory query evaluator

Implemented step 2 of §9 on branch
`claude/did-v2-schema-stage2-nGrJx`.

Added `src/did/+did2/query.m` — a four-tuple
`{field, operation, param1, param2}` search-structure query value
that evaluates directly against the V_gamma class-scoped wire shape
(`did2.document` or its underlying struct). The implementation is the
executable spec described in
`did-schema/schemas/did_query_model.md`.

Operators implemented (every operator named in the model spec):

- Scalar: `exact_string`, `exact_string_anycase`, `contains_string`,
  `regexp`, `exact_number`, `lessthan`, `lessthaneq`, `greaterthan`,
  `greaterthaneq`, `hasfield`.
- Array: `hasmember`, `hasanysubfield_contains_string` (legacy
  shorthand for `<field>[*].<sub>` + `contains_string`),
  `hasanysubfield_exact_string` (correlated lowering used by
  `depends_on`).
- Document-level: `isa` (matches concrete class or any entry of
  `document_class.superclasses[*].class_name`), `depends_on` (with
  `*` wildcard on the name).
- Negation: `~`-prefix on every operator except `or`. `~or` is
  rejected at construction time with `did2:query:badOperator`.

Composition:

- `and(q1, q2)` concatenates search-structure arrays.
- `or(q1, q2)` builds a single search structure whose operation is
  `or` and whose `param1` / `param2` are the sub-search-structure
  arrays. `evaluateAll` AND-s its struct array (empty matches
  vacuously); the `or` branch shortcircuits on `param1`.

Field selector:

- Dot-paths resolve via `did2.query.resolvePath(s, fieldPath)`, which
  returns a cell array of leaf values.
- A path segment ending in `[*]` expands array-of-structure
  iteration with existential semantics. Multiple `[*]` segments
  compose as a cross-product of expansions.
- Unresolvable paths return `{}`. With a scalar operator that means
  no match; with `~`-negation the match flips to true (literal
  reading of the model spec).
- Per the model spec, two `[*]` predicates over the same array
  combined with `and()` are evaluated independently (not correlated
  to the same element).

API surface:

- `did2.query()` empty query — matches everything (vacuous AND).
- `did2.query(field, op, param1, param2)` four-tuple constructor;
  `param1` / `param2` default to `''`.
- `did2.query(searchstruct)` wraps an existing struct.
- `did2.query.all()` and `did2.query.none()` syntactic sugar built on
  `isa`.
- `q.matches(docOrStruct)` returns logical scalar.
- `q.filter(docs)` returns the matching subset of a list of
  documents; `q.filter(docs, AsMask=true)` returns a logical mask.
- `did2.query.resolvePath(s, fieldPath)` and
  `did2.query.evaluate(ss, docStruct)` are exposed for the SQL
  compiler's test harness (§6.2).

Added `tests/+did2/+unittest/testQuery.m` — function-based tests
covering every operator above, the negation prefix, AND/OR
composition, `[*]` iteration (single and nested), the independent
quantifier semantics, the filter/asMask path, and the
plain-struct vs `did2.document` input branches.

Next up: step 3 — the SQLite backend with the JSON1 fallback path.
The in-memory evaluator becomes the reference implementation the
SQL compiler is tested against.
