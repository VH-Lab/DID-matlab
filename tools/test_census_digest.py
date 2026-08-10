#!/usr/bin/env python3
"""Tests for tools/census_digest.py.

Every case here is a shape that ACTUALLY OCCURRED in a corpus report and broke
the digest when it lived in a YAML heredoc. They run in under a second; the
defects they cover previously took a ~3-hour corpus run to surface.

Run: python3 tools/test_census_digest.py
"""

import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from census_digest import aslist, digest, render_report, rollup  # noqa: E402


class TestAsList(unittest.TestCase):
    def test_matlab_single_struct_becomes_a_one_element_list(self):
        # jsonencode writes a 1-element struct array as a bare object. Slicing
        # that with [:10] raises KeyError: slice(None, 10, None) -- the crash
        # that killed run #256 after 2h49m.
        self.assertEqual(aslist({"count": 45}), [{"count": 45}])

    def test_multi_row_array_passes_through(self):
        self.assertEqual(aslist([{"a": 1}, {"a": 2}]), [{"a": 1}, {"a": 2}])

    def test_absent_field_is_empty(self):
        self.assertEqual(aslist(None), [])


class DigestCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir, ignore_errors=True)

    def write(self, name, obj):
        with open(os.path.join(self.dir, name + "-summary.json"), "w") as fh:
            json.dump(obj, fh)

    def run_digest(self):
        lines, failed = digest(self.dir)
        return "\n".join(lines), failed


