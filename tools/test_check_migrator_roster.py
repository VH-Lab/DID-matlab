#!/usr/bin/env python3
"""Tests for tools/check_migrator_roster.py -- the Contents.m / test-coverage gate.

The gate exists because a hand-maintained index was consulted as fact and had
drifted in the direction that UNDERSTATES what exists. A gate against that
failure has one intolerable defect of its own: reading CLEAN while measuring
nothing, or while measuring the wrong thing. So the tests here are, in order:

  1. the scan finds files at all, and an EMPTY directory FAILS rather than
     reporting a tidy zero;
  2. the matching rule cannot false-PASS -- with a fixture in which the naive
     substring rule passes and this one fails, since the whole point of the
     rule is that difference;
  3. the roster round-trips, and a deleted entry is detected;
  4. the coverage leg reads EXECUTABLE code, not header prose, and its baseline
     is a ratchet;
  5. the twelve-stale-headers defect that was found while writing this cannot
     come back: an H1 that names a leaf class the code does not emit fails.

Run: python3 tools/test_check_migrator_roster.py     (or: python3 -m pytest)
"""

import os
import re
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_migrator_roster as gate  # noqa: E402

REPO = gate.REPO


# ------------------------------------------------- 1. can it see its input?

def test_the_scan_finds_migrators_at_all():
    names = gate.migrator_names()
    print("\n--- DENOMINATOR: %d migrator(s) discovered in %s ---"
          % (len(names), os.path.relpath(gate.MIGRATOR_DIR, REPO)))
    assert names, "the package scan found NO migrators; every count below would be a lie"
    assert "Contents" not in names, "Contents.m is the index, not a migrator"
    assert "private" not in names and "super" not in names, \
        "subpackages are not concrete migrators"


def test_an_empty_directory_fails_rather_than_reporting_a_clean_zero():
    """silentLoss printed "0 empty edges" for two days while reading nothing."""
    empty = tempfile.mkdtemp()
    try:
        assert gate.migrator_names(empty) == []
        code = _run_main_against(migrator_dir=empty)
    finally:
        shutil.rmtree(empty)
    print("--- gate pointed at an empty migrator directory: exit %d ---" % code)
    assert code != 0, (
        "a gate that scans zero files must FAIL. Exiting 0 there is the exact "
        "defect this file exists to prevent: a clean-looking instrument that "
        "read nothing.")


def test_a_missing_test_directory_fails_rather_than_reporting_full_coverage():
    empty = tempfile.mkdtemp()
    try:
        assert gate.test_sources(empty) == {}
        code = _run_main_against(test_dir=os.path.join(empty, "nope"))
    finally:
        shutil.rmtree(empty)
    print("--- gate pointed at a missing test directory: exit %d ---" % code)
    assert code != 0, (
        "with no test files every migrator is trivially 'uncovered by nothing "
        "that ran'. Reporting that as coverage would be the reassuring direction.")


# ------------------------------------------- 2. the rule cannot false-PASS

NAIVE_TRAP = """%   Some narrative about the package.
%     image_stack_parameters
%         drops the template's timestamp placeholder.
%     frequency_filter
%         splits the inherited superclass block off into its own document.
"""


def test_the_naive_substring_rule_passes_where_the_real_rule_fails():
    """THE CASE THE RULE EXISTS FOR, shown rather than asserted.

    `image_stack` occurs inside `image_stack_parameters`; `filter` occurs inside
    `frequency_filter`. Both containers are real names in this package, so a
    substring test would report a migrator as documented on the strength of a
    DIFFERENT file's entry -- a false PASS on a staleness gate, which is worse
    than the staleness.
    """
    for name in ("image_stack", "filter"):
        assert name in NAIVE_TRAP, (
            "fixture is wrong: the naive rule must PASS here, otherwise this "
            "test proves nothing about the difference between the two rules")
        assert not gate.is_mentioned(name, NAIVE_TRAP), (
            "%r was accepted as mentioned, but the fixture names only a LONGER "
            "identifier containing it. The matcher has degraded to a substring "
            "test." % name)
    print("\n--- substring trap: 2/2 names pass the naive rule and fail the real one ---")


def test_the_rule_accepts_an_ordinary_entry():
    text = "%     image_stack        - 1 -> 3. -> a body-backed image_observation\n"
    assert gate.is_mentioned("image_stack", text)
    assert not gate.is_mentioned("image_stack_parameters", text), \
        "the rule must not match in the other direction either"


def test_the_rule_accepts_the_boundaries_that_actually_occur():
    for text in ("`image_stack`", "(image_stack)", "migrators_j.image_stack;",
                 "image_stack\n", "  image_stack  "):
        assert gate.is_mentioned("image_stack", text), \
            "a real Contents.m boundary was rejected: %r" % text
    for text in ("Ximage_stack", "image_stackX", "image_stack2", "_image_stack"):
        assert not gate.is_mentioned("image_stack", text), \
            "an identifier-internal occurrence was accepted: %r" % text


