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
| 8 | Document instances use class-scoped property blocks (one block per class in the chain, keyed by `_classname` verbatim). | See §4.1. Matches V_gamma_SPEC.md "JSON Format: Document Instances" after the SPEC update that restored V_alpha-style class scoping. MATLAB struct field names can't begin with `_`, so the four top-level system keys are stored as `x_*` internally and rewritten to `_*` on serialise. |

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
`_queryable: true` path declared by the V_gamma schemas, we add a stored
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
Instances"*. V_gamma documents use **class-scoped property blocks**: there
is one top-level block per class in the inheritance chain, keyed by that
class's `_classname` verbatim. Fields live in the block of the class that
declared them. There is no `property_list_name` knob — the block key
*is* the class name.

The MATLAB representation has one quirk: struct field names cannot begin
with `_`. The four underscore-prefixed top-level system keys (`_classname`,
`_class_version`, `_superclasses`, `_depends_on`) are stored as
`x_classname`, `x_class_version`, `x_superclasses`, `x_depends_on` —
mirroring exactly what `jsondecode` produces. Class-block keys (`base`,
`daqsystem`, ...) are valid MATLAB identifiers (V_gamma classnames match
`^[a-z][a-z0-9_]*$`) and stay verbatim. `did2.document.toJSON` rewrites
`"x_<name>":` keys back to `"_<name>":` on the encoded output so the wire
form matches the spec; `fromJSON` relies on `jsondecode`'s default rename
on parse.

Top-level keys populated by `did2.schema.cache.buildBlankDocument`:

| Key (JSON / MATLAB) | Type | Source |
|---|---|---|
| `_classname` / `x_classname` | char | concrete class's `_classname` |
| `_class_version` / `x_class_version` | char | concrete class's `_class_version` |
| `_superclasses` / `x_superclasses` | struct array | one elem per ancestor; each has `_classname` (`x_classname`) and `_class_version` (`x_class_version`) |
| `_depends_on` / `x_depends_on` | struct array | each entry has `_name` (`x_name`) and `value`; empty by default |
| `base` / `base` | struct | property block with the four base fields (`id`, `session_id`, `name`, `datestamp`); `id` auto-minted via `did.ido.unique_id`, `datestamp` set to current UTC ISO-8601 |
| `<class>` / `<class>` | struct | one property block per class in the chain, including the concrete class itself; each populated with `_blank_value` for the fields *that class* declares (empty `{}` if it declares none) |

Field identity is `(declaring_class, _name)`. Same-named fields in
different classes of the chain are distinct paths (`base.id` vs.
`<subclass>.id`), not an override. The SPEC's "no shadowing, by
construction" rule means validators and query engines work in
class-qualified paths.

V_alpha → V_gamma at the document level:

```
V_alpha                                  V_gamma
-------                                  -------
document_class.class_name                _classname
document_class.class_version             _class_version
document_class.superclasses              _superclasses
document_class.property_list_name        (gone; block key == _classname)
document_class.definition                (gone; schema files own this)
document_class.validation                (gone; schema files own this)
base.id, base.session_id, ...            base.id, base.session_id, ...
<property_list_name>.<field>             <_classname>.<field>
depends_on (top-level list)              _depends_on (renamed only)
```

The converter (§7) inverts the mapping when reading V_alpha documents:
strip `document_class`, write the four V_gamma top-level keys, and
rename each property block whose `property_list_name` differs from its
`class_name` so the block key equals the class name.

---

## 5. Schema cache

A `+did2/+schema/cache.m` (or similar) loads all V_gamma schema files once,
resolves superclass chains, and pre-computes:

- For each classname: the full inherited field list.
- The subset of fields with `_queryable: true`, split into scalar paths and
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
   `ontology_image`, `ontology_label`), and reshapes `_ontology` annotations
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

### 2026-05-12 — close step 1: class-scoped cache implementations + fixtures

V_gamma_SPEC.md was amended (upstream did-schema commit `137f583`) to
restore class-scoped property blocks on document instances, replacing
the earlier "flatten on inheritance" wire shape. Decision #8 above is
revised accordingly, and §4.1 documents the resulting in-memory layout
(class-block top-level keys plus the four `_<system>` keys stored as
`x_<system>`).

