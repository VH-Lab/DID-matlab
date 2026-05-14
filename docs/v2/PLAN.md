# DID-matlab v2 Plan — V_delta support

**Status:** living document. Edit freely as decisions are made or revised.

**Scope:** transform DID-matlab so it consumes `did-schema` V_delta (and later
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
| 8 | Document instances use a top-level `document_class` header plus class-scoped property blocks (one block per class in the chain, keyed by `class_name` verbatim). | See §4.1. Matches V_delta_SPEC.md "JSON Format: Document Instances" after the SPEC's two-step revision: (i) restore class-scoped blocks; (ii) drop the underscore prefix on all NDI-extension keys. Every key in the wire shape is a plain MATLAB identifier, so the in-memory MATLAB struct is the JSON shape verbatim. |
| 9 | When the queryable-paths set declared by the schemas changes between sessions, **rebuild** the `documents` table via table-swap rather than ALTER TABLE incrementally. | V_delta is still evolving and ALTER's main downside (orphan / dead columns accumulating over schema bumps) hits exactly when it's least tolerable. Rebuild keeps the schema canonical and pays a one-time O(n) IO cost we can afford while DBs are small. Closes §10 question 2. |

Open questions are in §10.

---

## 2. Why a clean break (and not a coexistence shim)

The V_delta document shape is structurally different from the current MATLAB
`document_properties` layout in three ways that compound:

- Top-level keys are snake_case (`id`, `class_version`, `depends_on`) instead of
  the V_alpha `base.*` / `document_class.*` / `<property_list_name>` nesting.
- Several classes bumped to `_class_version: 2.0.0` and collapsed multiple
  coordinated fields into a single named composite (e.g. `probe_location` lost
  `ontology_name`+`name`, gained `location` as an `ontology_term`).
- V_delta adds named composite types (`ontology_term`, plus SI-dimensioned
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
    body          TEXT NOT NULL,                  -- full V_delta JSON
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
`queryable: true` path declared by the V_delta schemas, we add a stored
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

- Holds the V_delta JSON shape directly. No translation to/from `base.*`
  nesting.
- Loads, serialises, and validates against `did-schema` V_delta schema files
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
V_delta JSON shape *as specified in V_delta_SPEC.md, "JSON Format: Document
Instances"*, exactly. After V_delta's "drop underscore prefixes" pass,
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

V_alpha → V_delta at the document level:

```
V_alpha                                  V_delta
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

A `+did2/+schema/cache.m` (or similar) loads all V_delta schema files once,
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
   to the V_delta two-key form.
4. Validates against V_delta. Successful docs insert into the new DB; failures
   land in a `quarantine` table with the original body and a reason string.
   Nothing is silently dropped.

The converter ships in v2, not v1, so v1 users aren't forced to upgrade their
existing read-only workflows.

### 7.1 Per-class conversion specs live in `did-schema`

As of the V_delta cutover, the human-readable specification of *what each
per-classname migration does* lives in `did-schema` at
`schemas/V_delta/conversions/from_did_v1/<class_name>.md`. One markdown
per class, following the template at `_TEMPLATE.md` in that directory.

The 13 NDIcalc-vis-matlab types (`contrast_tuning`, `contrast_tuning_calc`,
`hartley_calc`, `reverse_correlation`, etc.) have full conversion
markdowns. The 88 V_gamma-inherited types currently do not; the rules for
them live only in this PLAN's §7 prose and in head-knowledge. **Writing
conversion markdowns for the four `2.0.0`-bumped classes** (`probe_location`,
`treatment`, `ontology_image`, `ontology_label`) is a prerequisite to
completing the converter, and should land as a separate did-schema PR
before the corresponding MATLAB migration functions are written.

The markdowns are documentation, not code. MATLAB migration functions
implement the rules; CI verifies the implementations against the
markdowns by hand-checked correspondence (not by parsing the markdown).
Schema-driven migration (parsing the markdown to drive the engine) is a
future direction once the corpus stabilises.

### 7.2 Quarantine, not silent drop

Documents that fail to migrate land in a `quarantine` table on the v2
database with three columns: `original_body` (TEXT, the v1 JSON
verbatim), `reason` (TEXT, the error message), and `failed_at`
(timestamp). The CLI prints a summary at end of run and exits with
non-zero status if any quarantine rows were created, so CI catches
regressions.

### 7.3 Migrator API and registration

Migration functions live under `+did2/+convert/+migrators/`, named
`<v1_class_name>.m`. Each implements:

```matlab
function v2_body = migrate(v1_body)
```

The dispatcher (`v1_to_v2.m`) reads each v1 document's class_name and
calls the matching `migrators.(class_name)`. Unknown classes default to
an **identity migrator** that performs only the universal renames
(`base.id` → `id`, ontology reshape, etc.) and emits a warning. Sites
with ad-hoc classes register their own migrators by adding a file in
the same directory.

### 7.4 What still uses head-knowledge

These conversions are documented only in conversation history / commit
messages today:

- The four `2.0.0`-bumped classes (`probe_location`, `treatment`,
  `ontology_image`, `ontology_label`). Their pre/post field-by-field
  shape exists in PRs against did-schema but not as conversion
  markdowns.
- Universal renames: top-level `base.id` → `id` etc. Should be
  documented in the `conversions/from_did_v1/_files.md` meta-doc
  (currently a TODO skeleton).
- The ontology annotation reshape (V_alpha 4-key → V_delta `{node,
  name}`).

Writing these down in did-schema is part of step 6.

---

## 8. Backwards compatibility / coexistence

- `release/v1.x` branch holds the V_alpha-compatible line. Critical bug fixes
  only.
- v2 development lives on `v2` (this branch). Downstream packages
  (NDI-matlab, vhlab_vhtools) pin to a v1 tag until they port.
- Once NDI-matlab v2 stabilises, v2 becomes default (`main`) and v1 retires.

---

## 9. Order of work

1. **`+did2/document.m`** — V_delta document object with load/validate/
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
6. **v1 → v2 converter + CI test data pipeline** — §7 plus end-to-end
   validation against real NDI datasets. See §9.6 for sub-steps.
7. **NDI-matlab port** on a feature branch; iterate until parity.

Each step is shippable; nothing requires the next step to land first.

### 9.6 Step 6 sub-steps

Step 6 is bigger than the previous steps because it combines the
migration engine with the end-to-end CI test that validates it. Break
into the following sub-PRs:

#### 6a. Converter skeleton + identity path

- `+did2/+convert/v1_to_v2.m` with the dispatcher, quarantine table,
  CLI entry point, and a summary-at-end-of-run report.
- `+did2/+convert/+migrators/_identity.m` — the universal-rename
  migrator (top-level key rename, ontology reshape) that all unknown
  classes fall back to.
- Unit tests against synthetic v1 documents (no real datasets yet).

#### 6b. Per-class conversion markdowns for the four `2.0.0`-bumped classes

This is a did-schema PR, not did-matlab:

- `schemas/V_delta/conversions/from_did_v1/probe_location.md`
- `schemas/V_delta/conversions/from_did_v1/treatment.md`
- `schemas/V_delta/conversions/from_did_v1/ontology_image.md`
- `schemas/V_delta/conversions/from_did_v1/ontology_label.md`
- Updates `_files.md` and `_index.md` to record the rules and status.

Should land before 6c so the implementations have a written spec to
review against.

#### 6c. Migrator implementations for the bumped classes

One MATLAB file per class under `+did2/+convert/+migrators/`,
implementing the rules in the 6b markdowns. Unit tests built from the
"worked example" sections of each markdown.

#### 6d. CI test data pipeline

The original step-6 motivating problem: get real NDI datasets running
through the converter on every PR.

- Pick a hosting location for the small (~16 MB) and large (~192 MB)
  datasets. Options: GitHub Release asset on `vh-lab/did-matlab`,
  Zenodo (citable DOI), or a project-owned S3 bucket. Datasets must
  be downloadable without authentication.
- Add a `tests/+did2/+integration/` directory for tests that download
  and exercise real data. These run under a separate test profile
  from the existing hermetic unit tests.
- Add a CI workflow `did-matlab.yml` (or extend an existing one) with
  two jobs:
  - **`integration-small`** — runs on every PR. Downloads the 16 MB
    dataset, runs the converter end-to-end, asserts zero quarantine
    rows, runs a small set of golden queries against the v2 result.
    Cache the dataset by URL+hash.
  - **`integration-nightly`** — scheduled or `nightly`-label-gated.
    Runs the 192 MB dataset with the same assertions plus larger-scale
    performance probes.
- Both jobs gate on `mksqlite` availability (the docker image or
  GitHub Actions runner must have it; document the requirement).

#### 6e. NDIcalc-vis-matlab migrators

The 13 NDIcalc-vis types added to V_delta on did-schema PR #26 already
have conversion markdowns. Implementing their migrators is independent
from 6a-6d (they don't appear in most v1 datasets) but should be done
in lockstep with NDI-matlab adopting V_delta-format calculator outputs.

This is a follow-up after 6d ships, gated on whether the test datasets
include calculator outputs (most don't).

### 9.7 Cross-cutting work that's not in any single step

These touch multiple steps; track separately:

- **V_delta switch in steps 1-5 code** — completed. Schema cache now
  points at `did-schema/schemas/V_delta/stable/`; sqlitedb tags
  databases with `schema_generation: V_delta`; test fixtures renamed.
  See progress log entry "V_delta switch".
- **`index.json` resolution** — currently the schema cache resolves
  by reading sibling JSON files from `schemaPath`. Once `did-schema`
  has tier folders (`stable/draft/deprecated`) the cache should
  optionally consult `schemas/V_delta/index.json` to find draft and
  deprecated classes too. For now the cache only sees `stable/`,
  which is sufficient because every V_delta class lives there.
- **Microschemas implementation** — design lives in
  `did-schema/schemas/V_delta/microschemas/_DESIGN.md`. Implementation
  is downstream of the schema-side meta-schema additions. DID-matlab
  needs to read the discriminator field, look up the microschema, and
  validate the body field — adds one new code path in
  `+did2/+schema/cache.m`'s `validateDocument`. Defer until the
  schema-side mechanism lands.
- **`abstract_fields` enforcement** — design discussed in PR #26
  conversation. The validator gains a rule: any concrete class whose
  superclass chain includes a class with `abstract_fields: [...]`
  must declare every named field in its own `fields`. Small change to
  `validateDocument`; defer until any V_delta class actually declares
  `abstract_fields`.

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
- Migration map completeness: the V_delta `2.0.0` bumps listed in
  `V_delta_notes.md` are mechanical, but real v1 databases may carry
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

- `src/did/+did2/document.m` — V_delta document object. API surface
  in place (construct from JSON / struct / `(className, values)`,
  `get` / `set` / `iterate`, `toJSON` / `toStruct`, `className` /
  `classVersion`, `validate`, plus static `fromJSON` / `fromStruct` /
  `blank`). Dot-path get/set is implemented in full. The `[*]` array
  iterator is implemented via `iterate(arrayPath)`; the bare `get`
  rejects paths containing `[*]` to keep the scalar/array distinction
  honest. `validate` and `blank` delegate to the schema cache.
- `src/did/+did2/+schema/cache.m` — schema cache class. Singleton
  bootstrap, schema-path resolution (env override
  `DID_SCHEMA_PATH`, or sibling `did-schema/schemas/V_delta` checkout),
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
against the V_delta meta-schema; then start the in-memory query
evaluator (step 2).

### 2026-05-12 — class-scoped property blocks, then drop underscores

Two upstream did-schema SPEC revisions landed back-to-back and both
required reworking the +did2 in-memory shape:

1. **Class-scoped property blocks restored** (did-schema commit
   `137f583`). V_delta was amended to organise document instances
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

Combined, every key in a V_delta wire shape is now a plain MATLAB
identifier, so the in-memory MATLAB struct is the JSON shape verbatim
— no `x_<name>` aliasing, no `jsonencode`-time rewrite pass, no
`extractField` underscore-probe helper. Round-tripping a V_delta
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
- `buildBlankDocument(className)` — class-scoped V_delta document:
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

Fixtures at `tests/+did2/fixtures/V_delta/` (`base.json`,
`demoA.json`, `demoB.json`, `demoC.json`, `demoFile.json`,
`CURIE_lookups_meta.json`, `README.md`) rewritten to the
plain-key V_delta shape.

`tests/+did2/testSchemaCache.m` updated: 22 tests assert on the
plain-key shape (`doc.document_class.class_name`, `doc.depends_on`,
etc.) and check that a V_delta document round-trips through
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
that evaluates directly against the V_delta class-scoped wire shape
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
               body, body_hash)` — full V_delta JSON in `body`.
    `superclasses(doc_id, classname)` — indexed by classname; one
    row per class in the chain *including* the concrete class
    itself, so `isa` is a single indexed lookup.
    `depends_on(doc_id, name, value)` — indexed by `(name, value)`.
    `meta(key, value)` — schema generation + version markers; the
    constructor uses these to reject files that aren't V_delta
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
  that round-trip V_delta documents through a real SQLite file
  and verify that the compiled queries plus the post-filter return
  the same hits as the in-memory evaluator. Covers add / get /
  remove, allIds ordering, reopen, foreign-file rejection,
  `Validate=false`, every body operator, sidecar-table lookups
  for `isa` / `depends_on`, AND/OR composition, and the `regexp`
  post-filter path. The whole file filters itself out when
  `mksqlite` is not on the MATLAB path (via `assumeFail`), so
  CI runs without the MEX still pass.

Updated `src/did/+did2/Contents.m` to document the new
`+database` subpackage and to reflect the class-scoped V_delta
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
a real V_delta schema with a `duration`/`frequency`/`ontology_term`
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

- `tests/+did2/fixtures/V_delta/demoArray.json` — new class
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

### 2026-05-13 — V_delta switch

did-schema landed `V_delta` as the new sandbox schema set (PR
`Waltham-Data-Science/did-schema#26`, merged). V_delta supersedes
V_gamma. The set version replaces V_gamma without back-compat: V_gamma
was sandbox with no production consumers; V_delta absorbs its content
plus 13 new NDIcalc-vis-matlab document types (contrast_tuning,
spatial_frequency_tuning, hartley_calc, reverse_correlation, ...).

Shape changes from V_gamma worth knowing for the +did2 loader:

- **Tier layout.** Schemas now live under `schemas/V_delta/stable/`
  rather than the flat `schemas/V_gamma/`. `draft/` and `deprecated/`
  tier folders exist but are empty in the initial cutover.
- **Superclass references** are now `{class_name}` only — the
  `schema: "$NDISCHEMAPATH/..."` path key is gone. Consumer tooling
  resolves superclasses by class_name. The +did2 schema cache was
  already class_name-driven, so no behavioral fix was needed.
- **`maturity_level`** vocabulary replaced `{work_in_progress, mature}`
  with `{stable, draft, deprecated}`. The +did2 loader doesn't read
  this field, so no fix needed beyond updating test fixtures.
- **Meta-schema** at `schemas/V_delta/stable/did_schema_meta.json` is
  V_delta-specific (new enum, dropped `schema` key in superclass
  reference object).
- **`index.json`** at the V_delta root is the new resolution source
  of truth for class_name → path lookups. The +did2 loader is not yet
  consuming it; planned for the cross-cutting work in §9.7.

Changes to +did2 on the `claude/setup-ci-test-data-XV7F3` branch:

- `+did2/+schema/cache.m`: `defaultSchemaPath()` returns
  `…/did-schema/schemas/V_delta/stable/` instead of `…/V_gamma/`.
- `+did2/+database/sqlitedb.m`: `schema_generation` is written and
  asserted as `V_delta`. Old V_gamma databases are rejected at open
  time; no upgrade path provided (V_gamma was internal sandbox).
- Test fixtures: `tests/+did2/fixtures/V_gamma/` renamed to
  `tests/+did2/fixtures/V_delta/`; `maturity_level` values updated to
  `stable`; `schema` keys dropped from superclass refs.
- Comments and docstrings sweep V_gamma → V_delta throughout `src/`
  and `tests/`.

Discussions captured in did-schema PR #26 also produced design
decisions that are not yet implemented anywhere:

- **Microschemas** for open-ended document-variant registries
  (treatments, measurements). Design at
  `did-schema/schemas/V_delta/microschemas/_DESIGN.md`. Implementation
  is downstream of meta-schema additions on the schema side.
- **Abstract fields** (`abstract_fields` on a parent class declaring
  fields that concrete subclasses must implement). Picked for the
  `calculator_base` pattern. Implementation deferred until any
  V_delta class actually uses it.

Next up: step 6 — the v1 → v2 converter (PLAN.md §7) plus the CI
test data pipeline (§9.6 sub-steps).


### 2026-05-13 — step 6a + 6c v1->V_delta converter skeleton + 4 migrators

Started step 6 on branch `claude/v2-update-step-6-qhmu3`. Sub-steps
6a (converter skeleton + identity path) and 6c (migrator
implementations for the four 2.0.0-bumped classes) landed together.
Sub-step 6b (the per-class conversion markdowns in did-schema) was
already complete on the prep branch
`claude/did-matlab-step-6-prep-sWvHr`; the designated did-schema
branch `claude/v2-update-step-6-qhmu3` is forked off the prep branch
so the four ontology-collapse markdowns
(`probe_location.md`, `treatment.md`, `ontology_image.md`,
`ontology_label.md`), `_universal_renames.md`, and the new
`schema_version` field on `base.json` are the substrate this work
sits on. 6d (CI test data pipeline) and 6e (NDIcalc-vis migrators)
remain.

Added the `+did2/+convert` subpackage on the did-matlab side:

- `src/did/+did2/+convert/v1_to_v2.m` — dispatcher and CLI entry
  point. Accepts a struct, struct array, cell array of structs, or
  JSON char (or any cell-array mix of those). Runs each input
  through `universalRenames` + the matching per-class migrator
  under `+migrators`, then wraps the v2 body in a `did2.document`
  and optionally validates it via `did2.schema.cache`. Documents
  that fail any step end up in a quarantine struct array with
  `original_body` (the JSON-encoded input), `class_name`
  (post-universal-rename, or `<unknown>` if the header was
  unreadable), `reason` (the captured error message), and
  `failed_at` (UTC ISO-8601 timestamp). Returns
  `{migrated, quarantine, summary}`; `summary` tracks totals plus
  a `by_class` struct mapping class names to migrated counts.
  Three name-value options: `Validate` (default true),
  `SchemaCache` (default the shared cache), `Verbose` (default
  false, prints the end-of-run summary report).

- `src/did/+did2/+convert/universalRenames.m` — the cross-cutting
  did_v1 -> V_delta rewrites from did-schema's
  `_universal_renames.md`:
    - snake_case `document_class.class_name` (so e.g. legacy
      `ontologyImage` becomes `ontology_image`) and rename the
      matching top-level property-block key in lockstep.
    - snake_case any `document_class.superclasses[i].class_name`.
    - promote V_alpha `depends_on[i].id` -> V_delta
      `depends_on[i].value`, leaving an existing non-empty
      `value` alone; drop the legacy `version` key.
    - default `base.schema_version` to `'V_delta'` when absent so
      the new V_delta-required field on base is satisfied.
  Internal helpers (`snakeCase`, `renameDependsOnEntries`) are
  local functions; no public surface beyond `universalRenames`
  itself.

- `src/did/+did2/+convert/+migrators/identity.m` — the
  post-universal-rename passthrough used as the default fallback
  by the dispatcher. Named `identity` rather than `_identity`
  because a leading underscore is not a valid MATLAB identifier;
  PLAN.md §9.6's `_identity.m` label is a documentation typo and
  has been left as-is in §9.6 with a note in the file header that
  the file is on disk as `identity.m`.

- `src/did/+did2/+convert/+migrators/{probe_location, treatment,
  ontology_image, ontology_label}.m` — per-class migrators for
  the four 2.0.0-bumped classes, implementing the field-level
  rules in the corresponding conversion markdowns:
    - `probe_location`: collapse `(ontology_name, name)` into a
      `location` ontology_term composite.
    - `treatment`: collapse `(ontologyName | ontology_name, name)`
      into a `treatment_name` ontology_term; pass through
      `numeric_value` and `string_value`. The dual-spelling input
      on the source CURIE field handles both V_alpha (camelCase
      `ontologyName`) and V_beta-housekept (snake-case
      `ontology_name`) sources.
    - `ontology_image`: collapse `(ontology_name,
      ontology_region)` into a `region` ontology_term. Universal
      renames take care of the `ontologyImage -> ontology_image`
      class rename.
    - `ontology_label`: collapse `(ontology_name, label_id,
      label)` into a `term` ontology_term, composing the CURIE
      as `<lowercased, space-to-underscore ontology_name>:<label_id>`.
      `label_id` is stringified whether numeric or already-char.

Tests landed alongside the implementations:

- `tests/+did2/+unittest/testConvertV1ToV2.m` — function-based
  tests covering the universal-rename effects (schema_version
  default + preservation when already set, snake-casing of
  camelCase class names with the matching property-block key
  rename, `depends_on` id -> value promotion + version drop,
  preservation of an existing non-empty `value`), the
  identity-migrator passthrough, the dispatcher with struct,
  JSON, and cell-array inputs, the quarantine path on a
  malformed input, mixed migrated+quarantine results, and the
  `by_class` summary table.
- `tests/+did2/+unittest/testMigrators.m` — function-based
  tests built from the worked examples in each conversion
  markdown: probe_location's two-char collapse, treatment from
  both `ontologyName` and `ontology_name` sources,
  ontology_image's class rename plus region composition,
  ontology_label's CURIE composition with prefix normalisation
  (lower-casing, space -> underscore) and stringified
  `label_id`, the `did2:convert:missingBlock` error on a body
  missing the expected property block, and end-to-end
  dispatcher routing through `did2.document` for probe_location
  and ontology_label.

Test runs use `'Validate', false` end-to-end and skip the
schema-cache layer entirely so they do not depend on a
checked-out did-schema directory at the runner's working
directory. A follow-up PR can add an opt-in suite that
validates the migrated documents against the cached V_delta
schemas when the schema dir is reachable.

What remains in step 6 after this PR:

- **6b** (did-schema markdowns) — done on the prep branch, now
  inherited by the designated step-6 branch on did-schema. The
  ontology-collapse markdowns are read-but-not-parsed during this
  work; the MATLAB migrators encode the same rules by hand.
- **6d** (CI test data pipeline) — separate PR. Needs decisions
  on dataset hosting (GitHub Release asset vs Zenodo vs S3),
  mksqlite availability in the CI runner image, and the
  `integration-small` / `integration-nightly` workflow gates.
- **6e** (NDIcalc-vis-matlab migrators) — separate PR, gated on
  6d once the test datasets are wired up. The 13 NDIcalc-vis
  conversion markdowns already exist on the prep branch; the
  migrator implementations are mechanical from there.

Next up: 6d.


### 2026-05-14 — step 6 readers: v1 DB readers + fromV1Database

Landed on branch `claude/v2-update-step-6-readers-qhmu3` after the
6a + 6c PR (#126) merged into V2. Adds the input side of the
converter so a real legacy v1 DID database (sqlite or
matlabdumbjsondb) can be opened, every document body read out as
raw JSON, and the whole batch piped through
`did2.convert.v1_to_v2` into a fresh v2 sqlitedb file. Closes
the "tool that opens NDI datasets or sessions, grabs all the
documents in JSON, and runs the conversion tool" line of work
from the architecture discussion in conversation. The NDI-layer
wrapper (a `ndi.convert.session(S, dstPath)` shim) is
deliberately kept out of `+did2` and lives in NDI-matlab to keep
`+did2` namespace-clean.

Added under `src/did/+did2/+convert/`:

- **`+readers/sqliteV1.m`** — reader for `did.implementations.sqlitedb`
  files. Opens the .sqlite via mksqlite (the same MEX +did2's own
  storage already requires), runs `SELECT json_code FROM docs`, and
  returns the bodies as a cellstr. The v1 schema was discovered by
  reading `src/did/+did/+implementations/sqlitedb.m`:
    - documents table: `docs(doc_id TEXT UNIQUE, doc_idx INTEGER
      AUTOINCREMENT PK, timestamp NUMERIC, json_code TEXT)`
    - other v1 tables (`branches`, `branch_docs`, `doc_data`,
      `fields`, `files`) are out of scope at this layer; the
      reader is body-level only.
  Errors flow through `did2:convert:readerFailed` (e.g. file
  missing, table missing, mksqlite missing).

- **`+readers/dumbJsonV1.m`** — reader for `matlabdumbjsondb`
  directories. Walks `<dbdir>/{.dumbjsondb,dumbjsondb}/` for the
  `Object_id_<ID>_v<HEX5>.json` body files, picks the highest-version
  body per id (matching `latestdocversion` semantics), and returns
  the bodies as a cellstr. Layout discovered by reading
  `src/did/+did/+implementations/matlabdumbjsondb.m` +
  `src/did/+did/+file/dumbjsondb.m`:
    - `Object_id_<ID>_v<HEX5>.json` — document JSON body
      (`HEX5 = dec2hex(version, 5)`).
    - `Object_id_<ID>.txt` — meta file pointing at the latest
      version number.
    - `Object_id_<ID>_v<HEX5>.json.binary` — associated binary
      file (touched empty by default; out of scope for this layer).

- **`fromV1Database.m`** — the end-to-end orchestrator. Sniffs
  `srcPath`:
    - file path -> `sqliteV1` reader,
    - directory -> `dumbJsonV1` reader,
    - anything else -> `did2:convert:badSourcePath`.
  Pipes the bodies through `did2.convert.v1_to_v2`, inserts the
  successful `did2.document` instances into a fresh
  `did2.database.sqlitedb` at `dstPath`, and writes the
  quarantine struct array (if any) to `<dstPath>.quarantine.json`
  via `jsonencode`. Refuses to overwrite an existing `dstPath`
  unless `Overwrite=true` is passed. Returns the same
  `{migrated, quarantine, summary}` struct that `v1_to_v2`
  returns. Name-value options: `Validate` (default true),
  `SchemaCache` (default []), `Verbose` (default false),
  `Overwrite` (default false).

Tests landed alongside:

- `tests/+did2/+unittest/testReaders.m` — synthesises tiny v1
  databases in tempfiles for both flavours and asserts the
  readers return the expected bodies. Covers empty databases,
  empty directories, the highest-version-wins rule for the
  dumbjsondb reader, and the malformed-source error paths.
  Gated via `assumeFail` when mksqlite is not on the MATLAB
  path (matches the existing `testSqliteDb` pattern).
- `tests/+did2/+unittest/testFromV1Database.m` — end-to-end
  tests through the orchestrator: build a synthetic v1 sqlite
  source, run `fromV1Database` to a tempfile v2 sqlite, verify
  every doc round-trips and `summary.migrated_count` matches;
  same for a dumbjsondb source; verify quarantine on a
  malformed input lands in `<dstPath>.quarantine.json`; verify
  `Overwrite=false` (default) refuses an existing dst and
  `Overwrite=true` proceeds. Tests use `'Validate', false` so
  they do not depend on a checked-out did-schema directory.

Updates `src/did/+did2/+convert/Contents.m` to document the
new `+readers` subpackage and the `fromV1Database` entry. New
`+readers/Contents.m` file documents the reader convention.

Files in v1 docs — deliberate out-of-scope follow-up:

V1 DID documents whose body contains a populated `files.file_info`
array reference binary blobs that live in the v1
database's `<dbdir>/files/<uid>` cache (for sqlitedb) or in
`Object_id_<ID>_v<HEX5>.json.binary` sidecars (for dumbjsondb).
The readers ignore these blobs entirely — they only return the
body JSON. A future pass needs to (a) copy the file blobs into
a v2 file store and (b) ensure migrators preserve the `files`
block in the body so v2 docs can resolve their attachments. In
practice this affects image-flavoured / raw-data classes (e.g.
`ontology_image` and NDI subclasses like `epoch`, `element`).

No tests were run locally — the authoring environment has no
MATLAB. CI will verify on merge.

Next up: 6d (CI test data pipeline). With the readers in place,
6d can wire a real ~16 MB v1 NDI sqlite into the per-PR
`integration-small` job and feed it through `fromV1Database`
end-to-end, asserting zero quarantine rows + a small set of
golden queries against the v2 result.
