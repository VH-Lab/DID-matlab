#!/usr/bin/env python3
"""Scratch count (never for V2): what DID-matlab claude/tuning-axis-terms writes
over a dumped final batch (tools/corpus_counts_dump.m: migrated.jsonl), for the
four decisions of 2026-11-12 (Jess Haley, did-schema
did_v2_go_forward_class_audit.md): [tuning axes named from the varied property],
[response type harmonics are integers], [depends on name not written when it
equals the edge], [spike unit quality and mean waveform terms]. Denominators
first. Usage: python3 -I tuning_terms_counts.py DUMP_DIR [DUMP_DIR ...]
"""
import json
import os
import sys
from collections import Counter

PREFIX = 'v1 independent_variable_label: '


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def cname(d):
    return ((d.get('document_class') or {}).get('class_name')) or ''


def term_key(t):
    if not isinstance(t, dict):
        return '<none>'
    return '%s | %s' % (t.get('node') or '', t.get('name') or '')


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
    c = Counter()
    hist = {k: Counter() for k in ('axis term (tuning_curve_calculation)',
                                   'response_type', 'label in notes',
                                   'neuron calculation variable',
                                   'spike waveform method')}
    c['documents'] = len(docs)
    c['unparsed lines'] = bad
    for d in docs:
        cn = cname(d)
        if cn in ('tuningcurve_calc', 'stimulus_tuningcurve', 'neuron_extracellular',
                  'contrasttuning_calc', 'contrastsensitivity_calc', 'oridirtuning_calc'):
            c['still v1: ' + cn] += 1
        # response_type on any value block
        for blk in d.values():
            if isinstance(blk, dict) and isinstance(blk.get('value'), dict) \
                    and 'response_type' in blk['value']:
                c['values with response_type'] += 1
                hist['response_type'][term_key(blk['value']['response_type'])] += 1
        if cn == 'tuning_curve_calculation':
            c['tuning_curve_calculation'] += 1
            dims = as_list((d.get('data') or {}).get('dimensions'))
            for dm in dims:
                hist['axis term (tuning_curve_calculation)'][term_key(dm.get('term'))] += 1
            notes = (d.get('statement') or {}).get('notes') or ''
            last = notes.split('\n')[-1] if isinstance(notes, str) else ''
            if last.startswith(PREFIX):
                c['  with the v1 label in notes'] += 1
                hist['label in notes'][last[len(PREFIX):]] += 1
            params = as_list(((d.get('interaction') or {}).get('method') or {}).get('parameters'))
            names = [((p or {}).get('variable') or {}).get('name') for p in params]
            if 'depends on.name' in names:
                c['  with depends on.name'] += 1
            if 'depends on.value' in names:
                c['  with depends on.value'] += 1
        if cn == 'calculation':
            v = (d.get('statement') or {}).get('variable') or {}
            node = (v.get('node') or '') if isinstance(v, dict) else ''
            name = (v.get('name') or '') if isinstance(v, dict) else ''
            if node in ('EMPTY:0000446', 'EMPTY:0000447') or name in (
                    'spike sort quality', 'mean spike waveform',
                    'unit isolation quality', 'spike waveform'):
                hist['neuron calculation variable'][term_key(v)] += 1
                if node == 'EMPTY:0000447' or name in ('mean spike waveform', 'spike waveform'):
                    m = ((d.get('interaction') or {}).get('method') or {}).get('term')
                    hist['spike waveform method'][term_key(m)] += 1
    rep = os.path.join(dump, 'migration_report_final.json')
    carried = Counter()
    if os.path.exists(rep):
        try:
            r = json.load(open(rep, encoding='utf-8'))
            for e in as_list(r.get('carried_as_v1')):
                if not isinstance(e, dict):
                    continue
                why = str(e.get('reason') or e.get('why') or e)
                if 'depends_on' in why and 'tuningcurve_calc' in why:
                    carried['carried: tuningcurve_calc depends_on reason'] += 1
                if 'neuron_extracellular' in str(e.get('class', '')):
                    carried['carried: neuron_extracellular'] += 1
        except ValueError:
            carried['report unreadable'] = 1
    else:
        carried['migration_report_final.json'] = 'not measured'
    wb = os.path.join(dump, 'whole_batch_round_trip.json')
    if os.path.exists(wb):
        w = json.load(open(wb, encoding='utf-8'))
        for k in ('ids_lost', 'ids_accepted_lost', 'sources_checked', 'sources_ok',
                  'sources_failed', 'failures'):
            if k in w and not isinstance(w[k], (list, dict)):
                c['whole batch: ' + k] = w[k]
            elif k in w:
                c['whole batch: ' + k + ' (entries)'] = len(w[k])
    else:
        c['whole batch round trip'] = 'not measured'
    return c, hist, carried


def main():
    tc, th, tcar = Counter(), {}, Counter()
    for dump in sys.argv[1:]:
        c, h, car = count(dump)
        print('== %s' % dump)
        for k, v in list(c.items()) + list(car.items()):
            print('  %-55s %s' % (k, v))
            if isinstance(v, int):
                (tcar if k in car else tc)[k] += v
        for name, hh in h.items():
            print('  -- %s (%d)' % (name, sum(hh.values())))
            for k, v in hh.most_common(25):
                print('       %7d  %s' % (v, k))
            th.setdefault(name, Counter()).update(hh)
    if len(sys.argv) > 2:
        print('== TOTAL over %d dump(s)' % (len(sys.argv) - 1))
        for k, v in list(tc.items()) + list(tcar.items()):
            print('  %-55s %s' % (k, v))
        for name, hh in th.items():
            print('  -- %s (%d)' % (name, sum(hh.values())))
            for k, v in hh.most_common(40):
                print('       %7d  %s' % (v, k))


if __name__ == '__main__':
    main()
