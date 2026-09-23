#!/usr/bin/env python3
"""Every +migrators_j migrator must be in Contents.m, and must have a test.

WHY THIS EXISTS
---------------
`+migrators_j/Contents.m` is consulted as FACT about which classes deliberately
have no migrator -- DID-schema/CLAUDE.md cites it by line for exactly that
("DELIBERATELY WITHOUT A MIGRATOR: `projectvar`", Contents.m:346). So absence
from that file reads, to a human, as "this class has no migrator on purpose".

It was absent for 38 files that DO have one:

    DENOMINATOR: 81 migrator .m files in +migrators_j (Contents.m excluded)
    unmentioned anywhere in Contents.m: 38

That is a hand-maintained index consulted as fact, drifting in the direction
that UNDERSTATES what exists -- the same shape as the coverage ledger's
"dissolved (rename/decompose)" label and the plan headers that claimed no
sign-off while carrying one. The direction is what let it survive: it never
produces a wrong build, only work redone and wrong answers to "what is left".

WHAT IS GENERATED AND WHAT IS NOT
---------------------------------
The narrative half of Contents.m is HAND-WRITTEN and stays that way: it carries
TEAM-SIGN-OFF citations, corrections with their evidence, and design rationale
that no generator can derive. Only the ROSTER is generated -- one entry per
migrator, its text taken from that migrator's OWN H1 summary paragraph -- and
it is fenced by the two markers below. `--check` re-renders and diffs, which is
how DID-schema protects its four schema artifacts.

That leaves one drift this tool cannot see and does not claim to: a migrator
whose H1 summary is itself stale. Twelve were, on 2026-08-12 -- each naming a
`*_calculation` leaf class that does not exist -- and they were repaired before
this roster was first generated, not by this tool. `test_every_jcalculation_
header_names_the_leaf_it_emits` in the sibling test file closes that one case,
mechanically, because the leaf is an argument the code passes.

THE MATCHING RULE, AND WHY A SUBSTRING TEST WILL NOT DO
------------------------------------------------------
A migrator `X.m` counts as MENTIONED when the exact token `X` occurs in
Contents.m bounded on BOTH sides by a character outside [0-9A-Za-z_].

A bare `X in text` substring test false-PASSES, and a false pass on a staleness
gate is the defect being removed. `image_stack` occurs inside
`image_stack_parameters`; `filter` occurs inside `frequency_filter`. Both are
real names in this package, so a substring rule would report a file as
documented on the strength of a DIFFERENT file's entry. MATLAB identifiers are
[A-Za-z][0-9A-Za-z_]*, so a name embedded in a longer identifier is a different
identifier, and the boundary rule is exactly that fact.

The rule is proved rather than asserted: test_check_migrator_roster.py builds a
Contents fixture in which the naive rule passes and this one fails.

TEST COVERAGE, AND WHY THE NUMBER IS NOT ZERO
---------------------------------------------
Coverage in this repository is NOT one test file per migrator -- most migrators
are exercised from shared files (testMigratorsJ, testMigratorsJDaqConfiguration,
testFixtureCorpus, ...) by building a v1 body whose `class_name` is the migrator
name and running it through did2.convert.v1_to_v2. So coverage is expressed as
a QUOTED CLASS-NAME LITERAL in a test file, and that is what is checked here --
in EXECUTABLE code only, with MATLAB comments stripped, because every one of
these files opens with a long header that names classes it does not drive.

One migrator has no such literal anywhere and is pinned in UNTESTED below. It
is NOT papered over with a fabricated test: a shallow test that asserts nothing
would make this instrument read clean while measuring less, which is this
project's signature failure. The list is a RATCHET -- it may shrink freely, and
anything new in it fails.

DENOMINATORS. Every gate prints what it inspected, first and unconditionally, and
a scan that finds NO migrators or NO test files FAILS rather than reporting a
clean zero. `silentLoss` printed "0 empty edges" while reading nothing for two
days; a gate pointed at an empty directory must be loud, not green.

Run:  python3 tools/check_migrator_roster.py            (check; exits non-zero)
      python3 tools/check_migrator_roster.py --write    (regenerate the roster)
"""

