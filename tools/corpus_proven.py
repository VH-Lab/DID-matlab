#!/usr/bin/env python3
"""Feed a corpus run's reports to did-schema's coverage ladder, and render the
CORPUS-PROVEN rung (stage 5) -- the only rung that can honestly say a class is
DONE.

    python3 tools/corpus_proven.py --schema-repo did-schema \
        corpus-reports tests/corpus-reports

WHY THIS EXISTS. `DID-schema/tools/coverage.py` computes a per-class migration
ladder whose top rung reads `0 yes / 0 no / 102 NOT MEASURED`, because the
reports that would answer it are written by a MATLAB corpus run in THIS
repository and have never been in reach of that tool. Both halves already
exist; nothing carried the evidence from one to the other. This is that carry.

WHAT IS WHOSE. The VERDICT is coverage.py's -- `load_corpus_evidence()` and
`corpus_verdict()`, which are written and unit-tested over there. This tool
does not reimplement either, and must not: two implementations of "is this
class proven" that disagree is worse than one that is missing. What this tool
owns is
  (1) FINDING the reports, recursively, over any number of roots, and saying
      out loud how many it found and where it looked;
  (2) INVOKING coverage.py across the repo boundary and reporting precisely
      how that interface behaved;
  (3) CROSS-CHECKING the rung it gets back against the census it fed in -- a
      row marked proven whose class appears in NO census is an instrument
      fault, not a result;
  (4) making the ATTRIBUTION LIMIT visible, because the failure signals are
      keyed by the EMITTED class and the census is keyed by the v1 SOURCE
      class, and inverting that map is not clean.

THE ATTRIBUTION LIMIT, stated once. A corpus-level ZERO is a sound upper bound
for every class in it: if the whole corpus has 0 quarantine, 0 orphans, 0
fragments and no empty required edge, then every class present in it is clean
and no attribution ever has to be performed. That is the regime every corpus
run to date has been in. When a corpus is NOT globally clean, a failure has to
be attributed to a source class through the target map, and 25 of the 85
distinct target classes are reachable from more than one v1 source (measured
below, from the ledger itself). Those are AMBIGUOUS BY CONSTRUCTION and this
tool says so rather than guessing.

ABSENT IS NOT ZERO, and NOT MEASURED IS NOT CLEAN. A class that appears in no
corpus reads NOT MEASURED forever, never `yes` and never `no`: THE CORPORA ARE
A SAMPLE OF DATASETS, NOT THE UNIVERSE, and reading "absent from the six
corpora we hold" as "clean" is the standing error this project has paid for
four times over.

ZERO REPORTS IS A NON-ZERO EXIT. Corpus run #3 (31315510527) ran six corpora
for over an hour, went green on all six, downloaded five artifacts, wrote ten
files, printed `NO CORPUS REPORTS FOUND` and exited 0 -- because a one-level
glob was pointed at a directory that `upload-artifact` had moved one level
down. The denominator below prints roots named, roots missing, directories
walked and files matched, first and unconditionally, so "found nothing" and
"looked in the wrong place" are distinguishable from the output alone.

WHAT FAILS THE STEP AND WHAT ONLY REPORTS. Instrument faults fail: no reports,
no readable source census, coverage.py absent or erroring, a rung that
contradicts the census it was computed from. A MIGRATION DEFECT -- a class
whose rung comes back `no` -- is REPORT-ONLY by default and prints in full;
pass `--gate-on-failed-rung` to make it fail the step. The reason for the
split is that this step exists to carry evidence, and a corpus failure is
exactly when that evidence matters most: the run must reach the artifact.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

REPORT_SUFFIX = "-summary.json"
LEDGER_REL = os.path.join("schemas", "V_eta_coverage_ledger.json")
COVERAGE_REL = os.path.join("tools", "coverage.py")

# The three rung states coverage.py emits, spelled as it spells them.
S_YES = "yes"
S_NO = "no"
S_NOT_MEASURED = "not measured"


def norm_class(name):
    """lowercase + underscores stripped.

    did2.validate.sourceCensus's `normClass`, and coverage.py's `norm_class`.
    Both sides of every comparison here are normalised because V_eta is
    snake_case and NDI is camelCase, and a comparison that picks one spelling
    matches nothing: `demo_ndi` was dispositioned DELETE off a grep against a
    repository that has never contained that string.
    """
    return str(name).replace("_", "").lower()


# ---------------------------------------------------------------------------
# (1) FINDING THE REPORTS
# ---------------------------------------------------------------------------

def find_reports(roots):
    """Every *-summary.json under each root, AT ANY DEPTH.

    Returns (paths, denominator). RECURSIVE for the reason recorded in
    census_digest.find_reports: MATLAB's pwd during a corpus run is `tests/`,
    so reports land in `tests/corpus-reports/`, and `upload-artifact` given
    two search paths promotes the artifact root to their least common
    ancestor, so a downloaded copy sits at
    `corpus-reports/tests/corpus-reports/`. Depth is artifact plumbing and
    must never again decide whether the census is seen.

    A root that does not exist is REPORTED, not fatal -- `corpus-reports/` at
    the repo root legitimately does not exist in test-code.yml, where the
    corpora run in-process.
    """
    den = {"roots_named": list(roots), "roots_missing": [],
           "dirs_walked": 0, "files_matched": 0,
           "duplicate_basenames": [], "per_root": {}}
    seen, paths = {}, []
    for root in roots:
        if not os.path.isdir(root):
            den["roots_missing"].append(root)
            den["per_root"][root] = 0
            continue
        found = []
        for dirpath, _dirs, names in os.walk(root):
            den["dirs_walked"] += 1
            for name in sorted(names):
                if name.endswith(REPORT_SUFFIX):
                    found.append(os.path.join(dirpath, name))
        found.sort()
        den["per_root"][root] = len(found)
        for p in found:
            den["files_matched"] += 1
            key = os.path.basename(p)
            if key in seen:
                # NOT collapsed silently. coverage.py's own reader does not
                # de-duplicate, so two copies of one corpus would be summed
                # into its `by_class` twice and named twice in the verdict's
                # "across N corpus(es)" clause. The count would still be a
                # count of a clean thing, so nothing would go red -- which is
                # exactly why it is printed here.
                den["duplicate_basenames"].append(
                    {"basename": key, "kept": seen[key], "also_at": p})
                continue
            seen[key] = p
            paths.append(p)
    return paths, den


def read_reports(paths):
    """Parse the reports and pull out the two halves stage 5 needs.

    The v1 SOURCE census (`source_census.by_class`) is the only block that can
    say "documents OF THIS v1 CLASS were in the batch"; everything else in a
    report is keyed by the EMITTED class.
    """
    den = {"files_read": 0, "files_unreadable": 0, "files_unparseable": 0,
           "reports_with_source_census": 0, "source_census_failed": [],
           "v1_documents_censused": 0, "v1_classes_seen": 0}
    reports, by_class = [], {}
    for p in paths:
        try:
            with open(p, "r") as fh:
                blob = fh.read()
        except OSError as err:
            den["files_unreadable"] += 1
            reports.append({"path": p, "corpus": os.path.basename(p),
                            "unreadable": str(err)})
            continue
        try:
            rep = json.loads(blob)
        except json.JSONDecodeError as err:
            den["files_unparseable"] += 1
            reports.append({"path": p, "corpus": os.path.basename(p),
                            "unparseable": str(err)})
            continue
        if not isinstance(rep, dict):
            den["files_unparseable"] += 1
            reports.append({"path": p, "corpus": os.path.basename(p),
                            "unparseable": "top level is not an object"})
            continue
        den["files_read"] += 1
        row = corpus_row(p, rep)
        sc = rep.get("source_census")
        if isinstance(sc, dict) and "audit_failed" in sc:
            den["source_census_failed"].append(
                {"corpus": row["corpus"], "why": str(sc["audit_failed"])})
        elif (isinstance(sc, dict) and isinstance(sc.get("total_docs"), int)
                and sc["total_docs"] > 0 and isinstance(sc.get("by_class"), dict)):
            den["reports_with_source_census"] += 1
            den["v1_documents_censused"] += sc["total_docs"]
            row["census_total_docs"] = sc["total_docs"]
            for key, val in sc["by_class"].items():
                try:
                    n = int(val)
                except (TypeError, ValueError):
                    continue
                row["census_classes"] += 1
                slot = by_class.setdefault(norm_class(key), {})
                slot[row["corpus"]] = slot.get(row["corpus"], 0) + n
        reports.append(row)
    den["v1_classes_seen"] = len(by_class)
    return reports, by_class, den


# ---------------------------------------------------------------------------
# (2) PER-CORPUS CLEANLINESS -- the regime that decides whether attribution is
#     ever performed at all.
# ---------------------------------------------------------------------------

def corpus_row(path, rep):
    """One corpus's headline counters, with ABSENT distinguished from ZERO.

    A counter this report does not carry is `None` here and prints as
    `(absent)`. It is NOT folded into a zero and it does NOT make the corpus
    globally clean: `testCorpusPRED` never calls did2.validate.references, so
    PRED's report carries no `reference_integrity` at all, and summing that
    silence as a zero orphan count is the shape of error this project keeps
    paying for.
    """
    ri = rep.get("reference_integrity")
    ri = ri if isinstance(ri, dict) else {}
    sl = rep.get("silent_loss")
    sl = sl if isinstance(sl, dict) else {}
    erd = sl.get("empty_required_dependency")
    if isinstance(erd, dict):          # jsonencode writes a 1-row struct array
        erd = [erd]                    # as a bare object
    erd = [e for e in (erd or []) if isinstance(e, dict)]
    quarantine_by_class = {}
    qr = rep.get("quarantine_reasons")
    if isinstance(qr, dict):
        qr = [qr]
    for entry in (qr or []):
        if not isinstance(entry, dict) or not entry.get("class_name"):
            continue
        try:
            n = int(entry.get("count") or 0)
        except (TypeError, ValueError):
            n = 0
        key = norm_class(entry["class_name"])
        quarantine_by_class[key] = quarantine_by_class.get(key, 0) + n
    row = {
        "path": path,
        "corpus": str(rep.get("corpus") or os.path.basename(path)),
        "total": rep.get("total"),
        "migrated_count": rep.get("migrated_count"),
        "quarantine_count": rep.get("quarantine_count"),
        "fragment_count": rep.get("fragment_count"),
        "orphan_count": ri.get("orphan_count"),
        "edges_examined": ri.get("edges_examined"),
        "empty_required_edge_rows": len(erd),
        "empty_required_edge_classes": sorted(
            {norm_class(e["class_name"]) for e in erd if e.get("class_name")}),
        "quarantine_by_class": quarantine_by_class,
        "census_total_docs": None,
        "census_classes": 0,
    }
    faults = []
    for key in ("quarantine_count", "fragment_count", "orphan_count"):
        val = row[key]
        if val is None:
            faults.append("`%s` is ABSENT from the report -- NOT a zero" % key)
        elif val:
            faults.append("%s = %s" % (key, val))
    if row["empty_required_edge_rows"]:
        faults.append("%d empty-required-edge row(s)"
                      % row["empty_required_edge_rows"])
    row["globally_clean"] = not faults
    row["not_clean_because"] = faults
    return row


# ---------------------------------------------------------------------------
# (3) THE INTERFACE: coverage.py --corpus-reports
# ---------------------------------------------------------------------------

def run_coverage(schema_repo, roots, timeout=1800):
    """Invoke did-schema's coverage.py over the same roots. Never reimplement it.

    Returns a dict that always carries `ran` and, when it did not, a `why`
    precise enough to act on -- an interface gap is a thing to REPORT to the
    counterpart, not to route around by computing the verdict here.

    NOTE it WRITES: coverage.py regenerates `schemas/V_eta_coverage_ledger.md`
    and `.json` in the checkout it runs in. In CI that checkout is a throwaway
    sibling clone, which is the only reason this is acceptable. `--check` is
    not an option -- it exits before stage 5's input is ever read.
    """
    out = {"ran": False, "schema_repo": schema_repo, "roots": list(roots)}
    tool = os.path.join(schema_repo, COVERAGE_REL)
    if not os.path.isdir(schema_repo):
        out["why"] = ("the did-schema checkout is not at `%s` -- stage 5 has no "
                      "verdict engine to invoke" % schema_repo)
        return out
    if not os.path.isfile(tool):
        out["why"] = ("`%s` does not exist. The corpus rung is computed THERE; "
                      "this step only feeds it." % tool)
        return out
    with open(tool, "r", errors="replace") as fh:
        src = fh.read()
    missing = [n for n in ("load_corpus_evidence", "corpus_verdict",
                           "--corpus-reports")
               if n not in src]
    if missing:
        out["why"] = ("`%s` does not carry %s -- the `--corpus-reports` "
                      "interface this step depends on is not present in that "
                      "checkout" % (tool, ", ".join("`%s`" % m for m in missing)))
        return out
    cmd = [sys.executable, COVERAGE_REL]
    for root in roots:
        cmd += ["--corpus-reports", os.path.abspath(root)]
    try:
        proc = subprocess.run(cmd, cwd=schema_repo, timeout=timeout,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except subprocess.TimeoutExpired:
        out["why"] = "coverage.py did not finish within %ds" % timeout
        return out
    out["ran"] = True
    out["exit_code"] = proc.returncode
    out["stdout"] = proc.stdout.decode("utf-8", "replace")
    out["command"] = " ".join(cmd)
    if proc.returncode != 0:
        out["why"] = ("coverage.py exited %d. Its own output is reproduced "
                      "above; this is a did-schema-side failure, not a corpus "
                      "result." % proc.returncode)
    return out


def read_ledger(schema_repo):
    """The regenerated ledger, or a named reason it could not be read."""
    path = os.path.join(schema_repo, LEDGER_REL)
    if not os.path.isfile(path):
        return None, "`%s` does not exist after the run" % path
    try:
        with open(path, "r") as fh:
            doc = json.loads(fh.read())
    except (OSError, json.JSONDecodeError) as err:
        return None, "`%s` is unreadable: %s" % (path, err)
    rows = doc.get("rows")
    if not isinstance(rows, list) or not rows:
        return None, "`%s` carries no `rows`" % path
    return rows, None


def rung_state(row):
    """coverage.py's stage-5 state for one ledger row, or None if absent.

    Read from `stage.stage5_state`, falling back to the ladder entry. Absent
    means the ledger has been restructured -- reported as an interface gap
    rather than defaulted, because defaulting it to `not measured` would make
    a broken read indistinguishable from an honest one.
    """
    stage = row.get("stage")
    if not isinstance(stage, dict):
        return None, None
    state = stage.get("stage5_state")
    why = None
    for entry in (stage.get("ladder") or []):
        if isinstance(entry, dict) and entry.get("stage") == 5:
            state = state or entry.get("state")
            why = entry.get("why")
    return state, why


# ---------------------------------------------------------------------------
# (4) THE CROSS-CHECK, and THE ATTRIBUTION LIMIT
# ---------------------------------------------------------------------------

def cross_check(rows, by_class):
    """The rung must not claim more than the census it was computed from.

    Two directions, and only these two, because they are the two that can be
    checked WITHOUT recomputing the verdict:

      A. A row marked PROVEN whose v1 class appears in NO readable source
         census. That is the standing error of this project -- absence read as
         a pass -- and it is an instrument fault wherever it comes from.
      B. A row marked PROVEN or FAILED in a run where nothing was censused at
         all.

    Neither asks whether the verdict is RIGHT; that question belongs to
    coverage.py and is answered by its own tests.
    """
    violations = []
    for row in rows:
        state, _why = rung_state(row)
        if state not in (S_YES, S_NO):
            continue
        seen = by_class.get(norm_class(row["v1_class"]), {})
        total = sum(seen.values())
        if total <= 0:
            violations.append(
                "`%s` is rung `%s` while 0 document(s) of it appear in any "
                "readable source census -- absence rendered as a result"
                % (row["v1_class"], state))
    return violations


def attribution_census(rows):
    """How cleanly a failure keyed by an EMITTED class inverts to a v1 source.

    TWO measurements, because two questions are being asked and they have
    different answers:

      RECORDED    over `targets` + `decided_targets`, pairs counted with
                  multiplicity across those two lists. This is the census the
                  team has on record (243 pairs / 85 targets / 60 / 25 / 48)
                  and it is reproduced here so the recorded figure stays
                  checkable.
      ATTRIBUTION over the set coverage.py's `corpus_verdict` actually matches
                  a fault against: targets + decided_targets + second_pass +
                  THE SOURCE CLASS ITSELF (a guarded passthrough validates
                  under its own name). This is the one that decides whether a
                  given fault is attributable.

    A target reachable from exactly one v1 source attributes a failure
    cleanly. A target reachable from more than one does NOT, and this tool
    never guesses which source it came from.
    """
    def sets(keys, with_self):
        out = {}
        for row in rows:
            names = set()
            for key in keys:
                names |= {norm_class(t) for t in (row.get(key) or [])}
            if with_self:
                names.add(norm_class(row["v1_class"]))
            out[row["v1_class"]] = names
        return out

    def summarise(per_source, pair_count):
        sources_of = {}
        for src, targets in per_source.items():
            for t in targets:
                sources_of.setdefault(t, set()).add(src)
        unique = sorted(t for t, s in sources_of.items() if len(s) == 1)
        shared = sorted((t for t, s in sources_of.items() if len(s) > 1),
                        key=lambda t: (-len(sources_of[t]), t))
        all_shared = sorted(src for src, targets in per_source.items()
                            if targets and all(len(sources_of[t]) > 1
                                               for t in targets))
        return {
            "rows": len(per_source),
            "pairs": pair_count,
            "distinct_targets": len(sources_of),
            "targets_from_exactly_one_source": len(unique),
            "targets_from_more_than_one_source": len(shared),
            "sources_all_of_whose_targets_are_shared": len(all_shared),
            "top_shared": [{"target": t, "sources": len(sources_of[t])}
                           for t in shared[:5]],
            "sources_of": {t: sorted(s) for t, s in sources_of.items()},
            "per_source": {k: sorted(v) for k, v in per_source.items()},
        }

    recorded_keys = ("targets", "decided_targets")
    recorded_pairs = sum(len(r.get(k) or []) for r in rows for k in recorded_keys)
    recorded = summarise(sets(recorded_keys, False), recorded_pairs)
    attr_keys = ("targets", "decided_targets", "second_pass")
    attr_pairs = sum(len(r.get(k) or []) for r in rows for k in attr_keys) + len(rows)
    attribution = summarise(sets(attr_keys, True), attr_pairs)
    # THE THIRD SET, and it is the one the ambiguity report is computed over:
    # every class a fault could be keyed by EXCEPT the source's own name. The
    # source's own name is excluded deliberately -- a fault recorded under it
    # is attributable by construction (v1 class names are unique across rows),
    # so leaving it in makes "all of this row's targets are shared" impossible
    # to satisfy and the whole measurement vacuous.
    emitted = summarise(sets(attr_keys, False),
                        sum(len(r.get(k) or []) for r in rows for k in attr_keys))
    return {"recorded": recorded, "attribution": attribution, "emitted": emitted}


def ambiguous_in(corpus, by_class, emitted):
    """v1 classes present in a NOT-clean corpus that share an emitted target.

    A failure recorded against a target several v1 sources reach cannot be
    pinned to one of them. Those rows are named AMBIGUOUS BY CONSTRUCTION,
    with the number of sources sharing the target, and never assigned.

    `all_shared` marks the rows where EVERY emitted target is shared -- no
    fault over any of their targets can be attributed at all. The others have
    at least one target of their own, so a fault there is attributable and
    only the shared part of their footprint is ambiguous.

    Only meaningful for a corpus that is NOT globally clean: in the clean
    regime a corpus-level zero bounds every class in it and nothing is
    attributed.
    """
    sources_of = emitted["sources_of"]
    out = []
    for src, targets in emitted["per_source"].items():
        if not by_class.get(norm_class(src), {}).get(corpus):
            continue
        shared = [t for t in targets if len(sources_of.get(t, [])) > 1]
        if not shared:
            continue
        out.append({"v1_class": src,
                    "shared_targets": shared,
                    "all_shared": len(shared) == len(targets),
                    "sharers": max(len(sources_of[t]) for t in shared)})
    return sorted(out, key=lambda d: (not d["all_shared"], d["v1_class"]))


# ---------------------------------------------------------------------------
# RENDER
# ---------------------------------------------------------------------------

def render(state, out):
    p = out.append
    find_den = state["find_denominator"]
    read_den = state["read_denominator"]

    p("V_eta CORPUS-PROVEN rung (stage 5) -- feeding did-schema's coverage ladder")
    p("  DENOMINATOR: %d root(s) named, %d MISSING, %d director(ies) walked, "
      "%d file(s) matched `*%s`, %d duplicate basename(s) NOT read, %d parsed, "
      "%d unreadable, %d unparseable, %d carrying a readable v1 source census, "
      "%d v1 document(s) censused, %d distinct v1 class(es) seen"
      % (len(find_den["roots_named"]), len(find_den["roots_missing"]),
         find_den["dirs_walked"], find_den["files_matched"], REPORT_SUFFIX,
         len(find_den["duplicate_basenames"]), read_den["files_read"],
         read_den["files_unreadable"], read_den["files_unparseable"],
         read_den["reports_with_source_census"],
         read_den["v1_documents_censused"], read_den["v1_classes_seen"]))
    for root in find_den["roots_named"]:
        p("    root %-40s %s" % (
            root, "*** DOES NOT EXIST" if root in find_den["roots_missing"]
            else "%d report(s)" % find_den["per_root"].get(root, 0)))
    for dup in find_den["duplicate_basenames"]:
        p("    *** DUPLICATE %s -- read %s, IGNORED %s. coverage.py does not "
          "de-duplicate: two roots that nest would double its counts."
          % (dup["basename"], dup["kept"], dup["also_at"]))
    for fail in read_den["source_census_failed"]:
        p("    *** %s: the source census FAILED in the run (%s) -- every class "
          "in this corpus is unmeasurable, not clean"
          % (fail["corpus"], fail["why"]))

    p("")
    p("  PER-CORPUS GLOBAL CLEANLINESS -- the regime that decides whether")
    p("  attribution is ever performed. A corpus-level ZERO is a sound upper")
    p("  bound for EVERY class in it; a non-zero is not a per-class verdict.")
    p("    %-14s %10s %8s %6s %7s %9s %9s  %s"
      % ("corpus", "v1 docs", "classes", "quar", "orphan", "fragment",
         "emptyedge", "GLOBALLY CLEAN"))
    for row in state["corpora"]:
        def cell(val):
            return "(absent)" if val is None else str(val)
        p("    %-14s %10s %8d %6s %7s %9s %9d  %s"
          % (row["corpus"][:14],
             cell(row["census_total_docs"]), row["census_classes"],
             cell(row["quarantine_count"]), cell(row["orphan_count"]),
             cell(row["fragment_count"]), row["empty_required_edge_rows"],
             "yes" if row["globally_clean"]
             else "NO -- " + "; ".join(row["not_clean_because"])))
    clean = [r for r in state["corpora"] if r["globally_clean"]]
    p("    %d of %d corpus(es) GLOBALLY CLEAN."
      % (len(clean), len(state["corpora"])))

    p("")
    p("  THE INTERFACE: did-schema `tools/coverage.py --corpus-reports`")
    cov = state["coverage"]
    if cov["ran"]:
        p("    ran: %s" % cov["command"])
        p("    exit %d%s" % (cov["exit_code"],
                             "" if cov["exit_code"] == 0
                             else " *** " + cov.get("why", "")))
    else:
        p("    *** NOT RUN. %s" % cov.get("why", "no reason recorded"))
        p("    This step produced its half and stopped. The verdict is NOT "
          "recomputed here: two implementations of `is this class proven` "
          "that disagree is worse than one that is missing.")

    p("")
    p("  THE RUNG, read back from %s" % LEDGER_REL)
    if state["rung"] is None:
        # NOT a zero, and not an empty table. Printing "PROVEN: 0" here would
        # be the run-#3 defect in its purest form: a count rendered for a
        # measurement that never happened.
        p("    *** NOT MEASURED -- %s"
          % (state["ledger_why"] or state["coverage"].get("why")
             or "the rung was never computed; see the fault(s) below"))
    else:
        t = state["rung"]
        p("    DENOMINATOR: %d ledger row(s), %d carrying a stage-5 state"
          % (t["rows"], t["with_state"]))
        p("    PROVEN (`yes`)      : %d" % t["yes"])
        p("    FAILED (`no`)       : %d" % t["no"])
        p("    NOT MEASURED        : %d -- of which %d hold 0 document(s) in "
          "every readable census" % (t["not_measured"], t["absent_from_corpora"]))
        p("    unrecognised state  : %d" % t["unknown"])
        p("    THE CORPORA ARE A SAMPLE OF DATASETS, NOT THE UNIVERSE. A class")
        p("    absent from all of them is UNTESTED, never clean and never failed.")
        for name in t["yes_classes"]:
            p("      PROVEN   %s" % name)
        for item in t["no_rows"]:
            p("      FAILED   %-32s %s" % (item["v1_class"], item["why"]))

    p("")
    p("  THE ATTRIBUTION LIMIT -- failure signals are keyed by the EMITTED")
    p("  class; the census is keyed by the v1 SOURCE class.")
    att = state["attribution"]
    if att is None:
        p("    *** NOT COMPUTED -- the ledger was not read.")
    else:
        rec, use = att["recorded"], att["attribution"]
        p("    DENOMINATOR (recorded census, over `targets` + `decided_targets`,")
        p("    pairs counted with multiplicity across those two lists):")
        p("      %d row(s), %d (source -> target) pair(s), %d distinct target(s)"
          % (rec["rows"], rec["pairs"], rec["distinct_targets"]))
        p("      targets reachable from EXACTLY ONE v1 source : %d"
          % rec["targets_from_exactly_one_source"])
        p("      targets reachable from MORE THAN ONE source  : %d"
          % rec["targets_from_more_than_one_source"])
        p("      v1 sources ALL of whose targets are shared   : %d"
          % rec["sources_all_of_whose_targets_are_shared"])
        p("    DENOMINATOR (the set `corpus_verdict` actually matches a fault")
        p("    against: + `second_pass` + the source class itself):")
        p("      %d (source -> target) pair(s), %d distinct target(s), %d from "
          "exactly one source, %d from more than one"
          % (use["pairs"], use["distinct_targets"],
             use["targets_from_exactly_one_source"],
             use["targets_from_more_than_one_source"]))
        p("      most-shared: " + ", ".join(
            "%s (%d sources)" % (d["target"], d["sources"])
            for d in use["top_shared"]) or "      most-shared: none")
        dirty = [r for r in state["corpora"] if not r["globally_clean"]]
        if not dirty:
            p("    EVERY corpus above is globally clean, so ATTRIBUTION WAS")
            p("    NEVER PERFORMED: each PROVEN row rests on a corpus-level")
            p("    zero, which is a sound upper bound for every class in it.")
        else:
            p("    %d corpus(es) are NOT globally clean, so attribution WAS"
              % len(dirty))
            p("    required. What can be attributed is attributed by")
            p("    coverage.py through the unique-target inversion; the rest is")
            p("    AMBIGUOUS BY CONSTRUCTION and is named here, never guessed:")
            for row in dirty:
                amb = state["ambiguous"].get(row["corpus"], [])
                full = [d for d in amb if d["all_shared"]]
                p("      %s: %d class(es) present reach a SHARED target; %d of "
                  "them reach ONLY shared targets, so no fault over any target "
                  "of theirs is attributable at all"
                  % (row["corpus"], len(amb), len(full)))
                for item in amb[:20]:
                    p("        %-28s %s shared target(s), up to %d other "
                      "source(s) reach them%s"
                      % (item["v1_class"], len(item["shared_targets"]),
                         item["sharers"] - 1,
                         "   <- EVERY target shared" if item["all_shared"]
                         else ""))
                if row["quarantine_count"]:
                    p("        NOTE `quarantine_count` is CORPUS-LEVEL in the "
                      "verdict: coverage.py reads no per-class quarantine")
                    p("        table, so a non-zero count fails EVERY class "
                      "present in this corpus. That is conservative, not")
                    p("        attributed. The report DOES carry the per-class "
                      "breakdown (`quarantine_reasons[].class_name`, the")
                    p("        post-universalRenames source class), printed "
                      "below so the implicated classes are visible:")
                    for name, n in sorted(row["quarantine_by_class"].items(),
                                          key=lambda kv: -kv[1])[:20]:
                        p("          %6d  %s" % (n, name))

    p("")
    for line in state["gates"]:
        p("  " + line)
    p("  GATE: %d instrument fault(s), %d migration defect(s) "
      "(%s). EXIT %d"
      % (len(state["instrument_faults"]), state["rung"]["no"] if state["rung"]
         else 0,
         "gating" if state["gate_on_failed_rung"] else "report-only",
         state["exit_code"]))
    return out


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def analyse(roots, schema_repo, gate_on_failed_rung=False, run_coverage_fn=None):
    """Everything except printing, so the tests can drive it."""
    paths, find_den = find_reports(roots)
    reports, by_class, read_den = read_reports(paths)
    corpora = [r for r in reports if "corpus" in r and "unreadable" not in r
               and "unparseable" not in r]
    state = {
        "find_denominator": find_den, "read_denominator": read_den,
        "corpora": corpora, "by_class": by_class,
        "gate_on_failed_rung": gate_on_failed_rung,
        "instrument_faults": [], "gates": [], "rung": None,
        "attribution": None, "ambiguous": {}, "ledger_why": None,
        "coverage": {"ran": False, "why": "not reached"},
    }
    faults = state["instrument_faults"]

    if find_den["files_matched"] == 0:
        faults.append(
            "NO CORPUS REPORTS FOUND. %d root(s) named, %d of them missing, %d "
            "director(ies) walked. This is a NON-ZERO EXIT on purpose: run #3 "
            "printed exactly this after an hour of green corpora and exited 0."
            % (len(find_den["roots_named"]), len(find_den["roots_missing"]),
               find_den["dirs_walked"]))
    elif read_den["reports_with_source_census"] == 0:
        faults.append(
            "%d report(s) matched and %d parsed, but NONE carried a readable v1 "
            "source census (`source_census.by_class` with `total_docs` > 0). "
            "Stage 5 cannot be computed from the emitted-class counters alone."
            % (find_den["files_matched"], read_den["files_read"]))

    if not faults:
        runner = run_coverage_fn or run_coverage
        state["coverage"] = runner(schema_repo, roots)
        if not state["coverage"]["ran"]:
            faults.append("THE INTERFACE IS NOT AVAILABLE: "
                          + state["coverage"].get("why", ""))
        elif state["coverage"].get("exit_code"):
            faults.append("coverage.py exited %d -- see its output above"
                          % state["coverage"]["exit_code"])
        else:
            rows, why = read_ledger(schema_repo)
            state["ledger_why"] = why
            if why:
                faults.append("THE LEDGER COULD NOT BE READ BACK: " + why)
            else:
                state["rows"] = rows
                tally = {"rows": len(rows), "with_state": 0, "yes": 0, "no": 0,
                         "not_measured": 0, "unknown": 0,
                         "absent_from_corpora": 0, "yes_classes": [],
                         "no_rows": []}
                for row in rows:
                    st, why_row = rung_state(row)
                    if st is None:
                        tally["unknown"] += 1
                        continue
                    tally["with_state"] += 1
                    if st == S_YES:
                        tally["yes"] += 1
                        tally["yes_classes"].append(row["v1_class"])
                    elif st == S_NO:
                        tally["no"] += 1
                        tally["no_rows"].append(
                            {"v1_class": row["v1_class"], "why": why_row or ""})
                    elif st == S_NOT_MEASURED:
                        tally["not_measured"] += 1
                        if not sum(by_class.get(
                                norm_class(row["v1_class"]), {}).values()):
                            tally["absent_from_corpora"] += 1
                    else:
                        tally["unknown"] += 1
                state["rung"] = tally
                if tally["unknown"]:
                    faults.append(
                        "%d ledger row(s) carry NO recognised stage-5 state -- "
                        "the ledger's shape has changed under this reader"
                        % tally["unknown"])
                for violation in cross_check(rows, by_class):
                    faults.append("THE RUNG CONTRADICTS THE CENSUS: " + violation)
                state["attribution"] = attribution_census(rows)
                for row in corpora:
                    if not row["globally_clean"]:
                        state["ambiguous"][row["corpus"]] = ambiguous_in(
                            row["corpus"], by_class,
                            state["attribution"]["emitted"])

    for fault in faults:
        state["gates"].append("*** INSTRUMENT FAULT: " + fault)
    failed = state["rung"]["no"] if state["rung"] else 0
    if failed and not gate_on_failed_rung:
        state["gates"].append(
            "%d class(es) came back rung `no`. REPORT-ONLY: this step carries "
            "evidence, and a corpus failure is exactly when that evidence must "
            "reach the artifact. Pass --gate-on-failed-rung to make it fail."
            % failed)
    state["exit_code"] = 1 if (faults or (failed and gate_on_failed_rung)) else 0
    return state


def publish(state, out_dir, schema_repo, text):
    """The intermediate artifact: the rung, the evidence, and the raw ledger."""
    os.makedirs(out_dir, exist_ok=True)
    doc = {
        "tool": "DID-matlab tools/corpus_proven.py",
        "find_denominator": state["find_denominator"],
        "read_denominator": state["read_denominator"],
        "corpora": [{k: v for k, v in row.items() if k != "path"}
                    for row in state["corpora"]],
        "coverage_interface": {k: v for k, v in state["coverage"].items()
                               if k != "stdout"},
        "rung": state["rung"],
        "attribution": (None if state["attribution"] is None else {
            "recorded": {k: v for k, v in state["attribution"]["recorded"].items()
                         if k not in ("sources_of", "per_source")},
            "attribution": {k: v for k, v
                            in state["attribution"]["attribution"].items()
                            if k not in ("sources_of", "per_source")}}),
        "ambiguous_by_construction": state["ambiguous"],
        "instrument_faults": state["instrument_faults"],
        "exit_code": state["exit_code"],
    }
    with open(os.path.join(out_dir, "v_eta_corpus_proven.json"), "w") as fh:
        json.dump(doc, fh, indent=1, sort_keys=True)
    with open(os.path.join(out_dir, "corpus_proven.txt"), "w") as fh:
        fh.write("\n".join(text) + "\n")
    if state["coverage"].get("stdout"):
        with open(os.path.join(out_dir, "coverage_stdout.txt"), "w") as fh:
            fh.write(state["coverage"]["stdout"])
    ledger = os.path.join(schema_repo, LEDGER_REL)
    if os.path.isfile(ledger):
        shutil.copyfile(ledger, os.path.join(out_dir,
                                             "V_eta_coverage_ledger.json"))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("roots", nargs="*", default=["corpus-reports",
                                                 "tests/corpus-reports"],
                    help="report roots, searched RECURSIVELY")
    ap.add_argument("--schema-repo", default=os.environ.get("DID_SCHEMA_REPO",
                                                            "did-schema"))
    ap.add_argument("--out-dir", default="corpus-proven")
    ap.add_argument("--gate-on-failed-rung", action="store_true",
                    help="make a rung `no` fail the step (default: report-only)")
    args = ap.parse_args(argv)
    roots = args.roots or ["corpus-reports", "tests/corpus-reports"]
    state = analyse(roots, args.schema_repo, args.gate_on_failed_rung)
    text = render(state, [])
    print("\n".join(text))
    if state["coverage"].get("stdout"):
        print("\n  ----- coverage.py output -----")
        for line in state["coverage"]["stdout"].rstrip().split("\n"):
            print("  | " + line)
    publish(state, args.out_dir, args.schema_repo, text)
    return state["exit_code"]


if __name__ == "__main__":
    sys.exit(main())
