#!/usr/bin/env python3
"""What each batch post-pass CONSUMES and EMITS, read off a declaration it carries.

WHY A DECLARATION AND NOT A DERIVATION
--------------------------------------
DID-schema `V_eta_OPEN_WORK.md` row 107: the completion ladder answers "does
this class have a migrator" and "does that migrator emit the decided target" by
looking at the migrator NAMED AFTER the class. Three legitimate emission shapes
are invisible to that question, and a batch post-pass is one of them --
`generic_file` is folded by `foldGenericFiles` and read as stage 0, unconsumed.

The repair is a DECLARATION, for the reason `_EDGE_REFERENT_UNIQUE` is declared
by name in DID-schema `tools/build_v_eta.py` rather than derived: a derivation
drops a member silently the day someone renames a class. Here the derivation is
worse than silent, it is impossible -- and that is provable in one command:

    $ grep -lE "\\bbase\\b" src/did/+did2/+convert/*.m | wc -l

matches nearly the whole package, because `base`, `app` and `session` are
ordinary words in ordinary code as well as class names. A name sweep over these
files cannot separate "this pass folds `app` documents" from "this pass has a
variable called app". So the passes say what they do, and this file reads it.

THE GRAMMAR
-----------
Two markers, each a header comment line of TOKEN, colon, value. The idiom is
the package's own: `tools/test_batch_pass_wiring.py` already exempts a pass on
a header line of a token, a colon and a reason. Continuation lines are indented
comment lines that do not start a new marker.

    BATCH-PASS-CONSUMES: <class>[, <class>...]
    BATCH-PASS-CONSUMES: NONE -- <reason>

    BATCH-PASS-EMITS: <source> -> <form>: <rhs>
    BATCH-PASS-EMITS: NONE -- <reason>

        <source>  a class named in CONSUMES, or the literal UNATTRIBUTED for an
                  emission no single consumed class owns.
        <form>    document  a minted document of each class in <rhs>
                  inline    a FIELD BLOCK written onto another document, named
                            by the class in <rhs>. Shape (3) of row 107; the
                            block's class may exist in the built set without a
                            document of it ever being minted.
                  nothing   nothing is emitted for <source>. <rhs> is then a
                            REASON, not a class list.

FOUR RULES, EACH OF WHICH A REAL PASS WOULD OTHERWISE HAVE BROKEN QUIETLY
-------------------------------------------------------------------------
1. A PASS WITH NO DECLARATION IS AN ERROR, NEVER AN EMPTY SET. This is the
   whole point. `silentLoss` printed "0 empty edges" while reading nothing for
   two days; a pass that declares nothing must not read as a pass that consumes
   nothing. Missing markers are reported under their own heading and make this
   tool exit non-zero.
2. EMPTINESS MUST BE STATED, WITH A REASON. `resolveDatasetEntities` genuinely
   consumes no did_v1 class, and says so in the `NONE -- <reason>` form. That
   sentence is checkable; an absent marker is not.
3. EVERY CONSUMED CLASS NEEDS AN EMITS LINE. Otherwise a declaration can be
   half-written -- three classes consumed, one accounted for -- and the two
   unaccounted ones look like classes that emit nothing.
4. AN EMITS SOURCE MUST BE CONSUMED. A pass cannot emit for a class it never
   said it reads; that is how a typo becomes a credited rung.

WHAT THIS FILE DOES NOT DO. It does not decide which passes exist. The chain is
DERIVED by `census_digest.harness_pass_chain()`, which reads what the corpus
harness actually composes -- a hand-kept list here would go stale the first time
a pass was added, which is exactly the failure mode being repaired.

DENOMINATOR: every report below prints the size of the chain it read and how
many of those passes carried a declaration, first and unconditionally.
"""

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)
CONVERT_PKG = os.path.join("src", "did", "+did2", "+convert")

