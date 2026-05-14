# RFC — step 6d: CI test data pipeline

**Status:** draft. Pre-implementation. Open questions are flagged
with **Decision needed**; once they're answered the workflow YAML
can be written in a follow-up commit on this branch.

**Scope:** wire the just-landed `did2.convert.fromV1Database`
end-to-end into CI so every PR (and/or nightly job) demonstrates
that the v1 → V_delta converter still produces a valid, queryable
v2 sqlitedb from a real v1 NDI dataset. Out of scope: the files /
binary-blob migration follow-up; the NDI-matlab session wrapper;
6e (NDIcalc-vis migrators).

**Context:** PR #126 added the converter + per-class migrators.
PR #127 added the v1 readers + the `fromV1Database` orchestrator.
Both PRs have unit-test buckets that synthesise tiny in-memory v1
DBs and run conversion against `'Validate', false`. CI today
exercises neither (a) a real-shape v1 dataset nor (b) the
`Validate=true` path against cached V_delta schemas. 6d closes
both gaps.

---

## 1. Decisions needed

The sections below enumerate the choices. Each has a tentative
recommendation so the discussion has a starting point — these
are not commitments.

### 1.1 Test dataset hosting — where does the v1 NDI fixture live?

The integration job needs a real v1 NDI sqlite database to point
`fromV1Database` at. Options:

| # | Option | Pros | Cons |
|---|---|---|---|
| A | **GitHub Release asset on did-matlab itself** | No external dependency; versioned with the repo; downloadable via authenticated `gh release download`; free for public repos. | Asset is mutable per release; needs a release-tagging discipline; ~2 GB cap per file (fine for ~16 MB). |
| B | **Zenodo** | DOI-stable; canonical for scientific datasets; permanent. | Slower download; out-of-band upload workflow; opaque to the repo. |
| C | **S3 bucket (VH-Lab-owned)** | Full control; cheap; signed-URL access. | Needs credentials in CI secrets; ongoing $ on egress; one more thing to administer. |
| D | **git-lfs in this repo** | In-tree; no external fetch step. | LFS bandwidth quotas; clone time penalty for every contributor; LFS adoption changes the repo's contributor onboarding story. |
| E | **Generated at runtime by a synthesis script** | Zero external dependency; deterministic. | Synthesis script becomes the spec, not real data; misses real-world malformations; doesn't catch the "actual NDI session schema in the wild" class of bugs. |

**Tentative recommendation: A (GitHub Release asset).** Smallest
moving parts, free, in-repo discoverable via `gh release list`,
and the dataset versioning question gets answered by tagging a
data release like `dataset-ndi-v1-2026-05`. Option E (synthetic)
also lives in-tree as a *complement* — fast smoke test that
runs even without network — but A carries the real-shape
guarantee.

**Decision needed:** A, B, C, D, E, or A+E.

### 1.2 mksqlite in CI — how does the MEX get onto the runner?

Both `did2.database.sqlitedb` and `did2.convert.readers.sqliteV1`
require `mksqlite` on the MATLAB path. Today contributors install
it locally from `https://github.com/a-ma72/mksqlite`. CI options:

| # | Option | Pros | Cons |
|---|---|---|---|
| A | **Build mksqlite from source in the workflow** | Fully transparent; pinned commit in the workflow. | Adds ~1-2 min per job for the mex build; requires apt-get sqlite-dev + a working mex compiler in the runner image. |
| B | **Prebuilt mksqlite binary stored as a workflow artifact** | Fast (no rebuild). | Needs a separate "build mksqlite" workflow that produces the artifact + a refresh discipline when mksqlite upstream changes. |
| C | **Custom runner image with mksqlite pre-baked** | Fastest jobs; build cost paid once. | Image maintenance burden; needs ghcr.io or DockerHub hosting; pins runner OS. |
| D | **Use Octave + a sqlite shim instead of MATLAB+mksqlite** | Free CI; no MathWorks license at all. | Octave compatibility for the rest of the +did2 codebase is unverified; the v2 storage was developed against MATLAB-bundled mksqlite. |

**Tentative recommendation: A (build from source in the
workflow).** mksqlite is small and builds in ~30 s on Linux. The
workflow pins the upstream commit. If job time becomes a
problem, promote to B via a tiny "build-mksqlite-mex" reusable
workflow that caches by upstream SHA.

**Decision needed:** A, B, C, or D.

### 1.3 CI runner choice — what hosts MATLAB?

| # | Option | Pros | Cons |
|---|---|---|---|
| A | **GitHub-hosted `ubuntu-latest` + `matlab-actions/setup-matlab@v2`** | Standard; documented; no infra to run; supports licence-less MATLAB for the actions usage. | Cold-start install of MATLAB is ~3-5 min; runner OS fixed by GitHub. |
| B | **VH-Lab-hosted self-hosted runner** | Persistent MATLAB install; fast warm starts; can host the dataset locally too. | Infra burden; needs admin + uptime guarantees; security review of self-hosted runner exposure. |
| C | **MathWorks Cloud Center / BYOL** | First-class MATLAB support. | Cost; access setup; overkill for this. |

**Tentative recommendation: A.** `matlab-actions/setup-matlab@v2`
on `ubuntu-latest` is the standard and matches what the
MathWorks-published examples assume. Caching is opt-in via the
action's `cache` input.

**Decision needed:** A, B, or C.

### 1.4 Workflow gating — when does the integration job run?

