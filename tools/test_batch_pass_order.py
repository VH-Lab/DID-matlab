#!/usr/bin/env python3
"""tools/batch_pass_order.py: the derived order, its two rules, and its gaps.

[migration reliability practices] (c), Jess Haley, 2026-10-26 (did-schema
docs/plans/did_v2_go_forward_class_audit.md): whole-dataset passes declare
what they read and write, and their order is derived and checked.

Each test prints its denominator before its verdict. The mutation tests are
the point: a checker that reads the repository and says OK proves nothing
until it has been shown to say FAIL on a composition that is wrong, on a pass
with no declaration, and on declarations no order can satisfy.

NDI-matlab's second pass is checked when $NDI_MATLAB names a checkout; the
test that needs it says NOT CHECKED otherwise (a third state, never a pass).

Run: python3 tools/test_batch_pass_order.py
"""

import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import batch_pass_order as bpo  # noqa: E402

P = "BATCH-PASS-"


def eff(reads=(), adds=(), changes=(), removes=()):
    it = lambda xs: [bpo.parse_item(x) for x in xs]
    return {"declared": True, "errors": [], "none_reasons": {},
            "reads": it(reads), "adds": it(adds), "changes": it(changes),
            "removes": it(removes)}


def test_the_repository_is_read_and_in_order():
    out = bpo.check()
    print("  DENOMINATOR: chain derived %s, %d pass(es), %d composition(s), "
          "%d pair(s) compared" % (out["chain_derived"], len(out["passes"]),
                                   len(out["compositions"]),
                                   out["pairs_compared"]))
    assert out["chain_derived"], "the batch-pass chain was not derived"
    assert len(out["passes"]) > 0 and len(out["compositions"]) > 0, \
        "nothing was read, so OK would be vacuous"
    assert out["pairs_compared"] > 0
    assert not out["errors"], "; ".join(out["errors"])


def test_the_orders_the_source_comments_state_are_derived():
    """The constraints the pass headers state in prose (their ORDER notes)
    must come out of the declarations, or the declarations are incomplete."""
    out = bpo.check()
    comp = out["compositions"][0]
    pairs = {(a, b) for a, b, _ in comp["constraints"]}
    print("  DENOMINATOR: %d constraint(s) derived in %s"
          % (len(pairs), comp["label"]))
    c = "did2.convert."
    stated = [
        # resolveOpenmindsCitations.m: "THIS RUNS BEFORE resolveDatasetEntities"
        (c + "resolveOpenmindsCitations", c + "resolveDatasetEntities"),
        # resolveEpochProbemap.m: "AFTER epochMint ... AND AFTER resolveSessionAnchors"
        (c + "epochMint", c + "resolveEpochProbemap"),
        (c + "resolveSessionAnchors", c + "resolveEpochProbemap"),
        # resolveValidIntervals.m: "It reads the `epoch` documents epochMint
        # appends, so it MUST run after epochMint"
        (c + "epochMint", c + "resolveValidIntervals"),
        # epochMint.m resolveBathAnchors reads result.deferred_bath_anchors
        (c + "resolveDeferredBaths", c + "epochMint"),
    ]
    missing = [p for p in stated if p not in pairs]
    assert not missing, "not derived: %s" % missing


def test_a_reader_before_a_writer_fails_R1():
    effects = {"A": eff(reads=["entity(epoch)"]), "B": eff(adds=["entity"])}
    v = bpo.conflicts(effects["A"], effects["B"])
    print("  DENOMINATOR: 1 pair, %d conflict(s)" % len(v))
    assert v and v[0].startswith("R1"), v
    order, cycle = bpo.derive(["A", "B"], effects)
    assert order == ["B", "A"] and not cycle, (order, cycle)


def test_a_remover_before_a_reader_fails_R2():
    effects = {"A": eff(removes=["acquisition_epoch"]),
               "B": eff(reads=["acquisition_epoch"])}
    v = bpo.conflicts(effects["A"], effects["B"])
    print("  DENOMINATOR: 1 pair, %d conflict(s)" % len(v))
    assert v and v[0].startswith("R2"), v


def test_qualifiers_narrow_and_unqualified_overlaps_all():
    e = bpo.parse_item
    checks = [(e("entity(dataset)"), e("entity(epoch)"), False),
              (e("entity"), e("entity(epoch)"), True),
              (e("entity(epoch)"), e("entity(epoch)"), True),
              (e("result.epoch_mint"), e("result.epoch_mint"), True),
              (e("observation"), e("entity"), False)]
    print("  DENOMINATOR: %d pair(s)" % len(checks))
    for a, b, want in checks:
        assert bpo.overlaps(a, b) == want, (a, b, want)