class TestDigest(DigestCase):
    def test_single_row_vacuous_field_does_not_crash(self):
        # The EXACT shape from run #256: Dab had 45 vacuous-field occurrences
        # across one (class, block, field) row, so MATLAB emitted an object.
        self.write("Dab", {
            "corpus": "Dab", "total": 27561, "migrated_count": 110086,
            "quarantine_count": 0,
            "silent_loss": {
                "total_docs": 110086, "skipped_docs": 0,
                "empty_dependency_count": 84593, "vacuous_field_count": 45,
                "empty_required_dependency": [
                    {"count": 24685, "class_name": "intensity_observation",
                     "edge_name": "subject_id"}],
                "vacuous_required_field": {
                    "count": 45, "class_name": "x", "block": "b",
                    "field_name": "f"},
            }})
        text, failed = self.run_digest()
        self.assertEqual(failed, [], "single-row object must render, not fail")
        self.assertIn("24685  intensity_observation.subject_id", text)
        self.assertIn("45  x / b.f", text)

    def test_total_docs_is_always_printed(self):
        # A census that inspected nothing must not read as a clean result.
        self.write("Empty", {
            "corpus": "Empty", "total": 10, "migrated_count": 10,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 0, "skipped_docs": 0,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0}})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("inspected 0 doc(s)", text)
        self.assertIn("THE CENSUS INSPECTED NOTHING", text)

    def test_all_skipped_is_called_out(self):
        self.write("Skip", {
            "corpus": "Skip", "total": 5, "migrated_count": 5,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 5, "skipped_docs": 5,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0}})
        text, _ = self.run_digest()
        self.assertIn("every document was skipped", text)

    def test_one_bad_report_does_not_suppress_the_others(self):
        # Run #256's real cost: a crash on corpus 3 of 5 meant corpora 4 and 5
        # -- the two LARGEST -- never printed at all.
        self.write("Good1", {"corpus": "Good1", "total": 1,
                             "migrated_count": 1, "quarantine_count": 0})
        with open(os.path.join(self.dir, "Bad-summary.json"), "w") as fh:
            fh.write("{not json")
        self.write("Good2", {"corpus": "Good2", "total": 2,
                             "migrated_count": 2, "quarantine_count": 0})
        text, failed = self.run_digest()
        self.assertIn("Good1", text)
        self.assertIn("Good2", text, "a later corpus must still print")
        self.assertEqual(len(failed), 1)
        self.assertIn("UNREADABLE", text)

    def test_failure_is_still_reported_nonzero(self):
        with open(os.path.join(self.dir, "Bad-summary.json"), "w") as fh:
            fh.write("{not json")
        _, failed = self.run_digest()
        self.assertTrue(failed, "an unreadable report must not exit clean")

    def test_no_reports_is_a_failure_not_a_quiet_zero(self):
        # INVERTED, not updated. This test used to assert `failed == []` --
        # the same premise the code held, so it could not catch the code. Run
        # #3 (31315510527) then printed "NO CORPUS REPORTS FOUND" and exited
        # 0 while five downloaded artifacts sat one directory deeper, and the
        # census job went green having aggregated nothing.
        text, failed = self.run_digest()
        self.assertIn("NO CORPUS REPORTS FOUND", text)
        self.assertTrue(failed, "an empty digest must not exit clean")

    def test_reports_found_at_any_depth(self):
        # The REAL layout from run #3, reproduced exactly: MATLAB writes to
        # `<pwd>/corpus-reports/` with pwd = `tests/`, upload-artifact roots
        # the zip at the repo root, and download-artifact --path corpus-reports
        # unpacks it one level deeper still.
        deep = os.path.join(self.dir, "tests", "corpus-reports")
        os.makedirs(deep)
        with open(os.path.join(deep, "Deep-summary.json"), "w") as fh:
            json.dump({"corpus": "Deep", "total": 7, "migrated_count": 7,
                       "quarantine_count": 0}, fh)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("Deep", text)
        self.assertIn("total=7", text)

    def test_the_same_corpus_at_two_depths_is_read_once(self):
        # The two-path upload can carry both copies. Collapse to one, and SAY
        # that one was collapsed -- a silently deduped denominator is the
        # thing rule 5 exists to prevent.
        body = {"corpus": "Dup", "total": 3, "migrated_count": 3,
                "quarantine_count": 0}
        self.write("Dup", body)
        deep = os.path.join(self.dir, "tests", "corpus-reports")
        os.makedirs(deep)
        with open(os.path.join(deep, "Dup-summary.json"), "w") as fh:
            json.dump(body, fh)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("1 corpus report(s)", text)
        self.assertIn("1 duplicate(s) collapsed", text)

    def test_search_denominator_precedes_everything(self):
        self.write("A", {"corpus": "A", "total": 1, "migrated_count": 1,
                         "quarantine_count": 0})
        text, _ = self.run_digest()
        first = text.splitlines()[0]
        self.assertIn("REPORT SEARCH", first)
        self.assertIn("1 file(s)", first)

    def test_family_violation_count_is_printed_even_when_zero(self):
        # Unconditional, like total_docs. A number that only appears when
        # non-zero cannot be distinguished from a number nobody computed.
        self.write("F", {
            "corpus": "F", "total": 1, "migrated_count": 1,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 1, "skipped_docs": 0,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0,
                            "family_violation_count": 0},
        })
        text, _ = self.run_digest()
        self.assertIn("0 edge-family cardinality violation(s)", text)

    def test_family_violation_rows_name_declared_and_found(self):
        self.write("G", {
            "corpus": "G", "total": 1, "migrated_count": 1,
            "quarantine_count": 0,
            "silent_loss": {
                "total_docs": 9, "skipped_docs": 0,
                "empty_dependency_count": 0, "vacuous_field_count": 0,
                "family_violation_count": 4,
                # single row arrives as a bare object, not a list
                "family_count_violation": {
                    "count": 4, "class_name": "subject_interaction",
                    "edge_name": "time_reference_#",
                    "declared": "min 1", "found": 0},
            },
        })
        text, _ = self.run_digest()
        self.assertIn("4 edge-family cardinality violation(s)", text)
        self.assertIn("subject_interaction.time_reference_#", text)
        self.assertIn("declared min 1, found 0", text)

    def test_several_roots_are_searched_and_one_missing_is_not_fatal(self):
        # test-code.yml digests `corpus-reports` from the repo root while the
        # corpora write to `tests/corpus-reports`; that step has been printing
        # NO REPORTS FOUND for exactly one directory's worth of offset.
        other = os.path.join(self.dir, "elsewhere")
        os.makedirs(other)
        with open(os.path.join(other, "Far-summary.json"), "w") as fh:
            json.dump({"corpus": "Far", "total": 2, "migrated_count": 2,
                       "quarantine_count": 0}, fh)
        lines, failed = digest([os.path.join(self.dir, "absent"), other])
        text = "\n".join(lines)
        self.assertEqual(failed, [])
        self.assertIn("total=2", text)

    def test_missing_directory_says_so(self):
        lines, failed = digest(os.path.join(self.dir, "nope"))
        text = "\n".join(lines)
        self.assertIn("the directory itself does not exist", text)
        self.assertTrue(failed)

    def test_quarantine_reasons_single_object(self):
        self.write("Q", {
            "corpus": "Q", "total": 1, "migrated_count": 0,
            "quarantine_count": 1,
            "quarantine_reasons": {"count": 1, "class_name": "c",
                                   "reason": "required endpoints missing"}})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("required endpoints missing", text)



