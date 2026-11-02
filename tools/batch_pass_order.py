#!/usr/bin/env python3
"""The order of the whole-dataset passes, DERIVED from what each declares it
reads and writes, and CHECKED against every place that composes them.

THE DECISION. did-schema docs/plans/did_v2_go_forward_class_audit.md, Decided
by Jess Haley, 2026-10-26 [migration reliability practices], practice (c):
"whole-dataset passes (DID-matlab `resolve*` post-passes, NDI-matlab's second
pass) declare what they read and write, and their order is derived and
checked, not kept in comments."

WHAT EACH PASS DECLARES. Four markers, in the same header comment block as
the CONSUMES / EMITS markers tools/batch_pass_declarations.py reads (those
credit the completion ladder; these say what the pass needs and changes, which
is a different question: a document a pass mints by re-running a migrator is
credited to that migrator, but it is still in the batch for the next pass).
Each value is a comma-separated list of ITEMS, or `NONE -- <reason>`:

    <prefix>READS:   what the pass selects from the batch and must see in full
    <prefix>ADDS:    documents it appends to the batch
    <prefix>CHANGES: documents already in the batch that it edits, or prunes
                     some of (a duplicate dropped, an edge cut)
    <prefix>REMOVES: documents it folds away (a source it replaces)

(<prefix> is the BATCH-PASS- prefix; the tokens are assembled below rather
than spelled out, for the reason tools/batch_pass_declarations.py gives.)

An ITEM is a class name (`entity`, `acquisition_epoch`), a class with a
qualifier in parentheses (`entity(dataset)`, `directed_relation(included_in)`)
or a value one pass hands the next outside the batch: a field of the batch
result (`result.deferred_bath_anchors`) or, in NDI-matlab, a variable of
ndi.migrate.local (`ndi.bath_anchors`). A qualifier narrows: `entity(dataset)` and
`entity(epoch)` are different documents, and an unqualified `entity` overlaps
every `entity(...)`. A qualifier is the declaring pass's statement of what it
selects; it is text, and it is matched exactly, so a qualifier that makes two
items disjoint is a claim the declaration's author makes and a reviewer
checks.

What a pass reads only to COUNT (a report instrument that decides nothing) is
not a read here. A pass that folds the documents of a class it can handle and
leaves the rest for a later pass CHANGES that class; REMOVES is for documents
no later pass is meant to read.

THE TWO RULES. For passes P and Q, P earlier in a composition than Q:

    R1  P READS an item Q ADDS or CHANGES  -> P runs too early: it cannot see
        what Q writes. ("A pass that consumes something emitted later.")
    R2  Q READS an item P REMOVES          -> Q runs too late: P has folded
        away what Q reads.

The derived order is the topological order of those constraints over the
members of a composition, ties broken by the composition's own order, so a
composition that breaks no rule derives to itself. A cycle means no order can
satisfy the declarations, and fails.

WHAT IS COMPOSED, read from code, never from a list kept here:
  * DID-matlab: each report-writing call site census_digest names
    (runCorpusDiscovery, testCorpusPRED), its did2.convert.* calls in call
    order, restricted to the derived chain (census_digest.harness_pass_chain);
  * NDI-matlab (with --ndi ROOT, or $NDI_MATLAB): NDI's second pass in
    +ndi/+migrate/local.m, step by step. A step is the code between two
    `migrateStepMark('<label>', ...)` calls; the steps are those after the one
    that calls did2.convert.v1_to_v2 (pass 1) and before the one that calls
    ndi.migrate.internal.carryUnchangedAsV1 (the final v1 stamp, which
    local.m runs "after pass 1, the DID batch passes and the second pass").
    A step that calls a DID-matlab pass, directly or through one local
    function of local.m, uses that pass's declaration; any other step
    declares itself in a comment block inside the step. A step with no
    declaration FAILS.

DENOMINATOR FIRST: every report prints how many passes it read, how many
declare all four markers, how many compositions it checked and how many
ordered pairs it compared, before any verdict.

Exit status: 0 when every member of every composition is declared, every
declaration parses, no composition breaks R1 or R2 and no cycle exists;
1 otherwise.
"""

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import batch_pass_declarations as bpd  # noqa: E402
import census_digest  # noqa: E402

