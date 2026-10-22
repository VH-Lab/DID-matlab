#!/usr/bin/env python3
"""Which corpus jobs test-code.yml fans out to, and did every one report?

    python3 tools/corpus_matrix.py matrix --alone JH,Soph [--github-output F]
    python3 tools/corpus_matrix.py check corpus-reports [more roots...]

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


def build_matrix(names, alone):
    unknown = [a for a in alone if a not in names]
    if unknown:
        raise SystemExit("corpus_matrix: --alone names %s with no %s<NAME>.m "
                         "(known: %s)" % (unknown, PREFIX, " ".join(names)))
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


def check(roots, repo=REPO, out=print):
    names = discover(repo)
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


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("matrix")
    m.add_argument("--alone", default="",
                   help="comma-separated corpora that each get their own job")
    m.add_argument("--github-output", default=None)
    c = sub.add_parser("check")
    c.add_argument("roots", nargs="+")
    args = ap.parse_args(argv)
    if args.cmd == "matrix":
        names = discover()
        alone = [a for a in re.split(r"[,\s]+", args.alone) if a]
        mat = build_matrix(names, alone)
        print("DENOMINATOR: %d corpus test file(s) -> %d job(s)"
              % (len(names), len(mat["include"])))
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
