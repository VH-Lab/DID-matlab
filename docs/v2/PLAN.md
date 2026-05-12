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
| 9 | When the queryable-paths set declared by the schemas changes between sessions, **rebuild** the `documents` table via table-swap rather than ALTER TABLE incrementally. | V_gamma is still evolving and ALTER's main downside (orphan / dead columns accumulating over schema bumps) hits exactly when it's least tolerable. Rebuild keeps the schema canonical and pays a one-time O(n) IO cost we can afford while DBs are small. Closes §10 question 2. |

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
- ~~ALTER TABLE add-column for new queryable paths after the first DB open~~
  Resolved in Decision 9: rebuild the `documents` table by table-swap on
  schema-cache mismatch. Revisit if DBs grow large enough that rebuild IO
  becomes a problem.
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

### 2026-05-12 — step 3 SQLite + JSON1 fallback backend

Implemented step 3 of §9 on branch
`claude/did-matlab-v2-step3-JxBfW`.

Added the `+did2/+database` subpackage with two pieces:

- **`src/did/+did2/+database/sqlitedb.m`** — first v2 storage
  backend. Opens or creates a sqlite3 file via `mksqlite` and
  installs the body + sidecar schema from §3.1:
    `documents(id, classname, class_version, session_id, datestamp,
               body, body_hash)` — full V_gamma JSON in `body`.
    `superclasses(doc_id, classname)` — indexed by classname; one
    row per class in the chain *including* the concrete class
    itself, so `isa` is a single indexed lookup.
    `depends_on(doc_id, name, value)` — indexed by `(name, value)`.
    `meta(key, value)` — schema generation + version markers; the
    constructor uses these to reject files that aren't V_gamma
    databases (`did2:database:notV2Database`).
  Foreign-key cascades drop the sidecar rows when a document is
  removed. The class is `handle`-typed and tracks the mksqlite dbid
  itself; `delete`/`close` are idempotent.

  API (deliberately small for step 3):
    `add(doc | {doc1,...}, Validate=true)`
    `remove(id | document)`
    `get(id)` returns a `did2.document`
    `has(id)` / `count()` / `allIds()`
    `search(q)` / `searchIds(q)`
  `Validate=false` skips `cache.validateDocument` for bulk loads
  (the `unsafe_insert` escape hatch noted in §1).

- **`src/did/+did2/+database/compileQuery.m`** — translates a
  `did2.query` to a SQL `WHERE` clause plus a parameter cell array.
  Implements the JSON1 fallback path described in §3.4 and §6.1:
    Scalar leaves -> `json_extract(body, '$.<path>')` against `?`,
    with negation guarded by `IS NULL OR NOT (...)` so unresolvable
    paths flip to true under `~`.
    Array-iteration `[*]` paths -> `EXISTS (FROM json_each(...) je1
    [, json_each(...) jeK ...] WHERE <leaf-predicate>)`. Multiple
    `[*]` segments compose as a cross-product of `json_each` joins.
    `isa` -> `EXISTS (FROM superclasses WHERE doc_id = ? AND
    classname = ?)` against the sidecar table.
    `depends_on` -> `EXISTS (FROM depends_on WHERE ... )`; the `*`
    wildcard on `name` drops the name predicate.
    `hasfield` -> `json_type(body, '$.<path>') IS NOT NULL`, so a
    JSON `null` still counts as "present" (matches in-memory
    semantics that `hasfield` is presence, not truthiness).
    `hasmember`, `hasanysubfield_contains_string`,
    `hasanysubfield_exact_string` — all desugar onto the same
    `json_each` machinery; the contains-string sugar is rewritten
    to a `[*]`-path + `contains_string`.
    `and()` -> `( ... ) AND ( ... )`; `or()` -> `( ... ) OR ( ... )`.

  Two operators are compiled to a permissive `1=1` pre-filter
  because sqlite3 cannot natively express them: `regexp` (the
  `REGEXP` UDF is not registered by mksqlite) and `exact_number`
  against multi-element targets. `did2.database.sqlitedb.search`
  always runs `did2.query.matches` over the SQL result set as a
  correctness backstop, so the SQL pre-filter is only ever an
  over-approximation. This is exactly the "slow but complete"
  contract called for in §9 step 3.