def test_declarations_no_order_satisfies_are_a_cycle():
    effects = {"A": eff(reads=["x"], adds=["y"]),
               "B": eff(reads=["y"], adds=["x"])}
    order, cycle = bpo.derive(["A", "B"], effects)
    print("  DENOMINATOR: 2 passes, cycle %s" % cycle)
    assert cycle == ["A", "B"], (order, cycle)


def test_the_parser_reports_a_half_written_declaration():
    lines = ["%% %sREADS: entity(epoch), result.epoch_mint," % P,
             "%%     acquisition_epoch" % (),
             "%% %sADDS: NONE -- appends nothing" % P]
    d = bpo.parse_effects(lines)
    print("  DENOMINATOR: 4 markers expected, errors %s" % d["errors"])
    assert d["declared"]
    assert [x for x in d["errors"] if "CHANGES" in x]
    assert [x for x in d["errors"] if "REMOVES" in x]
    assert d["reads"] == [("entity", "epoch"), ("result.epoch_mint", None),
                          ("acquisition_epoch", None)], d["reads"]


def test_a_none_needs_a_reason():
    lines = ["%% %s%s: NONE" % (P, e) for e in bpo.EFFECTS]
    d = bpo.parse_effects(lines)
    print("  DENOMINATOR: 4 markers, %d error(s)" % len(d["errors"]))
    assert len(d["errors"]) == 4, d["errors"]


def _fake_ndi(steps_body):
    root = tempfile.mkdtemp()
    path = os.path.join(root, bpo.NDI_LOCAL)
    os.makedirs(os.path.dirname(path))
    text = ("function result = local(path, options)\n"
            "    convertResult = did2.convert.v1_to_v2(bodies);\n"
            "    tStep = migrateStepMark('pass 1 v1_to_v2', tStart, tStep, convertResult);\n"
            + steps_body +
            "    convertResult.migrated = ndi.migrate.internal.carryUnchangedAsV1(convertResult.migrated);\n"
            "    tStep = migrateStepMark('carryUnchangedAsV1', tStart, tStep, convertResult);\n"
            "end\n\n"
            "function r = wrapEpochMint(r)\n"
            "    r = did2.convert.epochMint(r);\n"
            "end\n")
    with open(path, "w") as fh:
        fh.write(text)
    return root


def _decl(reads="NONE -- x", adds="NONE -- x", changes="NONE -- x",
          removes="NONE -- x"):
    return "".join("    %% %s%s: %s\n" % (P, e, v) for e, v in
                   zip(bpo.EFFECTS, (reads, adds, changes, removes)))


def test_ndi_steps_are_found_declared_wrapped_and_ordered():
    body = ("    % an NDI step that reads the epochs epochMint mints\n"
            + _decl(reads="entity(epoch)") +
            "    convertResult = readsEpochs(convertResult);\n"
            "    tStep = migrateStepMark('readsEpochs', tStart, tStep, convertResult);\n"
            "    convertResult = wrapEpochMint(convertResult);\n"
            "    tStep = migrateStepMark('epochMint', tStart, tStep, convertResult);\n"
            "    convertResult = noDeclaration(convertResult);\n"
            "    tStep = migrateStepMark('undeclared', tStart, tStep, convertResult);\n")
    root = _fake_ndi(body)
    out = bpo.check(None, root)
    comp = out["compositions"][-1]
    print("  DENOMINATOR: %d NDI step(s) of %d marked"
          % (out["ndi"]["second_pass_steps"], out["ndi"]["steps_marked"]))
    assert out["ndi"]["second_pass_steps"] == 3
    assert comp["order"] == ["NDI step 'readsEpochs'", "did2.convert.epochMint",
                             "NDI step 'undeclared'"], comp["order"]
    assert any("NDI step 'undeclared': NO DECLARATION" in e
               for e in out["errors"]), out["errors"]
    assert any("readsEpochs" in v and "R1" in v for v in comp["violations"]), \
        comp["violations"]


def test_ndi_second_pass_of_the_checkout():
    root = os.environ.get("NDI_MATLAB")
    if not root:
        print("  NOT CHECKED: $NDI_MATLAB is not set")
        return
    out = bpo.check(None, root)
    print("  DENOMINATOR: %d NDI second-pass step(s) of %d marked in %s"
          % (out["ndi"].get("second_pass_steps", 0), out["ndi"]["steps_marked"],
             out["ndi"]["path"]))
    assert out["ndi"].get("second_pass_steps", 0) > 0
    assert not out["errors"], "; ".join(out["errors"])


if __name__ == "__main__":
    failures = 0
    for fn in [v for k, v in sorted(globals().items()) if k.startswith("test_")]:
        print(fn.__name__)
        try:
            fn()
            print("PASS %s" % fn.__name__)
        except AssertionError as err:
            failures += 1
            print("FAIL %s\n  %s" % (fn.__name__, err))
    sys.exit(1 if failures else 0)
