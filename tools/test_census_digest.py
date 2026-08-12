#!/usr/bin/env python3
"""Tests for tools/census_digest.py.

Every case here is a shape that ACTUALLY OCCURRED in a corpus report and broke
the digest when it lived in a YAML heredoc. They run in under a second; the
defects they cover previously took a ~3-hour corpus run to surface.

Run: python3 tools/test_census_digest.py
"""

import contextlib
import io
import json
import os
import shutil
import sys
import tempfile
import re
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# The tool's own source, for the handful of tests that assert on what it
# SAYS rather than on what it computes.
DIGEST_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "census_digest.py")
from census_digest import (TRF_NOT_SHAPEABLE, aslist, digest,  # noqa: E402
                           edge_arity, edge_arity_pivot,
                           epoch_association, ndi_required,
                           ndi_required_names, norm_class,
                           normalised_class_index, render_report, rollup,
                           time_reference_families, trf_shape_regime)


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
        # THE EXPECTED COUNT IS READ FROM THE DERIVED CHAIN, NOT FROM
        # POST_PASSES. This assertion used to read `len(POST_PASSES)`, with a
        # comment explaining that reading it from the table rather than writing
        # a literal kept it from going stale -- and the table was itself the
        # stale copy. It said 7 while the harness composed 9, so the test
        # certified a denominator that omitted two passes. Reading the source
        # of a number is only protection when it is the RIGHT source.
        import census_digest
        n = len(census_digest.post_pass_expectations())
        self.assertGreaterEqual(n, 3)
        self.assertIn("batch post-passes: %d expected" % n, text)
        self.assertIn("0 carry a report here", text)
        self.assertIn("NOT IN THIS REPORT", text)
        self.assertNotIn("FOLDED to relative_reference", text)
        # EVERY expected pass prints its own line, not just the first: a block
        # that named one pass and silently omitted the rest would be the exact
        # invisibility this whole section exists to remove.
        for field, fn, _cols in census_digest.POST_PASSES:
            self.assertIn(field, text)
            self.assertIn(fn, text)

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
class TestBoundedExtentCounters(DigestCase):
    """The bounded-extent group added with the extent refusals (2026-08-11).

    WHY A WHOLE CLASS FOR SEVEN COUNTERS. They exist because a
    `session_bounded_reference` whose `start`/`end` could not be READ used to
    fold with its window discarded, no counter moving, nothing quarantining --
    20,411 documents did, and the cross-corpus rollup that covered them printed
    `0 REFUSED` and was, line by line, correct. So the failure mode these
    counters guard against is a zero that cannot be told apart from a clean
    result, and a digest that renders them in a way that produces its own
    indistinguishable zero would reintroduce the defect one layer up. Every
    test here is about that: which zero is this.
    """

    def _fold(self, **over):
        """The FULL report shape, new counters included.

        Deliberately separate from TestPostPassRendering._fold, which is left
        WITHOUT the new keys so it keeps exercising the older-report path.
        """
        rep = {
            "documents_inspected": 1000, "documents_unreadable": 0,
            "session_documents_seen": 2, "anchors_seen": 40,
            "anchors_relative": 30, "anchors_bounded": 10,
            "anchors_folded": 40, "refused_total": 0,
            "refused_no_session_id": 0, "refused_no_session_document": 0,
            "refused_ambiguous_session": 0, "refused_ambiguous_relation": 0,
            "refused_unknown_relation": 0, "refused_negative_extent": 0,
            "refused_unreadable_extent_unit": 0, "refused_malformed_extent": 0,
            "refused_extent_without_start": 0,
            "bounded_extents_examined": 10, "bounded_with_start_field": 10,
            "bounded_with_end_field": 10, "bounded_blank_extent_cells": 0,
            "bounded_window_carried": 10, "bounded_start_only_carried": 0,
            "bounded_no_window_stated": 0,
            "fold_quarantined": 0, "ran": True,
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

    def test_the_extent_counters_are_rendered_at_all(self):
        # The epochMint defect, restated: a counter that reaches the artifact
        # and not the screen has not been reported to anybody.
        self._corpus("A", session_anchor_fold=self._fold())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("bounded extents EXAMINED", text)
        self.assertIn("extent unit the fold cannot read", text)
        self.assertIn("extent is not a duration cell", text)
        self.assertIn("an `end` with no readable `start`", text)

    def test_the_denominator_is_rendered_before_the_refusals(self):
        # Operating Rule 5 as an ordering assertion, not a presence one: the
        # examined count must appear ABOVE the refusal it qualifies, because a
        # reader who meets `0 refused` first has already formed the wrong
        # impression by the time the denominator arrives.
        self._corpus("A", session_anchor_fold=self._fold())
        text, _ = self.run_digest()
        self.assertLess(text.index("bounded extents EXAMINED"),
                        text.index("extent unit the fold cannot read"))

    def test_zero_examined_is_VACUOUS_not_clean(self):
        # The corpus has no bounded anchor at all. Every extent counter is 0 and
        # means nothing; saying so is the whole job.
        self._corpus("A", session_anchor_fold=self._fold(
            anchors_bounded=0, bounded_extents_examined=0,
            bounded_with_start_field=0, bounded_with_end_field=0,
            bounded_window_carried=0))
        text, _ = self.run_digest()
        self.assertIn("0 bounded extents were EXAMINED", text)
        self.assertIn("vacuous", text)
        self.assertIn("NOT 'no window was dropped'", text)

    def test_a_report_predating_the_counters_says_UNMEASURED(self):
        # An older artifact carries `session_anchor_fold` with none of the new
        # keys. It has not measured 0 windows dropped; it has measured nothing.
        rep = self._fold()
        for key in ("bounded_extents_examined", "bounded_with_start_field",
                    "bounded_with_end_field", "bounded_window_carried",
                    "bounded_start_only_carried", "bounded_no_window_stated",
                    "bounded_blank_extent_cells",
                    "refused_unreadable_extent_unit",
                    "refused_malformed_extent",
                    "refused_extent_without_start"):
            del rep[key]
        self._corpus("A", session_anchor_fold=rep)
        text, _ = self.run_digest()
        self.assertIn("NOT IN THIS REPORT", text)
        self.assertIn("UNMEASURED -- it is not zero", text)
        # and the individual rows still print `(absent)` rather than 0
        self.assertIn("(absent)  bounded extents EXAMINED", text)

    def test_a_dropped_window_is_visible_in_the_per_corpus_block(self):
        self._corpus("A", session_anchor_fold=self._fold(
            refused_unreadable_extent_unit=3, refused_total=3,
            anchors_folded=37, bounded_window_carried=7))
        text, _ = self.run_digest()
        self.assertIn("3    extent unit the fold cannot read", text)
        # the comparison a reader would otherwise have to make by eye
        self.assertIn("10 bod(ies) carried a `start` field and only 7 kept a",
                      text)

    def test_the_rollup_states_its_denominator_and_the_refused_total(self):
        self._corpus("A", session_anchor_fold=self._fold(
            bounded_extents_examined=10, refused_malformed_extent=2,
            refused_total=2))
        self._corpus("B", session_anchor_fold=self._fold(
            bounded_extents_examined=5, bounded_window_carried=5))
        text, _ = self.run_digest()
        self.assertIn("BOUNDED EXTENTS -- the reading of the group above", text)
        self.assertIn("DENOMINATOR: 15 bounded extent(s) examined across 2 "
                      "report(s)", text)
        self.assertIn("2  bod(ies) REFUSED because their extent could not be "
                      "carried", text)

    def test_a_zero_rollup_says_it_is_the_expected_reading_and_a_SAMPLE(self):
        self._corpus("A", session_anchor_fold=self._fold())
        text, _ = self.run_digest()
        self.assertIn("0 refused over 10 examined", text)
        self.assertIn("corpora are a SAMPLE", text)

    def test_a_rollup_over_zero_examined_is_VACUOUS_not_clean(self):
        self._corpus("A", session_anchor_fold=self._fold(
            anchors_bounded=0, bounded_extents_examined=0,
            bounded_with_start_field=0, bounded_with_end_field=0,
            bounded_window_carried=0))
        text, _ = self.run_digest()
        self.assertIn("0 examined -- every extent counter above is VACUOUS",
                      text)
        self.assertIn("not 'nothing dropped'", text)

    def test_a_rollup_with_no_carrier_of_the_counters_says_UNMEASURED(self):
        rep = self._fold()
        for key in list(rep):
            if key.startswith("bounded_") or key in (
                    "refused_unreadable_extent_unit", "refused_malformed_extent",
                    "refused_extent_without_start"):
                del rep[key]
        self._corpus("A", session_anchor_fold=rep)
        self._corpus("B", session_anchor_fold=dict(rep))
        text, _ = self.run_digest()
        self.assertIn("NOT CARRIED BY ANY OF THE 2 REPORT(S)", text)
        self.assertIn("UNMEASURED, and it is not the same as zero", text)

    def test_a_partial_sum_NAMES_the_reports_that_carried_no_counter(self):
        # THE legacy_ndi_document PATTERN, one level down. One report has the
        # counters and one does not, so the total is over half the corpora and
        # must not be printed as a whole-corpus figure.
        old = self._fold()
        for key in ("bounded_extents_examined", "bounded_window_carried"):
            del old[key]
        self._corpus("A", session_anchor_fold=self._fold(
            bounded_extents_examined=10))
        self._corpus("B", session_anchor_fold=old)
        text, _ = self.run_digest()
        self.assertIn("PARTIAL: summed over 1 of 2 report(s)", text)
        self.assertIn("SOME COUNTERS ARE SUMMED OVER FEWER REPORTS", text)
        self.assertIn("bounded_extents_examined", text)
        self.assertIn("no such counter in: B", text)

    def test_a_counter_present_everywhere_is_not_marked_partial(self):
        # The control. A banner that fired on a complete sum would train people
        # to ignore it, which is how a real partial sum gets through.
        self._corpus("A", session_anchor_fold=self._fold())
        self._corpus("B", session_anchor_fold=self._fold())
        text, _ = self.run_digest()
        self.assertNotIn("PARTIAL: summed over", text)
        self.assertNotIn("SOME COUNTERS ARE SUMMED OVER FEWER REPORTS", text)

    def test_the_blank_cell_row_says_it_is_cells_not_documents(self):
        # One body can contribute two, so it is not part of the seven-bucket
        # partition. A reader of the artifact does not have the source comment
        # that says so, hence the label.
        self._corpus("A", session_anchor_fold=self._fold(
            bounded_blank_extent_cells=4))
        text, _ = self.run_digest()
        self.assertIn("blank duration CELLS (not documents)", text)


class TestEpochAssociation(DigestCase):
    """The epoch-association block (#72) -- measurement only.

    WHAT IT MEASURES AND WHY NOTHING SAW IT. A statement reaches its epoch
    through a REFERENCE CHAIN, not a direct edge:

        subject_interaction --time_reference_#--> relative_reference
                            --relative_to-------> epoch

    `min_count: 1` guarantees the family exists and `relative_to` is REQUIRED,
    so a POPULATED reference resolves. But `time_reference_#` is
    `mustBeNonEmpty: false`, so `time_reference_1 = ''` satisfies the family and
    reaches nothing -- and the armed RequiredDependencies gate keys on
    `mustBeNonEmpty`. The two existing silent-loss checks step over it from
    opposite sides: the family check ignores what a member holds, the empty-edge
    check excludes numbered families outright.

    These tests are about the DISTINCTIONS, because every one of them is a place
    this project has previously collapsed two facts into one number: measured
    zero vs never measured, empty edge vs edge outside the batch, a count vs its
    denominator.
    """

    def _ea(self, **over):
        ea = {
            "docs_inspected": 1000, "docs_unreadable": 0, "docs_classified": 1000,
            "anchor_edge": "relative_to", "reference_root": "time_reference",
            "terminal_class": "epoch", "max_depth": 8,
            "terminal_class_in_schema": 1, "reference_root_in_schema": 1,
            "family_docs_declaring": 300, "family_docs_absent": 40,
            "family_docs_present": 260, "family_docs_all_empty": 60,
            "family_docs_populated": 200, "family_members_total": 270,
            "family_members_empty": 60, "family_members_populated": 210,
            "family_all_empty_by_class": [
                {"class_name": "voltage_observation",
                 "edge_name": "time_reference_#", "count": 60}],
            "epoch_documents": 11, "epoch_id_docs_declaring": 90,
            "epoch_id_edges_present": 90, "epoch_id_empty": 30,
            "epoch_id_resolved": 50, "epoch_id_resolved_not_epoch": 2,
            "epoch_id_unresolved_in_batch": 10,
            "epoch_id_by_class": [
                {"class_name": "directed_relation", "state": "empty",
                 "count": 30}],
            "chain_docs_examined": 200, "chain_docs_reaching_epoch": 120,
            "chain_docs_reaching_no_epoch": 50, "chain_docs_undetermined": 30,
            "chain_members_examined": 210, "chain_member_unresolved": 30,
            "chain_member_not_a_reference": 0,
            "chain_member_anchor_absent": 45, "chain_member_anchor_empty": 5,
            "chain_member_reaches_epoch": 125,
            "chain_member_reaches_other": 5, "chain_member_incomplete": 0,
            "chain_member_depth_exceeded": 0,
            "chain_member_unclassified": 0,
            "chain_terminus_by_class": [
                {"class_name": "session", "count": 5}],
        }
        ea.update(over)
        return ea

    def _corpus(self, name="A", ea=None, **over):
        sl = {"total_docs": 1000, "skipped_docs": 0,
              "empty_dependency_count": 0, "vacuous_field_count": 0}
        if ea is not None:
            sl["epoch_association"] = ea
        sl.update(over.pop("silent_loss", {}))
        body = {"corpus": name, "total": 100, "migrated_count": 1000,
                "quarantine_count": 0, "silent_loss": sl}
        body.update(over)
        self.write(name, body)

    # --- denominator first, unconditionally --------------------------------

    def test_the_denominator_is_printed_before_any_count(self):
        # Rule 5. The block states what it inspected before it states what it
        # found, so a count can never be read without one.
        self._corpus("A", self._ea())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        den = text.index("DENOMINATOR: 1000 document(s) inspected")
        cnt = text.index("REACH AN EPOCH")
        self.assertLess(den, cnt, "the denominator must precede the counts")

    def test_the_names_it_followed_are_printed(self):
        # The four names the block cannot derive from the schema. Printed so a
        # reader can see WHICH chain produced the numbers.
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("FOLLOWED: <family> -> `relative_to` -> `epoch`", text)

    def test_a_followed_class_that_does_not_load_is_shouted(self):
        # THE demo_ndi FAILURE, pre-empted: rename `epoch` and every
        # reaches-an-epoch count goes to zero for reasons that have nothing to
        # do with the data. The report must say so rather than read clean.
        self._corpus("A", self._ea(terminal_class_in_schema=0,
                                   chain_docs_reaching_epoch=0))
        text, _ = self.run_digest()
        self.assertIn("DOES NOT LOAD FROM THE SCHEMA", text)
        self.assertIn("property of the", text)

    def test_a_schema_that_loads_prints_no_banner(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertNotIn("DOES NOT LOAD FROM THE SCHEMA", text)

    # --- NOT MEASURED is never a row of zeros ------------------------------

    def test_a_report_without_the_block_is_not_rendered_as_zeros(self):
        # It predates the counter. Rendering zeros would assert a measurement
        # that was never taken -- the exact reading `silentLoss` shipped.
        self._corpus("A", None)
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED", text)
        self.assertIn("was not wired into the run", text)
        self.assertNotIn("REACH AN EPOCH", text)

    def test_a_block_that_inspected_nothing_is_not_a_zero(self):
        self._corpus("A", self._ea(docs_inspected=0))
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- it inspected 0 document(s)", text)

    def test_a_block_whose_every_document_was_unreadable_is_not_a_zero(self):
        self._corpus("A", self._ea(docs_inspected=5, docs_unreadable=5))
        text, _ = self.run_digest()
        self.assertIn("all 5 document(s) handed to it were unreadable", text)

    def test_a_failed_silent_loss_audit_says_so(self):
        self._corpus("A", None, silent_loss={"audit_failed": "boom"})
        text, _ = self.run_digest()
        self.assertIn("the silent-loss audit FAILED (boom)", text)

    def test_a_malformed_silent_loss_field_is_never_read_as_measured(self):
        # `"audit_failed" in sl` on a STRING is a substring test: it answers a
        # question nobody asked, and then the code proceeds as though the field
        # were readable. The reader is asserted directly because the rest of
        # the digest already treats this shape as a hard per-corpus failure
        # (loud, non-zero exit) and never reaches this block.
        for bad in ("boom", ["a"], 7):
            m = epoch_association({"corpus": "A", "silent_loss": bad})
            self.assertFalse(m["measured"], repr(bad))
            self.assertIn("malformed", m["why"])
        # ... and a real audit failure keeps its own, different wording.
        m = epoch_association({"silent_loss": {"audit_failed": "boom"}})
        self.assertFalse(m["measured"])
        self.assertIn("the silent-loss audit FAILED (boom)", m["why"])

    def test_a_malformed_block_says_so_rather_than_counting(self):
        self._corpus("A", "not-a-dict")
        text, failed = self.run_digest()
        self.assertEqual(failed, [], "a malformed block must not kill the corpus")
        self.assertIn("malformed", text)

    def _block(self, text):
        """Just the per-corpus epoch-association block.

        Scoped on purpose: "NOT MEASURED" appears in the metadata-tier block of
        the same output, and a whole-text assertion would pass or fail for
        reasons that have nothing to do with this measurement.

        The end marker moved from "METADATA TIER:" to the populations block
        when that block landed BETWEEN the two, for the same reason: the
        populations block says NOT MEASURED about `epoch_mint` and `by_class`,
        neither of which is this block's business. TestEpochPopulations owns
        those assertions.
        """
        start = text.index("EPOCH ASSOCIATION (#72): does a statement")
        end = text.index("EPOCH DOCUMENT POPULATIONS", start)
        return text[start:end]

    def test_a_measured_zero_prints_as_a_zero(self):
        # The other side of the same coin: measured-and-clean must be legible
        # as a result, not hidden behind the NOT MEASURED wording.
        self._corpus("A", self._ea(family_docs_all_empty=0,
                                   family_all_empty_by_class=[]))
        text, _ = self.run_digest()
        block = self._block(text)
        self.assertIn("0      <-- REACH NOTHING", block)
        self.assertNotIn("NOT MEASURED", block)

    # --- (1) the family: present-and-blank is the hole ---------------------

    def test_the_all_empty_family_row_is_rendered(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("REACH NOTHING: every member blank", text)
        self.assertIn("voltage_observation.time_reference_#", text)

    def test_a_single_row_object_does_not_crash(self):
        # MATLAB's jsonencode writes a ONE-element struct array as a bare
        # object. That shape killed run #256 after 2h49m; every list-shaped read
        # here goes through aslist for that reason.
        self._corpus("A", self._ea(
            family_all_empty_by_class={"class_name": "x",
                                       "edge_name": "time_reference_#",
                                       "count": 7},
            epoch_id_by_class={"class_name": "y", "state": "empty",
                               "count": 3},
            chain_terminus_by_class={"class_name": "session", "count": 1}))
        text, failed = self.run_digest()
        self.assertEqual(failed, [], "a one-row object must render, not fail")
        self.assertIn("x.time_reference_#", text)
        self.assertIn("y.epoch_id  empty", text)

    def test_no_class_declaring_a_family_is_called_untested(self):
        # Zero documents COULD carry one, so zero carrying one is not evidence.
        self._corpus("A", self._ea(family_docs_declaring=0))
        text, _ = self.run_digest()
        self.assertIn("NO DOCUMENT'S CLASS DECLARES A TIME-REFERENCE FAMILY",
                      text)
        self.assertIn("'untested', not 'clean'", text)

    # --- (2) three DISTINCT epoch_id states --------------------------------

    def test_the_three_epoch_id_states_are_printed_separately(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("RESOLVED -- names a document in this batch", text)
        self.assertIn("EMPTY -- names nothing", text)
        self.assertIn("NOT IN THIS BATCH", text)

    def test_unresolved_is_not_called_dangling(self):
        # A batch is a SAMPLE. jSessionAnchor's discovery-mode orphans were an
        # edge naming a document outside the batch, and calling them broken is
        # the error operating rule 3 names.
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("'not in this batch' is NOT 'dangling'", text)

    def test_an_epoch_id_resolving_to_a_non_epoch_is_surfaced(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("of those, the target is NOT an epoch", text)

    def test_epoch_document_count_is_printed(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("`epoch` document(s) in this batch", text)

    # --- (3) the chain --------------------------------------------------

    def test_the_chain_number_the_decision_rests_on_is_labelled(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("the number the decision rests on", text)

    def test_undetermined_is_a_third_state_not_a_failure(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("UNDETERMINED -- left the batch, or too deep", text)

    def test_no_populated_member_means_the_chain_was_never_walked(self):
        self._corpus("A", self._ea(chain_docs_examined=0,
                                   chain_docs_reaching_epoch=0))
        text, _ = self.run_digest()
        self.assertIn("the chain", text)
        self.assertIn("was never walked", text)
        self.assertIn("'untested', not 'nothing reaches one'", text)

    def test_a_missing_counter_prints_absent_not_zero(self):
        # A counter the report does not carry and a counter that is zero are
        # different facts. The rows come from the digest's own list, not from
        # the report's keys, so one cannot vanish.
        ea = self._ea()
        del ea["chain_member_depth_exceeded"]
        self._corpus("A", ea)
        text, _ = self.run_digest()
        self.assertIn("(absent)  ", text)
        self.assertIn("chain longer than max_depth", text)

    # --- the rollup ------------------------------------------------------

    def test_the_rollup_sums_across_corpora(self):
        self._corpus("A", self._ea())
        self._corpus("B", self._ea(chain_docs_reaching_epoch=80,
                                   docs_inspected=500))
        text, _ = self.run_digest()
        self.assertIn("EPOCH ASSOCIATION (#72) -- MEASUREMENT ONLY", text)
        self.assertIn("2 carried a readable epoch-association block", text)
        self.assertIn("1500 document(s) inspected in total", text)
        self.assertIn("200  ", text)   # 120 + 80 reaching an epoch

    def test_the_rollup_denominator_excludes_and_names_unmeasured_corpora(self):
        # A total over one corpus and a total over two are different facts.
        self._corpus("A", self._ea())
        self._corpus("B", None)
        text, _ = self.run_digest()
        self.assertIn("1 carried a readable epoch-association block, 1 did not",
                      text)
        self.assertIn("NOT MEASURED in: B", text)
        self.assertIn("not quote them as a whole-corpus figure", text)

    def test_the_rollup_says_so_when_nothing_was_measured(self):
        self._corpus("A", None)
        text, _ = self.run_digest()
        self.assertIn("no corpus contributed a readable block", text)

    def test_the_rollup_flags_a_corpus_whose_class_names_did_not_load(self):
        self._corpus("A", self._ea())
        self._corpus("B", self._ea(reference_root_in_schema=0))
        text, _ = self.run_digest()
        self.assertIn("the followed class names DID NOT LOAD", text)
        self.assertIn("B", text)

    def test_the_rollup_merges_rows_of_the_same_class(self):
        self._corpus("A", self._ea())
        self._corpus("B", self._ea())
        text, _ = self.run_digest()
        self.assertIn("120  voltage_observation.time_reference_#", text)

    def test_the_rollup_prints_every_section_even_at_zero(self):
        self._corpus("A", self._ea(family_all_empty_by_class=[],
                                   epoch_id_by_class=[],
                                   chain_terminus_by_class=[]))
        text, _ = self.run_digest()
        self.assertIn("FAMILIES PRESENT AND ENTIRELY BLANK: 0 occurrence(s)",
                      text)
        self.assertIn("epoch_id EDGES BY CLASS AND STATE: 0 occurrence(s)", text)
        self.assertIn("CHAIN TERMINI (non-epoch): 0 occurrence(s)", text)

    def test_the_block_never_claims_to_enforce_anything(self):
        # MEASUREMENT ONLY was the instruction, and the output has to say so:
        # this block is read by people deciding whether to arm a gate.
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("MEASUREMENT ONLY -- nothing here is enforced", text)


class TestNdiRequiredEdges(DigestCase):
    """The "NDI requires it, V_eta does not" census -- rendering side.

    THE BLIND SPOT. `silentLoss/requiredDependencies` returns names only for
    edges declared `mustBeNonEmpty` in the V_eta chain, so an edge V_eta
    RELAXED is not counted as zero -- it is never looked at. The corpus's
    "0 empty required edges across 627,526 documents" is therefore SILENT
    about that whole set rather than reassuring about it.

    Every test below is about a DISTINCTION, because each is a place two facts
    could collapse into one number: measured zero vs never measured, a zero
    that means agreement vs a zero that means the schema was never stamped,
    and -- the one that matters most -- this bucket vs the armed gate's bucket.
    """

    def _nd(self, **over):
        nd = {
            "docs_inspected": 1000, "docs_unreadable": 0,
            "docs_unclassifiable": 0, "docs_classified": 1000,
            "marker_key": "ndi_mustBeNonEmpty",
            "classes_carrying_the_marker": 40,
            "relaxed_classes": 12, "relaxed_edges_declared": 14,
            "docs_declaring_a_relaxed_edge": 500,
            "edges_examined": 560, "edges_populated": 60, "edges_empty": 500,
        }
        nd.update(over)
        return nd

    def _corpus(self, name="A", nd=None, rows=None, count=500, **over):
        sl = {"total_docs": 1000, "skipped_docs": 0,
              "empty_dependency_count": 0, "vacuous_field_count": 0}
        if nd is not None:
            sl["ndi_required_denominator"] = nd
            sl["ndi_required_dependency_count"] = count
            sl["ndi_required_dependency"] = rows if rows is not None else [
                {"class_name": "ontology_label", "edge_name": "document_id",
                 "count": 400},
                {"class_name": "spikewaves", "edge_name": "element_id",
                 "count": 100}]
        body = {"corpus": name, "total": 100, "migrated_count": 1000,
                "quarantine_count": 0, "silent_loss": sl}
        body.update(over)
        self.write(name, body)

    # --- denominator first, unconditionally --------------------------------

    def test_the_denominator_precedes_the_count(self):
        # Rule 5. This project shipped a counter that read nothing for two days.
        self._corpus("A", self._nd())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        den = text.index("DENOMINATOR: 1000 document(s) inspected, 0 unreadable")
        cnt = text.index("500 empty NDI-required edge(s)")
        self.assertLess(den, cnt)

    def test_the_marker_key_it_followed_is_printed(self):
        # The one string in the block that is not schema-driven. If the build
        # stops stamping it, every count goes to zero -- printing the key is
        # what stops that reading as agreement with NDI.
        self._corpus("A", self._nd())
        text, _ = self.run_digest()
        self.assertIn("FOLLOWED: schema key `ndi_mustBeNonEmpty`", text)

    def test_every_denominator_row_is_rendered(self):
        self._corpus("A", self._nd())
        text, _ = self.run_digest()
        for label in ("documents with no document_class (NOT looked at)",
                      "classes whose chain carries the marker",
                      "classes declaring a RELAXED edge",
                      "distinct (class, edge) pairs relaxed",
                      "documents declaring one",
                      "edge occurrences examined",
                      "EMPTY  <-- the count"):
            self.assertIn(label, text)

    def test_a_counter_the_report_lacks_is_not_printed_as_zero(self):
        nd = self._nd()
        del nd["relaxed_classes"]
        self._corpus("A", nd)
        text, _ = self.run_digest()
        self.assertIn("(absent)  classes declaring a RELAXED edge", text)

    # --- the four not-measured conditions, each distinct from a zero -------

    def test_a_report_without_the_block_is_NOT_MEASURED(self):
        self._corpus("A", nd=None)
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- this report carries no "
                      "ndi_required_denominator block", text)
        self.assertNotIn("empty NDI-required edge(s), V_eta-optional", text)

    def test_zero_inspected_is_NOT_MEASURED_not_a_clean_zero(self):
        self._corpus("A", self._nd(docs_inspected=0))
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- it inspected 0 document(s)", text)

    def test_all_unreadable_is_NOT_MEASURED(self):
        self._corpus("A", self._nd(docs_unreadable=1000))
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- all 1000 document(s) handed to it were "
                      "unreadable", text)

    def test_a_failed_audit_is_NOT_MEASURED(self):
        self.write("A", {"corpus": "A", "total": 1, "migrated_count": 1,
                         "quarantine_count": 0,
                         "silent_loss": {"audit_failed": "boom"}})
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- the silent-loss audit FAILED", text)

    def test_a_malformed_block_is_NOT_MEASURED(self):
        self._corpus("A", nd="nope")
        text, _ = self.run_digest()
        self.assertIn("the ndi_required_denominator block is malformed", text)

    # --- the two vacuous zeros, told apart from each other and from clean ---

    def test_an_unstamped_schema_is_not_a_finding_of_agreement(self):
        # classes_carrying_the_marker == 0 means DID-schema never stamped the
        # key, or it was renamed. That is the demo_ndi failure shape: a query
        # against a string the schema has never contained, read as "this does
        # not exist anywhere".
        self._corpus("A", self._nd(classes_carrying_the_marker=0,
                                   relaxed_classes=0,
                                   relaxed_edges_declared=0,
                                   docs_declaring_a_relaxed_edge=0,
                                   edges_examined=0, edges_populated=0,
                                   edges_empty=0),
                     rows=[], count=0)
        text, _ = self.run_digest()
        self.assertIn("NO CLASS IN THIS BATCH CARRIES THE MARKER AT ALL", text)
        self.assertIn("property of the query", text)

    def test_a_stamped_schema_with_nothing_relaxed_says_untested(self):
        # The marker is present, but no class relaxes an edge NDI requires --
        # so the counter could not fire, and the zero means untested.
        self._corpus("A", self._nd(relaxed_classes=0,
                                   relaxed_edges_declared=0,
                                   docs_declaring_a_relaxed_edge=0,
                                   edges_examined=0, edges_populated=0,
                                   edges_empty=0),
                     rows=[], count=0)
        text, _ = self.run_digest()
        self.assertIn("NO CLASS DECLARES AN EDGE NDI REQUIRES AND V_eta", text)
        self.assertNotIn("NO CLASS IN THIS BATCH CARRIES THE MARKER", text)

    # --- THE BUCKETS ARE NEVER MERGED --------------------------------------

    def test_the_two_buckets_print_as_separate_numbers(self):
        # THE LOAD-BEARING PROPERTY. One is "an edge OUR schema requires is
        # blank" -- what the armed gate keys on. The other is "an edge NDI
        # requires is blank while we permit it". Adding them makes the armed
        # gate's figure describe nothing.
        self._corpus("A", self._nd())
        text, _ = self.run_digest()
        self.assertIn("silent-loss: 0 empty required edge(s)", text)
        self.assertIn("500 empty NDI-required edge(s), V_eta-optional", text)
        self.assertIn("never add this to the empty-required-edge count", text)

    def test_the_rollup_keeps_the_buckets_apart(self):
        self._corpus("A", self._nd())
        text, _ = self.run_digest()
        self.assertIn("DO NOT ADD THIS TO 'EMPTY REQUIRED EDGES' ABOVE", text)
        self.assertIn("EMPTY REQUIRED EDGES: 0 document(s) across 0 row(s)",
                      text)
        self.assertIn("500 empty NDI-required edge(s) across 2 row(s)", text)

    def test_the_block_says_it_is_report_only(self):
        # Read by people deciding whether to arm a gate. It must not read as
        # one.
        self._corpus("A", self._nd())
        text, _ = self.run_digest()
        self.assertIn("report-only", text)

    # --- rollup arithmetic --------------------------------------------------

    def test_the_same_row_in_two_corpora_is_summed_into_one_line(self):
        self._corpus("A", self._nd())
        self._corpus("B", self._nd())
        text, _ = self.run_digest()
        self.assertIn("800  ontology_label.document_id", text)
        self.assertIn("200  spikewaves.element_id", text)

    def test_an_unmeasured_corpus_is_named_and_excluded_never_summed_as_zero(self):
        self._corpus("A", self._nd())
        self._corpus("B", nd=None)
        text, _ = self.run_digest()
        self.assertIn("2 corpus report(s); 1 carried a readable block, 1 did "
                      "not", text)
        self.assertIn("*** NOT MEASURED in: B", text)
        self.assertIn("sums over 1 corpora, not 2", text)

    def test_the_rollup_names_corpora_whose_schema_was_never_stamped(self):
        self._corpus("A", self._nd())
        self._corpus("B", self._nd(classes_carrying_the_marker=0))
        text, _ = self.run_digest()
        self.assertIn("THE MARKER IS ABSENT FROM THE SCHEMA IN: B", text)

    def test_the_rollup_prints_the_section_even_with_no_rows(self):
        self._corpus("A", self._nd(edges_empty=0), rows=[], count=0)
        text, _ = self.run_digest()
        self.assertIn("0 empty NDI-required edge(s) across 0 row(s)", text)
        self.assertIn("(none)", text)

    def test_a_matlab_one_row_object_does_not_crash_the_block(self):
        # jsonencode writes a 1-element struct array as a bare object. That
        # shape killed run #256 after 2h49m in a different block.
        self._corpus("A", self._nd(),
                     rows={"class_name": "ontology_label",
                           "edge_name": "document_id", "count": 500})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("500  ontology_label.document_id", text)

    def test_the_unclassifiable_state_is_rendered_not_folded_away(self):
        # A document that PARSED and still was never looked at. Folding it into
        # either neighbour makes a batch nothing was read from print like a
        # clean one -- the defect silentLoss exists to detect, and the one this
        # row was added for after CI run 31463987352.
        self._corpus("A", self._nd(docs_unclassifiable=400,
                                   docs_classified=600))
        text, _ = self.run_digest()
        self.assertIn("400  documents with no document_class (NOT looked at)",
                      text)
        self.assertIn("600  documents classified", text)

    def test_the_three_document_states_sum_to_the_denominator_in_the_rollup(self):
        # The partition is the property, so the rollup has to preserve it
        # rather than sum three unrelated numbers.
        self._corpus("A", self._nd(docs_inspected=1000, docs_unreadable=100,
                                   docs_unclassifiable=300,
                                   docs_classified=600))
        self._corpus("B", self._nd(docs_inspected=500, docs_unreadable=0,
                                   docs_unclassifiable=100,
                                   docs_classified=400))
        text, _ = self.run_digest()
        self.assertIn("1500 document(s) inspected in total", text)
        self.assertIn("400  documents with no document_class (NOT looked at)",
                      text)
        self.assertIn("1000  documents classified", text)

    def test_the_reader_returns_a_reason_not_just_False(self):
        # A caller must be able to PRINT why, not merely know that it could not
        # read the block.
        m = ndi_required({"silent_loss": {"total_docs": 5}})
        self.assertFalse(m["measured"])
        self.assertIn("no ndi_required_denominator block", m["why"])


class TestNdiRequiredIdentities(DigestCase):
    """WHICH divergences a corpus exercised -- the names beside the counts.

    THE DEFECT THIS COVERS. silentLoss built two seen-sets (`nrSeenRelaxed`,
    `nrSeenEdges`) over a whole batch and reported only `.Count`, so a
    six-corpus run said "N of the schema's divergences were exercised" and
    nothing anywhere said WHICH. The keys lived in memory for the run and were
    dropped; no log and no artifact held them, and re-running the corpus did
    not recover them. The complement -- the divergences no corpus touches --
    was therefore unnameable, and it is the half that ranks planning work.

    EVERY ASSERTION HERE NAMES A NAME. A test that only checked the field was
    present, or only that a section header printed, would pass against a
    renderer that exports an empty list for everything -- the failure mode a
    neighbouring instrument shipped an hour before this was written, where a
    partition check replaced by `return True` left 76 tests green because every
    other test asserted the partition on data where it held.
    """

    def _nd(self, **over):
        nd = {
            "docs_inspected": 1000, "docs_unreadable": 0,
            "docs_unclassifiable": 0, "docs_classified": 1000,
            "marker_key": "ndi_mustBeNonEmpty",
            "classes_carrying_the_marker": 40,
            "relaxed_classes": 2, "relaxed_edges_declared": 3,
            "relaxed_class_names": ["ontology_label", "spikewaves"],
            "relaxed_edge_names": ["ontology_label.document_id",
                                   "ontology_label.other_id",
                                   "spikewaves.element_id"],
            "docs_declaring_a_relaxed_edge": 500,
            "edges_examined": 560, "edges_populated": 60, "edges_empty": 500,
        }
        nd.update(over)
        return nd

    def _corpus(self, name="A", nd=None, rows=None, count=0):
        sl = {"total_docs": 1000, "skipped_docs": 0,
              "empty_dependency_count": 0, "vacuous_field_count": 0,
              "ndi_required_denominator": nd if nd is not None else self._nd(),
              "ndi_required_dependency_count": count,
              "ndi_required_dependency": rows if rows is not None else []}
        self.write(name, {"corpus": name, "total": 100, "migrated_count": 1000,
                          "quarantine_count": 0, "silent_loss": sl})

    # --- per corpus: the names themselves, not merely a header --------------

    def test_the_relaxed_class_names_are_printed(self):
        self._corpus("A")
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("ontology_label", text)
        self.assertIn("spikewaves", text)

    def test_the_relaxed_edge_pairs_are_printed_class_dot_edge(self):
        # The dot spelling matters: `ndi_required_dependency` rows render as
        # `class.edge`, so the pairs SEEN and the pairs found EMPTY are
        # comparable strings rather than two formats to reconcile.
        self._corpus("A")
        text, _ = self.run_digest()
        self.assertIn("ontology_label.document_id", text)
        self.assertIn("ontology_label.other_id", text)
        self.assertIn("spikewaves.element_id", text)

    def test_a_report_predating_the_export_is_UNMEASURED_not_an_empty_list(self):
        # THE distinction. An absent list and an empty list are different
        # facts; rendering the first as the second would say "this corpus
        # exercised nothing" about a corpus nobody asked.
        nd = self._nd()
        del nd["relaxed_class_names"]
        del nd["relaxed_edge_names"]
        self._corpus("A", nd)
        text, _ = self.run_digest()
        self.assertIn("NAMES NOT MEASURED -- this report predates the identity "
                      "export", text)
        self.assertIn("An absent list is not an empty one", text)
        self.assertNotIn("0 (class, edge) pair(s) relaxed seen", text)

    def test_a_measured_empty_list_says_so_in_its_own_words(self):
        # And is NOT the same output as the absent case above.
        self._corpus("A", self._nd(relaxed_classes=0, relaxed_edges_declared=0,
                                   relaxed_class_names=[],
                                   relaxed_edge_names=[],
                                   docs_declaring_a_relaxed_edge=0,
                                   edges_examined=0, edges_populated=0,
                                   edges_empty=0))
        text, _ = self.run_digest()
        self.assertIn("0 (class, edge) pair(s) relaxed seen. This is a "
                      "MEASURED zero", text)
        self.assertNotIn("predates the identity export", text)

    def test_a_list_shorter_than_its_own_count_is_called_out(self):
        # The counts were here first and other tooling reads them. If the two
        # disagree the report is wrong somewhere, and the SHORTER one must not
        # be quietly preferred -- a names list that went short would shrink the
        # union and read as progress.
        self._corpus("A", self._nd(relaxed_edge_names=[
            "ontology_label.document_id"]))
        text, _ = self.run_digest()
        self.assertIn("THE LIST AND ITS COUNT DISAGREE: "
                      "`relaxed_edges_declared` says 3, 1 name(s) were "
                      "exported", text)

    def test_a_malformed_list_is_not_measured(self):
        self._corpus("A", self._nd(relaxed_edge_names=42))
        text, _ = self.run_digest()
        self.assertIn("`relaxed_edge_names` is malformed (int)", text)

    def test_entries_that_are_not_strings_are_counted_and_named(self):
        # The MATLAB side pins the export to a 1xN ROW cell. Nobody here has a
        # MATLAB to confirm that `jsonencode` flattens a COLUMN cell to the
        # same flat JSON array, so the digest does not assume it: a nested
        # array (the shape a column would produce if it did NOT flatten) is
        # reported rather than silently filtered down to an empty union.
        self._corpus("A", self._nd(relaxed_edge_names=[["a"], ["b"], ["c"]]))
        text, _ = self.run_digest()
        self.assertIn("3 of 3 entries in `relaxed_edge_names` are not strings",
                      text)

    def test_a_bare_string_is_one_name_not_a_pile_of_letters(self):
        # Defensive. MATLAB writes a cell as a JSON array at every length, but
        # a single string arriving here must not iterate character by
        # character and manufacture a 26-entry union of letters.
        self._corpus("A", self._nd(relaxed_classes=1,
                                   relaxed_class_names="ontology_label"))
        text, _ = self.run_digest()
        self.assertIn("1 class(es) declaring a relaxed edge", text)
        self.assertNotIn("          o\n", text)

    # --- the rollup: the union is the point ---------------------------------

    def test_the_union_merges_two_corpora_and_names_where_each_was_seen(self):
        self._corpus("A", self._nd(
            relaxed_classes=1, relaxed_edges_declared=1,
            relaxed_class_names=["ontology_label"],
            relaxed_edge_names=["ontology_label.document_id"]))
        self._corpus("B", self._nd(
            relaxed_classes=1, relaxed_edges_declared=1,
            relaxed_class_names=["probe_geometry"],
            relaxed_edge_names=["probe_geometry.probe_id"]))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("2 distinct (class, edge) pair(s) relaxed in the union",
                      text)
        self.assertIn("ontology_label.document_id", text)
        self.assertIn("probe_geometry.probe_id", text)
        # WHERE each was seen, so a pair present in one corpus and a pair
        # present in all six are distinguishable.
        self.assertRegex(text, r"ontology_label\.document_id\s+seen in: A")
        self.assertRegex(text, r"probe_geometry\.probe_id\s+seen in: B")

    def test_every_name_a_corpus_carried_reaches_the_union(self):
        # A UNION THAT GOES SHORT READS AS PROGRESS: fewer pairs in the union
        # means a smaller measured set, which means a LARGER unmeasured
        # complement -- but the way it is quoted ("we have seen k of them") the
        # error still arrives as a confident number. Asserted against a corpus
        # carrying THREE pairs, so a union that keeps only the first per corpus
        # cannot pass.
        self._corpus("A")   # 2 classes, 3 pairs
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("3 distinct (class, edge) pair(s) relaxed in the union",
                      text)
        self.assertIn("2 distinct class(es) declaring a relaxed edge in the "
                      "union", text)
        i = text.index("THE UNION OF IDENTITIES SEEN")
        tail = text[i:]
        for name in ("ontology_label", "spikewaves",
                     "ontology_label.document_id", "ontology_label.other_id",
                     "spikewaves.element_id"):
            self.assertIn(name, tail, "%s never reached the union" % name)

    def test_a_pair_in_two_corpora_is_one_union_entry_naming_both(self):
        self._corpus("A", self._nd(
            relaxed_classes=1, relaxed_edges_declared=1,
            relaxed_class_names=["ontology_label"],
            relaxed_edge_names=["ontology_label.document_id"]))
        self._corpus("B", self._nd(
            relaxed_classes=1, relaxed_edges_declared=1,
            relaxed_class_names=["ontology_label"],
            relaxed_edge_names=["ontology_label.document_id"]))
        text, _ = self.run_digest()
        self.assertIn("1 distinct (class, edge) pair(s) relaxed in the union",
                      text)
        self.assertRegex(text, r"ontology_label\.document_id\s+seen in: A, B")

    def test_the_summed_count_and_the_union_size_are_told_apart(self):
        # THE READING ERROR THIS EXISTS TO STOP. The rollup's
        # `relaxed_edges_declared` line ADDS per-corpus DISTINCT counts, so a
        # pair present in two corpora contributes 2. The figure that has been
        # quoted against the schema-side divergence set is that sum; the union
        # size is the cross-corpus distinct figure and is the one to subtract.
        self._corpus("A", self._nd(
            relaxed_classes=1, relaxed_edges_declared=1,
            relaxed_class_names=["ontology_label"],
            relaxed_edge_names=["ontology_label.document_id"]))
        self._corpus("B", self._nd(
            relaxed_classes=1, relaxed_edges_declared=1,
            relaxed_class_names=["ontology_label"],
            relaxed_edge_names=["ontology_label.document_id"]))
        text, _ = self.run_digest()
        self.assertIn("`relaxed_edges_declared` sums to 2 across the rollup; "
                      "the union is", text)
        self.assertIn("counted", text)

    def test_a_corpus_without_names_is_named_and_the_union_says_over_how_many(self):
        nd_old = self._nd()
        del nd_old["relaxed_class_names"]
        del nd_old["relaxed_edge_names"]
        self._corpus("A")
        self._corpus("Old", nd_old)
        text, _ = self.run_digest()
        self.assertIn("1 of 2 readable block(s) carried `relaxed_edge_names`",
                      text)
        self.assertIn("*** NAMES NOT MEASURED in: Old", text)
        self.assertIn("union below is over 1 corpus report(s), not 2", text)

    def test_no_report_carrying_names_is_not_an_empty_union(self):
        nd_old = self._nd()
        del nd_old["relaxed_class_names"]
        del nd_old["relaxed_edge_names"]
        self._corpus("Old", nd_old)
        text, _ = self.run_digest()
        self.assertIn("NO REPORT CARRIED `relaxed_edge_names`. There is "
                      "nothing to union", text)
        self.assertIn("This is NOT 'no (class, edge) pair(s) relaxed were "
                      "seen'", text)

    def test_the_rollup_refuses_to_own_the_divergence_set(self):
        # The set of divergences is computed in DID-schema. Duplicating it here
        # would create a second copy to drift, and both copies would print
        # confidently. The rollup reports what was SEEN and says where the
        # comparison belongs.
        self._corpus("A")
        text, _ = self.run_digest()
        self.assertIn("THIS IS WHAT THE SAMPLE EXERCISED, NOT WHAT EXISTS",
                      text)
        self.assertIn("computed in", text)
        self.assertIn("DID-schema", text)
        self.assertIn("UNMEASURED on real data -- not clean, unlooked-at",
                      text)

    # --- stability ----------------------------------------------------------

    def test_the_union_is_rendered_in_a_stable_order(self):
        # Two reports of the same corpus must diff cleanly. The MATLAB side
        # sorts; the digest sorts again, so an unsorted report cannot produce
        # an unstable digest either.
        self._corpus("A", self._nd(
            relaxed_classes=3, relaxed_edges_declared=3,
            relaxed_class_names=["z_class", "a_class", "m_class"],
            relaxed_edge_names=["z.e", "a.e", "m.e"]))
        text, _ = self.run_digest()
        i = text.index("THE UNION OF IDENTITIES SEEN")
        tail = text[i:]
        self.assertLess(tail.index("a_class"), tail.index("m_class"))
        self.assertLess(tail.index("m_class"), tail.index("z_class"))
        self.assertLess(tail.index("a.e"), tail.index("m.e"))
        self.assertLess(tail.index("m.e"), tail.index("z.e"))

    # --- the reader, directly ------------------------------------------------

    def test_the_reader_distinguishes_absent_from_empty(self):
        absent = ndi_required_names({"relaxed_classes": 3},
                                    "relaxed_class_names", "relaxed_classes")
        self.assertFalse(absent["measured"])
        self.assertIn("predates the identity export", absent["why"])
        empty = ndi_required_names({"relaxed_classes": 0,
                                    "relaxed_class_names": []},
                                   "relaxed_class_names", "relaxed_classes")
        self.assertTrue(empty["measured"])
        self.assertEqual(empty["names"], [])
        self.assertIsNone(empty["drift"])

    def test_the_reader_returns_the_actual_names(self):
        # Not a count, not a bool -- the strings. A reader that returned
        # `measured: True` with an empty list would pass a presence-only test.
        m = ndi_required_names({"relaxed_classes": 2,
                                "relaxed_class_names": ["b", "a"]},
                               "relaxed_class_names", "relaxed_classes")
        self.assertTrue(m["measured"])
        self.assertEqual(m["names"], ["b", "a"])
        self.assertIsNone(m["drift"])


class TestLegacyNdiDocumentBlock(DigestCase):
    """The legacy identity block (`ndi_document` -> `base`).

    THE COUNTER THIS COVERS IS EXPECTED TO READ ZERO on every corpus we hold,
    which is exactly why it is tested here rather than only on a corpus run:
    the whole value of the instrument is that a zero it PRINTS is
    distinguishable from a zero nothing measured. No MATLAB is available in
    this environment, so the MATLAB half (universalRenames' report,
    v1_to_v2's accumulator, writeCorpusReport's persist) is UNEXECUTED and CI
    is its first run; the Python half is covered by these tests.
    """

    def _legacy(self, **over):
        L = {"bodies_total": 1000,
             "bodies_reaching_universal_renames": 1000,
             "bodies_skipped_already_target": 0,
             "bodies_unreached": 0,
             "ndi_document_block_seen": 0,
             "moved_wholesale_no_base": 0,
             "discarded_ndi_document_base_present": 0,
             "moved_missing_id": 0,
             "moved_missing_session_id": 0,
             "moved_with_any_undeclared_field": 0,
             "moved_undeclared_field_instances": 0,
             "moved_carrying_experiment_unique_reference": 0,
             "moved_carrying_document_unique_reference": 0,
             "moved_carrying_type": 0,
             "moved_carrying_database_version": 0,
             "moved_by_class": {},
             "discarded_by_class": {}}
        L.update(over)
        return L

    def _corpus(self, name, legacy):
        body = {"corpus": name, "total": 1000, "migrated_count": 1000,
                "quarantine_count": 0}
        if legacy is not None:
            body["legacy_ndi_document"] = legacy
        self.write(name, body)

    def test_an_all_zero_block_is_still_printed(self):
        # The point of the whole exercise: "nothing in this sample" must be a
        # line, not an absence. 633,432 documents across 6 corpora quarantined
        # 0 at run 31464483119, so all-zero is the EXPECTED reading.
        self._corpus("A", self._legacy())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("MOVED WHOLESALE into `base` (no `base` present)", text)
        self.assertIn("0  carried an `ndi_document` block", text)

    def test_the_denominator_precedes_the_arms(self):
        # Rule 5, and here the denominator is NOT `total`.
        self._corpus("A", self._legacy())
        text, _ = self.run_digest()
        den = text.index("bod(ies) reached universalRenames")
        arm = text.index("MOVED WHOLESALE")
        self.assertLess(den, arm)

    def test_the_denominator_is_the_pass_not_the_batch(self):
        # A re-run over already-migrated bodies takes the idempotency
        # short-circuit, so the rename pass sees nothing. That MUST NOT read as
        # "no legacy blocks in this corpus".
        self._corpus("A", self._legacy(bodies_reaching_universal_renames=0,
                                       bodies_skipped_already_target=1000))
        text, _ = self.run_digest()
        self.assertIn("0 bodies reached the rename pass", text)
        self.assertIn("it is NOT 'no legacy blocks found'", text)

    def test_the_two_arms_are_separate_numbers(self):
        # Discarding a stale block beside a good `base` and moving a block that
        # IS the only identity are different facts. Never summed.
        self._corpus("A", self._legacy(ndi_document_block_seen=5,
                                       moved_wholesale_no_base=2,
                                       discarded_ndi_document_base_present=3))
        text, _ = self.run_digest()
        self.assertIn("2  MOVED WHOLESALE into `base` (no `base` present)", text)
        self.assertIn("3  discarded (`base` present and wins)", text)

    def test_a_moved_block_prints_the_vintage_discriminator(self):
        # An arm count alone cannot say whether anything is broken: a
        # 2020-vintage block already spells id/session_id and moves soundly.
        self._corpus("A", self._legacy(
            ndi_document_block_seen=2, moved_wholesale_no_base=2,
            moved_missing_id=2, moved_missing_session_id=2,
            moved_with_any_undeclared_field=2,
            moved_undeclared_field_instances=8,
            moved_carrying_experiment_unique_reference=2,
            moved_carrying_document_unique_reference=2,
            moved_carrying_type=2, moved_carrying_database_version=2,
            moved_by_class={"projectvar": 2}))
        text, _ = self.run_digest()
        self.assertIn("2 missing required `id`, 2 missing `session_id`", text)
        self.assertIn("2 carrying 8 field(s) `base` does not declare", text)
        # THE LABEL ON THIS ROW WAS "2019 vintage:" AND IT WAS WRONG ABOUT
        # ITSELF. `type` and `database_version` are in ALL FOUR vintages of the
        # ndi_document block, not only the 2019 ones, so a row headed "2019
        # vintage" that counts them read as evidence of a vintage it does not
        # discriminate. The row is now headed "field names present" and the
        # vintage question is answered by the classifier below it.
        self.assertIn("field names present: 2 experiment_unique_reference", text)
        self.assertNotIn("2019 vintage: 2 experiment_unique_reference", text)
        self.assertIn("2  projectvar (moved wholesale)", text)
        # ...and this fixture carries NO classifier, so the composition must
        # read UNMEASURED rather than as six zeros.
        self.assertIn("VINTAGE BREAKDOWN: UNMEASURED", text)

    # ---- the vintage classifier on the wholesale-move arm ----------------
    #
    # The `ndi_document` block had FOUR shapes and two consecutive pairs differ
    # by ONE field name, so the moved_carrying_* rows above cannot name a
    # vintage. These assert the breakdown that can, and -- more importantly --
    # that a report predating the classifier reads as UNMEASURED rather than as
    # six zeros, and that a breakdown which does not partition its arm SAYS SO.

    def _vintages(self, **over):
        v = {"moved_vintage_bodies_classified": 0,
             "moved_vintage_2019_05_unique_reference": 0,
             "moved_vintage_2019_11_experiment_document_id": 0,
             "moved_vintage_2019_12_experiment_id_and_id": 0,
             "moved_vintage_2020_05_session_id_and_id": 0,
             "moved_vintage_unknown": 0,
             "moved_vintage_unreadable_block": 0}
        v.update(over)
        return v

    def test_the_vintage_breakdown_prints_its_denominator_before_the_buckets(self):
        # Rule 5, and here the denominator is the CLASSIFIER's, not the arm's
        # and not the batch's.
        self._corpus("A", self._legacy(
            ndi_document_block_seen=4, moved_wholesale_no_base=4,
            **self._vintages(moved_vintage_bodies_classified=4,
                             moved_vintage_2019_05_unique_reference=1,
                             moved_vintage_2020_05_session_id_and_id=3)))
        text, _ = self.run_digest()
        den = text.index("vintage of the 4 moved block(s)")
        bucket = text.index("2020-05 session_id/id")
        self.assertLess(den, bucket)
        self.assertIn("3  2020-05 session_id/id", text)
        self.assertIn("SOUND -- both identity fields land", text)

    def test_a_report_predating_the_classifier_reads_UNMEASURED_not_zero(self):
        # THE WHOLE POINT OF THE SEPARATE BUCKET SET. Six printed zeros would
        # claim the arm is composed entirely of nothing, which is a measurement
        # that was never taken.
        self._corpus("A", self._legacy(ndi_document_block_seen=2,
                                       moved_wholesale_no_base=2))
        text, _ = self.run_digest()
        self.assertIn("VINTAGE BREAKDOWN: UNMEASURED", text)
        self.assertNotIn("0  2020-05 session_id/id", text)

    def test_buckets_that_do_not_partition_the_arm_say_so(self):
        # A body that reached no bucket is what the `unknown` bucket exists to
        # catch. If it happens anyway, the breakdown must not render as a
        # composition -- it is missing documents.
        self._corpus("A", self._legacy(
            ndi_document_block_seen=5, moved_wholesale_no_base=5,
            **self._vintages(moved_vintage_bodies_classified=5,
                             moved_vintage_2020_05_session_id_and_id=3)))
        text, _ = self.run_digest()
        self.assertIn("THE BUCKETS DO NOT PARTITION THE ARM: 3 summed, "
                      "5 classified", text)
        self.assertIn("A body reached no bucket", text)

    def test_an_arm_that_outruns_the_classifier_says_so(self):
        # moved_wholesale_no_base and the classifier denominator are set at
        # different places in countMovedBlock; if they ever diverge, a body took
        # the arm and was never classified.
        self._corpus("A", self._legacy(
            ndi_document_block_seen=4, moved_wholesale_no_base=4,
            **self._vintages(moved_vintage_bodies_classified=3,
                             moved_vintage_2020_05_session_id_and_id=3)))
        text, _ = self.run_digest()
        self.assertIn("4 body(ies) took the wholesale-move arm and 3 reached "
                      "the classifier", text)

    def test_the_unknown_bucket_is_called_out_rather_than_listed_quietly(self):
        # An unrecognised field set means the four-vintage account is
        # incomplete, which is the way this measurement is most likely to be
        # wrong. It must not sit as one row among six.
        self._corpus("A", self._legacy(
            ndi_document_block_seen=2, moved_wholesale_no_base=2,
            **self._vintages(moved_vintage_bodies_classified=2,
                             moved_vintage_2020_05_session_id_and_id=1,
                             moved_vintage_unknown=1)))
        text, _ = self.run_digest()
        self.assertIn("NOT rounded to the nearest vintage", text)
        self.assertIn("1 block(s) carried a field set the four-vintage "
                      "account does not predict", text)
        self.assertIn("READ THIS ROW FIRST", text)

    def test_the_rollup_names_reports_that_carry_no_classifier(self):
        # THE legacy_ndi_document PATTERN ONE LEVEL DOWN. The classifier landed
        # after the arm counter, so a sample can carry the block everywhere and
        # the breakdown only somewhere. Summing the gap as zero would understate
        # every vintage.
        self._corpus("A", self._legacy(
            ndi_document_block_seen=1, moved_wholesale_no_base=1,
            **self._vintages(moved_vintage_bodies_classified=1,
                             moved_vintage_2020_05_session_id_and_id=1)))
        self._corpus("B", self._legacy(ndi_document_block_seen=1,
                                       moved_wholesale_no_base=1))
        text, _ = self.run_digest()
        self.assertIn("VINTAGE BREAKDOWN: summed over 1 of 2 report(s)", text)
        self.assertIn("NO CLASSIFIER (predates it, UNMEASURED not zero): B",
                      text)

    def test_the_rollup_says_when_nothing_carried_the_classifier(self):
        # A zero over zero reports is not a composition. It must not read like
        # one.
        self._corpus("A", self._legacy(ndi_document_block_seen=1,
                                       moved_wholesale_no_base=1))
        text, _ = self.run_digest()
        self.assertIn("VINTAGE BREAKDOWN: summed over 0 of 1 report(s)", text)
        self.assertIn("The arm's COMPOSITION is unknown, which is", text)

    def test_a_report_without_the_block_prints_nothing(self):
        # An older report predates the counter. Rendering it as zeros would
        # claim a measurement that was never taken.
        self._corpus("A", None)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertNotIn("legacy ndi_document block", text)

    def test_the_rollup_sums_across_corpora_with_its_denominator(self):
        self._corpus("A", self._legacy(ndi_document_block_seen=1,
                                       moved_wholesale_no_base=1,
                                       moved_missing_id=1))
        self._corpus("B", self._legacy(ndi_document_block_seen=2,
                                       moved_wholesale_no_base=2,
                                       moved_missing_id=2))
        text, _ = self.run_digest()
        self.assertIn("LEGACY IDENTITY BLOCK (`ndi_document` -> `base`)", text)
        self.assertIn("DENOMINATOR: 2 of 2 report(s) carried the counter", text)
        self.assertIn("3  MOVED WHOLESALE into `base` (the defect); 3 of them",
                      text)

    def test_the_rollup_names_a_report_that_carries_no_counter(self):
        # A report predating the counter must not be summed as a zero. That
        # substitution is how "12,296 documents, three classes" survived for
        # months while the real figure was 26,406.
        self._corpus("A", self._legacy())
        self._corpus("B", None)
        text, _ = self.run_digest()
        self.assertIn("DENOMINATOR: 1 of 2 report(s) carried the counter", text)
        self.assertIn("NOT SUMMED (no counter in the report): B", text)

    def test_a_zero_rollup_says_unmeasured_not_clean(self):
        self._corpus("A", self._legacy())
        text, _ = self.run_digest()
        self.assertIn("UNMEASURED, not zero", text)

    def test_no_report_carrying_the_counter_is_not_zero_pre_base_documents(self):
        self._corpus("A", None)
        text, _ = self.run_digest()
        self.assertIn("nothing to sum. This is NOT '0 pre-base documents'",
                      text)

    def test_a_missing_counter_prints_a_question_mark_not_a_zero(self):
        L = self._legacy()
        del L["moved_missing_id"]
        L["moved_wholesale_no_base"] = 1
        L["ndi_document_block_seen"] = 1
        self._corpus("A", L)
        text, _ = self.run_digest()
        self.assertIn("? missing required `id`", text)


class ThreePassCase(DigestCase):
    """Shared corpus writer for the three passes wired into the digest
    2026-08-11.

    ALL THREE WERE BUILT THE SAME DAY AND RENDERED NOWHERE. Their counters
    reached the corpus artifact -- writeCorpusReport copies the whole struct --
    and stopped there, so a full corpus run over six corpora would have printed
    nothing about the lawn/plate subject tiers, the openMINDS citation graph or
    the response-parameters fold. That is the epochMint defect, three times, on
    106 counters.
    """

    def _corpus(self, name="A", **fields):
        body = {"corpus": name, "total": 100, "migrated_count": 1000,
                "quarantine_count": 0,
                "silent_loss": {"total_docs": 1000, "skipped_docs": 0,
                                "empty_dependency_count": 0,
                                "vacuous_field_count": 0}}
        body.update(fields)
        self.write(name, body)

    def halves(self):
        """(per-corpus text, cross-corpus text).

        WHY THE SPLIT IS NOT FUSSINESS. It was added after mutation testing:
        neutering the PER-CORPUS vacuity banner turned one test red instead of
        three, and neutering the ROLLUP one turned NOTHING red, because both
        blocks say nearly the same sentence and every assertion was run against
        the whole document. A test that cannot tell which of two instruments
        printed a line cannot notice one of them going silent -- which is this
        file's own subject matter, arriving in this file.
        """
        text, failed = self.run_digest()
        marker = "ACROSS ALL CORPORA"
        self.assertIn(marker, text)
        i = text.index(marker)
        return text[:i], text[i:], failed


class TestTheThreePassesAreWiredAtAll(ThreePassCase):
    """Named explicitly, so deleting an entry fails a test that says why.

    The generic sweep in tools/test_batch_pass_wiring.py checks that every
    counter a RENDERED pass declares has a row -- which passes just as well if
    the whole entry is deleted, because a scan over what exists cannot notice
    something that stopped existing. Same reason
    test_the_response_parameters_fold_is_wired exists over there.
    """

    def test_each_of_the_three_has_a_POST_PASSES_entry(self):
        import census_digest
        keys = dict((name, fn) for name, fn, _rows in census_digest.POST_PASSES)
        for key, fn in (("lawn_plate_subjects",
                         "did2.convert.resolveLawnPlateSubjects"),
                        ("openminds_citations",
                         "did2.convert.resolveOpenmindsCitations"),
                        ("response_parameters_fold",
                         "did2.convert.resolveResponseParameters")):
            self.assertIn(key, keys, "%s lost its POST_PASSES entry -- every "
                                     "counter it declares goes invisible" % key)
            self.assertEqual(keys[key], fn)

    def test_the_counters_that_came_off_the_debt_list_are_rendered(self):
        # SHRINK ONLY, checked from the digest's side too. Seven counters were
        # on NOT_RENDERED_YET as REAL COUNTERS, REALLY NOT RENDERED; they are
        # rows now, and a silent removal would put them back in the artifact
        # with nothing printing them.
        import census_digest
        rows = dict((name, set(k for k, _l in r))
                    for name, _fn, r in census_digest.POST_PASSES)
        for key in ("documents_with_epoch_id", "strings_declined",
                    "strings_declined_distinct"):
            self.assertIn(key, rows["epoch_mint"])
        for key in ("anchor_session_from_timeref", "anchor_session_from_document",
                    "method_from_app_block", "method_from_class_default"):
            self.assertIn(key, rows["valid_interval_decompose"])


class TestLawnPlateRendering(ThreePassCase):
    """The two-tier E. coli subject mint (TEAM DECISION 2026-08-11)."""

    def _lp(self, **over):
        rep = {
            "ran": True, "documents_inspected": 1000, "documents_unreadable": 0,
            "ontology_table_rows_seen": 500,
            "plate_rows_seen": 10, "image_rows_seen": 20, "lawn_rows_seen": 30,
            "exp_id_source_rows_seen": 10,
            "sessions_with_lawn_plate_tables": 1,
            "unclassified_rows_in_those_sessions": 5,
            "columns_resolved_by_key": 120, "columns_resolved_by_term_name": 3,
            "plate_rows_with_measurements": 8,
            "plate_rows_with_values_but_none_emittable": 1,
            "plate_rows_with_no_values_at_all": 1,
            "plate_rows_refused_no_session_id": 0,
            "plate_rows_refused_no_plate_key": 0,
            "plate_rows_refused_no_exp_id": 0,
            "plate_subjects_minted": 8, "plate_observations_emitted": 30,
            "lawn_rows_with_measurements": 28,
            "lawn_rows_with_values_but_none_emittable": 1,
            "lawn_rows_with_no_values_at_all": 1,
            "lawn_rows_refused_no_session_id": 0,
            "lawn_rows_refused_no_identity_keys": 0,
            "lawn_subjects_minted": 28, "lawn_observations_emitted": 200,
            "chains_attempted": 28, "chains_resolved": 28,
            "refused_no_image_row": 0, "refused_image_row_ambiguous": 0,
            "refused_image_row_has_no_plate_key": 0, "refused_no_plate_row": 0,
            "refused_plate_row_ambiguous": 0, "refused_lawn_no_exp_id": 0,
            "member_of_relations_emitted": 28,
            "withheld_plate_tier_not_minted": 0,
            "withheld_lawn_tier_not_minted": 2, "refused_total": 0,
            "celegans_patch_subjects_seen": 40,
            "celegans_patch_subjects_relabelled": 38,
            "celegans_patch_subjects_already_triple": 0,
            "celegans_patch_subjects_refused_no_exp_id": 2,
            "celegans_patch_subjects_refused_ambiguous_exp_id": 0,
            "celegans_patch_subjects_unparseable_handle": 0,
            "celegans_patch_relabel_quarantined": 0,
            "local_identifier_fallback_to_document_id": 0,
            "local_identifier_collisions_within_batch": 0,
            "subjects_quarantined": 0, "statements_quarantined": 0,
            "documents_appended": 294, "source_rows_left_in_place": 60,
        }
        rep.update(over)
        return rep

    def test_it_is_rendered_at_all(self):
        self._corpus("A", lawn_plate_subjects=self._lp())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("did2.convert.resolveLawnPlateSubjects", text)
        self.assertIn("SUBJECTS minted", text)
        self.assertIn("member_of EDGES emitted", text)

    def test_the_denominator_prints_first_and_unconditionally(self):
        self._corpus("A", lawn_plate_subjects=self._lp())
        text, _ = self.run_digest()
        self.assertIn("DENOMINATOR: 500 ontology_table_row document(s)", text)

    def test_a_zero_denominator_says_vacuous(self):
        self._corpus("A", lawn_plate_subjects={
            "ran": True, "documents_inspected": 900,
            "ontology_table_rows_seen": 0})
        percorpus, _rollup, _f = self.halves()
        self.assertIn("DENOMINATOR: 0 ontology_table_row", percorpus)
        self.assertIn("above is VACUOUS -- including the spelling canary",
                      percorpus)

    def test_an_absent_denominator_is_unmeasured_not_zero(self):
        rep = self._lp()
        del rep["ontology_table_rows_seen"]
        self._corpus("A", lawn_plate_subjects=rep)
        text, _ = self.run_digest()
        self.assertIn("`ontology_table_rows_seen` IS NOT IN THIS REPORT", text)
        self.assertIn("UNMEASURED here. It is not zero", text)

    def test_nothing_recognised_says_the_canary_could_not_fire(self):
        # THE HONEST READING, and the reason this block was worth writing by
        # hand: `unclassified_rows_in_those_sessions` is only counted in
        # sessions where a table WAS recognised, so a wholly wrong column-token
        # rule forces it to 0 and produces the same output as a corpus with no
        # E. coli tables. The digest must not read that as clean.
        self._corpus("A", lawn_plate_subjects=self._lp(
            plate_rows_seen=0, image_rows_seen=0, lawn_rows_seen=0,
            unclassified_rows_in_those_sessions=0))
        text, _ = self.run_digest()
        self.assertIn("NOTHING RECOGNISED, AND THIS READING IS AMBIGUOUS", text)
        self.assertIn("cannot detect a wholly wrong one", text)

    def test_the_canary_fires_when_unclassified_swamps_recognised(self):
        self._corpus("A", lawn_plate_subjects=self._lp(
            unclassified_rows_in_those_sessions=400))
        text, _ = self.run_digest()
        self.assertIn("SPELLING CANARY: 400 unclassified row(s) beside 60",
                      text)
        self.assertIn("That is what a WRONG", text)
        self.assertIn("column-token rule looks like", text)

    def test_a_broken_tier_partition_is_named_as_a_counter_defect(self):
        # plate_rows_seen must equal the three states. A violation is a counter
        # that stopped moving, not a corpus fact, and saying which matters.
        self._corpus("A", lawn_plate_subjects=self._lp(
            plate_rows_with_no_values_at_all=0))
        text, _ = self.run_digest()
        self.assertIn("the three plate-row states sum to 9, not "
                      "plate_rows_seen", text)

    def test_a_handle_collision_is_a_message_to_the_team(self):
        self._corpus("A", lawn_plate_subjects=self._lp(
            local_identifier_collisions_within_batch=7))
        text, _ = self.run_digest()
        self.assertIn("7 HANDLE COLLISION(S)", text)
        self.assertIn("The team's directive asserts", text)
        self.assertIn("does not", text)
        self.assertIn("choose another scheme on its own", text)

    def test_withheld_edges_are_named_as_not_a_loss(self):
        self._corpus("A", lawn_plate_subjects=self._lp())
        text, _ = self.run_digest()
        self.assertIn("THIS IS NOT A LOSS AND NOT A REFUSAL", text)

    def test_refused_total_says_what_it_excludes(self):
        self._corpus("A", lawn_plate_subjects=self._lp())
        text, _ = self.run_digest()
        self.assertIn("EXCLUDES the C. elegans relabel", text)

    def test_units_are_on_the_rows_that_are_not_documents(self):
        # COLUMNS, SESSIONS, ROWS and EDGES all appear in one column. Labelling
        # them is the only thing that stops a reader adding them up.
        self._corpus("A", lawn_plate_subjects=self._lp())
        text, _ = self.run_digest()
        self.assertIn("COLUMNS matched by key (not rows)", text)
        self.assertIn("SESSIONS holding any of those", text)
        self.assertIn("member_of EDGES emitted (edges, not rows)", text)

    def test_a_missing_counter_prints_absent_not_zero(self):
        rep = self._lp()
        del rep["lawn_subjects_minted"]
        self._corpus("A", lawn_plate_subjects=rep)
        text, _ = self.run_digest()
        self.assertIn("(absent)    SUBJECTS minted", text)

    def test_the_rollup_names_a_report_that_lacks_a_counter(self):
        # NEVER SUMMED AS 0. This is the defect that made the digest print
        # NO CORPUS REPORTS FOUND and exit 0, one level down.
        rep = self._lp()
        del rep["lawn_subjects_minted"]
        self._corpus("A", lawn_plate_subjects=self._lp())
        self._corpus("B", lawn_plate_subjects=rep)
        text, _ = self.run_digest()
        self.assertIn("lawn_subjects_minted", text)
        self.assertIn("no such counter in: B", text)
        self.assertIn("contributes", text)

    def test_the_rollup_denominator_and_vacuity(self):
        self._corpus("A", lawn_plate_subjects={
            "ran": True, "documents_inspected": 1, "ontology_table_rows_seen": 0})
        self._corpus("B", lawn_plate_subjects={
            "ran": True, "documents_inspected": 1, "ontology_table_rows_seen": 0})
        _percorpus, rollup_text, _f = self.halves()
        self.assertIn("DENOMINATOR: 0 ontology_table_row document(s) across 2 "
                      "report(s)", rollup_text)
        self.assertIn("above is VACUOUS -- including the spelling canary",
                      rollup_text)


class TestOpenmindsCitationsRendering(ThreePassCase):
    """The openMINDS citation assembly (TEAM DECISION 2026-08-11, "Do B")."""

    def _om(self, **over):
        rep = {
            "ran": True, "documents_inspected": 1000, "documents_unreadable": 0,
            "openminds_documents_seen": 50, "openminds_components_seen": 3,
            "dataset_versions_seen": 1,
            "dataset_versions_superseded_by_newer": 0,
            "components_without_dataset_version": 1,
            "components_planned": 2, "components_consumed": 1,
            "components_withheld": 1, "components_reverted_on_validation": 0,
            "withheld_reasons": ["component 2 would leave ab12 referenced by "
                                 "3 surviving document(s)"],
            "documents_consumed": 25, "datasets_emitted": 1,
            "persons_emitted": 4, "persons_id_preserved": 4,
            "organizations_emitted": 2, "organizations_id_preserved": 2,
            "funding_emitted": 1, "funding_slots_empty_skipped": 0,
            "publications_emitted": 1, "publications_without_doi_skipped": 0,
            "web_resources_emitted": 1, "web_resources_from_iri": 1,
            "web_resources_from_doi": 0,
            "experimental_approach_terms_emitted": 2, "relations_emitted": 9,
            "affiliations_beyond_first_dropped": 1,
            "contribution_documents_consumed_without_a_home": 4,
            "data_type_documents_consumed_without_a_home": 1,
            "technique_documents_consumed_without_a_home": 2,
            "bodies_quarantined": 0, "documents_appended": 19,
        }
        rep.update(over)
        return rep

    def test_it_is_rendered_at_all(self):
        self._corpus("A", openminds_citations=self._om())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("did2.convert.resolveOpenmindsCitations", text)
        self.assertIn("person entities emitted", text)

    def test_the_denominator_prints_first(self):
        self._corpus("A", openminds_citations=self._om())
        text, _ = self.run_digest()
        self.assertIn("DENOMINATOR: 50 `openminds` document(s)", text)

    def test_a_zero_denominator_is_vacuous_and_points_at_the_metadata_tier(self):
        self._corpus("A", openminds_citations={
            "ran": True, "documents_inspected": 900,
            "openminds_documents_seen": 0})
        percorpus, _rollup, _f = self.halves()
        self.assertIn("EVERY counter above is VACUOUS", percorpus)
        self.assertIn("METADATA TIER section above counts the same class",
                      percorpus)

    def test_the_rollup_says_vacuous_in_its_own_words(self):
        # The rollup and the per-corpus block both go quiet independently, so
        # each needs an assertion the other cannot satisfy.
        self._corpus("A", openminds_citations={
            "ran": True, "documents_inspected": 900,
            "openminds_documents_seen": 0})
        self._corpus("B", openminds_citations={
            "ran": True, "documents_inspected": 900,
            "openminds_documents_seen": 0})
        _percorpus, rollup_text, _f = self.halves()
        self.assertIn("DENOMINATOR: 0 `openminds` document(s) across 2 "
                      "report(s)", rollup_text)
        self.assertIn("total above is VACUOUS", rollup_text)
        self.assertIn("METADATA TIER rollup", rollup_text)

    def test_an_absent_denominator_is_unmeasured_not_zero(self):
        rep = self._om()
        del rep["openminds_documents_seen"]
        self._corpus("A", openminds_citations=rep)
        text, _ = self.run_digest()
        self.assertIn("`openminds_documents_seen` IS NOT IN THIS REPORT", text)
        self.assertIn("It is not zero", text)

    def test_the_withheld_reasons_are_printed_verbatim(self):
        # They are a CELL ARRAY, so they get no numeric row -- and the reason a
        # component was withheld is the finding, not the count.
        self._corpus("A", openminds_citations=self._om())
        text, _ = self.run_digest()
        self.assertIn("WITHHELD by the orphan guard", text)
        self.assertIn("component 2 would leave ab12", text)

    def test_a_single_withheld_reason_arriving_as_a_bare_string_renders(self):
        # RUN #256's LESSON, applied to a field that is a CELL rather than a
        # struct array. MATLAB's jsonencode writes a 1-element cell as a
        # 1-element array today, but every list-shaped read in this file goes
        # through aslist rather than the one shape that happened to break --
        # so the bare-string shape is exercised rather than assumed away.
        self._corpus("A", openminds_citations=self._om(
            withheld_reasons="component 2 would leave ab12 dangling"))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("component 2 would leave ab12 dangling", text)

    def test_withheld_with_no_reason_string_says_so(self):
        self._corpus("A", openminds_citations=self._om(withheld_reasons=[]))
        text, _ = self.run_digest()
        self.assertIn("no reason strings in this report", text)

    def test_a_broken_component_sum_is_named_as_a_counter_defect(self):
        self._corpus("A", openminds_citations=self._om(components_withheld=0))
        text, _ = self.run_digest()
        self.assertIn("planned (2) != consumed (1) + withheld (0)", text)

    def test_a_broken_seen_sum_is_named(self):
        self._corpus("A", openminds_citations=self._om(
            openminds_components_seen=9))
        text, _ = self.run_digest()
        self.assertIn("components_seen (9) != planned (2) + no-root (1)", text)

    def test_a_reverted_component_is_called_a_build_defect(self):
        self._corpus("A", openminds_citations=self._om(
            components_planned=3, components_reverted_on_validation=1,
            bodies_quarantined=2))
        text, _ = self.run_digest()
        self.assertIn("REVERTED ON VALIDATION", text)
        self.assertIn("defect in the build, not in the corpus", text)

    def test_consumed_greater_than_appended_is_explained_not_alarmed(self):
        self._corpus("A", openminds_citations=self._om())
        text, _ = self.run_digest()
        self.assertIn("LARGE", text)
        self.assertIn("IS EXPECTED AND IS NOT LOSS", text)

    def test_a_classified_web_resource_that_was_not_emitted_is_named(self):
        self._corpus("A", openminds_citations=self._om(
            web_resources_from_doi=1))
        text, _ = self.run_digest()
        self.assertIn("fullDocumentation reference(s) were CLASSIFIED", text)

    def test_the_four_lossy_rows_are_summed_and_labelled_as_loss(self):
        self._corpus("A", openminds_citations=self._om())
        text, _ = self.run_digest()
        self.assertIn("LOSSY: Contribution role documents", text)
        self.assertIn("consumed with NOWHERE TO PUT THEM", text)

    def test_the_rollup_names_where_a_component_was_withheld(self):
        self._corpus("A", openminds_citations=self._om())
        self._corpus("B", openminds_citations=self._om(
            components_planned=1, components_withheld=0, components_consumed=1,
            withheld_reasons=[]))
        text, _ = self.run_digest()
        self.assertIn("*** WITHHELD in: A", text)
        self.assertNotIn("*** WITHHELD in: A, B", text)

    def test_the_rollup_names_a_report_that_lacks_a_counter(self):
        rep = self._om()
        del rep["persons_emitted"]
        self._corpus("A", openminds_citations=self._om())
        self._corpus("B", openminds_citations=rep)
        text, _ = self.run_digest()
        self.assertIn("persons_emitted", text)
        self.assertIn("no such counter in: B", text)


class TestResponseParametersRendering(ThreePassCase):
    """#61's resolver half (TEAM-SIGN-OFF [stimulus response] 2026-08-08)."""

    def _rp(self, **over):
        rep = {
            "ran": True, "documents_inspected": 1000, "documents_unreadable": 0,
            "leaves_seen": 0, "leaves_with_edge": 0, "leaves_without_edge": 0,
            "suppressed_responses_seen": 11167,
            "parameters_documents_seen": 11440, "inlined": 0,
            "fields_copied": 0, "harmonic_checked": 0,
            "harmonic_uncheckable": 0, "refused_not_in_batch": 0,
            "refused_ambiguous": 0, "refused_wrong_class": 0,
            "refused_no_fields": 0, "refused_inline_present": 0,
            "refused_harmonic_mismatch": 0, "refused_total": 0,
            "fold_quarantined": 0,
            "parameters_documents_referenced_after": 11440,
            "parameters_documents_unreferenced_after": 0,
            "parameters_documents_deleted": 0,
        }
        rep.update(over)
        return rep

    def test_it_is_rendered_at_all(self):
        self._corpus("A", response_parameters_fold=self._rp())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("did2.convert.resolveResponseParameters", text)
        self.assertIn("INLINED", text)

    def test_zero_leaves_beside_suppressed_responses_says_blocked_upstream(self):
        # THE PAIR. `leaves_seen: 0` alone is three findings; the pass reports
        # the second number precisely so the digest can tell them apart.
        self._corpus("A", response_parameters_fold=self._rp())
        text, _ = self.run_digest()
        self.assertIn("BLOCKED UPSTREAM", text)
        self.assertIn("11167 v1 `stimulus_response_scalar` document(s)", text)
        self.assertIn("NOT 'nothing to do'", text)

    def test_zero_leaves_and_zero_suppressed_is_a_different_reading(self):
        self._corpus("A", response_parameters_fold=self._rp(
            suppressed_responses_seen=0))
        text, _ = self.run_digest()
        self.assertIn("no stimulus responses at all", text)
        self.assertNotIn("BLOCKED UPSTREAM", text)

    def test_an_absent_suppression_counter_is_named_as_unmeasured(self):
        rep = self._rp()
        del rep["suppressed_responses_seen"]
        self._corpus("A", response_parameters_fold=rep)
        text, _ = self.run_digest()
        self.assertIn("`suppressed_responses_seen` is absent", text)
        self.assertIn("A bare 0 here means neither", text)

    def test_leaves_with_nothing_inlined_or_refused_is_called_a_defect(self):
        self._corpus("A", response_parameters_fold=self._rp(
            leaves_seen=5, leaves_with_edge=5))
        text, _ = self.run_digest()
        self.assertIn("NOTHING inlined or refused", text)
        self.assertIn("real defect in resolveResponseParameters", text)

    def test_a_harmonic_mismatch_is_the_alarming_row(self):
        self._corpus("A", response_parameters_fold=self._rp(
            leaves_seen=5, leaves_with_edge=5, inlined=4,
            refused_harmonic_mismatch=1, refused_total=1))
        text, _ = self.run_digest()
        self.assertIn("IS THE ALARMING ROW OF THE BLOCK", text)
        self.assertIn("refusal(s) for freq_response ~= value.harmonic", text)
        self.assertIn("refuses rather", text)

    def test_the_deletion_gate_prints_its_own_denominator(self):
        self._corpus("A", response_parameters_fold=self._rp())
        text, _ = self.run_digest()
        self.assertIn("DELETION GATE: 11440 parameters document(s) in this "
                      "batch", text)
        self.assertIn("EVIDENCE", text)

    def test_a_zero_deletion_denominator_says_vacuous(self):
        self._corpus("A", response_parameters_fold=self._rp(
            parameters_documents_seen=0,
            parameters_documents_referenced_after=0))
        percorpus, _rollup, _f = self.halves()
        self.assertIn("DELETION GATE: 0 parameters document(s) in this batch",
                      percorpus)
        self.assertIn("the referenced/unreferenced rows above are", percorpus)
        self.assertIn("VACUOUS", percorpus)

    def test_a_non_zero_deleted_count_is_an_alarm(self):
        # This pass deletes nothing by construction; a non-zero means it has
        # pre-empted a decision that belongs to the team.
        self._corpus("A", response_parameters_fold=self._rp(
            parameters_documents_deleted=3))
        text, _ = self.run_digest()
        self.assertIn("parameters_documents_deleted is 3 and MUST be 0", text)

    def test_a_broken_gate_partition_is_named(self):
        self._corpus("A", response_parameters_fold=self._rp(
            parameters_documents_referenced_after=1))
        text, _ = self.run_digest()
        self.assertIn("referenced (1) + unreferenced (0) != seen (11440)", text)

    def test_fields_copied_is_labelled_as_cells_not_documents(self):
        self._corpus("A", response_parameters_fold=self._rp())
        text, _ = self.run_digest()
        self.assertIn("field VALUES copied (cells, not documents)", text)

    def test_the_rollup_names_a_report_that_lacks_a_counter(self):
        rep = self._rp()
        del rep["parameters_documents_unreferenced_after"]
        self._corpus("A", response_parameters_fold=self._rp())
        self._corpus("B", response_parameters_fold=rep)
        text, _ = self.run_digest()
        self.assertIn("parameters_documents_unreferenced_after", text)
        self.assertIn("no such counter in: B", text)

    def test_the_rollup_says_vacuous_in_its_own_words(self):
        self._corpus("A", response_parameters_fold=self._rp(
            suppressed_responses_seen=0, parameters_documents_seen=0,
            parameters_documents_referenced_after=0))
        self._corpus("B", response_parameters_fold=self._rp(
            suppressed_responses_seen=0, parameters_documents_seen=0,
            parameters_documents_referenced_after=0))
        _percorpus, rollup_text, _f = self.halves()
        self.assertIn("DENOMINATOR: 0 harmonic_component_calculation "
                      "leaf/leaves across 2 report(s)", rollup_text)
        self.assertIn("REFUSAL total above is VACUOUS", rollup_text)
        self.assertIn("0 leaves beside 0 suppressed responses", rollup_text)

    def test_the_rollup_says_blocked_upstream_across_corpora(self):
        self._corpus("A", response_parameters_fold=self._rp())
        self._corpus("B", response_parameters_fold=self._rp(
            suppressed_responses_seen=349))
        text, _ = self.run_digest()
        self.assertIn("11516 v1 response(s) STILL SUPPRESSED across the run",
                      text)


class TestEpochPopulations(DigestCase):
    """Three counters, three batches, printed side by side and reconciled.

    THE DEFECT. Corpus run 31508009545 (head 602ee141, all 7 jobs green, census
    digest job 93869969402) printed, from the same six corpora, in one digest:

        epoch_mint                 8433 epochs minted
        valid_interval_decompose   8433 epoch documents to anchor to
        epoch association             0 `epoch` document(s) in this batch
                                      0 REACH AN EPOCH  <-- "the number the
                                                            decision rests on"

    Nothing in the output reconciled them, so a reader could not tell a
    MIGRATION defect (epochs minted and then lost) from a MEASUREMENT defect
    (one counter reading a different batch) -- opposite conclusions, both
    actionable.

    It is the second. runCorpusDiscovery.m:61 calls v1_to_v2, which computes
    `silent_loss` at v1_to_v2.m:382; every batch post-pass runs after, epochMint
    at runCorpusDiscovery.m:136, and nothing recomputes it. Soph's own report
    shows the ladder without needing the source: silent_loss 254304, epoch_mint
    254239, +176 minted, valid_interval 254415 = migrated_count.

    These tests hold the DISTINCTION, not the numbers: a figure must carry the
    population it counted over, the post-mint figures must be cross-checked
    against each other, and an unreadable stage must never read as a zero.
    """

    def _corpus(self, name="A", **over):
        ea = {
            "docs_inspected": 1000, "docs_unreadable": 0,
            "docs_classified": 1000, "anchor_edge": "relative_to",
            "reference_root": "time_reference", "terminal_class": "epoch",
            "max_depth": 8, "terminal_class_in_schema": 1,
            "reference_root_in_schema": 1,
            "family_docs_declaring": 300, "family_docs_absent": 0,
            "family_docs_present": 300, "family_docs_all_empty": 0,
            "family_docs_populated": 300, "family_members_total": 300,
            "family_members_empty": 0, "family_members_populated": 300,
            "epoch_documents": 0, "epoch_id_docs_declaring": 90,
            "epoch_id_edges_present": 0, "epoch_id_empty": 0,
            "epoch_id_resolved": 0, "epoch_id_resolved_not_epoch": 0,
            "epoch_id_unresolved_in_batch": 0,
            "chain_docs_examined": 300, "chain_docs_reaching_epoch": 0,
            "chain_docs_reaching_no_epoch": 300,
            "chain_docs_undetermined": 0, "chain_members_examined": 300,
            "chain_member_unresolved": 0, "chain_member_not_a_reference": 0,
            "chain_member_anchor_absent": 300, "chain_member_anchor_empty": 0,
            "chain_member_reaches_epoch": 0, "chain_member_reaches_other": 0,
            "chain_member_incomplete": 0, "chain_member_depth_exceeded": 0,
            "chain_member_unclassified": 0,
        }
        ea.update(over.pop("ea", {}))
        body = {
            "corpus": name, "total": 500, "migrated_count": 1100,
            "quarantine_count": 0,
            "by_class": {"epoch": 100, "subject": 40},
            "silent_loss": {"total_docs": 1000, "skipped_docs": 0,
                            "epoch_association": ea},
            "epoch_mint": {"ran": True, "documents_inspected": 1000,
                           "epochs_minted": 100, "epochs_found_existing": 0},
            "valid_interval_decompose": {"ran": True,
                                         "documents_inspected": 1100,
                                         "epoch_documents_seen": 100},
        }
        for key, value in over.items():
            if value is None:
                body.pop(key, None)
            elif key == "by_class":
                # REPLACED, never merged: by_class is a class census and half of
                # one plus half of another is not a census of anything. Merging
                # would also make "a corpus whose census has no `epoch` key"
                # unexpressible, which is the case that separates a measured
                # zero from an absent table.
                body[key] = value
            elif isinstance(value, dict) and isinstance(body.get(key), dict):
                body[key].update(value)
            else:
                body[key] = value
        self.write(name, body)

    def _block(self, text):
        start = text.index("EPOCH DOCUMENT POPULATIONS -- WHICH BATCH EACH "
                           "FIGURE COUNTED (this corpus)")
        end = text.index("METADATA TIER", start)
        return text[start:end]

    # --- rule 5: the denominator, and it is the POPULATION -----------------

    def test_the_denominator_prints_first_and_unconditionally(self):
        self._corpus("A")
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        block = self._block(text)
        self.assertLess(block.index("DENOMINATOR: 4 of 4 pipeline stage(s)"),
                        block.index("THE LADDER"))

    def test_the_epoch_association_block_states_which_batch_it_read(self):
        # THE HEADLINE REPAIR. The three figures may not print side by side
        # again without the block saying which population it counted over.
        self._corpus("A")
        text, _ = self.run_digest()
        self.assertIn("POPULATION: the PASS-1 batch (1000 document(s)), "
                      "which is 100 SMALLER than the migrated output (1100)",
                      text)

    def test_the_ladder_names_every_stage_and_its_population(self):
        self._corpus("A")
        block = self._block(self.run_digest()[0])
        for stage in ("silent_loss / epoch_association", "epoch_mint",
                      "valid_interval_decompose", "migrated_count"):
            self.assertIn(stage, block)
        self.assertIn("THE LADDER IS NOT FLAT (1000 .. 1100)", block)

    # --- the commensurable set, and the cross-check ------------------------

    def test_the_three_post_mint_figures_agree_and_say_so(self):
        self._corpus("A")
        block = self._block(self.run_digest()[0])
        self.assertIn("-> AGREE (3 figure(s), all 100).", block)

    def test_a_post_mint_disagreement_is_a_finding_and_exits_non_zero(self):
        # THE MIGRATION DEFECT this instrument exists to catch: epochs minted
        # and then lost before the final class census.
        self._corpus("A", by_class={"epoch": 3})
        text, failed = self.run_digest()
        self.assertIn("do NOT agree", text)
        self.assertIn("minted and then", text)
        self.assertIn("<epoch document populations disagree>", failed)

    def test_the_PER_CORPUS_block_reports_its_own_disagreement(self):
        # Asserted against the per-corpus block SPECIFICALLY. The rollup
        # computes its own disagreement from its own sums, so a whole-text
        # assertion passes while the per-corpus check is dead -- exactly the
        # trap where a partition check becomes `return True` and every test
        # stays green because another assertion covered the same data.
        self._corpus("A", by_class={"epoch": 3})
        block = self._block(self.run_digest()[0])
        self.assertIn("do NOT agree", block)
        self.assertIn("3 (by_class", block)
        self.assertNotIn("-> AGREE", block)

    def test_a_disagreement_that_cancels_in_the_sum_is_still_reported(self):
        # A + B sum to the same total on two of the three figures while each
        # corpus disagrees with itself. Summing is how the 4,563-document JH
        # row nearly hid; the rollup names the corpus rather than averaging.
        self._corpus("A", by_class={"epoch": 60})
        self._corpus("B", by_class={"epoch": 140})
        text, failed = self.run_digest()
        self.assertIn("A corpus disagrees with ITSELF", text)
        self.assertIn("A: ", text.split("ACROSS ALL")[-1])
        self.assertIn("B: ", text.split("ACROSS ALL")[-1])
        self.assertIn("<epoch document populations disagree>", failed)

    def test_unequal_contributing_sets_are_NOT_COMPARABLE_and_exit_zero(self):
        # THE REAL SIX-CORPUS SHAPE, and the guard nothing was testing. A
        # mutation that disabled it stayed GREEN across the whole suite.
        #
        # In run 31508009545 five corpora had an epoch-association population
        # SMALLER than migrated_count (pre-mint) while PRED's equalled it --
        # legitimately, because PRED minted nothing and no pass changed its
        # batch. So `epoch_association` contributes to the summed cross-check
        # from ONE corpus while the other three figures contribute from all
        # six, and the sums differ for a reason that is not about epochs.
        #
        # Comparing sums over different contributing sets is the 562,422 error
        # exactly. Without the guard this run reports a DIGEST DEFECT and the
        # corpus job goes red on six internally-consistent corpora.
        self._corpus("premint")                       # ea pre-mint
        self._corpus("final", migrated_count=1000,    # ea on the final batch
                     ea={"docs_inspected": 1000, "epoch_documents": 100},
                     epoch_mint={"documents_inspected": 900},
                     valid_interval_decompose={"documents_inspected": 1000})
        text, failed = self.run_digest()
        rollup = text.split("ACROSS ALL")[-1]
        self.assertIn("THESE SUMS ARE NOT COMPARABLE", rollup)
        self.assertIn("epoch_association from final", rollup)
        self.assertIn("No conclusion is drawn from the difference", rollup)
        # and NOT reported as a defect in either direction
        self.assertNotIn("DEFECT IN census_digest.py", rollup)
        self.assertEqual(failed, [])

    def test_agreement_across_corpora_exits_zero(self):
        self._corpus("A")
        self._corpus("B")
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("-> AGREE (3 figure(s), all 200).", text)

    # --- the pre-mint annotation -------------------------------------------

    def test_reach_an_epoch_is_stripped_of_its_authority_pre_mint(self):
        # The figure the epoch decision was going to be taken on. At pass 1 it
        # cannot be anything but 0, and the output has to say so.
        self._corpus("A")
        block = self._block(self.run_digest()[0])
        self.assertIn("AT THIS STAGE IT CANNOT BE ANYTHING BUT 0", block)
        self.assertIn("The post-mint value is UNMEASURED", block)

    def test_a_pre_mint_zero_is_never_printed_beside_the_mint_unqualified(self):
        self._corpus("A")
        block = self._block(self.run_digest()[0])
        premint = block.index("MEASURED PRE-MINT")
        self.assertLess(block.index("COMMENSURABLE, must agree"), premint)
        self.assertIn("DO NOT COMPARE THEM", block)

    # --- self-adjusting: the split is derived, not hardcoded ---------------

    def test_a_block_measured_on_the_final_batch_becomes_commensurable(self):
        # If silent_loss is ever recomputed after the passes, its population
        # equals migrated_count and its `epoch` count joins the cross-check
        # instead of being excused. The instrument must start ENFORCING on its
        # own rather than staying quiet on a stale assumption about the wiring.
        self._corpus("A", migrated_count=1000,
                     ea={"docs_inspected": 1000, "epoch_documents": 100},
                     epoch_mint={"documents_inspected": 900},
                     valid_interval_decompose={"documents_inspected": 1000})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        block = self._block(text)
        self.assertIn("-> AGREE (4 figure(s), all 100).", block)
        self.assertNotIn("MEASURED PRE-MINT", block)
        self.assertIn("POPULATION: the FINAL migrated batch", text)

    def test_a_final_stage_block_that_disagrees_is_caught(self):
        # The other half of the same behaviour: once commensurable, a wrong
        # figure is a finding rather than an excused stage artefact.
        self._corpus("A", migrated_count=1000,
                     ea={"docs_inspected": 1000, "epoch_documents": 7},
                     epoch_mint={"documents_inspected": 900},
                     valid_interval_decompose={"documents_inspected": 1000})
        text, failed = self.run_digest()
        self.assertIn("<epoch document populations disagree>", failed)
        self.assertIn("7 (epoch_association", text)

    def test_reach_an_epoch_is_announced_as_real_when_measured_late(self):
        self._corpus("A", migrated_count=1000,
                     ea={"docs_inspected": 1000, "epoch_documents": 100,
                         "chain_docs_reaching_epoch": 42},
                     epoch_mint={"documents_inspected": 900},
                     valid_interval_decompose={"documents_inspected": 1000})
        block = self._block(self.run_digest()[0])
        self.assertIn("`REACH AN EPOCH` = 42, measured on the FINAL migrated "
                      "batch", block)

    # --- absent is not zero, in every stage --------------------------------

    def test_an_absent_pass_is_named_not_zero_filled(self):
        self._corpus("A", epoch_mint=None)
        block = self._block(self.run_digest()[0])
        self.assertIn("no `epoch_mint` block -- the pass was not wired", block)
        self.assertIn("(absent)  epoch_mint", block)
        self.assertNotIn("epoch_mint: minted", block)

    def test_a_failed_pass_is_not_a_measurement_of_zero(self):
        self._corpus("A", epoch_mint={"pass_failed": "boom"})
        block = self._block(self.run_digest()[0])
        self.assertIn("`epoch_mint` FAILED (boom)", block)
        self.assertIn("pass-1 form", block)

    def test_a_pass_that_did_not_run_is_its_own_state(self):
        self._corpus("A", valid_interval_decompose={"ran": False})
        block = self._block(self.run_digest()[0])
        self.assertIn("`valid_interval_decompose` did not run", block)

    def test_a_missing_by_class_is_named_as_the_unwatched_direction(self):
        # by_class is the only figure that would notice an epoch DELETED after
        # minting, so its absence is a named gap rather than a silent one.
        self._corpus("A", by_class=None)
        block = self._block(self.run_digest()[0])
        self.assertIn("carries no `by_class`", block)
        self.assertIn("DELETED after minting", block)

    def test_a_by_class_without_an_epoch_key_is_a_measured_zero(self):
        # DIFFERENT from an absent by_class: the census ran and found none.
        self._corpus("A", by_class={"subject": 40})
        text, failed = self.run_digest()
        self.assertIn("<epoch document populations disagree>", failed)
        self.assertIn("0 (by_class", text)

    def test_a_mint_without_found_existing_is_not_compared(self):
        # `epochs_found_existing` is part of the population and not part of the
        # mint's work. Absent, its contribution is UNKNOWN -- assuming zero
        # would manufacture a disagreement out of a missing counter.
        self._corpus("A", epoch_mint={"epochs_found_existing": None})
        block = self._block(self.run_digest()[0])
        self.assertIn("its contribution to the population is UNKNOWN", block)
        self.assertNotIn("epoch_mint: minted", block)

    def test_no_comparable_figure_at_all_is_untested_not_agreed(self):
        # Every post-mint source gone. An empty cross-check must not read as a
        # passed one -- this is the `silentLoss` failure (0 empty edges while
        # reading nothing) in the shape this block could take it.
        self._corpus("A", epoch_mint=None, valid_interval_decompose=None,
                     by_class=None)
        block = self._block(self.run_digest()[0])
        self.assertIn("(none readable -- nothing to cross-check", block)
        self.assertIn("'untested', not 'agreed'", block)
        self.assertNotIn("-> AGREE", block)

    def test_one_figure_alone_is_untested_not_confirmed(self):
        # Exactly one comparable figure: nothing opposes it, so it cannot have
        # been checked, and the block must not let it read as confirmed.
        self._corpus("A", migrated_count=1000,
                     ea={"docs_inspected": 1000, "epoch_documents": 100},
                     epoch_mint=None, valid_interval_decompose=None,
                     by_class=None)
        block = self._block(self.run_digest()[0])
        self.assertIn("ONE figure only", block)
        self.assertIn("untested, not confirmed", block)
        self.assertNotIn("-> AGREE", block)

    def test_the_rollup_names_the_corpora_a_stage_is_missing_from(self):
        self._corpus("A")
        self._corpus("B", epoch_mint=None)
        text, _ = self.run_digest()
        self.assertIn("[NOT from: B]", text)

    # --- the shape the real run produced, end to end -----------------------

    def test_the_run_31508009545_shape_reconciles_instead_of_contradicting(self):
        # Soph's figures, quoted from census digest job 93869969402.
        self._corpus("Soph", migrated_count=254415,
                     by_class={"epoch": 176},
                     ea={"docs_inspected": 254304, "docs_classified": 254304,
                         "epoch_documents": 0,
                         "chain_docs_examined": 72441,
                         "chain_docs_reaching_epoch": 0,
                         "chain_docs_reaching_no_epoch": 72441},
                     silent_loss={"total_docs": 254304},
                     epoch_mint={"documents_inspected": 254239,
                                 "epochs_minted": 176,
                                 "epochs_found_existing": 0},
                     valid_interval_decompose={
                         "documents_inspected": 254415,
                         "epoch_documents_seen": 176})
        text, failed = self.run_digest()
        # NOT a defect: the three post-mint figures agree.
        self.assertEqual(failed, [])
        block = self._block(text)
        self.assertIn("-> AGREE (3 figure(s), all 176).", block)
        # ... and the zero is explained rather than left to be compared.
        self.assertIn("254304  silent_loss / epoch_association", block)
        self.assertIn("254239  epoch_mint", block)
        self.assertIn("254415  migrated_count", block)
        self.assertIn("111 document(s) smaller than the migrated output", block)


class TestPostPassEpochPopulation(DigestCase):
    """The OTHER site the contradicting numbers print at.

    THE HALF-REPAIR THIS EXISTS TO PREVENT. Labelling only the
    epoch-association block leaves `epochs minted` and `epoch documents to
    anchor to` bare, and those are the figures that printed 8433 against its 0
    in run 31508009545 -- in the ROLLUP's post-pass block, some forty lines
    below the rollup's epoch-association block. A reader at that point does not
    have the other block on screen. Both sites must name their batch, so the
    two numbers cannot be read as one comparison from either end.

    The population is READ from `documents_inspected` (set on entry to every
    pass -- epochMint.m:212, resolveValidIntervals.m:427), never assumed, and
    an absent one prints as absent rather than as a number.
    """

    def _report(self, name="A", **over):
        body = {
            "corpus": name, "total": 100, "migrated_count": 1100,
            "quarantine_count": 0,
            "by_class": {"epoch": 100},
            "silent_loss": {"total_docs": 1000, "skipped_docs": 0},
            "epoch_mint": {"ran": True, "documents_inspected": 1000,
                           "epochs_minted": 100, "epochs_found_existing": 0},
            "valid_interval_decompose": {"ran": True,
                                         "documents_inspected": 1100,
                                         "epoch_documents_seen": 100},
        }
        for key, value in over.items():
            if value is None:
                body.pop(key, None)
            elif isinstance(value, dict) and isinstance(body.get(key), dict):
                body[key].update(value)
            else:
                body[key] = value
        self.write(name, body)

    def _per_corpus(self, text):
        return text[text.index("batch post-passes:"):text.index("ACROSS ALL")]

    def _rollup(self, text):
        return text[text.index("BATCH POST-PASSES:"):]

    def test_the_mint_figure_names_its_batch_per_corpus(self):
        self._report()
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("POPULATION: `epochs minted` counts documents this pass",
                      block)
        self.assertIn("ADDED to a batch of 1000 document(s).", block)

    def test_the_valid_interval_figure_names_its_batch_per_corpus(self):
        self._report()
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("documents in a batch of 1100 document(s) -- AFTER",
                      block)
        self.assertIn("did2.convert.epochMint appended.", block)

    def test_both_figures_point_at_the_reconciliation(self):
        # The cross-reference is the thing that makes a bare number safe: a
        # reader who lands on 8433 is told where the 0 is explained.
        self._report()
        block = self._per_corpus(self.run_digest()[0])
        self.assertEqual(block.count("Cross-checked"), 2)
        self.assertEqual(block.count("EPOCH DOCUMENT POPULATIONS"), 2)

    def test_the_ROLLUP_figures_name_their_batch_and_say_it_is_a_sum(self):
        # THE ACTUAL SITE OF THE DEFECT. Run 31508009545 printed both 8433s
        # here. A summed population must never read as one batch.
        self._report("A")
        self._report("B")
        block = self._rollup(self.run_digest()[0])
        self.assertIn("ADDED to a batch of 2000 document(s) (summed over 2 "
                      "report(s)).", block)
        self.assertIn("documents in a batch of 2200 document(s) (summed over "
                      "2 report(s)) -- AFTER", block)

    def test_an_unrecorded_population_prints_as_unrecorded_not_as_a_number(self):
        # A pass whose report carries no `documents_inspected`. The annotation
        # must not invent a population -- an unmeasured denominator that
        # arrives as a figure is the defect this whole file guards.
        self._report(epoch_mint={"documents_inspected": None})
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("ADDED to a batch of UNRECORDED size.", block)

    def test_a_failed_pass_gets_no_population_line(self):
        # A pass that threw measured nothing, so there is no batch to name.
        # Printing one would dress a non-measurement as a measurement.
        self._report(epoch_mint={"pass_failed": "boom"})
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("*** FAILED: boom", block)
        self.assertNotIn("`epochs minted` counts documents", block)

    def test_a_pass_that_did_not_run_gets_no_population_line(self):
        self._report(valid_interval_decompose={"ran": False})
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("did not run", block)
        self.assertNotIn("`epoch documents to anchor to` counts", block)

    def test_no_other_post_pass_is_annotated(self):
        # Scoped to the two passes that report an `epoch` figure. Annotating a
        # pass that reports none would attach a caution to a number that never
        # took part in the contradiction.
        self._report(session_anchor_fold={"ran": True,
                                          "documents_inspected": 1100,
                                          "anchors_seen": 5})
        block = self._per_corpus(self.run_digest()[0])
        self.assertEqual(block.count("POPULATION: `epochs minted`"), 1)
        self.assertEqual(block.count("POPULATION: `epoch documents"), 1)


class TestTimeReferenceFamilies(DigestCase):
    """#52: the time-reference-family block (`did2.validate.timeReferenceFamilies`).

    THE DEFECT THESE COVER IS THE ONE THE INSTRUMENT ITSELF HAD ON ARRIVAL: it
    ran, it persisted, and it printed nowhere, so the evidence for a team
    decision reached a zip file and stopped. No MATLAB is available in this
    container, so the MATLAB half is UNEXECUTED here and CI is its first run;
    everything below is the Python half.

    EVERY ASSERTION IS SCOPED TO ONE HALF OF THE BLOCK. The reference verdict
    and the shape verdict are near-identical two-line banners, and an assertion
    made against the whole digest passes when only one of them exists -- two
    near-identical banners covering each other is a mutation that came back
    green earlier today, one file over. `_reference_half` and `_shape_half`
    slice them apart so each is checked in its own half.
    """

    SPLIT = "kind=2rel | clock=same | relative_to=distinct | extent=2instant"
    NCLOCK = "kind=2rel | clock=distinct | relative_to=same | extent=2span"
    OTHER = "kind=1other+1rel | clock=same | relative_to=same | extent=2instant"

    # ---- fixtures --------------------------------------------------------

    def _block(self, **over):
        """A MEASURED block: 4 of 40 referencing slots carry two members, 3 of
        those shapeable and 1 not. The counters satisfy every invariant the
        instrument's control flow guarantees, so a test that breaks one has to
        break it deliberately."""
        b = {
            "docs_inspected": 1000, "docs_unreadable": 0,
            "docs_unclassifiable": 0, "docs_classified": 1000,
            "docs_class_unresolved": 0, "docs_with_an_id": 1000,
            "docs_declaring_family": 40, "docs_declaring_two_families": 0,
            "schema_cache_available": True,
            "slots_examined": 40, "slots_with_no_member": 0,
            "slots_with_blank_members_only": 0,
            "members_examined": 44, "members_blank": 0,
            "statements_with_reference": 40, "statements_multi_reference": 4,
            "count_distribution": [{"members": 1, "statements": 36},
                                   {"members": 2, "statements": 4}],
            "shape": [
                {"shape_key": self.SPLIT, "statements": 3, "members": 2,
                 "example_document_id": "abc123",
                 "example_class_name": "subject_interaction",
                 "family": "time_reference_#"},
                {"shape_key": TRF_NOT_SHAPEABLE, "statements": 1, "members": 2,
                 "example_document_id": "def456",
                 "example_class_name": "directed_relation",
                 "family": "time_reference_#"}],
            "shape_denominator": {"multi_slots_examined": 4,
                                  "multi_slots_shaped": 3,
                                  "multi_slots_unresolved": 1,
                                  "multi_members_examined": 8,
                                  "multi_members_resolved": 7,
                                  "multi_members_unresolved": 1},
            "emitter": [
                {"shape_key": self.SPLIT,
                 "statement_class": "subject_interaction",
                 "statement_name": "migrated_valid_interval",
                 "anchor_names": "migrated_valid_interval_anchor",
                 "statements": 3},
                {"shape_key": TRF_NOT_SHAPEABLE,
                 "statement_class": "directed_relation",
                 "statement_name": "", "anchor_names": "<unresolved>",
                 "statements": 1}],
            "emitter_denominator": {"multi_slots_with_statement_name": 3,
                                    "multi_slots_without_statement_name": 1},
            "reference_census_vacuous": False,
            "reference_census_vacuous_reason":
                "MEASURED: 40 document(s) declare a time-reference family; "
                "40 slot(s) examined; 40 carry at least one populated member.",
            "shape_census_vacuous": False,
            "shape_census_vacuous_reason":
                "MEASURED: 4 multi-reference statement(s), 3 shaped, 1 not "
                "shapeable (referent outside the batch), 2 distinct shape(s).",
            "headline":
                "DENOMINATOR: 1000 document(s) inspected (0 unreadable, 0 "
                "unclassifiable, 0 class-unresolved); 40 declare a "
                "time-reference family; 40 slot(s); 40 statement(s) carry a "
                "reference; 4 carry more than one.",
        }
        b.update(over)
        return b

    def _corpus(self, name, block, **rest):
        body = {"corpus": name, "total": 1000, "migrated_count": 1000,
                "quarantine_count": 0}
        if block is not None:
            body["time_reference_families"] = block
        body.update(rest)
        self.write(name, body)

    # ---- slicing helpers -------------------------------------------------

    def _per_corpus(self, text, corpus="A"):
        """The #52 block for ONE corpus, cut out of the whole digest.

        Bounded ABOVE by the corpus header and BELOW by the next block's
        header, so a line that leaked in from the cross-corpus rollup cannot
        satisfy a per-corpus assertion.
        """
        start = text.index("--- %s ---" % corpus)
        body = text[start:]
        head = body.index("#52 EVIDENCE")
        tail = body.index("EPOCH ASSOCIATION (#72)", head)
        return body[head:tail]

    def _rollup(self, text):
        """The cross-corpus #52 block only."""
        start = text.index("ACROSS ALL CORPORA")
        body = text[start:]
        head = body.index("#52 -- TIME REFERENCES PER STATEMENT")
        return body[head:]

    def _reference_half(self, block):
        """From `REFERENCE CENSUS:` to `SHAPE CENSUS:` -- and NOT past it."""
        return block[block.index("REFERENCE CENSUS:"):
                     block.index("SHAPE CENSUS:")]

    def _shape_half(self, block):
        """From `SHAPE CENSUS:` to the derived-regime line."""
        return block[block.index("SHAPE CENSUS:"):
                     block.index("SHAPE-CENSUS REGIME")]

    # ---- the block exists at all ----------------------------------------

    def test_the_per_corpus_block_is_rendered(self):
        # The whole point: this instrument ran and printed NOWHERE. A block in
        # the artifact and not on the screen is the epochMint defect.
        self._corpus("A", self._block())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("#52 EVIDENCE -- TIME-REFERENCE FAMILIES PER STATEMENT",
                      text[:text.index("ACROSS ALL CORPORA")])

    def test_the_cross_corpus_block_is_rendered(self):
        # Asserted SEPARATELY from the per-corpus one: they are two call sites
        # and removing either must redden a test of its own.
        self._corpus("A", self._block())
        text, _ = self.run_digest()
        self.assertIn("#52 -- TIME REFERENCES PER STATEMENT",
                      text[text.index("ACROSS ALL CORPORA"):])

    def test_it_is_never_added_to_the_uniqueness_table(self):
        # The two are the #52 pair and they answer different questions. Both
        # blocks say so in their own words, so a reader who arrives at either
        # one first is told.
        self._corpus("A", self._block())
        text, _ = self.run_digest()
        self.assertIn("a SEPARATE bucket from the family-UNIQUENESS violations",
                      self._per_corpus(text))
        self.assertIn("do NOT add this to the", self._rollup(text))

    # ---- reading order ---------------------------------------------------

    def test_the_headline_and_both_verdicts_precede_every_count(self):
        # The instrument's author handed this over as the reading order and it
        # is not stylistic: every count here has a meaning that depends on
        # which vacuity regime produced it.
        self._corpus("A", self._block())
        block = self._per_corpus(self.run_digest()[0])
        head = block.index("DENOMINATOR: 1000 document(s) inspected")
        ref = block.index("REFERENCE CENSUS:")
        shape = block.index("SHAPE CENSUS:")
        rows = block.index("DENOMINATOR ROWS")
        self.assertLess(head, ref)
        self.assertLess(ref, shape)
        self.assertLess(shape, rows)

    # ---- the two verdicts, each checked in its OWN half ------------------

    def test_the_reference_verdict_renders_in_its_own_half(self):
        self._corpus("A", self._block())
        half = self._reference_half(self._per_corpus(self.run_digest()[0]))
        self.assertIn("REFERENCE CENSUS: MEASURED", half)
        self.assertIn("40 document(s) declare a time-reference family", half)

    def test_the_shape_verdict_renders_in_its_own_half(self):
        self._corpus("A", self._block())
        half = self._shape_half(self._per_corpus(self.run_digest()[0]))
        self.assertIn("SHAPE CENSUS: MEASURED", half)
        self.assertIn("4 multi-reference statement(s), 3 shaped", half)

    def test_a_missing_reference_verdict_is_not_covered_by_the_shape_one(self):
        # The mutation this exists for: delete one banner and the other keeps a
        # whole-digest assertion green. Each half is asserted to carry ITS OWN
        # flag name, so neither can stand in for the other.
        self._corpus("A", self._block())
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("REFERENCE CENSUS:", self._reference_half(block))
        self.assertNotIn("SHAPE CENSUS:", self._reference_half(block))
        self.assertIn("SHAPE CENSUS:", self._shape_half(block))
        self.assertNotIn("REFERENCE CENSUS:", self._shape_half(block))

    def test_a_verdict_with_no_reason_string_says_so(self):
        # `_reason` is written on every path out of the instrument, so an
        # absent one is a finding about the report and not a formatting detail.
        b = self._block()
        del b["shape_census_vacuous_reason"]
        self._corpus("A", b)
        half = self._shape_half(self._per_corpus(self.run_digest()[0]))
        self.assertIn("carries NO `shape_census_vacuous_reason`", half)

    def test_a_flag_that_contradicts_its_own_reason_is_flagged(self):
        # The flag says MEASURED and the sentence opens VACUOUS. Trust neither.
        b = self._block(shape_census_vacuous_reason="VACUOUS: something else.")
        self._corpus("A", b)
        half = self._shape_half(self._per_corpus(self.run_digest()[0]))
        self.assertIn("THE FLAG AND ITS REASON DISAGREE", half)

    # ---- the THREE ways the shape census reads empty ---------------------

    def test_no_document_could_have_carried_a_reference(self):
        # reference_census_vacuous. Every count below it is empty by
        # construction and says nothing about time references.
        b = self._block(
            docs_declaring_family=0, slots_examined=0, members_examined=0,
            statements_with_reference=0, statements_multi_reference=0,
            count_distribution=[], shape=[], emitter=[],
            shape_denominator={"multi_slots_examined": 0,
                               "multi_slots_shaped": 0,
                               "multi_slots_unresolved": 0,
                               "multi_members_examined": 0,
                               "multi_members_resolved": 0,
                               "multi_members_unresolved": 0},
            emitter_denominator={"multi_slots_with_statement_name": 0,
                                 "multi_slots_without_statement_name": 0},
            reference_census_vacuous=True,
            reference_census_vacuous_reason=(
                "VACUOUS: 1000 document(s) classified, NONE belonging to a "
                "class whose chain declares a time-reference family. No "
                "document in this batch could have carried a time reference, "
                "so every count below is empty by construction and says "
                "nothing about time references."),
            shape_census_vacuous=True,
            shape_census_vacuous_reason=(
                "VACUOUS: the reference census itself was vacuous -- see its "
                "reason."))
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("REFERENCE CENSUS: VACUOUS", self._reference_half(block))
        self.assertIn("could have carried a time reference",
                      self._reference_half(block))
        self.assertIn("NOT REACHED -- the reference census was itself vacuous",
                      block)

    def test_no_statement_carries_a_second_reference_is_a_result(self):
        # shape_census_vacuous, reading ONE: the undefined regime is empty in
        # this batch. That agrees with the signed model's prediction.
        b = self._block(
            statements_multi_reference=0,
            count_distribution=[{"members": 1, "statements": 40}],
            shape=[], emitter=[],
            shape_denominator={"multi_slots_examined": 0,
                               "multi_slots_shaped": 0,
                               "multi_slots_unresolved": 0,
                               "multi_members_examined": 0,
                               "multi_members_resolved": 0,
                               "multi_members_unresolved": 0},
            emitter_denominator={"multi_slots_with_statement_name": 0,
                                 "multi_slots_without_statement_name": 0},
            shape_census_vacuous=True,
            shape_census_vacuous_reason=(
                "VACUOUS: 40 statement(s) carry a time reference and EVERY ONE "
                "carries exactly one. No statement is in the undefined regime, "
                "so the shape table could not fire; its emptiness is 'the case "
                "does not occur here', not 'the shapes are fine'."))
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("SHAPE CENSUS: VACUOUS", self._shape_half(block))
        self.assertIn("UNOCCUPIED -- statements carry a reference, none "
                      "carries two (a RESULT)", block)
        # ...and it must NOT print the occupied-and-unmeasured alarm.
        self.assertNotIn("THE UNDEFINED REGIME IS OCCUPIED", block)

    def test_multi_reference_statements_with_none_shapeable_is_not_clean(self):
        # shape_census_vacuous, reading TWO -- the SAME flag, the OPPOSITE
        # finding. The regime is occupied and nobody measured it. This is the
        # one zero in the block that must never read as clean.
        b = self._block(
            statements_multi_reference=9,
            count_distribution=[{"members": 1, "statements": 31},
                                {"members": 2, "statements": 9}],
            statements_with_reference=40,
            shape=[{"shape_key": TRF_NOT_SHAPEABLE, "statements": 9,
                    "members": 2, "example_document_id": "q",
                    "example_class_name": "epoch",
                    "family": "time_reference_#"}],
            shape_denominator={"multi_slots_examined": 9,
                               "multi_slots_shaped": 0,
                               "multi_slots_unresolved": 9,
                               "multi_members_examined": 18,
                               "multi_members_resolved": 9,
                               "multi_members_unresolved": 9},
            emitter=[{"shape_key": TRF_NOT_SHAPEABLE,
                      "statement_class": "epoch",
                      "statement_name": "migrated_epoch_extent",
                      "anchor_names": "<unresolved>", "statements": 9}],
            emitter_denominator={"multi_slots_with_statement_name": 9,
                                 "multi_slots_without_statement_name": 0},
            shape_census_vacuous=True,
            shape_census_vacuous_reason=(
                "VACUOUS: 9 multi-reference statement(s) found, and EVERY ONE "
                "had at least one referent outside this batch, so no shape "
                "could be computed. The regime is occupied and UNMEASURED -- "
                "this is the one zero that must never read as clean."))
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("SHAPE CENSUS: VACUOUS", self._shape_half(block))
        self.assertIn("OCCUPIED AND UNMEASURED", block)
        self.assertIn("THE UNDEFINED REGIME IS OCCUPIED AND WAS NOT MEASURED",
                      block)
        # ...and it must NOT print the "a RESULT" reassurance, which is the
        # other reading of the same flag.
        self.assertNotIn("none carries two (a RESULT)", block)

    def test_the_regime_is_derived_from_the_counters_not_the_flag(self):
        # A block whose flag has been set wrong still classifies correctly:
        # trf_shape_regime reads the numbers. Four inputs, four answers.
        self.assertEqual(trf_shape_regime(
            {"reference_census_vacuous": True}), "not_reached")
        self.assertEqual(trf_shape_regime(
            {"reference_census_vacuous": False, "docs_declaring_family": 0}),
            "not_reached")
        self.assertEqual(trf_shape_regime(
            {"reference_census_vacuous": False, "docs_declaring_family": 5,
             "statements_multi_reference": 0}), "unoccupied")
        self.assertEqual(trf_shape_regime(
            {"reference_census_vacuous": False, "docs_declaring_family": 5,
             "statements_multi_reference": 9,
             "shape_denominator": {"multi_slots_shaped": 0}}),
            "occupied_unmeasured")
        self.assertEqual(trf_shape_regime(
            {"reference_census_vacuous": False, "docs_declaring_family": 5,
             "statements_multi_reference": 9,
             "shape_denominator": {"multi_slots_shaped": 3}}), "measured")

    # ---- absent is not zero ----------------------------------------------

    def test_a_report_predating_the_instrument_is_named_not_summed(self):
        # THE RULE THIS BLOCK EXISTS UNDER. A report with no block contributes
        # NOTHING and is named; it is never a corpus that measured a zero.
        self._corpus("A", self._block())
        self._corpus("Old", None)
        text, _ = self.run_digest()
        old = self._per_corpus(text, "Old")
        self.assertIn("NOT MEASURED", old)
        self.assertIn("PREDATES the instrument", old)
        # No counts for it, and the rollup denominator says 1 of 2.
        self.assertNotIn("DENOMINATOR ROWS", old)
        roll = self._rollup(text)
        self.assertIn("2 corpus report(s); 1 carried a readable block, "
                      "1 did not", roll)
        self.assertIn("NOT MEASURED in: Old", roll)
        self.assertIn("sums over 1 corpora, not 2", roll)
        # ...and its 1000 documents are NOT in the inspected total.
        self.assertIn("1000 document(s) inspected in total", roll)

    def test_an_absent_counter_prints_absent_and_not_zero(self):
        b = self._block()
        del b["docs_with_an_id"]
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("(absent)  DISTINCT document ids indexed", block)

    def test_a_failed_audit_is_not_a_zero(self):
        self._corpus("A", {"audit_failed": "Undefined function 'classChain'"})
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("audit FAILED (Undefined function 'classChain')", block)
        self.assertNotIn("DENOMINATOR ROWS", block)

    def test_no_schema_cache_reads_as_did_not_look(self):
        # The instrument's own words. Every count is 0 on this path and none of
        # them is a finding.
        b = self._block(schema_cache_available=False)
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("no schema cache was available", block)
        self.assertNotIn("DENOMINATOR ROWS", block)

    # ---- the union, and the summing trap ---------------------------------

    def test_the_rollup_unites_shape_rows_by_key_instead_of_summing_them(self):
        # THE TRAP, verbatim from one file over: the relaxed-edge rollup ADDED
        # per-corpus distinct counts, so a pair in three corpora counted 3 and
        # a published "7 of 26 seen" was an upper bound. A shape is the same
        # kind of identity. Here the SPLIT shape is in BOTH corpora and the
        # NCLOCK shape in one, so the distinct figure is 2 and the summed row
        # count is 3.
        self._corpus("A", self._block())
        b2 = self._block(
            shape=[{"shape_key": self.SPLIT, "statements": 5, "members": 2,
                    "example_document_id": "zzz",
                    "example_class_name": "subject_interaction",
                    "family": "time_reference_#"},
                   {"shape_key": self.NCLOCK, "statements": 2, "members": 2,
                    "example_document_id": "yyy",
                    "example_class_name": "epoch",
                    "family": "time_reference_#"}],
            statements_multi_reference=7,
            count_distribution=[{"members": 1, "statements": 33},
                                {"members": 2, "statements": 7}],
            shape_denominator={"multi_slots_examined": 7,
                               "multi_slots_shaped": 7,
                               "multi_slots_unresolved": 0,
                               "multi_members_examined": 14,
                               "multi_members_resolved": 14,
                               "multi_members_unresolved": 0},
            emitter=[{"shape_key": self.SPLIT,
                      "statement_class": "subject_interaction",
                      "statement_name": "migrated_valid_interval",
                      "anchor_names": "migrated_valid_interval_anchor",
                      "statements": 5},
                     {"shape_key": self.NCLOCK, "statement_class": "epoch",
                      "statement_name": "migrated_epoch_extent",
                      "anchor_names": "migrated_epoch_extent_anchor",
                      "statements": 2}],
            emitter_denominator={"multi_slots_with_statement_name": 7,
                                 "multi_slots_without_statement_name": 0})
        self._corpus("B", b2)
        roll = self._rollup(self.run_digest()[0])
        self.assertIn("SHAPES, UNITED BY `shape_key` ACROSS CORPORA -- NOT "
                      "SUMMED.", roll)
        self.assertIn("2 distinct shape(s) in the union", roll)
        # The summed figure is printed BESIDE it, named as the wrong one.
        self.assertIn("the per-corpus shape-row counts ADD to 3", roll)
        # The shared shape appears ONCE, with both corpora named on it.
        self.assertEqual(roll.count(self.SPLIT), 2)  # shape row + emitter row
        self.assertIn("seen in: A, B", roll)
        # Its slot counts DO add -- occurrences are not identities.
        self.assertIn("8 slot(s)  members=2  " + self.SPLIT, roll)

    def test_the_pseudo_row_is_not_counted_as_a_shape(self):
        # `<NOT SHAPEABLE ...>` is a row so the table PARTITIONS the multi
        # slots, and it is not a shape. The instrument's own MEASURED sentence
        # counts it, which is why the digest says so out loud.
        self._corpus("A", self._block())
        text, _ = self.run_digest()
        block = self._per_corpus(text)
        self.assertIn("SHAPES: 2 table row(s) -- 1 shape(s) and 1 "
                      "NOT-SHAPEABLE", block)
        self.assertIn("that sentence is one high", block)
        roll = self._rollup(text)
        self.assertIn("1 distinct shape(s) in the union", roll)
        self.assertIn("Plus 1 NOT-SHAPEABLE pseudo-row (1 slot(s))", roll)

    def test_the_pseudo_row_total_is_checked_against_its_counter(self):
        # If the MATLAB literal ever drifts, the row silently becomes an
        # ordinary shape. The invariant catches it.
        b = self._block()
        b["shape"][1]["shape_key"] = "<NOT SHAPEABLE -- something else>"
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("INTERNAL CONSISTENCY: 8 invariant(s) checked, "
                      "1 disagreement(s)", block)
        self.assertIn("the NOT-SHAPEABLE pseudo-row matches its counter",
                      block)

    # ---- the alarms ------------------------------------------------------

    def test_a_distribution_row_at_two_is_marked_undefined(self):
        self._corpus("A", self._block())
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("4 slot(s) carry 2 populated member(s)   <-- UNDEFINED "
                      "REGIME", block)
        self.assertNotIn("carry 1 populated member(s)   <-- UNDEFINED", block)

    def test_a_member_that_is_not_a_time_reference_is_flagged(self):
        # `must_refer` is existence-only, so such a document validates clean.
        # The instrument calls it "a finding, not something to round off".
        b = self._block()
        b["shape"][0]["shape_key"] = self.OTHER
        b["emitter"][0]["shape_key"] = self.OTHER
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("A MEMBER OF THIS FAMILY IS NOT A TIME REFERENCE", block)

    def test_two_families_on_one_class_changes_what_a_slot_means(self):
        b = self._block(docs_declaring_two_families=2)
        self._corpus("A", b)
        text, _ = self.run_digest()
        self.assertIn("A CLASS IN THIS BATCH DECLARES TWO TIME-REFERENCE",
                      self._per_corpus(text))
        self.assertIn("TWO FAMILIES ON ONE CLASS in: A", self._rollup(text))

    def test_an_unresolvable_class_is_not_looked_at(self):
        b = self._block(docs_class_unresolved=7)
        self._corpus("A", b)
        text, _ = self.run_digest()
        self.assertIn("name a class the schema cache could not",
                      self._per_corpus(text))
        self.assertIn("CLASSES THE CACHE COULD NOT RESOLVE in: A (7)",
                      self._rollup(text))

    def test_a_broken_partition_is_reported_as_an_instrument_defect(self):
        b = self._block()
        b["shape_denominator"]["multi_slots_shaped"] = 2
        self._corpus("A", b)
        block = self._per_corpus(self.run_digest()[0])
        self.assertIn("INTERNAL CONSISTENCY: 8 invariant(s) checked, "
                      "1 disagreement(s)", block)
        self.assertIn("the shape pass partitions its slots", block)
        self.assertIn("NOT a property of the corpus", block)

    # ---- the reading instructions ---------------------------------------

    def test_the_reading_instructions_name_what_to_be_alarmed_by(self):
        # They are read off timeReferenceFamilies.m, and the point of asserting
        # them is that a block whose prose is deleted stops telling a reader
        # which zero is which.
        self._corpus("A", self._block())
        roll = self._rollup(self.run_digest()[0])
        self.assertIn("WHAT TO BE ALARMED BY IN THIS BLOCK", roll)
        self.assertIn("ANY DISTRIBUTION ROW AT 2 OR MORE", roll)
        self.assertIn("MULTI-REFERENCE STATEMENTS WITH NONE SHAPEABLE", roll)
        self.assertIn("WHAT THIS BLOCK CANNOT TELL YOU", roll)
        self.assertIn("WHETHER AN INDEX MEANS A ROLE", roll)
        self.assertIn("THE CORPORA ARE A SAMPLE OF DATASETS", roll)

    def test_the_digest_proposes_no_role_name(self):
        # #52 is the team's call. A digest that suggested `start_anchor` would
        # be answering the question its own output exists to inform.
        self._corpus("A", self._block())
        text, _ = self.run_digest()
        for invented in ("start_anchor", "end_anchor", "role_name",
                         "should be named", "we recommend"):
            self.assertNotIn(invented, self._rollup(text))

    # ---- MATLAB shapes ---------------------------------------------------

    def test_a_single_row_table_arrives_as_a_bare_object(self):
        # jsonencode writes a 1-element struct array as an object. The shape
        # that killed run #256 after 2h49m, applied to this block's four
        # list-shaped fields.
        b = self._block(
            count_distribution={"members": 2, "statements": 4},
            shape={"shape_key": self.SPLIT, "statements": 4, "members": 2,
                   "example_document_id": "abc123",
                   "example_class_name": "subject_interaction",
                   "family": "time_reference_#"},
            emitter={"shape_key": self.SPLIT,
                     "statement_class": "subject_interaction",
                     "statement_name": "migrated_valid_interval",
                     "anchor_names": "migrated_valid_interval_anchor",
                     "statements": 4},
            statements_with_reference=4,
            shape_denominator={"multi_slots_examined": 4,
                               "multi_slots_shaped": 4,
                               "multi_slots_unresolved": 0,
                               "multi_members_examined": 8,
                               "multi_members_resolved": 8,
                               "multi_members_unresolved": 0},
            emitter_denominator={"multi_slots_with_statement_name": 4,
                                 "multi_slots_without_statement_name": 0})
        self._corpus("A", b)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("4 slot(s)  2 member(s)  " + self.SPLIT,
                      self._per_corpus(text))

    def test_the_reader_survives_a_malformed_block(self):
        self._corpus("A", ["not", "an", "object"])
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("malformed (list)", self._per_corpus(text))

    def test_the_reader_is_a_function_a_caller_can_use(self):
        # Same contract as ndi_required/epoch_association: measured + why.
        self.assertFalse(time_reference_families({})["measured"])
        self.assertIn("PREDATES", time_reference_families({})["why"])
        self.assertTrue(time_reference_families(
            {"time_reference_families": self._block()})["measured"])


# =====================================================================
# THE BATCH-POST-PASS CENSUS
# =====================================================================
#
# WHAT THESE ARE FOR. The digest printed "BATCH POST-PASSES: 2 expected in a
# V_eta run" while `runCorpusDiscovery` composed NINE, and every pass the
# digest's own table omitted produced no line at all -- no counter, no
# denominator, not even a note that it had not been read. The two passes it
# omitted were not new and not obscure: `resolveDeferredBaths` is the FIRST
# pass in the chain and `resolveDatasetEntities` DELETES documents.
#
# The number was wrong because it came from the wrong place. POST_PASSES is a
# render table; the chain is decided by the call sites. So these tests assert
# the SOURCE of the expected set, not its value:
#
#   * the set is derived from the report-writing call sites and the convert
#     package's signatures, so a pass added to the harness is expected here on
#     the same commit;
#   * a pass that RAN and attached no report is COUNTED AND NAMED, in wording
#     that cannot be confused with a pass that did not run;
#   * the census (expected / seen / unmeasured) precedes any per-pass detail;
#   * an underivable chain says NOT DERIVED and calls the table a floor, rather
#     than falling back and printing a confident number.
#
# Each was run against the pre-change digest, or against a mutated copy of the
# new one, and each failed there. A test written from the same premise as the
# code cannot catch the code.

import census_digest  # noqa: E402


class PassCensusTree(unittest.TestCase):
    """Build a throwaway repo tree so the derivation can be driven, not mocked.

    A test that monkeypatched `harness_pass_chain` would assert that the
    renderer prints whatever it is handed, which is the one thing never in
    doubt. The question is whether the DERIVATION reads MATLAB correctly, so
    these write MATLAB.
    """

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.pkg = os.path.join(self.root, census_digest.CONVERT_PKG)
        os.makedirs(self.pkg)
        for label, rel in census_digest.REPORT_WRITING_CALL_SITES:
            os.makedirs(os.path.dirname(os.path.join(self.root, rel)),
                        exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def pass_file(self, name, outputs="[result, report]", first="result"):
        with open(os.path.join(self.pkg, name + ".m"), "w") as fh:
            fh.write("function %s = %s(%s, options)\n%%%s\nend\n"
                     % (outputs, name, first, name.upper()))

    def call_site(self, body):
        for _label, rel in census_digest.REPORT_WRITING_CALL_SITES:
            with open(os.path.join(self.root, rel), "w") as fh:
                fh.write(body)

    def chain(self):
        return census_digest.harness_pass_chain(self.root, _cache=False)


class TestPassSetIsDerived(PassCensusTree):
    def test_a_bare_call_and_a_guarded_call_are_both_in_the_chain(self):
        self.pass_file("alpha")
        self.pass_file("beta")
        self.call_site(
            "result = did2.convert.alpha(result, 'Validate', true);\n"
            "result = did2.unittest.helpers.runBatchPass(result, ...\n"
            "    'did2.convert.beta', 'beta_fold', ...\n"
            "    @(r) did2.convert.beta(r, 'Validate', true));\n")
        ch = self.chain()
        self.assertTrue(ch["derived"])
        self.assertEqual(ch["chain"], ["alpha", "beta"])
        # Only the guarded one attaches a report field, and that asymmetry is
        # the fact the whole census turns on.
        self.assertEqual(ch["fields"], {"beta": "beta_fold"})

    def test_a_function_whose_first_argument_is_not_result_is_not_a_pass(self):
        # v1_to_v2(v1Bodies, ...) is the real member of this class: called by
        # every call site, not a batch post-pass. Excluded by SIGNATURE, so no
        # hand-written exclusion list can go stale.
        self.pass_file("perDocument", outputs="result", first="v1Bodies")
        self.pass_file("alpha")
        self.call_site("result = did2.convert.perDocument(bodies);\n"
                       "result = did2.convert.alpha(result);\n")
        ch = self.chain()
        self.assertEqual(ch["chain"], ["alpha"])
        self.assertEqual(ch["called_not_a_pass"], ["perDocument"])

    def test_a_pass_named_only_in_a_comment_is_not_in_the_chain(self):
        # ndi.migrate.local NAMES did2.convert.resolveDeferredBaths in five
        # comments and calls it nowhere; a scan that accepted prose would
        # report a chain assembled from documentation.
        self.pass_file("alpha")
        self.pass_file("ghost")
        self.call_site("% see also did2.convert.ghost(result) for the precise\n"
                       "%{\n"
                       "result = did2.convert.ghost(result);\n"
                       "%}\n"
                       "result = did2.convert.alpha(result);  % did2.convert.ghost(\n")
        ch = self.chain()
        self.assertEqual(ch["chain"], ["alpha"])
        self.assertEqual(ch["unwired"], ["ghost"])

    def test_a_quoted_pass_name_is_not_a_call(self):
        # The harness carries every pass name as a quoted string, twice over
        # (runBatchPass's argument and its own stdout table). A scan that
        # counted those would report a chain built from a table.
        self.pass_file("alpha")
        self.pass_file("tabled")
        self.call_site("expected = { 'tabled_fold', 'did2.convert.tabled' };\n"
                       "result = did2.convert.alpha(result);\n")
        self.assertEqual(self.chain()["chain"], ["alpha"])

    def test_a_pass_the_call_sites_never_compose_is_reported_unwired(self):
        # resolveSessionAnchors sat built, tested and uncalled for a day.
        self.pass_file("alpha")
        self.pass_file("neverCalled")
        self.call_site("result = did2.convert.alpha(result);\n")
        self.assertEqual(self.chain()["unwired"], ["neverCalled"])

    def test_call_sites_that_disagree_are_a_finding(self):
        self.pass_file("alpha")
        self.pass_file("beta")
        sites = census_digest.REPORT_WRITING_CALL_SITES
        with open(os.path.join(self.root, sites[0][1]), "w") as fh:
            fh.write("result = did2.convert.alpha(result);\n"
                     "result = did2.convert.beta(result);\n")
        with open(os.path.join(self.root, sites[1][1]), "w") as fh:
            fh.write("result = did2.convert.alpha(result);\n")
        ch = self.chain()
        self.assertEqual([fn for fn, _who in ch["site_disagreement"]], ["beta"])

    def test_an_unreadable_source_is_not_derived_and_says_so(self):
        # Nothing may fall back quietly to the render table: "could not ask"
        # and "asked, everything agreed" must not print the same.
        ch = census_digest.harness_pass_chain(
            os.path.join(self.root, "nowhere"), _cache=False)
        self.assertFalse(ch["derived"])
        out = []
        census_digest.render_pass_census(out, ch)
        text = "\n".join(out)
        self.assertIn("NOT DERIVED", text)
        self.assertIn("FLOOR", text)
        self.assertIn("NOT FOUND", text)


class TestPassCensusRendering(DigestCase):
    """What the digest PRINTS about passes it cannot measure."""

    def _chain(self, chain, fields, derived=True, unmeasured=()):
        sites = [{"label": lbl, "path": "/x/" + lbl, "exists": True,
                  "lines": 10, "chain": chain}
                 for lbl, _rel in census_digest.REPORT_WRITING_CALL_SITES]
        return {"derived": derived, "chain": chain, "fields": fields,
                "sites": sites,
                "package": {"path": "/x", "files": len(chain), "exists": True,
                            "passes": sorted(chain)},
                "site_disagreement": [], "called_not_a_pass": [],
                "unwired": list(unmeasured)}

    def test_a_pass_that_attaches_no_report_is_named_unmeasured(self):
        # THE DEFECT. Such a pass produced NO LINE AT ALL: "ran and reported
        # nothing" and "does not exist" were the same output.
        #
        # THE FIXTURE USED `resolveDeferredBaths`, WHICH IS NO LONGER
        # UNMEASURED -- it and `resolveDatasetEntities` gained report structs
        # and render rows on 2026-08-11, which is the outcome this whole census
        # existed to force. The property is unchanged and still worth guarding:
        # a TENTH pass wired in tomorrow with no report must be named, not
        # silently omitted. So the fixture now uses a pass that genuinely has
        # no row, rather than the assertion being relaxed to keep passing.
        out = []
        census_digest.render_post_passes(
            {"epoch_mint": {"ran": True, "documents_inspected": 5}}, out,
            self._chain(["aPassNobodyHasWrittenRowsFor", "epochMint"],
                        {"epochMint": "epoch_mint"}))
        text = "\n".join(out)
        self.assertIn("aPassNobodyHasWrittenRowsFor", text)
        self.assertIn("RAN, MEASURED BY NOTHING", text)
        self.assertIn("1 carry a report here", text)
        self.assertIn("1 UNMEASURED BY CONSTRUCTION", text)

    def test_unmeasured_does_not_read_like_not_wired(self):
        # The two are opposite readings: one pass ran and left no trace, the
        # other never ran. They must not share wording.
        out = []
        census_digest.render_post_passes(
            {}, out, self._chain(["resolveDeferredBaths", "epochMint"],
                                 {"epochMint": "epoch_mint"}))
        text = "\n".join(out)
        unmeasured = [ln for ln in out if "resolveDeferredBaths" in ln]
        self.assertTrue(unmeasured)
        for line in unmeasured:
            self.assertNotIn("NOT IN THIS REPORT", line)
        self.assertIn("NOT IN THIS REPORT", text)   # epoch_mint's line

    def test_the_unmeasured_count_leads_the_block(self):
        out = []
        census_digest.render_post_passes(
            {}, out, self._chain(["resolveDeferredBaths", "epochMint"],
                                 {"epochMint": "epoch_mint"}))
        head = out[0]
        self.assertIn("expected", head)
        self.assertIn("UNMEASURED BY CONSTRUCTION", head)
        # ... and before any per-pass line.
        first_detail = min(i for i, ln in enumerate(out)
                           if "resolveDeferredBaths" in ln
                           or "epoch_mint" in ln)
        self.assertLess(0, first_detail)

    def test_a_render_table_entry_no_call_site_composes_is_flagged(self):
        # Stale in the reassuring direction: rendering counters for a pass
        # nothing runs reads as coverage.
        out = []
        census_digest.render_post_passes(
            {}, out, self._chain(["epochMint"], {"epochMint": "epoch_mint"}))
        text = "\n".join(out)
        self.assertIn("COMPOSED BY NO", text)
        self.assertIn("session_anchor_fold", text)

    def test_a_carried_report_with_no_render_rows_is_named(self):
        out = []
        census_digest.render_post_passes(
            {"newthing": {"ran": True, "widgets": 3}}, out,
            self._chain(["brandNew"], {"brandNew": "newthing"}))
        text = "\n".join(out)
        self.assertIn("NO ROWS", text)
        self.assertIn("brandNew", text)


class TestPassCensusInTheDenominator(DigestCase):
    def test_the_census_precedes_every_report_and_every_pass_detail(self):
        self.write("A", {"corpus": "A", "migrated_count": 1,
                         "quarantine_count": 0})
        lines, _failed = digest(self.dir)
        head = [i for i, ln in enumerate(lines)
                if "BATCH POST-PASS CENSUS" in ln]
        self.assertTrue(head, "the census must be part of the leading denominator")
        first_corpus = min(i for i, ln in enumerate(lines) if "--- A ---" in ln)
        self.assertLess(head[0], first_corpus)
        census = "\n".join(lines[head[0]:first_corpus])
        self.assertIn("EXPECTED", census)
        self.assertIn("UNMEASURED", census)
        self.assertIn("DENOMINATOR", census)

    def test_the_census_prints_when_there_are_no_reports_at_all(self):
        # A pass that measures nothing is a fact about the PIPELINE. It must
        # not become invisible because the input was empty -- that is run #3's
        # "NO CORPUS REPORTS FOUND", exit 0, one level up.
        lines, failed = digest(os.path.join(self.dir, "empty"))
        text = "\n".join(lines)
        self.assertIn("BATCH POST-PASS CENSUS", text)
        self.assertIn("NO CORPUS REPORTS FOUND", text)
        self.assertNotEqual(failed, [])


class TestThisRepositoryAgrees(unittest.TestCase):
    """Run the derivation against THIS checkout. Not a fixture -- the tree.

    A synthetic tree proves the parser; only the real one proves the parser
    reads the real harness. These are the assertions that would have caught
    the 2-vs-9 gap on the day it opened.
    """

    def setUp(self):
        self.root = census_digest.REPO_ROOT
        self.chain = census_digest.harness_pass_chain(self.root, _cache=False)
        if not self.chain["derived"]:
            self.skipTest("harness sources not present in this checkout")

    def test_every_pass_the_harness_composes_is_expected_by_the_digest(self):
        expected = {e["fn"] for e in
                    census_digest.post_pass_expectations(self.chain)}
        missing = sorted(set(self.chain["chain"]) - expected)
        self.assertEqual(missing, [], "passes the harness runs and the digest "
                                      "does not expect: %s" % missing)

    def test_the_expected_set_is_at_least_the_render_table(self):
        self.assertGreaterEqual(
            len(census_digest.post_pass_expectations(self.chain)),
            len(census_digest.POST_PASSES))

    def test_the_two_report_writing_call_sites_compose_the_same_chain(self):
        # They write into the SAME digest. A chain that differs between them
        # makes two reports incomparable, and nothing else compares them.
        #
        # THE DENOMINATOR FIRST, AND IT IS NOT DECORATION: with one site read,
        # "no disagreement" is true by construction. A shrunken site list would
        # otherwise turn this test green by removing its subject.
        read = [s for s in self.chain["sites"] if s["exists"]]
        self.assertGreaterEqual(len(read), 2,
                                "fewer than two report-writing call sites were "
                                "read: %s" % [s["path"] for s in
                                              self.chain["sites"]])
        for site in read:
            self.assertTrue(site["chain"], "%s composed nothing" % site["path"])
        self.assertEqual(self.chain["site_disagreement"], [])

    def test_no_batch_post_pass_in_the_package_is_composed_by_neither_site(self):
        self.assertEqual(self.chain["unwired"], [])

    def test_the_harness_stdout_table_names_exactly_the_reporting_passes(self):
        """`printBatchPasses`'s `expected` cell array is a SECOND hand list.

        It lives in MATLAB and cannot be exercised without MATLAB, so it is
        gated from here instead: it may name exactly the passes that go through
        `runBatchPass` (the only ones that attach a report field it could
        print), no more and no fewer. A pass added to the chain with a report
        field and forgotten in that table would print nothing in the corpus
        log, which is the same invisibility one layer down.
        """
        path = os.path.join(self.root,
                            census_digest.REPORT_WRITING_CALL_SITES[0][1])
        body = census_digest.strip_matlab_comments(open(path).read())
        import re
        tabled = set(re.findall(
            r"'(\w+)',\s*\.{0,3}\s*'did2\.convert\.\w+'", body))
        self.assertTrue(tabled, "no printBatchPasses table found -- if it was "
                                "removed, delete this test with it")
        self.assertEqual(tabled, set(self.chain["fields"].values()))

    def test_the_two_independent_derivations_agree(self):
        """`tools/test_batch_pass_wiring.py` derives the same set, differently.

        It reads the report key from the PASS's own `result.<key> = report;`
        line; the digest reads it from the `runBatchPass` argument in the
        harness. Two routes to one fact, and nothing compared them -- which is
        how the render table came to say 7 while the wiring gate said 9 and
        both looked healthy from where they stood.

        A DISAGREEMENT HERE IS NOT COSMETIC: it means a pass attaches a report
        the harness does not name, or the harness names a key the pass does not
        attach. Either way one of the two is describing a pipeline that is not
        running.
        """
        try:
            import test_batch_pass_wiring as wiring
        except ImportError:                                   # pragma: no cover
            self.skipTest("tools/test_batch_pass_wiring.py not importable")
        passes, exempt, _n = wiring.discover()
        theirs = {name for name, _key in passes} | {n for n, _r in exempt}
        self.assertEqual(theirs, set(self.chain["chain"]))
        keys = {name: key for name, key in passes if key}
        self.assertEqual(keys, self.chain["fields"])
        # And the passes THEY record as report-less are exactly the ones this
        # digest prints as unmeasured.
        self.assertEqual(
            set(wiring.NO_REPORT_YET),
            set(self.chain["chain"]) - set(self.chain["fields"]))

    def test_the_passes_with_no_report_field_are_the_ones_reported_unmeasured(self):
        unmeasured = {e["fn"] for e in
                      census_digest.post_pass_expectations(self.chain)
                      if e["state"] == "unmeasured"}
        self.assertEqual(
            unmeasured,
            set(self.chain["chain"]) - set(self.chain["fields"]))


class TestReferenceIntegrity(DigestCase):
    """THE ORPHAN HALF OF THE GATE -- absent must print as ABSENT.

    The corpus gate is quoted everywhere as "0 quarantine + 0 orphans". Corpus
    run 31522068566 (job 93917442013) prints `quarantined: 0  fragments: 0`
    and no orphan figure anywhere in 2,790 lines: the only occurrences of the
    word are prose and openMINDS's `components_withheld (orphan guard)`, which
    counts something else. So the FIRST thing tested here is that a report
    with no orphan count says so loudly, because that is the state every
    corpus report is in today and silence is what let it last.
    """

    BARE = {"corpus": "Bare", "total": 10, "migrated_count": 12,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 12, "skipped_docs": 0}}

    def with_block(self, name, block):
        r = dict(self.BARE, corpus=name)
        r["reference_integrity"] = block
        return r

    def test_a_report_with_no_orphan_count_prints_ABSENT_not_silence(self):
        self.write("Bare", self.BARE)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("ORPHAN depends_on EDGES: *** NOT MEASURED IN THIS "
                      "REPORT ***", text)
        self.assertIn("THIS IS NOT A ZERO", text)

    def test_the_absent_message_says_what_would_have_to_change(self):
        # "Report what would have to change to measure it". THIS ASSERTION
        # MOVED 2026-08-12 and the move is the finding: the note used to say
        # "writeCorpusReport persists no orphan field", which was true and is
        # no longer -- the persistence landed. An absence now has THREE causes
        # and the note has to name them, because reading a post-wiring absence
        # as the pre-wiring one would send a reader to fix something already
        # fixed while the real cause (PRED) went untouched.
        self.write("Bare", self.BARE)
        text, _failed = self.run_digest()
        self.assertIn("did2.validate.references", text)
        self.assertIn("writeCorpusReport", text)
        self.assertIn("THE WIRING EXISTS AS OF 2026-08-12", text)
        self.assertIn("testCorpusPRED NEVER CALLS did2.validate.references",
                      text)
        self.assertIn("PREDATING the wiring", text)
        self.assertIn("audit_failed", text)

    def test_orphans_and_empty_edges_are_never_conflated(self):
        # references.m:90 skips empty edges, which is why mustBeNonEmpty on a
        # depends_on is decorative. The two counters answer different
        # questions and the output has to say so in both branches.
        self.write("Bare", self.BARE)
        absent, _ = self.run_digest()
        self.assertIn("references.m:90", absent)
        shutil.rmtree(self.dir, ignore_errors=True)
        os.mkdir(self.dir)
        self.write("Full", self.with_block("Full", {
            "total_docs": 12, "edges_examined": 40, "orphan_count": 0,
            "orphans": []}))
        present, _ = self.run_digest()
        self.assertIn("references.m:90", present)

    def test_both_denominators_print_BEFORE_the_orphan_count(self):
        # Rule 5, positionally: total_docs and edges_examined are the two
        # denominators and an orphan count without them is not evidence.
        self.write("Full", self.with_block("Full", {
            "total_docs": 12, "edges_examined": 40, "orphan_count": 2,
            "orphans": [{"doc_id": "a", "doc_class": "x",
                         "edge_name": "subject_id", "edge_document_id": "z"},
                        {"doc_id": "b", "doc_class": "x",
                         "edge_name": "subject_id", "edge_document_id": "y"}]}))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        docs = text.index("document(s) inspected  <- DENOMINATOR")
        edges = text.index("NON-EMPTY depends_on edge(s) examined")
        orphans = text.index("ORPHAN(S): edge names a document not in the batch")
        self.assertLess(docs, edges)
        self.assertLess(edges, orphans)
        self.assertIn("2  x.subject_id", text)

    def test_the_block_is_found_BY_SHAPE_whatever_the_key_is_called(self):
        # Nothing is persisted yet, so no key name is settled. Guessing one
        # and reporting ABSENT when the guess missed is the demo_ndi failure:
        # a query against a string the input never contained, reported as a
        # fact about the input.
        r = dict(self.BARE, corpus="Odd")
        r["whatever_they_called_it"] = {"total_docs": 3, "edges_examined": 9,
                                        "orphan_count": 0, "orphans": []}
        self.write("Odd", r)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("read", text)
        self.assertIn("`whatever_they_called_it`", text)
        self.assertNotIn("NOT MEASURED IN THIS REPORT", text)

    def test_zero_edges_examined_is_vacuous_not_clean(self):
        self.write("Empty", self.with_block("Empty", {
            "total_docs": 0, "edges_examined": 0, "orphan_count": 0,
            "orphans": []}))
        text, _failed = self.run_digest()
        self.assertIn("0 EDGES EXAMINED", text)
        self.assertIn("VACUOUS rather than clean", text)

    def test_a_key_NAMED_orphan_in_an_unrendered_shape_is_named(self):
        # "No such counter" and "a counter is here in a shape I do not render"
        # are different findings. The second one is a wiring mismatch and must
        # not print as an absence.
        r = dict(self.BARE, corpus="Mismatch")
        r["orphan_summary"] = 3
        self.write("Mismatch", r)
        text, _failed = self.run_digest()
        self.assertIn("NOT MEASURED IN THIS REPORT", text)
        self.assertIn("orphan_summary", text)
        self.assertIn("wiring mismatch", text)

    def test_two_blocks_carrying_orphan_count_refuse_to_choose(self):
        r = dict(self.BARE, corpus="Two")
        r["reference_integrity"] = {"orphan_count": 0, "edges_examined": 1}
        r["reference_report"] = {"orphan_count": 9, "edges_examined": 2}
        self.write("Two", r)
        text, _failed = self.run_digest()
        self.assertIn("will not choose between them", text)
        self.assertNotIn("9  ORPHAN(S)", text)

    def test_a_non_numeric_orphan_count_is_not_rendered_as_a_number(self):
        self.write("Junk", self.with_block("Junk", {
            "total_docs": 1, "edges_examined": 1, "orphan_count": "lots"}))
        text, _failed = self.run_digest()
        self.assertIn("is not a number", text)

    def test_the_rollup_says_ABSENT_when_NO_report_carries_one(self):
        # The state every corpus run to date has been in, said once, loudly.
        self.write("A", dict(self.BARE, corpus="A"))
        self.write("B", dict(self.BARE, corpus="B"))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("NO REPORT IN THIS RUN CARRIES AN ORPHAN COUNT AT ALL",
                      text)
        self.assertIn("THE SECOND HALF OF THE '0 quarantine + 0", text)

    def test_the_rollup_names_the_corpora_that_carried_nothing(self):
        # An absent count is never summed as a zero -- the same rule the
        # NDI-required and legacy-vintage rollups already apply.
        self.write("Has", self.with_block("Has", {
            "total_docs": 5, "edges_examined": 7, "orphan_count": 1,
            "orphans": [{"doc_id": "a", "doc_class": "c",
                         "edge_name": "e", "edge_document_id": "z"}]}))
        self.write("Lacks", dict(self.BARE, corpus="Lacks"))
        text, _failed = self.run_digest()
        self.assertIn("DENOMINATOR: 2 corpus report(s); 1 carried an orphan "
                      "count, 1 did not", text)
        self.assertIn("NOT MEASURED in: Lacks", text)
        self.assertIn("sums over 1 corpora, not 2", text)
        self.assertIn("1 orphan(s) across 1 row(s)", text)


class TestReferenceIntegrityPersisted(DigestCase):
    """THE HALF THAT WAS BUILT 2026-08-12 -- the count now REACHES the report.

    `V_eta_OPEN_WORK.md` #101: the orphan half of the "0 quarantine + 0
    orphans" gate was asserted by `runCorpusDiscovery` and never persisted,
    because `did2.validate.references` ran ~65 lines AFTER `writeCorpusReport`.
    The sweep now runs ABOVE it and the block lands on
    `result.reference_integrity`.

    EVERY FIXTURE HERE IS THE SHAPE `referenceIntegrityBlock` EMITS, not a
    shape convenient for the digest -- `audit`, both denominators, the COMPLETE
    `orphan_rows` aggregate and the CAPPED `orphans` sample. A test written
    from the digest's own premise cannot catch the digest.
    """

    BARE = {"corpus": "X", "total": 10, "migrated_count": 12,
            "quarantine_count": 0,
            "silent_loss": {"total_docs": 12, "skipped_docs": 0}}

    def harness_block(self, edges, orphans=(), cap=200):
        """Exactly what tests/+did2/+unittest/+helpers/runCorpusDiscovery.m
        `referenceIntegrityBlock` builds, JSON-encoded."""
        rows = {}
        for o in orphans:
            key = "%s.%s" % (o["doc_class"], o["edge_name"])
            rows[key] = rows.get(key, 0) + 1
        return {
            "audit": "did2.validate.references",
            "total_docs": 12,
            "edges_examined": edges,
            "orphan_count": len(orphans),
            "orphan_rows": [{"key": k, "count": n} for k, n in
                            sorted(rows.items(), key=lambda kv: -kv[1])],
            "orphans_shown": min(cap, len(orphans)),
            "orphan_sample_cap": cap,
            "orphans": list(orphans)[:cap],
        }

    def write_corpus(self, name, block=None):
        r = dict(self.BARE, corpus=name)
        if block is not None:
            r["reference_integrity"] = block
        self.write(name, r)

    def orphan(self, cls="stimulus_presentation", edge="element_id", i=0):
        return {"doc_id": "d%d" % i, "doc_class": cls, "edge_name": edge,
                "edge_document_id": "missing%d" % i}

    # --- 1. THE CLEAN CASE ------------------------------------------------
    def test_clean_run_renders_a_zero_WITH_the_denominator_that_earns_it(self):
        # The whole point of persisting `edges_examined` beside the count. A
        # clean run must not print the same thing as a run that swept nothing.
        self.write_corpus("Soph", self.harness_block(254304))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("254304", text)
        self.assertIn("NON-EMPTY depends_on edge(s) examined", text)
        self.assertIn("0  ORPHAN(S): edge names a document not in the batch",
                      text)
        self.assertNotIn("NOT MEASURED IN THIS REPORT", text)
        # the SPECIFIC phrase -- a bare "VACUOUS" also matches the unrelated
        # "VACUOUS REQUIRED FIELDS" heading further down the digest.
        self.assertNotIn("VACUOUS rather than clean", text)

    def test_a_clean_zero_and_a_swept_nothing_are_DIFFERENT_output(self):
        # The requirement in one test: both print `orphan_count: 0`, and the
        # reader must be able to tell them apart from the output alone.
        self.write_corpus("Real", self.harness_block(254304))
        clean, _ = self.run_digest()
        shutil.rmtree(self.dir, ignore_errors=True)
        os.mkdir(self.dir)
        self.write_corpus("Empty", self.harness_block(0))
        vacuous, _ = self.run_digest()
        self.assertNotIn("VACUOUS rather than clean", clean)
        self.assertIn("0 EDGES EXAMINED", vacuous)
        self.assertIn("VACUOUS rather than clean", vacuous)

    def test_the_rollup_flags_a_run_where_NO_corpus_examined_an_edge(self):
        # The per-corpus vacuity check existed; the rollup summed 0 + 0 and
        # printed a clean-looking total.
        self.write_corpus("A", self.harness_block(0))
        self.write_corpus("B", self.harness_block(0))
        text, _ = self.run_digest()
        self.assertIn("0 EDGES EXAMINED ACROSS EVERY MEASURED CORPUS", text)
        self.assertIn("'untested', not '0 orphans'", text)

    # --- 2. THE ORPHANS-FOUND CASE ---------------------------------------
    def test_orphans_found_are_counted_named_and_summed(self):
        self.write_corpus("JH", self.harness_block(
            900000, [self.orphan(i=0), self.orphan(i=1),
                     self.orphan("image_observation", "subject_id", 2)]))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("2  stimulus_presentation.element_id", text)
        self.assertIn("1  image_observation.subject_id", text)
        self.assertIn("3 orphan(s) across 2 row(s)", text)

    def test_row_counts_come_from_the_COMPLETE_aggregate_not_the_SAMPLE(self):
        # THE TRUNCATION TRAP. JH carries >900k edges, so the raw array is
        # capped; counting the sample while the complete table sits beside it
        # understates every row in exactly the run whose report you need.
        block = self.harness_block(
            900000, [self.orphan(i=i) for i in range(10)], cap=3)
        self.assertEqual(len(block["orphans"]), 3)      # the sample IS capped
        self.assertEqual(block["orphan_rows"][0]["count"], 10)
        self.write_corpus("JH", block)
        text, _ = self.run_digest()
        self.assertIn("10  stimulus_presentation.element_id", text)
        self.assertNotIn("3  stimulus_presentation.element_id", text)
        self.assertIn("10 orphan(s) across 1 row(s)", text)

    def test_the_cap_announces_itself(self):
        # v1_to_v2's rule, applied here: a silent truncation is how a report
        # starts lying.
        self.write_corpus("JH", self.harness_block(
            900000, [self.orphan(i=i) for i in range(10)], cap=3))
        text, _ = self.run_digest()
        self.assertIn("CAPPED SAMPLE: 3 of 10 shown (cap 3)", text)
        self.assertIn("NOT truncated", text)

    def test_an_uncapped_run_does_NOT_claim_a_truncation(self):
        self.write_corpus("Small", self.harness_block(
            50, [self.orphan(i=0)], cap=200))
        text, _ = self.run_digest()
        self.assertNotIn("CAPPED SAMPLE", text)

    def test_a_single_orphan_row_arrives_as_an_OBJECT_not_a_list(self):
        # jsonencode emits a 1-element struct array as a bare object. Every
        # list-shaped read goes through aslist -- including the new one.
        block = self.harness_block(50, [self.orphan(i=0)])
        block["orphan_rows"] = block["orphan_rows"][0]
        self.write_corpus("One", block)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("1  stimulus_presentation.element_id", text)

    # --- 3. THE NOT-MEASURED CASE -- AND PRED IS THE ONE THAT MATTERS -----
    def test_PRED_renders_UNMEASURED_and_is_never_summed_as_a_zero(self):
        # `testCorpusPRED.m` never calls did2.validate.references at any point
        # (0 matches), so persisting the count did NOT give PRED one. A corpus
        # we hard-gate on and never measure is a denominator missing from every
        # figure we quote -- and it must not read as a clean zero.
        for name in ("20211116", "B", "Dab", "JH", "Soph"):
            self.write_corpus(name, self.harness_block(1000))
        self.write_corpus("PRED", None)          # exactly what PRED writes
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("DENOMINATOR: 6 corpus report(s); 5 carried an orphan "
                      "count, 1 did not", text)
        self.assertIn("NOT MEASURED in: PRED", text)
        self.assertIn("sums over 5 corpora, not 6", text)
        self.assertIn("testCorpusPRED NEVER CALLS did2.validate.references",
                      text)
        # and the sums are over the five that measured, not six
        self.assertIn("= 5000", text)

    def test_the_addends_are_NAMED_and_the_counter_is_named_with_them(self):
        # The 562,422-vs-562,448 lesson: a total whose inputs are three screens
        # up gets re-derived by hand, and the hand picks up the adjacent line.
        # `edges_examined`, `total_docs` and `orphan_count` sit three lines
        # apart in this very block.
        self.write_corpus("B", self.harness_block(14181))
        self.write_corpus("Dab", self.harness_block(30354,
                                                    [self.orphan(i=0)]))
        text, _ = self.run_digest()
        self.assertIn("addends -- `edges_examined`, NOT `total_docs` and NOT "
                      "`orphan_count`:", text)
        self.assertIn("B 14181 + Dab 30354 = 44535", text)
        self.assertIn("addends -- `orphan_count`, the finding:", text)
        self.assertIn("B 0 + Dab 1 = 1", text)

    def test_a_FAILED_sweep_is_not_an_absent_one(self):
        # The block is persisted on the failure path too, naming the audit, so
        # "the instrument broke" and "this corpus never ran it" are different
        # output rather than one shared silence.
        self.write_corpus("Broke", {"audit": "did2.validate.references",
                                    "audit_failed": "Out of memory."})
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("NOT MEASURED IN THIS REPORT", text)
        self.assertIn("the reference-integrity sweep FAILED (Out of memory.)",
                      text)
        self.assertIn("THE SWEEP RAN AND THREW", text)
        self.assertIn("INSTRUMENT", text)

    def test_a_failed_sweep_does_not_claim_the_report_predates_the_wiring(self):
        # The three causes of an absence are different findings; the PER-CORPUS
        # failure branch must not print the other two. A measured sibling is
        # written alongside on purpose -- with ONLY a broken corpus the ROLLUP
        # correctly falls back to the generic note that lists all three causes,
        # and asserting against that would be asserting against correct output.
        self.write_corpus("Good", self.harness_block(1000))
        self.write_corpus("Broke", {"audit": "did2.validate.references",
                                    "audit_failed": "boom"})
        text, _ = self.run_digest()
        self.assertIn("THE SWEEP RAN AND THREW", text)
        self.assertNotIn("PREDATING the wiring", text)

    def test_a_failed_sweep_is_named_in_the_rollup_and_not_summed(self):
        self.write_corpus("Good", self.harness_block(1000))
        self.write_corpus("Broke", {"audit": "did2.validate.references",
                                    "audit_failed": "boom"})
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED in: Broke (the reference-integrity sweep "
                      "FAILED (boom))", text)
        self.assertIn("sums over 1 corpora, not 2", text)

    def test_an_orphan_and_an_empty_edge_are_never_conflated_here_either(self):
        # references.m:90 SKIPS an empty edge, so it cannot dangle and cannot
        # be counted here. Said in the measured branch, not only the absent one.
        self.write_corpus("Soph", self.harness_block(254304))
        text, _ = self.run_digest()
        self.assertIn("references.m:90", text)


class TestEpochStringRetention(DigestCase):
    """`epoch_string_retention` -- persisted at e9ef734, rendered nowhere.

    The block lands in the artifact JSON and in the per-corpus log and not in
    this digest, the write-only condition `epoch_mint` and
    `session_anchor_fold` were both in before their blocks landed here.
    """

    FULL = {
        "ran": True,
        "v1_documents_inspected": 10, "v1_documents_unreadable": 0,
        "migrated_documents_inspected": 12, "migrated_documents_unreadable": 0,
        "v1_documents_with_string": 4, "v1_strings_read": 5, "v1_pairs": 3,
        "v1_by_source": [{"source": "epochid.epochid", "documents": 4,
                          "distinct_strings": 3}],
        "v1_classes_inspected": 7, "v1_classes_with_string": 2,
        "v1_by_class": [
            {"class_name": "vmspikefit", "documents_with_string": 2,
             "distinct_pairs": 2, "pairs_dropped": 2},
            {"class_name": "epochfiles", "documents_with_string": 2,
             "distinct_pairs": 1, "pairs_dropped": 0}],
        "v1_declined": 3, "v1_declined_distinct": 1,
        "retained_as_string": 1, "retained_as_epoch_document": 0,
        "retained_total": 1, "pairs_dropped": 2,
        "dropped_by_v1_class": {"vmspikefit": 2},
        "dropped_detail": [{"session_id": "s1", "epoch_string": "t00023",
                            "v1_classes": ["vmspikefit"]}],
        "epoch_documents_seen": 0,
    }

    def report(self, name, esr=None, **extra):
        r = {"corpus": name, "total": 10, "migrated_count": 12,
             "quarantine_count": 0,
             "silent_loss": {"total_docs": 12, "skipped_docs": 0}}
        if esr is not None:
            r["epoch_string_retention"] = esr
        r.update(extra)
        return r

    def test_the_block_is_rendered_at_all(self):
        self.write("B", self.report("B", self.FULL))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("EPOCH-STRING RETENTION", text)
        self.assertIn("2  DROPPED  <-- the number this instrument exists for",
                      text)

    def test_an_absent_block_is_NAMED_not_rendered_as_zeros(self):
        self.write("B", self.report("B"))
        text, _failed = self.run_digest()
        self.assertIn("the instrument was not wired into the run that produced "
                      "it", text)
        self.assertIn("must\n      not print identically", text)

    def test_ran_false_is_not_a_clean_zero(self):
        self.write("B", self.report("B", dict(self.FULL, ran=False)))
        text, _failed = self.run_digest()
        self.assertIn("DID NOT RUN", text)
        self.assertIn("which is not a clean zero", text)

    def test_audit_failed_is_named(self):
        self.write("B", self.report("B", {"audit_failed": "index out of range"}))
        text, _failed = self.run_digest()
        self.assertIn("the retention audit FAILED (index out of range)", text)

    def test_the_two_class_counts_print_ON_ONE_LINE(self):
        # `pairs_dropped: 0` beside `v1_pairs: 0` is vacuous, and the
        # class-level version of that reading needs BOTH counts adjacent:
        # "no class carried a string" and "no class was inspected" are
        # different facts that read identically apart.
        self.write("B", self.report("B", self.FULL))
        text, _failed = self.run_digest()
        line = [l for l in text.splitlines() if "v1 classes:" in l]
        self.assertEqual(len(line), 1, text)
        self.assertIn("7 inspected", line[0])
        self.assertIn("2 of them carried an epoch string", line[0])

    def test_v1_pairs_is_labelled_THE_DENOMINATOR(self):
        self.write("B", self.report("B", self.FULL))
        text, _failed = self.run_digest()
        line = [l for l in text.splitlines() if "v1 strings:" in l]
        self.assertTrue(line, text)
        self.assertIn("3 distinct (session,string) pair(s)  <- THE DENOMINATOR",
                      line[0])

    def test_zero_pairs_prints_VACUOUS_not_clean(self):
        # `pairs_dropped: 0` with `v1_pairs: 0` is the reading this whole
        # block exists to keep apart from a clean corpus.
        empty = dict(self.FULL, v1_pairs=0, pairs_dropped=0, retained_total=0,
                     retained_as_string=0, v1_by_class=[],
                     dropped_by_v1_class={}, dropped_detail=[])
        self.write("B", self.report("B", empty))
        text, _failed = self.run_digest()
        self.assertIn("0 OF 0 PAIRS", text)
        self.assertIn("VACUOUS", text)

    def test_zero_classes_inspected_is_flagged_separately(self):
        none = dict(self.FULL, v1_classes_inspected=0, v1_classes_with_string=0)
        self.write("B", self.report("B", none))
        text, _failed = self.run_digest()
        self.assertIn("0 CLASSES INSPECTED", text)

    def test_declined_is_marked_EXCLUDED_from_the_denominator(self):
        self.write("B", self.report("B", self.FULL))
        text, _failed = self.run_digest()
        self.assertIn("EXCLUDED FROM THE DENOMINATOR", text)
        self.assertIn("3 hit(s), 1 distinct", text)

    def test_both_known_droppers_print_a_row_when_the_corpus_holds_neither(self):
        # vmspikefit and pyraview drop the string by construction. Their
        # ABSENCE from v1_by_class means "no such document here", NOT "the
        # drop is fixed", so both get a line either way.
        none = dict(self.FULL, v1_by_class=[], dropped_by_v1_class={},
                    dropped_detail=[])
        self.write("B", self.report("B", none))
        text, _failed = self.run_digest()
        for name in ("vmspikefit", "pyraview"):
            self.assertIn(name, text)
        self.assertIn("0 of 0 INSPECTED", text)
        self.assertIn("NOT a measured zero", text)

    def test_a_known_dropper_that_IS_present_prints_MEASURED(self):
        self.write("B", self.report("B", self.FULL))
        text, _failed = self.run_digest()
        self.assertIn("vmspikefit                     MEASURED: 2 dropped of "
                      "2 pair(s) carried", text)
        self.assertIn("pyraview                       0 of 0 INSPECTED", text)

    def test_dropped_by_v1_class_is_a_CROSSCHECK_not_a_second_table(self):
        # Two derivations of one fact, computed in two loops in the MATLAB.
        # A disagreement between them IS the signal; nothing else surfaces it.
        drifted = dict(self.FULL, dropped_by_v1_class={"vmspikefit": 2,
                                                       "pyraview": 1})
        self.write("B", self.report("B", drifted))
        text, _failed = self.run_digest()
        self.assertIn("THE TWO PER-CLASS DERIVATIONS DISAGREE", text)
        self.assertIn("names 2 class(es)", text)
        self.assertIn("table above shows 1", text)

    def test_agreeing_derivations_say_so_rather_than_stay_silent(self):
        self.write("B", self.report("B", self.FULL))
        text, _failed = self.run_digest()
        self.assertIn("both derivations agree", text)

    def test_a_single_row_v1_by_class_object_does_not_crash(self):
        # jsonencode writes a 1-element struct array as a bare object. The
        # defect that killed run #256, one block further down.
        one = dict(self.FULL,
                   v1_by_class={"class_name": "pyraview",
                                "documents_with_string": 1,
                                "distinct_pairs": 1, "pairs_dropped": 1},
                   dropped_by_v1_class={"pyraview": 1},
                   dropped_detail={"session_id": "s", "epoch_string": "e",
                                   "v1_classes": ["pyraview"]})
        self.write("B", self.report("B", one))
        text, failed = self.run_digest()
        self.assertEqual(failed, [], "a 1-row object must render, not fail")
        self.assertIn("pyraview", text)
        self.assertIn("1 dropped of      1 pair(s) carried", text)

    def test_the_rollup_sums_v1_pairs_and_pairs_dropped(self):
        self.write("A", self.report("A", self.FULL))
        self.write("B", self.report("B", dict(self.FULL, v1_pairs=5,
                                              pairs_dropped=1)))
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        tail = text[text.index("EPOCH-STRING RETENTION -- did a did_v1"):]
        self.assertIn("8 (session,string) pair(s)  <- THE DENOMINATOR", tail)
        self.assertIn("3  DROPPED", tail)

    def test_the_rollup_UNITES_v1_by_class_and_never_sums_distinct_counts(self):
        # THE MISTAKE THIS GUARDS IS LIVE IN THIS DIGEST: `relaxed_classes`
        # sums to 7 across the rollup while the true union is 3, and the
        # NDI-required block prints a *** warning about it. A class in two
        # corpora is ONE row here, and its distinct-pair counts stay per
        # corpus rather than being added into a 4 that means nothing.
        self.write("A", self.report("A", self.FULL))
        self.write("B", self.report("B", self.FULL))
        text, _failed = self.run_digest()
        tail = text[text.index("EPOCH-STRING RETENTION -- did a did_v1"):]
        self.assertIn("2 distinct class(es) carried an epoch string in the "
                      "union, over 2 readable report(s)", tail)
        self.assertIn("seen in: A, B", tail)
        self.assertIn("dropped/carried: A 2/2, B 2/2", tail)
        self.assertNotIn("4 pair(s)", tail)

    def test_the_rollup_names_unmeasured_corpora_and_does_not_zero_them(self):
        self.write("Has", self.report("Has", self.FULL))
        self.write("Lacks", self.report("Lacks"))
        text, _failed = self.run_digest()
        tail = text[text.index("EPOCH-STRING RETENTION -- did a did_v1"):]
        self.assertIn("2 corpus report(s); 1 carried a readable retention "
                      "block, 1 did not", tail)
        self.assertIn("NOT MEASURED in: Lacks", tail)
        self.assertIn("sums over 1 corpora, not 2", tail)

    def test_the_rollup_says_ABSENT_when_nothing_carries_the_block(self):
        self.write("A", self.report("A"))
        self.write("B", self.report("B"))
        text, _failed = self.run_digest()
        self.assertIn("NO REPORT IN THIS RUN CARRIED A RETENTION BLOCK", text)
        self.assertIn("the subtraction was never performed", text)

    def test_the_rollup_prints_both_known_droppers_when_no_corpus_holds_one(self):
        none = dict(self.FULL, v1_by_class=[], dropped_by_v1_class={},
                    dropped_detail=[])
        self.write("A", self.report("A", none))
        self.write("B", self.report("B", none))
        text, _failed = self.run_digest()
        tail = text[text.index("EPOCH-STRING RETENTION -- did a did_v1"):]
        self.assertIn("vmspikefit", tail)
        self.assertIn("pyraview", tail)
        self.assertIn("0 of 0 INSPECTED", tail)

    def test_the_rollup_reports_a_per_class_derivation_disagreement(self):
        drifted = dict(self.FULL,
                       dropped_by_v1_class={"vmspikefit": 2, "pyraview": 1})
        self.write("A", self.report("A", drifted))
        text, _failed = self.run_digest()
        tail = text[text.index("EPOCH-STRING RETENTION -- did a did_v1"):]
        self.assertIn("PER-CLASS DERIVATIONS DISAGREE in: A", tail)



class TestTheGraphWithoutEditorBannerClaimsNothingItCannotSee(unittest.TestCase):
    """The banner concluded what MIGRATES. A counter may not do that.

    It printed "those facts migrate NOWHERE for this dataset" on the strength
    of two claims that were both false at the moment it ran -- that the bare
    `openminds` class had no migrator, and that `metadata_editor.m` was the only
    source of the dataset tier. `+migrators_j/openminds.m` and
    `dataset_remote.m` refute them, and `resolveOpenmindsCitations` -- whose own
    counters print eight lines below this banner -- was an ancestor of the run.

    This is the house error inverted: it alarms rather than reassures, which is
    not a lesser fault. It cost a build cycle and put "live data loss" at the
    top of a decision list.
    """

    def _banner(self):
        src = open(DIGEST_PATH, encoding="utf-8").read()
        m = re.search(r'if m\["verdict"\] == "GRAPH WITHOUT EDITOR":(.*?)\n\n',
                      src, re.DOTALL)
        self.assertTrue(m, "the GRAPH WITHOUT EDITOR branch is gone or renamed")
        return "\n".join(
            ln for ln in m.group(1).splitlines() if "p(" in ln)

    def test_it_does_not_claim_anything_migrates_nowhere(self):
        banner = self._banner()
        print("DENOMINATOR: 1 branch inspected, %d printed line(s)"
              % len(banner.splitlines()))
        # THE TWO FALSE ASSERTIONS, by their distinctive words -- not every
        # word that resembles them. A first draft forbade "migrate" and "no
        # migrator" outright and failed on the corrected banner, whose job is
        # to DENY those very claims ("It does NOT mean the tier has no
        # migrator"). A guard that cannot tell an assertion from its negation
        # fails on the fix and gets relaxed to shut it up.
        for phrase in ("NOWHERE", "only source"):
            self.assertNotIn(
                phrase, banner,
                "the banner asserts %r again. It counts documents; it cannot "
                "see which migrators exist, and it was wrong about exactly "
                "that. Point the reader at the openminds_citations block "
                "instead of concluding." % phrase)
        self.assertIn("does NOT", banner,
                      "the banner no longer says what its absence does NOT "
                      "mean, which is the only reason it is safe to print.")

    def test_it_tells_the_reader_where_the_real_answer_is(self):
        banner = self._banner()
        self.assertIn("openminds_citations", banner,
                      "the banner reports an absence without pointing at the "
                      "pass whose counters answer it. A reader then infers.")
        self.assertIn("more than one writer", banner,
                      "the banner must say that `openminds` documents are not "
                      "by themselves a citation graph -- +haley/doImport.m "
                      "emits strain assemblies under the same class name, "
                      "which is what JH's 8 documents actually are.")


# ==========================================================================
# THE PASS CENSUS AS A GATE (armed 2026-08-11)
# ==========================================================================
#
# Until this commit the census DETECTED every condition below, printed it with
# a *** banner in three separate places, and exited 0. So the tests that
# existed asserted the WORDING of a warning, and a warning nobody has to act on
# is the state `resolveDeferredBaths` and `resolveDatasetEntities` sat in for
# months while mutating every corpus.
#
# THESE DRIVE THE DERIVATION, THEY DO NOT MOCK IT. Each writes MATLAB into a
# throwaway tree, derives the chain from that text with the real
# `harness_pass_chain`, and installs the result in the chain cache so that
# `main()` -- the real entry point, with the real exit code -- reads it. A test
# that handed `digest()` a dict would assert that the gate fails on whatever it
# is given, which is the one thing never in doubt.
#
# THE SYNTHETIC TREE IS BUILT FROM `POST_PASSES` ITSELF, on purpose. A tree of
# invented names would make every render-table entry `not_in_chain`, so the
# stale sentinel would fire in every case here and no case could isolate the
# condition it is named for. Building the baseline FROM the table means the
# baseline is clean by construction and each test perturbs exactly one thing.
#
# RUN AGAINST THE PRE-CHANGE DIGEST, each of these fails: `main()` returned 0
# for all four conditions. A test written from the same premise as the code
# cannot catch the code.


class PassCensusGateCase(PassCensusTree):
    """A synthetic +convert package and call sites, plus a real exit code."""

    def setUp(self):
        PassCensusTree.setUp(self)
        self.reports = tempfile.mkdtemp()
        self._saved = census_digest._CHAIN_CACHE.pop(
            census_digest.REPO_ROOT, None)

    def tearDown(self):
        # The cache is module state shared with every other test in this file.
        census_digest._CHAIN_CACHE.pop(census_digest.REPO_ROOT, None)
        if self._saved is not None:
            census_digest._CHAIN_CACHE[census_digest.REPO_ROOT] = self._saved
        shutil.rmtree(self.reports, ignore_errors=True)
        PassCensusTree.tearDown(self)

    def write_report(self, name="Fix"):
        """One minimal, VALID corpus report.

        Present so that a non-zero exit in these tests can only have come from
        the pass gate: with no reports at all the digest already fails on
        MISSING_REPORTS, and an exit code that would be 1 anyway proves nothing
        about the gate.
        """
        with open(os.path.join(self.reports, name + "-summary.json"), "w") as fh:
            json.dump({"corpus": name, "total": 1, "migrated_count": 1,
                       "quarantine_count": 0}, fh)

    def real_passes(self):
        """(function, report field) for every pass this digest renders."""
        return [(fn.split(".")[-1], field)
                for field, fn, _rows in census_digest.POST_PASSES]

    def build(self, guarded=(), bare=(), omit=()):
        """Write the package + both call sites, then derive and install."""
        lines = []
        for fn, field in guarded:
            if fn in omit:
                continue
            self.pass_file(fn)
            lines.append(
                "result = did2.unittest.helpers.runBatchPass(result, ...\n"
                "    'did2.convert.%s', '%s', ...\n"
                "    @(r) did2.convert.%s(r));\n" % (fn, field, fn))
        for fn in bare:
            self.pass_file(fn)
            lines.append("result = did2.convert.%s(result);\n" % fn)
        self.call_site("".join(lines))
        chain = self.chain()
        census_digest._CHAIN_CACHE[census_digest.REPO_ROOT] = chain
        return chain

    def run_main(self):
        """The real entry point. Returns (exit code, stdout)."""
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = census_digest.main(["census_digest.py", self.reports])
        return code, buf.getvalue()


class TestPassCensusGateIsArmed(PassCensusGateCase):
    def test_the_clean_chain_still_exits_0(self):
        # THE PRECONDITION, ASSERTED RATHER THAN ASSUMED. Arming a gate onto a
        # condition that is already non-zero turns CI red for something nobody
        # has triaged; this is the shape that was measured at 0 before the gate
        # was armed, and it must keep exiting 0.
        self.write_report()
        self.build(guarded=self.real_passes())
        code, text = self.run_main()
        self.assertEqual(code, 0, "a fully wired chain must not go red:\n" + text)
        self.assertIn("GATE PASSED", text)
        self.assertIn("0 UNMEASURED", text)

    def test_a_pass_measured_by_nothing_turns_the_job_red(self):
        # THE GATE. Before this commit the same tree printed "RAN, MEASURED BY
        # NOTHING" in three places and returned 0.
        self.write_report()
        self.build(guarded=self.real_passes(),
                   bare=["aTenthPassNobodyPairedWithAReport"])
        code, text = self.run_main()
        self.assertEqual(code, 1,
                         "a pass that runs and is measured by nothing must be "
                         "a non-zero exit, not a banner:\n" + text)
        self.assertIn(census_digest.UNMEASURED_PASSES, text)
        self.assertIn("aTenthPassNobodyPairedWithAReport", text)
        self.assertIn("GATE FAILED", text)
        # SEPARATE SENTINELS, NOT ONE BUCKET: this defect must not report as
        # the other two, whose triage and whose fix are different.
        self.assertNotIn(census_digest.UNRENDERED_PASSES, text)
        self.assertNotIn(census_digest.STALE_PASS_TABLE, text)

    def test_an_unrendered_report_is_a_different_sentinel(self):
        # A pass that DOES attach a report which this file has no rows for.
        # Lower severity -- the numbers are in the artifact -- so it is armed
        # separately and must never print as `unmeasured`.
        self.write_report()
        self.build(guarded=self.real_passes()
                   + [("aTenthPassWithNoRenderRows", "tenth_fold")])
        code, text = self.run_main()
        self.assertEqual(code, 1, text)
        self.assertIn(census_digest.UNRENDERED_PASSES, text)
        self.assertIn("aTenthPassWithNoRenderRows -> result.tenth_fold", text)
        self.assertNotIn(census_digest.UNMEASURED_PASSES, text)

    def test_a_table_entry_no_call_site_composes_is_a_different_sentinel(self):
        # The reassuring direction: counters printed for a pass that does not
        # run read as coverage of it.
        self.write_report()
        dropped = self.real_passes()[0][0]
        self.build(guarded=self.real_passes(), omit=[dropped])
        code, text = self.run_main()
        self.assertEqual(code, 1, text)
        self.assertIn(census_digest.STALE_PASS_TABLE, text)
        self.assertIn(dropped, text)
        self.assertNotIn(census_digest.UNMEASURED_PASSES, text)

    def test_the_floor_path_reports_not_evaluated_rather_than_clean(self):
        # THE FALLBACK. When the sources cannot be read, every render-table row
        # is `renderable` BY CONSTRUCTION, so the three content gates would read
        # 0 -- a property of the table, not a fact about the harness. Firing
        # them there would assert a conclusion the data cannot support; calling
        # them clean would be silentLoss. Neither: NOT EVALUATED, and the
        # derivation itself is the failure.
        self.write_report()
        census_digest._CHAIN_CACHE[census_digest.REPO_ROOT] = (
            census_digest.harness_pass_chain(
                os.path.join(self.root, "nowhere"), _cache=False))
        code, text = self.run_main()
        self.assertEqual(code, 1,
                         "a gate that could not be evaluated has not agreed "
                         "with anything:\n" + text)
        self.assertIn(census_digest.PASS_SET_NOT_DERIVED, text)
        self.assertIn("NOT EVALUATED", text)
        self.assertNotIn(census_digest.UNMEASURED_PASSES, text)
        self.assertNotIn(census_digest.UNRENDERED_PASSES, text)
        self.assertNotIn(census_digest.STALE_PASS_TABLE, text)

    def test_one_defect_counts_once_however_many_corpora_were_read(self):
        # ONE GATE, EVALUATED ONCE. The same condition is RENDERED at three
        # sites (the leading census, each corpus block, the rollup); failing at
        # each would make the number of findings a property of how many reports
        # were downloaded.
        for name in ("A", "B", "C"):
            self.write_report(name)
        self.build(guarded=self.real_passes(), bare=["aTenthPass"])
        lines, failed = census_digest.digest(self.reports)
        self.assertEqual(
            failed.count(census_digest.UNMEASURED_PASSES), 1,
            "one unmeasured pass over three corpora must be ONE finding, not "
            "one per report:\n" + "\n".join(lines))

    def test_a_gate_finding_survives_a_run_that_found_no_reports(self):
        # The no-reports return used to DISCARD everything already in `failed`,
        # so the gate was disarmed by precisely the input condition that
        # guarantees nobody reads the rest of the output. Both facts are true
        # at once and both must be reported.
        self.build(guarded=self.real_passes(), bare=["aTenthPass"])
        _lines, failed = census_digest.digest(
            os.path.join(self.reports, "absent"))
        self.assertIn(census_digest.MISSING_REPORTS, failed)
        self.assertIn(census_digest.UNMEASURED_PASSES, failed)


class TestEdgeArity(DigestCase):
    """The UNGATED edge-arity census -- rendering side.

    WHY THIS BLOCK EXISTS AT ALL. "How many existing documents carry a plural
    `document_id` edge" had no answer anywhere and was being written down as
    UNMEASURED. Three counters could have answered it:

      NDI `imagedEntitySubjects.blocked_plural_document_id`  -- NDI-side, and
          the DID corpus harness never invokes that pass.
      NDI `ontologyRowSubjects`                              -- no arity
          counter; `resolved_via_document_id_edge` counts RESOLUTIONS.
      `silentLoss.uniqueness_denominator.docs_multi_member`  -- GATED on
          `referent_unique_by`, which DID-schema declares on three families,
          all of them `time_reference_#`.

    So every test here is about a DISTINCTION, the same as the NDI-required
    ones: measured zero vs never measured, a zero because nothing was plural vs
    a zero because nothing was looked at, and -- the one that decides whether
    the block is worth having -- the singular denominator printing on the same
    line as the plural count.

    THE FIXTURE NUMBERS COME FROM WHAT NDI'S WRITER PRODUCES, not from the
    counter's shape. `tableDocMaker.m:289` writes a BARE `document_id` when a
    row names one referent and `:291` writes `document_id_1..n` when it names
    several, so a real corpus is overwhelmingly arity 1 with a small plural
    tail -- which is exactly the shape that makes a plural-only census look
    like a big finding and a fold-everything census look like a small one.
    """

    def _ea(self, **over):
        # 76,766 ontology_table_row documents is the figure recorded for
        # `ontology_table_row`'s empty `subject_id` census; the arity split
        # below is illustrative, the SHAPE is not.
        ea = {
            "docs_inspected": 80000, "docs_unreadable": 0,
            "docs_unclassifiable": 0, "docs_classified": 80000,
            "docs_errored": 0,
            "docs_with_depends_on": 76766,
            "docs_with_indexed_edge": 24,
            "docs_with_plural_family": 24,
            "edges_examined": 76802, "edges_unnamed": 0,
            "indexed_edges_examined": 60,
            "pairs_examined": 76766, "pairs_plural": 24,
            "families_seen": 3, "plural_families_seen": 1,
            "max_arity_seen": 4,
            "arity_distribution": [
                {"class_name": "ontology_table_row", "edge_name": "document_id",
                 "arity": "1", "count": 76742},
                {"class_name": "ontology_table_row", "edge_name": "document_id",
                 "arity": "2", "count": 20},
                {"class_name": "ontology_table_row", "edge_name": "document_id",
                 "arity": "3+", "count": 4},
            ],
            "plural_by_family": [
                {"class_name": "ontology_table_row", "edge_name": "document_id",
                 "max_arity": 4, "count": 24},
            ],
        }
        ea.update(over)
        return ea

    def _corpus(self, name="A", ea=None, headline=24, **over):
        sl = {"total_docs": 80000, "skipped_docs": 0,
              "empty_dependency_count": 0, "vacuous_field_count": 0}
        if ea is not None:
            sl["edge_arity"] = ea
            sl["edge_arity_plural_count"] = headline
        body = {"corpus": name, "total": 8000, "migrated_count": 80000,
                "quarantine_count": 0, "silent_loss": sl}
        body.update(over)
        self.write(name, body)

    # --- denominator first, unconditionally --------------------------------

    def test_the_denominator_precedes_the_count(self):
        # Rule 5, and this counter is the one whose zero would close an open
        # question, so it is the one that must never print without its
        # denominator above it.
        self._corpus("A", self._ea())
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        den = text.index("DENOMINATOR: 80000 document(s) inspected, 0 unreadable")
        cnt = text.index("PLURAL (>1 member)  <-- the count")
        self.assertLess(den, cnt)

    def test_every_denominator_row_is_rendered(self):
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        for label in ("documents with no document_class (NOT looked at)",
                      "documents carrying at least one edge",
                      "carrying an INDEXED `_<n>` edge",
                      "carrying a PLURAL family",
                      "depends_on entries examined",
                      "with no usable name (dropped, and COUNTED)",
                      "(document, family) pairs examined",
                      "PLURAL (>1 member)  <-- the count",
                      "distinct (class, family) pairs seen",
                      "largest arity seen anywhere"):
            self.assertIn(label, text)

    def test_the_error_counter_is_rendered_and_marked_as_overlapping(self):
        # It is NOT a partition state. A reader who added it to the three would
        # get a figure larger than the denominator, which reads as more
        # coverage than there is -- this project's characteristic error.
        self._corpus("A", self._ea(docs_errored=3))
        text, _ = self.run_digest()
        self.assertIn("3    (overlaps: threw part-way, NOT a partition state)",
                      text)

    def test_a_counter_the_report_lacks_is_not_printed_as_zero(self):
        ea = self._ea()
        del ea["edges_unnamed"]
        self._corpus("A", ea)
        text, _ = self.run_digest()
        self.assertIn("(absent)    with no usable name", text)

    # --- the not-measured conditions, each distinct from a zero -------------

    def test_a_report_without_the_block_is_NOT_MEASURED(self):
        # A report predating the counter must not contribute a reassuring zero
        # to the very question the counter was built to answer.
        self._corpus("A", None)
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- this report carries no edge_arity block",
                      text)
        self.assertNotIn("MEASURED ZERO", text)

    def test_an_inspected_zero_is_NOT_MEASURED(self):
        self._corpus("A", self._ea(docs_inspected=0))
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- it inspected 0 document(s)", text)

    def test_an_all_unreadable_batch_is_NOT_MEASURED(self):
        self._corpus("A", self._ea(docs_unreadable=80000))
        text, _ = self.run_digest()
        self.assertIn("NOT MEASURED -- all 80000 document(s) handed to it were "
                      "unreadable", text)

    def test_a_malformed_block_is_NOT_MEASURED(self):
        self._corpus("A", ea=None)
        # rewrite with a non-object edge_arity
        self.write("A", {"corpus": "A", "total": 1, "migrated_count": 1,
                         "quarantine_count": 0,
                         "silent_loss": {"total_docs": 1, "skipped_docs": 0,
                                         "edge_arity": 7}})
        text, _ = self.run_digest()
        self.assertIn("the edge_arity block is malformed (int)", text)

    # --- the thing the block is FOR ----------------------------------------

    def test_the_singular_denominator_prints_beside_the_plural_count(self):
        # THE POINT OF THE PIVOT. "24 documents carry more than one
        # `document_id`" is a different fact depending on whether the family
        # occurs 30 times or 76,766 times, and the two numbers arriving three
        # screens apart is how the second stops being read.
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        line = [l for l in text.split("\n")
                if "ontology_table_row.document_id" in l and "1: " in l]
        self.assertTrue(line, "the arity distribution did not render a row")
        self.assertIn("1: 76742", line[0])
        self.assertIn("2: 20", line[0])
        self.assertIn("3+: 4", line[0])

    def test_the_plural_family_row_carries_its_largest_arity(self):
        # A plural family with max arity 2 and one with max arity 40 are
        # different problems, and the row count alone cannot tell them apart.
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("ontology_table_row.document_id   (largest arity seen: 4)",
                      text)

    def test_a_single_row_object_does_not_crash(self):
        # jsonencode writes a 1-element MATLAB struct array as a bare OBJECT,
        # not a list. That exact shape killed run #256 after 2h49m in a
        # different block; every reader here goes through aslist for it.
        ea = self._ea(
            arity_distribution={"class_name": "ontology_table_row",
                                "edge_name": "document_id",
                                "arity": "2", "count": 20},
            plural_by_family={"class_name": "ontology_table_row",
                              "edge_name": "document_id",
                              "max_arity": 2, "count": 20})
        self._corpus("A", ea)
        text, failed = self.run_digest()
        self.assertEqual(failed, [], "a single-row object must render")
        self.assertIn("2: 20", text)

    # --- WHICH zero is it --------------------------------------------------

    def test_a_plural_zero_over_real_pairs_is_a_MEASURED_zero(self):
        # The only zero in this block that is a RESULT, and it has to say so:
        # every other annotated zero in this digest means the opposite, and a
        # reader who has learnt to distrust them would distrust this one too.
        ea = self._ea(pairs_plural=0, docs_with_plural_family=0,
                      plural_families_seen=0, max_arity_seen=1,
                      docs_with_indexed_edge=0, indexed_edges_examined=0,
                      arity_distribution=[
                          {"class_name": "ontology_table_row",
                           "edge_name": "document_id",
                           "arity": "1", "count": 76766}],
                      plural_by_family=[])
        self._corpus("A", ea, headline=0)
        text, _ = self.run_digest()
        self.assertIn("MEASURED ZERO: 76766 (document, family) pair(s) were "
                      "examined", text)
        self.assertIn("This is a RESULT", text)
        self.assertIn("sample of datasets, not the universe", text)

    def test_a_zero_with_nothing_in_reach_is_untested_not_clean(self):
        ea = self._ea(docs_with_depends_on=0, docs_with_indexed_edge=0,
                      docs_with_plural_family=0, edges_examined=0,
                      indexed_edges_examined=0, pairs_examined=0,
                      pairs_plural=0, families_seen=0,
                      plural_families_seen=0, max_arity_seen=0,
                      arity_distribution=[], plural_by_family=[])
        self._corpus("A", ea, headline=0)
        text, _ = self.run_digest()
        self.assertIn("NO DOCUMENT IN REACH CARRIES AN EDGE AT ALL", text)
        self.assertIn("'untested', not 'clean'", text)
        self.assertNotIn("MEASURED ZERO", text)

    def test_the_absent_indexed_spelling_is_reported_as_corroboration(self):
        # NDI's writer uses `_<n>` ONLY for the plural case, so "no indexed edge
        # anywhere" is an INDEPENDENT way of seeing "no plural edge anywhere".
        # Printing it is what makes the plural zero checkable rather than taken.
        ea = self._ea(docs_with_indexed_edge=0, indexed_edges_examined=0,
                      pairs_plural=0, docs_with_plural_family=0,
                      plural_families_seen=0, plural_by_family=[])
        self._corpus("A", ea, headline=0)
        text, _ = self.run_digest()
        self.assertIn("NOT ONE `_<n>` EDGE APPEARED", text)
        self.assertIn("tableDocMaker.m:289", text)

    def test_an_unknown_bucket_is_named_not_dropped(self):
        # A bucket the digest has no column for takes documents with it, and a
        # silently short table reads as a smaller finding. The counter names
        # its buckets in one place (silentLoss/arityBucket) precisely so this
        # cannot happen; if it does, the reader is told before the table.
        ea = self._ea(arity_distribution=[
            {"class_name": "ontology_table_row", "edge_name": "document_id",
             "arity": "1", "count": 76742},
            {"class_name": "ontology_table_row", "edge_name": "document_id",
             "arity": "many", "count": 24}])
        self._corpus("A", ea)
        text, _ = self.run_digest()
        self.assertIn("BUCKET 'many' IS NOT ONE THIS DIGEST RENDERS", text)
        self.assertIn("24 document(s) in", text)

    def test_a_drift_between_the_headline_and_the_denominator_is_reported(self):
        # They are incremented on the same branch of the same loop. This file
        # has already shipped an accumulator that was counted and never
        # assigned, reporting 0 on a document the detector had just flagged.
        self._corpus("A", self._ea(), headline=99)
        text, _ = self.run_digest()
        self.assertIn("`edge_arity_plural_count` is 99 and `pairs_plural` is 24",
                      text)
        self.assertIn("cannot", text)

    def test_it_says_a_plural_edge_is_not_by_itself_a_violation(self):
        # `derived_from` and `syncrule_id` are MEANT to be plural. A block that
        # printed a count with no such note would be read as a defect count,
        # and the first response would be to "fix" families that are correct.
        self._corpus("A", self._ea())
        text, _ = self.run_digest()
        self.assertIn("DO NOT read this as a violation count", text)

    # --- the rollup ---------------------------------------------------------

    def test_the_rollup_names_the_corpora_it_could_not_measure(self):
        self._corpus("A", self._ea())
        self._corpus("B", None)
        text, failed = self.run_digest()
        self.assertEqual(failed, [])
        self.assertIn("NOT MEASURED in: B", text)
        self.assertIn("sums over 1 corpora, not 2", text)

    def test_the_rollup_sums_the_counters_and_names_its_denominator(self):
        self._corpus("A", self._ea())
        self._corpus("B", self._ea())
        text, _ = self.run_digest()
        self.assertIn("DENOMINATOR: 2 corpus report(s); 2 carried a readable "
                      "block, 0 did not; 160000 document(s) inspected in total",
                      text)
        # 24 + 24 pairs, and the distribution rows add too.
        self.assertIn("48    PLURAL (>1 member)  <-- the count", text)
        self.assertIn("1: 153484", text)

    def test_the_rollup_takes_a_MAXIMUM_of_max_arity_never_a_sum(self):
        # Adding maxima reports an arity no document has. This is the one field
        # in the block that must not be summed, and the label says so.
        self._corpus("A", self._ea(max_arity_seen=4))
        self._corpus("B", self._ea(max_arity_seen=7))
        text, _ = self.run_digest()
        self.assertIn("7  largest arity in ANY corpus (a MAXIMUM, never summed)",
                      text)
        self.assertNotIn("11  largest arity", text)

    def test_the_rollup_with_no_readable_block_says_UNMEASURED(self):
        self._corpus("A", None)
        self._corpus("B", None)
        text, _ = self.run_digest()
        self.assertIn("NOTHING TO TOTAL", text)
        self.assertIn("It is NOT '0 plural edges'", text)

    def test_the_rollup_merges_plural_rows_and_maxes_their_arity(self):
        self._corpus("A", self._ea())
        self._corpus("B", self._ea(
            max_arity_seen=9,
            plural_by_family=[{"class_name": "ontology_table_row",
                               "edge_name": "document_id",
                               "max_arity": 9, "count": 5}]))
        text, _ = self.run_digest()
        self.assertIn("29  ontology_table_row.document_id", text)
        self.assertIn("(largest arity: 9)", text)

    # --- the reader, tested directly ---------------------------------------

    def test_the_reader_reports_why_rather_than_returning_a_zero(self):
        self.assertFalse(edge_arity({})["measured"])
        self.assertIn("no edge_arity block", edge_arity({})["why"])
        self.assertFalse(
            edge_arity({"silent_loss": {"audit_failed": "boom"}})["measured"])

    def test_the_pivot_folds_the_buckets_and_names_the_strays(self):
        table, unknown = edge_arity_pivot([
            {"class_name": "c", "edge_name": "e", "arity": "1", "count": 10},
            {"class_name": "c", "edge_name": "e", "arity": "3+", "count": 2},
            {"class_name": "c", "edge_name": "e", "arity": "9", "count": 1}])
        self.assertEqual(table["c.e"]["1"], 10)
        self.assertEqual(table["c.e"]["3+"], 2)
        self.assertEqual(table["c.e"]["2"], 0)
        # The stray is NOT folded into a column and NOT dropped: it is named,
        # and its documents stay visible in `total`.
        self.assertEqual(unknown, {"9": 1})
        self.assertEqual(table["c.e"]["total"], 13)


if __name__ == "__main__":
    unittest.main(verbosity=2)