_PREFIX = "BATCH-PASS-"
EFFECTS = ("READS", "ADDS", "CHANGES", "REMOVES")
TOKENS = {e: _PREFIX + e for e in EFFECTS}

_EFFECT_MARKER = re.compile(
    r"^%\s*" + re.escape(_PREFIX) + r"(" + "|".join(EFFECTS) + r")\s*:\s*(.*)$")
_COMMENT = re.compile(r"^%\s?(.*)$")
_ITEM = re.compile(
    r"^(?:(?:result|ndi)\.[a-z_][a-z0-9_]*"
    r"|[A-Za-z_]\w*(?:\s*\(\s*[^(),]+?\s*\))?)$")

NDI_LOCAL = os.path.join("src", "ndi", "+ndi", "+migrate", "local.m")
_STEP_MARK = re.compile(r"migrateStepMark\(\s*'([^']*)'")


# ---------------------------------------------------------------- items ----

def parse_item(text):
    """'entity(dataset)' -> ('entity', 'dataset'); 'epoch' -> ('epoch', None)."""
    t = text.strip()
    m = re.match(r"^([A-Za-z_][\w.]*)\s*(?:\(\s*(.*?)\s*\))?$", t)
    if not m:
        return None
    return (m.group(1), m.group(2) or None)


def overlaps(a, b):
    """Two items name overlapping documents: the same class, and either is
    unqualified or both carry the same qualifier."""
    if a[0] != b[0]:
        return False
    return a[1] is None or b[1] is None or a[1] == b[1]


def show(item):
    return item[0] if item[1] is None else "%s(%s)" % item


# ---------------------------------------------------------- declarations ---

def effect_values(lines):
    """{effect: [value, ...]} from comment LINES, joining indented
    continuation lines; a blank comment line or a divider closes a value."""
    out = {e: [] for e in EFFECTS}
    cur = None
    for raw in lines:
        s = raw.strip()
        m = _EFFECT_MARKER.match(s)
        if m:
            cur = (m.group(1), len(out[m.group(1)]))
            out[m.group(1)].append(m.group(2).strip())
            continue
        if cur is None:
            continue
        body = _COMMENT.match(s)
        body = body.group(1).rstrip() if body else None
        if body is None or not body.strip() or set(body.strip()) <= {"-"} \
                or not body.startswith(" ") or "BATCH-PASS" in body:
            cur = None
            continue
        eff, idx = cur
        out[eff][idx] = (out[eff][idx] + " " + body.strip()).strip()
    return out


def parse_effects(lines):
    """Parse the four markers from comment LINES.

    Returns {declared, reads, adds, changes, removes, none_reasons, errors};
    each effect a list of (class, qualifier) items. `declared` is True when
    any of the four markers is present (so a half-written declaration is
    reported as invalid, not as absent).
    """
    vals = effect_values(lines)
    d = {"declared": any(vals[e] for e in EFFECTS), "none_reasons": {},
         "errors": []}
    for e in EFFECTS:
        d[e.lower()] = []
        if not vals[e]:
            d["errors"].append("no %s: line" % TOKENS[e])
            continue
        if len(vals[e]) > 1:
            d["errors"].append("%s: given %d times" % (TOKENS[e], len(vals[e])))
        v = vals[e][0]
        if v.startswith("NONE"):
            reason = v[4:].lstrip(" -").strip()
            if not reason:
                d["errors"].append("%s: NONE carries no reason" % TOKENS[e])
            d["none_reasons"][e.lower()] = reason
            continue
        parts = [p.strip() for p in v.split(",") if p.strip()]
        if not parts:
            d["errors"].append("%s: names nothing and is not NONE" % TOKENS[e])
        for p in parts:
            item = parse_item(p) if _ITEM.match(p) else None
            if item is None:
                d["errors"].append("%s: `%s` is not an item" % (TOKENS[e], p))
            elif item in d[e.lower()]:
                d["errors"].append("%s: `%s` is listed twice" % (TOKENS[e], p))
            else:
                d[e.lower()].append(item)
    return d


