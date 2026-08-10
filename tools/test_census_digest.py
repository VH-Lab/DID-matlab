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
from census_digest import (aslist, digest, norm_class,  # noqa: E402
                           normalised_class_index, render_report, rollup)


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


class TestMetadataTier(DigestCase):
    """metadata_editor vs the openMINDS dataset graph.

    NDI writes the two on independent paths (saveEditor2Doc.m on window-close;
    save_dataset_docs.m on the Save button), neither removes the other's store,
    and only `metadata_editor` has a migrator that produces the dataset /
    person / organization / funding / publication / web_resource tier. So a
    corpus with the graph and NO editor document migrates with its authors,
    funding and publications missing -- and the counts that would say whether
    that happens were already in the reports, unread.

    The keys these tests use are the ones MATLAB actually writes:
    `did2.validate.sourceCensus`'s `normClass` lowercases and STRIPS
    UNDERSCORES, so the source census is keyed `metadataeditor`. A test that
    fed the pretty spelling would pass against a lookup that can never match a
    real report -- the demo_ndi failure, in a test.
    """

    def _corpus(self, name, source_by_class=None, source_total=100,
                by_class=None, source_census="present"):
        body = {"corpus": name, "total": 10, "migrated_count": 10,
                "quarantine_count": 0}
        if by_class is not None:
            body["by_class"] = by_class
        if source_census == "present":
            body["source_census"] = {"total_docs": source_total,
                                     "skipped_docs": 0,
                                     "by_class": source_by_class or {}}
        elif source_census == "failed":
            body["source_census"] = {"audit_failed": "boom"}
        elif source_census == "empty":
            body["source_census"] = {"total_docs": 0, "skipped_docs": 0,
                                     "by_class": {}}
        self.write(name, body)

    def test_counts_are_read_from_the_normalised_source_census_keys(self):
        # sourceCensus.m: `normClass` = lower + strip underscores. Looking the
        # class up by its pretty name would return 0 for every real corpus.
        self._corpus("A", {"metadataeditor": 1, "openminds": 8},
                     source_total=78688)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("1  metadata_editor", text)
        self.assertIn("8  openminds ", text)
        self.assertIn("78688 doc(s) read", text)

    def test_the_normaliser_matches_both_spellings(self):
        self.assertEqual(norm_class("metadata_editor"), "metadataeditor")
        idx = normalised_class_index({"metadataeditor": 2,
                                      "metadata_editor": 3})
        self.assertEqual(idx["metadataeditor"]["count"], 5,
                         "two spellings of one class must sum, not shadow")

    def test_graph_without_editor_is_named_per_corpus_and_in_the_rollup(self):
        # THE OPEN QUESTION this block exists to answer.
        self._corpus("JH", {"openminds": 8}, source_total=78688)
        text, _ = self.run_digest()
        self.assertIn("graph=8, editor=0 -> GRAPH WITHOUT EDITOR", text)
        self.assertIn("migrate", text)
        self.assertIn("1  GRAPH WITHOUT EDITOR   JH", text)

    def test_editor_without_graph_and_both_are_distinct_verdicts(self):
        self._corpus("Editor", {"metadataeditor": 1})
        self._corpus("Both", {"metadataeditor": 1, "openminds": 4})
        text, _ = self.run_digest()
        self.assertIn("graph=0, editor=1 -> EDITOR WITHOUT GRAPH", text)
        self.assertIn("graph=4, editor=1 -> BOTH", text)
        self.assertIn("1  BOTH                   Both", text)
        self.assertIn("1  EDITOR WITHOUT GRAPH   Editor", text)

    def test_a_measured_zero_prints_as_a_zero(self):
        # The other half of the distinction: a corpus that WAS measured and
        # holds neither class must print explicit zeros, not silence.
        self._corpus("Clean", {"subject": 12})
        text, _ = self.run_digest()
        self.assertIn("0  metadata_editor", text)
        self.assertIn("0  openminds ", text)
        self.assertIn("graph=0, editor=0 -> NEITHER", text)

    def test_a_corpus_with_no_source_census_is_NOT_rendered_as_zeros(self):
        # THE WHOLE POINT. "It has neither" and "we never counted" must not
        # print the same -- this project has shipped the absence of that
        # distinction twice.
        self._corpus("NoCensus", source_census="absent")
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED", text)
        self.assertIn("no v1 source census block", text)
        self.assertNotIn("0  metadata_editor", text)
        self.assertNotIn("-> NEITHER", text)

    def test_a_failed_source_census_says_so_rather_than_counting(self):
        self._corpus("Failed", source_census="failed")
        text, _ = self.run_digest()
        self.assertIn("the v1 source census FAILED (boom)", text)
        self.assertNotIn("0  metadata_editor", text)

    def test_a_census_that_read_nothing_is_not_a_zero_either(self):
        # total_docs=0 is the silentLoss failure verbatim: the instrument read
        # nothing, so its zeros describe nothing.
        self._corpus("Nothing", source_census="empty")
        text, _ = self.run_digest()
        self.assertIn("the v1 source census read 0 document(s)", text)
        self.assertNotIn("-> NEITHER", text)

    def test_sibling_openminds_classes_are_counted_but_not_folded_in(self):
        # openminds_subject is the subject bundle, not the dataset graph.
        # Folding it into the graph total would manufacture a co-occurrence.
        self._corpus("S", {"openmindssubject": 40, "metadataeditor": 1})
        text, _ = self.run_digest()
        self.assertIn("40  openminds_subject", text)
        self.assertIn("graph=0, editor=1 -> EDITOR WITHOUT GRAPH", text)

    def test_an_unexpected_openminds_class_is_surfaced_not_dropped(self):
        self._corpus("X", {"openmindsnewthing": 3})
        text, _ = self.run_digest()
        self.assertIn("3  openmindsnewthing", text)
        self.assertIn("ANOTHER openminds_* class", text)

    def test_no_extras_says_so_explicitly(self):
        self._corpus("X", {"openminds": 1})
        text, _ = self.run_digest()
        self.assertIn("no openminds_* class outside the expected list", text)

    def test_absence_from_the_migrated_by_class_is_not_read_as_absent_source(self):
        # THE INVERSION THIS BLOCK MUST NOT MAKE. The top-level `by_class` is
        # the MIGRATED-OUTPUT histogram: `metadata_editor` is missing from it
        # exactly WHEN THE MIGRATION WORKED. The source count must still show 1.
        self._corpus("Migrated", {"metadataeditor": 1},
                     by_class={"dataset": 1, "person": 4, "organization": 2})
        text, _ = self.run_digest()
        self.assertIn("1  metadata_editor", text)
        self.assertIn("dataset=1, person=4, organization=2", text)

    def test_a_report_with_no_by_class_says_the_emitted_tier_is_unmeasured(self):
        self._corpus("NoBC", {"metadataeditor": 1})
        text, _ = self.run_digest()
        self.assertIn("migrated dataset tier: NOT MEASURED", text)

    def test_the_rollup_denominator_excludes_and_names_unmeasured_corpora(self):
        self._corpus("Has", {"openminds": 8}, source_total=50)
        self._corpus("Missing", source_census="absent")
        text, _ = self.run_digest()
        self.assertIn("2 corpus report(s); 1 carried a readable v1 source "
                      "census, 1 did not; 50 v1 source doc(s) read in total",
                      text)
        self.assertIn("*** NOT MEASURED in: Missing", text)
        self.assertIn("sums over 1 corpora, not 2", text)

    def test_the_rollup_sums_the_classes_across_corpora(self):
        self._corpus("A", {"openminds": 8, "metadataeditor": 1})
        self._corpus("B", {"openminds": 2})
        text, _ = self.run_digest()
        self.assertIn("10  openminds", text)
        self.assertIn("1  metadata_editor", text)
        self.assertIn("1  BOTH", text)
        self.assertIn("1  GRAPH WITHOUT EDITOR   B", text)

    def test_the_rollup_prints_every_bucket_even_at_zero(self):
        self._corpus("A", {"openminds": 8, "metadataeditor": 1})
        text, _ = self.run_digest()
        self.assertIn("0  EDITOR WITHOUT GRAPH   --", text)
        self.assertIn("0  NEITHER                --", text)

    def test_the_rollup_totals_the_emitted_tier_from_by_class(self):
        self._corpus("A", {"metadataeditor": 1},
                     by_class={"dataset": 1, "person": 3})
        self._corpus("B", {"metadataeditor": 1},
                     by_class={"dataset": 1, "person": 5, "funding": 2})
        text, _ = self.run_digest()
        self.assertIn("dataset=2, person=8, organization=0, funding=2", text)