def test_a_matcher_that_always_says_mentioned_is_caught():
    """MUTATION: disarm the matcher and watch the unmentioned leg go blind.

    RECORDED HONESTLY, because the first draft of this test asserted the wrong
    thing and passed for the wrong reason would have been worse than no test.
    It disarmed `is_mentioned` and asserted that main() reddens. main() does NOT
    redden -- and that is a true structural fact, not a hole: once the roster is
    generated it CONTAINS every name, so the roster diff strictly dominates the
    unmentioned leg on the real tree, and there is no state of the real tree in
    which the matcher is the only thing standing between a defect and a green
    exit.

    So the mutation is made observable with a CONSTRUCTED FIXTURE at the level
    of the leg itself: a Contents text that names `image_stack_parameters` and
    not `image_stack`. The real matcher reports the gap; the stub reports none.
    """
    fixture = NAIVE_TRAP
    # Both are real files -- +migrators_j/image_stack.m and +migrators/filter.m --
    # and the fixture names only their longer containers,
    # +migrators_j/+super/image_stack_parameters.m and `frequency_filter`.
    names = ["image_stack", "filter"]

    real = [n for n in names if not gate.is_mentioned(n, fixture)]
    original = gate.is_mentioned
    try:
        gate.is_mentioned = lambda name, text: True
        blind = [n for n in names if not gate.is_mentioned(n, fixture)]
    finally:
        gate.is_mentioned = original

    print("\n--- DENOMINATOR: %d name(s) against a fixture that names only their "
          "longer containers ---" % len(names))
    print("    real matcher reports unmentioned: %s" % (real or "--"))
    print("    stubbed always-True reports:      %s" % (blind or "--"))
    assert real == names, (
        "the real matcher must see BOTH gaps; it saw %s" % (real or "none"))
    assert blind == [], "the stub was supposed to be blind; something else answered"
    assert real != blind, (
        "disarming the matcher changed nothing, so the leg does not depend on "
        "it and this gate's central rule is unexercised")


# ------------------------------------------------------- 3. the roster block

def test_the_committed_roster_is_exactly_what_the_generator_produces():
    with open(gate.CONTENTS) as handle:
        contents = handle.read()
    block = gate.read_roster(contents)
    assert block is not None, "Contents.m carries no generated roster block"
    expected = gate.render_roster(gate.migrator_names())
    print("--- roster: %d line(s) committed, %d generated ---"
          % (block.count("\n") + 1, expected.count("\n") + 1))
    assert block == expected, (
        "the roster in Contents.m has drifted from the generator. Re-run "
        "`python3 tools/check_migrator_roster.py --write`; do not hand-edit.")


def test_every_migrator_is_mentioned_in_contents():
    names = gate.migrator_names()
    with open(gate.CONTENTS) as handle:
        contents = handle.read()
    missing = [n for n in names if not gate.is_mentioned(n, contents)]
    print("--- DENOMINATOR: %d migrator(s) checked against Contents.m; "
          "%d unmentioned ---" % (len(names), len(missing)))
    assert not missing, (
        "unmentioned in Contents.m: %s. Absence from this file reads as "
        "'deliberately has no migrator' -- DID-schema/CLAUDE.md cites it for "
        "exactly that." % ", ".join(missing))


def test_deleting_a_roster_entry_reddens():
    """MUTATION: remove one entry's lines from the roster and re-check."""
    names = gate.migrator_names()
    with open(gate.CONTENTS) as handle:
        original = handle.read()
    block = gate.render_roster(names)
    outside = original.replace(block, "")
    # A migrator the narrative ALSO names would still be "mentioned" after the
    # roster entry is removed -- the roster diff would catch it and the mention
    # leg would not. Pick one of the 38 the narrative never named, so the
    # mutation is visible to BOTH legs and the demonstration is not weaker than
    # it looks.
    victim = next(n for n in names if not gate.is_mentioned(n, outside))
    lines = block.split("\n")
    start = next(i for i, l in enumerate(lines) if l == "%     " + victim)
    stop = start + 1
    while stop < len(lines) and lines[stop].startswith("%         "):
        stop += 1
    mutated = "\n".join(lines[:start] + lines[stop:])
    assert mutated != block
    holed = original.replace(block, mutated)
    print("--- mutation: dropped the %r entry (%d line(s)) ---" % (victim, stop - start))
    assert not gate.is_mentioned(victim, holed), \
        "the entry was removed and the name is still matched somewhere"
    assert gate.read_roster(holed) != block, "the roster diff would not notice"


def test_the_roster_is_generated_from_each_migrator_own_h1():
    """A roster of placeholder lines is worse than one that admits a gap."""
    names = gate.migrator_names()
    empty = [n for n in names if not gate.h1_summary(n)]
    print("--- DENOMINATOR: %d H1 summary paragraph(s) read; %d empty ---"
          % (len(names), len(empty)))
    assert not empty, (
        "no H1 summary paragraph in: %s. The roster would carry a placeholder "
        "line for each, which reads as documented and is not." % ", ".join(empty))
    for name in names:
        assert gate.h1_summary(name) in gate.render_roster([name]).replace(
            "\n%         ", " ").replace("%         ", ""), \
            "the rendered entry for %s does not carry its H1 text" % name


