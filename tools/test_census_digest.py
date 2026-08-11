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
from census_digest import (aslist, digest, epoch_association,  # noqa: E402
                           ndi_required, norm_class, normalised_class_index,
                           render_report, rollup)


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
        # The EXPECTED count is read from POST_PASSES, not written here as a
        # literal. It was `2` and went stale the moment a third pass was added
        # (generic_file_fold, 2026-08-11) -- a test asserting the denominator's
        # VALUE rather than its SOURCE fails on every legitimate addition, which
        # trains people to edit the number instead of reading the line. What
        # this test is actually for is that an absent pass PRINTS, and that is
        # asserted below.
        import census_digest
        n = len(census_digest.POST_PASSES)
        self.assertGreaterEqual(n, 3)
        self.assertIn("batch post-passes: %d expected, 0 present" % n, text)
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
        """
        start = text.index("EPOCH ASSOCIATION (#72): does a statement")
        end = text.index("METADATA TIER:", start)
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
        self.assertIn("2019 vintage: 2 experiment_unique_reference", text)
        self.assertIn("2  projectvar (moved wholesale)", text)

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