- **`tests/+did2/+unittest/testCompileQuery.m`** — string-based
  smoke tests over the compiler output (no mksqlite required).
  Covers every operator, the negation guard for missing paths,
  single and nested `[*]` expansions, sidecar lookups for `isa`
  and `depends_on`, and AND/OR composition.

- **`tests/+did2/+unittest/testSqliteDb.m`** — integration tests
  that round-trip V_gamma documents through a real SQLite file
  and verify that the compiled queries plus the post-filter return
  the same hits as the in-memory evaluator. Covers add / get /
  remove, allIds ordering, reopen, foreign-file rejection,
  `Validate=false`, every body operator, sidecar-table lookups
  for `isa` / `depends_on`, AND/OR composition, and the `regexp`
  post-filter path. The whole file filters itself out when
  `mksqlite` is not on the MATLAB path (via `assumeFail`), so
  CI runs without the MEX still pass.

Updated `src/did/+did2/Contents.m` to document the new
`+database` subpackage and to reflect the class-scoped V_gamma
shape in the conventions block.

Step 4 (schema-driven scalar generated columns + indexes, per
§3.2) and step 5 (the `queryable_array_elem` sidecar, per §3.3)
both layer cleanly on top of what landed here: the JSON1
fallback compile path remains the correctness baseline; step 4
just adds routing to the generated columns when the path is in
the schema's queryable set, and step 5 adds routing to the
sidecar for `[*]` paths. No data-shape changes to `documents`,
`superclasses`, or `depends_on` are required.

### 2026-05-12 — step 4 indexed scalar paths + rebuild-on-mismatch

Implemented step 4 of §9 on branch
`claude/did-matlab-v2-step4-Pn8Rk`.

`did2.schema.cache` gained the two methods step 4 needs:

- `loadAllSchemas()` — parse every `*.json` in the schema directory
  into the cache (skipping `*_meta.json` / `ndi_reserved_keys.json`).
  Run once at sqlitedb-open so `queryablePaths()` returns a
  deterministic set independent of which classes have happened to be
  touched in this MATLAB session.
- `queryablePaths()` — walks the loaded classes and returns
    `.scalar` — struct array; one entry per scalar `queryable: true`
                field (`path`, `declaringClass`, `fieldName`, `type`,
                `column`, `affinity`).  `column` is the canonical
                `q_<dot-path-with-underscores>` name; `affinity` is the
                SQLite type affinity (TEXT for char/did_uid/timestamp,
                INTEGER for boolean/integer, REAL for double/matrix).
    `.array`  — cellstr of `[*]`-bearing dot-paths from array-of-
                structure queryable fields. Populated for step 5;
                step 4 only consumes `.scalar`.

`did2.database.sqlitedb` now installs one STORED generated column on
the `documents` table per scalar queryable path, plus a covering index
(§3.2):

    q_base_name TEXT GENERATED ALWAYS AS (json_extract(body, '$.base.name')) STORED
    CREATE INDEX documents_q_base_name ON documents(q_base_name)

…and so on for every entry in `.scalar`. At open time, the
constructor:

1. Resolves the schema cache, loads all schemas, snapshots the
   queryable-paths set onto the instance. Failures (no schema dir,
   broken cache) degrade gracefully to pure JSON1 fallback.
2. For a new DB, calls `createSchema()` which emits the table with
   the q_* columns from the start.
3. For an existing DB, calls `assertSchema()` + the new
   `reconcileQueryableColumns()`. If the installed q_* column set
   doesn't match what the cache now declares, the table is rebuilt
   by table-swap (Decision 9, §3.2 +PLAN.md §10 question 2 resolved):
   create `documents_new` with the current generated columns, copy
   the canonical columns over (the generated columns auto-populate
   from `body`), drop the old table, rename, recreate the indexes.
   Foreign keys on `superclasses`/`depends_on` are temporarily
   disabled around the swap per the recommended SQLite pattern
   (sqlite.org/lang_altertable.html §7).