def did_pass_effects(root, fn):
    path = os.path.join(root, bpd.CONVERT_PKG, fn + ".m")
    text = bpd._read_text(path)
    if text is None:
        return {"declared": False, "errors": ["source not readable: " + path],
                "reads": [], "adds": [], "changes": [], "removes": [],
                "none_reasons": {}}
    d = parse_effects(bpd.header_lines(text))
    # A class the pass CONSUMES (the ladder's declaration) is one it reads,
    # unless that declaration says it emits nothing for it (a crediting note,
    # e.g. a source the pass only stamps and hands to a migrator).
    dec = bpd.parse_declaration(text)
    for c in dec.get("consumes", []):
        e = dec.get("emits", {}).get(c)
        if e is not None and e["form"] == "nothing":
            continue
        # read as itself, or in its migrated form qualified by its v1 name
        # (`entity(element)` is a v1 `element` after pass 1)
        if d["declared"] and not any(overlaps((c, None), r) or r[1] == c
                                     for r in d["reads"]):
            d["errors"].append(
                "consumes `%s` (its CONSUMES line) but does not list it in %s"
                % (c, TOKENS["READS"]))
    return d


# ---------------------------------------------------------- compositions ---

def did_compositions(root):
    """[(label, [fn, ...])] from the DID-matlab report-writing call sites,
    restricted to the derived chain; and the chain info."""
    info = census_digest.harness_pass_chain(root, _cache=False)
    chain = set(info.get("chain") or [])
    comps = []
    for s in info.get("sites", []):
        if s.get("exists"):
            comps.append(("DID-matlab " + s["label"],
                          [fn for fn in s["chain"] if fn in chain]))
    return comps, info


def _main_function_code(text):
    """The first function of a MATLAB file (up to the next top-level
    `function` line), comments KEPT, line structure kept."""
    lines = text.splitlines()
    out = []
    for i, line in enumerate(lines):
        if i > 0 and re.match(r"^function\b", line):
            break
        out.append(line)
    return out


def ndi_steps(ndi_root, chain):
    """NDI's second pass, step by step, from +ndi/+migrate/local.m.

    Returns (steps, info): steps a list of {label, did_pass, effects, calls};
    info the denominator and anything that could not be read.
    """
    path = os.path.join(ndi_root, NDI_LOCAL)
    info = {"path": path, "exists": os.path.isfile(path), "steps_marked": 0,
            "pass_one_found": False, "record_found": False}
    funcs = {}
    text = bpd._read_text(path)
    if text is None:
        return [], info
    lines = _main_function_code(text)
    # local functions of local.m, by name -> their code (comments stripped)
    for m in re.finditer(r"^function\s+(?:\[[^\]]*\]\s*=\s*|\w+\s*=\s*)?"
                         r"(\w+)\s*\(", text, re.M):
        nxt = re.search(r"^function\b", text[m.end():], re.M)
        body = text[m.start(): m.end() + (nxt.start() if nxt else len(text))]
        funcs[m.group(1)] = bpd._code_of(body)
    marks = [i for i, l in enumerate(lines)
             if _STEP_MARK.search(bpd._decomment(l))]
    info["steps_marked"] = len(marks)
    segs, start = [], 0
    for i in marks:
        label = _STEP_MARK.search(lines[i]).group(1)
        segs.append((label, lines[start:i + 1]))
        start = i + 1
    first = last = None
    for k, (label, seg) in enumerate(segs):
        code = bpd._code_of("\n".join(seg))
        if first is None and re.search(r"did2\.convert\.v1_to_v2\s*\(", code):
            first = k
        if last is None and re.search(
                r"ndi\.migrate\.internal\.carryUnchangedAsV1\s*\(", code):
            last = k
    info["pass_one_found"] = first is not None
    info["record_found"] = last is not None
    if first is None or last is None:
        return [], info
    steps = []
    for label, seg in segs[first + 1:last]:
        code = bpd._code_of("\n".join(seg))
        called = [m.group(1) for m in
                  re.finditer(r"did2\.convert\.([A-Za-z_]\w*)\s*\(", code)]
        did = [c for c in called if c in chain]
        if not did:
            # one level through a local wrapper of local.m
            for f in dict.fromkeys(re.findall(r"(?<![\w.])(\w+)\s*\(", code)):
                if f in funcs and f != "local":
                    did += [m.group(1) for m in re.finditer(
                        r"did2\.convert\.([A-Za-z_]\w*)\s*\(", funcs[f])
                        if m.group(1) in chain]
        comments = [l.strip() for l in seg if l.strip().startswith("%")]
        local = parse_effects(comments)
        step = {"label": label, "did_pass": did[0] if did else None,
                "local": local}
        if len(did) > 1:
            local["errors"].append("calls %d DID-matlab passes in one step: %s"
                                   % (len(did), ", ".join(did)))
        if did and local["declared"]:
            local["errors"].append(
                "calls did2.convert.%s and also declares itself; the pass's "
                "own declaration is the one that counts" % did[0])
        steps.append(step)
    return steps, info