import os
import re
import sys
import textwrap

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATOR_DIR = os.path.join(REPO, "src", "did", "+did2", "+convert", "+migrators_j")
CONTENTS = os.path.join(MIGRATOR_DIR, "Contents.m")
TEST_DIR = os.path.join(REPO, "tests", "+did2", "+unittest")

BEGIN = "%   ===================== BEGIN GENERATED ROSTER ====================="
END = "%   ====================== END GENERATED ROSTER ======================"

# Migrators with no quoted class-name literal in the executable code of any
# test file. A RATCHET: it may shrink freely; anything new here fails.
#
# EMPTY AS OF 2026-08-12, and the reason is worth more than the zero.
#
# This set held `temporal_frequency_tuning`, with a note warning that "writing a
# fixture to close the number is the move this file exists to prevent". The
# fixture that closed it was NOT that move, and the evidence is what it found:
# built from the WRITER (NDIcalc-vis-matlab `65718ed`, the single construction
# site at `+ndi/+calc/+vis/temporal_frequency_tuning.m:295`) rather than from a
# sibling, it turned up FOUR field names the uniform-family assumption had
# guessed wrong -- `+vis/+frequency/temporal_frequency_analysis.m:58` writes
# `L50`/`Pref`/`H50` capitalised and universalRenames does not reach nested
# fields, and the writer sets no R2 on the DOG fit at all. The NDI template
# disagrees with the writer three further ways; the writer wins, per the
# standing ground-truth rule.
#
# It also surfaced three defects it deliberately does NOT assert, so that a
# repair need not fight a pinned gap: `jTuningCurveValue` reads `response_units`
# at block level while the writer puts it under `properties` (and its real value
# is the EMPTY MATRIX in 8 of 8 mock documents while V_eta types the slot
# `char`, so this is not a one-line path fix); `controlBlock` reads three
# control fields off the block while the writer puts five inside `tuning_curve`;
# and `abs`, a complete second analysis, has no destination at all.
#
# THE RATCHET IS NOW STRICT AT ZERO. A new entry here fails rather than being
# recorded, which is the correct end state for this list -- and if a future
# migrator genuinely cannot be tested, the honest move is to say why in a
# comment beside its name, not to re-open the set silently.
UNTESTED = set()


# ----------------------------------------------------------------- discovery

def migrator_names(directory=None):
    """Every concrete migrator in the package, by class name. Contents.m is not one."""
    directory = MIGRATOR_DIR if directory is None else directory
    if not os.path.isdir(directory):
        return []
    return sorted(
        f[:-2] for f in os.listdir(directory)
        if f.endswith(".m") and f != "Contents.m"
        and os.path.isfile(os.path.join(directory, f)))


def h1_summary(name, directory=None):
    """A migrator's OWN H1 summary paragraph, collapsed to one string.

    MATLAB's convention: the comment block immediately after the function line,
    opening with %FUNCTIONNAME. The SUMMARY is everything up to the first blank
    comment line; whatever follows is detail, correction notes and evidence, and
    is deliberately not pulled into the roster.
    """
    directory = MIGRATOR_DIR if directory is None else directory
    with open(os.path.join(directory, name + ".m")) as handle:
        lines = handle.read().split("\n")
    i = 0
    while i < len(lines) and not lines[i].lstrip().startswith("%"):
        i += 1
    para = []
    while i < len(lines) and lines[i].lstrip().startswith("%"):
        text = lines[i].lstrip()[1:].strip()
        if not text:
            break
        para.append(text)
        i += 1
    joined = re.sub(r"\s+", " ", " ".join(para)).strip()
    # Drop the leading %FUNCTIONNAME token; the roster prints the name itself.
    return re.sub(r"^%s\s+" % re.escape(name.upper()), "", joined).strip()


