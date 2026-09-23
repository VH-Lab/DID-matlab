#!/usr/bin/env python3
"""Every batch post-pass in the DERIVED chain carries a VALID declaration.

WHAT THIS GATES, AND THE ONE FAILURE IT EXISTS FOR. A pass added tomorrow with
no declaration must turn this file red. That is the single property the whole
mechanism rests on: DID-schema's `coverage.py` credits completion rungs from
these declarations, and an undeclared pass there is reported as MISSING, never
as a pass that consumes nothing. If this test could pass with a pass
undeclared, the reassuring reading would come back through the gate built to
stop it.

DENOMINATOR FIRST. Every test below prints how many passes it read before it
prints a verdict, because a sweep over zero files passes every assertion it
makes. `test_the_chain_is_not_empty` is the one that makes the rest mean
something.

NO MATLAB IS NEEDED and that is deliberate: this container has none
(`command -v matlab octave` exits 1), so a static read of the sources is the
only gate with an opinion while the work is being done -- the same reasoning
`tools/test_batch_pass_wiring.py` gives for sitting beside its MATLAB sibling.
"""

import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import batch_pass_declarations as bpd  # noqa: E402


@pytest.fixture(scope="module")
def out():
    return bpd.scan()


def test_the_chain_is_not_empty(out, capsys):
    with capsys.disabled():
        print("\nDENOMINATOR: chain_derived=%s, %d pass(es) in the derived chain"
              % (out["chain_derived"], out["chain_size"]))
    assert out["chain_derived"], out["why"]
    assert out["chain_size"] > 0, (
        "the derived chain is EMPTY, so every other assertion in this file is "
        "vacuous: " + str(out["why"]))


def test_every_pass_in_the_chain_carries_a_declaration(out, capsys):
    with capsys.disabled():
        print("\nDENOMINATOR: %d pass(es) read, %d declared, %d missing"
              % (out["chain_size"], len(out["declared"]), len(out["missing"])))
    assert not out["missing"], (
        "MISSING A DECLARATION -- add the two header markers (see "
        "tools/batch_pass_declarations.py for the grammar): "
        + ", ".join("%s: %s" % (fn, "; ".join(out["passes"][fn]["errors"]))
                    for fn in out["missing"]))


def test_no_declaration_is_malformed(out, capsys):
    errs = {fn: out["passes"][fn]["errors"] for fn in out["declared"]
            if out["passes"][fn]["errors"]}
    with capsys.disabled():
        print("\nDENOMINATOR: %d declaration(s) checked, %d invalid"
              % (len(out["declared"]), len(errs)))
    assert not errs, "; ".join("%s: %s" % (k, " / ".join(v))
                               for k, v in errs.items())


def test_every_consumed_class_is_accounted_for(out, capsys):
    """Rule 3 of the grammar, asserted independently of the parser's own list.

    The parser already raises this as an error; this re-derives it from the
    parsed structure so a regression that stops RAISING is still caught.
    """
    gaps, consumed = [], 0
    for fn in out["declared"]:
        d = out["passes"][fn]
        consumed += len(d["consumes"])
        for c in d["consumes"]:
            if c not in d["emits"]:
                gaps.append("%s: %s" % (fn, c))
    with capsys.disabled():
        print("\nDENOMINATOR: %d consumed class(es) across %d declaration(s)"
              % (consumed, len(out["declared"])))
    assert not gaps, "consumed with no EMITS line: " + ", ".join(gaps)


def test_emptiness_is_stated_with_a_reason(out, capsys):
    """A pass that consumes nothing says WHY. Absence is never the statement."""
    none_passes = [fn for fn in out["declared"]
                   if out["passes"][fn]["consumes_none_reason"] is not None]
    with capsys.disabled():
        print("\nDENOMINATOR: %d declaration(s), %d declaring CONSUMES NONE"
              % (len(out["declared"]), len(none_passes)))
    for fn in none_passes:
        assert out["passes"][fn]["consumes_none_reason"].strip(), fn
        assert not out["passes"][fn]["emits"], (
            "%s consumes NONE and yet declares an emission" % fn)


# ---------------------------------------------------------------------------
# THE MUTATION CHECKS. Each constructs a source that SHOULD fail and asserts it
# does. A gate is only as good as its ability to go red, and the four rules
# above are exactly the four ways a declaration can be quietly wrong.
# ---------------------------------------------------------------------------

