#!/usr/bin/env python3
"""Scratch (branch claude/corpus-counts-1110 only). Split a v1 corpus into N
shards of WHOLE sessions, for a corpus that does not migrate inside one 6-hour
job (Soph, run 42874677863: the job hit its time limit while migrating).

Sessions are grouped as tools/sample_corpus.py groups them (base.session_id),
and sessions joined by a cross-session depends_on are kept in one shard
(union-find), so no shard cuts a reference the full corpus resolves. Groups
are packed largest first onto the lightest shard. Denominators first.

usage: shard_corpus.py --src DIR --out DIR --shards N --index K
"""
import argparse
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sample_corpus import corpus_files, depends_on_ids  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--shards', type=int, required=True)
    ap.add_argument('--index', type=int, required=True)
    a = ap.parse_args()
    files = corpus_files(a.src)
    ses_of_file, ses_of_id, deps = {}, {}, {}
    unreadable = 0
    for f in files:
        try:
            d = json.load(open(os.path.join(a.src, f), encoding='utf-8'))
        except ValueError:
            d = {}
            unreadable += 1
        b = d.get('base') or {}
        s = str(b.get('session_id') or '')
        ses_of_file[f] = s
        if b.get('id'):
            ses_of_id[b['id']] = s
        deps[f] = depends_on_ids(d)
    parent = {s: s for s in set(ses_of_file.values())}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    cross = 0
    for f, ds in deps.items():
        for i in ds:
            t = ses_of_id.get(i)
            if t is not None and t != ses_of_file[f]:
                cross += 1
                parent[find(t)] = find(ses_of_file[f])
    groups = {}
    for f, s in ses_of_file.items():
        groups.setdefault(find(s), []).append(f)
    print('SHARD DENOMINATOR: %d file(s) (%d unreadable), %d session(s), %d cross-session '
          'depends_on edge(s), %d group(s)' % (len(files), unreadable, len(parent), cross, len(groups)))
    load = [0] * a.shards
    member = [[] for _ in range(a.shards)]
    for g in sorted(groups, key=lambda g: (-len(groups[g]), g)):
        k = min(range(a.shards), key=lambda i: (load[i], i))
        load[k] += len(groups[g])
        member[k].append(g)
    print('SHARD loads: %s' % load)
    os.makedirs(a.out, exist_ok=True)
    n = 0
    for g in member[a.index]:
        for f in groups[g]:
            shutil.copyfile(os.path.join(a.src, f), os.path.join(a.out, f))
            n += 1
    print('SHARD %d of %d: %d group(s), %d file(s) -> %s' % (a.index, a.shards, len(member[a.index]), n, a.out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