| # | Option | Pros | Cons |
|---|---|---|---|
| A | **Per-PR `integration-small`** (every PR, ~3-5 min) | Catches regressions before merge; tight feedback loop. | Quota burn; flaky-on-network risk. |
| B | **Push to V2 / main only** | No PR-time flakiness; cheap. | Regressions land in V2 before anyone sees them. |
| C | **Nightly cron** | Cheap; comprehensive bucket. | Slow signal; PR author isn't in the loop. |
| D | **`workflow_dispatch` only** (manual) | Zero scheduled cost. | Easy to forget; defeats the point. |
| E | **A + C combo** — small bucket per-PR, full bucket nightly | Best of both. | Two workflows to maintain. |

**Tentative recommendation: E (A + C).** Per-PR small bucket
runs a <1 min synthetic + a single real-dataset round-trip (zero
quarantine + a handful of golden queries). Nightly cron runs the
full bucket against larger datasets (when we acquire them) and
the `Validate=true` path against the full V_delta cache.

**Decision needed:** A, B, C, D, or E.

### 1.5 Test dataset size & shape — what does the canonical fixture cover?

What the integration job actually points `fromV1Database` at:

| # | Option | What it contains |
|---|---|---|
| A | **Single ~16 MB real NDI v1 sqlite** | A real session DB drawn from an NDI experiment. Representative of in-the-wild data; covers the migrated classes (`probe_location`, `treatment`, `ontology_image`, `ontology_label`) plus whatever else NDI emits. |
| B | **Synthetic minimal (<1 MB)** | One doc per migrated class, built via mksqlite + a small fixture script. Deterministic. |
| C | **A + B** — synthetic in-tree, real-data fetched | Synthetic runs anywhere with zero network; real-data adds the in-the-wild guarantee. |

**Tentative recommendation: C.** The synthetic fixture lives in
`tests/+did2/+integration/fixtures/` and is regenerated by a
small `make_fixture.m` script; the real-data fixture is fetched
via §1.1's release-asset mechanism. The per-PR job uses the
synthetic fixture; the nightly job uses both.

**Decision needed:** A, B, or C.

### 1.6 MATLAB license in CI

The `matlab-actions/setup-matlab@v2` action supports
licence-less usage for "MATLAB and Simulink", but some toolboxes
require a licence. The v2 codebase today uses only base MATLAB
+ `mksqlite` (MEX, no toolbox dependency). Quick check:

- `runtests` lives in base MATLAB (no licence).
- `jsondecode` / `jsonencode` are base MATLAB.
- `arguments` blocks are base MATLAB (R2019b+).
- `mksqlite` is a community MEX, no MathWorks licence needed beyond MATLAB itself.

**Tentative recommendation: rely on the action's licence-less
mode.** If we find a toolbox creeping in (e.g.
"Database Toolbox" — we deliberately don't use it), revisit.

**Decision needed:** confirm or flag a toolbox dependency I've
missed.

### 1.7 Assertion contract — what does the integration job actually check?

For each test run:

1. `fromV1Database` returns `summary.failed_count == 0` on the
   canonical fixture (zero quarantine).
2. `summary.by_class` matches the per-fixture expected
   counts (stored as a small JSON sidecar next to the fixture).
3. A small set of golden queries against the produced v2
   sqlitedb returns the expected number of rows
   (e.g. `did2.compileQuery({'document_class.class_name', 'eq',
   'probe_location'})` → N hits).
4. **Nightly only:** re-run with `'Validate', true` against the
   V_delta schema cache; assert every migrated doc validates.

**Tentative recommendation: all four, with #4 only on nightly.**

**Decision needed:** confirm assertion list (add / remove).

---

## 2. What the workflow YAML will look like (once §1 is decided)

Sketch only — exact form depends on §1.1-§1.4 answers.

```yaml
# .github/workflows/integration-small.yml
name: integration-small
on:
  pull_request:
    branches: [V2, main]
  workflow_dispatch:
jobs:
  convert-roundtrip:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: matlab-actions/setup-matlab@v2
      - name: Build mksqlite          # §1.2 option A
        run: ...
      - name: Fetch test dataset      # §1.1 option A
        run: gh release download dataset-ndi-v1-2026-05 ...
        env: { GH_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
      - name: Run integration bucket
        uses: matlab-actions/run-tests@v2
        with:
          source-folder: src/did
          select-by-folder: tests/+did2/+integration
```

Plus a parallel `.github/workflows/integration-nightly.yml` on a
`schedule: [{cron: '17 4 * * *'}]` trigger that adds the real-data
fixture + the `Validate=true` pass.

A new test class `tests/+did2/+integration/testFromV1DatabaseRealData.m`
holds the assertion contract from §1.7.

---

## 3. What this RFC explicitly defers

- **Files migration.** v1 docs with `files.file_info` carry
  binary blobs. The integration job in 6d will check JSON-body
  round-trip only. The dataset fixture should still *include*
  docs with `files` blocks so that when files migration lands,
  the integration job can be extended to check blob round-trip
  without changing the fixture.
- **NDI-matlab session wrapper.** A `ndi.convert.session(S, dstPath)`
  shim that calls `fromV1Database` lives in NDI-matlab, not
  here. 6d's integration job points at a DB path directly.
- **6e (NDIcalc-vis migrators).** Gated on 6d landing — once
  the integration job is green on the canonical fixture, the
  NDIcalc-vis class of v1 docs can be wired in.

---

## 4. Open process question

Should this RFC also live in the did-schema repo? The schema
repo is the source of truth for what "valid" means but doesn't
participate in MATLAB CI. **Tentative recommendation: no — keep
this RFC in did-matlab/docs/v2/ since it's about MATLAB-side
infrastructure. did-schema gets a one-line cross-link if
needed.**
