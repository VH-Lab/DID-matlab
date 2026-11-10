#!/usr/bin/env python3
"""Scratch counter (branch claude/corpus-counts-1110 only; never for V2).

Decided by Jess Haley 2026-11-10 [two corpus counts]: run and report; nothing is
changed on the strength of them.

COUNT 1 (did-schema #89), over the FINAL migrated batch that
tools/corpus_counts_dump.m wrote (runCorpusDiscovery: pass 1 + every batch pass):
  - ontology_term values ({node, name} dicts, anywhere) whose node is empty,
    by <class>.<field path>;
  - statements (class closure contains `statement`) whose `variable` node is not
    in did-schema's term registry, with the top unregistered names.
COUNT 2 (did-schema #200, carry-106): v1 documents that become a statement
  (some output id of the source, in the final batch, is a statement) whose v1
  base.name is not empty, by v1 class, with example names.

Every block prints its denominator first. A denominator of 0 prints NOT MEASURED.

usage: corpus_counts.py --corpus NAME --dump DIR --schemas ETA_SCHEMA_DIR
                        --registry did_v2_term_registry.json [--json OUT]
"""
import argparse
import collections
import json
import os
import sys


def load_jsonl(path):
    docs = []
    bad = 0
    with open(path, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                docs.append(json.loads(line))
            except ValueError:
                bad += 1
    return docs, bad


def class_graph(schema_dir):
    parents = {}
    n = 0
    for root, _, files in os.walk(schema_dir):
        for f in files:
            if not f.endswith('.json'):
                continue
            try:
                d = json.load(open(os.path.join(root, f), encoding='utf-8'))
            except ValueError:
                continue
            dc = d.get('document_class') if isinstance(d, dict) else None
            if not isinstance(dc, dict) or 'class_name' not in dc:
                continue
            n += 1
            sup = dc.get('superclasses') or []
            if isinstance(sup, dict):
                sup = [sup]
            parents[dc['class_name']] = [s.get('class_name') for s in sup
                                         if isinstance(s, dict)]
            paths = []
            collect_term_paths(d.get('fields') or [], '', paths)
            TERM_PATHS[dc['class_name']] = paths
    return parents, n


TERM_PATHS = {}


def collect_term_paths(fields, prefix, out):
    for f in fields:
        if not isinstance(f, dict) or 'name' not in f:
            continue
        p = prefix + f['name']
        if f.get('type') == 'ontology_term':
            out.append(p)
        if isinstance(f.get('fields'), list):
            collect_term_paths(f['fields'], p + '.', out)


def closure(cls, parents, doc=None):
    seen = set()
    stack = [cls]
    while stack:
        c = stack.pop()
        if c in seen:
            continue
        seen.add(c)
        stack.extend(parents.get(c, []))
    if doc is not None:
        sup = (doc.get('document_class') or {}).get('superclasses') or []
        if isinstance(sup, dict):
            sup = [sup]
        for s in sup:
            if isinstance(s, dict) and s.get('class_name'):
                seen |= closure(s['class_name'], parents)
    return seen


def cname(doc):
    dc = doc.get('document_class') if isinstance(doc, dict) else None
    if isinstance(dc, dict):
        return str(dc.get('class_name', '<none>'))
    return '<none>'


def doc_id(doc):
    b = doc.get('base') if isinstance(doc, dict) else None
    if isinstance(b, dict):
        return b.get('id')
    return None


def is_empty(v):
    return v is None or v == '' or v == [] or (isinstance(v, str) and not v.strip())


def walk_terms(obj, path, out):
    if isinstance(obj, dict):
        if 'node' in obj:
            out.append((path, obj))
        for k, v in obj.items():
            walk_terms(v, path + ('.' if path else '') + k, out)
    elif isinstance(obj, list):
        for v in obj:
            walk_terms(v, path, out)


def slot_values(obj, parts):
    """Leaves at a dotted path, descending through lists."""
    if isinstance(obj, list):
        for v in obj:
            yield from slot_values(v, parts)
        return
    if not parts:
        yield obj
        return
    if isinstance(obj, dict) and parts[0] in obj:
        yield from slot_values(obj[parts[0]], parts[1:])


def schema_terms(doc, classes):
    """(path, value) for every value at a schema-declared ontology_term slot
    of a class in the document's closure; the class's fields live in the
    document's block of that class's name."""
    out = []
    for c in sorted(classes):
        block = doc.get(c)
        if block is None:
            continue
        for p in TERM_PATHS.get(c, []):
            for v in slot_values(block, p.split('.')):
                out.append(('%s.%s' % (c, p), v))
    return out


def find_variable(doc):
    """statement.variable (statement declares `variable`, scalar ontology_term)."""
    st = doc.get('statement')
    if isinstance(st, dict) and 'variable' in st:
        v = st['variable']
        if isinstance(v, dict):
            return 'statement.variable', v
        return 'statement.variable', {'node': '', 'name': ''}
    return None, None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--corpus', required=True)
    ap.add_argument('--dump', required=True)
    ap.add_argument('--schemas', required=True)
    ap.add_argument('--registry', required=True)
    ap.add_argument('--v1dir', default=None)
    ap.add_argument('--json', default=None)
    a = ap.parse_args()
    C = a.corpus
    P = lambda *x: print('[%s] COUNTS ' % C + ' '.join(str(y) for y in x))

    parents, nclasses = class_graph(a.schemas)
    P('schema classes read from %s: %d' % (a.schemas, nclasses))
    reg = json.load(open(a.registry, encoding='utf-8'))
    terms = reg['terms'] if isinstance(reg, dict) else reg
    reg_nodes = {t.get('node') for t in terms if t.get('node')}
    reg_names = {t.get('name') for t in terms if t.get('name')}
    P('term registry %s: %d term(s), %d node(s)' % (a.registry, len(terms), len(reg_nodes)))

    docs, bad = load_jsonl(os.path.join(a.dump, 'migrated.jsonl'))
    P('COUNT1 documents inspected: %d (unparseable lines: %d)' % (len(docs), bad))
    report = {'corpus': C, 'documents_inspected': len(docs), 'unparseable': bad}

    # ---- COUNT 1a: empty-node ontology_term values
    # A term value is (i) a dict at a slot the schema declares ontology_term,
    # for a class in the document's closure, or (ii) any other dict with a
    # `node` key (undeclared slot, e.g. a carried v1 body or an entry shape the
    # schema does not spell out). "node empty" = the key absent, '' or [].
    tv = 0
    empty = collections.Counter()
    empty_both = collections.Counter()
    by_slot = collections.Counter()
    not_struct = collections.Counter()   # declared slot holding a non-dict, non-empty value
    blank_slot = collections.Counter()   # declared scalar slot holding '' / None
    declared_n = 0
    for d in docs:
        c = cname(d)
        seen = set()
        vals = []
        for path, v in schema_terms(d, closure(c, parents, d)):
            if isinstance(v, dict):
                seen.add(id(v))
                vals.append((path, v))
                declared_n += 1
            elif v is None or v == '':
                blank_slot['%s:%s' % (c, path)] += 1
            elif v == []:
                pass
            else:
                not_struct['%s:%s' % (c, path)] += 1
        extra = []
        walk_terms(d, '', extra)
        for path, t in extra:
            if id(t) not in seen and 'node' in t:
                vals.append(('%s (undeclared slot)' % path, t))
        for path, t in vals:
            tv += 1
            key = '%s:%s' % (c, path)
            by_slot[key] += 1
            if is_empty(t.get('node')):
                empty[key] += 1
                if is_empty(t.get('name')):
                    empty_both[key] += 1
    if tv == 0:
        P('COUNT1a term values inspected: 0 -> NOT MEASURED')
    else:
        P('COUNT1a term values inspected: %d (at schema-declared ontology_term slots: %d; '
          'other {node,..} dicts: %d); node empty or absent: %d (of which name also empty: %d)'
          % (tv, declared_n, tv - declared_n, sum(empty.values()), sum(empty_both.values())))
        P('COUNT1a declared slots holding a blank scalar (\'\' or null, no struct): %d; '
          'holding a non-struct value: %d' % (sum(blank_slot.values()), sum(not_struct.values())))
        for k, n in empty.most_common():
            P('COUNT1a   %-78s node-empty %7d  (name also empty %7d) of %7d values'
              % (k, n, empty_both[k], by_slot[k]))
        for k, n in blank_slot.most_common(20):
            P('COUNT1a   blank scalar at %-70s %7d' % (k, n))
        for k, n in not_struct.most_common(20):
            P('COUNT1a   non-struct at %-72s %7d' % (k, n))
    report['term_values_inspected'] = tv
    report['term_values_declared'] = declared_n
    report['values_by_slot'] = dict(by_slot)
    report['blank_slot'] = dict(blank_slot)
    report['not_struct'] = dict(not_struct)
    report['empty_node_by_slot'] = {k: {'empty_node': n, 'name_also_empty': empty_both[k],
                                        'values': by_slot[k]} for k, n in empty.items()}

    # ---- COUNT 1b: statement variables not in the registry
    stmt = 0
    no_slot = collections.Counter()
    var_paths = collections.Counter()
    unreg_empty = collections.Counter()      # node empty: name -> count
    unreg_node = collections.Counter()       # node present, not registered: (node,name)
    unreg_by_class = collections.Counter()
    stmt_by_class = collections.Counter()
    for d in docs:
        c = cname(d)
        if 'statement' not in closure(c, parents, d):
            continue
        stmt += 1
        stmt_by_class[c] += 1
        p, t = find_variable(d)
        if t is None:
            no_slot[c] += 1
            continue
        var_paths[p] += 1
        node, name = t.get('node'), t.get('name')
        if is_empty(node):
            unreg_empty[str(name)] += 1
            unreg_by_class[c] += 1
        elif node not in reg_nodes:
            unreg_node['%s | %s' % (node, name)] += 1
            unreg_by_class[c] += 1
    if stmt == 0:
        P('COUNT1b statements inspected: 0 -> NOT MEASURED')
    else:
        nun = sum(unreg_empty.values()) + sum(unreg_node.values())
        P('COUNT1b statements inspected: %d; variable slot found in %d (paths %s); no slot %d'
          % (stmt, sum(var_paths.values()), dict(var_paths), sum(no_slot.values())))
        P('COUNT1b variable not in registry: %d (node empty: %d; node set but not registered: %d)'
          % (nun, sum(unreg_empty.values()), sum(unreg_node.values())))
        for c, n in stmt_by_class.most_common():
            P('COUNT1b   class %-40s statements %7d  unregistered variable %7d  no variable slot %d'
              % (c, n, unreg_by_class[c], no_slot[c]))
        for k, n in unreg_node.most_common(15):
            P('COUNT1b   top unregistered (node | name): %-60s %7d' % (k, n))
        for k, n in unreg_empty.most_common(15):
            P('COUNT1b   top empty-node variable name: %-50s %7d (name in registry by name: %s)'
              % (repr(k), n, k in reg_names))
    report.update({'statements_inspected': stmt,
                   'statements_by_class': dict(stmt_by_class),
                   'no_variable_slot_by_class': dict(no_slot),
                   'unregistered_by_class': dict(unreg_by_class),
                   'unregistered_node_set': dict(unreg_node),
                   'unregistered_node_empty': dict(unreg_empty)})

    # ---- COUNT 2: v1 base.name on sources that become statements
    so = json.load(open(os.path.join(a.dump, 'source_outputs.json'), encoding='utf-8'))
    if isinstance(so, dict):
        so = [so]
    v1files = json.load(open(os.path.join(a.dump, 'v1_files.json'), encoding='utf-8'))
    if isinstance(v1files, str):
        v1files = [v1files]
    v1dir = a.v1dir or open(os.path.join(a.dump, 'corpus_dir.txt'), encoding='utf-8').read().strip()
    final_cls = {}
    for d in docs:
        i = doc_id(d)
        if i:
            final_cls[i] = cname(d)
    P('COUNT2 v1 sources: %d; v1 files listed: %d; v1 dir %s; final ids %d'
      % (len(so), len(v1files), v1dir, len(final_cls)))
    becomes = 0
    named = collections.Counter()
    den_by_class = collections.Counter()
    ws_only = 0
    examples = collections.defaultdict(list)
    direct_den = collections.Counter()
    direct_named = collections.Counter()
    direct_cls = collections.Counter()
    gone = 0
    carried = 0
    unread = 0
    for row in so:
        outs = row.get('output_ids') or []
        if isinstance(outs, str):
            outs = [outs]
        if row.get('carried'):
            carried += 1
            continue
        present = [final_cls[o] for o in outs if o in final_cls]
        if outs and not present:
            gone += 1
        if not any('statement' in closure(c, parents) for c in present):
            continue
        becomes += 1
        v1c = row.get('class_name') or '<none>'
        den_by_class[v1c] += 1
        # The direct replacement: the final document holding the v1 id
        # ([every v1 id survives]). Is IT a statement, or does the source also
        # become something else (an entity) that holds the id?
        direct = final_cls.get(row.get('id'))
        direct_is_stmt = direct is not None and 'statement' in closure(direct, parents)
        if direct_is_stmt:
            direct_den[v1c] += 1
        direct_cls[(v1c, direct or '<id not held>')] += 1
        k = int(row['input_index']) - 1
        try:
            body = json.load(open(os.path.join(v1dir, v1files[k]), encoding='utf-8'))
        except (OSError, ValueError, IndexError):
            unread += 1
            continue
        nm = (body.get('base') or {}).get('name') if isinstance(body, dict) else None
        if isinstance(nm, list):
            nm = ''.join(str(x) for x in nm)
        if nm is None or nm == '':
            continue
        if isinstance(nm, str) and not nm.strip():
            ws_only += 1
        named[v1c] += 1
        if direct_is_stmt:
            direct_named[v1c] += 1
        if nm not in examples[v1c] and len(examples[v1c]) < 4:
            examples[v1c].append(nm)
    if becomes == 0:
        P('COUNT2 v1 documents that become statements: 0 -> NOT MEASURED')
    else:
        P('COUNT2 v1 documents that become statements: %d (v1 bodies unreadable: %d; '
          'carried-as-v1 sources skipped: %d; sources whose outputs are all gone from the '
          'final batch: %d); base.name not empty: %d (whitespace-only: %d)'
          % (becomes, unread, carried, gone, sum(named.values()), ws_only))
        for c, n in den_by_class.most_common():
            P('COUNT2   v1 class %-40s become statements %7d  base.name non-empty %7d  e.g. %s'
              % (c, n, named[c], json.dumps(examples[c])[:300]))
        P('COUNT2 of these, the v1 id is held by a statement (direct replacement is a '
          'statement): %d; base.name non-empty among them: %d'
          % (sum(direct_den.values()), sum(direct_named.values())))
        for c, n in direct_den.most_common():
            P('COUNT2   direct v1 class %-40s id held by a statement %7d  base.name non-empty %7d'
              % (c, n, direct_named[c]))
        for (c, d), n in sorted(direct_cls.items(), key=lambda x: -x[1]):
            P('COUNT2   v1 class %-30s -> class holding its v1 id: %-30s %7d' % (c, d, n))
    report.update({'v1_sources': len(so), 'v1_become_statements': becomes,
                   'v1_bodies_unreadable': unread, 'outputs_gone': gone,
                   'carried_skipped': carried,
                   'become_statements_by_class': dict(den_by_class),
                   'named_by_class': dict(named), 'examples': dict(examples),
                   'direct_statement_by_class': dict(direct_den),
                   'direct_named_by_class': dict(direct_named),
                   'id_holder_class': {'%s -> %s' % k: v for k, v in direct_cls.items()}})
    if a.json:
        json.dump(report, open(a.json, 'w'), indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main())
