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