# ----------------------------------------------------------------- check ---

def conflicts(p, q):
    """Why P may not run before Q, as a list of strings (empty: it may)."""
    out = []
    for r in p["reads"]:
        for w in q["adds"] + q["changes"]:
            if overlaps(r, w):
                out.append("R1: the earlier pass reads %s and the later "
                           "pass writes %s" % (show(r), show(w)))
    for r in q["reads"]:
        for x in p["removes"]:
            if overlaps(r, x):
                out.append("R2: the earlier pass removes %s and the later "
                           "pass reads %s" % (show(x), show(r)))
    return out


def constraints(names, effects):
    """[(first, then, reason)]: every pair of NAMES whose declarations fix
    their order, with the rule that fixes it."""
    out = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            for why in conflicts(effects[a], effects[b]):
                out.append((b, a, "%s before %s (the other way round, %s)"
                            % (b, a, why)))
            for why in conflicts(effects[b], effects[a]):
                out.append((a, b, "%s before %s (the other way round, %s)"
                            % (a, b, why)))
    return out


def derive(names, effects):
    """The order the declarations require over NAMES (a composition), ties
    broken by NAMES' own order. Returns (order, cycle): cycle a list of the
    names left when no remaining pass is free to run, else []."""
    must_precede = {n: set() for n in names}   # n must precede these
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if a == b:
                continue
            # a constraint in either direction, from the declarations alone:
            # A may not run before B, so B must precede A; and the converse
            if conflicts(effects[a], effects[b]):
                must_precede[b].add(a)
            if conflicts(effects[b], effects[a]):
                must_precede[a].add(b)
    indeg = {n: 0 for n in names}
    for a in names:
        for b in must_precede[a]:
            indeg[b] += 1
    order, left = [], list(names)
    while left:
        free = [n for n in left if indeg[n] == 0]
        if not free:
            return order, left
        n = free[0]
        order.append(n)
        left.remove(n)
        for b in must_precede[n]:
            indeg[b] -= 1
    return order, []


