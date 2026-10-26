#!/usr/bin/env python3
"""Tests for tools/check_carry_citations.py -- carry notes cite carry register rows.

The gate ([carry register], Jess Haley, 2026-10-26) fails a carry note that
cites a row the register does not hold, and a carry site that does not say
which row its note cites. Each test below builds a small source tree and a
register in a temp directory and checks that the gate fails (or passes) for the
reason it should, so a gate that reads nothing, or reads the wrong thing,
cannot pass these:

  1. it sees its input: no register, an empty register, or a tree with no
     carry site FAILS rather than reporting a tidy zero;
  2. a row id that is not in the register FAILS (R1), in a note or a marker;
  3. a carry site with no marker FAILS (R2), and a marker that says nothing
     FAILS (R3);
  4. a marker naming a row whose tag the code does not write FAILS (R4), and
     a `via` file that writes it passes;
  5. `none` passes, is listed, and FAILS under --strict;
  6. a comment that mentions a carry call is not a site.

Run: python3 tools/test_check_carry_citations.py     (or: python3 -m pytest)
"""

import io
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import check_carry_citations as gate  # noqa: E402

GOOD_SITE = """function b = good(preBody)
% carry-register: carry-001
did2.convert.reportNote('carried_as_v1', 'x', 'id', '[carry-001] unplaced: x.y');
b = {preBody};
end
"""


class Tree:
    """A temp did-schema checkout (register) and a temp migrator source tree."""

    def __init__(self, ids=("carry-001", "carry-002"), files=None):
        self.root = tempfile.mkdtemp(prefix="carrycite-")
        self.schema = os.path.join(self.root, "did-schema")
        self.src = os.path.join(self.root, "src")
        os.makedirs(os.path.join(self.schema, "schemas"))
        os.makedirs(os.path.join(self.src, "private"))
        if ids is not None:
            with open(os.path.join(self.schema, gate.REGISTER_REL), "w") as f:
                json.dump({"rows": [{"id": i} for i in ids]}, f)
        for name, text in (files or {"good.m": GOOD_SITE}).items():
            with open(os.path.join(self.src, name), "w") as f:
                f.write(text)

    def run(self, strict=False):
        out = io.StringIO()
        code, res = gate.check(self.schema, src=self.src, strict=strict, out=out)
        self.output = out.getvalue()
        shutil.rmtree(self.root)
        return code, res


def fails_with(tree, rule, strict=False):
    code, res = tree.run(strict=strict)
    assert code == 1, tree.output
    assert any(f.startswith(rule) for f in res["failures"]), tree.output
    return res


# ------------------------------------------------- 1. can it see its input?

def test_a_good_site_passes_and_the_denominator_prints_first():
    t = Tree()
    code, res = t.run()
    assert code == 0, t.output
    assert t.output.startswith("DENOMINATOR:"), t.output
    assert "1 carry site(s)" in t.output, t.output
    assert res["sites"][0]["rows"] == ["carry-001"]


def test_no_register_fails():
    fails_with(Tree(ids=None), "R5")


def test_an_empty_register_fails():
    fails_with(Tree(ids=()), "R5")


def test_a_tree_with_no_carry_site_fails():
    fails_with(Tree(files={"plain.m": "function x = plain()\nx = 1;\nend\n"}), "R5")


# ------------------------------------------------- 2. rows exist

def test_a_note_citing_a_row_not_in_the_register_fails():
    fails_with(Tree(files={"bad.m": GOOD_SITE.replace("carry-001", "carry-099")}), "R1")


def test_a_row_id_in_a_helper_file_is_checked_too():
    files = {"good.m": GOOD_SITE,
             "private/helper.m": "function s = helper()\ns = '[carry-777] x';\nend\n"}
    fails_with(Tree(files=files), "R1")


# ------------------------------------------------- 3. every site says its row

def test_a_site_with_no_marker_fails():
    text = GOOD_SITE.replace("% carry-register: carry-001\n", "")
    fails_with(Tree(files={"bad.m": text}), "R2")