# The tokens are assembled rather than written out, for the reason
# test_batch_pass_wiring.py gives about WIRING-EXEMPT: a docstring or a test
# that spells a marker verbatim becomes a declaration the moment anyone copies
# this file's text into a .m header, and a gate that can disarm itself in its
# own documentation is this project's recurring failure in miniature.
_PREFIX = "BATCH-PASS-"
CONSUMES_TOKEN = _PREFIX + "CONSUMES"
EMITS_TOKEN = _PREFIX + "EMITS"

FORMS = ("document", "inline", "nothing")

_MARKER = re.compile(
    r"^%\s*(" + re.escape(CONSUMES_TOKEN) + "|" + re.escape(EMITS_TOKEN)
    + r")\s*:\s*(.*)$")
_COMMENT = re.compile(r"^%\s?(.*)$")
_NAME = re.compile(r"^[A-Za-z_]\w*$")


def _read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


def header_lines(text):
    """The LEADING comment block of a MATLAB file, after the function line.

    A declaration must live in the header, where the next reader sees it. The
    block ends at the first line that is neither a comment nor blank -- so a
    marker in a mid-file comment is NOT a declaration and is reported as
    missing rather than picked up by accident.
    """
    out, started = [], False
    for line in text.splitlines():
        s = line.strip()
        if not started:
            if s.startswith("function"):
                started = True
            continue
        if s.startswith("%"):
            out.append(s)
        elif s == "":
            # A blank line inside these headers is rare but not fatal; a blank
            # line AFTER the header is followed by code, which ends the block
            # on the next iteration anyway.
            continue
        else:
            break
    return out


def marker_values(lines):
    """{token: [value, ...]} for the two markers, joining continuation lines.

    A continuation is any following comment line that does not itself start a
    marker and is not a divider rule. Joined with a single space so a value may
    wrap without the parser caring where.
    """
    out = {CONSUMES_TOKEN: [], EMITS_TOKEN: []}
    cur = None
    for raw in lines:
        m = _MARKER.match(raw)
        if m:
            cur = (m.group(1), len(out[m.group(1)]))
            out[m.group(1)].append(m.group(2).strip())
            continue
        if cur is None:
            continue
        body = _COMMENT.match(raw)
        body = body.group(1).rstrip() if body else ""
        if not body.strip() or set(body.strip()) <= {"-"}:
            cur = None            # blank or a divider rule closes the value
            continue
        if not raw.startswith("%") or not body.startswith(" "):
            cur = None            # an unindented comment is new prose
            continue
        tok, idx = cur
        out[tok][idx] = (out[tok][idx] + " " + body.strip()).strip()
    return out


def _split_list(s):
    return [p.strip() for p in s.split(",") if p.strip()]


