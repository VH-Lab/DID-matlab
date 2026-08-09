#!/usr/bin/env python3
"""Render the corpus census from the per-corpus *-summary.json reports.

WHY THIS IS A FILE AND NOT A YAML HEREDOC
-----------------------------------------
This digest shipped broken twice, and both times the reason was that it lived
inside a `run:` block in test-code.yml where nothing could execute it except a
full ~3-hour corpus run:

  1. It printed "0 empty required edges, 0 vacuous required fields" without
     printing `total_docs`, so a census that inspected NOTHING was
     indistinguishable from one that found nothing wrong -- the very bug
     `silentLoss` itself had shipped with.

  2. It did `dict[:10]`. MATLAB's `jsonencode` writes a ONE-ELEMENT struct array
     as a bare object rather than a one-element array, so a report with exactly
     one offending row arrives as a dict. That killed run #256 mid-corpus and
     cost the two largest corpora their output.

Neither defect was reachable by any test while the code lived in YAML. As a
module it is importable, and tests/test_census_digest.py exercises both shapes
in under a second.

Usage:
    python3 tools/census_digest.py <reports-dir> [<reports-dir> ...]

Exits non-zero if any report could not be rendered -- but only AFTER every
readable report has printed. A digest that cannot read its input must say so;
it must not also destroy the data it could read.
"""

import json
import os
import sys
import traceback

# Sentinel placed in the `failed` list when the digest found no reports at all.
# ZERO REPORTS IS A FAILURE OF THE INSTRUMENT, NOT A CLEAN RUN. It used to
# return `(lines, [])` -- so run #3's census job printed "NO CORPUS REPORTS
# FOUND" and went GREEN, and six corpora that had run for over an hour
# reported nothing at all. A digest with no input has not agreed with the
# corpora; it has not read them.
MISSING_REPORTS = "<no *-summary.json found>"


def aslist(v):
    """Normalise MATLAB's array-or-object encoding to a list.

    `jsonencode` emits a 1-element struct array as a bare object and a 2+
    element one as an array, so any list-shaped field can arrive either way.
    Every list-shaped read goes through here -- not just the field that
    happened to break once.
    """
    if v is None:
        return []
    if isinstance(v, dict):
        return [v]
    if isinstance(v, list):
        return v
    return [v]