Filled in the schema cache to the level step 1 needs and wired
end-to-end tests through `did2.document.blank` / `did2.document.validate`.

Implemented in `src/did/+did2/+schema/cache.m`:

- `classChain(className)` — root-first list including the class itself
  (e.g., `demoB -> {base, demoA, demoB}`).
- `ownFields(className)` — the `_fields` list the class declares
  directly (no inheritance).
- `fieldsFor(className)` — merged inherited fields tagged with their
  declaring class. Returns a struct array `(declaringClass, fieldDef)`
  so callers know which property block each field belongs to.
- `buildBlankDocument(className)` — class-scoped V_gamma document:
  top-level `x_classname` / `x_class_version` / `x_superclasses`
  (struct array of `{x_classname, x_class_version}` ancestor entries
  parent-first) / empty `x_depends_on`, plus one property block per
  class in the chain. Base block has `id` auto-minted via
  `did.ido.unique_id()` and `datestamp` set to current UTC
  millisecond ISO-8601 with trailing `Z`. Empty blocks present for
  classes that declare no fields, per the SPEC.
- `validateDocument(docOrStruct)` — accepts a `did2.document` or its
  underlying struct, walks the class chain, and for each class
  validates the fields *that class declares* against its property
  block. Error messages use the qualified `<class>.<name>` form.
  Type-shape runs before `_mustBe*` checks so a wrong-type value is
  reported as `did2:validation:typeMismatch` rather than
  `did2:validation:notScalar`. New error IDs added:
  `did2:validation:missingClassBlock`, `did2:validation:badClassBlock`.
- `queryablePaths` stays a stub — it belongs to steps 3 and 4 and
  will return class-qualified dot-paths (e.g.,
  `daqsystem.sample_rate.hertz`) once the storage layer lands.

In `src/did/+did2/document.m`:

- `className` / `classVersion` read from `x_classname` / `x_class_version`.
- `toJSON` post-processes the `jsonencode` output with a regex that
  rewrites `"x_<name>":` keys back to `"_<name>":`. This is the only
  place we serialise V_gamma JSON; `fromJSON` relies on
  `jsondecode`'s default behaviour to read it back in.

Added `tests/+did2/fixtures/V_gamma/`:

| File | Origin | Why |
|---|---|---|
| `base.json` | upstream `did-schema` V_gamma | The root class. |
| `CURIE_lookups_meta.json` | upstream | Exercises registry load. |
| `demoA.json` | V_gamma translation of v1 `demoA.json` | `base` subclass with one queryable char field. |
| `demoB.json` | V_gamma translation of v1 `demoB.json` | Multi-level (`demoB → demoA → base`). |
| `demoC.json` | V_gamma translation of v1 `demoC.json` | Declares three `_depends_on` entries. |
| `demoFile.json` | V_gamma translation of v1 `demoFile.json` | Declares `_file` attachments. |
| `README.md` | new | Documents origins and refresh procedure. |

New `tests/+did2/testSchemaCache.m` (function-based) points the cache
at the fixture via `setSchemaPath` in `setupOnce`, then covers: schema-path
plumbing, `getClass` (incl. missing-class error), CURIE registry presence,
superclass-chain depth, `classChain`, `ownFields`, `fieldsFor` declaring-class
tagging, `buildBlankDocument` (top-level metadata, all chain blocks present
as expected, minted id, current UTC datestamp), `validateDocument`
(empty-field, max-length boundary, type mismatch, missing class_name,
missing class block), and an end-to-end `toJSON` round-trip that asserts
the serialised form uses `_classname` and not `x_classname`.

Step 1 is now complete to the level the rest of the plan needs.
`queryablePaths` is the only intentional stub left in the cache;
detailed per-named-composite validation and `_depends_on` value
checks are deferred to a focused follow-up. Next up: step 2 — the
in-memory query evaluator over the class-scoped paths, which will
also be the executable spec the SQL compiler is later tested against.