def parse_declaration(text):
    """Parse one pass's source. Returns a dict; `errors` empty means valid.

    Keys: declared (both markers present), consumes, consumes_none_reason,
    emits {source: {form, targets, reason}}, unattributed, errors.
    """
    d = {"declared": False, "consumes": [], "consumes_none_reason": None,
         "emits": {}, "unattributed": [], "errors": []}
    vals = marker_values(header_lines(text))
    cons, emits = vals[CONSUMES_TOKEN], vals[EMITS_TOKEN]

    if not cons:
        d["errors"].append("no %s: line in the header" % CONSUMES_TOKEN)
    if not emits:
        d["errors"].append("no %s: line in the header" % EMITS_TOKEN)
    if d["errors"]:
        return d
    d["declared"] = True

    for v in cons:
        if v.startswith("NONE"):
            reason = v[4:].lstrip(" -").strip()
            if not reason:
                d["errors"].append("%s: NONE carries no reason" % CONSUMES_TOKEN)
            d["consumes_none_reason"] = reason
            continue
        names = _split_list(v)
        if not names:
            d["errors"].append("%s: names nothing and is not NONE"
                               % CONSUMES_TOKEN)
        for n in names:
            if not _NAME.match(n):
                d["errors"].append("%s: `%s` is not a class name"
                                   % (CONSUMES_TOKEN, n))
            elif n not in d["consumes"]:
                d["consumes"].append(n)
    if d["consumes"] and d["consumes_none_reason"] is not None:
        d["errors"].append("%s: says NONE and also names classes"
                           % CONSUMES_TOKEN)

    emits_none = False
    for v in emits:
        if v.startswith("NONE"):
            reason = v[4:].lstrip(" -").strip()
            if not reason:
                d["errors"].append("%s: NONE carries no reason" % EMITS_TOKEN)
            emits_none = True
            continue
        if "->" not in v:
            d["errors"].append("%s: `%s` has no `->`" % (EMITS_TOKEN, v[:60]))
            continue
        src, rest = v.split("->", 1)
        src, rest = src.strip(), rest.strip()
        if ":" not in rest:
            d["errors"].append("%s: `%s` names no form (%s)"
                               % (EMITS_TOKEN, src, "/".join(FORMS)))
            continue
        form, rhs = rest.split(":", 1)
        form, rhs = form.strip(), rhs.strip()
        if form not in FORMS:
            d["errors"].append("%s: `%s` has form `%s`, not one of %s"
                               % (EMITS_TOKEN, src, form, "/".join(FORMS)))
            continue
        if src != "UNATTRIBUTED" and src not in d["consumes"]:
            d["errors"].append(
                "%s: `%s` is not in %s" % (EMITS_TOKEN, src, CONSUMES_TOKEN))
            continue
        if form == "nothing":
            if not rhs:
                d["errors"].append("%s: `%s -> nothing` carries no reason"
                                   % (EMITS_TOKEN, src))
            entry = {"form": form, "targets": [], "reason": rhs}
        else:
            targets = _split_list(rhs)
            bad = [t for t in targets if not _NAME.match(t)]
            if not targets:
                d["errors"].append("%s: `%s -> %s` names no class"
                                   % (EMITS_TOKEN, src, form))
            for t in bad:
                d["errors"].append("%s: `%s` is not a class name"
                                   % (EMITS_TOKEN, t))
            entry = {"form": form,
                     "targets": [t for t in targets if _NAME.match(t)],
                     "reason": None}
        if src == "UNATTRIBUTED":
            d["unattributed"].append(entry)
        elif src in d["emits"]:
            d["errors"].append("%s: `%s` is declared twice" % (EMITS_TOKEN, src))
        else:
            d["emits"][src] = entry

    if emits_none and (d["emits"] or d["unattributed"]):
        d["errors"].append("%s: says NONE and also declares an emission"
                           % EMITS_TOKEN)
    if d["consumes_none_reason"] is not None and not emits_none:
        d["errors"].append(
            "%s is NONE, so %s must be NONE too" % (CONSUMES_TOKEN, EMITS_TOKEN))
    for c in d["consumes"]:
        if c not in d["emits"]:
            d["errors"].append(
                "`%s` is consumed and no %s line says what becomes of it"
                % (c, EMITS_TOKEN))
    return d


# ============================================================================
# THE SHARED HELPER -- the FOURTH consumption channel, and the smallest one.
# ============================================================================
#
# THE ROW THIS REPAIRS. DID-schema's ladder scored `app` at rung 3 = `no`,
# "the decided target `software` is not among what the migrator emits today
# (nothing)". It is emitted, at six live call sites, by
# `+migrators_j/private/jSoftwareFromApp.m` -- which is named after neither the
# source class nor the target, so the ladder's three existing channels (a
# migrator NAMED AFTER the class, a batch post-pass, an `emitted_by`
# cross-reference) all miss it. Tell (1) of the four the open-list
# reconciliation recorded: work landed under a different name.
#
# WHY THE SAME GRAMMAR AND NOT A NEW ONE. A helper's fold is the same statement
# a pass makes -- "I read class C, and C becomes T" -- so it reuses
# CONSUMES/EMITS verbatim and `parse_declaration` is not touched. The file's
# own design note is the reason: ONE grammar, one place it can drift from. A
# second grammar for the same sentence is how the two halves of a file come to
# disagree.
#
# WHY THE DECLARATION SITS ON THE FOLD AND NOT ON THE MINT. `jSoftwareFromApp`
# carries no `'class_name','software'` literal at all; it calls `jSoftware`,
# which does. A rule of "the file with the literal declares" would put the
# sentence on a helper that has never heard of `app` and cannot say what
# becomes of it. The declaration belongs to whoever owns the FOLD.
#
# AND WHY THIS IS NOT ARMED. `scan()` errors on an undeclared pass, and can,
# because the chain is DERIVED so the denominator is known and every member of
# it was declared before the gate went on. There is no equivalent derivation
# here: nothing distinguishes "a helper that owes a declaration" from "a helper
# that folds nothing" without reading intent. So a helper declaration is
# VOLUNTARY, an undeclared helper credits NOTHING, and the report prints both
# counts -- which keeps rule 1's substance (a missing declaration can only
# leave a rung where it was, never make one look better) without arming a gate
# nobody has measured. `helpers_minting_undeclared` names the ones most likely
# to owe one, so "nobody looked" stays visible instead of reading as zero.
HELPER_DIRS = (
    os.path.join("+migrators_j", "private"),
    os.path.join("+migrators_j", "+super"),
    "+entities",
)