`did2.database.compileQuery` gained a `'QueryablePaths', PATHS`
name-value pair. With a non-empty PATHS, scalar leaves whose dot-path
is in the set compile to `<column> OP ?` directly against the
generated column instead of `json_extract(body, '$.<path>')`,
letting SQLite use the column's index. NULL-guarded negation,
`json_each` array iteration, and `json_type` `hasfield` are
unchanged. Paths not in the set still take the JSON1 fallback.
`did2.database.sqlitedb.search` threads the snapshotted path set
into the compiler.

Two Hidden test hooks on `sqlitedb` (`testHookDbId`,
`testHookQueryableColumns`) let the unit tests assert on the raw
generated-column state without round-tripping through public methods.

- `tests/+did2/+unittest/testSchemaCache.m` — five new tests cover
  the queryable-path discovery, column-name convention, TEXT
  affinity on the fixture's all-string scalars, the empty array
  bucket, and the idempotence of `loadAllSchemas`.
- `tests/+did2/+unittest/testCompileQuery.m` — five new tests cover
  the generated-column routing (positive and fallback), the
  NULL-guarded negation against the column, the carve-out for
  `hasfield` (which must keep using `json_type`), and the fact that
  `[*]`-bearing paths ignore the scalar queryable set.
- `tests/+did2/+unittest/testSqliteDb.m` — three integration tests
  cover the generated columns appearing at create-time, the
  indexed-scalar search matching the fallback, and the
  rebuild-on-mismatch flow (which `assumeFail`s on SQLite versions
  that don't support `ALTER TABLE ... DROP COLUMN`, i.e. <3.35).

Updated Decision 9 in §1 and struck §10 question 2 (resolved).
Composite-type sub-path expansion (`sample_rate.hertz`, etc.) is
the next obvious extension to `queryablePaths` — none of the demo
fixtures exercise it yet, so it landed as a follow-up for whenever
a real V_gamma schema with a `duration`/`frequency`/`ontology_term`
field gets queried.

Next up: step 5 — the `queryable_array_elem` sidecar table for
`[*]` paths.

### 2026-05-12 — step 5 queryable_array_elem sidecar

Implemented step 5 of §9 on branch
`claude/add-array-fixtures-v2-CbcV2`.

The previous agent's hand-off flagged that the demo fixtures had no
array-of-structure queryable fields, so the integration tests
couldn't exercise the sidecar end-to-end. Step 5 starts with a
fixture extension and then layers the schema-cache / database /
query-compiler changes on top.

- `tests/+did2/fixtures/V_gamma/demoArray.json` — new class
  extending base with a single field `axes` (type `structure`,
  `mustBeScalar: false`, `queryable: true`) whose element template
  declares three sub-fields: `name` (char, non-queryable label),
  `unit` (char, queryable TEXT-affinity), and `size` (integer,
  queryable INTEGER-affinity). The class exercises both
  `value_text` and `value_num` sidecar columns from a single
  fixture.

- `src/did/+did2/+schema/cache.m` — `queryablePaths().array` now
  returns a struct array with the leaf metadata the database
  backend needs to populate and the compiler needs to route:
    `path`           — full `[*]`-bearing dot-path
                       (e.g., `demoArray.axes[*].unit`).
    `declaringClass` — class that declares the parent array field.
    `parentField`    — array-of-structure field name (`axes`).
    `parentPath`     — class-qualified parent path (`demoArray.axes`).
    `subField`       — queryable sub-field name (`unit`).
    `type`           — schema type of the sub-field.
    `affinity`       — SQLite type affinity (`TEXT` / `REAL` /
                       `INTEGER`) used to pick the sidecar's
                       `value_text` vs. `value_num` column.
  The discovery walk now expects an array-of-structure field to be
  `mustBeScalar: false`, `type: structure`, `queryable: true`, and
  to declare its element template under `fields`. Sub-fields are
  emitted only when they are themselves queryable scalars.

- `src/did/+did2/+database/sqlitedb.m` — `createSchema` installs the
  `queryable_array_elem(doc_id, path, elem_index, value_text,
  value_num)` table from §3.3 with foreign-key cascades and the
  `qae_path_text` / `qae_path_num` / `qae_doc_id` indexes.
  `addOne` populates the sidecar in the same transaction as the
  `documents` / `superclasses` / `depends_on` inserts, picking the
  right value column per path's affinity and skipping empty leaves.
  Bootstrap caches the array-path definitions alongside the
  scalar columns and threads both into `compileQuery`.
  Reconciliation:
    - The configured array-paths set is recorded in the `meta`
      table under `queryable_array_paths`, newline-delimited (a
      sentinel `<none>` covers the empty-set case so the column's
      `NOT NULL` constraint doesn't depend on mksqlite binding
      `''` literally).
    - At open, `reconcileQueryableArrayPaths` compares the stored
      set to the current one. On a mismatch it wipes the sidecar
      and re-populates by replaying every stored document body
      through the new path set, then refreshes the meta row.
    - `ensureSidecarTable` lazily installs the table when the
      database predates step 5.
    - The reconcile path degrades gracefully (no-op) when the
      bootstrap couldn't resolve the schema cache, so a host
      that temporarily lacks the schema directory doesn't strip
      a healthy sidecar.

- `src/did/+did2/+database/compileQuery.m` — new
  `'QueryableArrayPaths'` name-value option, accepting either the
  schema-cache struct array (so the affinity travels through) or a
  cellstr of bare paths (defaults to TEXT affinity). When a
  scalar `[*]`-leaf's dot-path is in the indexed set, the compiler
  emits `EXISTS (SELECT 1 FROM queryable_array_elem qae WHERE
  qae.doc_id = documents.id AND qae.path = ? AND <leaf-predicate>)`
  against the affinity-appropriate `qae.value_*` column.
  Negation flips to `NOT EXISTS (...)`, which also matches docs
  with no rows at that path (preserving the in-memory rule that
  an unresolvable path under `~op` matches). Paths not in the set
  still take the `json_each` fallback, so ad-hoc exploration over
  unindexed array shapes keeps working. `hasmember`,
  `hasanysubfield_contains_string`, and
  `hasanysubfield_exact_string` continue to use `json_each`:
  the sidecar stores one row per (element, queryable sub-field)
  and can't natively serve correlated multi-sub-field predicates.

- `tests/+did2/+unittest/testSchemaCache.m` — three new tests
  cover the `.array` struct-array shape, the per-entry leaf
  metadata (`parentPath`, `subField`, `type`, `affinity`), and
  the count match against the fixtures.
- `tests/+did2/+unittest/testCompileQuery.m` — five new tests
  cover the sidecar EXISTS expansion, the json_each fallback for
  unindexed paths, the negation flip to `NOT EXISTS`, the
  numeric-affinity routing to `qae.value_num`, and the
  regexp pre-filter remaining a permissive `1=1` even when the
  surrounding subquery narrows to `qae.path = ?`.
- `tests/+did2/+unittest/testSqliteDb.m` — six integration tests
  cover sidecar population at insert (TEXT and numeric paths),
  indexed-`[*]` search routing matching the in-memory evaluator,
  numeric comparison via `value_num`, `ON DELETE CASCADE`
  cleanup, the `meta` row tracking the configured path set, and
  the reconcile-on-mismatch flow rebuilding the sidecar from
  stored bodies.

`did2.database.sqlitedb` grew a `testHookQueryableArrayPaths`
helper alongside the existing scalar-column hook, so the unit
tests can introspect the configured set without round-tripping
through public methods.

Step 5 leaves the in-memory evaluator and the JSON1 fallback
both untouched, so the SQL compiler's sidecar path is a routing
optimisation only: every test that exercises the compiler also
post-filters through `did2.query.matches`, and any divergence
between the sidecar pre-filter and the reference evaluator would
surface as a search-result mismatch immediately.

Next up: step 6 — the v1 → v2 converter (PLAN.md §7).
