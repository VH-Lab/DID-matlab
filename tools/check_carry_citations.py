#!/usr/bin/env python3
"""Every carry note a migrator writes cites its carry register row.

Decided by Jess Haley, 2026-10-26 [carry register] (did-schema
schemas/V_eta_go_forward_class_audit.md): every reason the generic migration
carries a v1 document whole as v1 is a row of ONE register,
did-schema schemas/V_eta_carry_register.json, "so that a carry is never read as
'V2 is missing a field'"; "every carry note a migrator writes cites its
register row, and a DID-matlab test fails on a carry whose reason is not
registered".

A carry note is `did2.convert.reportNote('carried_as_v1', CLASS, ID, DETAIL)`.
DETAIL cites a row by a `[carry-NNN]` tag placed before the reason it covers:
at the start of the note when every reason in it is that row's
('[carry-022] needs_mapping: ...'), before each item when a note lists reasons
of different rows ('unplaced: [carry-014] ..., [carry-015] ...').

Notes are built at run time, often from parts made in another file, so this
reads the SOURCE: every carry site (a `reportNote('carried_as_v1'` call, or a
call of treatment.m's `carryAsV1`) carries, in the comment lines directly above
it, a marker saying which rows its note can cite:

    % carry-register: carry-001
    % carry-register: carry-023 carry-024 via private/jTreatmentBodies.m; none
    %   for an amount a dose cannot place
    % carry-register: none
    % carry-register: forwarded (each caller's marker names the row ...)

FAILS (exit 1) on any of:
  R1  a `carry-NNN` token anywhere in the scanned sources that is not a row id
      of the register (a citation of a row that does not exist);
  R2  a carry site with no `% carry-register:` marker directly above it;
  R3  a marker that names no row and says neither `none` nor `forwarded`;
  R4  a row a marker names whose `[carry-NNN]` tag is not written in that
      file, nor in a file the marker names with `via` (the marker claims a
      citation the code does not make), or a `via` file that does not exist;
  R5  the register cannot be read, or holds no rows, or no carry site is found
      (a check that inspected nothing is not a pass).
REPORTS, and fails only with --strict:
  a marker saying `none`: a carry reason with NO register row yet. The rule is
  not to invent a row here; the team adds it to the register, and the marker
  then names it. These are listed, with the note text that follows the marker.

It prints its denominator first: the register and its row count, the files
scanned and the carry sites found.

Where the register is read from (the did-schema checkout the tests already
use): --did-schema DIR, else $DID_SCHEMA_ROOT, else ./did-schema (the CI
workflows check did-schema out there), else ../did-schema (a sibling checkout).

Usage: python3 tools/check_carry_citations.py [--did-schema DIR] [--strict]
"""
import argparse
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "src", "did", "+did2", "+convert")
REGISTER_REL = os.path.join("schemas", "V_eta_carry_register.json")

ROW_TOKEN = re.compile(r"carry-\d{3}")
SITE = re.compile(r"reportNote\(\s*'carried_as_v1'|\bcarryAsV1\(")
MARKER = re.compile(r"^\s*%\s*carry-register:(.*)$")
VIA = re.compile(r"\bvia\s+(\S+?\.m)\b")
MARKER_REACH = 8   # comment lines above a site searched for its marker


def find_did_schema(explicit=None):
    """The did-schema checkout holding the register, or None."""
    candidates = []
    if explicit:
        candidates.append(explicit)
    env = os.environ.get("DID_SCHEMA_ROOT")
    if env:
        candidates.append(env)
    candidates += [os.path.join(REPO, "did-schema"),
                   os.path.join(os.path.dirname(REPO), "did-schema")]
    for c in candidates:
        if os.path.isfile(os.path.join(c, REGISTER_REL)):
            return c
    return None


def register_ids(path):
    with open(path) as f:
        reg = json.load(f)
    rows = reg.get("rows", []) if isinstance(reg, dict) else []
    return [r.get("id") for r in rows if isinstance(r, dict)]


def m_files(src):
    out = []
    for root, _dirs, files in os.walk(src):
        for name in files:
            if name.endswith(".m"):
                out.append(os.path.join(root, name))
    return sorted(out)


def is_comment(line):
    return line.lstrip().startswith("%")


def sites_in(lines):
    """Line indexes (0-based) of carry sites: code lines, not definitions."""
    out = []
    for i, line in enumerate(lines):
        code = line.split("%", 1)[0] if not is_comment(line) else ""
        if not code.strip() or code.lstrip().startswith("function"):
            continue
        if SITE.search(code):
            out.append(i)
    return out


def marker_for(lines, i):
    """The marker text above site line I (its continuation lines joined), or None."""
    j = i - 1
    block = []
    while j >= 0 and i - j <= MARKER_REACH and is_comment(lines[j]):
        block.insert(0, lines[j])
        j -= 1
    for k, line in enumerate(block):
        m = MARKER.match(line)
        if m:
            rest = [m.group(1)] + [b.strip().lstrip("%") for b in block[k + 1:]]
            return " ".join(s.strip() for s in rest).strip()
    return None


def note_text(lines, i):
    """The site's statement, up to its closing ';' (for the listing)."""
    out = []
    for line in lines[i:i + 6]:
        out.append(line.strip())
        if line.rstrip().endswith(";"):
            break
    return " ".join(out)