# ------------------------------------------------------------ the match rule

def is_mentioned(name, text):
    """THE MATCHING RULE. See the module docstring for why it is not `in`.

    `name` must appear bounded on both sides by a character outside the MATLAB
    identifier set, so `image_stack` is NOT satisfied by `image_stack_parameters`
    and `filter` is NOT satisfied by `frequency_filter`.
    """
    return re.search(r"(?<![0-9A-Za-z_])%s(?![0-9A-Za-z_])" % re.escape(name),
                     text) is not None


# ------------------------------------------------------------- the generator

def render_roster(names, directory=None):
    """The generated block, markers included. Deterministic in `names` order."""
    out = [BEGIN,
           "%",
           "%   One entry per file in this package, GENERATED from each migrator's own H1",
           "%   summary paragraph by tools/check_migrator_roster.py. DO NOT HAND-EDIT: the",
           "%   gate diffs this block against the generator and a hand edit fails it. To",
           "%   change an entry, change that migrator's H1 and re-run with --write.",
           "%"]
    out.append("%   " + str(len(names)) + " migrator(s).")
    out.append("%")
    for name in names:
        out.append("%     " + name)
        summary = h1_summary(name, directory) or "(this migrator has no H1 summary paragraph)"
        for line in textwrap.wrap(summary, width=76, break_on_hyphens=False):
            out.append("%         " + line)
    out.append("%")
    out.append(END)
    return "\n".join(out)


def read_roster(contents_text):
    """The roster block currently in Contents.m, or None when there is none."""
    start = contents_text.find(BEGIN)
    stop = contents_text.find(END)
    if start < 0 or stop < 0 or stop < start:
        return None
    return contents_text[start:stop + len(END)]


def write_roster(contents_text, block):
    """Replace the roster block, or append one at the end of the header comment."""
    existing = read_roster(contents_text)
    if existing is not None:
        return contents_text.replace(existing, block)
    lines = contents_text.split("\n")
    last = max(i for i, l in enumerate(lines) if l.lstrip().startswith("%"))
    return "\n".join(lines[:last + 1] + ["%"] + block.split("\n") + lines[last + 1:])


# ---------------------------------------------------------------- test scan

def strip_matlab_comments(text):
    """Executable code only. A quoted class name in a header comment is not a test.

    Every test file here opens with a long header that names classes it does not
    drive, so a raw scan would grant coverage from prose. Handles %{ %} blocks,
    end-of-line %, and does not mistake a transpose quote for a string opener.
    """
    out = []
    in_block = False
    for line in text.split("\n"):
        stripped = line.strip()
        if in_block:
            if re.fullmatch(r"%\}", stripped):
                in_block = False
            out.append("")
            continue
        if re.fullmatch(r"%\{", stripped):
            in_block = True
            out.append("")
            continue
        kept = []
        i = 0
        in_string = False
        while i < len(line):
            char = line[i]
            if in_string:
                if char == "'":
                    if i + 1 < len(line) and line[i + 1] == "'":
                        kept.append("''")
                        i += 2
                        continue
                    in_string = False
                kept.append(char)
                i += 1
                continue
            if char == "'":
                before = line[:i].rstrip()
                # A quote after an identifier, ) ] } or . is TRANSPOSE, not a string.
                if before and (before[-1].isalnum() or before[-1] in ")]}._'"):
                    kept.append(char)
                    i += 1
                    continue
                in_string = True
                kept.append(char)
                i += 1
                continue
            if char == "%":
                break
            kept.append(char)
            i += 1
        out.append("".join(kept))
    return "\n".join(out)


def test_sources(directory=None):
    """{filename: executable code} for every test file. Helpers are NOT tests.

    tests/+did2/+unittest/+helpers/runCorpusDiscovery.m names many classes while
    asserting nothing about any of them; counting it would hand out coverage for
    being listed in the harness.
    """
    directory = TEST_DIR if directory is None else directory
    if not os.path.isdir(directory):
        return {}
    sources = {}
    for name in sorted(os.listdir(directory)):
        if not (name.startswith("test") and name.endswith(".m")):
            continue
        with open(os.path.join(directory, name)) as handle:
            sources[name] = strip_matlab_comments(handle.read())
    return sources