class TestInspectedRollupArithmetic(DigestCase):
    """The cross-corpus `inspected` total, and the 26 it was once off by.

    DID-schema/CLAUDE.md records 562,422 documents inspected for corpus run
    31415147934. The six per-corpus `silent-loss: inspected` lines in that
    run's own digest log sum to 562,448. The difference is corpus B, whose
    block reads

        total=12917  migrated=13778  quarantine=0
        silent-loss: inspected 13804 doc(s), skipped 0

    and 1484 + 13778 + 29168 + 336136 + 31 + 181825 = 562,422 exactly: the
    recorded figure took B's `migrated_count` where the other five took
    `inspected`. That run predates this rollup (it ran at 02854c7; the rollup
    landed in f9defe3), so the number was hand-summed -- the digest's
    arithmetic was never involved and is not what is wrong.

    These tests pin the arithmetic to the real figures so the same
    substitution cannot be made silently again.
    """

    # (corpus, total, migrated_count, silent-loss total_docs) from the digest
    # log of run 31415147934, job "Census digest" (93561591223).
    RUN_31415147934 = [
        ("20211116", 1220, 1484, 1484),
        ("B", 12917, 13778, 13804),
        ("Dab", 27561, 33955, 29168),
        ("JH", 78688, 336132, 336136),
        ("PRED", 14, 31, 31),
        ("Soph", 101427, 181760, 181825),
    ]

    def _write_the_real_run(self):
        for name, total, migrated, inspected in self.RUN_31415147934:
            self.write(name, {
                "corpus": name, "total": total, "migrated_count": migrated,
                "quarantine_count": 0, "fragment_count": 0,
                "silent_loss": {"total_docs": inspected, "skipped_docs": 0,
                                "empty_dependency_count": 0,
                                "vacuous_field_count": 0}})

    def test_the_recorded_562422_is_the_migrated_substitution(self):
        # Pure arithmetic, no digest involved: this is the identity that
        # identifies the error, and it must keep holding for the note above to
        # stay true.
        inspected = sum(r[3] for r in self.RUN_31415147934)
        swapped = sum(r[2] if r[0] == "B" else r[3]
                      for r in self.RUN_31415147934)
        self.assertEqual(inspected, 562448)
        self.assertEqual(swapped, 562422)
        self.assertEqual(inspected - swapped, 26)

    def test_the_rollup_reproduces_562448_from_the_real_reports(self):
        self._write_the_real_run()
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("6 corpus report(s) summed; 6 carried a readable "
                      "silent-loss audit; 562448 document(s) inspected in "
                      "total", text)
        self.assertNotIn("562422", text)

    def test_the_addends_are_printed_and_named(self):
        # The total is only checkable if its inputs are beside it. They were
        # not, and a hand re-derivation picked up the adjacent counter.
        self._write_the_real_run()
        text, _ = self.run_digest()
        self.assertIn("addends -- silent-loss `inspected`, NOT `migrated` and "
                      "NOT `total`:", text)
        self.assertIn("20211116 1484 + B 13804 + Dab 29168 + JH 336136 + "
                      "PRED 31 + Soph 181825 = 562448", text)

    def test_the_rollup_sums_inspected_and_never_migrated_count(self):
        # Written so it cannot pass by coincidence: migrated_count is larger
        # than total_docs in one corpus and smaller in the other, so summing
        # the wrong field gives a different number either way.
        self.write("Big", {
            "corpus": "Big", "total": 1, "migrated_count": 900,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 100, "skipped_docs": 0,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0}})
        self.write("Small", {
            "corpus": "Small", "total": 1, "migrated_count": 5,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 50, "skipped_docs": 0,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0}})
        text, _ = self.run_digest()
        self.assertIn("150 document(s) inspected in total", text)
        self.assertNotIn("905 document(s) inspected", text)

    def test_a_corpus_with_no_audit_contributes_no_addend(self):
        self.write("Good", {
            "corpus": "Good", "total": 1, "migrated_count": 1,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 7, "skipped_docs": 0,
                            "empty_dependency_count": 0,
                            "vacuous_field_count": 0}})
        self.write("Bad", {"corpus": "Bad", "total": 1, "migrated_count": 1,
                           "quarantine_count": 0,
                           "silent_loss": {"audit_failed": "boom"}})
        text, _ = self.run_digest()
        self.assertIn("Good 7 = 7", text)
        self.assertNotIn("Bad 0", text)


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