def check(did_schema, src=SRC, strict=False, out=sys.stdout):
    """Run the check; return (exit_code, result dict)."""
    p = lambda *a: print(*a, file=out)  # noqa: E731
    failures = []
    pending = []
    res = {"failures": failures, "pending": pending, "sites": []}

    reg_path = os.path.join(did_schema, REGISTER_REL) if did_schema else None
    if not reg_path or not os.path.isfile(reg_path):
        p("NOT CHECKED: no did-schema checkout holding %s (pass --did-schema, set "
          "DID_SCHEMA_ROOT, or check did-schema out at ./did-schema)" % REGISTER_REL)
        failures.append("R5 register not found")
        return 1, res
    try:
        ids = register_ids(reg_path)
    except (OSError, ValueError) as err:
        p("FAIL R5 the register cannot be read: %s" % err)
        failures.append("R5 unreadable")
        return 1, res
    known = set(i for i in ids if i)
    files = m_files(src)

    all_sites = []
    texts = {}
    for path in files:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.read().split("\n")
        texts[path] = lines
        for i in sites_in(lines):
            all_sites.append((path, i))

    p("DENOMINATOR: register %s (%d row(s)); %d .m file(s) under %s; "
      "%d carry site(s)" % (reg_path, len(known), len(files),
                            os.path.relpath(src, REPO), len(all_sites)))
    if not known:
        failures.append("R5 the register holds no rows")
    if not all_sites:
        failures.append("R5 no carry site found: the scan inspected nothing")

    rel = lambda path: os.path.relpath(path, src)  # noqa: E731

    # R1: every row token names a register row
    for path in files:
        for n, line in enumerate(texts[path], 1):
            for tok in ROW_TOKEN.findall(line):
                if tok not in known:
                    failures.append("R1 %s:%d cites %s, which is not a row of the "
                                    "register" % (rel(path), n, tok))

    cited_rows = set()
    for path, i in all_sites:
        where = "%s:%d" % (rel(path), i + 1)
        marker = marker_for(texts[path], i)
        site = {"where": where, "marker": marker, "rows": [], "none": False}
        res["sites"].append(site)
        if marker is None:
            failures.append("R2 %s: carry site with no '%% carry-register:' marker "
                            "above it: %s" % (where, note_text(texts[path], i)))
            continue
        rows = sorted(set(ROW_TOKEN.findall(marker)))
        site["rows"] = rows
        site["none"] = bool(re.search(r"\bnone\b", marker))
        forwarded = bool(re.search(r"\bforwarded\b", marker))
        if not rows and not site["none"] and not forwarded:
            failures.append("R3 %s: the marker names no row and says neither 'none' "
                            "nor 'forwarded': %s" % (where, marker))
        searched = ["\n".join(texts[path])]
        for via in VIA.findall(marker):
            vpath = os.path.normpath(os.path.join(os.path.dirname(path), via))
            if not os.path.isfile(vpath):
                failures.append("R4 %s: the marker's via file %s does not exist"
                                % (where, via))
                continue
            with open(vpath, encoding="utf-8", errors="replace") as f:
                searched.append(f.read())
        for row in rows:
            if not any("[%s]" % row in s for s in searched):
                failures.append("R4 %s: the marker names %s but no '[%s]' tag is "
                                "written in that file or its via file(s)"
                                % (where, row, row))
            else:
                cited_rows.add(row)
        if site["none"]:
            pending.append((where, marker, note_text(texts[path], i)))

    n_cite = sum(1 for s in res["sites"] if s["rows"])
    n_only = sum(1 for s in res["sites"] if s["rows"] and not s["none"])
    p("sites citing a row: %d of %d (every reason cited: %d; some reason with no "
      "row: %d); sites citing none: %d" % (
          n_cite, len(all_sites), n_only, n_cite - n_only,
          sum(1 for s in res["sites"] if s["none"] and not s["rows"])))
    p("register rows cited by a site: %d of %d" % (len(cited_rows), len(known)))
    uncited = sorted(known - cited_rows)
    if uncited:
        p("register rows no DID-matlab carry site cites (not a failure: a row "
          "may be carried elsewhere): %s" % ", ".join(uncited))

    if pending:
        p("")
        p("CARRY REASONS WITH NO REGISTER ROW (%d site(s)): the team adds the row; "
          "the marker then names it%s" % (len(pending),
                                         "" if strict else "; --strict fails on these"))
        for where, marker, text in pending:
            p("  %s  [%s]" % (where, marker))
            p("      %s" % text)
        if strict:
            failures.append("--strict: %d carry site(s) with a reason no register "
                            "row covers" % len(pending))

    p("")
    if failures:
        for f in failures:
            p("FAIL " + f)
        p("%d failure(s)" % len(failures))
        return 1, res
    p("OK: every row a carry note cites exists in the register, and every carry "
      "site names its row(s) or says it has none")
    return 0, res


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--did-schema", default=None,
                    help="did-schema checkout holding %s" % REGISTER_REL)
    ap.add_argument("--strict", action="store_true",
                    help="also fail on carry reasons with no register row")
    args = ap.parse_args(argv)
    code, _ = check(find_did_schema(args.did_schema), strict=args.strict)
    return code


if __name__ == "__main__":
    sys.exit(main())
