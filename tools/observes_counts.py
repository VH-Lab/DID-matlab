#!/usr/bin/env python3
"""Scratch count (never for V2): `observes` directed_relations left in a dumped
final batch (tools/corpus_counts_dump.m: migrated.jsonl), and, for each, whether
a manipulation or observation with the same instrument and subject is present.

[observes retires on a matching manipulation] (Jess Haley, 2026-11-12).
Denominators first.

Usage: python3 -I observes_counts.py DUMP_DIR [DUMP_DIR ...]
"""
import json
import os
import sys
from collections import Counter


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def cname(d):
    return ((d.get('document_class') or {}).get('class_name')) or ''


def edges(d, name):
    out = []
    for e in as_list(d.get('depends_on')):
        if isinstance(e, dict) and e.get('name') == name:
            v = e.get('value') or e.get('document_id') or e.get('id')
            if v:
                out.append(v)
    return out


def is_observes(d):
    if cname(d) != 'directed_relation':
        return False
    r = (d.get('directed_relation') or {}).get('relation') or {}
    if isinstance(r, dict):
        return str(r.get('name', '')).strip().lower() == 'observes' or \
            str(r.get('handle', '')).strip().lower() == 'observes'
    return str(r).strip().lower() == 'observes'


def count(dump):
    docs, bad = [], 0
    with open(os.path.join(dump, 'migrated.jsonl'), encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                docs.append(json.loads(line))
            except ValueError:
                bad += 1
    print(f'== {dump}: {len(docs)} final documents read, {bad} unreadable')
    pairs = Counter()
    for d in docs:
        if cname(d) in ('manipulation', 'observation'):
            for i in edges(d, 'instrument_id'):
                for s in edges(d, 'entity_id'):
                    pairs[(cname(d), i, s)] += 1
    rels = [d for d in docs if cname(d) == 'directed_relation']
    obs = [d for d in rels if is_observes(d)]
    print(f'directed_relation documents: {len(rels)}; of them `observes`: {len(obs)}')
    kinds = Counter()
    for d in obs:
        c = (edges(d, 'child_id') or [''])[0]
        p = (edges(d, 'parent_id') or [''])[0]
        m = pairs[('manipulation', c, p)]
        o = pairs[('observation', c, p)]
        kinds[('matching manipulation' if m else 'no matching manipulation') + ', ' +
              ('matching observation' if o else 'no matching observation')] += 1
    for k, v in sorted(kinds.items()):
        print(f'  observes left with {k}: {v}')
    return len(obs)


if __name__ == '__main__':
    total = sum(count(d) for d in sys.argv[1:])
    print(f'TOTAL observes left: {total}')
