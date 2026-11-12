#!/usr/bin/env python3
"""Scratch count (never for V2): stimulus responses with / without their spike-times
input, and method documents carrying isspike, over a dumped final batch
(tools/corpus_counts_dump.m: migrated.jsonl, one document per line).

[response computed from the spike times] (Jess Haley, 2026-11-12). Denominators
first.

Usage: python3 -I spike_input_counts.py DUMP_DIR [DUMP_DIR ...]
"""
import json
import os
import sys
from collections import Counter


def as_list(x):
    if x is None:
        return []
    if isinstance(x, list):
        return x
    return [x]


def cname(d):
    return ((d.get('document_class') or {}).get('class_name')) or ''


def supers(d):
    out = []
    for s in as_list((d.get('document_class') or {}).get('superclasses')):
        if isinstance(s, dict):
            out.append(s.get('class_name') or '')
    return out


def edges(d, name):
    out = []
    for e in as_list(d.get('depends_on')):
        if isinstance(e, dict) and e.get('name') == name:
            v = e.get('value') or e.get('document_id') or e.get('id')
            if v:
                out.append(v)
    return out


def did(d):
    return ((d.get('base') or {}).get('id')) or ''


def is_spike_obs(d):
    if cname(d) != 'observation' or 'time' not in supers(d):
        return False
    v = (d.get('statement') or {}).get('variable') or {}
    return isinstance(v, dict) and str(v.get('node', '')).upper() == 'GO:0001508'


def count(dump):
    path = os.path.join(dump, 'migrated.jsonl')
    docs = []
    bad = 0
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                docs.append(json.loads(line))
            except ValueError:
                bad += 1
    byid = {did(d): d for d in docs}
    spike_ids = {did(d) for d in docs if is_spike_obs(d)}
    responses = [d for d in docs if cname(d) == 'calculation' and 'harmonic_component' in supers(d)]
    with_spike = [r for r in responses if any(i in spike_ids for i in edges(r, 'input_id'))]
    n_inputs = Counter(len(edges(r, 'input_id')) for r in responses)
    methods = [d for d in docs if cname(d) == 'method']
    users = Counter()
    for r in responses:
        for m in edges(r, 'method_id'):
            users[m] += 1

    def has_isspike(m):
        for p in as_list((m.get('method') or {}).get('parameters')):
            v = (p or {}).get('variable') or {}
            if isinstance(v, dict) and v.get('name') == 'isspike':
                return True
        return False
    resp_methods = [m for m in methods if (m.get('method') or {}).get('term', {}).get('node') == 'EDAM:operation_2945']
    with_isspike = [m for m in methods if has_isspike(m)]
    with_isspike_used = [m for m in with_isspike if users[did(m)] > 0]
    v1_params = [d for d in docs if cname(d) == 'stimulus_response_scalar_parameters_basic']
    v1_params_used = [d for d in v1_params if users[did(d)] > 0]
    v1_responses = [d for d in docs if cname(d) == 'stimulus_response_scalar']
    report = {}
    for name in ('migration_report_final.json',):
        p = os.path.join(dump, name)
        if os.path.exists(p):
            try:
                r = json.load(open(p, encoding='utf-8'))
                report[name] = (r.get('counts') or {}).get('inputs_not_found', 'not measured')
            except ValueError:
                report[name] = 'unreadable'
    # [orphaned response settings are an accepted loss] (2026-11-12)
    REASON = 'orphaned settings, identical to a used one, nothing refers to it'
    PCLS = 'stimulus_response_scalar_parameters_basic'
    def load(name):
        p = os.path.join(dump, name)
        if not os.path.exists(p):
            return None
        try:
            return json.load(open(p, encoding='utf-8'))
        except ValueError:
            return None
    fin = load('migration_report_final.json')
    kd = 'not measured'
    kd_orphan = 'not measured'
    if isinstance(fin, dict):
        lst = as_list(fin.get('known_v1_defects'))
        kd = len(lst)
        kd_orphan = sum(1 for e in lst if isinstance(e, dict)
                        and e.get('class') == PCLS and e.get('reason') == REASON)
    fold = load('response_parameters_fold.json') or {}
    nm = load('not_migrated.json')
    nm_ids = {e.get('id') for e in as_list(nm) if isinstance(e, dict)}
    wb = load('whole_batch_round_trip.json') or {}
    acc = wb.get('accepted_losses_by_name') or {}
    extra = {
        'fold: parameters_documents_seen': fold.get('parameters_documents_seen', 'not measured'),
        'fold: methods_minted': fold.get('methods_minted', 'not measured'),
        'fold: orphans_seen': fold.get('orphans_seen', 'not measured'),
        'fold: orphans_dropped_identical_twin': fold.get('orphans_dropped_identical_twin', 'not measured'),
        'fold: orphans_kept_no_identical_twin': fold.get('orphans_kept_no_identical_twin', 'not measured'),
        'fold: isspike_written_no_converted_user': fold.get('isspike_written_no_converted_user', 'not measured'),
        'result.not_migrated entries': len(nm_ids) if nm is not None else 'not measured',
        '  of them still in the final batch': len(nm_ids & set(byid)) if nm is not None else 'not measured',
        'final report known_v1_defects (all)': kd,
        '  orphaned-settings entries': kd_orphan,
        'whole batch: ids_lost': wb.get('ids_lost', 'not measured'),
        'whole batch: ids_accepted_lost': wb.get('ids_accepted_lost', 'not measured'),
        'whole batch: accepted orphaned response settings': acc.get('orphanedResponseSettings', 'not measured') if wb else 'not measured',
        'whole batch: sources_changed_by_batch_pass': wb.get('sources_changed_by_batch_pass', 'not measured'),
    }
    out = {
        'documents': len(docs), 'unparsed_lines': bad,
        'spike_times_observations': len(spike_ids),
        'responses (calculation+harmonic_component)': len(responses),
        '  with the spike-times input': len(with_spike),
        '  without it': len(responses) - len(with_spike),
        '  input_id count histogram': dict(sorted(n_inputs.items())),
        'v1 stimulus_response_scalar still v1': len(v1_responses),
        'method documents (all)': len(methods),
        '  Data analysis methods (EDAM:operation_2945)': len(resp_methods),
        '  method documents carrying isspike': len(with_isspike),
        '    of them used by a converted response': len(with_isspike_used),
        'v1 parameters documents still v1': len(v1_params),
        '  of them named by a converted response': len(v1_params_used),
        'final-batch migration report inputs_not_found': report.get('migration_report_final.json', 'not measured'),
    }
    out.update(extra)
    return out


def main():
    total = Counter()
    for dump in sys.argv[1:]:
        c = count(dump)
        print('== %s' % dump)
        for k, v in c.items():
            print('  %-55s %s' % (k, v))
            if isinstance(v, int):
                total[k] += v
    if len(sys.argv) > 2:
        print('== TOTAL over %d dump(s)' % (len(sys.argv) - 1))
        for k, v in total.items():
            print('  %-55s %s' % (k, v))


if __name__ == '__main__':
    main()