_HEAD = "function [result, report] = p(result, options)\n"
_C = "%   " + bpd.CONSUMES_TOKEN + ": "
_E = "%   " + bpd.EMITS_TOKEN + ": "


def _parse(*lines):
    return bpd.parse_declaration(_HEAD + "".join(l + "\n" for l in lines))


def test_mutation_no_markers_is_missing_not_empty():
    d = _parse("%P Does a thing.", "%", "%   It consumes documents.")
    assert not d["declared"]
    assert d["consumes"] == [] and d["emits"] == {}
    assert len(d["errors"]) == 2, d["errors"]


def test_mutation_a_marker_outside_the_header_does_not_count():
    text = (_HEAD + "%P Does a thing.\n" + "x = 1;\n"
            + _C + "generic_file\n" + _E + "generic_file -> document: opaque_body\n")
    d = bpd.parse_declaration(text)
    assert not d["declared"], "a mid-file comment must not read as a declaration"


def test_mutation_consumed_class_with_no_emits_line_is_an_error():
    d = _parse("%P.", _C + "generic_file, ontology_label",
               _E + "generic_file -> document: opaque_body")
    assert d["declared"] and d["errors"]
    assert any("ontology_label" in e for e in d["errors"]), d["errors"]


def test_mutation_emits_a_class_it_never_consumed():
    d = _parse("%P.", _C + "generic_file",
               _E + "generic_file -> document: opaque_body",
               _E + "valid_interval -> document: logical_observation")
    assert any("valid_interval" in e for e in d["errors"]), d["errors"]


def test_mutation_none_without_a_reason():
    d = _parse("%P.", _C + "NONE", _E + "NONE -- nothing is emitted")
    assert any("no reason" in e for e in d["errors"]), d["errors"]


def test_mutation_nothing_without_a_reason():
    d = _parse("%P.", _C + "valid_interval", _E + "valid_interval -> nothing:")
    assert any("no reason" in e for e in d["errors"]), d["errors"]


def test_mutation_unknown_form():
    d = _parse("%P.", _C + "generic_file",
               _E + "generic_file -> maybe: opaque_body")
    assert any("maybe" in e for e in d["errors"]), d["errors"]


def test_mutation_consumes_none_but_emits_something():
    d = _parse("%P.", _C + "NONE -- reads no v1 class",
               _E + "UNATTRIBUTED -> document: epoch")
    assert d["errors"], "CONSUMES NONE with an emission must not validate"


def test_a_wrapped_value_is_joined():
    d = _parse("%P.", _C + "generic_file",
               _E + "generic_file -> document: term_observation,",
               "%       opaque_body")
    assert d["emits"]["generic_file"]["targets"] == [
        "term_observation", "opaque_body"], d


def test_inline_is_a_distinct_form_from_document():
    d = _parse("%P.", _C + "x", _E + "x -> inline: method_parameters")
    assert d["emits"]["x"]["form"] == "inline"
    assert d["emits"]["x"]["targets"] == ["method_parameters"]


def test_the_live_declarations_include_the_three_row_107_shapes(out):
    """The confirmed instances row 107 names, read from the real sources."""
    assert out["chain_derived"]
    fold = out["passes"]["foldGenericFiles"]
    assert "generic_file" in fold["consumes"]                    # shape (2)
    assert fold["emits"]["generic_file"]["form"] == "document"
    rp = out["passes"]["resolveResponseParameters"]              # shape (3)
    k = "stimulus_response_scalar_parameters_basic"
    assert rp["emits"][k]["form"] == "inline"
    assert rp["emits"][k]["targets"] == ["method_parameters"]
    vi = out["passes"]["resolveValidIntervals"]                  # the honesty case
    assert vi["emits"]["valid_interval"]["form"] == "nothing", (
        "resolveValidIntervals is DORMANT by team decision; declaring an "
        "emission here would credit a rung off code that is switched off")


# ============================================================================
# THE SHARED HELPER -- the same grammar, a different denominator.
# ============================================================================
#
# These gate the FOURTH channel. The property under test is the opposite of the
# one above: a pass in the derived chain MUST declare and the gate is armed,
# because the chain is derived so the denominator is known. Nothing derives "a
# helper that owes a declaration", so declaring is VOLUNTARY here -- and what
# replaces the gate is that an undeclared helper credits NOTHING and the scan
# says how many mint while declaring nothing. Both halves are asserted, because
# "voluntary" degrades into "silently unmeasured" the moment the second half
# stops being printed.


