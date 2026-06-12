# DID-matlab Audit Remediation — Results (2026-06-12)

Branch `audit/did-matlab-2026-06`, off `origin/main` (`03b0f7f`). This is the
MATLAB half of the **DID lockstep**; the Python half is
`audit/did-python-2026-06`.

> **⚠️ Author-not-run.** Authored without a local MATLAB runtime. Please run the
> DID-matlab + symmetry test suites before merging.

## Findings addressed (audit §6.1)

| # | Severity | Commit | Summary |
|---|----------|--------|---------|
| 6.1-3 | Medium | `14439fb` | **SQL injection via interpolated ids.** Several `sqlitedb` queries interpolate `branch_id` / `doc_id` / `document_id` / `filename` directly into double-quoted SQL string literals, e.g. `['... WHERE doc_id="' document_id '"']`. `run_sql_query()` does not forward bind parameters to mksqlite (it calls `do_run_sql_query` without `varargin`), so those values cannot be passed as `?` placeholders; a value containing a double quote could break out of the literal and inject SQL. Added a private `escapeSqlLiteral` helper that doubles embedded double quotes (inside a double-quoted token SQLite reads `""` as an escaped `"`), mirroring DID-python's `_sql_escape`, and applied it at all 15 value-interpolation sites. The already-parameterized `run_sql_noOpen('... =?', val)` calls are unchanged. |

### isa (6.1-1) — no MATLAB change needed

MATLAB's `isa` (via `doc2sql` `meta.class`/`meta.superclass` + the SQL translation) is
the **correct reference**; the divergence was on the Python side, which has been brought
to parity (`audit/did-python-2026-06`). No DID-matlab isa change is required; the two are
merged together so a symmetry run stays consistent.

### sqlite indexes (6.1-4) — already present in MATLAB

The audit item is "Python omits MATLAB's sqlite indexes." MATLAB already creates them;
the Python side added the equivalents. No MATLAB change.

## DECISION required — do not merge a serialization change without sign-off

**§6.1-2 / §7.3-13: the `timestamp` column meaning diverges across languages and is NOT
changed here.** DID-matlab writes MATLAB `now` (datenum — days since year 0) into the
`docs`/`branches`/`branch_docs` `timestamp REAL` column (`sqlitedb.m` `do_add_branch`,
add-doc, add-to-branch); DID-python writes `time.time()` (Unix epoch seconds) into the
same column. Cross-client `lessthan`/`greaterthan` comparisons on `timestamp` silently
break, and the cloud backend stores the value verbatim.

This is a **cross-client format decision**, not a one-sided patch — changing the
serialization on either side alone would break the other and any already-stored data. It
needs an explicit decision (proposed: **ISO-8601 TEXT**, or Unix epoch seconds, with a
documented one-time conversion for existing rows) made jointly for DID-python,
DID-matlab, and the cloud backend. Left untouched pending that decision.

## Lockstep / merge

Merge with `audit/did-python-2026-06` (the Python field-name validation is the same audit
item 6.1-3). VH-Lab fork-and-PR: a DID-matlab fork is created at review time.
