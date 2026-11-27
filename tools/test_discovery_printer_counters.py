#!/usr/bin/env python3
"""Every counter the discovery run PRINTS for a batch pass is one the pass WRITES.

WHY (DID-matlab #536). runCorpusDiscovery's printBatchPasses reads each counter
with numGet(rep, '<name>'), which returns NaN for a name the report does not
hold -- on purpose: a missing counter must not print as a measured zero. But
nothing checked that the names it reads still exist. When a pass renamed or
removed a counter, its line went on printing NaN, every run, in every corpus.
On Soph run 45870909504 (all six shards) eight counters printed NaN this way:

    v1 metadata archives  five counters of the fold 0ec02b61 removed
                          (the documents are carried as v1 for NDI's second
                          pass, counted as metadata_archives_carried_for_ndi)
    response parameters   `inlined` (replaced by `methods_minted`)
    clock alignment       `syncrule_not_filefind` (now
                          `syncrule_not_device_pair`) and
                          `syncrule_channels_emitted` (removed by ad8a6ce8)

A NaN is honest about the one line, but a census line made of NaN says nothing,
and the same defect returns the next time a counter is renamed. This gate reads
the sources as text, so it runs without MATLAB:

    for each `case '<report field>'` block of printBatchPasses's switch,
    every numGet(rep, '<name>') name must be a field of that pass's report:
    a top-level name of its `report = struct(...)` initializer, or a
    `report.<name> =` assignment in the pass's file.

The denominator (blocks and names checked) prints first. A pass in the
`expected` table with no case block is listed, not failed: it prints only the
generic line, and test_batch_pass_wiring.py owns that leg.

Run: python3 tools/test_discovery_printer_counters.py
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_batch_pass_wiring import struct_field_names  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DISCOVERY = os.path.join(ROOT, "tests", "+did2", "+unittest", "+helpers",
                         "runCorpusDiscovery.m")
CONVERT_DIR = os.path.join(ROOT, "src", "did", "+did2", "+convert")

_EXPECTED_ROW = re.compile(r"'(\w+)'\s*,\s*'did2\.convert\.(\w+)'")
_CASE = re.compile(r"^\s*case\s+'(\w+)'\s*$", re.M)
_NUMGET = re.compile(r"numGet\(\s*rep\s*,\s*'(\w+)'\s*\)")
_ASSIGN = re.compile(r"\breport\.(\w+)\s*(?:\([^)]*\)\s*)?=(?!=)")


def _read(path):
    with open(path, "r", encoding="utf-8") as handle:
        return handle.read()


def _strip_comment_lines(text):
    return "\n".join(line for line in text.splitlines()
                     if not line.strip().startswith("%"))


def expected_table(text):
    """(report field, function name) rows of printBatchPasses's table, in order."""
    i = text.find("expected = {")
    assert i >= 0, "no `expected = {` table in %s" % DISCOVERY
    j = text.find("};", i)
    return _EXPECTED_ROW.findall(_strip_comment_lines(text[i:j]))


def printer_cases(text):
    """{report field: the numGet names its case block reads} for the switch
    that follows the `expected` table."""
    i = text.find("expected = {")
    k = text.find("switch field", i)
    assert k >= 0, "no `switch field` after the expected table in %s" % DISCOVERY
    body = text[k:]
    # the switch ends at the first `    end` at its own indentation
    end = re.search(r"^    end\s*$", body, re.M)
    body = body[:end.start()] if end else body
    body = _strip_comment_lines(body)
    marks = list(_CASE.finditer(body))
    cases = {}
    for n, m in enumerate(marks):
        stop = marks[n + 1].start() if n + 1 < len(marks) else len(body)
        cases[m.group(1)] = _NUMGET.findall(body[m.end():stop])
    return cases


def report_fields(pass_text):
    """Every field name the pass's report can hold."""
    names = set(struct_field_names(pass_text) or [])
    names.update(_ASSIGN.findall(_strip_comment_lines(pass_text)))
    return names


def missing_counters(cases, table, read_pass):
    """[(report field, pass, name)] read by a printer block and written by no
    pass, plus the number of (block, name) pairs checked."""
    fn_of = dict(table)
    missing, checked = [], 0
    for field, names in sorted(cases.items()):
        assert field in fn_of, (
            "printer case '%s' names no row of the expected table" % field)
        have = report_fields(read_pass(fn_of[field]))
        for name in sorted(set(names)):
            checked += 1
            if name not in have:
                missing.append((field, fn_of[field], name))
    return missing, checked


def _read_pass(fn):
    return _read(os.path.join(CONVERT_DIR, fn + ".m"))


# ---------------------------------------------------------------- the gate

def test_every_printed_counter_is_a_counter_the_pass_writes():
    text = _read(DISCOVERY)
    table = expected_table(text)
    cases = printer_cases(text)
    missing, checked = missing_counters(cases, table, _read_pass)
    no_case = [fn for field, fn in table if field not in cases]
    print("\n--- discovery printer counters: %d pass(es) in the table, %d with a "
          "printer block, %d counter name(s) checked, %d not written by the "
          "pass ---" % (len(table), len(cases), checked, len(missing)))
    for fn in no_case:
        print("  %-34s no printer block (generic line only)" % fn)
    for field, fn, name in missing:
        print("  %-34s prints `%s`, which its report does not hold (NaN)"
              % (fn, name))
    assert len(table) >= 4 and len(cases) >= 4 and checked >= 50, (
        "the scan read too little (table %d, blocks %d, names %d): that is "
        "'did not look', not 'found nothing'" % (len(table), len(cases), checked))
    assert not missing, (
        "%d printed counter(s) no pass writes; each prints NaN on every corpus "
        "run: %s" % (len(missing), ", ".join(
            "%s.%s" % (fn, name) for _f, fn, name in missing)))


# ---------------------------------------------------------------- controls

_PRINTER = """
expected = { ...
    'alpha_fold', 'did2.convert.resolveAlpha'};
    switch field
        case 'alpha_fold'
            fprintf('%d %d', numGet(rep, 'seen'), numGet(rep, NAME));
    end
"""
_PASS = """function result = resolveAlpha(result)
report = struct( ...
    'seen', 0, ...
    'nested', struct('inner', {}), ... % 'commented', 1
    'ran', false);
report.folded = 0;
end
"""


def _control(second):
    text = _PRINTER.replace("NAME", second)
    return missing_counters(printer_cases(text), expected_table(text),
                            lambda _fn: _PASS)


def test_control_a_counter_the_pass_does_not_hold_is_found():
    missing, checked = _control("'gone'")
    assert checked == 2, checked
    assert missing == [("alpha_fold", "resolveAlpha", "gone")], missing


def test_control_nested_and_commented_names_are_not_counters():
    for name in ("'inner'", "'commented'"):
        missing, _ = _control(name)
        assert [m[2] for m in missing] == [name.strip("'")], (name, missing)


def test_control_initialized_and_assigned_counters_pass():
    for name in ("'ran'", "'folded'"):
        missing, checked = _control(name)
        assert checked == 2 and not missing, (name, missing)


if __name__ == "__main__":
    failures = 0
    for fn in [v for k, v in sorted(globals().items()) if k.startswith("test_")]:
        try:
            fn()
            print("PASS %s" % fn.__name__)
        except AssertionError as err:
            failures += 1
            print("FAIL %s\n  %s" % (fn.__name__, err))
    sys.exit(1 if failures else 0)
