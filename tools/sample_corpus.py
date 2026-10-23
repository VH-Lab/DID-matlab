#!/usr/bin/env python3
"""Reduce a v1 corpus to a few WHOLE SESSIONS that together hold every class.

Run (what test-corpus.yml does when dispatched with `sample: true`):

    python3 tools/sample_corpus.py --corpus B --src <dir of v1 *.json> \
        --out <sample root>

writes `<sample root>/B/*.json` (the kept documents, byte-for-byte copies) and
`<sample root>/B.sample.json` (the manifest: what was kept, why, and every
denominator). The manifest sits BESIDE the folder, never in it, because the
corpus driver reads every `*.json` in the folder as a v1 document.

WHY WHOLE SESSIONS. The batch post-passes (epochMint, resolveSessionAnchors,
resolveEpochProbemap, ...) work on a session's connected graph, and v1 joins
documents by STRING inside a session as well as by depends_on (CLAUDE.md:
`strcmpi(myprobemap.devicename, ...)`). A sample that cut a session in half
would make failures that the real corpus does not have. So the unit kept or
dropped is a whole `base.session_id` group, and nothing inside one is ever
dropped.

CROSS-SESSION REFERENCES are followed anyway: when a kept document's depends_on
names a document in a session that was not chosen, that WHOLE session is added
too (and its references, transitively). On the six corpora as of 2026-10-21
there are none, but the closure is what makes the claim "a sample cannot make
an orphan the full corpus does not have" true by construction rather than by
the current data.

THE SELECTION is greedy weighted set cover over v1 class names
(`document_class.class_name`): repeatedly take the session (plus the sessions
its references pull in) with the most NEW classes per document added. Ties go
to more new classes, then fewer documents, then the smaller session id. The
input order of files never matters, so the same corpus gives the same sessions
on every run; the manifest carries a digest of the kept file names so two runs
can be compared at a glance.

DENOMINATORS FIRST (Operating Rule 5). The report prints how many documents,
sessions and classes the corpus holds before it says what was kept. A class
the sample does not cover is a hard error, not a smaller number: a sampled run
that silently dropped a class would read as a clean run over that class.

A document whose JSON cannot be parsed is KEPT (it would fail the same way in
the full run) and counted as `docs_unreadable`. A document with no
`base.session_id` is grouped under the session key "" and treated like any
other session.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys

NO_SESSION = ""
UNREADABLE_CLASS = "<unreadable>"


def corpus_files(src):
    """The files the MATLAB corpus driver reads: `*.json`, not `._*`."""
    return sorted(f for f in os.listdir(src)
                  if f.endswith(".json") and not f.startswith("._")
                  and os.path.isfile(os.path.join(src, f)))


def depends_on_ids(doc):
    deps = doc.get("depends_on") or []
    if isinstance(deps, dict):
        deps = [deps]
    out = []
    for d in deps if isinstance(deps, list) else []:
        if isinstance(d, dict):
            v = d.get("value")
            if isinstance(v, str) and v:
                out.append(v)
    return out


def read_doc(path):
    """(id, class, session_id, depends_on ids) or None when unreadable."""
    try:
        with open(path, "rb") as fh:
            doc = json.loads(fh.read().decode("utf-8"))
    except (OSError, ValueError, UnicodeDecodeError):
        return None
    if not isinstance(doc, dict):
        return None
    base = doc.get("base") if isinstance(doc.get("base"), dict) else {}
    dc = doc.get("document_class") if isinstance(doc.get("document_class"), dict) else {}
    sid = base.get("session_id")
    return (str(base.get("id") or ""),
            str(dc.get("class_name") or ""),
            sid if isinstance(sid, str) else NO_SESSION,
            depends_on_ids(doc))


def load_corpus(src):
    """Index a corpus folder. Returns a dict the selector works on."""
    files = corpus_files(src)
    docs = {}          # file name -> (id, class, session, refs)
    unreadable = []
    for f in files:
        rec = read_doc(os.path.join(src, f))
        if rec is None:
            unreadable.append(f)
        else:
            docs[f] = rec
    return {"files": files, "docs": docs, "unreadable": unreadable}


def select_sessions(docs):
    """Greedy whole-session set cover. `docs`: file -> (id, class, session, refs).

    Returns (picks, kept_sessions) where picks is the ordered list of
    {session_id, sessions_added, docs_added, classes_added}.
    """
    sessions = {}                       # session -> list of files
    for f, (_, _, s, _) in docs.items():
        sessions.setdefault(s, []).append(f)
    id_session = {}
    for f, (i, _, s, _) in docs.items():
        if i:
            id_session.setdefault(i, s)
    # session -> sessions it references directly (other than itself)
    s_refs = {s: set() for s in sessions}
    for f, (_, _, s, refs) in docs.items():
        for r in refs:
            t = id_session.get(r)
            if t is not None and t != s:
                s_refs[s].add(t)
    s_classes = {s: {docs[f][1] for f in fs} for s, fs in sessions.items()}

    def closure(s, kept):
        out, stack = set(), [s]
        while stack:
            x = stack.pop()
            if x in out or x in kept:
                continue
            out.add(x)
            stack.extend(sorted(s_refs[x]))
        return out

    all_classes = set().union(*s_classes.values()) if s_classes else set()
    kept, covered, picks = set(), set(), []
    while covered != all_classes:
        best = None
        for s in sorted(sessions):
            if s in kept:
                continue
            add = closure(s, kept)
            new = set().union(*(s_classes[x] for x in add)) - covered
            if not new:
                continue
            n_docs = sum(len(sessions[x]) for x in add)
            # ratio compared exactly as a cross-multiplication; then more new
            # classes, then fewer documents, then the session id (sorted loop
            # + strict comparison keeps the smaller id on a full tie).
            key = (len(new), n_docs)
            if best is None:
                best = (s, add, new, key)
                continue
            bn, bd = best[3]
            if (len(new) * bd > bn * n_docs
                    or (len(new) * bd == bn * n_docs
                        and (len(new) > bn or (len(new) == bn and n_docs < bd)))):
                best = (s, add, new, key)
        if best is None:          # cannot happen: every class lives in a session
            raise RuntimeError("set cover stalled with classes uncovered: %s"
                               % sorted(all_classes - covered))
        s, add, new, (_, n_docs) = best
        kept |= add
        covered |= new
        picks.append({"session_id": s,
                      "sessions_added": sorted(add),
                      "docs_added": n_docs,
                      "classes_added": sorted(new)})
    # REDUNDANCY PRUNE. Greedy can take a session whose classes a later, larger
    # pick also holds (JH, 2026-10-21: the 17,945-doc session was taken for 4
    # classes the 60,739-doc session, picked next, holds as well). Try dropping
    # each pick, largest first; keep the drop when the rest still covers every
    # class AND stays closed under references (no kept session may reference a
    # dropped one). Deterministic: the order is (docs desc, session id).
    order = sorted(range(len(picks)),
                   key=lambda k: (-picks[k]["docs_added"], picks[k]["session_id"]))
    dropped = set()
    for k in order:
        rest = set()
        for j, pk in enumerate(picks):
            if j != k and j not in dropped:
                rest.update(pk["sessions_added"])
        if not rest:
            continue
        if set().union(*(s_classes[x] for x in rest)) != all_classes:
            continue
        if any(not s_refs[x] <= rest for x in rest):
            continue
        dropped.add(k)
    for k in sorted(dropped):
        picks[k]["pruned"] = True
    kept = set()
    for j, pk in enumerate(picks):
        if j not in dropped:
            kept.update(pk["sessions_added"])
    return picks, kept, sessions


def build_manifest(corpus, index):
    docs, unreadable = index["docs"], index["unreadable"]
    picks, kept, sessions = select_sessions(docs)
    kept_files = sorted([f for f, rec in docs.items() if rec[2] in kept]
                        + list(unreadable))
    by_class = {}
    holders = {}
    for f, (_, c, s, _) in docs.items():
        row = by_class.setdefault(c, {"class_name": c, "docs_in_corpus": 0,
                                      "docs_kept": 0})
        row["docs_in_corpus"] += 1
        holders.setdefault(c, set()).add(s)
        if s in kept:
            row["docs_kept"] += 1
    for c, row in by_class.items():
        row["sessions_holding"] = len(holders[c])
    if unreadable:
        by_class[UNREADABLE_CLASS] = {"class_name": UNREADABLE_CLASS,
                                      "docs_in_corpus": len(unreadable),
                                      "docs_kept": len(unreadable),
                                      "sessions_holding": 0}
    classes = sorted(c for c in by_class if c != UNREADABLE_CLASS)
    covered = sorted(c for c in classes if by_class[c]["docs_kept"] > 0)
    digest = hashlib.sha256("\n".join(kept_files).encode("utf-8")).hexdigest()
    return {
        "tool": "tools/sample_corpus.py",
        "corpus": corpus,
        "mode": "whole_sessions_greedy_set_cover",
        "docs_in_corpus": len(index["files"]),
        "docs_unreadable": len(unreadable),
        "docs_kept": len(kept_files),
        "sessions_in_corpus": len(sessions),
        "sessions_kept": len(kept),
        "classes_in_corpus": len(classes),
        "classes_covered": len(covered),
        "classes_uncovered": sorted(set(classes) - set(covered)),
        "kept_files_sha256": digest,
        "picks": picks,
        "by_class": [by_class[c] for c in sorted(by_class)],
        "kept_files": kept_files,
    }


def render(m):
    out = []
    p = out.append
    p("=== SAMPLED corpus %s (whole sessions, greedy class cover) ===" % m["corpus"])
    p("DENOMINATOR: %d doc(s) in corpus (%d unreadable), %d session(s), %d v1 class(es)"
      % (m["docs_in_corpus"], m["docs_unreadable"], m["sessions_in_corpus"],
         m["classes_in_corpus"]))
    pct = 100.0 * m["docs_kept"] / m["docs_in_corpus"] if m["docs_in_corpus"] else 0.0
    p("KEPT: %d of %d doc(s) (%.1f%%), %d of %d session(s); classes covered %d of %d"
      % (m["docs_kept"], m["docs_in_corpus"], pct, m["sessions_kept"],
         m["sessions_in_corpus"], m["classes_covered"], m["classes_in_corpus"]))
    p("kept-files sha256: %s" % m["kept_files_sha256"])
    p("picks (in order):")
    for k, pk in enumerate(m["picks"], 1):
        extra = " [PRUNED: a later pick covers it]" if pk.get("pruned") else ""
        if len(pk["sessions_added"]) > 1:
            extra += " (+%d referenced session(s))" % (len(pk["sessions_added"]) - 1)
        p("  %2d. session %-36s %7d doc(s)  +%d class(es)%s: %s"
          % (k, pk["session_id"] or '(no session_id)', pk["docs_added"],
             len(pk["classes_added"]), extra, ", ".join(pk["classes_added"])))
    p("per class:  %-42s %9s %9s %9s" % ("v1 class", "in corpus", "kept", "sessions"))
    for row in m["by_class"]:
        p("            %-42s %9d %9d %9d" % (row["class_name"], row["docs_in_corpus"],
                                          row["docs_kept"], row["sessions_holding"]))
    if m["classes_uncovered"]:
        p("*** UNCOVERED CLASSES: %s" % ", ".join(m["classes_uncovered"]))
    return "\n".join(out)


def write_sample(src, out_root, corpus, manifest):
    dest = os.path.join(out_root, corpus)
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    for f in manifest["kept_files"]:
        shutil.copyfile(os.path.join(src, f), os.path.join(dest, f))
    with open(os.path.join(out_root, corpus + ".sample.json"), "w") as fh:
        json.dump(manifest, fh, indent=1, sort_keys=True)
        fh.write("\n")
    return dest


def summarise_reports(roots):
    """One line per corpus report: was it sampled, and what did the sample hold.

    The census job prints this FIRST in a sampled run, so no number below it is
    read as a full-corpus number. A report without a `sample` block is a FULL
    run and says so; a sample block that failed to load says that.
    """
    paths = []
    for root in roots:
        if os.path.isfile(root):
            paths.append(root)
            continue
        for dp, _, fns in os.walk(root):
            paths.extend(os.path.join(dp, f) for f in fns if f.endswith("-summary.json"))
    paths = sorted(set(paths))
    lines = ["SAMPLE COVERAGE: %d corpus report(s) under %s" % (len(paths), " ".join(roots))]
    lines.append("  %-10s %-8s %17s %15s %15s" % ("corpus", "mode", "docs kept/corpus",
                                                  "sessions", "classes"))
    for p in paths:
        with open(p) as fh:
            r = json.load(fh)
        name = r.get("corpus") or os.path.basename(p)
        smp = r.get("sample")
        if smp is None:
            lines.append("  %-10s %-8s %17s" % (name, "FULL", "%s docs" % r.get("total")))
        elif "audit_failed" in smp:
            lines.append("  %-10s %-8s sample manifest unreadable: %s"
                         % (name, "SAMPLED?", smp["audit_failed"]))
        else:
            lines.append("  %-10s %-8s %17s %15s %15s" % (
                name, "SAMPLED",
                "%d/%d" % (smp.get("docs_kept", 0), smp.get("docs_in_corpus", 0)),
                "%d/%d" % (smp.get("sessions_kept", 0), smp.get("sessions_in_corpus", 0)),
                "%d/%d" % (smp.get("classes_covered", 0), smp.get("classes_in_corpus", 0))))
    return paths, "\n".join(lines)


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    if argv and argv[0] == "--summarise-reports":
        paths, text = summarise_reports(argv[1:] or ["corpus-reports"])
        print(text)
        return 0 if paths else 2
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--corpus", required=True, help="corpus name, e.g. B")
    ap.add_argument("--src", required=True, help="folder of v1 *.json documents")
    ap.add_argument("--out", help="sample root; writes <out>/<corpus>/ and "
                                  "<out>/<corpus>.sample.json")
    ap.add_argument("--summary-json", help="also write the manifest here")
    a = ap.parse_args(argv)
    if not os.path.isdir(a.src):
        print("ERROR: --src %s is not a folder" % a.src, file=sys.stderr)
        return 2
    index = load_corpus(a.src)
    if not index["files"]:
        # A sample of nothing is the all-zero run this project has shipped
        # before. Refuse it.
        print("ERROR: 0 *.json documents under %s -- refusing to sample nothing"
              % a.src, file=sys.stderr)
        return 2
    m = build_manifest(a.corpus, index)
    print(render(m))
    if a.out:
        dest = write_sample(a.src, a.out, a.corpus, m)
        print("wrote %d doc(s) to %s" % (len(m["kept_files"]), dest))
    if a.summary_json:
        with open(a.summary_json, "w") as fh:
            json.dump(m, fh, indent=1, sort_keys=True)
    if m["classes_uncovered"]:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