_STRONG_MINT = (
    re.compile(r"['\"]class_name['\"]\s*,\s*['\"]([A-Za-z_]\w*)['\"]"),
    re.compile(r"classBlock\s*\(\s*['\"]([A-Za-z_]\w*)['\"]"),
)


def _decomment(line):
    """Drop a MATLAB trailing comment, keep code. A `%` with an even number of
    single quotes before it opens a comment."""
    out, quotes = [], 0
    for ch in line:
        if ch == "'":
            quotes += 1
        elif ch == "%" and quotes % 2 == 0:
            break
        out.append(ch)
    return "".join(out)


def minted_classes(text):
    """Classes this file MINTS, read from code with comments stripped.

    Reported per helper so `helpers_minting_undeclared` can name the files
    whose folds are unmeasured. It is NOT used to credit anything: a mint site
    says a class is constructed here, never which v1 source reached it, and
    reading it as an emission for some source is the guess this whole module
    exists to avoid.
    """
    found = set()
    for raw in text.splitlines():
        code = _decomment(raw)
        for rx in _STRONG_MINT:
            for m in rx.finditer(code):
                found.add(m.group(1))
    return sorted(found)


def scan_helpers(root=None):
    """Shared helpers, with their declaration or its absence.

    Denominator FIRST, and it is TWO numbers, because they answer different
    questions: `candidates` is every helper file (the population a declaration
    could ever come from) and `minting` is the subset that constructs a
    document (the population most likely to owe one). A single count would
    make an undeclared minter indistinguishable from a helper that folds
    nothing.
    """
    root = root or REPO_ROOT
    out = {"root": root, "dirs": [], "candidates": 0, "helpers": {},
           "declared": [], "undeclared": [], "invalid": [],
           "minting": [], "helpers_minting_undeclared": [], "why": None}

    for rel in HELPER_DIRS:
        d = os.path.join(root, CONVERT_PKG, rel)
        out["dirs"].append({"path": rel, "exists": os.path.isdir(d)})
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".m") or name == "Contents.m":
                continue
            fn = name[:-2]
            out["candidates"] += 1
            text = _read_text(os.path.join(d, name))
            if text is None:
                out["helpers"][fn] = {
                    "declared": False, "consumes": [], "emits": {},
                    "unattributed": [], "consumes_none_reason": None,
                    "mints": [], "path": os.path.join(rel, name),
                    "errors": ["source not readable"]}
                out["undeclared"].append(fn)
                continue
            mints = minted_classes(text)
            if mints:
                out["minting"].append(fn)
            has_marker = (CONSUMES_TOKEN in text) or (EMITS_TOKEN in text)
            if not has_marker:
                out["helpers"][fn] = {
                    "declared": False, "consumes": [], "emits": {},
                    "unattributed": [], "consumes_none_reason": None,
                    "mints": mints, "path": os.path.join(rel, name),
                    "errors": []}
                out["undeclared"].append(fn)
                if mints:
                    out["helpers_minting_undeclared"].append(fn)
                continue
            dec = parse_declaration(text)
            dec["mints"] = mints
            dec["path"] = os.path.join(rel, name)
            out["helpers"][fn] = dec
            if dec["declared"]:
                out["declared"].append(fn)
                if dec["errors"]:
                    out["invalid"].append(fn)
            else:
                # A file carrying ONE marker is a HALF-WRITTEN declaration, not
                # an absent one, and it is the dangerous shape: CONSUMES alone
                # names a class with nothing said about what becomes of it. It
                # is INVALID, so the gate fails, rather than undeclared, which
                # would pass silently.
                out["invalid"].append(fn)
    return out


