#!/usr/bin/env python3
"""Tests for tools/corpus_proven.py -- the step that carries a corpus run's
evidence to did-schema's CORPUS-PROVEN rung.

Run: python3 tools/test_corpus_proven.py

EVERY CASE HERE IS A FAILURE THIS PROJECT HAS ALREADY PAID FOR, or the exact
inversion of one:

  * zero reports found, reported as a clean zero and exit 0 (corpus run #3:
    six green corpora, ten files written, `NO CORPUS REPORTS FOUND`, exit 0);
  * a one-level search against a path `upload-artifact` had moved one level
    down (the same run, and the cause of it);
  * absence rendered as a pass -- a class in no corpus reading as proven;
  * a counter the report does not carry, summed as a zero;
  * a failure attributed to one of several sources sharing a target.

The verdict itself is NOT tested here. It belongs to did-schema's
`coverage.py`, is tested there, and is invoked across the repo boundary by a
function these tests replace with a stub -- so what is under test is this
side's finding, feeding, cross-checking and reporting, which is the only part
this repository owns.
"""

import io
import json
import os
import contextlib
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from corpus_proven import (analyse, attribution_census,  # noqa: E402
                           corpus_row, find_reports, norm_class, render)


def report(corpus, classes, **kw):
    """A corpus report in the shape writeCorpusReport.m actually writes."""
    rep = {
        "corpus": corpus,
        "total": kw.get("total", 100),
        "migrated_count": kw.get("migrated_count", 100),
        "quarantine_count": kw.get("quarantine_count", 0),
        "by_class": {"subject": 1},
        "quarantine_reasons": kw.get("quarantine_reasons", []),
        "fragment_count": kw.get("fragment_count", 0),
        "fragment_by_class": kw.get("fragment_by_class", {}),
        "silent_loss": {"empty_required_dependency":
                        kw.get("empty_required_dependency", [])},
        "source_census": {"total_docs": kw.get("census_total", 100),
                          "skipped_docs": 0,
                          "by_class": {norm_class(c): n
                                       for c, n in classes.items()}},
    }
    if kw.get("with_reference_integrity", True):
        rep["reference_integrity"] = {"edges_examined": 50,
                                      "orphans": kw.get("orphans", []),
                                      "orphan_count": kw.get("orphan_count", 0)}
    if "source_census" in kw:
        rep["source_census"] = kw["source_census"]
    return rep


def ledger_row(v1_class, targets=(), state="not measured", why="", **kw):
    return {
        "v1_class": v1_class,
        "targets": list(targets),
        "decided_targets": list(kw.get("decided_targets", ())),
        "second_pass": list(kw.get("second_pass", ())),
        "stage": {"stage5_state": state,
                  "ladder": [{"stage": 5, "name": "CORPUS-PROVEN",
                              "state": state, "why": why}]},
    }