@pytest.fixture(scope="module")
def helpers():
    return bpd.scan_helpers()


def test_the_helper_population_is_not_empty(helpers, capsys):
    """The `silentLoss` guard for this scan: zero candidates is a failed
    lookup, and every assertion below it would pass over an empty set."""
    with capsys.disabled():
        print("\nDENOMINATOR: %d helper .m file(s) across %d dir(s), %d MINTING;"
              " %d declared, %d undeclared, %d INVALID"
              % (helpers["candidates"], len(helpers["dirs"]),
                 len(helpers["minting"]), len(helpers["declared"]),
                 len(helpers["undeclared"]), len(helpers["invalid"])))
    assert helpers["candidates"] > 0
    assert all(d["exists"] for d in helpers["dirs"]), \
        "a helper directory named here and absent on disk silently shrinks " \
        "the population: %s" % [d for d in helpers["dirs"] if not d["exists"]]


def test_no_helper_declaration_is_malformed(helpers):
    """A HALF-WRITTEN declaration -- one marker, not both -- is INVALID rather
    than undeclared. It was written on purpose, so silence is the wrong read."""
    assert helpers["invalid"] == [], \
        "; ".join("%s: %s" % (fn, helpers["helpers"][fn]["errors"] or
                              "one marker present, the other absent")
                  for fn in helpers["invalid"])


def test_jSoftwareFromApp_declares_the_app_fold(helpers):
    """The row the channel exists for. Asserted against evidence PRESENT."""
    dec = helpers["helpers"].get("jSoftwareFromApp")
    assert dec is not None, "jSoftwareFromApp is not in the helper population"
    assert dec["declared"], "it must carry BOTH markers"
    assert dec["consumes"] == ["app"]
    assert dec["emits"]["app"]["form"] == "document"
    assert dec["emits"]["app"]["targets"] == ["software"]


def test_the_declaration_sits_on_the_fold_not_on_the_mint(helpers):
    """jSoftwareFromApp carries no `class_name` literal at all -- jSoftware
    does. A rule of "the file with the literal declares" would put the sentence
    on a helper that has never heard of `app` and cannot say what becomes of
    it. This asserts the split is real and not an accident of where it landed."""
    assert helpers["helpers"]["jSoftwareFromApp"]["mints"] == []
    assert "software" in helpers["helpers"]["jSoftware"]["mints"]


def test_an_undeclared_helper_contributes_nothing_to_the_index(helpers):
    idx = bpd.helper_index(helpers)
    declared = set(helpers["declared"])
    for entries in idx.values():
        for e in entries:
            assert e["helper"] in declared


def test_the_undeclared_minters_are_named_not_just_counted(helpers):
    """`nobody looked` stays a third state. The unmeasured set must have a
    shape a reader can act on, not a bare integer."""
    for fn in helpers["helpers_minting_undeclared"]:
        assert helpers["helpers"][fn]["mints"], \
            "%s is listed as a minting helper and mints nothing" % fn
        assert fn not in helpers["declared"]


def test_a_marker_outside_the_helper_header_does_not_count():
    """Same rule as the passes: a declaration lives in the header, where the
    next reader sees it. A marker in a mid-file comment is not one."""
    text = ("function y = jThing(x)\n%JTHING Summary.\ny = x;\n"
            "% " + bpd.CONSUMES_TOKEN + ": thing\n"
            "% " + bpd.EMITS_TOKEN + ": thing -> document: other\n")
    assert not bpd.parse_declaration(text)["declared"]


def test_minted_classes_ignores_a_commented_out_mint():
    """The minting census strips comments, so a mint site quoted in prose --
    which this repository's headers do constantly -- is not counted as one."""
    live = "x.document_class = struct('class_name', 'real_thing');"
    dead = "%   x.document_class = struct('class_name', 'prose_thing');"
    assert bpd.minted_classes(live) == ["real_thing"]
    assert bpd.minted_classes(dead) == []


def test_helper_index_drops_a_declaration_carrying_errors():
    """Rule 4: a typo must not become a credited rung."""
    out = {"declared": ["jBroken"],
           "helpers": {"jBroken": {
               "declared": True, "consumes": ["thing"],
               "emits": {"thing": {"form": "document", "targets": ["t"],
                                   "reason": None}},
               "errors": ["EMITS: `other` is not in CONSUMES"]}}}
    assert bpd.helper_index(out) == {}