def helper_index(out):
    """{v1_class: [{helper, form, targets, reason}, ...]} over VALID
    declarations only. An invalid declaration credits nothing -- a typo must
    not become a credited rung, which is rule 4 of the grammar."""
    idx = {}
    for fn in sorted(out.get("declared", [])):
        dec = out["helpers"][fn]
        if dec.get("errors"):
            continue
        for src, e in sorted(dec["emits"].items()):
            idx.setdefault(src, []).append(
                {"helper": fn, "form": e["form"], "targets": list(e["targets"]),
                 "reason": e["reason"]})
    return idx


def render_helpers(out, stream=sys.stdout):
    p = lambda *a: print(*a, file=stream)
    p("SHARED HELPER DECLARATIONS   (voluntary; an undeclared helper credits "
      "nothing)")
    p("DENOMINATOR: %d helper .m file(s) across %d dir(s), %d of them MINTING; "
      "%d declared, %d undeclared, %d declared-but-INVALID"
      % (out["candidates"], len(out["dirs"]), len(out["minting"]),
         len(out["declared"]), len(out["undeclared"]), len(out["invalid"])))
    for d in out["dirs"]:
        if not d["exists"]:
            p("  *** DIRECTORY ABSENT: %s" % d["path"])
    for fn in out["declared"]:
        dec = out["helpers"][fn]
        if dec["consumes_none_reason"] is not None:
            p("  %-26s consumes NONE -- %s" % (fn, dec["consumes_none_reason"]))
        else:
            p("  %-26s consumes %s" % (fn, ", ".join(dec["consumes"])))
        for src, e in sorted(dec["emits"].items()):
            if e["form"] == "nothing":
                p("  %-26s   %s -> nothing: %s" % ("", src, e["reason"]))
            else:
                p("  %-26s   %s -> %s: %s"
                  % ("", src, e["form"], ", ".join(e["targets"])))
        for err in dec["errors"]:
            p("  %-26s   *** INVALID: %s" % ("", err))
    for fn in out["invalid"]:
        if fn not in out["declared"]:
            p("  %-26s *** HALF-WRITTEN: one marker present, the other absent"
              % fn)
    p("  UNMEASURED -- %d helper(s) mint a document and declare nothing, so "
      "what they fold is not credited anywhere:" % len(out["helpers_minting_undeclared"]))
    for fn in out["helpers_minting_undeclared"]:
        p("      %-24s mints %s"
          % (fn, ", ".join(out["helpers"][fn]["mints"])))