# ------------------------------------------------------- 4. the coverage leg

def test_coverage_reads_executable_code_and_not_header_prose():
    """Every test file here opens with a header naming classes it does not drive."""
    prose = ("function tests = testThing\n"
             "%TESTTHING covers 'contrast_tuning' and 'speed_tuning'.\n"
             "tests = functiontests(localfunctions);\n"
             "end\n")
    code = gate.strip_matlab_comments(prose)
    assert "contrast_tuning" not in code, \
        "a class named only in a comment would be granted coverage"
    real = "b.document_class = struct('class_name', 'contrast_tuning');\n"
    assert "contrast_tuning" in gate.strip_matlab_comments(real), \
        "a real fixture literal was stripped along with the comments"


def test_a_transpose_quote_does_not_swallow_the_rest_of_the_line():
    line = "x = a'; y = struct('class_name', 'speed_tuning');\n"
    assert "speed_tuning" in gate.strip_matlab_comments(line), (
        "the comment stripper mistook a transpose for a string opener and ate "
        "the fixture -- which would UNDERCOUNT coverage, i.e. fail loudly, but "
        "for the wrong reason")


def test_helper_files_do_not_grant_coverage():
    helpers = os.path.join(gate.TEST_DIR, "+helpers")
    if not os.path.isdir(helpers):
        return
    assert not gate.test_sources(helpers), (
        "the harness under +helpers names many classes while asserting nothing "
        "about any of them; counting it hands out coverage for being listed")


def test_the_untested_baseline_is_exact_and_is_a_ratchet():
    names = gate.migrator_names()
    sources = gate.test_sources()
    uncovered = [n for n in names if not gate.covering_tests(n, sources)]
    print("--- DENOMINATOR: %d migrator(s) against %d test file(s); "
          "%d with no covering test: %s ---"
          % (len(names), len(sources), len(uncovered), ", ".join(uncovered) or "--"))
    assert sources, "no test files were read; the coverage number is meaningless"
    new = sorted(set(uncovered) - set(gate.UNTESTED))
    assert not new, (
        "migrator(s) with no test and not on the baseline: %s. Write a REAL "
        "test; do not add one that asserts nothing to make the number green."
        % ", ".join(new))


def test_the_baseline_names_a_migrator_that_exists():
    names = set(gate.migrator_names())
    stale = sorted(gate.UNTESTED - names)
    assert not stale, (
        "UNTESTED names %s, which is not a migrator in this package. A baseline "
        "that outlives its subject silently loosens the ratchet." % ", ".join(stale))


# ---------------------------------- 5. the H1 must describe what the code does

def test_every_jcalculation_header_names_the_leaf_it_emits():
    """The defect this gate was written beside, closed mechanically.

    Twelve of the fourteen jCalculation migrators advertised a `*_calculation`
    leaf that does not exist in schemas/V_eta -- the R2/R3 tuning collapse
    retargeted the call sites and left every summary behind. Since the roster is
    generated FROM those summaries, the index would have been repaired into
    saying something false. The leaf is an argument the code passes, so the
    agreement is checkable here without MATLAB and without the schema repo.
    """
    names = gate.migrator_names()
    checked = []
    stale = []
    for name in names:
        with open(os.path.join(gate.MIGRATOR_DIR, name + ".m")) as handle:
            source = handle.read()
        code = "\n".join(l.split("%")[0] for l in source.split("\n"))
        found = re.search(r"jCalculation\(\s*\w+\s*,\s*'([a-z_0-9]+)'", code)
        if not found:
            continue
        leaf = found.group(1)
        checked.append(name)
        if not gate.is_mentioned(leaf, gate.h1_summary(name)):
            stale.append("%s emits %s, H1 does not name it" % (name, leaf))
    print("--- DENOMINATOR: %d migrator(s) scanned, %d calling jCalculation; "
          "%d with an H1 that does not name the leaf ---"
          % (len(names), len(checked), len(stale)))
    assert checked, "no jCalculation call sites found; this gate measured nothing"
    assert not stale, "\n  ".join(["stale H1 summaries:"] + stale)


# --------------------------------------------------------------- plumbing

def _run_main_against(migrator_dir=None, test_dir=None):
    """Run the gate's main() with the module's paths temporarily redirected."""
    saved = (gate.MIGRATOR_DIR, gate.TEST_DIR)
    try:
        if migrator_dir is not None:
            gate.MIGRATOR_DIR = migrator_dir
        if test_dir is not None:
            gate.TEST_DIR = test_dir
        return gate.main(["check_migrator_roster.py"])
    finally:
        gate.MIGRATOR_DIR, gate.TEST_DIR = saved


if __name__ == "__main__":
    failures = 0
    for name, fn in sorted(globals().items()):
        if not name.startswith("test_"):
            continue
        try:
            fn()
            print("PASS %s" % name)
        except AssertionError as err:
            failures += 1
            print("FAIL %s\n  %s" % (name, err))
    print("\n%d failure(s)" % failures)
    sys.exit(1 if failures else 0)
