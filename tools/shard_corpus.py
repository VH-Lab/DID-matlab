#!/usr/bin/env python3
"""Cut a v1 corpus into N shards of WHOLE SESSIONS; write shard K.

Run (what test-soph-corpus.yml does for each matrix shard):

    python3 tools/shard_corpus.py --corpus Soph --src <dir of v1 *.json> \
        --out <shard root> --shards 6 --index K

writes `<shard root>/Soph/*.json` (shard K's documents, byte-for-byte copies)
and `<shard root>/Soph.sample.json` (the manifest), the layout
tools/sample_corpus.py writes. The corpus driver reads it through
DID_CORPUS_SAMPLE_DIR exactly as it reads a sample
(did2.unittest.helpers.sampledCorpus), and the manifest rides inside the
report under `sample`, so a shard's numbers cannot pass for the corpus's.

WHY. Soph (~101k documents) no longer migrates inside one 6-hour job (runs
41094952761, 44030323541: cancelled at the limit). Every shard runs the same
test, the same post-passes and the same assertions over its sessions; the
union of the shards is the whole corpus, each document in exactly one shard.

WHOLE SESSIONS, and sessions joined by a cross-session depends_on go to the
same shard (union-find), for the reason sample_corpus.py keeps whole sessions:
the batch passes work on a session's connected graph, and no shard may cut a
reference the full corpus resolves. Groups are packed largest first onto the
lightest shard (ties: lower shard index; groups ordered by size, then key), so
the cut does not depend on file order. An unreadable document goes to shard 0
(it would fail the same way in the full run).

WHAT A SHARD DOES NOT SEE: other sessions. A batch pass that joins ACROSS
sessions without a depends_on edge (resolveDatasetEntities' dataset dedup,
for one) sees only its shard's share, so its counts are per shard and do not
simply add up to a full run's. The per-document migration does not depend on
other sessions.

DENOMINATORS FIRST: the corpus, its sessions and groups, every shard's load,
then what shard K holds.
"""
from __future__ import annotations

import argparse
import hashlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sample_corpus import (UNREADABLE_CLASS, load_corpus,  # noqa: E402
                           write_sample)


def session_groups(docs):
    """Sessions joined by any cross-session depends_on, as sorted groups.

    `docs`: file -> (id, class, session, refs). Returns (groups, n_cross)
    where groups maps a group key (its smallest session id) to the sorted
    list of its sessions.
    """
    sessions = sorted({rec[2] for rec in docs.values()})
    parent = {s: s for s in sessions}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    id_session = {}
    for f in sorted(docs):
        i, _, s, _ = docs[f]
        if i:
            id_session.setdefault(i, s)
    cross = 0
    for f in sorted(docs):
        _, _, s, refs = docs[f]
        for r in refs:
            t = id_session.get(r)
            if t is not None and t != s:
                cross += 1
                a, b = find(s), find(t)
                if a != b:
                    parent[max(a, b)] = min(a, b)
    groups = {}
    for s in sessions:
        groups.setdefault(find(s), []).append(s)
    return {min(v): sorted(v) for v in groups.values()}, cross


def assign(docs, n_shards):
    """Every group to a shard. Returns (shard_of_session, loads)."""
    groups, _ = session_groups(docs)
    size = {}
    for f, rec in docs.items():
        size[rec[2]] = size.get(rec[2], 0) + 1
    gsize = {g: sum(size[s] for s in ss) for g, ss in groups.items()}
    loads = [0] * n_shards
    shard_of = {}
    for g in sorted(groups, key=lambda g: (-gsize[g], g)):
        k = min(range(n_shards), key=lambda i: (loads[i], i))
        loads[k] += gsize[g]
        for s in groups[g]:
            shard_of[s] = k
    return shard_of, loads