def covering_tests(name, sources):
    """Test files driving `name` -- a quoted class-name literal in executable code."""
    pattern = re.compile(r"['\"]%s['\"]" % re.escape(name))
    return sorted(f for f, code in sources.items() if pattern.search(code))


# --------------------------------------------------------------------- main

def main(argv):
    write = "--write" in argv[1:]

    contents_path = os.path.join(MIGRATOR_DIR, "Contents.m")
    names = migrator_names()
    if not os.path.isfile(contents_path):
        print("DENOMINATOR: 0 migrator(s) readable -- no Contents.m at %s"
              % contents_path)
        return 1
    with open(contents_path) as handle:
        contents = handle.read()
    block = render_roster(names)

    if write:
        with open(contents_path, "w") as handle:
            handle.write(write_roster(contents, block))
        print("DENOMINATOR: %d migrator(s) rendered into %s"
              % (len(names), os.path.relpath(contents_path, REPO)))
        return 0

    sources = test_sources()
    outside = contents.replace(read_roster(contents) or "", "")
    unmentioned = [n for n in names if not is_mentioned(n, contents)]
    narrative = [n for n in names if is_mentioned(n, outside)]
    uncovered = [n for n in names if not covering_tests(n, sources)]

    print("DENOMINATOR: %d migrator .m file(s) in %s (Contents.m excluded); "
          "%s is %d char(s); %d test file(s) scanned in %s"
          % (len(names), os.path.relpath(MIGRATOR_DIR, REPO),
             os.path.basename(contents_path), len(contents),
             len(sources), os.path.relpath(TEST_DIR, REPO)))
    print("  mentioned in Contents.m:        %d" % (len(names) - len(unmentioned)))
    print("  UNMENTIONED:                    %d" % len(unmentioned))
    print("  of the mentioned, described in the hand-written narrative "
          "(outside the generated roster): %d" % len(narrative))
    print("  with a covering test:           %d" % (len(names) - len(uncovered)))
    print("  WITH NO TEST:                   %d   %s"
          % (len(uncovered), ", ".join(uncovered) or "--"))
    print("  pinned baseline UNTESTED:       %d   %s"
          % (len(UNTESTED), ", ".join(sorted(UNTESTED)) or "--"))

    failures = []
    if not names:
        failures.append(
            "NO MIGRATORS FOUND in %s. A scan of nothing is not a pass -- this "
            "gate reports zero only when it read something." % MIGRATOR_DIR)
    if not sources:
        failures.append(
            "NO TEST FILES FOUND in %s. The coverage leg measured nothing, so "
            "its zero is meaningless." % TEST_DIR)
    if unmentioned:
        failures.append(
            "%d migrator(s) unmentioned in Contents.m: %s\n  Re-run with --write."
            % (len(unmentioned), ", ".join(unmentioned)))
    if read_roster(contents) is None:
        failures.append("Contents.m carries no generated roster block. Run --write.")
    elif read_roster(contents) != block:
        failures.append(
            "the roster block in Contents.m differs from the generator's output. "
            "Re-run with --write; do not hand-edit the block.")
    new = sorted(set(uncovered) - set(UNTESTED))
    if new:
        failures.append(
            "%d migrator(s) with no test and not on the baseline: %s\n"
            "  Write a real test, or -- if the gap is deliberate -- add the name "
            "to UNTESTED with the reason. Do NOT add a test that asserts nothing."
            % (len(new), ", ".join(new)))
    closed = sorted(set(UNTESTED) - set(uncovered))
    if closed:
        print("  NOTE: now covered but still on the baseline (safe; tidy when "
              "convenient): %s" % ", ".join(closed))

    if failures:
        print("\nFAILED:")
        for item in failures:
            print("  * %s" % item)
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