class SourceCensusRendering(unittest.TestCase):
    """The v1 SOURCE census block: three pre-build measurements, denominator first."""

    def _render(self, sc):
        out = []
        render_report({"corpus": "X", "source_census": sc}, out)
        return "\n".join(out)

    def test_reports_its_denominator_first(self):
        txt = self._render({"total_docs": 1234, "skipped_docs": 2,
                            "docs_with_epoch_id": 10, "distinct_epoch_ids": 3})
        self.assertIn("read 1234 v1 doc(s), 2 unreadable", txt)

    def test_zero_documents_is_called_out_not_rendered_as_clean(self):
        # The silentLoss failure: an all-zero census is indistinguishable from a
        # clean one unless the denominator is checked and shouted about.
        txt = self._render({"total_docs": 0, "skipped_docs": 0,
                            "synthetic_epoch_id_count": 0,
                            "session_doc_count": 0, "approach_doc_count": 0})
        self.assertIn("READ NOTHING", txt)
        self.assertNotIn("grouping hazard", txt)

    def test_grouping_hazard_names_the_fusion_factor(self):
        txt = self._render({
            "total_docs": 9, "skipped_docs": 0,
            "synthetic_epoch_id_count": 1, "cross_session_epoch_id_count": 0,
            "synthetic_epoch_ids": [{"epoch_id": "whole_session_r",
                                     "distinct_elements": 7, "doc_count": 12}]})
        self.assertIn("would fuse    7 element span(s): whole_session_r", txt)

    def test_absent_session_document_is_shouted_not_printed_as_a_zero(self):
        txt = self._render({"total_docs": 9, "skipped_docs": 0,
                            "session_doc_count": 0, "distinct_session_ids": 1})
        self.assertIn("would have no", txt)

    def test_a_failed_census_says_so(self):
        txt = self._render({"audit_failed": "boom"})
        self.assertIn("AUDIT FAILED (boom)", txt)



class TestRollup(DigestCase):
    """The cross-corpus total -- the number that actually gets quoted.

    Every one of these drives `digest()` end to end rather than calling
    `rollup()` on a hand-built list, because the defect this guards against is
    a SUM taken over the wrong set of reports, and a hand-built list would fix
    the set by construction. Same trap as a test written from the code's own
    premise.
    """

    def _two_corpora(self):
        self.write("A", {
            "corpus": "A", "total": 100, "migrated_count": 100,
            "quarantine_count": 0, "fragment_count": 0,
            "silent_loss": {
                "total_docs": 100, "skipped_docs": 0,
                "empty_dependency_count": 11, "vacuous_field_count": 0,
                "empty_required_dependency": {
                    "count": 11, "class_name": "stimulus_presentation",
                    "edge_name": "element_id"}}})
        self.write("B", {
            "corpus": "B", "total": 200, "migrated_count": 200,
            "quarantine_count": 0, "fragment_count": 0,
            "silent_loss": {
                "total_docs": 200, "skipped_docs": 0,
                "empty_dependency_count": 1242, "vacuous_field_count": 0,
                "empty_required_dependency": [
                    {"count": 1242, "class_name": "stimulus_presentation",
                     "edge_name": "element_id"},
                    {"count": 7, "class_name": "other_class",
                     "edge_name": "subject_id"}]}})

    def test_the_same_row_in_two_corpora_is_summed_into_one_line(self):
        # The actual failure this exists to prevent: the row set was quoted as
        # three classes when it was six, and the per-corpus split is exactly
        # what made a hand sum hard enough to get wrong.
        self._two_corpora()
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("1253  stimulus_presentation.element_id", text)
        self.assertIn("EMPTY REQUIRED EDGES: 1260 document(s) across 2 row(s)", text)

    def test_the_denominator_names_how_many_corpora_went_into_the_sum(self):
        self._two_corpora()
        text, _ = self.run_digest()
        self.assertIn("2 corpus report(s) summed", text)
        self.assertIn("300 document(s) inspected in total", text)

    def test_a_corpus_with_no_audit_is_excluded_AND_said_so(self):
        # A total over four corpora and a total over six must not print
        # identically. This is the "0 empty edges while reading nothing"
        # failure, one layer up.
        self._two_corpora()
        self.write("C", {"corpus": "C", "total": 5, "migrated_count": 5,
                         "quarantine_count": 0,
                         "silent_loss": {"audit_failed": "boom"}})
        text, _ = self.run_digest()
        self.assertIn("3 corpus report(s) summed; 2 carried a readable", text)
        self.assertIn("contributed NO silent-loss numbers", text)
        self.assertIn("sums over 2 corpora, not 3", text)

    def test_zero_everywhere_still_prints_every_section(self):
        # Suppressing an empty section would make "we measured it and it was
        # clean" indistinguishable from "we never measured it".
        self.write("Clean", {
            "corpus": "Clean", "total": 3, "migrated_count": 3,
            "quarantine_count": 0, "fragment_count": 0,
            "silent_loss": {"total_docs": 3, "skipped_docs": 0,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0}})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("EMPTY REQUIRED EDGES: 0 document(s) across 0 row(s)", text)
        self.assertIn("VACUOUS REQUIRED FIELDS: 0 document(s)", text)
        self.assertIn("EDGE-FAMILY CARDINALITY VIOLATIONS: 0 document(s)", text)
        self.assertIn("(none)", text)

    def test_a_broken_rollup_does_not_destroy_the_per_corpus_output(self):
        # Run #256's lesson, applied to the new code: an exception in the
        # aggregate must not take the six individual reports with it.
        self._two_corpora()
        import census_digest
        real = census_digest.rollup
        census_digest.rollup = lambda reports, out: 1 / 0
        try:
            text, failed = self.run_digest()
        finally:
            census_digest.rollup = real
        self.assertIn("<rollup>", failed)
        self.assertIn("CROSS-CORPUS ROLLUP FAILED", text)
        self.assertIn("--- A ---", text)
        self.assertIn("--- B ---", text)


