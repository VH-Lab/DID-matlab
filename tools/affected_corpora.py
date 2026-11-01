#!/usr/bin/env python3
"""Which corpora (and NDI end-to-end runs) does a migrator change touch?

    python3 tools/affected_corpora.py --diff origin/claude/port-88
    python3 tools/affected_corpora.py src/did/+did2/+convert/+migrators_j/treatment.m

Prints, for each changed file, the v1 classes it reaches and the corpora that
hold them, then the union: the `corpora=` value to dispatch test-corpus.yml
with, and the NDI-matlab test-eta-migrate-*.yml workflows to re-run.

HOW A FILE MAPS TO v1 CLASSES (each rule is printed beside its result):

  +migrators_j/<name>.m       the v1 class <name>, matched on the normalised
                              spelling (lowercase, no `_`), because the corpora
                              spell NDI's camelCase (`ontologyTableRow`) and the
                              migrators snake_case (`ontology_table_row`).
  +migrators_j/private/<h>.m  every migrator that calls <h>, directly or through
                              other private helpers (a word-boundary grep of
                              this checkout), plus the ledger's
                              `build_state.helper_consumers`.
  +convert/<pass>.m           a batch post-pass: ALL corpora, because every
                              corpus run executes every pass over its whole
                              migrated batch, so a pass can break a corpus that
                              holds none of its consumers. The ledger's
                              `build_state.batch_pass_consumers` is printed
                              beside it; --narrow-passes uses it instead.
  anything else under src/,   ALL corpora: the driver, the validator, the
  the corpus test driver      builder and the `+v1read/` helpers reach every class.
  anything else               no corpus.

ALL is the conservative answer, never a guess narrowed for speed: a missed
corpus is a regression nobody runs.

THE CLASS CENSUS per corpus is `tools/corpus_class_census.json` (v1 class ->
document count, from the six S3 zips; regenerate with --write-census from
tools/sample_corpus.py manifests), or `source_census.by_class` of corpus
reports given with --reports. The ledger is did-schema's
schemas/did_v2_coverage_ledger.json, or schemas/V_eta_coverage_ledger.json in
a did-schema checkout from before the rename (--ledger, default
./did-schema/..., the new name first).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

from did_schema_names import schema_file

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CENSUS = os.path.join(HERE, "corpus_class_census.json")
CONVERT = "src/did/+did2/+convert/"
MIGRATORS = CONVERT + "+migrators_j/"
PRIVATE = MIGRATORS + "private/"
ALL = "ALL"

# The NDI-matlab workflows that run a corpus end to end (VH-Lab/NDI-matlab,
# .github/workflows, read 2026-10-21). 20211116 and JH have none.
NDI_E2E = {
    "PRED": "test-eta-migrate-e2e.yml",
    "B": "test-eta-migrate-b.yml",
    "Dab": "test-eta-migrate-dab.yml",
    "Soph": "test-eta-migrate-soph.yml",
}


def norm(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def load_census(path=CENSUS, reports=None):
    """{corpus: {normalised class: docs}}."""
    if reports:
        out = {}
        for root in reports:
            for dp, _, fns in os.walk(root):
                for f in fns:
                    if not f.endswith("-summary.json"):
                        continue
                    with open(os.path.join(dp, f)) as fh:
                        r = json.load(fh)
                    bc = (r.get("source_census") or {}).get("by_class") or {}
                    c = r.get("corpus") or f.split("-summary")[0]
                    out.setdefault(c, {}).update({norm(k): v for k, v in bc.items()})
        return out
    with open(path) as fh:
        data = json.load(fh)
    return {c: {norm(k): v for k, v in row["classes"].items()}
            for c, row in data["corpora"].items()}


def helper_callers(repo):
    """{helper name: set of migrator names reaching it (transitively)}."""
    mig_dir = os.path.join(repo, MIGRATORS)
    priv_dir = os.path.join(repo, PRIVATE)
    helpers = sorted(f[:-2] for f in os.listdir(priv_dir) if f.endswith(".m"))
    migrators = sorted(f[:-2] for f in os.listdir(mig_dir)
                       if f.endswith(".m") and f != "Contents.m")
    text = {}
    for m in migrators:
        with open(os.path.join(mig_dir, m + ".m"), errors="replace") as fh:
            text[("m", m)] = fh.read()
    for h in helpers:
        with open(os.path.join(priv_dir, h + ".m"), errors="replace") as fh:
            text[("h", h)] = fh.read()
    calls = {}
    for key, body in text.items():
        calls[key] = {h for h in helpers
                      if key != ("h", h) and re.search(r"\b%s\b" % re.escape(h), body)}
    out = {h: set() for h in helpers}
    for m in migrators:
        seen, stack = set(), list(calls[("m", m)])
        while stack:
            h = stack.pop()
            if h in seen:
                continue
            seen.add(h)
            stack.extend(calls[("h", h)])
        for h in seen:
            out[h].add(m)
    return out


def ledger_maps(ledger):
    passes, helpers = {}, {}
    for r in ledger.get("rows", []):
        bs = r.get("build_state") or {}
        for p in bs.get("batch_pass_consumers") or []:
            passes.setdefault(p, set()).add(norm(r["v1_class"]))
        for h in bs.get("helper_consumers") or []:
            helpers.setdefault(h, set()).add(norm(r["v1_class"]))
    return passes, helpers


def classes_for(path, callers, passes, ledger_helpers, narrow_passes=False):
    """(set of normalised v1 classes | ALL | empty set, rule text)."""
    p = path.replace("\\", "/")
    base = os.path.basename(p)[:-2] if p.endswith(".m") else os.path.basename(p)
    if p.startswith(PRIVATE) and p.endswith(".m"):
        ms = callers.get(base, set())
        cls = {norm(m) for m in ms} | ledger_helpers.get(base, set())
        if not cls:
            return ALL, "private helper with no caller found -> ALL"
        return cls, "private helper, called by %d migrator(s): %s" % (
            len(ms), ", ".join(sorted(ms)) or "(ledger only)")
    if p.startswith(MIGRATORS) and p.endswith(".m"):
        if base == "Contents":
            return set(), "Contents.m (documentation)"
        return {norm(base)}, "migrator for v1 class %s" % base
    if p.startswith(CONVERT) and p.count("/") == CONVERT.count("/") and p.endswith(".m"):
        if base in passes:
            note = "batch pass; ledger batch_pass_consumers: %s" % (
                ", ".join(sorted(passes[base])))
            if narrow_passes:
                return passes[base], note + " (--narrow-passes)"
            return ALL, note + " -> ALL (every corpus runs every pass)"
        return ALL, "convert-level file the ledger names no consumer for -> ALL"
    if p.startswith("src/"):
        return ALL, "src/ outside the per-class migrators -> ALL"
    if p.startswith("tests/+did2/+unittest/+helpers/") or \
            re.match(r"tests/\+did2/\+unittest/testCorpus\w*\.m$", p):
        return ALL, "corpus test driver -> ALL"
    return set(), "not corpus-affecting"


def analyse(paths, census, callers, passes, ledger_helpers, narrow_passes=False):
    rows, corpora = [], set()
    for p in paths:
        cls, rule = classes_for(p, callers, passes, ledger_helpers, narrow_passes)
        if cls == ALL:
            hit = set(census)
        else:
            hit = {c for c, held in census.items() if cls & set(held)}
        corpora |= hit
        rows.append({"file": p, "rule": rule,
                     "classes": "ALL" if cls == ALL else sorted(cls),
                     "corpora": sorted(hit)})
    return rows, sorted(corpora)


def changed_files(ref, repo):
    out = subprocess.run(["git", "-C", repo, "diff", "--name-only", ref + "...HEAD"],
                         check=True, capture_output=True, text=True).stdout
    return [l for l in out.splitlines() if l.strip()]


def write_census(manifests, path):
    data = {"generated_by": "tools/affected_corpora.py --write-census",
            "source": "tools/sample_corpus.py manifests over the S3 corpus zips",
            "corpora": {}}
    for m in manifests:
        with open(m) as fh:
            d = json.load(fh)
        data["corpora"][d["corpus"]] = {
            "docs": d["docs_in_corpus"],
            "classes": {r["class_name"]: r["docs_in_corpus"] for r in d["by_class"]}}
    with open(path, "w") as fh:
        json.dump(data, fh, indent=1, sort_keys=True)
        fh.write("\n")


def default_ledger(repo=REPO):
    """./did-schema's coverage ledger: `did_v2_coverage_ledger.json` if present,
    else `V_eta_coverage_ledger.json` (did-schema before the rename), else the
    new name, which the "NOT FOUND" line then names."""
    return schema_file(os.path.join(repo, "did-schema"), "coverage_ledger.json")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*", help="changed files (repo-relative)")
    ap.add_argument("--diff", metavar="REF", help="use `git diff --name-only REF...HEAD`")
    ap.add_argument("--repo", default=REPO)
    ap.add_argument("--ledger", default=default_ledger())
    ap.add_argument("--census", default=CENSUS)
    ap.add_argument("--reports", action="append",
                    help="read the class census from corpus reports instead")
    ap.add_argument("--narrow-passes", action="store_true",
                    help="map a batch pass to its ledger consumers instead of ALL")
    ap.add_argument("--write-census", nargs="+", metavar="MANIFEST",
                    help="regenerate --census from sample_corpus.py manifests and exit")
    a = ap.parse_args(argv)
    if a.write_census:
        write_census(a.write_census, a.census)
        print("wrote %s from %d manifest(s)" % (a.census, len(a.write_census)))
        return 0
    paths = list(a.files)
    if a.diff:
        paths += changed_files(a.diff, a.repo)
    census = load_census(a.census, a.reports)
    if not census:
        print("ERROR: the class census is empty -- nothing to map against", file=sys.stderr)
        return 2
    if os.path.isfile(a.ledger):
        with open(a.ledger) as fh:
            passes, ledger_helpers = ledger_maps(json.load(fh))
        ledger_note = a.ledger
    else:
        passes, ledger_helpers = {}, {}
        ledger_note = "NOT FOUND (%s): every batch pass maps to ALL" % a.ledger
    callers = helper_callers(a.repo)
    print("DENOMINATOR: %d changed file(s); census of %d corpora (%s); ledger %s"
          % (len(paths), len(census), ", ".join(
              "%s %d classes" % (c, len(census[c])) for c in sorted(census)), ledger_note))
    rows, corpora = analyse(paths, census, callers, passes, ledger_helpers,
                            a.narrow_passes)
    for r in rows:
        print("  %s\n      rule: %s\n      corpora: %s" % (
            r["file"], r["rule"], ", ".join(r["corpora"]) or "(none)"))
    print("AFFECTED CORPORA: %d of %d: %s" % (len(corpora), len(census),
                                             " ".join(corpora) or "(none)"))
    if corpora:
        print("  gh workflow run test-corpus.yml --ref <branch> -f corpora='%s'"
              % " ".join(corpora))
    ndi = [NDI_E2E[c] for c in corpora if c in NDI_E2E]
    print("NDI-matlab end-to-end: %s" % (" ".join(ndi) or "(none)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
