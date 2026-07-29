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
    python3 tools/census_digest.py <reports-dir>

Exits non-zero if any report could not be rendered -- but only AFTER every
readable report has printed. A digest that cannot read its input must say so;
it must not also destroy the data it could read.
"""

import glob
import json
import os
import sys
import traceback


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

    for q in aslist(r.get("quarantine_reasons"))[:5]:
        p("  quarantine: %5s [%s] %s" % (q.get("count", "?"),
                                         q.get("class_name", "?"),
                                         str(q.get("reason", ""))[:90]))


def digest(reports_dir):
    """Return (lines, failed_paths). Never raises on a malformed report."""
    out, failed = [], []
    files = sorted(glob.glob(os.path.join(reports_dir, "*-summary.json")))
    if not files:
        return (["NO CORPUS REPORTS FOUND (%s/*-summary.json)" % reports_dir], [])

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
    reports_dir = argv[1] if len(argv) > 1 else "corpus-reports"
    lines, failed = digest(reports_dir)
    print("\n".join(lines))
    if failed:
        print("DIGEST FAILED on %d report(s): %s" % (len(failed), ", ".join(failed)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