def build_manifest(corpus, index, n_shards, k):
    docs, unreadable = index["docs"], index["unreadable"]
    groups, cross = session_groups(docs)
    shard_of, loads = assign(docs, n_shards)
    loads = list(loads)
    loads[0] += len(unreadable)
    kept_sessions = sorted(s for s, i in shard_of.items() if i == k)
    kept = set(kept_sessions)
    kept_files = sorted([f for f, rec in docs.items() if rec[2] in kept]
                        + (list(unreadable) if k == 0 else []))
    by_class, holders = {}, {}
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
                                      "docs_kept": len(unreadable) if k == 0 else 0,
                                      "sessions_holding": 0}
    classes = sorted(c for c in by_class if c != UNREADABLE_CLASS)
    covered = sorted(c for c in classes if by_class[c]["docs_kept"] > 0)
    digest = hashlib.sha256("\n".join(kept_files).encode("utf-8")).hexdigest()
    return {
        "tool": "tools/shard_corpus.py",
        "corpus": corpus,
        "mode": "whole_session_shard",
        "shard_index": k,
        "shard_count": n_shards,
        "shard_loads": loads,
        "docs_in_corpus": len(index["files"]),
        "docs_unreadable": len(unreadable),
        "docs_kept": len(kept_files),
        "sessions_in_corpus": len({rec[2] for rec in docs.values()}),
        "sessions_kept": len(kept_sessions),
        "session_groups": len(groups),
        "cross_session_edges": cross,
        "sessions": kept_sessions,
        "classes_in_corpus": len(classes),
        "classes_covered": len(covered),
        # In OTHER shards, not lost: the union of the shards is the corpus.
        "classes_in_other_shards_only": sorted(set(classes) - set(covered)),
        "kept_files_sha256": digest,
        "by_class": [by_class[c] for c in sorted(by_class)],
        "kept_files": kept_files,
    }


def render(m):
    out = []
    p = out.append
    p("=== SHARD %d of %d, corpus %s (whole sessions) ==="
      % (m["shard_index"], m["shard_count"], m["corpus"]))
    p("DENOMINATOR: %d doc(s) in corpus (%d unreadable), %d session(s) in %d "
      "group(s), %d cross-session depends_on edge(s), %d v1 class(es)"
      % (m["docs_in_corpus"], m["docs_unreadable"], m["sessions_in_corpus"],
         m["session_groups"], m["cross_session_edges"], m["classes_in_corpus"]))
    p("SHARD loads (docs per shard, sum %d): %s" % (sum(m["shard_loads"]), m["shard_loads"]))
    p("KEPT: shard %d holds %d of %d doc(s), %d of %d session(s); classes %d of %d"
      % (m["shard_index"], m["docs_kept"], m["docs_in_corpus"], m["sessions_kept"],
         m["sessions_in_corpus"], m["classes_covered"], m["classes_in_corpus"]))
    p("kept-files sha256: %s" % m["kept_files_sha256"])
    p("sessions: %s" % ", ".join(s or "(no session_id)" for s in m["sessions"]))
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--corpus", required=True, help="corpus name, e.g. Soph")
    ap.add_argument("--src", required=True, help="folder of v1 *.json documents")
    ap.add_argument("--out", required=True, help="shard root; writes <out>/<corpus>/ "
                                                 "and <out>/<corpus>.sample.json")
    ap.add_argument("--shards", type=int, required=True)
    ap.add_argument("--index", type=int, required=True)
    a = ap.parse_args(argv)
    if a.shards < 1 or not 0 <= a.index < a.shards:
        print("ERROR: --index %d is not a shard of --shards %d" % (a.index, a.shards),
              file=sys.stderr)
        return 2
    if not os.path.isdir(a.src):
        print("ERROR: --src %s is not a folder" % a.src, file=sys.stderr)
        return 2
    index = load_corpus(a.src)
    if not index["files"]:
        print("ERROR: 0 *.json documents under %s -- refusing to shard nothing"
              % a.src, file=sys.stderr)
        return 2
    m = build_manifest(a.corpus, index, a.shards, a.index)
    print(render(m))
    if sum(m["shard_loads"]) != m["docs_in_corpus"]:
        print("ERROR: shard loads sum to %d, the corpus holds %d"
              % (sum(m["shard_loads"]), m["docs_in_corpus"]), file=sys.stderr)
        return 2
    if not m["kept_files"]:
        # More shards than session groups: an empty shard is a run of nothing.
        print("ERROR: shard %d holds 0 documents (%d group(s) for %d shard(s))"
              % (a.index, m["session_groups"], a.shards), file=sys.stderr)
        return 2
    dest = write_sample(a.src, a.out, a.corpus, m)
    print("wrote %d doc(s) to %s" % (len(m["kept_files"]), dest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