def test_a_marker_too_far_above_the_site_is_not_its_marker():
    text = GOOD_SITE.replace("% carry-register: carry-001\n",
                             "% carry-register: carry-001\nx = 1;\n")
    fails_with(Tree(files={"bad.m": text}), "R2")


def test_a_marker_naming_nothing_fails():
    text = GOOD_SITE.replace("% carry-register: carry-001", "% carry-register: see above")
    fails_with(Tree(files={"bad.m": text}), "R3")


def test_a_carry_as_v1_call_is_a_site():
    text = ("function b = t(preBody)\nb = carryAsV1(preBody, 'why');\nend\n"
            "function b = carryAsV1(preBody, why)\n"
            "% carry-register: forwarded\n"
            "did2.convert.reportNote('carried_as_v1', 'x', 'id', why);\nend\n")
    res = fails_with(Tree(files={"t.m": text}), "R2")
    assert any("t.m:2" in f for f in res["failures"]), res["failures"]


# ------------------------------------------------- 4. the code writes the tag

def test_a_marker_naming_a_row_the_code_does_not_write_fails():
    text = GOOD_SITE.replace("'[carry-001] unplaced: x.y'", "'unplaced: x.y'")
    fails_with(Tree(files={"bad.m": text}), "R4")


def test_a_via_file_that_writes_the_tag_passes():
    site = ("function b = v(preBody)\n"
            "% carry-register: carry-002 via private/why.m\n"
            "did2.convert.reportNote('carried_as_v1', 'x', 'id', why());\nend\n")
    files = {"v.m": site,
             "private/why.m": "function s = why()\ns = '[carry-002] needs_mapping: a | b';\nend\n"}
    t = Tree(files=files)
    code, _ = t.run()
    assert code == 0, t.output


def test_a_missing_via_file_fails():
    site = ("function b = v(preBody)\n"
            "% carry-register: carry-002 via private/gone.m\n"
            "did2.convert.reportNote('carried_as_v1', 'x', 'id', why());\nend\n")
    fails_with(Tree(files={"v.m": site}), "R4")


# ------------------------------------------------- 5. none is listed, not hidden

def test_none_passes_is_listed_and_fails_under_strict():
    text = GOOD_SITE.replace("% carry-register: carry-001", "% carry-register: none") \
                    .replace("[carry-001] ", "")
    t = Tree(files={"n.m": text})
    code, res = t.run()
    assert code == 0, t.output
    assert len(res["pending"]) == 1 and "NO REGISTER ROW" in t.output, t.output
    fails_with(Tree(files={"n.m": text}), "--strict", strict=True)


# ------------------------------------------------- 6. comments are not sites

def test_a_comment_mentioning_a_carry_call_is_not_a_site():
    text = GOOD_SITE + "% did2.convert.reportNote('carried_as_v1', ...) is how\n"
    t = Tree(files={"g.m": text})
    code, res = t.run()
    assert code == 0, t.output
    assert len(res["sites"]) == 1, t.output


# ------------------------------------------------- the real tree

def test_the_real_tree_against_the_did_schema_checkout():
    schema = gate.find_did_schema()
    if schema is None:
        print("NOT CHECKED: no did-schema checkout (the workflow runs the gate itself)")
        return
    out = io.StringIO()
    code, res = gate.check(schema, out=out)
    assert res["sites"], out.getvalue()
    assert code == 0, out.getvalue()


if __name__ == "__main__":
    failures = 0
    tests = [(n, f) for n, f in sorted(globals().items())
             if n.startswith("test_") and callable(f)]
    for name, fn in tests:
        try:
            fn()
            print("ok   %s" % name)
        except Exception as err:  # noqa: BLE001
            failures += 1
            print("FAIL %s\n  %s: %s" % (name, type(err).__name__, err))
    print("\n%d test(s), %d failure(s)" % (len(tests), failures))
    sys.exit(1 if failures else 0)