class Case(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.schema = os.path.join(self.dir, "did-schema")
        os.makedirs(os.path.join(self.schema, "schemas"))
        self.ledger_rows = []

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    # --- fixture plumbing --------------------------------------------------

    def write_report(self, relpath, rep):
        path = os.path.join(self.dir, relpath)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            json.dump(rep, fh)

    def stub_coverage(self, ran=True, exit_code=0):
        """Stand in for `coverage.py --corpus-reports`, writing the ledger it
        would write. The interface is invoked, never reimplemented."""
        def run(schema_repo, roots):
            if not ran:
                return {"ran": False, "why": "stubbed as unavailable",
                        "schema_repo": schema_repo, "roots": list(roots)}
            with open(os.path.join(schema_repo, "schemas",
                                   "V_eta_coverage_ledger.json"), "w") as fh:
                json.dump({"rows": self.ledger_rows}, fh)
            return {"ran": True, "exit_code": exit_code, "stdout": "",
                    "command": "stub", "schema_repo": schema_repo,
                    "roots": list(roots)}
        return run

    def run_tool(self, roots, gate=False, runner=None):
        cwd = os.getcwd()
        os.chdir(self.dir)
        try:
            state = analyse(roots, self.schema, gate,
                            run_coverage_fn=runner or self.stub_coverage())
        finally:
            os.chdir(cwd)
        return state, "\n".join(render(state, []))

    # --- the denominator ---------------------------------------------------

    def test_the_denominator_prints_first_and_unconditionally(self):
        # Rule 5. And it must print in the failing case too -- "found nothing"
        # and "looked in the wrong place" are distinguishable only from this.
        state, text = self.run_tool(["corpus-reports", "tests/corpus-reports"])
        first = text.split("\n")[1]
        self.assertIn("DENOMINATOR:", first)
        self.assertIn("2 root(s) named", first)
        self.assertIn("2 MISSING", first)
        self.assertIn("director(ies) walked", first)
        self.assertIn("0 file(s) matched", first)

    # --- MUTATION 1: an empty reports directory ----------------------------

    def test_zero_reports_is_a_non_zero_exit_not_a_clean_zero(self):
        # THE EXIT CODE ALONE DOES NOT CATCH THIS, and that is worth knowing:
        # deleting the zero-reports gate leaves the NEXT gate (no readable
        # source census) firing, so the step still exits 1 while DIAGNOSING
        # the wrong thing -- "none carried a readable census" for a run where
        # nothing was found at all. The assertion on the message is what
        # actually holds the line, so it is not decoration.
        os.makedirs(os.path.join(self.dir, "corpus-reports"))
        state, text = self.run_tool(["corpus-reports"])
        self.assertNotEqual(state["exit_code"], 0,
                            "zero reports MUST fail the step -- run #3 exited 0")
        self.assertIn("NO CORPUS REPORTS FOUND", text)
        self.assertEqual(state["rung"], None)
        self.assertNotIn("PROVEN (`yes`)", text)

    def test_reports_present_but_no_readable_source_census_also_fails(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {}, source_census={"audit_failed": "boom"}))
        state, text = self.run_tool(["corpus-reports"])
        self.assertNotEqual(state["exit_code"], 0)
        self.assertIn("NONE carried a readable v1 source census", text)
        # The failure is NAMED per corpus, not just counted.
        self.assertIn("the source census FAILED in the run", text)

    # --- MUTATION 4: the search narrowed to one level -----------------------

    def test_the_search_is_recursive_over_every_root(self):
        # The artifact-download layout: `upload-artifact` given two search
        # paths promotes the artifact root to their least common ancestor, so
        # the downloaded copy lands two directories below the named root.
        self.write_report("corpus-reports/tests/corpus-reports/B-summary.json",
                          report("B", {"subject": 3}))
        self.ledger_rows = [ledger_row("subject", ["subject"], "yes", "clean")]
        state, text = self.run_tool(["corpus-reports", "tests/corpus-reports"])
        self.assertEqual(state["find_denominator"]["files_matched"], 1)
        self.assertEqual(state["exit_code"], 0)
        self.assertIn("PROVEN   subject", text)

    def test_a_duplicate_basename_is_reported_not_silently_collapsed(self):
        rep = report("B", {"subject": 3})
        self.write_report("corpus-reports/B-summary.json", rep)
        self.write_report("tests/corpus-reports/B-summary.json", rep)
        self.ledger_rows = [ledger_row("subject", ["subject"], "yes", "clean")]
        state, text = self.run_tool(["corpus-reports", "tests/corpus-reports"])
        self.assertEqual(len(state["find_denominator"]["duplicate_basenames"]), 1)
        self.assertIn("*** DUPLICATE B-summary.json", text)
        self.assertIn("coverage.py does not de-duplicate", text)

    # --- MUTATION 2: a class absent from every corpus, rendered as proven ---

    def test_a_class_in_no_corpus_may_not_come_back_proven(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        self.ledger_rows = [
            ledger_row("subject", ["subject"], "yes", "clean"),
            # `element` is in NO census. Whatever produced this, it is absence
            # rendered as a result.
            ledger_row("element", ["element"], "yes", "clean"),
        ]
        state, text = self.run_tool(["corpus-reports"])
        self.assertNotEqual(state["exit_code"], 0)
        self.assertIn("THE RUNG CONTRADICTS THE CENSUS", text)
        self.assertIn("`element` is rung `yes` while 0 document(s)", text)

    def test_a_class_in_no_corpus_reads_not_measured_and_is_counted(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        self.ledger_rows = [
            ledger_row("subject", ["subject"], "yes", "clean"),
            ledger_row("element", ["element"], "not measured", "0 documents"),
        ]
        state, text = self.run_tool(["corpus-reports"])
        self.assertEqual(state["exit_code"], 0)
        self.assertEqual(state["rung"]["yes"], 1)
        self.assertEqual(state["rung"]["not_measured"], 1)
        self.assertEqual(state["rung"]["absent_from_corpora"], 1)
        self.assertIn("A SAMPLE OF DATASETS, NOT THE UNIVERSE", text)

    # --- ABSENT IS NOT ZERO ------------------------------------------------

    def test_an_absent_counter_is_not_a_zero_and_blocks_global_cleanliness(self):
        # testCorpusPRED never calls did2.validate.references, so PRED's report
        # carries no `reference_integrity` at all.
        rep = report("PRED", {"subject": 2}, with_reference_integrity=False)
        self.write_report("corpus-reports/PRED-summary.json", rep)
        self.ledger_rows = [ledger_row("subject", ["subject"], "not measured")]
        state, text = self.run_tool(["corpus-reports"])
        row = state["corpora"][0]
        self.assertIsNone(row["orphan_count"])
        self.assertFalse(row["globally_clean"])
        self.assertIn("(absent)", text)
        self.assertIn("`orphan_count` is ABSENT from the report -- NOT a zero",
                      text)

    # --- MUTATION 3: a failure over a target several sources share ---------

    def test_a_failure_over_a_shared_target_is_named_ambiguous_never_guessed(self):
        self.write_report("corpus-reports/D-summary.json", report(
            "D", {"alpha": 4, "beta": 4, "gamma": 4}, quarantine_count=9,
            quarantine_reasons=[{"class_name": "alpha", "reason": "x",
                                 "count": 9}]))
        self.ledger_rows = [
            # alpha and beta both reach `shared_target`; a fault recorded
            # against it cannot be pinned to either.
            ledger_row("alpha", ["shared_target"], "no", "D: 9 quarantined"),
            ledger_row("beta", ["shared_target"], "no", "D: 9 quarantined"),
            ledger_row("gamma", ["gamma_only"], "no", "D: 9 quarantined"),
        ]
        state, text = self.run_tool(["corpus-reports"])
        amb = {d["v1_class"] for d in state["ambiguous"]["D"]}
        self.assertEqual(amb, {"alpha", "beta"},
                         "a source whose every target is shared is AMBIGUOUS; "
                         "one with a target of its own is not")
        self.assertIn("AMBIGUOUS BY CONSTRUCTION", text)
        self.assertIn("alpha", text)
        self.assertIn("1 shared target(s), up to 1 other source(s) reach them",
                      text)
        self.assertIn("EVERY target shared", text)
        # `gamma` reaches a target no other source reaches, so its failure IS
        # attributable and it must not appear in the ambiguous list.
        self.assertNotIn("gamma  ", text.split("AMBIGUOUS BY CONSTRUCTION")[1])
        # The per-class quarantine table the report DOES carry is printed, so
        # the conservative corpus-level verdict is visible as conservative.
        self.assertIn("coverage.py reads no per-class quarantine", text)
        self.assertIn("9  alpha", text)

    def test_a_globally_clean_corpus_states_that_attribution_never_happened(self):
        self.write_report("corpus-reports/C-summary.json",
                          report("C", {"subject": 5}))
        self.ledger_rows = [ledger_row("subject", ["subject"], "yes", "clean")]
        state, text = self.run_tool(["corpus-reports"])
        self.assertIn("ATTRIBUTION WAS", text)
        self.assertIn("NEVER PERFORMED", text)
        self.assertEqual(state["ambiguous"], {})

    # --- the rung is report-only by default --------------------------------

    def test_a_failed_rung_reports_and_does_not_fail_the_step_by_default(self):
        self.write_report("corpus-reports/E-summary.json",
                          report("E", {"subject": 5}, quarantine_count=2))
        self.ledger_rows = [ledger_row("subject", ["subject"], "no",
                                       "E: 2 quarantined document(s)")]
        state, text = self.run_tool(["corpus-reports"])
        self.assertEqual(state["exit_code"], 0)
        self.assertIn("FAILED   subject", text)
        self.assertIn("REPORT-ONLY", text)
        state, _ = self.run_tool(["corpus-reports"], gate=True)
        self.assertNotEqual(state["exit_code"], 0)

    # --- the interface, when it is not there -------------------------------

    def test_an_absent_interface_is_reported_not_routed_around(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        state, text = self.run_tool(["corpus-reports"],
                                    runner=self.stub_coverage(ran=False))
        self.assertNotEqual(state["exit_code"], 0)
        self.assertIn("THE INTERFACE IS NOT AVAILABLE", text)
        self.assertIn("The verdict is NOT recomputed here", text)
        self.assertIsNone(state["rung"])

    def test_the_real_runner_names_a_missing_coverage_py(self):
        from corpus_proven import run_coverage
        out = run_coverage(os.path.join(self.dir, "nope"), ["x"])
        self.assertFalse(out["ran"])
        self.assertIn("did-schema checkout is not at", out["why"])
        out = run_coverage(self.schema, ["x"])
        self.assertFalse(out["ran"])
        self.assertIn("does not exist", out["why"])
        os.makedirs(os.path.join(self.schema, "tools"))
        with open(os.path.join(self.schema, "tools", "coverage.py"), "w") as fh:
            fh.write("# no interface here\n")
        out = run_coverage(self.schema, ["x"])
        self.assertFalse(out["ran"])
        self.assertIn("--corpus-reports", out["why"])
        self.assertIn("load_corpus_evidence", out["why"])

    def test_a_restructured_ledger_is_an_instrument_fault_not_a_default(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        self.ledger_rows = [{"v1_class": "subject", "targets": ["subject"]}]
        state, text = self.run_tool(["corpus-reports"])
        self.assertNotEqual(state["exit_code"], 0)
        self.assertIn("NO recognised stage-5 state", text)


class AttributionCensusCase(unittest.TestCase):
    def test_both_censuses_state_their_own_method(self):
        rows = [ledger_row("a", ["t1"], decided_targets=["t2"]),
                ledger_row("b", ["t1"]),
                ledger_row("c", ["t3"], second_pass=["t4"])]
        out = attribution_census(rows)
        rec = out["recorded"]
        # RECORDED: targets + decided_targets, pairs with multiplicity.
        self.assertEqual(rec["pairs"], 4)
        self.assertEqual(rec["distinct_targets"], 3)      # t1, t2, t3
        self.assertEqual(rec["targets_from_exactly_one_source"], 2)
        self.assertEqual(rec["targets_from_more_than_one_source"], 1)   # t1
        self.assertEqual(rec["sources_all_of_whose_targets_are_shared"], 1)
        # ATTRIBUTION: + second_pass + the source class itself.
        att = out["attribution"]
        self.assertEqual(att["pairs"], 5 + 3)
        self.assertIn("t4", att["sources_of"])
        self.assertIn("a", att["sources_of"]["a"])


class CorpusRowCase(unittest.TestCase):
    def test_a_one_row_struct_array_arrives_as_a_bare_object(self):
        # MATLAB's jsonencode writes a 1-element struct array as an object.
        row = corpus_row("p", {"corpus": "X", "quarantine_count": 0,
                               "fragment_count": 0,
                               "reference_integrity": {"orphan_count": 0},
                               "silent_loss": {"empty_required_dependency":
                                               {"class_name": "image_stack",
                                                "edge_name": "subject_id",
                                                "count": 4563}}})
        self.assertEqual(row["empty_required_edge_rows"], 1)
        self.assertEqual(row["empty_required_edge_classes"], ["imagestack"])
        self.assertFalse(row["globally_clean"])


class FindReportsCase(unittest.TestCase):
    def test_a_missing_root_is_reported_and_not_fatal(self):
        with tempfile.TemporaryDirectory() as d:
            os.makedirs(os.path.join(d, "there"))
            open(os.path.join(d, "there", "Z-summary.json"), "w").write("{}")
            paths, den = find_reports([os.path.join(d, "nowhere"),
                                       os.path.join(d, "there")])
            self.assertEqual(len(paths), 1)
            self.assertEqual(len(den["roots_missing"]), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