def render_report(r, out):
    """Render one corpus report. Raises on malformed input; the caller isolates."""
    p = lambda s="": out.append(s)

    p("")
    p("--- %s ---" % r.get("corpus", "(unnamed)"))
    p("  total=%s  migrated=%s  quarantine=%s"
      % (r.get("total", "?"), r.get("migrated_count", "?"),
         r.get("quarantine_count", "?")))

    sl = r.get("silent_loss") or {}
    if "audit_failed" in sl:
        p("  silent-loss: AUDIT FAILED (%s)" % sl["audit_failed"])
    elif sl:
        # total_docs FIRST and unconditionally. Without the denominator, a
        # census that inspected nothing and one that found nothing wrong print
        # identically -- see the module docstring.
        td = sl.get("total_docs", "?")
        p("  silent-loss: inspected %s doc(s), skipped %s"
          % (td, sl.get("skipped_docs", "?")))
        if td == 0:
            p("  *** total_docs=0 -- THE CENSUS INSPECTED NOTHING. The counts")
            p("  *** below are vacuous; do NOT read them as a clean result.")
        elif isinstance(td, int) and sl.get("skipped_docs", 0) == td:
            p("  *** every document was skipped -- counts below are vacuous.")
        p("  silent-loss: %s empty required edge(s), %s vacuous required field(s)"
          % (sl.get("empty_dependency_count", "?"),
             sl.get("vacuous_field_count", "?")))
        for e in aslist(sl.get("empty_required_dependency"))[:10]:
            p("      %8s  %s.%s" % (e.get("count", "?"),
                                    e.get("class_name", "?"),
                                    e.get("edge_name", "?")))
        for f in aslist(sl.get("vacuous_required_field"))[:10]:
            p("      %8s  %s / %s.%s" % (f.get("count", "?"),
                                         f.get("class_name", "?"),
                                         f.get("block", "?"),
                                         f.get("field_name", "?")))

    if "fragment_count" in r:
        fc = r["fragment_count"]
        p("  FRAGMENTS: %s migration(s) emitted only scaffolding%s"
          % (fc, "  <-- payload dropped, invisible to every other counter" if fc else ""))
        for k, v in sorted((r.get("fragment_by_class") or {}).items(),
                           key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s" % (v, k))

    if "unconverted_count" in r:
        p("  unconverted: %s document(s) returned unchanged" % r["unconverted_count"])
        for k, v in sorted((r.get("unconverted_by_class") or {}).items(),
                           key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s" % (v, k))

    sc = r.get("source_census") or {}
    if "audit_failed" in sc:
        p("  v1 source census: AUDIT FAILED (%s)" % sc["audit_failed"])
    elif sc:
        # The three pre-build measurements. DENOMINATOR FIRST, same rule as the
        # silent-loss block above and for the same reason.
        std = sc.get("total_docs", "?")
        p("  v1 source census: read %s v1 doc(s), %s unreadable"
          % (std, sc.get("skipped_docs", "?")))
        if std == 0:
            p("  *** total_docs=0 -- THE SOURCE CENSUS READ NOTHING. Everything")
            p("  *** below is vacuous; do NOT quote it as a measurement.")
        else:
            p("      epoch ids: %s doc(s) carry one, %s distinct"
              % (sc.get("docs_with_epoch_id", "?"),
                 sc.get("distinct_epoch_ids", "?")))
            for e in aslist(sc.get("epoch_id_by_prefix")):
                p("          %-16s %6s distinct  %8s doc(s)"
                  % (e.get("prefix", "?"), e.get("distinct_ids", "?"),
                     e.get("doc_count", "?")))
            # THE EPOCH GROUPING HAZARD. One `epoch` per distinct id string is
            # correct only where the string is unique per epoch;
            # `whole_session_<ref>` is minted per ELEMENT and would fuse.
            p("      grouping hazard: %s synthetic (whole_session_) id(s), "
              "%s id(s) spanning >1 session"
              % (sc.get("synthetic_epoch_id_count", "?"),
                 sc.get("cross_session_epoch_id_count", "?")))
            for x in aslist(sc.get("synthetic_epoch_ids"))[:5]:
                p("          would fuse %4s element span(s): %s"
                  % (x.get("distinct_elements", "?"), x.get("epoch_id", "?")))
            p("      session documents: %s   (distinct base.session_id: %s)"
              % (sc.get("session_doc_count", "?"),
                 sc.get("distinct_session_ids", "?")))
            if sc.get("session_doc_count") == 0:
                p("      *** NONE -- a REQUIRED `relative_to` would have no")
                p("      *** referent in this corpus.")
            p("      stimulation approaches: %s doc(s) over %s epoch(s)"
              % (sc.get("approach_doc_count", "?"),
                 sc.get("approach_epochs", "?")))
            for d in aslist(sc.get("subjects_per_approach_epoch")):
                p("          %4s subject(s): %6s epoch(s)"
                  % (d.get("n_subjects", "?"), d.get("n_epochs", "?")))
            if sc.get("approach_doc_count"):
                p("          %s approach epoch(s) with NO presentation document"
                  % sc.get("approach_epochs_no_presentation", "?"))

    for q in aslist(r.get("quarantine_reasons"))[:5]:
        p("  quarantine: %5s [%s] %s" % (q.get("count", "?"),
                                         q.get("class_name", "?"),
                                         str(q.get("reason", ""))[:90]))


def find_reports(reports_dirs):
    """Find every *-summary.json under each root in reports_dirs, at ANY depth.

    Return (chosen_paths, all_paths, dirs_walked).

    SEVERAL ROOTS because MATLAB's pwd during a corpus run is not fixed:
    `test-corpus.yml` downloads artifacts into `corpus-reports/` while
    `test-code.yml` runs the corpora in-process and they land in
    `tests/corpus-reports/`. That second workflow's digest step has been
    printing "NO CORPUS REPORTS FOUND" for the same reason, one directory off.
    A root that does not exist is reported, not fatal.

    RECURSIVE ON PURPOSE. The reports are written to `<pwd>/corpus-reports/`
    and MATLAB's pwd during a corpus run is `tests/`, so the report lands at
    `tests/corpus-reports/<NAME>-summary.json`. `upload-artifact` given two
    search paths takes their LEAST COMMON ANCESTOR as the artifact root -- the
    repo root -- so the zip carries `tests/corpus-reports/...`, and
    `download-artifact --path corpus-reports` unpacks it to
    `corpus-reports/tests/corpus-reports/...`. Run #3 (31315510527) downloaded
    5 artifacts, 10 files, and matched ZERO with the old one-level glob:

        Total of 5 artifact(s) downloaded
        NO CORPUS REPORTS FOUND (corpus-reports/*-summary.json)
        With the provided path, there will be 10 files uploaded

    Depth is an artifact-plumbing detail and must never again decide whether
    the census is seen. Duplicates (the same corpus found at two depths, which
    the two-path upload can produce) collapse to the shallowest path, and the
    collapse is REPORTED rather than silently applied.
    """
    all_paths, dirs_walked = [], 0
    for reports_dir in reports_dirs:
        for root, _dirs, names in os.walk(reports_dir):
            dirs_walked += 1
            for name in names:
                if name.endswith("-summary.json"):
                    all_paths.append(os.path.join(root, name))
    all_paths.sort()

    by_name, chosen = {}, []
    for path in all_paths:
        key = os.path.basename(path)
        if key in by_name:
            continue
        by_name[key] = path
        chosen.append(path)
    chosen.sort(key=lambda p: (os.path.basename(p), p))
    return chosen, all_paths, dirs_walked


def digest(reports_dirs):
    """Return (lines, failed_paths). Never raises on a malformed report.

    reports_dirs is a root or a list of roots.
    """
    if isinstance(reports_dirs, str):
        reports_dirs = [reports_dirs]
    out, failed = [], []
    files, all_paths, dirs_walked = find_reports(reports_dirs)

    # RULE 5, the digest's own denominator, printed FIRST and unconditionally.
    # Run #3 printed "NO CORPUS REPORTS FOUND" and exited 0 while five
    # artifacts sat unread one directory deeper. "Found nothing" and "looked
    # in the wrong place" have to be distinguishable from the output alone.
    out.append("REPORT SEARCH: %d file(s) matching *-summary.json under %s "
               "(%d director(ies) walked, %d duplicate(s) collapsed)"
               % (len(all_paths), ", ".join(repr(d) for d in reports_dirs),
                  dirs_walked, len(all_paths) - len(files)))
    for path in files:
        out.append("  read: %s" % path)
    if not files:
        out.append("NO CORPUS REPORTS FOUND (no *-summary.json at any depth "
                   "under %s)" % ", ".join(reports_dirs))
        for d in reports_dirs:
            if not os.path.isdir(d):
                out.append("  the directory itself does not exist: %s" % d)
        return (out, [MISSING_REPORTS])

    out.append("=" * 72)
    out.append("CORPUS CENSUS DIGEST  (%d corpus report(s))" % len(files))
    out.append("=" * 72)

    for path in files:
        try:
            with open(path) as fh:
                r = json.load(fh)
        except Exception as exc:
            out.append("")
            out.append("%s: UNREADABLE (%s)" % (path, exc))
            failed.append(path)
            continue
        try:
            render_report(r, out)
        except Exception:
            # Isolate per corpus: one malformed report must not suppress the
            # other five. Run #256 lost its two largest corpora to exactly this.
            out.append("  *** DIGEST FAILED for this corpus -- output above is partial:")
            out.append(traceback.format_exc())
            failed.append(path)

    out.append("")
    out.append("=" * 72)
    return out, failed


def main(argv):
    reports_dirs = argv[1:] or ["corpus-reports"]
    lines, failed = digest(reports_dirs)
    print("\n".join(lines))
    if failed:
        print("DIGEST FAILED on %d report(s): %s" % (len(failed), ", ".join(failed)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
