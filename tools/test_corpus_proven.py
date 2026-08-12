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
  * a failure attributed to one of several sources sharing a target;
  * a ladder computed over a SMALLER UNIVERSE than the one on record, written
    and rendered and exited 0 (run 31587869672: 91 v1 rows instead of 102,
    `rung 1  10 yes / 81 no` instead of 86/16, every job green).

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
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from corpus_proven import (analyse, attribution_census,  # noqa: E402
                           committed_ledger_classes, corpus_row, find_reports,
                           norm_class, render, universe_check)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKFLOW = os.path.join(REPO, ".github", "workflows", "test-corpus.yml")


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
    """A ledger row in the shape the COMMITTED coverage.py writes."""
    return {
        "v1_class": v1_class,
        "targets": list(targets),
        "decided_targets": list(kw.get("decided_targets", ())),
        "second_pass": list(kw.get("second_pass", ())),
        "stage": {"stage5_state": state,
                  "ladder": [{"stage": 5, "name": "CORPUS-PROVEN",
                              "state": state, "why": why}]},
    }


def renumbered_row(v1_class, targets=(), state="not measured", why=""):
    """The same row after the ladder was renumbered under this reader.

    Observed, not invented: a coverage.py restructure in flight moves
    CORPUS-PROVEN from rung 5 to rung 4 and renames `stage5_state` to
    `corpus_rung_state`. The ENTRY NAME is what survives both.
    """
    return {
        "v1_class": v1_class, "targets": list(targets),
        "decided_targets": [], "second_pass": [],
        "stage": {"corpus_rung_state": state,
                  "ladder": [{"stage": 1, "name": "a migrator CONSUMES it",
                              "state": "yes", "why": ""},
                             {"stage": 4, "name": "CORPUS-PROVEN",
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

    def commit_ledger(self, classes):
        """Make the fake did-schema checkout a real git repo whose HEAD carries
        a ledger over `classes`.

        A REAL `git show`, not a stub, because the thing under test is whether
        the baseline can be READ -- and every way that read fails (no git, no
        commit, no file) is a way this check quietly stops checking.
        """
        if shutil.which("git") is None:               # pragma: no cover
            self.skipTest("git is not on PATH")
        path = os.path.join(self.schema, "schemas",
                            "V_eta_coverage_ledger.json")
        with open(path, "w") as fh:
            json.dump({"rows": [ledger_row(c, [c]) for c in classes]}, fh)
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                   GIT_CONFIG_SYSTEM=os.devnull)
        run = lambda *a: subprocess.run(a, cwd=self.schema, env=env,
                                        stdout=subprocess.DEVNULL,
                                        stderr=subprocess.DEVNULL, check=True)
        run("git", "init", "-q")
        run("git", "add", "--", "schemas")
        run("git", "-c", "user.email=t@example.invalid", "-c", "user.name=t",
            "commit", "-q", "-m", "ledger")

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

    def test_the_rung_is_found_by_NAME_so_a_renumbered_ladder_still_reads(self):
        # Pinning the read to `stage == 5` returned None on every row of the
        # renumbered shape, and a reader that defaulted that to `not measured`
        # would have printed 0 PROVEN / 0 FAILED / N NOT MEASURED -- a broken
        # read wearing the exact costume of an honest measurement.
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        self.ledger_rows = [renumbered_row("subject", ["subject"], "yes",
                                           "5 documents, 0 quarantine")]
        state, text = self.run_tool(["corpus-reports"])
        self.assertEqual(state["exit_code"], 0)
        self.assertEqual(state["rung"]["yes"], 1)
        self.assertEqual(state["rung"]["unknown"], 0)
        self.assertIn("PROVEN   subject", text)

    def test_the_ladder_entry_name_alone_is_enough_to_find_the_rung(self):
        # THE PREVIOUS TEST DOES NOT PIN THE NAME-BASED READ, and that was
        # found by mutation: replacing the name match with `stage == 5` left
        # the whole suite green, because the observed restructure ALSO carries
        # `corpus_rung_state` and the key fallback caught it. Two mechanisms,
        # two shapes, one test each -- a fixture that exercises both at once
        # pins neither.
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        row = renumbered_row("subject", ["subject"], "yes", "clean")
        del row["stage"]["corpus_rung_state"]          # ladder entry only
        self.ledger_rows = [row]
        state, _text = self.run_tool(["corpus-reports"])
        self.assertEqual(state["rung"]["yes"], 1)
        self.assertEqual(state["rung"]["unknown"], 0)

    def test_a_top_level_state_key_alone_is_enough_too(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        row = renumbered_row("subject", ["subject"], "yes", "clean")
        row["stage"]["ladder"] = [{"stage": 1, "name": "a migrator CONSUMES it",
                                   "state": "yes", "why": ""}]
        self.ledger_rows = [row]
        state, _text = self.run_tool(["corpus-reports"])
        self.assertEqual(state["rung"]["yes"], 1)
        self.assertEqual(state["rung"]["unknown"], 0)

    # --- MUTATION 5: a ledger REWRITTEN over a SMALLER UNIVERSE -------------
    #
    # The mtime gate above catches "coverage.py wrote nothing" (run
    # 31572667236). Run 31587869672 WROTE -- and wrote 91 v1 rows where the
    # committed ledger carries 102, because DID_MATLAB did not resolve on the
    # runner, so the migrator scan was skipped and the 11 vhlab
    # app/calculator classes with no NDI template were dropped. The rung
    # rendered `10 yes / 81 no` for a ladder whose committed answer is 86/16,
    # and every job was green. Not "measured nothing" -- measured a smaller
    # world, silently, and exited 0.

    def test_a_shrunken_universe_is_an_instrument_fault_naming_both_counts(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        committed = ["subject"] + ["class_%02d" % i for i in range(1, 102)]
        self.commit_ledger(committed)                 # 102 rows at HEAD
        self.ledger_rows = [ledger_row(c, [c], "not measured", "0 documents")
                            for c in committed[:91]]  # 91 rows regenerated
        state, text = self.run_tool(["corpus-reports"])
        self.assertNotEqual(state["exit_code"], 0,
                            "a ladder computed over 91 of 102 classes is not a "
                            "smaller answer, it is an answer to a different "
                            "question -- and run 31587869672 exited 0")
        self.assertIn("THE V1 UNIVERSE SHRANK UNDER THE REGENERATION", text)
        # BOTH counts named, in the fault itself, not only in the render.
        fault = "\n".join(state["instrument_faults"])
        self.assertIn("wrote 91 v1 row(s)", fault)
        self.assertIn("carries 102", fault)
        # And the missing classes NAMED, so the cause is diagnosable from the
        # log alone -- 11 classes dropping out is a different fault from one.
        self.assertEqual(len(state["universe"]["missing"]), 11)
        self.assertIn("class_101", fault)
        self.assertIn("MISSING FROM THE REGENERATED LEDGER  class_101", text)
        # It is an INSTRUMENT fault, not a migration defect: the ladder was
        # computed over the wrong world, which says nothing about migration.
        self.assertEqual(state["rung"]["no"], 0)

    def test_an_equal_or_larger_universe_is_not_a_fault(self):
        # The universe legitimately GROWS -- NDI adds templates, and the count
        # has moved before. Only a shrink is a fault.
        for label, regenerated in (
                ("equal", ["subject", "alpha", "beta"]),
                ("larger", ["subject", "alpha", "beta", "gamma"])):
            with self.subTest(label):
                shutil.rmtree(self.dir, ignore_errors=True)
                self.setUp()
                self.write_report("corpus-reports/A-summary.json",
                                  report("A", {"subject": 5}))
                self.commit_ledger(["subject", "alpha", "beta"])
                self.ledger_rows = [
                    ledger_row(c, [c], "not measured", "0 documents")
                    for c in regenerated]
                state, text = self.run_tool(["corpus-reports"])
                self.assertEqual(state["exit_code"], 0)
                self.assertEqual(state["universe"]["committed"], 3)
                self.assertEqual(state["universe"]["regenerated"],
                                 len(regenerated))
                self.assertIsNone(state["universe"]["fault"])
                self.assertIn("no shrink", text)
                self.assertNotIn("SHRANK", text)

    def test_an_unreadable_baseline_is_NOT_EVALUATED_never_a_silent_pass(self):
        # No git, no commit, no file -- three ways the baseline read fails, and
        # every one of them is a check that DID NOT HAPPEN. The one thing it
        # may never look like is agreement.
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        self.ledger_rows = [ledger_row("subject", ["subject"], "yes", "clean")]
        state, text = self.run_tool(["corpus-reports"])   # self.schema: no .git
        self.assertFalse(state["universe"]["evaluated"])
        self.assertIsNone(state["universe"]["committed"])
        self.assertIsNone(state["universe"]["fault"])
        self.assertIn("NOT EVALUATED", text)
        self.assertIn("is not a git checkout", text)
        self.assertIn("This is NOT a pass", text)
        self.assertNotIn("no shrink", text)

    def test_the_baseline_read_names_each_way_it_can_fail(self):
        # Exercised against the REAL function, the way the mtime check is.
        if shutil.which("git") is None:                # pragma: no cover
            self.skipTest("git is not on PATH")
        classes, why = committed_ledger_classes(self.schema)
        self.assertIsNone(classes)
        self.assertIn("is not a git checkout", why)

        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull,
                   GIT_CONFIG_SYSTEM=os.devnull)
        subprocess.run(["git", "init", "-q"], cwd=self.schema, env=env,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=True)
        classes, why = committed_ledger_classes(self.schema)
        self.assertIsNone(classes, "an empty repo has no HEAD to read")
        self.assertIn("git", why)

        self.commit_ledger(["subject", "alpha"])
        classes, why = committed_ledger_classes(self.schema)
        self.assertIsNone(why)
        self.assertEqual(classes, ["subject", "alpha"])
        # And the ledger ON DISK is deliberately not the baseline: the run
        # overwrites it, so reading it back would compare a file to itself.
        with open(os.path.join(self.schema, "schemas",
                               "V_eta_coverage_ledger.json"), "w") as fh:
            json.dump({"rows": [ledger_row("subject", ["subject"])]}, fh)
        classes, why = committed_ledger_classes(self.schema)
        self.assertEqual(classes, ["subject", "alpha"],
                         "the baseline must come from `git show HEAD:`, never "
                         "from the working copy the run just rewrote")

    def test_a_same_size_ledger_with_different_names_reports_and_does_not_fault(self):
        # Nothing measured says a rename is an instrument problem. It is
        # reported and NOT judged -- inventing a verdict is the error this
        # whole file is against.
        out = universe_check([{"v1_class": "a"}, {"v1_class": "renamed"}],
                             ["a", "b"], None)
        self.assertIsNone(out["fault"])
        self.assertEqual(out["missing"], ["b"])
        self.assertEqual(out["added"], ["renamed"])

    def test_a_restructured_ledger_is_an_instrument_fault_not_a_default(self):
        self.write_report("corpus-reports/A-summary.json",
                          report("A", {"subject": 5}))
        self.ledger_rows = [{"v1_class": "subject", "targets": ["subject"]}]
        state, text = self.run_tool(["corpus-reports"])
        self.assertNotEqual(state["exit_code"], 0)
        self.assertIn("NO recognised stage-5 state", text)


def rung_step_env_scoped():
    """The `env:` mapping of the census job's rung step, by a SCOPED read.

    NOT a grep of the whole file: `DID_MATLAB` appearing SOMEWHERE in
    test-corpus.yml says nothing about whether the step that invokes
    corpus_proven.py carries it, and the six corpus jobs above it are a
    different job entirely. The scope is narrowed twice -- to the `census:`
    job, then to the step named `Per-class corpus proof` -- before a single
    key is read.

    Implemented without a YAML dependency and cross-checked against one when
    it imports (below), so the reader that always runs is the one that is
    always exercised. Comment lines are skipped: this env block is mostly
    comment, on purpose.
    """
    with open(WORKFLOW) as fh:
        lines = fh.read().split("\n")
    job = [i for i, ln in enumerate(lines) if ln == "  census:"]
    if len(job) != 1:
        raise AssertionError("expected exactly one `  census:` job header, "
                             "found %d" % len(job))
    start = job[0]
    end = next((i for i in range(start + 1, len(lines))
                if re.match(r"^  \S.*:\s*$", lines[i])), len(lines))
    steps = [i for i in range(start, end)
             if re.match(r"^      - name: .*Per-class corpus proof", lines[i])]
    if len(steps) != 1:
        raise AssertionError("expected exactly one `Per-class corpus proof` "
                             "step in the census job, found %d" % len(steps))
    s0 = steps[0]
    s1 = next((i for i in range(s0 + 1, end)
               if re.match(r"^      - ", lines[i])), end)
    envs = [i for i in range(s0, s1) if lines[i] == "        env:"]
    if not envs:
        return {}
    out = {}
    for ln in lines[envs[0] + 1:s1]:
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        if not ln.startswith("          "):           # dedent ends the block
            break
        m = re.match(r"^          ([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", ln)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out


class CensusJobWiringCase(unittest.TestCase):
    """The rung step must export BOTH sibling paths.

    WHY A TEST AND NOT A COMMENT. `coverage.py`'s `find_repo` tries `$ENV`,
    `/home/user/<name>`, then `<dirname of the did-schema root>/<name>`. On a
    runner `/home/user` does not exist and did-schema sits at
    `$GITHUB_WORKSPACE/did-schema`, so the third candidate is
    `$GITHUB_WORKSPACE/DID-matlab` -- which does not exist, because the
    workspace IS the DID-matlab checkout. `DID_MATLAB` came back None, the
    migrator scan was skipped, and the ladder was rendered over 91 classes.
    NDI_MATLAB resolves today WITHOUT the var, by the accident of being
    checked out at a path the third candidate matches; a future reader
    deleting it as redundant is the failure this test exists to stop.
    """

    def test_the_rung_step_exports_both_sibling_paths(self):
        env = rung_step_env_scoped()
        self.assertEqual(env.get("DID_MATLAB"), "${{ github.workspace }}",
                         "the workspace IS the DID-matlab checkout")
        self.assertEqual(env.get("NDI_MATLAB"),
                         "${{ github.workspace }}/NDI-matlab")

    def test_the_scoped_read_agrees_with_a_yaml_parser(self):
        # The scoped reader is the one that always runs, so it is the one that
        # must not rot. When PyYAML is present, a second parse of the same
        # step is a free cross-check of the reader itself.
        try:
            import yaml
        except ImportError:                            # pragma: no cover
            self.skipTest("PyYAML not installed; the scoped read stands alone")
        with open(WORKFLOW) as fh:
            doc = yaml.safe_load(fh)
        steps = [s for s in doc["jobs"]["census"]["steps"]
                 if "Per-class corpus proof" in str(s.get("name", ""))]
        self.assertEqual(len(steps), 1)
        self.assertEqual(steps[0].get("env"), rung_step_env_scoped())
        # And the step really is the one that runs this tool -- an env block
        # on the wrong step is exactly as useless as no env block.
        self.assertIn("tools/corpus_proven.py", steps[0]["run"])


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
