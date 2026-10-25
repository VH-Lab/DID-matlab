#!/usr/bin/env python3
"""Which corpus jobs test-code.yml fans out to, and did every one report?

    python3 tools/corpus_matrix.py matrix --alone JH,Soph [--github-output F]
    python3 tools/corpus_matrix.py check corpus-reports [more roots...]
    python3 tools/corpus_matrix.py gate --event E [--files-from F] [--github-output F]

THE CORPUS LIST IS DERIVED, NEVER KEPT. Both subcommands read it from
`tests/+did2/+unittest/testCorpus<NAME>.m`, so a new corpus test lands in the
matrix and in the expected set by existing, and a test-code.yml that forgot it
cannot exist. The `unit` job excludes the same files by the same prefix
(`did2.unittest.testCorpus`), so a corpus test is in exactly one place.

`matrix` prints (and with --github-output writes as `matrix=`) a GitHub
Actions matrix: one entry per corpus named in --alone, and one entry holding
every other corpus. A name in --alone with no test file is an ERROR, not a
silently empty job.

`check` is the AGGREGATE's gate. A corpus test writes
`<pwd>/corpus-reports/<NAME>-summary.json` (writeCorpusReport.m); the reports
are downloaded from every matrix job's artifact. It prints the expected set,
the found set and the denominators FIRST, then exits 1 if any expected corpus
has no report. A skipped corpus (assumeFail), a job that died before writing,
an artifact that did not upload -- all read the same here: MISSING, and red.
Reports for names outside the expected set (e.g. `fixture-*` from
testFailureFixtures) are listed as OTHER and do not count either way.

`gate` decides whether this run fans out to the corpora at all (written as
`run=true|false`). Generic migration is frozen (did-schema
`V_eta_go_forward_class_audit.md` [migration not generalizable]), so a 3-4 hour
corpus matrix on every push re-measures unchanged code; Jess Haley, 2026-10-24,
agreed to run the corpora only when migration code changes. The corpora run
when:
  - the event is workflow_dispatch (asked for by hand), or
  - the changed-file list is UNKNOWN (no --files-from, or an empty file: a
    failed API call is not measured, and not measured runs), or
  - a changed file starts with one of MIGRATION_PATHS.
Otherwise they are skipped, and the step says which files it read.

PAUSED corpora leave the matrix and the expected set. Jess Haley, 2026-10-25:
"Can we just stop running soph for now?" -- Soph alone is ~2.5 h of every
corpus run and its NDI end-to-end outgrew its 350-minute limit. A paused
corpus is printed as PAUSED (not measured), never as present or passed; it
still runs by hand through test-soph-corpus.yml (workflow_dispatch).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
TEST_DIR = os.path.join("tests", "+did2", "+unittest")
PREFIX = "testCorpus"
REPORT_SUFFIX = "-summary.json"
OTHERS = "others"
_NAME = re.compile(r"^%s(\w+)\.m$" % PREFIX)
# A changed file under one of these runs the corpora (see `gate`).
MIGRATION_PATHS = (
    "src/did/+did2/+convert/",
    "tests/+did2/+unittest/testCorpus",
    "tests/+did2/+unittest/+helpers/",
    "tools/corpus_matrix.py",
    ".github/workflows/test-code.yml",
)
# Corpora left out of the matrix and the expected set for now (see the
# docstring). Removing a name puts it back.
PAUSED = ("Soph",)


def discover(repo=REPO):
    """Sorted corpus names, one per tests/+did2/+unittest/testCorpus<NAME>.m."""
    d = os.path.join(repo, TEST_DIR)
    names = sorted(m.group(1) for f in os.listdir(d)
                   for m in [_NAME.match(f)] if m)
    if not names:
        raise SystemExit("corpus_matrix: 0 %s*.m files under %s -- the corpus "
                         "set is EMPTY, which is a broken checkout, not a pass"
                         % (PREFIX, d))
    return names


def build_matrix(names, alone, paused=PAUSED):
    unknown = [a for a in alone if a not in names]
    if unknown:
        raise SystemExit("corpus_matrix: --alone names %s with no %s<NAME>.m "
                         "(known: %s)" % (unknown, PREFIX, " ".join(names)))
    names = [n for n in names if n not in paused]
    alone = [a for a in alone if a not in paused]
    include = [{"group": a, "corpora": a} for a in alone]
    rest = [n for n in names if n not in alone]
    if rest:
        include.append({"group": OTHERS, "corpora": " ".join(rest)})
    covered = sorted(c for e in include for c in e["corpora"].split())
    assert covered == sorted(names), (covered, names)  # each corpus exactly once
    return {"include": include}


def find_reports(roots):
    """{basename: [paths]} for every *-summary.json under each root, recursively."""
    found, missing_roots = {}, []
    for root in roots:
        if not os.path.isdir(root):
            missing_roots.append(root)
            continue
        for dirpath, _dirs, files in os.walk(root):
            for f in files:
                if f.endswith(REPORT_SUFFIX):
                    found.setdefault(f, []).append(os.path.join(dirpath, f))
    return found, missing_roots


def check(roots, repo=REPO, out=print, paused=PAUSED):
    every = discover(repo)
    names = [n for n in every if n not in paused]
    held = [n for n in every if n in paused]
    found, missing_roots = find_reports(roots)
    got = {f[:-len(REPORT_SUFFIX)] for f in found}
    missing = [n for n in names if n not in got]
    present = [n for n in names if n in got]
    other = sorted(got - set(names))
    out("CORPUS REPORT CHECK")
    out("  expected %d corpus report(s), from %d %s*.m file(s): %s"
        % (len(names), len(names), PREFIX, " ".join(names)))
    out("  found    %d of %d expected; %d report file(s) in total under %s"
        % (len(present), len(names), sum(len(v) for v in found.values()),
           " ".join(roots)))
    if held:
        out("  paused   %d (not expected, NOT MEASURED here): %s"
            % (len(held), " ".join(held)))
    if missing_roots:
        out("  root(s) absent: %s" % " ".join(missing_roots))
    for n in names:
        paths = found.get(n + REPORT_SUFFIX, [])
        out("    %-10s %s" % (n, ", ".join(paths) if paths else "*** MISSING"))
    for n in other:
        out("    %-10s OTHER (not a %s*.m corpus; not counted)" % (n, PREFIX))
    if missing:
        out("CORPUS REPORT CHECK FAILED: %d of %d expected corpus report(s) "
            "MISSING: %s" % (len(missing), len(names), " ".join(missing)))
        return 1
    out("CORPUS REPORT CHECK: all %d expected corpus report(s) present"
        % len(names))
    return 0


def gate(event, files, out=print):
    """(run, reason). `files` is the changed-file list, or None when unknown."""
    if event == "workflow_dispatch":
        return True, "workflow_dispatch: run by hand"
    if not files:
        out("  changed files: NOT MEASURED (no list, or an empty one)")
        return True, "changed files not measured"
    hits = [f for f in files if f.startswith(MIGRATION_PATHS)]
    out("  changed files read: %d; under a migration path: %d"
        % (len(files), len(hits)))
    for f in hits:
        out("    %s" % f)
    if hits:
        return True, "%d changed file(s) under a migration path" % len(hits)
    return False, "no changed file under a migration path (%s)" % " ".join(
        MIGRATION_PATHS)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("matrix")
    m.add_argument("--alone", default="",
                   help="comma-separated corpora that each get their own job")
    m.add_argument("--github-output", default=None)
    c = sub.add_parser("check")
    c.add_argument("roots", nargs="+")
    g = sub.add_parser("gate")
    g.add_argument("--event", required=True)
    g.add_argument("--files-from", default=None)
    g.add_argument("--github-output", default=None)
    args = ap.parse_args(argv)
    if args.cmd == "gate":
        files = None
        if args.files_from and os.path.isfile(args.files_from):
            with open(args.files_from) as fh:
                files = [ln.strip() for ln in fh if ln.strip()]
        print("CORPUS GATE (event %s)" % args.event)
        run, why = gate(args.event, files)
        print("CORPUS GATE: %s -- %s" % ("RUN" if run else "SKIP", why))
        if args.github_output:
            with open(args.github_output, "a") as fh:
                fh.write("run=%s\n" % ("true" if run else "false"))
        return 0
    if args.cmd == "matrix":
        names = discover()
        alone = [a for a in re.split(r"[,\s]+", args.alone) if a]
        mat = build_matrix(names, alone)
        held = [n for n in names if n in PAUSED]
        print("DENOMINATOR: %d corpus test file(s), %d paused -> %d job(s)"
              % (len(names), len(held), len(mat["include"])))
        if held:
            print("  PAUSED (not run, not measured): %s" % " ".join(held))
        for e in mat["include"]:
            print("  job %-8s runs: %s" % (e["group"], e["corpora"]))
        line = "matrix=" + json.dumps(mat, separators=(",", ":"))
        print(line)
        if args.github_output:
            with open(args.github_output, "a") as fh:
                fh.write(line + "\n")
        return 0
    return check(args.roots)


if __name__ == "__main__":
    sys.exit(main())