class TestPostPassRendering(DigestCase):
    """The batch post-pass block (`epoch_mint`, `session_anchor_fold`).

    WHY THESE EXIST. `epoch_mint` was written into every corpus report from the
    day the pass landed and this digest never rendered it -- the number reached
    the artifact and stopped there, which is write-only, which is the condition
    this whole file exists to remove. `session_anchor_fold` was the sibling case
    one step earlier: the pass was built and not called at all, and no artifact
    could say so. Both defects are absence-shaped, so the tests below are mostly
    about what the digest prints when something is NOT there.
    """

    def _fold(self, **over):
        rep = {
            "documents_inspected": 1000, "documents_unreadable": 0,
            "session_documents_seen": 2, "anchors_seen": 40,
            "anchors_relative": 30, "anchors_bounded": 10,
            "anchors_folded": 40, "refused_total": 0,
            "refused_no_session_id": 0, "refused_no_session_document": 0,
            "refused_ambiguous_session": 0, "refused_ambiguous_relation": 0,
            "refused_unknown_relation": 0, "refused_negative_extent": 0,
            "fold_quarantined": 0, "ran": True,
        }
        rep.update(over)
        return rep

    def _mint(self, **over):
        rep = {
            "documents_inspected": 1000, "documents_unreadable": 0,
            "session_documents_seen": 2, "epoch_strings_read": 12,
            "distinct_epoch_id_strings": 7,
            "distinct_session_epoch_pairs": 9, "pairs_minus_strings": 2,
            "epochs_found_existing": 0, "epochs_minted": 9,
            "skipped_synthetic": 0, "skipped_no_session_id": 0,
            "skipped_no_session_document": 0, "skipped_ambiguous_session": 0,
            "method_parameters_seen": 3, "method_parameters_edges_filled": 3,
            "method_parameters_unresolved": 0, "mint_quarantined": 0,
            "ran": True,
        }
        rep.update(over)
        return rep

    def _corpus(self, name="A", **fields):
        body = {"corpus": name, "total": 100, "migrated_count": 1000,
                "quarantine_count": 0,
                "silent_loss": {"total_docs": 1000, "skipped_docs": 0,
                                "empty_dependency_count": 0,
                                "vacuous_field_count": 0}}
        body.update(fields)
        self.write(name, body)

    def test_epoch_mint_is_rendered_at_all(self):
        # The whole defect: it was in the report and not on the screen.
        self._corpus("A", epoch_mint=self._mint())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("did2.convert.epochMint", text)
        self.assertIn("epochs minted", text)
        self.assertIn("epochs the string key would have FUSED", text)

    def test_session_anchor_fold_is_rendered(self):
        self._corpus("A", session_anchor_fold=self._fold())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("did2.convert.resolveSessionAnchors", text)
        self.assertIn("FOLDED to relative_reference", text)

    def test_an_absent_pass_says_NOT_WIRED_rather_than_printing_zeros(self):
        # The exact condition that let resolveSessionAnchors sit unwired for a
        # day: no output at all. Zeros would be WORSE -- they would read as a
        # pass that ran and found nothing.
        self._corpus("A")
        text, _ = self.run_digest()
        self.assertIn("batch post-passes: 2 expected, 0 present", text)
        self.assertIn("NOT IN THIS REPORT", text)
        self.assertNotIn("FOLDED to relative_reference", text)

    def test_a_guarded_failure_is_a_banner_not_a_silence(self):
        self._corpus("A", session_anchor_fold={
            "pass": "did2.convert.resolveSessionAnchors",
            "pass_failed": "Index exceeds the number of array elements.",
            "pass_failed_identifier": "MATLAB:badsubscript", "ran": False})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("*** FAILED: Index exceeds", text)
        self.assertIn("MATLAB:badsubscript", text)
        self.assertIn("PASS-1 FORM", text)

    def test_a_no_op_pass_is_distinct_from_a_failed_one(self):
        self._corpus("A", epoch_mint={"ran": False, "documents_inspected": 0})
        text, _ = self.run_digest()
        self.assertIn("did not run (non-V_eta target, or an empty batch)", text)
        self.assertNotIn("*** FAILED", text)

    def test_a_missing_counter_prints_absent_not_zero(self):
        # A counter the report does not carry has NOT been measured. Printing 0
        # is the all-zeros-reads-as-clean failure in miniature.
        rep = self._fold()
        del rep["refused_negative_extent"]
        self._corpus("A", session_anchor_fold=rep)
        text, _ = self.run_digest()
        self.assertIn("(absent)    end < start", text)

    def test_deletion_gate_needs_both_halves(self):
        # refused_total == 0 alone is NOT the gate: a surviving
        # session_*_reference in by_class means documents still exist for a
        # class somebody might delete. epochfiles_ingested cost 2,484
        # quarantines exactly this way.
        self._corpus("A", session_anchor_fold=self._fold(),
                     by_class={"session_relative_reference": 5})
        text, _ = self.run_digest()
        self.assertIn("surviving session_*_reference in by_class=5", text)
        self.assertNotIn("BOTH HALVES MET", text)

    def test_deletion_gate_reports_when_both_halves_are_met(self):
        self._corpus("A", session_anchor_fold=self._fold(),
                     by_class={"relative_reference": 40})
        text, _ = self.run_digest()
        self.assertIn("BOTH HALVES MET", text)
        self.assertIn("are a SAMPLE", text)

    def test_rollup_flags_a_pass_that_ran_on_some_corpora_and_not_others(self):
        # THE THREE-OF-FOUR TRAP at the data level: healthy in every block it
        # appears in, invisible in the ones it does not.
        self._corpus("A", session_anchor_fold=self._fold())
        self._corpus("B")
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("ran in 1 of 2 report(s)", text)
        self.assertIn("*** NOT PRESENT in: B", text)
        self.assertIn("do not read the", text)

    def test_rollup_sums_only_the_corpora_that_carried_the_pass(self):
        self._corpus("A", session_anchor_fold=self._fold(anchors_folded=40))
        self._corpus("B", session_anchor_fold=self._fold(anchors_folded=60))
        text, _ = self.run_digest()
        self.assertIn("ran in 2 of 2 report(s)", text)
        self.assertIn("100  FOLDED to relative_reference", text)

    def test_rollup_separates_failed_from_absent(self):
        self._corpus("A", epoch_mint=self._mint())
        self._corpus("B", epoch_mint={"pass_failed": "boom", "ran": False})
        self._corpus("C")
        text, _ = self.run_digest()
        self.assertIn("ran in 1 of 3 report(s); 1 absent, 1 FAILED, 0 no-op",
                      text)
        self.assertIn("*** FAILED in: B", text)
        self.assertIn("*** NOT PRESENT in: C", text)

    def test_absent_everywhere_is_not_reported_as_absent_in_some(self):
        # "ran on some corpora and not others" would be FALSE when the pass is
        # in no report at all -- and that is the state the harness was actually
        # in before this change, so it is the state the digest must name
        # correctly.
        self._corpus("A")
        self._corpus("B")
        text, _ = self.run_digest()
        self.assertIn("NOT PRESENT IN ANY REPORT: A, B", text)
        self.assertIn("not wired into the harness", text)
        self.assertNotIn("some corpora and not others", text)

    def test_a_malformed_post_pass_field_does_not_kill_the_corpus_block(self):
        # MATLAB can encode an empty struct as [] -> null, or a caller can hand
        # us a list. Neither may take the report down; run #256's lesson.
        self._corpus("A", session_anchor_fold=[1, 2, 3])
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("MALFORMED", text)
        self.assertIn("--- A ---", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