def check(root=None, ndi_root=None):
    root = root or REPO_ROOT
    out = {"root": root, "ndi_root": ndi_root, "passes": {}, "compositions": [],
           "errors": [], "pairs_compared": 0}
    comps, info = did_compositions(root)
    out["chain_derived"] = bool(info.get("derived"))
    chain = list(info.get("chain") or [])
    out["chain"] = chain
    if not out["chain_derived"]:
        out["errors"].append("the DID-matlab batch-pass chain could not be "
                             "derived from the harness; nothing was checked")
        return out
    for fn in chain:
        out["passes"]["did2.convert." + fn] = did_pass_effects(root, fn)

    ndi_info = None
    if ndi_root:
        steps, ndi_info = ndi_steps(ndi_root, set(chain))
        out["ndi"] = ndi_info
        if not ndi_info["exists"]:
            out["errors"].append("NDI-matlab: %s is not there" % ndi_info["path"])
        elif not (ndi_info["pass_one_found"] and ndi_info["record_found"]):
            out["errors"].append(
                "NDI-matlab: the second pass could not be found in %s (pass 1 "
                "step found: %s; final v1 stamp step found: %s)"
                % (ndi_info["path"], ndi_info["pass_one_found"],
                   ndi_info["record_found"]))
        names = []
        for s in steps:
            if s["did_pass"]:
                names.append("did2.convert." + s["did_pass"])
            else:
                name = "NDI step '%s'" % s["label"]
                out["passes"][name] = s["local"]
                names.append(name)
        ndi_info["second_pass_steps"] = len(steps)
        comps.append(("NDI-matlab second pass", names))
    else:
        comps = [(label, ["did2.convert." + fn for fn in names])
                 for label, names in comps]
    if ndi_root:
        comps = [(label, ["did2.convert." + fn for fn in names])
                 if label.startswith("DID-matlab") else (label, names)
                 for label, names in comps]

    for name, d in out["passes"].items():
        if not d["declared"]:
            out["errors"].append("%s: NO DECLARATION (%s)"
                                 % (name, "; ".join(d["errors"])))
        elif d["errors"]:
            out["errors"].append("%s: INVALID: %s"
                                 % (name, "; ".join(d["errors"])))
    bad = {n for n, d in out["passes"].items()
           if not d["declared"] or d["errors"]}

    for label, names in comps:
        c = {"label": label, "order": names, "violations": [], "derived": [],
             "cycle": [], "skipped_undeclared": sorted(set(names) & bad)}
        usable = [n for n in names if n not in bad]
        eff = {n: out["passes"][n] for n in usable}
        for i, a in enumerate(usable):
            for b in usable[i + 1:]:
                out["pairs_compared"] += 1
                for why in conflicts(eff[a], eff[b]):
                    c["violations"].append("%s runs before %s: %s"
                                           % (a, b, why))
        c["derived"], c["cycle"] = derive(usable, eff)
        c["constraints"] = constraints(usable, eff)
        if c["violations"]:
            out["errors"].append("%s: %d order violation(s)"
                                 % (label, len(c["violations"])))
        if c["cycle"]:
            out["errors"].append("%s: no order satisfies the declarations; "
                                 "a cycle among %s" % (label, ", ".join(c["cycle"])))
        out["compositions"].append(c)
    return out


def render(out, stream=sys.stdout):
    p = lambda *a: print(*a, file=stream)
    declared = sum(1 for d in out["passes"].values()
                   if d["declared"] and not d["errors"])
    p("WHOLE-DATASET PASS ORDER (derived from declarations, checked)")
    p("DENOMINATOR: %d pass(es) read (%d DID-matlab chain member(s)%s), %d "
      "with a valid declaration; %d composition(s) checked; %d ordered "
      "pair(s) compared"
      % (len(out["passes"]), len(out.get("chain", [])),
         (", NDI second pass: %d step(s) of %d marked in %s"
          % (out["ndi"].get("second_pass_steps", 0), out["ndi"]["steps_marked"],
             out["ndi"]["path"])) if out.get("ndi") else
         ", NDI-matlab NOT CHECKED: no --ndi / $NDI_MATLAB",
         declared, len(out["compositions"]), out["pairs_compared"]))
    for c in out["compositions"]:
        p("")
        p("%s: %d member(s)%s" % (c["label"], len(c["order"]),
          "; NOT CHECKED (undeclared or invalid): " + ", ".join(c["skipped_undeclared"])
          if c["skipped_undeclared"] else ""))
        if c["cycle"]:
            p("  *** NO ORDER: a cycle among %s" % ", ".join(c["cycle"]))
        else:
            same = [n for n in c["order"] if n in c["derived"]] == c["derived"]
            p("  derived order %s the composed order:"
              % ("EQUALS" if same else "DIFFERS FROM"))
            for i, n in enumerate(c["derived"], 1):
                p("    %2d. %s" % (i, n))
        pairs = sorted({(a, b) for a, b, _ in c["constraints"]})
        p("  %d ordered pair(s) the declarations fix:" % len(pairs))
        for a, b in pairs:
            p("    %s  before  %s" % (a, b))
        for v in c["violations"]:
            p("  *** VIOLATION: " + v)
    p("")
    if out["errors"]:
        p("FAIL: %d problem(s)" % len(out["errors"]))
        for e in out["errors"]:
            p("  " + e)
    else:
        p("OK: every composition is in an order its declarations allow")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=None)
    ap.add_argument("--ndi", default=os.environ.get("NDI_MATLAB") or None,
                    help="an NDI-matlab checkout (default $NDI_MATLAB)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    out = check(args.root, args.ndi)
    if args.json:
        json.dump(out, sys.stdout, indent=1, sort_keys=True, default=list)
        print()
    else:
        render(out)
    return 1 if out["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