def scan(root=None):
    """Every pass in the DERIVED chain, with its declaration or its absence.

    Returns a dict carrying the denominator FIRST -- `chain_size`, `declared`,
    `missing` -- because "no declarations found" and "no passes found" are
    different facts and a caller cannot tell them apart from a bare list.
    """
    root = root or REPO_ROOT
    out = {"root": root, "chain_derived": False, "chain": [], "chain_size": 0,
           "passes": {}, "declared": [], "missing": [], "invalid": [],
           "why": None}

    sys.path.insert(0, HERE)
    try:
        import census_digest
    except Exception as exc:                                # pragma: no cover
        out["why"] = "census_digest is not importable: %s" % exc
        return out
    finally:
        if sys.path and sys.path[0] == HERE:
            sys.path.pop(0)

    info = census_digest.harness_pass_chain(root)
    out["chain_derived"] = bool(info.get("derived"))
    out["chain"] = list(info.get("chain") or [])
    out["chain_size"] = len(out["chain"])
    out["chain_info"] = {
        "package": info.get("package", {}).get("path"),
        "package_files": info.get("package", {}).get("files"),
        "sites": [{"label": s["label"], "exists": s["exists"],
                   "lines": s["lines"], "composes": len(s["chain"])}
                  for s in info.get("sites", [])],
        "called_not_a_pass": info.get("called_not_a_pass", []),
        "unwired": info.get("unwired", []),
    }
    if not out["chain_derived"]:
        out["why"] = ("the batch-pass chain could not be DERIVED from the "
                      "harness; refusing to fall back to a hand-kept list")
        return out

    for fn in out["chain"]:
        path = os.path.join(root, CONVERT_PKG, fn + ".m")
        text = _read_text(path)
        if text is None:
            d = {"declared": False, "consumes": [], "consumes_none_reason": None,
                 "emits": {}, "unattributed": [],
                 "errors": ["source not readable at " + path]}
        else:
            d = parse_declaration(text)
        d["path"] = path
        out["passes"][fn] = d
        if not d["declared"]:
            out["missing"].append(fn)
        else:
            out["declared"].append(fn)
            if d["errors"]:
                out["invalid"].append(fn)
    return out


def render(out, stream=sys.stdout):
    p = lambda *a: print(*a, file=stream)
    p("BATCH POST-PASS DECLARATIONS")
    ci = out.get("chain_info") or {}
    sites = ci.get("sites") or []
    p("DENOMINATOR: %d pass(es) in the DERIVED chain, %d declared, "
      "%d MISSING A DECLARATION, %d declared-but-INVALID"
      % (out["chain_size"], len(out["declared"]), len(out["missing"]),
         len(out["invalid"])))
    p("  chain derived from %s (%s .m file(s)) and %d report-writing call "
      "site(s): %s"
      % (ci.get("package"), ci.get("package_files"), len(sites),
         ", ".join("%s (%s line(s), composes %d)"
                   % (s["label"], s["lines"], s["composes"]) for s in sites)
         or "none"))
    if not out["chain_derived"]:
        p("  *** CHAIN NOT DERIVED: " + (out["why"] or "?"))
        return
    for fn in out["chain"]:
        d = out["passes"][fn]
        if not d["declared"]:
            p("  %-26s *** MISSING A DECLARATION: %s"
              % (fn, "; ".join(d["errors"])))
            continue
        if d["consumes_none_reason"] is not None:
            p("  %-26s consumes NONE -- %s" % (fn, d["consumes_none_reason"]))
        else:
            p("  %-26s consumes %s" % (fn, ", ".join(d["consumes"])))
        for src, e in sorted(d["emits"].items()):
            if e["form"] == "nothing":
                p("  %-26s   %s -> nothing: %s" % ("", src, e["reason"]))
            else:
                p("  %-26s   %s -> %s: %s"
                  % ("", src, e["form"], ", ".join(e["targets"])))
        for e in d["unattributed"]:
            p("  %-26s   UNATTRIBUTED -> %s: %s"
              % ("", e["form"], ", ".join(e["targets"]) or e["reason"]))
        for err in d["errors"]:
            p("  %-26s   *** INVALID: %s" % ("", err))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--json", action="store_true",
                    help="emit the scan as JSON instead of a report")
    ap.add_argument("--root", default=None)
    args = ap.parse_args(argv)
    out = scan(args.root)
    helpers = scan_helpers(args.root)
    if args.json:
        json.dump({"passes": out, "helpers": helpers}, sys.stdout, indent=1,
                  sort_keys=True)
        print()
    else:
        render(out)
        print()
        render_helpers(helpers)
    bad = bool(out["missing"]) or bool(out["invalid"]) or not out["chain_derived"]
    # A helper declaration is voluntary, so an UNDECLARED helper is not a
    # failure -- see the design note above. A MALFORMED one is: it was written
    # on purpose and does not parse, which is the typo-becomes-a-credited-rung
    # case rule 4 exists for.
    bad = bad or bool(helpers["invalid"])
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
