#!/usr/bin/env python3
"""Render the corpus census from the per-corpus *-summary.json reports.

WHY THIS IS A FILE AND NOT A YAML HEREDOC
-----------------------------------------
This digest shipped broken twice, and both times the reason was that it lived
inside a `run:` block in test-code.yml where nothing could execute it except a
full ~3-hour corpus run:

  1. It printed "0 empty required edges, 0 vacuous required fields" without
     printing `total_docs`, so a census that inspected NOTHING was
     indistinguishable from one that found nothing wrong -- the very bug
     `silentLoss` itself had shipped with.

  2. It did `dict[:10]`. MATLAB's `jsonencode` writes a ONE-ELEMENT struct array
     as a bare object rather than a one-element array, so a report with exactly
     one offending row arrives as a dict. That killed run #256 mid-corpus and
     cost the two largest corpora their output.

Neither defect was reachable by any test while the code lived in YAML. As a
module it is importable, and tests/test_census_digest.py exercises both shapes
in under a second.

Usage:
    python3 tools/census_digest.py <reports-dir> [<reports-dir> ...]

Exits non-zero if any report could not be rendered -- but only AFTER every
readable report has printed. A digest that cannot read its input must say so;
it must not also destroy the data it could read.
"""

import json
import os
import re
import sys
import textwrap
import traceback

# Sentinel placed in the `failed` list when the digest found no reports at all.
# ZERO REPORTS IS A FAILURE OF THE INSTRUMENT, NOT A CLEAN RUN. It used to
# return `(lines, [])` -- so run #3's census job printed "NO CORPUS REPORTS
# FOUND" and went GREEN, and six corpora that had run for over an hour
# reported nothing at all. A digest with no input has not agreed with the
# corpora; it has not read them.
MISSING_REPORTS = "<no *-summary.json found>"

# The digest's second non-zero exit, and the only one that is a claim about the
# MIGRATION rather than about the digest's own input. See epoch_populations()
# for what makes the figures it compares commensurable; the short version is
# that every figure in the set counts `epoch` documents in the batch AFTER
# did2.convert.epochMint has run, so they cannot legitimately differ. If they
# do, epochs were minted and then lost, and that is worth a red job.
EPOCH_POPULATIONS_DISAGREE = "<epoch document populations disagree>"


def aslist(v):
    """Normalise MATLAB's array-or-object encoding to a list.

    `jsonencode` emits a 1-element struct array as a bare object and a 2+
    element one as an array, so any list-shaped field can arrive either way.
    Every list-shaped read goes through here -- not just the field that
    happened to break once.
    """
    if v is None:
        return []
    if isinstance(v, dict):
        return [v]
    if isinstance(v, list):
        return v
    return [v]


# The batch post-passes a V_eta corpus run is expected to have executed, in the
# order the harness runs them. This list IS the denominator for the post-pass
# block: every entry prints a line whether or not the report carries it, so
# "the pass ran and changed nothing" and "the pass was never wired into the run
# that produced this report" are different output rather than the same silence.
#
# THAT DISTINCTION IS WHY THIS BLOCK EXISTS. `did2.convert.resolveSessionAnchors`
# was built and left uncalled, and no corpus artifact said so, because a pass
# that is not called writes nothing anywhere. `epoch_mint` was the sibling case:
# it WAS wired and WAS persisted into every report from the day it landed -- and
# this digest did not render it, so the number reached the artifact and stopped
# there. A measurement nobody can see without downloading a zip is the
# write-only condition this whole file exists to remove.
#
# (field-in-report, MATLAB function, [(report key, label), ...] to print)
POST_PASSES = [
    # TEAM DECISION 2026-08-11 ("Do B"): assemble the openMINDS dataset CITATION
    # graph into the entity tier, rather than accept the loss or require a
    # metadata_editor document.
    #
    # READ `openminds_documents_seen` FIRST. It is the denominator and it is
    # ROUTINELY 0: the pass's own header records corpus run 31441923369 as 1
    # graph-without-editor, 1 editor-without-graph and 4 NEITHER, so four of six
    # corpora can produce an entirely zero block that says nothing whatever
    # about whether the assembly works. The METADATA TIER section above counts
    # the same class from the v1 SOURCE census and is the place to look when
    # this is 0.
    #
    # TWO SUMS HOLD BY CONSTRUCTION and are the cheapest defect check here:
    #     components_seen  == planned + without_dataset_version
    #     components_planned == consumed + withheld + reverted_on_validation
    # Every component takes exactly one of those exits (resolveOpenmindsCitations
    # .m:380-455), so a violation is a counter that stopped being incremented,
    # not a corpus fact.
    ("openminds_citations", "did2.convert.resolveOpenmindsCitations", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("openminds_documents_seen", "`openminds` documents  <- THE DENOMINATOR"),
        ("openminds_components_seen", "connected components of them"),
        ("dataset_versions_seen", "DatasetVersion roots seen"),
        ("dataset_versions_superseded_by_newer", "  superseded by a newer root"),
        ("components_without_dataset_version", "components with NO root (untouched)"),
        ("components_planned", "components PLANNED"),
        ("components_consumed", "  CONSUMED"),
        ("components_withheld", "  WITHHELD (orphan guard)"),
        ("components_reverted_on_validation", "  REVERTED (a body failed validation)"),
        # A DOCUMENT count, not a component count. One component is typically
        # many documents (a person alone is five), so this must not be read
        # beside the component rows as though they shared a unit.
        ("documents_consumed", "source DOCUMENTS consumed (not components)"),
        ("datasets_emitted", "dataset entities emitted"),
        ("persons_emitted", "person entities emitted"),
        ("persons_id_preserved", "  with the source id preserved"),
        ("organizations_emitted", "organization entities emitted (deduped by name)"),
        ("organizations_id_preserved", "  with the source id preserved"),
        ("funding_emitted", "funding entities emitted"),
        ("funding_slots_empty_skipped", "  empty funding slots skipped"),
        ("publications_emitted", "publication entities emitted"),
        ("publications_without_doi_skipped", "  skipped: no DOI in the graph"),
        ("web_resources_emitted", "web_resource entities emitted"),
        ("web_resources_from_iri", "  fullDocumentation from a WebResource IRI"),
        ("web_resources_from_doi", "  fullDocumentation from a DOI identifier"),
        # TERMS inside one dataset entity, not documents. Labelled because the
        # rows around it are document counts and nothing else says so.
        ("experimental_approach_terms_emitted", "experimental_approach TERMS (not documents)"),
        ("relations_emitted", "directed_relation documents emitted"),
        # THE LOSSES, WITH NUMBERS ON THEM. Consumed because leaving them would
        # dangle an `openminds_#` edge; not emitted because the entity tier has
        # nowhere to put them. Counted rather than shrugged at, per the brief.
        ("affiliations_beyond_first_dropped", "LOSSY: affiliations after the first"),
        ("contribution_documents_consumed_without_a_home", "LOSSY: Contribution role documents"),
        ("data_type_documents_consumed_without_a_home", "LOSSY: SemanticDataType documents"),
        ("technique_documents_consumed_without_a_home", "LOSSY: technique documents"),
        ("bodies_quarantined", "QUARANTINED bodies"),
        ("documents_appended", "documents appended"),
    ]),
    ("epoch_mint", "did2.convert.epochMint", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("session_documents_seen", "session documents"),
        # THE THREE THAT REACHED THE ARTIFACT AND NOT THE SCREEN until
        # 2026-08-11. `strings_declined` is the one epochMint's own header asks
        # for by name: did2.validate.epochStrings names every source it reads
        # AND every source it declines, so a reader whose source is not wired
        # in "is a number in strings_by_source / strings_declined rather than"
        # a silence -- and that number was not being printed.
        ("documents_with_epoch_id", "documents carrying an epoch string"),
        ("epoch_strings_read", "epoch strings read"),
        ("strings_declined", "  strings DECLINED by the reader"),
        ("strings_declined_distinct", "  distinct declined strings"),
        ("distinct_epoch_id_strings", "distinct id strings"),
        ("distinct_session_epoch_pairs", "distinct (session,id) pairs"),
        ("pairs_minus_strings", "epochs the string key would have FUSED"),
        ("epochs_found_existing", "epochs already present"),
        ("epochs_minted", "epochs minted"),
        ("skipped_synthetic", "refused: synthetic whole_session_ id"),
        ("skipped_no_session_id", "refused: no base.session_id"),
        ("skipped_no_session_document", "refused: no session document"),
        ("skipped_ambiguous_session", "refused: ambiguous session"),
        ("method_parameters_seen", "method_parameters seen"),
        ("method_parameters_edges_filled", "method_parameters epoch_id filled"),
        ("method_parameters_unresolved", "method_parameters unresolved"),
        # THE INGESTED-METADATA FOLD, added 2026-08-11 with the arming of
        # `daqmetadatareader_epochdata_ingested` -> `acquisition_metadata_file`
        # (TEAM-SIGN-OFF [daq ingested payloads] 2026-08-08). 2,659 documents
        # are in scope: B 1,242 / Dab 1,242 / Soph 175.
        #
        # `metadata_fold_vacuous` LEADS THE GROUP because it is the thing that
        # makes the zeros readable. A corpus holding no
        # `daqmetadatareader_epochdata_ingested` document produces exactly the
        # same all-zero block as one where the fold ran and refused every
        # document, and those are opposite readings. It prints FIRST and it
        # prints unconditionally, so "nothing to do" can never be mistaken for
        # "everything done".
        ("metadata_fold_vacuous", "ingested-metadata fold VACUOUS (no sources)"),
        ("metadata_ingested_seen", "daqmetadatareader_epochdata_ingested seen"),
        ("metadata_ingested_already_folded", "  already acquisition_metadata_file"),
        ("metadata_ingested_edges_stamped", "  epoch_id stamped"),
        ("metadata_ingested_folds_emitted", "FOLDED to acquisition_metadata_file"),
        # NOT a quarantine count and not a refusal: the fold was attempted, the
        # body did not come back out of the re-validation, and the ORIGINAL
        # passthrough is what stayed in the batch. Nothing was lost and nothing
        # was gained, which is a third reading and needs its own row.
        ("metadata_ingested_folds_withheld", "  WITHHELD (fold did not validate)"),
        ("metadata_refused_total", "REFUSED (total)"),
        ("metadata_refused_no_epoch_string", "  no epoch string on the document"),
        ("metadata_refused_no_epoch_document", "  no epoch document for the pair"),
        ("metadata_refused_migrator_declined", "  migrator declined (no reader edge / no bytes)"),
        ("mint_quarantined", "QUARANTINED by the mint"),
    ]),
    ("session_anchor_fold", "did2.convert.resolveSessionAnchors", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("session_documents_seen", "session documents"),
        ("anchors_seen", "anchors seen"),
        ("anchors_relative", "  session_relative_reference"),
        ("anchors_bounded", "  session_bounded_reference"),
        # THE BOUNDED-EXTENT GROUP, added 2026-08-11 with the extent refusals.
        # `bounded_extents_examined` LEADS IT because it is the denominator: an
        # extent counter reading 0 beside an examined count of 0 says nothing,
        # and printing the refusals without it would make the two readings
        # identical. It is deliberately NOT `anchors_bounded` -- an anchor
        # refused earlier never reaches the extent read.
        ("bounded_extents_examined", "bounded extents EXAMINED"),
        ("bounded_with_start_field", "  carrying a `start` field at all"),
        ("bounded_with_end_field", "  carrying an `end` field at all"),
        ("bounded_window_carried", "  window CARRIED (start + duration)"),
        ("bounded_start_only_carried", "  start carried, no `end` stated"),
        ("bounded_no_window_stated", "  no window stated (nothing to lose)"),
        # A CELL COUNT, NOT A DOCUMENT COUNT -- one body can contribute two, so
        # it is not part of the seven-bucket partition and must not be summed
        # with the rows above. Said in the label because a reader of the
        # artifact does not have this comment.
        ("bounded_blank_extent_cells", "  blank duration CELLS (not documents)"),
        ("anchors_folded", "FOLDED to relative_reference"),
        ("refused_total", "REFUSED (total)"),
        ("refused_no_session_id", "  no base.session_id"),
        ("refused_no_session_document", "  no session document"),
        ("refused_ambiguous_session", "  ambiguous session"),
        ("refused_ambiguous_relation", "  ambiguous relation (concurrent_with)"),
        ("refused_unknown_relation", "  relation not in the v1 enum"),
        ("refused_negative_extent", "  end < start"),
        ("refused_unreadable_extent_unit", "  extent unit the fold cannot read"),
        ("refused_malformed_extent", "  extent is not a duration cell"),
        ("refused_extent_without_start", "  an `end` with no readable `start`"),
        ("fold_quarantined", "QUARANTINED by the fold"),
    ]),
    # #61's RESOLVER HALF (TEAM-SIGN-OFF [stimulus response] 2026-08-08): the
    # five run knobs move inline onto the harmonic_component_calculation leaf
    # and `method_parameters_id` is dropped, because the schema says a statement
    # carries the inline field OR the edge, never both.
    #
    # READ `leaves_seen` AND `suppressed_responses_seen` AS A PAIR, ALWAYS.
    # `leaves_seen: 0` alone is ambiguous and the pass was built so that it does
    # not have to be:
    #     0 leaves, 0 suppressed   this corpus has no stimulus responses.
    #     0 leaves, N suppressed   BLOCKED UPSTREAM. +migrators_j/
    #                              stimulus_response_scalar.m's epoch gate
    #                              suppresses the fold whenever the v1 body has
    #                              an `element_epochid` string and jEpochDocId
    #                              answers '' -- which is every did_v1 document
    #                              by construction -- so pass 1 emits no leaf at
    #                              all until #60 stamps the epoch_id edge. This
    #                              is the EXPECTED reading today.
    #     N leaves, 0 inlined      a real defect in resolveResponseParameters,
    #                              unless refused_total accounts for all of them.
    #
    # IT DELETES NOTHING, AND THAT IS THE GATE RATHER THAN AN OMISSION. The
    # three `parameters_documents_*` rows ARE the verify-before-delete
    # measurement the plan requires before 11,440 documents may go; they are
    # EVIDENCE, never authorisation, and the corpora are a SAMPLE.
    ("response_parameters_fold", "did2.convert.resolveResponseParameters", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("leaves_seen", "harmonic_component_calculation leaves  <- DENOMINATOR"),
        ("leaves_with_edge", "  carrying method_parameters_id"),
        ("leaves_without_edge", "  no such edge (complete as they stand)"),
        ("suppressed_responses_seen", "v1 responses STILL SUPPRESSED by the epoch gate"),
        ("parameters_documents_seen", "parameters documents  <- DELETION DENOMINATOR"),
        ("inlined", "INLINED"),
        # A FIELD-VALUE count, not a document count: one leaf contributes up to
        # five. It must not be read down the same column as `inlined`.
        ("fields_copied", "  field VALUES copied (cells, not documents)"),
        ("harmonic_checked", "freq_response cross-checked against value.harmonic"),
        ("harmonic_uncheckable", "  not checkable (one side unreadable)"),
        ("refused_total", "REFUSED (total)"),
        ("refused_not_in_batch", "  referent not in this batch"),
        ("refused_ambiguous", "  two documents claim that id"),
        ("refused_wrong_class", "  referent is the wrong class"),
        ("refused_no_fields", "  none of the five knobs present"),
        ("refused_inline_present", "  the leaf already carries inline parameters"),
        ("refused_harmonic_mismatch", "  freq_response ~= value.harmonic"),
        ("fold_quarantined", "QUARANTINED by the fold"),
        ("parameters_documents_referenced_after", "DELETION GATE: still referenced after"),
        ("parameters_documents_unreferenced_after", "  UNREFERENCED after (evidence only)"),
        # 0 by construction -- this pass never deletes. Printed anyway, because
        # the gate it measures is a gate to delete 11,440 documents and a
        # non-zero here would mean the pass pre-empted the team's decision.
        ("parameters_documents_deleted", "parameters documents DELETED (0 by construction)"),
    ]),
    # TEAM DECISION 2026-08-11 (two of them): "each lawn can be a subject and a
    # plate of lawns is another subject where each lawn is a member of it", and
    # "each experiment #, plate #, and patch # combo should be unique and should
    # dictate the local identifier for all patches. None should be labeled just
    # patch #".
    #
    # READ `ontology_table_rows_seen` FIRST, THEN THE THREE `*_rows_seen`.
    # The six tables this pass recognises are written by ONE converter --
    # NDI origin/main +setup/+conv/+haley/doImport.m -- so a corpus not built by
    # it recognises nothing and every row below is vacuous. That is a fact about
    # the SAMPLE, not about the pass.
    #
    # UNITS DIFFER DOWN THIS BLOCK AND ARE NAMED ON EACH ROW. Rows, sessions,
    # COLUMNS, subjects, observations, edges and handles all appear; none of the
    # groups is summable with another and the column invites exactly that.
    #
    # THE PARTITIONS THAT HOLD BY CONSTRUCTION (resolveLawnPlateSubjects.m:
    # 561-592, one exit per row):
    #     plate_rows_seen == with_measurements + values_but_none_emittable
    #                                          + no_values_at_all
    #     lawn_rows_seen  == the same three lawn rows
    # A violation is a counter that stopped moving, not a corpus fact.
    ("lawn_plate_subjects", "did2.convert.resolveLawnPlateSubjects", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("ontology_table_rows_seen", "ontology_table_row documents  <- DENOMINATOR"),
        ("plate_rows_seen", "  PLATE rows recognised"),
        ("image_rows_seen", "  IMAGE rows recognised (a join table, no subject)"),
        ("lawn_rows_seen", "  LAWN rows recognised"),
        ("exp_id_source_rows_seen", "  rows feeding the plate->expID index"),
        ("sessions_with_lawn_plate_tables", "SESSIONS holding any of those"),
        ("unclassified_rows_in_those_sessions", "SPELLING CANARY: unclassified ROWS in them"),
        # COLUMNS, summed over rows -- one row contributes as many as it matches.
        ("columns_resolved_by_key", "COLUMNS matched by key (not rows)"),
        ("columns_resolved_by_term_name", "COLUMNS matched by term name (not rows)"),
        ("plate_rows_with_measurements", "PLATE tier: rows with typed measurements"),
        ("plate_rows_with_values_but_none_emittable", "  rows with values, none emittable"),
        ("plate_rows_with_no_values_at_all", "  rows with no values at all"),
        ("plate_rows_refused_no_session_id", "  refused: no base.session_id"),
        ("plate_rows_refused_no_plate_key", "  refused: no plate identifier column"),
        ("plate_rows_refused_no_exp_id", "  refused: no expID"),
        ("plate_subjects_minted", "  SUBJECTS minted"),
        ("plate_observations_emitted", "  OBSERVATIONS emitted"),
        ("lawn_rows_with_measurements", "LAWN tier: rows with typed measurements"),
        ("lawn_rows_with_values_but_none_emittable", "  rows with values, none emittable"),
        ("lawn_rows_with_no_values_at_all", "  rows with no values at all"),
        ("lawn_rows_refused_no_session_id", "  refused: no base.session_id"),
        ("lawn_rows_refused_no_identity_keys", "  refused: no image/patch identifier"),
        ("lawn_subjects_minted", "  SUBJECTS minted"),
        ("lawn_observations_emitted", "  OBSERVATIONS emitted"),
        ("chains_attempted", "CHAIN patch->image->plate->expID: attempted"),
        ("chains_resolved", "  RESOLVED"),
        ("refused_no_image_row", "  refused: no image row"),
        ("refused_image_row_ambiguous", "  refused: two image rows claim the key"),
        ("refused_image_row_has_no_plate_key", "  refused: image row has no plateID"),
        ("refused_no_plate_row", "  refused: no plate row"),
        ("refused_plate_row_ambiguous", "  refused: two plate rows claim the key"),
        ("refused_lawn_no_exp_id", "  refused: no expID for that plate"),
        ("member_of_relations_emitted", "  member_of EDGES emitted (edges, not rows)"),
        ("withheld_plate_tier_not_minted", "  edge withheld: plate tier not minted"),
        ("withheld_lawn_tier_not_minted", "  edge withheld: lawn tier not minted"),
        # EXCLUDES the C. elegans relabel refusals below -- totalRefusals()
        # (resolveLawnPlateSubjects.m:1305-1317) sums eleven counters and none
        # of them is a `celegans_*` one. Said on the row because a reader
        # totalling the block by eye would put them together.
        ("refused_total", "REFUSED (total; EXCLUDES the C. elegans relabel)"),
        ("celegans_patch_subjects_seen", "C. ELEGANS relabel: patch subjects seen"),
        ("celegans_patch_subjects_relabelled", "  relabelled to the triple"),
        ("celegans_patch_subjects_already_triple", "  already a triple"),
        ("celegans_patch_subjects_refused_no_exp_id", "  left as a pair: no expID"),
        ("celegans_patch_subjects_refused_ambiguous_exp_id", "  left as a pair: ambiguous expID"),
        ("celegans_patch_subjects_unparseable_handle", "  unparseable handle"),
        ("celegans_patch_relabel_quarantined", "  QUARANTINED by the relabel"),
        ("local_identifier_fallback_to_document_id", "HANDLES that fell back to the document id"),
        # DENOMINATORS BEFORE THE FINDING, and the three buckets after it.
        # `_within_batch` is `formed - distinct` and the three sum to it by
        # construction (resolveLawnPlateSubjects.m splitCollisions), so the
        # reader never subtracts anything to get the answer.
        #
        # THE SPLIT EXISTS BECAUSE THE SINGLE NUMBER COULD NOT ANSWER THE
        # QUESTION IT PROVOKED. Run 31522068566 printed 6,414 collisions and
        # this file called the uniqueness directive "refuted on real data"; the
        # team asked "is it not within-session unique?" and the counter --
        # BATCH, not session, over a batch spanning both Haley sessions -- had
        # no way to say. Read `_within_session` for the directive; a
        # cross-session-only duplicate does not bear on it, because every index
        # in that pass and `ndi.session.database_search` are both scoped by
        # `base.session_id`.
        ("local_identifier_handles_formed", "HANDLES formed (handles, not rows)  <- DENOMINATOR"),
        ("local_identifier_handles_distinct", "  of them DISTINCT  <- DENOMINATOR"),
        ("local_identifier_collisions_within_batch", "HANDLE COLLISIONS within the batch"),
        ("local_identifier_collisions_within_session", "  of them WITHIN one base.session_id"),
        ("local_identifier_collisions_across_sessions_only", "  of them ACROSS sessions only"),
        ("local_identifier_collisions_unclassifiable_no_session_id", "  of them UNCLASSIFIABLE (no session id)"),
        ("subjects_quarantined", "QUARANTINED: subjects"),
        ("statements_quarantined", "QUARANTINED: observations + member_of"),
        ("documents_appended", "documents appended"),
        # NOT consumed, deliberately: the typed measures are stored twice until
        # a separate verify-before-delete step says otherwise.
        ("source_rows_left_in_place", "source ROWS left in place (not consumed)"),
    ]),
    # TEAM DECISION 2026-08-11: generic_file -> opaque_body + a statement whose
    # `variable` comes from the sibling ontologyLabel.
    #
    # READ `generic_files_seen` BEFORE ANYTHING ELSE ON THIS BLOCK. All six
    # corpora held ZERO `generic_file` documents at run 31327383671, so an
    # all-zero block is the EXPECTED output and says nothing whatever about
    # whether the fold works -- the class is written by the Babu converter, for
    # datasets that are not in this gate. The corpora are a SAMPLE. A non-zero
    # `generic_files_seen` is the first line that carries information; the
    # refusal breakdown under it then says why anything did not fold.
    ("generic_file_fold", "did2.convert.foldGenericFiles", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("generic_files_seen", "generic_file documents"),
        ("ontology_labels_seen", "ontology_label documents"),
        ("labels_pointing_at_a_file", "  of those, labelling a generic_file"),
        ("files_folded", "FOLDED to term_observation + opaque_body"),
        ("refused_total", "REFUSED (total)"),
        ("refused_no_label", "  no sibling ontologyLabel"),
        ("refused_ambiguous_label", "  two labels on one file"),
        ("refused_label_node_empty", "  label carries no ontologyNode"),
        ("refused_no_document_id", "  no document_id edge"),
        ("refused_referent_not_in_batch", "  referent not in this batch"),
        ("fold_quarantined", "QUARANTINED by the fold"),
        # NOT a refusal and NOT an error: a fold that SUCCEEDED and dropped two
        # fields on the way, because date_created/date_updated have no home in
        # the signed data_body model. Printed beside the successes so the loss
        # is a number in the artifact rather than a sentence in a header.
        ("date_fields_dropped", "date_created/date_updated DROPPED (lossy)"),
        # 0 by construction -- this pass writes to no ontology_label. Printed
        # because `ontology_label` is a ~7,007-document passthrough class and a
        # silent change to it would be ten times the size of the fold.
        ("labels_deleted", "ontology_label documents deleted"),
        ("labels_modified", "ontology_label documents modified"),
    ]),
    # TEAM DECISION 2026-08-11: valid_interval becomes a boolean-valued
    # subject_statement -- one validity_observation per interval, plus the
    # relative_reference it is anchored to.
    #
    # READ `sources_seen` BEFORE ANYTHING ELSE ON THIS BLOCK, and read it twice,
    # because zero means two different things here and only one of them is a
    # statement about the pass:
    #
    #   (a) as a SAMPLE fact -- all six corpora held ZERO `valid_interval`
    #       documents at run 31327383671, so an all-zero block says nothing
    #       whatever about whether the decompose works. markgarbage is an
    #       opt-in curation app; most datasets never ran it.
    #   (b) as HAZARD 1 LOOKING CORRECT -- because markgarbage is opt-in, NO
    #       document means the whole epoch is GOOD DATA (markgarbage.m:172-176
    #       returns the whole requested span on an empty record). A corpus with
    #       no sources MUST come out with `statements_emitted` 0. If that line
    #       is ever non-zero beside `sources_seen` 0, every epoch in every
    #       markgarbage-free dataset has just been reclassified, and NO OTHER
    #       INSTRUMENT HERE COULD SEE IT: quarantine and orphans are 0 either
    #       way.
    #
    # `sources_fully_decomposed` is a DELETION GATE, not a statistic: the
    # `valid_interval` tombstone may be retired only when it equals
    # `sources_seen` and `refused_total` is 0. `split_anchor_intervals` is a
    # PREDICTION UNDER TEST (CHANGE 5 measured that every markvalidinterval call
    # site passes one reference for both ends, so it should stay 0), and
    # `inheritance_candidates` is an OPEN TEAM QUESTION WITH A SIZE -- the
    # subjects NDI's `underlying_element` fallback serves, which nothing else in
    # this repo computes.
    ("valid_interval_decompose", "did2.convert.resolveValidIntervals", [
        ("documents_inspected", "documents inspected"),
        ("documents_unreadable", "UNREADABLE"),
        ("sources_seen", "valid_interval documents"),
        ("epoch_documents_seen", "epoch documents to anchor to"),
        ("intervals_seen", "intervals seen"),
        ("intervals_decomposed", "DECOMPOSED"),
        ("statements_emitted", "validity_observation emitted"),
        ("references_emitted", "relative_reference emitted"),
        ("split_anchor_intervals", "split-anchor intervals (expect 0)"),
        # THE PROVENANCE HALF OF THIS REPORT, unrendered until 2026-08-11.
        # Neither pair is a refusal and neither is a loss: each records WHERE a
        # value came from, so "they agreed" and "we fell back" stay
        # distinguishable. The timeref's session id is the AUTHORITATIVE one --
        # it names the session the referent lives in -- and the document's
        # base.session_id is the fallback (resolveValidIntervals.m:725-734).
        ("anchor_session_from_timeref", "anchor session from the timeref (authoritative)"),
        ("anchor_session_from_document", "  fell back to base.session_id"),
        # The verb is a CONSTANT in both branches; what the branch records is
        # the EVIDENCE for calling it curation (resolveValidIntervals.m:893-928).
        ("method_from_app_block", "method: the source names a producer app"),
        ("method_from_class_default", "  no app block -> the class default"),
        ("sources_fully_decomposed", "DELETION GATE: sources fully decomposed"),
        ("sources_partly_decomposed", "  sources only partly decomposed"),
        ("refused_total", "REFUSED (total)"),
        ("refused_no_element_id", "  no element_id"),
        ("refused_no_intervals", "  no readable interval"),
        ("refused_no_anchor_block", "  entry carries no timeref block"),
        ("refused_no_epoch_string", "  anchor names no epoch"),
        ("refused_no_epoch_document", "  no epoch document for (session,id)"),
        ("refused_ambiguous_epoch", "  two epoch documents claim the pair"),
        ("refused_no_clock", "  no clock / no_time"),
        ("refused_non_finite_times", "  t0 or t1 non-finite"),
        ("refused_negative_extent", "  t1 < t0"),
        # OPEN, not solved. Printed beside the successes so the inheritance
        # decision has a measured size rather than an intuition.
        ("inheritance_candidates", "OPEN: derived_from an element with statements"),
        # Loss that stays on the retained source, counted rather than shrugged at.
        ("sources_with_app_block", "app provenance left on the source"),
        ("staged_ontology_nodes", "ontology terms staged with an empty node"),
        ("references_quarantined", "QUARANTINED: references"),
        ("statements_quarantined", "QUARANTINED: statements"),
        ("statements_withheld_lost_anchor", "WITHHELD (anchor quarantined)"),
        ("documents_appended", "documents appended"),
    ]),
]


# ===========================================================================
# WHERE THE EXPECTED PASS SET COMES FROM -- AND WHY IT IS NO LONGER THIS FILE
# ===========================================================================
#
# POST_PASSES above is a RENDER TABLE: it says how to print the counters a pass
# attaches, and nothing else. It used to double as the EXPECTED SET -- the
# denominator the post-pass block counts against -- and that made it a second
# hand-maintained copy of the harness's chain. It drifted, in the direction
# this project's errors always drift:
#
#     $ python3 -c "import sys; sys.path.insert(0,'tools'); \
#           import census_digest as c; print(len(c.POST_PASSES))"
#     7
#     $ grep -c "did2\.convert\.[A-Za-z_]*(" \
#           tests/+did2/+unittest/+helpers/runCorpusDiscovery.m
#     ... 9 batch post-passes + v1_to_v2
#
# The digest reported "2 expected in a V_eta run" while the harness composed
# NINE, and every pass the table omitted contributed no counter, no
# denominator, and not even a line saying it had not been read. That is
# `testCorpusPRED` again: a thing we run and never measure.
#
# So the expected set is DERIVED, from the two places that actually decide it:
#
#   1. THE CALL SITES THAT WRITE THE REPORTS THIS DIGEST READS. Those files ARE
#      the chain -- the digest renders artifacts they produced, so their calls
#      are the ground truth for "what ran". Both are scanned, not one, because
#      testCorpusPRED writes a report too and a chain that differs between them
#      is a finding rather than a detail.
#   2. THE CONVERT PACKAGE'S SIGNATURES. A batch post-pass is a function whose
#      FIRST ARGUMENT is the `result` struct v1_to_v2 returns -- the same
#      discriminator did2.unittest.testBatchPassWiring/batchPasses uses, and
#      for its stated reason: a hand-kept list is the thing that goes stale the
#      day a pass is added. It is what separates the nine post-passes from
#      `v1_to_v2` (first arg `v1Bodies`) without a hand-written exclusion list.
#
# NOTHING HERE FALLS BACK QUIETLY. If the sources cannot be read the census
# says the expected set was NOT DERIVED, names the path it tried, and marks the
# render table as a FLOOR -- a set that cannot, by construction, show a pass it
# omits. "Could not ask" and "asked and everything agreed" must not print the
# same; that is the whole subject of this block.

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The package the passes live in. Scanned by SIGNATURE, never by name list.
CONVERT_PKG = os.path.join("src", "did", "+did2", "+convert")

# The call sites that WRITE a *-summary.json. testFixtureCorpus composes the
# same chain but writes no report, so it is deliberately not here: this list is
# "the sites that produced the artifacts being digested", not "every caller".
REPORT_WRITING_CALL_SITES = (
    ("runCorpusDiscovery",
     os.path.join("tests", "+did2", "+unittest", "+helpers",
                  "runCorpusDiscovery.m")),
    ("testCorpusPRED",
     os.path.join("tests", "+did2", "+unittest", "testCorpusPRED.m")),
)

_PASS_CALL = re.compile(r"did2\.convert\.([A-Za-z_]\w*)\s*\(")
# runBatchPass(result, 'did2.convert.<fn>', '<reportField>', @(r) ...) -- the
# helper that also WRITES the report field, so this pairing is the only place
# the function name and its report key are stated together. A pass called BARE
# has no pairing here, and that absence is not an oversight in the scan: it is
# the fact that the pass attaches no report at all.
_BATCH_PASS_FIELD = re.compile(
    r"runBatchPass\s*\(\s*result\s*,\s*(?:\.\.\.\s*)?"
    r"'did2\.convert\.(\w+)'\s*,\s*'(\w+)'", re.S)


def strip_matlab_comments(text):
    """Drop %-comments and %{ %} blocks.

    DELIBERATELY CRUDE, AND THE DIRECTION OF ERROR IS THE POINT -- the same
    reasoning DID-schema's check_pipeline_parity.py states for its copy. It
    does not understand a `%` inside a string literal, so it can OVER-strip.
    Over-stripping can only hide a call, which makes the expected set SMALLER;
    a smaller expected set can only under-claim coverage, and under-claiming is
    visible (a pass renders and is not in the census). It can never invent a
    pass, and it can never produce the dangerous direction -- a census that
    says everything expected was seen when something was not.
    """
    out, in_block = [], False
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("%{"):
            in_block = True
            continue
        if s.startswith("%}"):
            in_block = False
            continue
        if in_block or s.startswith("%"):
            continue
        out.append(re.sub(r"%.*$", "", line))
    return "\n".join(out)


def _read_text(path):
    try:
        with open(path, errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


def batch_pass_signatures(root):
    """Every batch post-pass in +did2/+convert, found by SIGNATURE.

    Returns (names_set, info). A batch post-pass is
    `function <out> = <name>(result, ...)`. Plain string parsing rather than
    one regex, for the reason testBatchPassWiring/batchPassName records: its
    regex matched four files locally and zero in CI, and strfind has no
    dialect.

    info carries the denominator -- the directory scanned and how many .m files
    were read -- because zero files and zero matches are different facts and
    the loop cannot tell them apart after it has run.
    """
    pkg = os.path.join(root, CONVERT_PKG)
    info = {"path": pkg, "files": 0, "exists": os.path.isdir(pkg)}
    if not info["exists"]:
        return set(), info
    names = set()
    for name in sorted(os.listdir(pkg)):
        if not name.endswith(".m"):
            continue
        text = _read_text(os.path.join(pkg, name))
        if text is None:
            continue
        info["files"] += 1
        fn = _batch_pass_name(text.splitlines()[0] if text else "")
        if fn:
            names.add(fn)
    return names, info


def _batch_pass_name(sig):
    """The function name in SIG, when SIG is a batch post-pass signature."""
    sig = sig.strip()
    if not sig.startswith("function"):
        return ""
    eq, op = sig.find("="), sig.find("(")
    cl = sig.rfind(")")
    if eq < 0 or op < 0 or cl < 0 or op < eq:
        return ""
    cand = sig[eq + 1:op].strip()
    if not cand.isidentifier():
        return ""
    args = sig[op + 1:cl].split(",")
    if not args or args[0].strip() != "result":
        return ""
    return cand


def call_site_chain(path):
    """The did2.convert.* chain one call site composes, in call order.

    Returns (ordered_names, {fn: report_field}, info). A CALL, not a mention:
    the identifier must be followed by `(`. That matters here -- the harness
    also carries the pass names as QUOTED STRINGS (in its own printBatchPasses
    table and in every runBatchPass argument), and a scan that accepted those
    would report a chain assembled from a table rather than from code.
    """
    info = {"path": path, "exists": os.path.isfile(path), "lines": 0}
    text = _read_text(path)
    if text is None:
        return [], {}, info
    info["lines"] = len(text.splitlines())
    body = strip_matlab_comments(text)
    order = []
    for m in _PASS_CALL.finditer(body):
        if m.group(1) not in order:
            order.append(m.group(1))
    fields = {fn: field for fn, field in _BATCH_PASS_FIELD.findall(body)}
    return order, fields, info


_CHAIN_CACHE = {}


def harness_pass_chain(root=None, _cache=True):
    """The expected batch-post-pass set, DERIVED. Never a hand-kept list.

    Returns a dict:
        derived            bool -- False means the sources could not be read
        chain              [fn, ...] in call order, batch post-passes only
        fields             {fn: report field} for the passes that attach one
        sites              [{label, path, exists, lines, chain}, ...]
        package            the signature-scan info + the names it found
        site_disagreement  [(fn, [labels that call it])] when the two report-
                           writing call sites do not compose the same chain
        called_not_a_pass  did2.convert.* called but not a batch post-pass by
                           signature (v1_to_v2 is the expected member)
        unwired            batch post-passes the call sites do not compose
    """
    root = root or REPO_ROOT
    if _cache and root in _CHAIN_CACHE:
        return _CHAIN_CACHE[root]

    pkg_passes, pkg_info = batch_pass_signatures(root)
    sites, union, fields = [], [], {}
    called_by = {}
    for label, rel in REPORT_WRITING_CALL_SITES:
        order, site_fields, info = call_site_chain(os.path.join(root, rel))
        info["label"] = label
        info["chain"] = order
        sites.append(info)
        for fn in order:
            called_by.setdefault(fn, []).append(label)
            if fn not in union:
                union.append(fn)
        fields.update(site_fields)

    readable = [s for s in sites if s["exists"]]
    derived = bool(readable) and pkg_info["exists"] and bool(pkg_passes)

    chain = [fn for fn in union if fn in pkg_passes]
    called_not_a_pass = [fn for fn in union if fn not in pkg_passes]
    labels = [s["label"] for s in readable]
    site_disagreement = [
        (fn, sorted(called_by.get(fn, [])))
        for fn in chain
        if len(labels) > 1 and sorted(called_by.get(fn, [])) != sorted(labels)
    ]
    out = {
        "derived": derived,
        "chain": chain,
        "fields": {fn: fields[fn] for fn in chain if fn in fields},
        "sites": sites,
        "package": dict(pkg_info, passes=sorted(pkg_passes)),
        "site_disagreement": site_disagreement,
        "called_not_a_pass": called_not_a_pass,
        "unwired": sorted(pkg_passes - set(chain)),
    }
    if _cache:
        _CHAIN_CACHE[root] = out
    return out


def post_pass_expectations(chain=None):
    """Zip the DERIVED chain against the render table. One row per pass.

    Each row is a dict:
        fn          the did2.convert function name
        field       the report key it attaches, or None if it attaches none
        rows        the render table's counter rows, or None
        state       'renderable'   -- attaches a report and this file can print it
                    'unrendered'   -- attaches a report, no render rows here
                    'unmeasured'   -- attaches NO report struct at all
        in_table    whether POST_PASSES carries an entry for it

    THE `unmeasured` ROW IS THE WHOLE POINT. A pass that runs and attaches no
    report contributes nothing to any artifact, so the ONLY way it can appear
    in this digest is for the expected set to name it and for the renderer to
    print it as unmeasured. Omitting it makes "ran and reported nothing" and
    "did not run" the same output, which is the `silentLoss` defect exactly.

    When the chain could NOT be derived, the render table is used as a FLOOR
    and every row is marked so -- see render_pass_census.
    """
    chain = chain or harness_pass_chain()
    by_fn = {}
    for name, fn, rows in POST_PASSES:
        by_fn[fn.split(".")[-1]] = (name, rows)

    expectations, seen = [], set()
    order = chain["chain"] if chain["derived"] else []
    for fn in order:
        seen.add(fn)
        field = chain["fields"].get(fn)
        entry = by_fn.get(fn)
        if entry is None:
            state = "unmeasured" if field is None else "unrendered"
            expectations.append({"fn": fn, "field": field, "rows": None,
                                 "state": state, "in_table": False})
            continue
        name, rows = entry
        # The render table's key and the harness's runBatchPass key are two
        # statements of the same fact. If they disagree the table's key is the
        # one the report actually carries, so it wins -- but the disagreement
        # is recorded rather than smoothed over.
        expectations.append({"fn": fn, "field": name, "rows": rows,
                             "state": "renderable", "in_table": True,
                             "field_mismatch": (field is not None
                                                and field != name)})
    # Anything the render table names that the derived chain does NOT contain.
    # STALE IN THE REASSURING DIRECTION: it renders counters for a pass no
    # report-writing call site composes, which reads as coverage.
    for name, fn, rows in POST_PASSES:
        short = fn.split(".")[-1]
        if short in seen:
            continue
        expectations.append({"fn": short, "field": name, "rows": rows,
                             "state": "renderable" if not chain["derived"]
                             else "not_in_chain", "in_table": True,
                             "derived": chain["derived"]})
    return expectations


def render_pass_census(out, chain=None, indent="  "):
    """The pass census, printed as part of the digest's leading denominator.

    RULE 5: how many passes were expected, where that number came from, how
    many of them can be measured at all, and how many cannot -- before any
    per-pass detail anywhere in the report.
    """
    chain = chain or harness_pass_chain()
    p = lambda s="": out.append(indent + s if s else "")
    exp = post_pass_expectations(chain)

    if not chain["derived"]:
        p("BATCH POST-PASS CENSUS: EXPECTED SET **NOT DERIVED**")
        for site in chain["sites"]:
            p("  call site %-20s %s" % (
                site.get("label", "?"),
                site["path"] if site["exists"] else
                "NOT FOUND: %s" % site["path"]))
        pkg = chain["package"]
        p("  convert package  %s (%d .m file(s), %d batch post-pass "
          "signature(s))" % (pkg["path"] if pkg["exists"]
                             else "NOT FOUND: %s" % pkg["path"],
                             pkg["files"], len(pkg["passes"])))
        p("  FALLING BACK to this file's render table: %d pass(es). That set "
          "is a FLOOR." % len(POST_PASSES))
        p("  It cannot show a pass it omits, which is the exact condition the")
        p("  derivation exists to remove. Treat every 'all present' below as")
        p("  'all present OF THE ONES THIS TABLE KNOWS ABOUT'.")
        return exp

    renderable = [e for e in exp if e["state"] == "renderable"]
    unrendered = [e for e in exp if e["state"] == "unrendered"]
    unmeasured = [e for e in exp if e["state"] == "unmeasured"]
    stale = [e for e in exp if e["state"] == "not_in_chain"]

    p("BATCH POST-PASS CENSUS (the expected set, derived -- not a list in this "
      "file)")
    for site in chain["sites"]:
        p("  DENOMINATOR: %-20s %d line(s), %d pass(es) composed  [%s]"
          % (site.get("label", "?"), site["lines"], len(site["chain"]),
             site["path"] if site["exists"] else "NOT FOUND"))
    pkg = chain["package"]
    p("  DENOMINATOR: %d .m file(s) in %s, %d batch post-pass signature(s)"
      % (pkg["files"], CONVERT_PKG, len(pkg["passes"])))
    p("  EXPECTED %d pass(es): %d with counters this digest renders, "
      "%d UNMEASURED" % (len(chain["chain"]), len(renderable) + len(unrendered),
                         len(unmeasured)))
    if unmeasured:
        p("  *** %d PASS(ES) RUN AND ARE MEASURED BY NOTHING:" % len(unmeasured))
        for e in unmeasured:
            p("  ***   did2.convert.%s" % e["fn"])
        p("  *** They attach no report struct to `result`, so no counter, no")
        p("  *** denominator and no failure of theirs can reach a corpus")
        p("  *** artifact. Every figure in this digest describes a migration")
        p("  *** that INCLUDED them and measured none of their work.")
    if unrendered:
        p("  *** %d PASS(ES) ATTACH A REPORT THIS DIGEST HAS NO ROWS FOR:"
          % len(unrendered))
        for e in unrendered:
            p("  ***   did2.convert.%s -> result.%s" % (e["fn"], e["field"]))
    if stale:
        p("  *** %d RENDER-TABLE ENTR(IES) NAME A PASS NO REPORT-WRITING CALL"
          % len(stale))
        p("  *** SITE COMPOSES -- stale in the reassuring direction:")
        for e in stale:
            p("  ***   %s (did2.convert.%s)" % (e["field"], e["fn"]))
    if chain["site_disagreement"]:
        p("  *** THE TWO REPORT-WRITING CALL SITES DO NOT COMPOSE THE SAME")
        p("  *** CHAIN. A report from one is not comparable with the other:")
        for fn, who in chain["site_disagreement"]:
            p("  ***   %-28s composed only by: %s" % (fn, ", ".join(who)))
    if chain["unwired"]:
        p("  %d batch post-pass(es) exist in the package and are composed by "
          "NEITHER" % len(chain["unwired"]))
        p("  report-writing call site: %s" % ", ".join(chain["unwired"]))
    if chain["called_not_a_pass"]:
        p("  not counted (did2.convert.* called but not a batch post-pass by "
          "signature): %s" % ", ".join(chain["called_not_a_pass"]))
    return exp


# --- THE METADATA TIER ----------------------------------------------------
#
# WHY THESE CLASSES ARE COUNTED, AND WHY THE CO-OCCURRENCE IS THE MEASUREMENT.
#
# `metadata_editor` and the openMINDS dataset graph are written on INDEPENDENT
# paths in NDI, and neither path reads or removes the other's store:
#
#   +ndi/+database/+metadata_ds_core/saveEditor2Doc.m:11-23
#       docName = ['metadata_editor'];  ... ndi.document(docName, ...)
#       -- written on the editor app's window-CLOSE.
#   +ndi/+database/+metadata_app/+fun/save_dataset_docs.m:12
#       ndi.query('openminds.matlab_type','exact_string',
#                 'openminds.core.products.Dataset')
#       -- the openMINDS graph, written on the Save BUTTON.
#
# On the V_eta side `+migrators_j/metadata_editor.m` is the ONLY migrator that
# emits the dataset / person / organization / funding / publication tier
# (`grep -rln "'person'" src/did/+did2/+convert/` matches that one file), and
# there is no migrator for the bare `openminds` class at all. So a dataset that
# has the graph and NO metadata_editor document migrates with its authors,
# funding and publications unmigrated -- and nothing in this digest could say
# whether that combination occurs, because the counts sat unread in `by_class`.
#
# THE COUNTS COME FROM THE v1 SOURCE CENSUS, not from the top-level `by_class`.
# That is not a detail: the top-level table is the MIGRATED-OUTPUT histogram, in
# which `metadata_editor` is absent precisely WHEN IT MIGRATED SUCCESSFULLY.
# Reading absence there as "the corpus has no editor document" would invert the
# finding.
METADATA_EDITOR_CLASS = "metadata_editor"
# The bare `openminds` class IS the dataset-graph store -- it is the class
# save_dataset_docs.m queries and removes. The siblings below are the
# subject/stimulus/element bundles: a different tier, counted for context and
# deliberately NOT folded into the graph total.
OPENMINDS_GRAPH_CLASS = "openminds"
OPENMINDS_SIBLING_CLASSES = ("openminds_element", "openminds_stimulus",
                             "openminds_subject")
METADATA_TIER_CLASSES = ((METADATA_EDITOR_CLASS, OPENMINDS_GRAPH_CLASS)
                         + OPENMINDS_SIBLING_CLASSES)
# What the metadata_editor migrator emits. Printed from the migrated-output
# `by_class` beside the source counts, so "the source document was there" and
# "the tier got built" are separate, visible facts.
METADATA_TIER_EMITTED = ("dataset", "person", "organization", "funding",
                         "publication", "web_resource")


def norm_class(name):
    """Lowercase, underscores stripped -- the mechanical demo_ndi check.

    V_eta is snake_case, NDI is camelCase, and `did2.validate.sourceCensus`
    normalises its `by_class` keys THE SAME WAY (`normClass`: lower + strip
    underscores), so its table is keyed `metadataeditor`, not `metadata_editor`.
    A lookup that used the pretty spelling would return nothing and print 0 --
    a zero that is a property of the query, which is the exact failure that
    dispositioned `demo_ndi` as DELETE off a grep against a repository that has
    never contained that string.

    The top-level `by_class` is keyed by the real class name instead, so BOTH
    sides are normalised here rather than picking one spelling.
    """
    return str(name).replace("_", "").lower()


def normalised_class_index(table):
    """{normalised class name: {"count": int, "keys": [original keys]}}.

    Keys that collide under normalisation are SUMMED and both spellings kept,
    so a table carrying two spellings of one class cannot silently drop one.
    """
    index = {}
    if not isinstance(table, dict):
        return index
    for key, value in table.items():
        try:
            n = int(value)
        except (TypeError, ValueError):
            continue
        entry = index.setdefault(norm_class(key), {"count": 0, "keys": []})
        entry["count"] += n
        entry["keys"].append(key)
    return index


def class_count(index, name):
    entry = index.get(norm_class(name))
    return entry["count"] if entry else 0


def metadata_tier(r):
    """Read one report's metadata-tier counts out of the v1 source census.

    Returns a dict whose `measured` flag is the point of the whole function: a
    corpus that contributed NO readable census must not be renderable as a row
    of zeros. That distinction is the thing this project has shipped the
    absence of twice (`silentLoss` printing "0 empty edges" while reading
    nothing; the digest repeating it), so it is a separate field rather than a
    convention about what a zero means.
    """
    sc = r.get("source_census") or {}
    if not sc:
        return {"measured": False,
                "why": "this report carries no v1 source census block"}
    if "audit_failed" in sc:
        return {"measured": False,
                "why": "the v1 source census FAILED (%s)" % sc["audit_failed"]}
    total = sc.get("total_docs")
    if not isinstance(total, int) or total <= 0:
        return {"measured": False,
                "why": "the v1 source census read %s document(s)" % total}

    index = normalised_class_index(sc.get("by_class"))
    counts = dict((cls, class_count(index, cls)) for cls in METADATA_TIER_CLASSES)
    known = set(norm_class(c) for c in METADATA_TIER_CLASSES)
    extras = {}
    for key, entry in index.items():
        if key.startswith("openminds") and key not in known:
            extras["/".join(entry["keys"])] = entry["count"]

    editor = counts[METADATA_EDITOR_CLASS]
    graph = counts[OPENMINDS_GRAPH_CLASS]
    if graph and editor:
        verdict = "BOTH"
    elif graph:
        verdict = "GRAPH WITHOUT EDITOR"
    elif editor:
        verdict = "EDITOR WITHOUT GRAPH"
    else:
        verdict = "NEITHER"
    return {"measured": True, "source_total": total,
            "skipped": sc.get("skipped_docs", "?"),
            "counts": counts, "extras": extras,
            "editor": editor, "graph": graph, "verdict": verdict}


def render_metadata_tier(r, out):
    """Render one corpus's metadata-tier co-occurrence."""
    p = lambda s="": out.append(s)

    p("  METADATA TIER: metadata_editor vs the openMINDS dataset graph")
    m = metadata_tier(r)
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed for this corpus. A corpus that contributed")
        p("      no readable census and a corpus that contributed a ZERO are")
        p("      different facts and must not print identically.")
        return

    p("      DENOMINATOR: from the v1 SOURCE census -- %s doc(s) read, "
      "%s unreadable" % (m["source_total"], m["skipped"]))
    for cls in METADATA_TIER_CLASSES:
        if cls == METADATA_EDITOR_CLASS:
            note = "   <- the editor store (saveEditor2Doc)"
        elif cls == OPENMINDS_GRAPH_CLASS:
            note = "   <- the dataset graph store (save_dataset_docs)"
        else:
            note = "   (subject/stimulus tier, not the dataset graph)"
        p("      %8d  %-22s%s" % (m["counts"][cls], cls, note))
    if m["extras"]:
        for key, n in sorted(m["extras"].items(), key=lambda kv: (-kv[1], kv[0])):
            p("      %8d  %-22s   <- ANOTHER openminds_* class, not in the "
              "expected list" % (n, key))
    else:
        p("      (no openminds_* class outside the expected list)")

    p("      CO-OCCURRENCE: graph=%d, editor=%d -> %s"
      % (m["graph"], m["editor"], m["verdict"]))
    if m["verdict"] == "GRAPH WITHOUT EDITOR":
        # THIS BANNER SAID THE TIER "migrates NOWHERE" AND BOTH OF ITS REASONS
        # WERE FALSE WHEN IT PRINTED, with the refutation eight lines below it
        # in its own output. Measured 2026-08-11:
        #
        #   $ ls src/did/+did2/+convert/+migrators_j/openminds.m
        #   src/did/+did2/+convert/+migrators_j/openminds.m      <- ee7f325
        #   $ grep -rln "'web_resource'" src/did/+did2/+convert/+migrators_j/
        #   .../dataset_remote.m                                 <- not only
        #   .../metadata_editor.m                                   metadata_editor
        #   $ git merge-base --is-ancestor 47e70bd 7ed9cda   # exit 0
        #
        # `resolveOpenmindsCitations` was an ancestor of the very run that
        # printed this, and its own counters sit directly underneath.
        #
        # It is this repository's house error INVERTED -- it alarms instead of
        # reassuring -- and that is not a lesser fault. It sent a reader after a
        # migrator that already existed and put "live data loss" at the top of a
        # decision list. A counter states what it counted; it does not get to
        # conclude what migrates.
        p("      *** this corpus carries `openminds` document(s) and NO")
        p("      *** metadata_editor document.")
        p("      *** WHAT THAT DOES AND DOES NOT MEAN. It does NOT by itself")
        p("      *** mean a citation graph is present: the bare `openminds`")
        p("      *** class has more than one writer, and `+haley/doImport.m`")
        p("      *** emits strain-assembly documents under the same class name.")
        p("      *** It does NOT mean the tier has no migrator -- read the")
        p("      *** `openminds_citations` block below for what was actually")
        p("      *** consumed, and the migrated `by_class` line for what landed.")
        p("      *** A zero there with 0 roots seen is 'no citation graph in")
        p("      *** this corpus', NOT 'the facts were dropped'.")

    by_class = r.get("by_class")
    if not isinstance(by_class, dict):
        p("      migrated dataset tier: NOT MEASURED -- this report carries no "
          "by_class")
    else:
        emitted = normalised_class_index(by_class)
        p("      migrated dataset tier (from the MIGRATED-OUTPUT by_class): %s"
          % ", ".join("%s=%d" % (c, class_count(emitted, c))
                      for c in METADATA_TIER_EMITTED))


# --- THE EPOCH ASSOCIATION (#72) ------------------------------------------
#
# WHAT IS BEING MEASURED AND WHY IT HAD NO COUNTER.
#
# The team settled (2026-08-10) that a statement reaches its epoch through a
# REFERENCE CHAIN, not a direct edge:
#
#     subject_interaction --time_reference_#--> relative_reference
#                         --relative_to-------> epoch
#
# `min_count: 1` guarantees the family EXISTS and `relative_reference.
# relative_to` is REQUIRED, so a POPULATED reference resolves. But
# `subject_interaction.time_reference_#` is `mustBeNonEmpty: false`, so
# `time_reference_1 = ''` SATISFIES the family and reaches nothing -- and the
# armed RequiredDependencies gate keys on `mustBeNonEmpty`, so it does not fire.
# Between them the two existing silent-loss checks step over exactly that
# document: the family check asks HOW MANY members exist and ignores what they
# hold, and the empty-edge check excludes numbered families by construction.
#
# MEASUREMENT ONLY. Nothing here or in silentLoss tightens a schema, arms a
# gate or changes what quarantines.
#
# The rows are printed from THIS list, not from whatever keys the report
# happens to carry, so a counter the report lacks prints "(absent)" instead of
# vanishing -- the same rule the post-pass block follows, and for the same
# reason: a missing counter and a zero counter are different facts.
EPOCH_ASSOCIATION_FAMILY = [
    ("family_docs_declaring", "document(s) whose CLASS declares a time-reference family"),
    ("family_docs_absent", "  carry NO member (cardinality -- reported separately above)"),
    ("family_docs_present", "  carry >= 1 member"),
    ("family_docs_all_empty", "    <-- REACH NOTHING: every member blank"),
    ("family_docs_populated", "    >= 1 populated member"),
    ("family_members_total", "members: total"),
    ("family_members_empty", "members: BLANK"),
    ("family_members_populated", "members: populated"),
]
EPOCH_ASSOCIATION_EDGES = [
    ("epoch_documents", "`epoch` document(s) in this batch"),
    ("epoch_id_docs_declaring", "document(s) whose CLASS declares an epoch_id edge"),
    ("epoch_id_edges_present", "epoch_id edge(s) found"),
    ("epoch_id_resolved", "  RESOLVED -- names a document in this batch"),
    ("epoch_id_resolved_not_epoch", "    of those, the target is NOT an epoch"),
    ("epoch_id_empty", "  EMPTY -- names nothing"),
    ("epoch_id_unresolved_in_batch", "  NOT IN THIS BATCH -- see the note below"),
]
EPOCH_ASSOCIATION_CHAIN = [
    ("chain_docs_examined", "document(s) with a POPULATED member"),
    ("chain_docs_reaching_epoch", "  REACH AN EPOCH   <-- the number the decision rests on"),
    ("chain_docs_reaching_no_epoch", "  terminate at a definite non-epoch document"),
    ("chain_docs_undetermined", "  UNDETERMINED -- left the batch, or too deep"),
    ("chain_members_examined", "member(s) examined, of which:"),
    ("chain_member_reaches_epoch", "  reach an epoch"),
    ("chain_member_reaches_other", "  terminate elsewhere"),
    ("chain_member_unresolved", "  target not in this batch"),
    ("chain_member_incomplete", "  every branch left the batch"),
    ("chain_member_not_a_reference", "  target is not a time reference at all"),
    ("chain_member_anchor_absent", "  reference declares no anchor edge (terminal by design)"),
    ("chain_member_anchor_empty", "  reference's REQUIRED anchor is blank"),
    ("chain_member_depth_exceeded", "  chain longer than max_depth"),
    ("chain_member_unclassified", "  UNCLASSIFIED -- a state with no counter"),
]


# --- THE EDGES NDI REQUIRES AND V_eta DOES NOT ----------------------------
#
# A SEPARATE BUCKET, NEVER SUMMED WITH THE REAL REQUIRED-EDGE CENSUS.
#
# `silentLoss/requiredDependencies` returns names only for edges declared
# `mustBeNonEmpty` in the V_eta chain, so an edge V_eta RELAXED is not counted
# as zero -- it is not looked at. "0 empty required edges across 627,526
# documents" is therefore SILENT about that whole set. This block renders the
# set. It is REPORT ONLY: the fact travels as a separate schema key
# (`ndi_mustBeNonEmpty`, stamped by DID-schema's tools/ndi_required_stamp.py)
# that nothing validates or gates on.
#
# The two facts are kept apart in every line of output because merging them
# would make the ARMED gate's number unreadable: one is "an edge our schema
# requires is blank", the other is "an edge NDI requires is blank while we
# permit it". Those rank differently and are repaired differently.
NDI_REQUIRED_DENOMINATOR = [
    # THE THREE DOCUMENT STATES, which partition docs_inspected exactly:
    # unreadable (vBodies could not parse it) + unclassifiable (it parsed and
    # carries no document_class) + classified. They are rendered together
    # because the middle one is the state that reads as "clean" when it is
    # omitted -- a document that parsed and was still never looked at.
    ("docs_unclassifiable", "documents with no document_class (NOT looked at)"),
    ("docs_classified", "documents classified"),
    ("classes_carrying_the_marker", "classes whose chain carries the marker"),
    ("relaxed_classes", "classes declaring a RELAXED edge"),
    ("relaxed_edges_declared", "distinct (class, edge) pairs relaxed"),
    ("docs_declaring_a_relaxed_edge", "documents declaring one"),
    ("edges_examined", "edge occurrences examined"),
    ("edges_populated", "  populated"),
    ("edges_empty", "  EMPTY  <-- the count"),
]

# THE IDENTITY LISTS, and the counter each one pairs with.
#
# WHY THEY EXIST. `relaxed_classes` and `relaxed_edges_declared` are counts of
# distinct things, and for a long time they were ALL that survived: silentLoss
# built the two seen-sets over a whole corpus and reported `.Count`, so a
# six-corpus run could say "7 of the schema's divergences were exercised" and
# nothing anywhere -- no log, no artifact, no re-run -- could say WHICH seven.
# The complement is the interesting half (a divergence no corpus touches is
# UNMEASURED, not clean), and a complement cannot be taken against an integer.
#
# The counts are unchanged and still mean what they meant; these lists are
# additional. `len(names) == count` is therefore an invariant of a report that
# carries both, and the renderer CHECKS it -- a names list that quietly went
# short would otherwise shrink the union and read as progress.
NDI_REQUIRED_NAME_FIELDS = [
    ("relaxed_class_names", "relaxed_classes",
     "class(es) declaring a relaxed edge"),
    ("relaxed_edge_names", "relaxed_edges_declared",
     "(class, edge) pair(s) relaxed"),
]


def ndi_required_names(nd, field, count_field):
    """Read ONE identity list out of an NDI-required block.

    The distinction this function exists to preserve: a report that PREDATES
    the identity export carries no list at all, and that is not the same fact
    as a list that came back empty. An absent list must never be rendered as
    `[]`, summed into a union as nothing, or counted as a corpus that
    contributed -- exactly the rule the legacy-vintage and post-pass blocks
    already apply one level up.

    Returns a dict with `measured`, plus `names`/`drift` when measured and
    `why` when not.
    """
    if not isinstance(nd, dict):
        return {"measured": False,
                "why": "the block it would live in is malformed"}
    if field not in nd:
        return {"measured": False,
                "why": "this report predates the identity export -- it carries "
                       "`%s` and not `%s`" % (count_field, field)}
    v = nd[field]
    if isinstance(v, str):
        # Defensive: a single-element list is the only shape MATLAB emits for a
        # cell (jsonencode writes a cell as a JSON array whatever its length),
        # but a bare string would otherwise iterate character by character and
        # produce a union of letters.
        v = [v]
    if not isinstance(v, list):
        return {"measured": False,
                "why": "`%s` is malformed (%s)" % (field, type(v).__name__)}
    names = [x for x in v if isinstance(x, str)]
    drift = None
    if len(names) != len(v):
        drift = ("%d of %d entries in `%s` are not strings"
                 % (len(v) - len(names), len(v), field))
    declared = nd.get(count_field)
    if drift is None and isinstance(declared, int) and declared != len(names):
        drift = ("`%s` says %d, %d name(s) were exported"
                 % (count_field, declared, len(names)))
    return {"measured": True, "names": names, "drift": drift}


def render_ndi_required_names(nd, out, indent="      "):
    """Render one corpus's identity lists. Absent is NOT empty."""
    p = lambda s="": out.append(s)
    p("%sIDENTITIES -- WHICH divergences this corpus actually exercised."
      % indent)
    for field, count_field, label in NDI_REQUIRED_NAME_FIELDS:
        m = ndi_required_names(nd, field, count_field)
        if not m["measured"]:
            p("%s    NAMES NOT MEASURED -- %s." % (indent, m["why"]))
            p("%s    No list is printed and this corpus contributes NOTHING"
              % indent)
            p("%s    to the union below. An absent list is not an empty one."
              % indent)
            continue
        names = m["names"]
        if m["drift"]:
            p("%s    *** THE LIST AND ITS COUNT DISAGREE: %s. One of the two"
              % (indent, m["drift"]))
            p("%s    *** is wrong; do not take the shorter as the answer."
              % indent)
        if not names:
            p("%s    0 %s seen. This is a MEASURED zero -- read it with the"
              % (indent, label))
            p("%s      note above, which says whether the counter could fire "
              "at all." % indent)
            continue
        p("%s    %d %s:" % (indent, len(names), label))
        for n in names:
            p("%s        %s" % (indent, n))


def ndi_required(r):
    """Read one report's NDI-required block, or say why it cannot be read.

    Four NOT-MEASURED conditions, each distinct from a zero and from each
    other -- the same discipline the epoch-association reader applies, for the
    same reason:

      absent          the report predates the counter. NOT rendered as zeros.
      malformed       the key is there and is not an object.
      inspected 0     silentLoss looked at nothing; every count is vacuous.
      all unreadable  it was handed documents and could parse none.

    A FIFTH condition is NOT a not-measured -- it is measured and vacuous, and
    it is handled by the renderer rather than here:
    `classes_carrying_the_marker == 0` means the SCHEMA WAS NEVER STAMPED, so
    the zero is a property of the build and not of the data. That is the
    demo_ndi failure shape (a query against a string the schema has never
    contained), and it prints as a warning rather than as a clean result.
    """
    sl = r.get("silent_loss") or {}
    if not isinstance(sl, dict):
        return {"measured": False,
                "why": "the silent_loss field is malformed (%s)"
                       % type(sl).__name__}
    if "audit_failed" in sl:
        return {"measured": False,
                "why": "the silent-loss audit FAILED (%s)" % sl["audit_failed"]}
    nd = sl.get("ndi_required_denominator")
    if nd is None:
        return {"measured": False,
                "why": "this report carries no ndi_required_denominator block "
                       "-- the counter was not wired into the run that "
                       "produced it"}
    if not isinstance(nd, dict):
        return {"measured": False,
                "why": "the ndi_required_denominator block is malformed (%s)"
                       % type(nd).__name__}
    inspected = nd.get("docs_inspected")
    if not isinstance(inspected, int) or inspected <= 0:
        return {"measured": False, "block": nd,
                "why": "it inspected %s document(s)" % inspected}
    unreadable = nd.get("docs_unreadable")
    if isinstance(unreadable, int) and unreadable >= inspected:
        return {"measured": False, "block": nd,
                "why": "all %s document(s) handed to it were unreadable"
                       % inspected}
    return {"measured": True, "block": nd, "inspected": inspected}


def render_ndi_required(r, out):
    """Render one corpus's NDI-required block. Denominator first."""
    p = lambda s="": out.append(s)
    sl = r.get("silent_loss") if isinstance(r.get("silent_loss"), dict) else {}

    p("  EDGES NDI REQUIRES AND V_eta DOES NOT (report-only, a SEPARATE")
    p("  bucket -- never add this to the empty-required-edge count above)")
    m = ndi_required(r)
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed for this corpus. A corpus that could not")
        p("      be measured and a corpus that measured a ZERO are different")
        p("      facts and must not print identically.")
        return
    nd = m["block"]
    p("      DENOMINATOR: %s document(s) inspected, %s unreadable"
      % (nd.get("docs_inspected", "?"), nd.get("docs_unreadable", "?")))
    # THE KEY IT FOLLOWED, printed as data. Everything else here is
    # schema-driven; this string is not, so if the build stops stamping it the
    # counts all go to zero and the block would otherwise read clean.
    p("      FOLLOWED: schema key `%s` (stamped at build time from NDI's own "
      "schema documents)" % nd.get("marker_key", "?"))
    _ea_rows(nd, NDI_REQUIRED_DENOMINATOR, out)
    if nd.get("classes_carrying_the_marker") == 0:
        p("      *** NO CLASS IN THIS BATCH CARRIES THE MARKER AT ALL. The")
        p("      *** schema was not stamped, or the key was renamed. Every")
        p("      *** count above is a property of the query, NOT a finding")
        p("      *** that V_eta and NDI agree.")
    elif nd.get("relaxed_edges_declared") == 0:
        p("      *** NO CLASS DECLARES AN EDGE NDI REQUIRES AND V_eta")
        p("      *** RELAXES, so the counter could not fire. The zero means")
        p("      *** 'untested', not 'clean'.")
    # The identities BEFORE the empty-edge rows: these describe the
    # denominator (what was looked at), the rows below describe the finding.
    render_ndi_required_names(nd, out)
    p("      %s empty NDI-required edge(s), V_eta-optional"
      % sl.get("ndi_required_dependency_count", "?"))
    for e in aslist(sl.get("ndi_required_dependency"))[:15]:
        p("      %8s  %s.%s" % (e.get("count", "?"), e.get("class_name", "?"),
                                e.get("edge_name", "?")))


def rollup_ndi_required(reports, out):
    """Cross-corpus NDI-required rollup. Denominator first, unmeasured NAMED.

    Kept as its own block and its own totals for the reason stated above: this
    number and the empty-required-edge number are different facts, and a reader
    who adds them gets a figure that describes nothing. The rollup exists at
    all because the number that gets quoted is the total, and a total
    recomputed by hand from six blocks goes stale silently -- 562,422 stood in
    CLAUDE.md for a while and was the six corpora with one `migrated_count`
    substituted for an `inspected`.
    """
    p = lambda s="": out.append(s)

    measured, unmeasured = [], []
    totals = {}
    rows = {}
    unstamped = []
    # field -> {name: [corpora it was seen in]} and field -> [corpora with no
    # list at all]. Kept per field rather than merged, because the class union
    # and the pair union answer different questions and a corpus can only be
    # missing both together today -- but a future report that carries one and
    # not the other must not silently borrow the other's denominator.
    unions = dict((f, {}) for f, _c, _l in NDI_REQUIRED_NAME_FIELDS)
    union_missing = dict((f, []) for f, _c, _l in NDI_REQUIRED_NAME_FIELDS)
    union_carried = dict((f, []) for f, _c, _l in NDI_REQUIRED_NAME_FIELDS)
    union_drift = dict((f, []) for f, _c, _l in NDI_REQUIRED_NAME_FIELDS)
    for i, r in enumerate(reports):
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        m = ndi_required(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        nd = m["block"]
        for field, count_field, _label in NDI_REQUIRED_NAME_FIELDS:
            n = ndi_required_names(nd, field, count_field)
            if not n["measured"]:
                union_missing[field].append("%s (%s)" % (name, n["why"]))
                continue
            union_carried[field].append(name)
            if n["drift"]:
                union_drift[field].append("%s: %s" % (name, n["drift"]))
            for item in n["names"]:
                unions[field].setdefault(item, []).append(name)
        for key, _label in NDI_REQUIRED_DENOMINATOR + [("docs_inspected", ""),
                                                       ("docs_unreadable", "")]:
            if key in nd:
                try:
                    totals[key] = totals.get(key, 0) + int(nd[key] or 0)
                except (TypeError, ValueError):
                    pass
        if nd.get("classes_carrying_the_marker") == 0:
            unstamped.append(name)
        sl = r.get("silent_loss") or {}
        for e in aslist(sl.get("ndi_required_dependency")):
            key = "%s.%s" % (e.get("class_name", "?"), e.get("edge_name", "?"))
            rows[key] = rows.get(key, 0) + int(e.get("count") or 0)

    p("")
    p("  EDGES NDI REQUIRES AND V_eta DOES NOT -- REPORT ONLY, a SEPARATE")
    p("  bucket. DO NOT ADD THIS TO 'EMPTY REQUIRED EDGES' ABOVE: that one is")
    p("  'an edge OUR schema requires is blank' and is what the armed gate")
    p("  keys on; this one is 'an edge NDI requires is blank while we permit")
    p("  it', which no gate sees and which ranks planning work.")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable block, "
      "%d did not; %d document(s) inspected in total"
      % (len(reports), len(measured), len(unmeasured),
         totals.get("docs_inspected", 0)))
    if unmeasured:
        p("      *** NOT MEASURED in: %s" % ", ".join(unmeasured))
        p("      *** the totals below are sums over %d corpora, not %d -- do"
          % (len(measured), len(reports)))
        p("      *** not quote them as a whole-corpus figure.")
    if not measured:
        p("      (nothing to total -- no corpus contributed a readable block)")
        return
    if unstamped:
        p("      *** THE MARKER IS ABSENT FROM THE SCHEMA IN: %s."
          % ", ".join(unstamped))
        p("      *** Their zeros are a property of the build, not a finding.")
    _ea_rows(totals, NDI_REQUIRED_DENOMINATOR, out, indent="        ")
    total = sum(rows.values())
    p("      %d empty NDI-required edge(s) across %d row(s)" % (total, len(rows)))
    for key, n in sorted(rows.items(), key=lambda kv: (-kv[1], kv[0])):
        p("      %8d  %s" % (n, key))
    if not rows:
        p("      (none)")
    rollup_ndi_required_union(unions, union_carried, union_missing,
                              union_drift, len(measured), totals, out)


def rollup_ndi_required_union(unions, carried, missing, drift, n_measured,
                              totals, out):
    """THE UNION OF IDENTITIES SEEN ACROSS CORPORA -- the point of the export.

    The counts alone answer "how many of the schema's divergences did the
    sample exercise". Only the union answers WHICH, and only WHICH makes the
    COMPLEMENT nameable: a divergence that appears in no corpus is unmeasured
    on real data, which is neither clean nor dangerous, just unlooked-at.

    THE DIVERGENCE SET ITSELF IS NOT HERE AND MUST NOT BE. It is computed in
    DID-schema from the stamped schema; a copy in this repo would be a second
    copy to drift, and the drift would be invisible because both sides would
    print confidently. This block reports what was SEEN and says plainly that
    the comparison happens where the set lives.

    A corpus whose report predates the export is NAMED, never counted as
    having contributed an empty set -- the union would otherwise shrink toward
    a reassuring "nothing left to worry about" with each older report added.
    """
    p = lambda s="": out.append(s)
    p("      THE UNION OF IDENTITIES SEEN, over the corpora that carried them:")
    for field, count_field, label in NDI_REQUIRED_NAME_FIELDS:
        seen = unions.get(field) or {}
        got = carried.get(field) or []
        lost = missing.get(field) or []
        p("          DENOMINATOR: %d of %d readable block(s) carried `%s`; "
          "%d distinct %s in the union"
          % (len(got), n_measured, field, len(seen), label))
        for d in drift.get(field) or []:
            p("          *** LIST/COUNT DISAGREEMENT in %s -- the union may be "
              "short." % d)
        if lost:
            p("          *** NAMES NOT MEASURED in: %s." % ", ".join(lost))
            p("          *** Not summed and not treated as an empty set. The")
            p("          *** union below is over %d corpus report(s), not %d."
              % (len(got), n_measured))
        if not got:
            p("          *** NO REPORT CARRIED `%s`. There is nothing to union."
              % field)
            p("          *** This is NOT 'no %s were seen'." % label)
            continue
        if not seen:
            p("          (empty union -- every corpus that carried the list")
            p("           exported none. A MEASURED zero.)")
            continue
        for item in sorted(seen):
            p("          %-58s seen in: %s"
              % (item, ", ".join(sorted(set(seen[item])))))
        # THE SUMMED COUNT IS NOT THE DISTINCT COUNT, and the summed one is
        # what has been quoted. `_ea_rows` above prints the ROLLUP total for
        # `relaxed_edges_declared`, which adds six per-corpus DISTINCT counts
        # together -- so a pair that occurs in three corpora contributes 3.
        # The union size is the cross-corpus distinct figure, and it is the one
        # to subtract from the schema-side divergence set. When the two differ
        # the difference is overlap between corpora, and saying so is cheaper
        # than letting a reader assume the larger number is the answer.
        summed = totals.get(count_field)
        if isinstance(summed, int) and summed != len(seen):
            p("          *** `%s` sums to %d across the rollup; the union is"
              % (count_field, summed))
            p("          *** %d. The rollup total ADDS per-corpus distinct"
              % len(seen))
            p("          *** counts, so overlap between corpora is counted")
            p("          *** more than once. %d is the distinct figure to"
              % len(seen))
            p("          *** compare against the schema-side set%s."
              % (" -- and it is a LOWER BOUND, since not every report "
                 "carried names" if lost else ""))
    p("      *** THIS IS WHAT THE SAMPLE EXERCISED, NOT WHAT EXISTS. The set of")
    p("      *** NDI-required / V_eta-optional divergences is computed in")
    p("      *** DID-schema from the stamped schema and is deliberately NOT")
    p("      *** duplicated here. Subtract the union above from that set: the")
    p("      *** remainder is UNMEASURED on real data -- not clean, unlooked-at.")


# --- #52: HOW MANY TIME REFERENCES DOES ONE STATEMENT CARRY, AND WHAT SHAPE? -
#
# `did2.validate.timeReferenceFamilies` is the evidence for open item #52, where
# the record states plainly that MULTIPLE REFERENCES ON ONE STATEMENT ARE
# UNDEFINED IN MEANING until the `time_reference_#` edges are role-named. It
# runs in v1_to_v2 and writeCorpusReport persists it, and until this block
# landed it printed NOWHERE -- the write-only condition this whole file exists
# to remove, arriving for the seventh time.
#
# A SEPARATE BUCKET FROM silentLoss's `family_uniqueness_violation`, and the two
# must never be added or read as one number. That counter asks whether two
# members of one family BREAK the signed uniqueness rule. This one asks the
# prior, descriptive question the rule does not answer: how often does a family
# have more than one member, and what do those members look like relative to
# each other. A batch can satisfy uniqueness perfectly and be full of shapes
# nobody has decided the meaning of -- the instrument's own header says distinct
# clocks and distinct anchors are both "unique" and are not the same thing.
#
# READING ORDER IS PART OF THE CONTRACT: `headline`, then BOTH vacuity flags,
# and only then a count. It is enforced by the renderer's line order and by
# test_the_headline_and_both_verdicts_precede_every_count.

# The literal `trfUnresolvedKey()` returns. It is a ROW IN THE SHAPE TABLE and
# NOT A SHAPE: it is there so the table partitions `multi_slots_examined`,
# because a statement that could not be shaped must stay countable in the same
# place the shaped ones are or it drops out of the accounting into a silence.
# The renderer checks its statement total against `multi_slots_unresolved`, so
# if this string ever drifts from the MATLAB side the disagreement prints
# instead of the row quietly becoming an ordinary shape.
TRF_NOT_SHAPEABLE = "<NOT SHAPEABLE -- referent outside the batch>"

# The reference-census denominator, in the order the instrument's own header
# lists it. `docs_inspected` is printed by the headline above these rows and is
# deliberately not repeated here.
TRF_DENOMINATOR = [
    # The document states, which partition docs_inspected exactly. The two
    # "NOT looked at" arms are rendered as such: a document that parsed and was
    # never classified reads as clean when it is left out.
    ("docs_unreadable", "documents vBodies could not parse (NOT looked at)"),
    ("docs_unclassifiable", "documents with no document_class (NOT looked at)"),
    ("docs_classified", "documents classified"),
    ("docs_class_unresolved",
     "  classified, chain NOT in the schema cache (NOT looked at)"),
    ("docs_with_an_id", "DISTINCT document ids indexed -- the referent lookup"),
    ("docs_declaring_family",
     "documents whose chain declares a time-reference family"),
    ("docs_declaring_two_families",
     "  declaring TWO  <-- above 0 a slot is no longer a document"),
    ("slots_examined", "(document, family) SLOT(s) examined -- the unit below"),
    ("slots_with_no_member", "  declaring no numbered member at all"),
    ("slots_with_blank_members_only",
     "  every member present and BLANK (names no document)"),
    ("members_examined", "member(s) examined"),
    ("members_blank", "  blank -- the empty-required-edge census owns these"),
    ("statements_with_reference", "slot(s) carrying at least one POPULATED member"),
    ("statements_multi_reference",
     "  carrying TWO OR MORE  <-- the regime #52 exists to decide"),
]

# The shape-census denominator. Kept as its own list because it has its own
# vacuity verdict and its own way of reading zero.
TRF_SHAPE_DENOMINATOR = [
    ("multi_slots_examined", "multi-reference slot(s) reaching the shape pass"),
    ("multi_slots_shaped", "  shaped (every referent inside the batch)"),
    ("multi_slots_unresolved",
     "  NOT SHAPEABLE (a referent outside the batch)"),
    ("multi_members_examined", "member(s) in those slots"),
    ("multi_members_resolved", "  resolved to a document in the batch"),
    ("multi_members_unresolved", "  NOT in the batch"),
]


def _trf_wrap(text, indent, width=78):
    """Wrap one of the instrument's `_reason` sentences for a log.

    They run to ~250 characters because they are written to be read on their
    own, and an unwrapped one is a line nobody finishes.
    """
    lines = textwrap.wrap(str(text), width=max(20, width - len(indent)))
    return [indent + line for line in lines] or [indent + str(text)]


def time_reference_families(r):
    """Read one report's time-reference-family block, or say why it cannot be.

    FIVE NOT-MEASURED conditions, each distinct from a zero and from each other.
    The first is the one this block was written for:

      absent          the report PREDATES the instrument. It is NAMED and
                      contributes nothing -- never rendered or summed as zeros.
      malformed       the key is there and is not an object.
      audit_failed    v1_to_v2's try/catch caught it; the report carries the
                      message and no counters at all.
      inspected 0     it was handed nothing.
      no schema cache no class chain could be resolved, so NO FAMILY COULD BE
                      DISCOVERED. This is "did not look", not "found nothing",
                      and the instrument says so in its own reason string.

    A SIXTH condition is NOT a not-measured and is handled by the renderer:
    `docs_declaring_family == 0` means nothing in the batch could have carried a
    time reference. That is measured and vacuous -- the block ran, looked, and
    the question does not arise here.
    """
    trf = r.get("time_reference_families")
    if trf is None:
        return {"measured": False,
                "why": "this report carries no time_reference_families block "
                       "-- it PREDATES the instrument, which landed 2026-08-11"}
    if not isinstance(trf, dict):
        return {"measured": False,
                "why": "the time_reference_families block is malformed (%s)"
                       % type(trf).__name__}
    if "audit_failed" in trf:
        return {"measured": False,
                "why": "the time-reference-family audit FAILED (%s)"
                       % trf["audit_failed"]}
    inspected = trf.get("docs_inspected")
    if not isinstance(inspected, int) or inspected <= 0:
        return {"measured": False, "block": trf,
                "why": "it inspected %s document(s)" % inspected}
    if trf.get("schema_cache_available") is False:
        return {"measured": False, "block": trf,
                "why": "no schema cache was available, so no class chain could "
                       "be resolved and no family could be discovered"}
    unreadable = trf.get("docs_unreadable")
    if isinstance(unreadable, int) and unreadable >= inspected:
        return {"measured": False, "block": trf,
                "why": "all %s document(s) handed to it were unreadable"
                       % inspected}
    return {"measured": True, "block": trf, "inspected": inspected}


def trf_shape_regime(block):
    """Which of the FOUR shape-census readings a block is in, FROM THE COUNTERS.

    Derived from the numbers rather than by matching the `_reason` string, so a
    flag that disagrees with its own counters is visible instead of authoritative
    -- the renderer prints the disagreement. The four:

      not_reached          the reference census was itself vacuous. The shape
                           table could not even be attempted.
      unoccupied           statements carry a reference and EVERY ONE carries
                           exactly one. A RESULT: the undefined regime is empty
                           in this batch.
      occupied_unmeasured  multi-reference statements EXIST and not one could be
                           shaped, because every one had a referent outside the
                           batch. THE ONE ZERO THAT MUST NEVER READ AS CLEAN --
                           the regime is occupied and we did not measure it.
      measured             at least one multi-reference statement was shaped.

    `unoccupied` and `occupied_unmeasured` BOTH set `shape_census_vacuous`, and
    they are opposite findings. Separating them is the reason this function
    exists rather than the renderer reading one boolean.
    """
    if not isinstance(block, dict):
        return "not_reached"
    if block.get("reference_census_vacuous") is True:
        return "not_reached"
    if _int_or_none(block.get("docs_declaring_family")) == 0:
        return "not_reached"
    multi = _int_or_none(block.get("statements_multi_reference"))
    if multi == 0:
        return "unoccupied"
    sd = block.get("shape_denominator") or {}
    shaped = _int_or_none(sd.get("multi_slots_shaped")) if isinstance(sd, dict) else None
    if multi is None or shaped is None:
        return "not_reached"
    if shaped == 0:
        return "occupied_unmeasured"
    return "measured"


def _trf_invariants(block):
    """The equalities the instrument's own control flow guarantees.

    Every one of these is a partition or a one-increment-per-iteration identity
    read off timeReferenceFamilies.m, not a hope about the data:

      pass 2 runs once per pending record, and a pending record is appended
      exactly when `statements_multi_reference` is bumped; inside it,
      `multi_slots_examined`, one `shape` row and one `emitter` row each go up
      by one, and the slot lands in exactly one of shaped/unresolved.

    So a disagreement here is a defect in the instrument or in the JSON round
    trip, never a property of the corpus. Returns a list of
    (label, left_name, left, right_name, right).
    """
    if not isinstance(block, dict):
        return []
    sd = block.get("shape_denominator") or {}
    ed = block.get("emitter_denominator") or {}
    if not isinstance(sd, dict):
        sd = {}
    if not isinstance(ed, dict):
        ed = {}
    g = lambda d, k: _int_or_none(d.get(k))
    shape_rows = aslist(block.get("shape"))
    emit_rows = aslist(block.get("emitter"))
    dist_rows = aslist(block.get("count_distribution"))
    total = lambda rows: sum(_int_or_none(x.get("statements")) or 0
                             for x in rows if isinstance(x, dict))
    pseudo = sum(_int_or_none(x.get("statements")) or 0 for x in shape_rows
                 if isinstance(x, dict)
                 and x.get("shape_key") == TRF_NOT_SHAPEABLE)
    checks = [
        ("every multi-reference slot reaches the shape pass",
         "statements_multi_reference", g(block, "statements_multi_reference"),
         "shape_denominator.multi_slots_examined", g(sd, "multi_slots_examined")),
        ("the shape pass partitions its slots",
         "multi_slots_examined", g(sd, "multi_slots_examined"),
         "shaped + NOT SHAPEABLE",
         _int_sum(g(sd, "multi_slots_shaped"), g(sd, "multi_slots_unresolved"))),
        ("the shape pass partitions its members",
         "multi_members_examined", g(sd, "multi_members_examined"),
         "resolved + unresolved",
         _int_sum(g(sd, "multi_members_resolved"),
                  g(sd, "multi_members_unresolved"))),
        ("the shape table partitions the multi-reference slots",
         "multi_slots_examined", g(sd, "multi_slots_examined"),
         "sum of shape row statements", total(shape_rows)),
        ("the emitter table partitions the same slots",
         "multi_slots_examined", g(sd, "multi_slots_examined"),
         "sum of emitter row statements", total(emit_rows)),
        ("every multi-reference slot is attributed or visibly unattributed",
         "multi_slots_examined", g(sd, "multi_slots_examined"),
         "with + without a statement name",
         _int_sum(g(ed, "multi_slots_with_statement_name"),
                  g(ed, "multi_slots_without_statement_name"))),
        ("the count distribution covers every referencing slot",
         "statements_with_reference", g(block, "statements_with_reference"),
         "sum of distribution row statements", total(dist_rows)),
        ("the NOT-SHAPEABLE pseudo-row matches its counter",
         "multi_slots_unresolved", g(sd, "multi_slots_unresolved"),
         "statements on the `%s` row" % TRF_NOT_SHAPEABLE, pseudo),
    ]
    return [c for c in checks if c[2] is not None and c[4] is not None]


def _int_sum(*vals):
    """Sum that stays None if any addend is missing -- an absent counter must
    not turn into a 0 that makes a partition check pass."""
    if any(v is None for v in vals):
        return None
    return sum(vals)


def _trf_kind_part(shape_key):
    """The `kind=` segment of a shape key, or '' when there is none.

    The pseudo-row has no segments at all, which is why this returns '' rather
    than raising: `other` must not be searched for in a string that is not a
    shape.
    """
    if not isinstance(shape_key, str) or "|" not in shape_key:
        return ""
    first = shape_key.split("|", 1)[0].strip()
    return first if first.startswith("kind=") else ""


def _trf_shape_description(shape_key):
    """The instrument's OWN words for a shape, when it has words for it.

    trfShapeKey's header names exactly two compositions and says they are not
    the same modelling situation. Those two get its sentence, quoted; every
    other key gets nothing rather than a description invented here. NOTHING IN
    THIS FUNCTION IS A ROLE NAME -- naming `time_reference_1` is the team's
    call and is the whole subject of #52.
    """
    if not isinstance(shape_key, str) or "|" not in shape_key:
        return ""
    same_anchor = "relative_to=same" in shape_key
    diff_anchor = "relative_to=distinct" in shape_key
    # The discriminator label follows the SCHEMA's `referent_unique_by` path
    # (`value.clock` on all three families today), so the segment is matched by
    # its verdict rather than by assuming the word `clock`.
    parts = [s.strip() for s in shape_key.split("|")]
    disc = ""
    for s in parts[1:]:
        if s.startswith("relative_to=") or s.startswith("extent="):
            continue
        disc = s
        break
    if diff_anchor and disc.endswith("=same"):
        return ("the instrument's header calls this the SPLIT-ANCHOR shape: "
                "members agreeing on %s and anchored to DIFFERENT documents"
                % disc.split("=", 1)[0])
    if same_anchor and disc.endswith("=distinct"):
        return ("the instrument's header calls this the SAME-EXTENT-N-%sS "
                "shape: members on DIFFERENT %s anchored to the SAME document"
                % (disc.split("=", 1)[0].upper(), disc.split("=", 1)[0]))
    return ""


def render_time_reference_families(r, out):
    """Render one corpus's #52 block. Headline, then BOTH verdicts, then counts.

    THAT ORDER IS THE INSTRUCTION THE INSTRUMENT'S AUTHOR HANDED OVER, and it is
    not stylistic. Every count in this block has a reading that depends on which
    vacuity regime produced it, and the most dangerous of them -- multi-reference
    statements found and none of them shapeable -- prints as a table of zeros if
    a reader reaches the numbers first.
    """
    p = lambda s="": out.append(s)

    p("  #52 EVIDENCE -- TIME-REFERENCE FAMILIES PER STATEMENT (report-only,")
    p("  a SEPARATE bucket from the family-UNIQUENESS violations above: that")
    p("  one asks whether two members break the signed rule, this one asks how")
    p("  often a statement has two at all and what they look like. Never one")
    p("  number.)")
    m = time_reference_families(r)
    block = m.get("block")

    # 1. THE HEADLINE, first and unconditionally -- the instrument composes it
    #    on every path out of itself INCLUDING its early returns, so a block
    #    that measured nothing still carries one.
    if isinstance(block, dict) and block.get("headline"):
        for line in _trf_wrap(block["headline"], "      "):
            p(line)
    elif isinstance(block, dict):
        p("      *** THE BLOCK CARRIES NO `headline`. The instrument writes one")
        p("      *** on every path out of itself, so its absence means this")
        p("      *** report was not produced by it as shipped. The rows below")
        p("      *** are read straight off the counters instead.")
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed for this corpus. A corpus that could not")
        p("      be measured and a corpus that measured a ZERO are different")
        p("      facts and must not print identically.")
        # The reasons still print when the block exists: "no schema cache" is a
        # not-measured whose reason string is the explanation.
        _render_trf_verdicts(block, out)
        return

    # 2. BOTH VACUITY VERDICTS, BEFORE ANY COUNT.
    _render_trf_verdicts(block, out)

    regime = trf_shape_regime(block)
    if regime == "occupied_unmeasured":
        p("      *** THE UNDEFINED REGIME IS OCCUPIED AND WAS NOT MEASURED.")
        p("      *** %s statement(s) carry two or more references and NOT ONE"
          % block.get("statements_multi_reference", "?"))
        p("      *** could be shaped -- every one had a referent outside this")
        p("      *** batch. An empty shape table here is not 'the shapes are")
        p("      *** fine'; it is 'we did not see them'. This is the one zero")
        p("      *** in this block that must never read as clean.")
    elif regime == "unoccupied":
        p("      *** 0 multi-reference statements, over %s that carry one. That"
          % block.get("statements_with_reference", "?"))
        p("      *** is a RESULT and it agrees with the signed model, which")
        p("      *** predicts a single distribution row at 1. It is a fact")
        p("      *** about THIS SAMPLE and not about the class of documents.")

    # 3. The denominators.
    p("      DENOMINATOR ROWS (`(absent)` is a counter the report does not")
    p("      carry -- never printed as 0):")
    _ea_rows(block, TRF_DENOMINATOR, out, indent="          ")
    if _int_or_none(block.get("docs_declaring_two_families")):
        p("      *** A CLASS IN THIS BATCH DECLARES TWO TIME-REFERENCE")
        p("      *** FAMILIES. The `statements_*` counters above are")
        p("      *** (document, family) PAIRS, not documents, and nothing else")
        p("      *** in this block changes to say so.")
    if _int_or_none(block.get("docs_class_unresolved")):
        p("      *** %s document(s) name a class the schema cache could not"
          % block.get("docs_class_unresolved"))
        p("      *** resolve. Those were NOT LOOKED AT -- they are not classes")
        p("      *** that declare no family.")

    # 4. The count distribution -- the deliverable for #52.
    dist = [x for x in aslist(block.get("count_distribution"))
            if isinstance(x, dict)]
    p("      COUNT DISTRIBUTION -- populated members per slot. THE ROW AT 1 IS")
    p("      THE WELL-DEFINED CASE; every row at 2+ is a statement whose")
    p("      meaning the record calls UNDEFINED until #52 names the edges.")
    if not dist:
        p("          (no row -- no slot carries a populated member)")
    for row in sorted(dist, key=lambda x: _int_or_none(x.get("members")) or 0):
        n = _int_or_none(row.get("members"))
        p("          %10s slot(s) carry %s populated member(s)%s"
          % (row.get("statements", "?"), row.get("members", "?"),
             "   <-- UNDEFINED REGIME" if (n or 0) >= 2 else ""))

    # 5. The shapes.
    _render_trf_shapes(block, out)

    # 6. The invariants -- with their own denominator, per Rule 5 applied to
    #    this renderer's own checking.
    checks = _trf_invariants(block)
    bad = [c for c in checks if c[2] != c[4]]
    p("      INTERNAL CONSISTENCY: %d invariant(s) checked, %d disagreement(s)"
      % (len(checks), len(bad)))
    for label, ln, lv, rn, rv in bad:
        p("      *** %s: `%s` = %s but %s = %s. One of the two is wrong;"
          % (label, ln, lv, rn, rv))
        p("      *** this is a defect in the instrument or in the JSON round")
        p("      *** trip, NOT a property of the corpus.")


def _render_trf_verdicts(block, out):
    """The two vacuity verdicts and their reasons, verbatim.

    TWO FLAGS, TWO DIFFERENT QUESTIONS, and they are printed together and
    labelled because a reader who takes one for the other gets the wrong answer
    in the reassuring direction:

      reference_census_vacuous  NO DOCUMENT COULD HAVE CARRIED A REFERENCE --
                                nothing in the batch belongs to a class whose
                                chain declares a time-reference family (or we
                                could not look at all). Every count is empty by
                                construction and says nothing about time
                                references.
      shape_census_vacuous      NO STATEMENT CARRIES A SECOND REFERENCE -- and
                                it fires AGAIN, for a completely different
                                reason, when multi-reference statements were
                                found and every one had a referent outside the
                                batch. `trf_shape_regime` tells those two apart
                                from the counters; the flag alone cannot.

    Each `_reason` begins `VACUOUS:` or `MEASURED:` and is the instrument's own
    sentence. It is printed rather than paraphrased -- a paraphrase is a second
    copy to drift, and this file's own history is a list of those.
    """
    p = lambda s="": out.append(s)
    if not isinstance(block, dict):
        return
    for flag, reason, label in (
            ("reference_census_vacuous", "reference_census_vacuous_reason",
             "REFERENCE CENSUS"),
            ("shape_census_vacuous", "shape_census_vacuous_reason",
             "SHAPE CENSUS")):
        if flag not in block:
            p("      %s: NO VERDICT -- this report carries no `%s`. Absent is"
              % (label, flag))
            p("          not `false`; do not read the counts as measured.")
            continue
        verdict = "VACUOUS" if block.get(flag) else "MEASURED"
        p("      %s: %s" % (label, verdict))
        text = block.get(reason)
        if not text:
            p("          *** and it carries NO `%s`. The instrument writes one"
              % reason)
            p("          *** on every path; its absence is itself a finding.")
            continue
        for line in _trf_wrap(text, "          "):
            p(line)
        # The flag and its own sentence must agree on which way round they are.
        starts = str(text).strip().upper().startswith(verdict)
        if not starts:
            p("          *** THE FLAG AND ITS REASON DISAGREE: `%s` is %s and"
              % (flag, block.get(flag)))
            p("          *** the reason opens with the other word. Trust")
            p("          *** neither until the instrument is re-read.")
    # The flag says vacuous-or-not; only the counters say WHICH vacuum.
    regime = trf_shape_regime(block)
    p("      SHAPE-CENSUS REGIME, derived from the counters and not from the")
    p("      flag: %s" % {
        "not_reached": "NOT REACHED -- the reference census was itself vacuous",
        "unoccupied": "UNOCCUPIED -- statements carry a reference, none carries "
                      "two (a RESULT)",
        "occupied_unmeasured": "OCCUPIED AND UNMEASURED -- multi-reference "
                               "statements exist and NONE was shapeable",
        "measured": "MEASURED -- at least one multi-reference statement was "
                    "shaped",
    }[regime])


def _render_trf_shapes(block, out):
    """The shape table for one corpus, denominator first."""
    p = lambda s="": out.append(s)
    sd = block.get("shape_denominator")
    if not isinstance(sd, dict):
        sd = {}
    p("      SHAPE DENOMINATOR:")
    _ea_rows(sd, TRF_SHAPE_DENOMINATOR, out, indent="          ")
    rows = [x for x in aslist(block.get("shape")) if isinstance(x, dict)]
    real = [x for x in rows if x.get("shape_key") != TRF_NOT_SHAPEABLE]
    pseudo = [x for x in rows if x.get("shape_key") == TRF_NOT_SHAPEABLE]
    p("      SHAPES: %d table row(s) -- %d shape(s) and %d NOT-SHAPEABLE"
      % (len(rows), len(real), len(pseudo)))
    p("      pseudo-row(s). THE PSEUDO-ROW IS NOT A SHAPE. The instrument's own")
    p("      `MEASURED:` sentence above counts it among its 'distinct")
    p("      shape(s)', because that number is numel(shape) over the whole")
    p("      table -- so where a pseudo-row exists that sentence is one high.")
    p("      A SHAPE KEY DESCRIBES THE DATA AND IS NOT A ROLE NAME.")
    if not rows:
        p("          (no row -- see the shape-census verdict above for which")
        p("           of the three empty readings this is)")
        return
    for row in sorted(rows, key=lambda x: -(_int_or_none(x.get("statements")) or 0)):
        p("          %8s slot(s)  %s member(s)  %s"
          % (row.get("statements", "?"), row.get("members", "?"),
             row.get("shape_key", "?")))
        p("                    e.g. %s  [%s]  family %s"
          % (row.get("example_document_id") or "(no id)",
             row.get("example_class_name") or "(no class)",
             row.get("family") or "(unnamed)"))
        desc = _trf_shape_description(row.get("shape_key"))
        if desc:
            for line in _trf_wrap(desc, "                    "):
                p(line)
        if "other" in _trf_kind_part(row.get("shape_key")):
            p("          *** A MEMBER OF THIS FAMILY IS NOT A TIME REFERENCE.")
            p("          *** `must_refer_to_document_class` is existence-only,")
            p("          *** so it validates clean. The instrument calls this")
            p("          *** 'a finding, not something to round off'.")
    emit = [x for x in aslist(block.get("emitter")) if isinstance(x, dict)]
    ed = block.get("emitter_denominator")
    if not isinstance(ed, dict):
        ed = {}
    p("      EMITTERS (a HINT off `base.name`, which is a convention and not an")
    p("      interface): %d row(s); %s slot(s) carry a statement name, %s do not"
      % (len(emit), ed.get("multi_slots_with_statement_name", "(absent)"),
         ed.get("multi_slots_without_statement_name", "(absent)")))
    for row in sorted(emit, key=lambda x: -(_int_or_none(x.get("statements")) or 0)):
        p("          %8s  %s / name=%s / anchors=%s"
          % (row.get("statements", "?"),
             row.get("statement_class") or "(no class)",
             row.get("statement_name") or "(unnamed)",
             row.get("anchor_names") or "(none)"))


def rollup_time_reference_families(reports, out):
    """Cross-corpus #52 rollup. Shapes UNITED BY `shape_key`, never summed.

    THE UNION IS THE WHOLE POINT AND THE SUM IS A TRAP THIS REPOSITORY HAS
    ALREADY FALLEN INTO. One file over, the relaxed-edge rollup added six
    per-corpus DISTINCT counts together, so a (class, edge) pair present in
    three corpora contributed 3 -- and the published "7 of 26 divergences seen"
    was an upper bound whose true value could have been as low as 2. A shape is
    the same kind of thing: `kind=2rel | clock=distinct | relative_to=same |
    extent=2instant` is ONE shape however many corpora hold it, and the number
    that will get quoted is "how many distinct shapes does the team have to
    name". So the distinct figure here is len(union), and the summed row count
    is printed BESIDE it, named as the upper bound it is.

    Statement counts inside a row ARE summed -- those are slot counts and they
    add. The rule is about identities, not about occurrences.

    A report predating the instrument is NAMED and contributes NOTHING. It is
    never counted as a corpus that measured a zero: a union that absorbs absent
    reports shrinks toward a reassuring "nothing left to name" with every older
    report added.
    """
    p = lambda s="": out.append(s)

    measured, unmeasured = [], []
    totals = {}
    dist = {}
    shapes = {}
    emitters = {}
    regimes = {"not_reached": [], "unoccupied": [], "occupied_unmeasured": [],
               "measured": []}
    per_corpus_shape_rows = 0
    two_families, unresolved_classes = [], []
    inconsistent = []

    for i, r in enumerate(reports):
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        m = time_reference_families(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        b = m["block"]
        regimes[trf_shape_regime(b)].append(name)
        sd = b.get("shape_denominator") if isinstance(b.get("shape_denominator"), dict) else {}
        for key, _label in TRF_DENOMINATOR + [("docs_inspected", "")]:
            if key in b:
                v = _int_or_none(b[key])
                if v is not None:
                    totals[key] = totals.get(key, 0) + v
        for key, _label in TRF_SHAPE_DENOMINATOR:
            if key in sd:
                v = _int_or_none(sd[key])
                if v is not None:
                    totals[key] = totals.get(key, 0) + v
        if _int_or_none(b.get("docs_declaring_two_families")):
            two_families.append(name)
        if _int_or_none(b.get("docs_class_unresolved")):
            unresolved_classes.append("%s (%s)"
                                      % (name, b.get("docs_class_unresolved")))
        if [c for c in _trf_invariants(b) if c[2] != c[4]]:
            inconsistent.append(name)
        for row in aslist(b.get("count_distribution")):
            if not isinstance(row, dict):
                continue
            k = _int_or_none(row.get("members"))
            if k is None:
                continue
            dist[k] = dist.get(k, 0) + (_int_or_none(row.get("statements")) or 0)
        rows = [x for x in aslist(b.get("shape")) if isinstance(x, dict)]
        # Counted WITHOUT the pseudo-row, so this figure and the union size
        # below are the same kind of thing. Comparing a with-pseudo sum against
        # a without-pseudo union would make them differ by one for a reason
        # that has nothing to do with the overlap the comparison is about.
        per_corpus_shape_rows += len([x for x in rows
                                      if x.get("shape_key") != TRF_NOT_SHAPEABLE])
        for row in rows:
            key = row.get("shape_key", "?")
            # UNITED BY `shape_key`. The MATLAB table keys its rows on
            # (shape_key, member count), so one key can arrive as two rows from
            # a single corpus; they collapse here and the member counts are
            # kept as a SET so nothing is lost by uniting.
            ent = shapes.setdefault(key, {"statements": 0, "corpora": set(),
                                          "members": set(), "families": set(),
                                          "example": None})
            ent["statements"] += _int_or_none(row.get("statements")) or 0
            ent["corpora"].add(name)
            mem = _int_or_none(row.get("members"))
            if mem is not None:
                ent["members"].add(mem)
            if row.get("family"):
                ent["families"].add(str(row["family"]))
            if ent["example"] is None and row.get("example_document_id"):
                ent["example"] = (row["example_document_id"],
                                  row.get("example_class_name") or "(no class)",
                                  name)
        for row in aslist(b.get("emitter")):
            if not isinstance(row, dict):
                continue
            k = (row.get("shape_key", "?"),
                 row.get("statement_class") or "(no class)",
                 row.get("statement_name") or "(unnamed)",
                 row.get("anchor_names") or "(none)")
            ent = emitters.setdefault(k, {"statements": 0, "corpora": set()})
            ent["statements"] += _int_or_none(row.get("statements")) or 0
            ent["corpora"].add(name)

    p("")
    p("  #52 -- TIME REFERENCES PER STATEMENT, AND THE SHAPES WHEN THERE ARE")
    p("  TWO. REPORT ONLY, a SEPARATE bucket: do NOT add this to the")
    p("  EDGE-FAMILY UNIQUENESS table above. That one is 'two members break the")
    p("  signed uniqueness rule'; this one is 'a statement has two members at")
    p("  all', which no rule forbids and which the record calls UNDEFINED IN")
    p("  MEANING until the edges are role-named.")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable block, "
      "%d did not; %d document(s) inspected in total"
      % (len(reports), len(measured), len(unmeasured),
         totals.get("docs_inspected", 0)))
    if unmeasured:
        p("      *** NOT MEASURED in: %s" % ", ".join(unmeasured))
        p("      *** the totals below are sums over %d corpora, not %d -- do"
          % (len(measured), len(reports)))
        p("      *** not quote them as a whole-corpus figure. A report that")
        p("      *** predates the instrument contributes NOTHING; it is not a")
        p("      *** corpus that measured a zero.")
    if not measured:
        p("      (nothing to total -- no corpus contributed a readable block)")
        return
    p("      SHAPE-CENSUS REGIME PER CORPUS, derived from the counters:")
    for key, label in (
            ("measured", "MEASURED -- multi-reference statements were shaped"),
            ("occupied_unmeasured",
             "OCCUPIED AND UNMEASURED -- multi-reference statements exist and "
             "NONE was shapeable  <-- never read this as clean"),
            ("unoccupied",
             "UNOCCUPIED -- statements carry a reference, none carries two "
             "(a RESULT)"),
            ("not_reached",
             "NOT REACHED -- no document could have carried a reference at "
             "all (vacuous)")):
        p("          %-22s %s" % (", ".join(regimes[key]) or "(none)", label))
    if regimes["occupied_unmeasured"]:
        p("      *** %s IS IN THE OCCUPIED-AND-UNMEASURED REGIME. The empty"
          % ", ".join(regimes["occupied_unmeasured"]))
        p("      *** shape table there means the referents were outside the")
        p("      *** batch, NOT that the shapes are fine.")
    if two_families:
        p("      *** TWO FAMILIES ON ONE CLASS in: %s. The slot counters are"
          % ", ".join(two_families))
        p("      *** (document, family) pairs there, not documents.")
    if unresolved_classes:
        p("      *** CLASSES THE CACHE COULD NOT RESOLVE in: %s. Those"
          % ", ".join(unresolved_classes))
        p("      *** documents were NOT LOOKED AT.")
    if inconsistent:
        p("      *** INTERNAL CONSISTENCY FAILED in: %s. See the per-corpus"
          % ", ".join(inconsistent))
        p("      *** block for which equality broke.")
    p("      DENOMINATOR ROWS, SUMMED over the %d readable block(s). These are"
      % len(measured))
    p("      OCCURRENCE counts and they add; the identities below do NOT.")
    _ea_rows(totals, TRF_DENOMINATOR, out, indent="        ")
    _ea_rows(totals, TRF_SHAPE_DENOMINATOR, out, indent="        ")

    p("")
    p("      COUNT DISTRIBUTION, summed across corpora (slot counts ADD; it is")
    p("      IDENTITIES that must not be summed):")
    if not dist:
        p("          (no row)")
    for k in sorted(dist):
        p("          %10d slot(s) carry %d populated member(s)%s"
          % (dist[k], k, "   <-- UNDEFINED REGIME" if k >= 2 else ""))
    over_one = sum(v for k, v in dist.items() if k >= 2)
    p("          %d slot(s) in total are in the regime #52 exists to decide."
      % over_one)

    real = dict((k, v) for k, v in shapes.items() if k != TRF_NOT_SHAPEABLE)
    pseudo = shapes.get(TRF_NOT_SHAPEABLE)
    p("")
    p("      SHAPES, UNITED BY `shape_key` ACROSS CORPORA -- NOT SUMMED.")
    p("          DENOMINATOR: %d distinct shape(s) in the union, over %d "
      "corpus report(s) that carried a readable block."
      % (len(real), len(measured)))
    if pseudo:
        p("          Plus 1 NOT-SHAPEABLE pseudo-row (%d slot(s)), which is NOT"
          % pseudo["statements"])
        p("          a shape -- it exists so the table partitions the")
        p("          multi-reference slots instead of losing them to silence.")
    if per_corpus_shape_rows != len(real):
        p("          *** the per-corpus shape-row counts ADD to %d; the union"
          % per_corpus_shape_rows)
        p("          *** is %d. %d is the distinct figure. Adding per-corpus"
          % (len(real), len(real)))
        p("          *** counts is the error that made a published '7 of 26")
        p("          *** seen' an upper bound one file over -- a shape present")
        p("          *** in three corpora would count 3.")
    if not real and not pseudo:
        p("          (empty union -- read the regime table above for which of")
        p("           the empty readings this is; it is not one fact)")
    for key, ent in sorted(real.items(),
                           key=lambda kv: (-kv[1]["statements"], kv[0])):
        p("          %8d slot(s)  members=%s  %s"
          % (ent["statements"],
             ",".join(str(x) for x in sorted(ent["members"])) or "?", key))
        p("                    seen in: %s   famil(ies): %s"
          % (", ".join(sorted(ent["corpora"])),
             ", ".join(sorted(ent["families"])) or "(unnamed)"))
        if ent["example"]:
            p("                    e.g. %s [%s] in %s"
              % (ent["example"][0], ent["example"][1], ent["example"][2]))
        desc = _trf_shape_description(key)
        if desc:
            for line in _trf_wrap(desc, "                    "):
                p(line)
        if "other" in _trf_kind_part(key):
            p("          *** A MEMBER HERE IS NOT A TIME REFERENCE AT ALL.")
            p("          *** `must_refer` is existence-only so it validates")
            p("          *** clean; the instrument calls it a finding.")

    p("")
    p("      EMITTERS, united the same way -- %d distinct (shape, class, name,"
      % len(emitters))
    p("      anchors) row(s). `base.name` is a CONVENTION, not an interface.")
    for k, ent in sorted(emitters.items(),
                         key=lambda kv: (-kv[1]["statements"], kv[0])):
        p("          %8d  %s / name=%s / anchors=%s"
          % (ent["statements"], k[1], k[2], k[3]))
        p("                    shape: %s" % k[0])
        p("                    seen in: %s" % ", ".join(sorted(ent["corpora"])))
    if not emitters:
        p("          (none)")

    _trf_reading_instructions(out)


def _trf_reading_instructions(out):
    """WHAT TO BE ALARMED BY -- every item read off timeReferenceFamilies.m.

    Nothing here is invented and nothing here names a role. #52 is the question
    of whether `time_reference_1` should become a role name; a digest that
    proposed one would be answering the team's question in its own output.
    """
    p = lambda s="": out.append(s)
    p("")
    p("      WHAT TO BE ALARMED BY IN THIS BLOCK (each item is read off")
    p("      src/did/+did2/+validate/timeReferenceFamilies.m, not invented):")
    p("        * ANY DISTRIBUTION ROW AT 2 OR MORE. The instrument's header")
    p("          states the signed model's PREDICTION as a prediction: every")
    p("          statement carries exactly one reference, the distribution has")
    p("          a single row at 1, and the shape table is vacuous. It counted")
    p("          44 code lines writing a literal `time_reference_1` and ZERO")
    p("          writing `time_reference_2` or higher, across 258 .m files, and")
    p("          found ONE site numbering a family programmatically --")
    p("          did2.convert.resolveValidIntervals's split-anchor branch,")
    p("          which the model predicts never fires. A row at 2+ is that")
    p("          prediction failing, and it is exactly the evidence #52 wants.")
    p("        * MULTI-REFERENCE STATEMENTS WITH NONE SHAPEABLE. The shape")
    p("          census reports VACUOUS for two opposite reasons. 'No statement")
    p("          carries a second one' is a result; 'every one had a referent")
    p("          outside the batch' is an occupied regime nobody measured.")
    p("          The regime table above tells them apart from the counters.")
    p("        * `other` IN A SHAPE KEY'S `kind=` PART. A member is pointing at")
    p("          something that is not a time reference. must_refer is")
    p("          existence-only, so the document validates clean.")
    p("        * `docs_declaring_two_families` ABOVE ZERO. No class declares")
    p("          two today, which is the only reason the `statements_*`")
    p("          counters can be read as documents. Above zero they are")
    p("          (document, family) pairs and nothing renames them.")
    p("        * `docs_class_unresolved` OR `docs_unclassifiable` ABOVE ZERO.")
    p("          Both are 'not looked at', not 'declares nothing'.")
    p("        * A NON-ZERO `slots_with_blank_members_only` OR `members_blank`.")
    p("          A member that is present and blank satisfies min_count and")
    p("          names no document. It belongs to the empty-required-edge")
    p("          census, and it is NOT a reference -- do not read it as one.")
    p("      WHAT THIS BLOCK CANNOT TELL YOU, stated rather than guessed:")
    p("        * WHETHER AN INDEX MEANS A ROLE. That is #52 itself and it is a")
    p("          V_eta disposition. The instrument proposes no role names and")
    p("          neither does this digest; a shape key describes what the")
    p("          referenced documents DIFFER ON, never what a member means.")
    p("        * WHETHER AN `example_document_id` IS STABLE. It is the FIRST")
    p("          statement seen in batch order, and the instrument takes")
    p("          whatever order its caller hands it -- nothing in its source")
    p("          fixes that order across runs. Treat it as a handle to open")
    p("          one instance, not as an identity.")
    p("        * HOW MANY ANCHORS AN `anchors=` STRING STANDS FOR. It is")
    p("          strjoin(unique(names)), so it DEDUPS and SORTS: two anchors")
    p("          sharing a name render as one entry and the order is gone.")
    p("          The member count on the shape row is the number.")
    p("        * WHETHER TWO DOCUMENTS SHARE AN ID. `docs_with_an_id` counts")
    p("          DISTINCT ids and the index keeps the FIRST holder, so a")
    p("          referent whose id is duplicated resolves to whichever came")
    p("          first. Nothing in the report measures how often that happens.")
    p("      *** AND THE STANDING RULE: THE CORPORA ARE A SAMPLE OF DATASETS,")
    p("      *** NOT THE UNIVERSE. A shape absent from every corpus here is")
    p("      *** UNMEASURED, not impossible.")


def epoch_association(r):
    """Read one report's epoch-association block, or say why it cannot be read.

    Four NOT-MEASURED conditions, kept apart from each other and from a zero:

      absent        the report has no `epoch_association` -- it predates the
                    counter. NOT rendered as zeros.
      malformed     the key is there and is not an object.
      inspected 0   silentLoss looked at nothing. Every count below it is
                    vacuous -- this is the original defect, and the rule is
                    unchanged: check total_docs before believing any figure.
      all unreadable  it was handed documents and could parse none.
    """
    sl = r.get("silent_loss") or {}
    if not isinstance(sl, dict):
        # `"audit_failed" in sl` on a string is a SUBSTRING test, which would
        # answer a question nobody asked. Malformed input gets its own reading.
        return {"measured": False,
                "why": "the silent_loss field is malformed (%s)"
                       % type(sl).__name__}
    if "audit_failed" in sl:
        return {"measured": False,
                "why": "the silent-loss audit FAILED (%s)" % sl["audit_failed"]}
    ea = sl.get("epoch_association")
    if ea is None:
        return {"measured": False,
                "why": "this report carries no epoch_association block -- the "
                       "counter was not wired into the run that produced it"}
    if not isinstance(ea, dict):
        return {"measured": False,
                "why": "the epoch_association block is malformed (%s)"
                       % type(ea).__name__}
    inspected = ea.get("docs_inspected")
    if not isinstance(inspected, int) or inspected <= 0:
        return {"measured": False, "block": ea,
                "why": "it inspected %s document(s)" % inspected}
    unreadable = ea.get("docs_unreadable")
    if isinstance(unreadable, int) and unreadable >= inspected:
        return {"measured": False, "block": ea,
                "why": "all %s document(s) handed to it were unreadable"
                       % inspected}
    return {"measured": True, "block": ea, "inspected": inspected}


def _ea_rows(ea, rows, out, indent="          "):
    for key, label in rows:
        if key in ea:
            out.append("%s%10s  %s" % (indent, ea[key], label))
        else:
            # A counter the report does not carry is NOT printed as 0.
            out.append("%s%10s  %s" % (indent, "(absent)", label))


def _epoch_association_population(r):
    """Which batch the epoch-association figures describe, in one line.

    Derived from the report -- the pass-1 population against the final
    `migrated_count` -- not from a belief about the wiring, so it stays true if
    the wiring changes. Three readings, and "cannot tell" is one of them.
    """
    ea = epoch_association(r)
    if not ea["measured"]:
        return "unknown -- the block could not be read"
    pop = _int_or_none(ea["block"].get("docs_inspected"))
    final = _int_or_none(r.get("migrated_count"))
    if pop is None or final is None:
        return ("cannot be determined -- the report does not carry both a "
                "block population and a migrated_count")
    if pop == final:
        return ("the FINAL migrated batch (%d document(s), equal to "
                "migrated_count)" % pop)
    return ("the PASS-1 batch (%d document(s)), which is %d SMALLER than the "
            "migrated output (%d). Batch post-passes -- did2.convert.epochMint "
            "among them -- run after silent_loss is computed, so these counts "
            "are NOT comparable with the post-pass epoch figures. See EPOCH "
            "DOCUMENT POPULATIONS below."
            % (pop, final - pop, final))


def _render_post_pass_epoch_population(name, pop, p, scope=""):
    """Name the batch a post-pass `epoch` figure counted over, at the figure.

    THE OTHER HALF OF THE SAME REPAIR, and it is not decoration. The
    epoch-association block now says which batch it read, but the two figures
    that CONTRADICTED it -- `epochs minted` and `epoch documents to anchor to`
    -- print here, in the post-pass block, roughly forty lines further down. A
    reader who arrives at those does not have the epoch-association block on
    screen, so labelling only one side leaves the two numbers comparable in
    exactly the direction the defect ran: 8433 here, 0 there, nothing at either
    site saying they count different batches.

    `documents_inspected` is set on entry to every pass (epochMint.m:212,
    resolveValidIntervals.m:427), so it IS the population and is read from the
    report rather than asserted. Absent, this says so and prints no number --
    a population nobody measured must not arrive as a figure.

    Called from BOTH the per-corpus block and the rollup, because the rollup is
    where run 31508009545 actually printed 8433 against the epoch-association
    0. `scope` says whether the population is one corpus's or a sum, so a
    summed population is never read as a single batch.
    """
    batch = ("a batch of UNRECORDED size" if pop is None
             else "a batch of %d document(s)%s" % (pop, scope))
    if name == "epoch_mint":
        p("          POPULATION: `epochs minted` counts documents this pass")
        p("          ADDED to %s. It is NOT the" % batch)
        p("          same quantity as the `epoch` count in EPOCH ASSOCIATION")
        p("          above, which read the PASS-1 batch -- before this pass")
        p("          ran. Cross-checked in EPOCH DOCUMENT POPULATIONS.")
    else:
        p("          POPULATION: `epoch documents to anchor to` counts `epoch`")
        p("          documents in %s -- AFTER" % batch)
        p("          did2.convert.epochMint appended. NOT comparable with the")
        p("          `epoch` count in EPOCH ASSOCIATION above. Cross-checked")
        p("          in EPOCH DOCUMENT POPULATIONS.")


def render_epoch_association(r, out):
    """Render one corpus's epoch-association block. Denominator first."""
    p = lambda s="": out.append(s)

    p("  EPOCH ASSOCIATION (#72): does a statement actually reach an epoch?")
    p("      MEASUREMENT ONLY -- nothing here is enforced and nothing "
      "quarantines on it.")
    m = epoch_association(r)
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed for this corpus. A corpus that could not")
        p("      be measured and a corpus that measured a ZERO are different")
        p("      facts and must not print identically.")
        return
    ea = m["block"]

    p("      DENOMINATOR: %s document(s) inspected, %s unreadable, %s classified"
      % (ea.get("docs_inspected", "?"), ea.get("docs_unreadable", "?"),
         ea.get("docs_classified", "?")))
    # THE POPULATION, printed with the denominator and never apart from it.
    # Rule 5 asks a counter how MANY things it inspected; this says WHICH, and
    # the difference is the whole defect: 633,432 documents is a true and
    # complete denominator for a batch that structurally cannot hold a minted
    # `epoch`. See epoch_populations() for the ladder that measures it.
    p("      POPULATION: %s" % _epoch_association_population(r))
    # THE NAMES IT FOLLOWED. Everything else in the block is schema-driven;
    # these are not, so a rename would send every count to zero and the report
    # would read clean -- the demo_ndi failure, where a grep against a string
    # the repository has never contained was reported as "this does not exist".
    p("      FOLLOWED: <family> -> `%s` -> `%s`, max depth %s"
      % (ea.get("anchor_edge", "?"), ea.get("terminal_class", "?"),
         ea.get("max_depth", "?")))
    for key, label in (("terminal_class_in_schema", "terminal_class"),
                       ("reference_root_in_schema", "reference_root")):
        val = ea.get(key)
        if val == 1:
            continue
        p("      *** `%s` (%s) DOES NOT LOAD FROM THE SCHEMA (%s=%s)."
          % (ea.get(label, "?"), label, key, val))
        p("      *** Every count below that mentions it is a property of the")
        p("      *** query, not of the data. Do NOT read them as zeros.")

    p("      (1) THE TIME-REFERENCE FAMILY -- does it reach anything at all?")
    _ea_rows(ea, EPOCH_ASSOCIATION_FAMILY, out)
    if ea.get("family_docs_declaring") == 0:
        p("          *** NO DOCUMENT'S CLASS DECLARES A TIME-REFERENCE FAMILY.")
        p("          *** The family counters could not fire; their zeros mean")
        p("          *** 'untested', not 'clean'.")
    for e in aslist(ea.get("family_all_empty_by_class"))[:10]:
        p("          %8s  %s.%s  family present, every member blank"
          % (e.get("count", "?"), e.get("class_name", "?"),
             e.get("edge_name", "?")))

    p("      (2) `epoch` DOCUMENTS AND `epoch_id` EDGES (checked BY NAME)")
    _ea_rows(ea, EPOCH_ASSOCIATION_EDGES, out)
    p("          NOTE: 'not in this batch' is NOT 'dangling'. A batch is a")
    p("          SAMPLE -- an edge naming a document outside it may resolve in")
    p("          a full migration (jSessionAnchor's discovery-mode orphans were")
    p("          exactly that). The three states are kept distinct; the third is")
    p("          named for what was measured.")
    for e in aslist(ea.get("epoch_id_by_class"))[:10]:
        p("          %8s  %s.epoch_id  %s"
          % (e.get("count", "?"), e.get("class_name", "?"),
             e.get("state", "?")))

    p("      (3) THE CHAIN, END TO END")
    _ea_rows(ea, EPOCH_ASSOCIATION_CHAIN, out)
    if ea.get("chain_docs_examined") == 0:
        p("          *** NO DOCUMENT CARRIES A POPULATED MEMBER, so the chain")
        p("          *** was never walked. Zero reaching an epoch means")
        p("          *** 'untested', not 'nothing reaches one'.")
    for e in aslist(ea.get("chain_terminus_by_class"))[:10]:
        p("          %8s  chain terminated at: %s"
          % (e.get("count", "?"), e.get("class_name", "?")))


def rollup_epoch_association(reports, out):
    """Cross-corpus epoch association, denominator first and unmeasured named.

    The rollup is the number that gets quoted -- in a plan document, in a commit
    message, in CLAUDE.md -- so it is computed here rather than hand-summed from
    the per-corpus blocks. That is not a hypothetical: 562,422 was recorded as
    an inspected total and was the six corpora with one of them contributing its
    `migrated_count` instead. Corpora that contributed nothing readable are
    NAMED and excluded, never summed in as zeros.
    """
    p = lambda s="": out.append(s)

    measured, unmeasured = [], []
    totals = {}
    empty_rows, edge_rows, term_rows = {}, {}, {}
    schema_warn = []
    for i, r in enumerate(reports):
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        m = epoch_association(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        ea = m["block"]
        for key, _label in (EPOCH_ASSOCIATION_FAMILY + EPOCH_ASSOCIATION_EDGES
                            + EPOCH_ASSOCIATION_CHAIN
                            + [("docs_inspected", ""), ("docs_unreadable", ""),
                               ("docs_classified", "")]):
            if key in ea:
                try:
                    totals[key] = totals.get(key, 0) + int(ea[key] or 0)
                except (TypeError, ValueError):
                    pass
        if ea.get("terminal_class_in_schema") != 1 or \
                ea.get("reference_root_in_schema") != 1:
            schema_warn.append(name)
        for e in aslist(ea.get("family_all_empty_by_class")):
            key = "%s.%s" % (e.get("class_name", "?"), e.get("edge_name", "?"))
            empty_rows[key] = empty_rows.get(key, 0) + int(e.get("count") or 0)
        for e in aslist(ea.get("epoch_id_by_class")):
            key = "%s.epoch_id  %s" % (e.get("class_name", "?"),
                                       e.get("state", "?"))
            edge_rows[key] = edge_rows.get(key, 0) + int(e.get("count") or 0)
        for e in aslist(ea.get("chain_terminus_by_class")):
            key = str(e.get("class_name", "?"))
            term_rows[key] = term_rows.get(key, 0) + int(e.get("count") or 0)

    p("")
    p("  EPOCH ASSOCIATION (#72) -- MEASUREMENT ONLY, nothing is enforced")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable "
      "epoch-association block, %d did not; %d document(s) inspected in total"
      % (len(reports), len(measured), len(unmeasured),
         totals.get("docs_inspected", 0)))
    # THE POPULATION, beside the denominator, for the same reason as the
    # per-corpus block: the totals below are a true sum over a batch that is
    # not the migrated output, and a reader comparing them with the mint's
    # figures further down has no way to know that from the numbers alone.
    pre_mint = [str(r.get("corpus") or "report #%d" % (i + 1))
                for i, r in enumerate(reports)
                if epoch_populations(r)["ea_is_final_stage"] is False]
    if pre_mint:
        p("      POPULATION: the PASS-1 batch in %s -- smaller than the "
          "migrated output, and measured BEFORE did2.convert.epochMint runs."
          % ", ".join(pre_mint))
        p("      NOT comparable with the post-pass `epoch` figures. See EPOCH")
        p("      DOCUMENT POPULATIONS below, which reconciles them.")
    else:
        p("      POPULATION: the FINAL migrated batch in every corpus that "
          "carried a readable block.")
    if unmeasured:
        p("      *** NOT MEASURED in: %s" % ", ".join(unmeasured))
        p("      *** the totals below are sums over %d corpora, not %d -- do"
          % (len(measured), len(reports)))
        p("      *** not quote them as a whole-corpus figure.")
    if not measured:
        p("      (nothing to total -- no corpus contributed a readable block)")
        return
    if schema_warn:
        p("      *** the followed class names DID NOT LOAD from the schema in:")
        p("      *** %s. Their counts are a property of the query."
          % ", ".join(schema_warn))

    p("      (1) THE TIME-REFERENCE FAMILY")
    _ea_rows(totals, EPOCH_ASSOCIATION_FAMILY, out, indent="        ")
    p("      (2) `epoch` DOCUMENTS AND `epoch_id` EDGES")
    _ea_rows(totals, EPOCH_ASSOCIATION_EDGES, out, indent="        ")
    p("      (3) THE CHAIN, END TO END")
    _ea_rows(totals, EPOCH_ASSOCIATION_CHAIN, out, indent="        ")

    for label, table in (("FAMILIES PRESENT AND ENTIRELY BLANK", empty_rows),
                         ("epoch_id EDGES BY CLASS AND STATE", edge_rows),
                         ("CHAIN TERMINI (non-epoch)", term_rows)):
        p("      %s: %d occurrence(s) across %d row(s)"
          % (label, sum(table.values()), len(table)))
        for key, n in sorted(table.items(), key=lambda kv: (-kv[1], kv[0])):
            p("        %8d  %s" % (n, key))
        if not table:
            p("        (none)")


# --- WHICH BATCH DID EACH `epoch` FIGURE COUNT OVER? ----------------------
#
# THE DEFECT THIS EXISTS TO PREVENT, stated as it happened.
#
# Corpus run 31508009545 (head 602ee141, all 7 jobs green) printed all of these
# from the same six corpora, in one digest, and reconciled none of them:
#
#     epoch_mint                 8433 epochs minted
#     valid_interval_decompose   8433 epoch documents to anchor to
#     epoch association          0 `epoch` document(s) in this batch
#                                0 REACH AN EPOCH  <-- "the number the
#                                                      decision rests on"
#
# Two counters said 8,433 epoch documents exist; a third said none did. A
# reader had no way to tell from the output whether 8,433 minted epochs were
# failing to reach the documents that should reference them (a migration
# defect) or whether one counter was looking somewhere else (a measurement
# defect). Those are opposite conclusions and both are actionable.
#
# IT IS THE SECOND, AND THE PIPELINE ORDER IS WHAT DOES IT.
# `tests/+did2/+unittest/+helpers/runCorpusDiscovery.m:61` calls
# `did2.convert.v1_to_v2`, which computes `result.silent_loss` at
# `v1_to_v2.m:382` over the pass-1 batch. Every batch post-pass runs AFTER
# that, at runCorpusDiscovery.m:70-302 -- epochMint at :136. Nothing recomputes
# `silent_loss`. So the epoch-association block reads a batch that CANNOT
# contain a minted `epoch` document, and its zero is a property of WHEN it ran.
#
# The corpus's own numbers say so without needing the source read (Soph):
#
#     silent_loss inspected           254304   pass 1
#     epoch_mint documents_inspected  254239   after two passes that also drop
#     epochs minted                    +176
#     valid_interval documents_inspected 254415  = 254239 + 176, exactly
#     migrated_count                   254415
#
# Every pass sets `documents_inspected = numel(result.migrated)` on entry
# (epochMint.m:212, resolveSessionAnchors.m:355, resolveValidIntervals.m:427),
# so that ladder is the batch growing under the passes, measured four times.
#
# WHAT THIS BLOCK DOES ABOUT IT. It prints the ladder, labels every `epoch`
# figure with the population it counted over, and splits them into two sets:
#
#   COMMENSURABLE -- all count `epoch` documents in a POST-MINT batch. They
#                    must be equal. A disagreement means epochs were minted and
#                    then lost, and it exits non-zero.
#   NOT COMMENSURABLE -- measured before the mint. Printed with the size of the
#                    gap, and the "REACH AN EPOCH" figure explicitly stripped of
#                    its authority while it is measured at that stage.
#
# THE SPLIT IS DERIVED FROM THE REPORT, NOT HARDCODED. A corpus whose
# epoch-association population already equals `migrated_count` has been measured
# on the final batch, and its figures move INTO the commensurable set and get
# cross-checked like the rest. So if the wiring is ever fixed -- silent_loss
# recomputed after the passes -- this instrument starts enforcing on its own
# instead of going quiet. That is deliberate: the rule against absence-as-
# evidence applies to the digest's own stage assumptions too.


def _pass_report(r, key):
    """One batch-pass report, or (None, why it cannot be read).

    FOUR states, and collapsing any two of them is how a zero becomes a lie:
    absent (not wired into the run), malformed, `pass_failed` (the harness guard
    caught a throw and the documents are in pass-1 form), and `ran == false`
    (a legitimate no-op). None of them is a measurement of zero.
    """
    rep = r.get(key)
    if rep is None:
        return None, "no `%s` block -- the pass was not wired into this run" % key
    if not isinstance(rep, dict):
        return None, "the `%s` block is malformed (%s)" % (key, type(rep).__name__)
    if rep.get("pass_failed"):
        return None, "`%s` FAILED (%s) -- its documents are in pass-1 form" \
                     % (key, rep["pass_failed"])
    if rep.get("ran") is False:
        return None, "`%s` did not run (non-V_eta target, or an empty batch)" % key
    return rep, None


def epoch_populations(r):
    """Every `epoch` figure in one report, tagged with the batch it counted.

    Returns a dict. `ladder` is [(population, label, note)] in pipeline order,
    with a None population where the report cannot supply one -- absent is not
    zero. `commensurable` and `pre_mint` are [(count, label)]. `unreadable` is
    the reasons, named. `disagreement` is None or the message.

    WHY `by_class` IS IN THE COMMENSURABLE SET. It is not the pass-1 census: it
    is recomputed from `result.migrated` by every post-pass that touches the
    batch (`recountSummary`, epochMint.m:702, resolveSessionAnchors.m:829,
    resolveValidIntervals.m:1123) and the last one to run is what
    writeCorpusReport.m:35 persists. So it is a FINAL class census and the
    minted epochs must appear in it. It is also the only one of the three that
    would notice a later pass DELETING an epoch document.
    """
    reading = {"ladder": [], "commensurable": [], "pre_mint": [],
               "unreadable": [], "disagreement": None, "not_comparable": None,
               "ea_is_final_stage": None, "gap": None}

    final = _int_or_none(r.get("migrated_count"))

    # (1) the pass-1 stage -- what silent_loss actually read.
    ea = epoch_association(r)
    ea_pop = None
    if ea["measured"]:
        block = ea["block"]
        ea_pop = _int_or_none(block.get("docs_inspected"))
        ea_epochs = _int_or_none(block.get("epoch_documents"))
        ea_reach = _int_or_none(block.get("chain_docs_reaching_epoch"))
        # THE DERIVED SPLIT. Same population as the final batch => the block was
        # measured on the migrated output and its figures are comparable.
        reading["ea_is_final_stage"] = (
            ea_pop is not None and final is not None and ea_pop == final)
        bucket = ("commensurable" if reading["ea_is_final_stage"]
                  else "pre_mint")
        if ea_epochs is not None:
            reading[bucket].append(
                (ea_epochs, "epoch_association: `epoch` document(s) in "
                            "the batch it read"))
        # REACH AN EPOCH is NEVER put in the equality check -- it counts
        # STATEMENTS that reach an epoch, not epoch documents, so it is not the
        # same quantity as the three below and must not be summed with them.
        # It is carried so the annotation can name it, which is the whole
        # point: it is the figure the epoch decision was going to be taken on.
        if ea_reach is not None:
            reading["reach_epoch"] = ea_reach
        if ea_pop is not None and final is not None:
            reading["gap"] = final - ea_pop
    else:
        reading["unreadable"].append("epoch_association: %s" % ea["why"])

    reading["ladder"].append(
        (ea_pop, "silent_loss / epoch_association",
         "PASS 1 (did2.convert.v1_to_v2 computes it before any post-pass)"))

    # (2) the mint.
    mint, why = _pass_report(r, "epoch_mint")
    if why:
        reading["unreadable"].append(why)
        reading["ladder"].append((None, "epoch_mint", "batch post-pass"))
    else:
        reading["ladder"].append(
            (_int_or_none(mint.get("documents_inspected")), "epoch_mint",
             "batch post-pass -- the batch BEFORE the mint appends"))
        minted = _int_or_none(mint.get("epochs_minted"))
        existing = _int_or_none(mint.get("epochs_found_existing"))
        if minted is None:
            reading["unreadable"].append(
                "epoch_mint carries no `epochs_minted` counter")
        else:
            # `epochs_found_existing` is part of the population and not part of
            # the mint's work: an epoch already in the batch is one the next
            # pass will also see. Absent it reads as unknown, so the row says so
            # rather than quietly assuming none.
            if existing is None:
                reading["unreadable"].append(
                    "epoch_mint carries no `epochs_found_existing` counter -- "
                    "its contribution to the population is UNKNOWN, so it is "
                    "not compared")
            else:
                reading["commensurable"].append(
                    (minted + existing,
                     "epoch_mint: minted %d + already present %d"
                     % (minted, existing)))

    # (3) the last pass, which counts `epoch` documents in the batch it got.
    vid, why = _pass_report(r, "valid_interval_decompose")
    if why:
        reading["unreadable"].append(why)
        reading["ladder"].append(
            (None, "valid_interval_decompose", "batch post-pass"))
    else:
        reading["ladder"].append(
            (_int_or_none(vid.get("documents_inspected")),
             "valid_interval_decompose", "batch post-pass"))
        seen = _int_or_none(vid.get("epoch_documents_seen"))
        if seen is None:
            reading["unreadable"].append(
                "valid_interval_decompose carries no `epoch_documents_seen`")
        else:
            reading["commensurable"].append(
                (seen, "valid_interval_decompose: epoch documents to anchor to"))

    # (4) the end of the pipeline.
    reading["ladder"].append((final, "migrated_count", "END OF PIPELINE"))
    by_class = r.get("by_class")
    if not isinstance(by_class, dict):
        reading["unreadable"].append(
            "the report carries no `by_class` -- the FINAL class census is "
            "the only figure that would notice an epoch DELETED after minting")
    else:
        reading["commensurable"].append(
            (class_count(normalised_class_index(by_class), "epoch"),
             "by_class: `epoch` in the FINAL class census"))

    values = set(v for v, _label in reading["commensurable"])
    if len(values) > 1:
        reading["disagreement"] = (
            "%d figure(s) counting `epoch` documents in a POST-MINT batch do "
            "NOT agree: %s" % (len(reading["commensurable"]),
                               ", ".join("%d (%s)" % (v, lab) for v, lab
                                         in reading["commensurable"])))
    return reading


def _render_epoch_populations(reading, p, scope):
    """Shared renderer for one corpus and for the rollup. Returns findings."""
    findings = []
    p("  EPOCH DOCUMENT POPULATIONS -- WHICH BATCH EACH FIGURE COUNTED (%s)"
      % scope)
    # RULE 5. The denominator here is how many populations could be read at
    # all, because that is what bounds every comparison below it.
    readable = [v for v, _l, _n in reading["ladder"] if v is not None]
    p("      DENOMINATOR: %d of %d pipeline stage(s) reported a population; "
      "%d figure(s) comparable, %d measured pre-mint, %d unreadable"
      % (len(readable), len(reading["ladder"]),
         len(reading["commensurable"]), len(reading["pre_mint"]),
         len(reading["unreadable"])))
    for why in reading["unreadable"]:
        p("      *** NOT MEASURED: %s." % why)

    p("      THE LADDER -- documents in the batch when each instrument ran:")
    for value, label, note in reading["ladder"]:
        p("        %10s  %-32s %s"
          % ("(absent)" if value is None else value, label, note))

    ladder_flat = (len(set(readable)) <= 1)
    if readable and not ladder_flat:
        p("      *** THE LADDER IS NOT FLAT (%d .. %d). The instruments below"
          % (min(readable), max(readable)))
        p("      *** did NOT read the same batch. A figure from one stage is")
        p("      *** not comparable with a figure from another.")

    p("      `epoch` DOCUMENTS, POST-MINT -- COMMENSURABLE, must agree:")
    if not reading["commensurable"]:
        p("        (none readable -- nothing to cross-check, which is")
        p("         'untested', not 'agreed')")
    for value, label in reading["commensurable"]:
        p("        %10d  %s" % (value, label))
    if reading["not_comparable"]:
        # A SUM IS NOT COMPARABLE WITH A SUM OVER A DIFFERENT SET. This is the
        # 562,422 error in miniature -- six corpora with one of them
        # substituting a different counter -- and here it would fire as a
        # migration defect on two corpora that are each internally consistent.
        p("      *** THESE SUMS ARE NOT COMPARABLE: %s"
          % reading["not_comparable"])
        p("      *** No conclusion is drawn from the difference. Read the")
        p("      *** per-corpus blocks, which compare like with like.")
    elif reading["disagreement"]:
        p("      *** %s" % reading["disagreement"])
        p("      *** These count the SAME THING over the SAME batch. A")
        p("      *** difference means `epoch` documents were minted and then")
        p("      *** lost, which is a MIGRATION defect, not a reporting one.")
        findings.append(reading["disagreement"])
    elif len(reading["commensurable"]) > 1:
        p("      -> AGREE (%d figure(s), all %d)."
          % (len(reading["commensurable"]),
             reading["commensurable"][0][0]))
    elif len(reading["commensurable"]) == 1:
        p("      *** ONE figure only -- nothing to cross-check it against.")
        p("      *** An unopposed figure is untested, not confirmed.")

    # REACH AN EPOCH is never left bare. Either it is annotated as a stage
    # artefact below, or -- once the block is measured on the final batch -- it
    # is announced as a real measurement here, so the two readings of the same
    # printed number cannot be confused for one another.
    if reading.get("ea_is_final_stage") and reading.get("reach_epoch") is not None:
        p("      `REACH AN EPOCH` = %d, measured on the FINAL migrated batch"
          % reading["reach_epoch"])
        p("      (the epoch-association population equals migrated_count). At")
        p("      this stage it is a real measurement, not a stage artefact.")

    # The pre-mint section prints only when something was ACTUALLY measured
    # pre-mint. When the epoch-association block has been measured on the final
    # batch its figures moved into the commensurable set above, and printing an
    # empty "do not compare these" warning would be the reverse of this block's
    # job: a caution about a hazard that is no longer there.
    if reading["pre_mint"]:
        p("      `epoch` FIGURES MEASURED PRE-MINT -- NOT COMMENSURABLE with")
        p("      the set above. DO NOT COMPARE THEM:")
        for value, label in reading["pre_mint"]:
            p("        %10d  %s" % (value, label))
        if reading.get("reach_epoch") is not None:
            p("        %10d  epoch_association: REACH AN EPOCH"
              % reading["reach_epoch"])
        gap = reading.get("gap")
        p("      *** silent_loss is computed inside did2.convert.v1_to_v2")
        p("      *** (v1_to_v2.m:382); every batch post-pass, did2.convert.")
        p("      *** epochMint included, runs AFTER it and nothing recomputes")
        p("      *** it. So no minted `epoch` document can be in the batch it")
        p("      *** read%s."
          % ("" if gap is None else ", which is %d document(s) smaller than "
             "the migrated output" % gap))
        p("      *** A 0 here is a property of WHEN the counter ran.")
        if reading.get("reach_epoch") == 0:
            p("      *** `REACH AN EPOCH` is labelled 'the number the decision")
            p("      *** rests on'. AT THIS STAGE IT CANNOT BE ANYTHING BUT 0,")
            p("      *** so it is not evidence that nothing reaches an epoch.")
            p("      *** The post-mint value is UNMEASURED. Do not take the")
            p("      *** epoch decision on it.")
    return findings


def render_epoch_populations(r, out):
    """Per corpus. Returns findings (the disagreement, if any)."""
    p = lambda s="": out.append(s)
    return _render_epoch_populations(epoch_populations(r), p, "this corpus")


def rollup_epoch_populations(reports, out):
    """Cross-corpus, summed per stage. Returns findings.

    Summed rather than re-derived, and the corpora that could not contribute a
    given stage are NAMED -- a corpus missing from a sum must not read as a
    corpus contributing zero. That is the 562,422 error, which was six corpora
    with one of them substituting a different counter.
    """
    p = lambda s="": out.append(s)
    p("")

    combined = {"ladder": [], "commensurable": [], "pre_mint": [],
                "unreadable": [], "disagreement": None, "not_comparable": None,
                "ea_is_final_stage": None, "gap": None}
    if not reports:
        p("  EPOCH DOCUMENT POPULATIONS: no corpus report to read.")
        return []

    per = [epoch_populations(r) for r in reports]
    names = [str(r.get("corpus") or "report #%d" % (i + 1))
             for i, r in enumerate(reports)]

    # The ladder rows are positional and identical across corpora by
    # construction (epoch_populations always appends all four), so summing by
    # index is sound. A stage absent in one corpus is NAMED, not zero-filled.
    for idx in range(len(per[0]["ladder"])):
        total, missing = 0, []
        for name, reading in zip(names, per):
            value = reading["ladder"][idx][0]
            if value is None:
                missing.append(name)
            else:
                total += value
        label = per[0]["ladder"][idx][1]
        note = per[0]["ladder"][idx][2]
        if missing:
            note = "%s  [NOT from: %s]" % (note, ", ".join(missing))
        combined["ladder"].append(
            (None if len(missing) == len(names) else total, label, note))

    contributors = {}
    for bucket in ("commensurable", "pre_mint"):
        labels = []
        for reading in per:
            for _v, label in reading[bucket]:
                base = label.split(":")[0]
                if base not in labels:
                    labels.append(base)
        for base in labels:
            total, sources = 0, []
            for name, reading in zip(names, per):
                for value, label in reading[bucket]:
                    if label.split(":")[0] == base:
                        total += value
                        sources.append(name)
            if bucket == "commensurable":
                contributors[base] = tuple(sources)
            combined[bucket].append(
                (total, "%s (summed over %d of %d corpora)"
                        % (base, len(sources), len(reports))))

    reach = [reading["reach_epoch"] for reading in per
             if reading.get("reach_epoch") is not None]
    if reach:
        combined["reach_epoch"] = sum(reach)
    combined["ea_is_final_stage"] = all(
        reading.get("ea_is_final_stage") for reading in per)
    gaps = [reading["gap"] for reading in per if reading["gap"] is not None]
    if gaps:
        combined["gap"] = sum(gaps)
    for name, reading in zip(names, per):
        for why in reading["unreadable"]:
            combined["unreadable"].append("%s: %s" % (name, why))

    # THE ROLLUP DOES NOT INDEPENDENTLY CLAIM A MIGRATION DEFECT, and the
    # reason is arithmetic rather than caution. If every figure is contributed
    # by the SAME corpora, per-corpus agreement forces sum agreement: each
    # corpus contributes one value x_i to every label, so every sum is the same
    # sum of the same x_i. So a sum-level disagreement can arise ONLY from
    # unequal contributing sets -- which is not a fact about epochs at all.
    #
    # It was written the other way first, and that version FIRED, red, on two
    # corpora that were each internally consistent: corpus A carried a
    # by_class and corpus B did not, so 150+150+100 "disagreed". That is the
    # 562,422 error exactly -- comparing figures whose denominators differ --
    # arriving inside the instrument built to stop it.
    #
    # What survives is the guard and the forwarding: name the mismatch in the
    # contributing sets and draw no conclusion from it, and pass every
    # per-corpus finding up, unconditionally, so a real defect in one corpus
    # cannot be absorbed into a total.
    sets = set(contributors.values())
    if len(sets) > 1:
        combined["not_comparable"] = "; ".join(
            "%s from %s" % (base, ", ".join(src) or "(no corpus)")
            for base, src in sorted(contributors.items()))
    elif len(set(v for v, _label in combined["commensurable"])) > 1:
        # Same contributing set and the sums still differ: by the argument
        # above that is impossible unless this digest's own summing is broken,
        # so it is reported as a DIGEST defect, not as a migration one.
        combined["disagreement"] = (
            "the sums differ while every figure was contributed by the SAME "
            "corpora, which is arithmetically impossible if the per-corpus "
            "figures agree. THIS IS A DEFECT IN census_digest.py, not in the "
            "migration: %s"
            % ", ".join("%d (%s)" % (v, lab)
                        for v, lab in combined["commensurable"]))

    findings = _render_epoch_populations(
        combined, p, "ACROSS ALL %d CORPORA" % len(reports))
    # Forwarded UNCONDITIONALLY. A per-corpus disagreement that cancels in the
    # sum is still a disagreement, and summing is how the 4,563-document JH row
    # nearly hid.
    for name, reading in zip(names, per):
        if reading["disagreement"]:
            p("      *** %s: %s" % (name, reading["disagreement"]))
            p("      *** A corpus disagrees with ITSELF. The sums above cannot")
            p("      *** show this; read that corpus's own block.")
            findings.append("%s: %s" % (name, reading["disagreement"]))
    return findings


def render_post_passes(r, out, chain=None):
    """Render the batch post-pass reports, denominator (the pass list) first.

    SIX distinguishable states per pass now, and keeping them distinguishable
    is the entire job:

      unmeasured    the pass RAN -- the harness composes it -- and attaches no
                    report struct at all, so nothing about it can reach this
                    artifact. Counted and NAMED. It used to be omitted, which
                    made it print identically to a pass that does not exist.
      absent        the report does not carry the field -- the pass was not
                    wired into the run that produced it (or the report predates
                    the wiring). NOT rendered as zeros.
      pass_failed   the harness guard (did2.unittest.helpers.runBatchPass)
                    caught a throw. Rendered as a *** banner: the documents are
                    in pass-1 form and the run's other numbers describe a
                    migration that did not include this pass.
      ran == false  the pass returned early -- a non-V_eta target, or an empty
                    batch. A legitimate no-op, and a different fact from both
                    of the above.
      not_in_chain  the render table names it and no report-writing call site
                    composes it. Stale in the reassuring direction.
      otherwise     the counters.

    The expected set comes from `harness_pass_chain`, not from POST_PASSES --
    see the block above that function for why the two must not be the same
    list.
    """
    p = lambda s="": out.append(s)

    chain = chain or harness_pass_chain()
    exp = post_pass_expectations(chain)
    present = [e for e in exp
               if e["field"] and isinstance(r.get(e["field"]), dict)]
    unmeasured = [e for e in exp if e["state"] == "unmeasured"]
    p("  batch post-passes: %d expected%s, %d carry a report here, "
      "%d UNMEASURED BY CONSTRUCTION"
      % (len(exp), "" if chain["derived"] else " (NOT DERIVED -- render-table "
         "floor)", len(present), len(unmeasured)))
    if unmeasured:
        p("      *** the %d unmeasured: %s"
          % (len(unmeasured),
             ", ".join("did2.convert.%s" % e["fn"] for e in unmeasured)))

    for e in exp:
        name, fn, rows = e["field"], "did2.convert.%s" % e["fn"], e["rows"]
        if e["state"] == "unmeasured":
            p("      %-22s RAN, MEASURED BY NOTHING -- %s attaches no report"
              % (e["fn"], fn))
            p("      %-22s struct to `result`, so this artifact carries no"
              % "")
            p("      %-22s counter, no denominator and no failure of its work."
              % "")
            continue
        if e["state"] == "unrendered":
            rep = r.get(name)
            p("      %-22s result.%s IS CARRIED and this digest has NO ROWS"
              % (e["fn"], name))
            p("      %-22s for it (%d key(s) unread in the artifact)"
              % ("", len(rep) if isinstance(rep, dict) else 0))
            continue
        if e["state"] == "not_in_chain":
            p("      %-22s *** IN THIS DIGEST'S RENDER TABLE AND COMPOSED BY NO"
              % name)
            p("      %-22s *** report-writing call site (%s). Rendering it"
              % ("", fn))
            p("      %-22s *** below would read as coverage of a pass that"
              % "")
            p("      %-22s *** does not run." % "")
            continue
        if e.get("field_mismatch"):
            p("      %-22s *** the harness attaches this pass's report to"
              % name)
            p("      %-22s *** result.%s; this table reads result.%s."
              % ("", chain["fields"].get(e["fn"]), name))
        rep = r.get(name)
        if rep is None:
            p("      %-22s NOT IN THIS REPORT -- the pass was not wired into"
              % name)
            p("      %-22s the run that produced it (%s)" % ("", fn))
            continue
        if not isinstance(rep, dict):
            p("      %-22s MALFORMED (%r)" % (name, type(rep).__name__))
            continue
        failed = rep.get("pass_failed")
        if failed:
            p("      %-22s *** FAILED: %s" % (name, failed))
            p("      %-22s *** identifier: %s"
              % ("", rep.get("pass_failed_identifier", "?")))
            p("      %-22s *** its documents are in PASS-1 FORM. Every other"
              % "")
            p("      %-22s *** number in this report describes a migration"
              % "")
            p("      %-22s *** that did NOT include %s." % ("", fn))
            continue
        if rep.get("ran") is False:
            p("      %-22s did not run (non-V_eta target, or an empty batch)"
              % name)
            continue
        p("      %-22s %s" % (name, fn))
        for key, label in rows:
            if key in rep:
                p("          %10s  %s" % (rep[key], label))
            else:
                # A counter the report does not carry is NOT printed as 0.
                p("          %10s  %s" % ("(absent)", label))
        # THE DELETION GATE, stated in the digest rather than left to be
        # re-derived. The six retiring reference classes may leave V_eta only
        # when refused_total is 0 AND no session_*_reference survives in
        # by_class -- deleting a class whose documents still exist is the
        # epochfiles_ingested regression, which cost 2,484 quarantines.
        # The two passes that report an `epoch` figure say which batch they
        # counted, AT the figure. See _render_post_pass_epoch_population.
        if name in ("epoch_mint", "valid_interval_decompose"):
            _render_post_pass_epoch_population(
                name, _int_or_none(rep.get("documents_inspected")), p)
        if name == "openminds_citations":
            _render_openminds_citations_reading(rep, p)
        if name == "response_parameters_fold":
            _render_response_parameters_reading(rep, p)
        if name == "lawn_plate_subjects":
            _render_lawn_plate_reading(rep, p)
        if name == "session_anchor_fold":
            _render_bounded_extent_reading(rep, p)
            survivors = 0
            by_class = r.get("by_class") or {}
            for cls in ("session_relative_reference", "session_bounded_reference"):
                try:
                    survivors += int(by_class.get(cls) or 0)
                except (TypeError, ValueError):
                    pass
            refused = rep.get("refused_total")
            p("          deletion gate: refused_total=%s, surviving "
              "session_*_reference in by_class=%s" % (refused, survivors))
            if refused == 0 and survivors == 0 and rep.get("anchors_seen"):
                p("          -> BOTH HALVES MET for this corpus. The corpora "
                  "are a SAMPLE, so this is")
                p("             one corpus's evidence, not authorisation to "
                  "delete the classes.")


def _reading_denominator(rep, key, label, p, when_absent, when_zero):
    """Print a reading block's denominator FIRST, in the three states it has.

    THE THREE STATES, and the first two both leave every counter in the block
    reading `0`, which is why each has to be NAMED rather than left to the
    reader. This is the same shape `_render_bounded_extent_reading` established
    and the wording is deliberately reused rather than reinvented:

      the counter is ABSENT   the report predates it. UNMEASURED, not zero.
      the counter is 0        the block is VACUOUS: nothing reached the thing
                              being counted. 'The rule could not fire', not
                              'nothing was wrong'.
      the counter is > 0      the numbers mean what they say.

    Returns the int, or None when it is absent or unreadable.
    """
    if key not in rep:
        p("          *** `%s` IS NOT IN THIS REPORT." % key)
        for line in when_absent:
            p("          *** %s" % line)
        p("          *** The quantity is UNMEASURED here. It is not zero.")
        return None
    value = _int_or_none(rep.get(key))
    if value is None:
        p("          *** `%s` is not a number, so the rows above cannot be"
          % key)
        p("          *** read. Treat this block as UNMEASURED.")
        return None
    p("          DENOMINATOR: %d %s" % (value, label))
    if value == 0:
        for line in when_zero:
            p("          *** %s" % line)
    return value


def _render_openminds_citations_reading(rep, p):
    """Say out loud how the openMINDS citation counters should be read.

    Every sentence here is derived from resolveOpenmindsCitations.m and its
    tests. Where the source did not settle a question, the block says so
    rather than filling the slot.
    """
    p("          THE CITATION ASSEMBLY -- the reading of the rows above")
    seen = _reading_denominator(
        rep, "openminds_documents_seen",
        "`openminds` document(s) in the migrated batch", p,
        when_absent=[
            "The pass landed 2026-08-11, so a report from before then carries",
            "no counter of any kind for it.",
        ],
        when_zero=[
            "This corpus holds no openMINDS graph store, so there was nothing",
            "to assemble and EVERY counter above is VACUOUS. That is a fact",
            "about the SAMPLE: the pass's own header records corpus run",
            "31441923369 as 1 graph-without-editor, 1 editor-without-graph and",
            "4 NEITHER. It is not evidence the assembly works or does not.",
            "The METADATA TIER section above counts the same class from the v1",
            "SOURCE census and is the place to look when this is 0.",
        ])
    if not seen:
        return

    # TWO SUMS THAT HOLD BY CONSTRUCTION. Checked rather than asserted in a
    # comment, because a counter that stops moving is exactly how a pass goes
    # quiet while still printing numbers.
    comps = _int_or_none(rep.get("openminds_components_seen"))
    planned = _int_or_none(rep.get("components_planned"))
    noroot = _int_or_none(rep.get("components_without_dataset_version"))
    consumed = _int_or_none(rep.get("components_consumed"))
    withheld = _int_or_none(rep.get("components_withheld"))
    reverted = _int_or_none(rep.get("components_reverted_on_validation"))
    if None not in (comps, planned, noroot) and comps != planned + noroot:
        p("          *** components_seen (%d) != planned (%d) + no-root (%d)."
          % (comps, planned, noroot))
        p("          *** Every component takes exactly one of those exits, so")
        p("          *** this is a counter that stopped being incremented.")
    if None not in (planned, consumed, withheld, reverted) \
            and planned != consumed + withheld + reverted:
        p("          *** planned (%d) != consumed (%d) + withheld (%d) +"
          % (planned, consumed, withheld))
        p("          *** reverted (%d). Same reading: a defect in the pass's"
          % reverted)
        p("          *** bookkeeping, not a fact about this corpus.")

    if withheld:
        p("          *** %d component(s) WITHHELD by the orphan guard. Nothing"
          % withheld)
        p("          *** was consumed and nothing emitted for them: the corpus")
        p("          *** is exactly as pass 1 left it, which is the state it is")
        p("          *** green in. This is a FINDING, not a passthrough")
        p("          *** statistic -- a SURVIVING document references something")
        p("          *** the plan wanted to consume, and consuming it would")
        p("          *** have dangled that document's `openminds_#` edge.")
        reasons = aslist(rep.get("withheld_reasons"))
        if reasons:
            for reason in reasons:
                p("          ***   %s" % reason)
        else:
            p("          ***   (no reason strings in this report -- the pass")
            p("          ***    records one per withheld component, so their")
            p("          ***    absence here is itself worth chasing.)")
    if reverted:
        p("          *** %d component(s) REVERTED ON VALIDATION. A body this"
          % reverted)
        p("          *** pass BUILT failed to validate, so the whole component")
        p("          *** was rolled back -- nothing appended, nothing consumed.")
        p("          *** That is a defect in the build, not in the corpus, and")
        p("          *** `bodies_quarantined` counts the failing bodies.")

    datasets = _int_or_none(rep.get("datasets_emitted"))
    if None not in (datasets, consumed) and datasets != consumed:
        p("          *** datasets_emitted (%d) != components_consumed (%d)."
          % (datasets, consumed))
        p("          *** buildComponent emits exactly one `dataset` per")
        p("          *** consumed component, so these must agree.")

    persons = _int_or_none(rep.get("persons_emitted"))
    p_pres = _int_or_none(rep.get("persons_id_preserved"))
    if None not in (persons, p_pres) and persons != p_pres:
        p("          *** persons_emitted (%d) != persons_id_preserved (%d),"
          % (persons, p_pres))
        p("          *** which cannot happen as the pass is written: a Person")
        p("          *** with no readable base.id is skipped BEFORE either")
        p("          *** counter moves. Read this as the pass having changed,")
        p("          *** and this block's account of it as stale.")
    orgs = _int_or_none(rep.get("organizations_emitted"))
    o_pres = _int_or_none(rep.get("organizations_id_preserved"))
    if None not in (orgs, o_pres) and orgs > o_pres:
        p("          %8d  organization(s) got a FRESH id rather than the"
          % (orgs - o_pres))
        p("                    source document's -- that is what an openMINDS")
        p("                    Organization with no readable base.id produces.")
        p("                    Not a loss; the entity is still emitted and")
        p("                    every relation points at the id it was given.")

    wr = _int_or_none(rep.get("web_resources_emitted"))
    iri = _int_or_none(rep.get("web_resources_from_iri"))
    doi = _int_or_none(rep.get("web_resources_from_doi"))
    if None not in (wr, iri, doi) and iri + doi > wr:
        p("          *** %d fullDocumentation reference(s) were CLASSIFIED"
          % (iri + doi - wr))
        p("          *** (IRI or DOI) and then not emitted, which happens only")
        p("          *** when the source document has no readable base.id. No")
        p("          *** counter of its own names that case; the difference")
        p("          *** between these rows is the only place it shows.")

    consumed_docs = _int_or_none(rep.get("documents_consumed"))
    appended = _int_or_none(rep.get("documents_appended"))
    if None not in (consumed_docs, appended):
        p("          %8d  source document(s) consumed -> %d appended. A LARGE"
          % (consumed_docs, appended))
        p("                    DROP HERE IS EXPECTED AND IS NOT LOSS: one")
        p("                    `person` is assembled from five openMINDS")
        p("                    documents (Person + Affiliation + Organization")
        p("                    + ORCID + ContactInformation).")

    lossy = ("affiliations_beyond_first_dropped",
             "contribution_documents_consumed_without_a_home",
             "data_type_documents_consumed_without_a_home",
             "technique_documents_consumed_without_a_home")
    if all(k in rep for k in lossy):
        total = sum(_int_or_none(rep.get(k)) or 0 for k in lossy)
        p("          %8d  thing(s) consumed with NOWHERE TO PUT THEM (the four"
          % total)
        p("                    LOSSY rows summed). Author ORDER survives as")
        p("                    `sequence`; the ROLE does not, because `person`")
        p("                    has no role field. This is real loss with a")
        p("                    number on it, and `affiliations_beyond_first_")
        p("                    dropped` is the size of an OPEN team question,")
        p("                    not a defect.")


def _render_response_parameters_reading(rep, p):
    """Say out loud how the #61 resolver's counters should be read.

    THE PAIR IS THE POINT. `leaves_seen: 0` alone is three different findings
    and the pass was built so that the report separates them; a block that
    printed the rows and left the pairing to the reader would put them back
    together.
    """
    p("          THE STIMULUS-RESPONSE FOLD -- the reading of the rows above")
    leaves = _reading_denominator(
        rep, "leaves_seen",
        "harmonic_component_calculation leaf/leaves in the batch", p,
        when_absent=[
            "The pass landed 2026-08-11, so a report from before then carries",
            "no counter of any kind for it.",
        ],
        when_zero=[
            "No leaf reached the fold, so every INLINE and REFUSAL counter",
            "above is VACUOUS. Read `suppressed_responses_seen` next -- it is",
            "measured independently of the leaves and is NOT vacuous.",
        ])
    if leaves is None:
        return

    with_edge = _int_or_none(rep.get("leaves_with_edge"))
    without = _int_or_none(rep.get("leaves_without_edge"))
    if None not in (with_edge, without) and with_edge + without != leaves:
        p("          *** leaves_with_edge (%d) + leaves_without_edge (%d) !="
          % (with_edge, without))
        p("          *** leaves_seen (%d). Every leaf takes one of those two"
          % leaves)
        p("          *** exits, so this is a counter that stopped moving.")

    suppressed = _int_or_none(rep.get("suppressed_responses_seen"))
    if leaves == 0:
        if suppressed is None:
            p("          *** `suppressed_responses_seen` is absent, so the ONE")
            p("          *** reading that distinguishes 'this corpus has no")
            p("          *** responses' from 'pass 1 suppressed every fold' is")
            p("          *** UNMEASURED. A bare 0 here means neither.")
        elif suppressed > 0:
            p("          *** BLOCKED UPSTREAM, AND THIS IS THE EXPECTED READING")
            p("          *** TODAY. %d v1 `stimulus_response_scalar` document(s)"
              % suppressed)
            p("          *** passed through UNFOLDED because +migrators_j/")
            p("          *** stimulus_response_scalar.m's epoch gate suppresses")
            p("          *** the fold whenever the v1 body has an")
            p("          *** `element_epochid` string and jEpochDocId answers ''")
            p("          *** -- which is every did_v1 document by construction.")
            p("          *** #60 stamping the epoch_id edge is what opens it.")
            p("          *** This is NOT 'nothing to do'.")
        else:
            p("          *** 0 leaves beside 0 suppressed response(s): this")
            p("          *** corpus holds no stimulus responses at all. A")
            p("          *** different fact from the blocked-upstream reading,")
            p("          *** and the two rows exist to keep them apart.")
    else:
        inlined = _int_or_none(rep.get("inlined"))
        refused = _int_or_none(rep.get("refused_total"))
        quar = _int_or_none(rep.get("fold_quarantined"))
        if inlined == 0 and refused == 0:
            p("          *** %d leaf/leaves seen and NOTHING inlined or refused."
              % leaves)
            p("          *** That is a real defect in resolveResponseParameters,")
            p("          *** not a corpus fact: a leaf either folds or is")
            p("          *** refused with a reason.")
        if None not in (with_edge, inlined, refused, quar):
            residual = with_edge - inlined - refused - quar
            if residual:
                p("          *** %d leaf/leaves with an edge neither inlined,"
                  % residual)
                p("          *** refused nor quarantined. The pass matches its")
                p("          *** rebuilt bodies back by base.id, so a residual")
                p("          *** here means an id did not come back -- unaccounted")
                p("          *** for, and it should be 0.")

    mismatch = _int_or_none(rep.get("refused_harmonic_mismatch"))
    if mismatch:
        p("          *** %d refusal(s) for freq_response ~= value.harmonic. THIS"
          % mismatch)
        p("          *** IS THE ALARMING ROW OF THE BLOCK. The migrator derives")
        p("          *** the leaf's harmonic from the same field this pass then")
        p("          *** checks, so a disagreement means that writer-derived")
        p("          *** identity has broken somewhere. The fold refuses rather")
        p("          *** than picking a winner, so nothing is lost -- but the")
        p("          *** cause is worth finding before it is read as noise.")

    # THE DELETION GATE. Rendered whether or not anything folded, because it is
    # measured over the whole batch and is the number a deletion decision would
    # be quoted from.
    seen = _int_or_none(rep.get("parameters_documents_seen"))
    ref_after = _int_or_none(rep.get("parameters_documents_referenced_after"))
    unref = _int_or_none(rep.get("parameters_documents_unreferenced_after"))
    deleted = _int_or_none(rep.get("parameters_documents_deleted"))
    if seen is None:
        p("          *** the deletion-gate denominator is absent, so the")
        p("          *** referenced/unreferenced rows cannot be read.")
        return
    p("          DELETION GATE: %d parameters document(s) in this batch" % seen)
    if seen == 0:
        p("          *** 0 seen -- the referenced/unreferenced rows above are")
        p("          *** VACUOUS. Nothing here bears on whether the class may")
        p("          *** be retired.")
    elif None not in (ref_after, unref) and ref_after + unref != seen:
        p("          *** referenced (%d) + unreferenced (%d) != seen (%d). The"
          % (ref_after, unref, seen))
        p("          *** walk classifies every parameters document exactly")
        p("          *** once, so this is a counter that stopped moving.")
    elif unref is not None:
        p("          %8d  unreferenced after the fold. This is EVIDENCE for the"
          % unref)
        p("                    verify-before-delete gate and NEVER authorisation:")
        p("                    the corpora are a SAMPLE, and it is computed by")
        p("                    walking every edge of every document rather than")
        p("                    by assuming this pass removed the only referent.")
    if deleted:
        p("          *** parameters_documents_deleted is %d and MUST be 0. This"
          % deleted)
        p("          *** pass deletes nothing by construction; a non-zero means")
        p("          *** it has pre-empted a decision that is the team's.")


def _collision_split_reading(rep, collisions, pad, p):
    """The within/across/unclassifiable split of a non-zero collision count.

    WHY IT IS PRINTED SEPARATELY FROM THE NUMBER ABOVE. Corpus run 31522068566
    reported 6,414 handle collisions and this file declared the team's
    (experiment, plate, patch) uniqueness directive "refuted on real data". The
    team's reply was "Is it not within-session unique? That's what matters."
    The counter said `..._within_batch` -- BATCH, not session -- and a batch
    spans both Haley sessions, so the claim of refutation was one the
    instrument could not support. This block prints the cut that answers it, or
    says the cut is not in the report.

    THE THREE ARE PRINTED WHOLE, NEVER AS TWO PLUS A SUBTRACTION, and their sum
    is checked against the batch total here rather than assumed: a mismatch
    means a counter stopped moving, which is a defect in the pass and not a
    fact about the corpus.
    """
    within = _int_or_none(rep.get("local_identifier_collisions_within_session"))
    across = _int_or_none(
        rep.get("local_identifier_collisions_across_sessions_only"))
    unclas = _int_or_none(
        rep.get("local_identifier_collisions_unclassifiable_no_session_id"))
    if within is None or across is None or unclas is None:
        p("%s*** THE WITHIN/ACROSS SPLIT IS NOT IN THIS REPORT, so whether" % pad)
        p("%s*** the directive is refuted is UNMEASURED here -- not clean," % pad)
        p("%s*** and not refuted either. A collision between two SESSIONS" % pad)
        p("%s*** does not bear on it; one inside a session does." % pad)
        return
    p("%s*** OF THOSE: %d WITHIN one base.session_id, %d ACROSS sessions"
      % (pad, within, across))
    p("%s*** only, %d UNCLASSIFIABLE (an occurrence with no session id)."
      % (pad, unclas))
    if within + across + unclas != collisions:
        p("%s*** AND THEY DO NOT SUM TO %d. That is a counter that stopped"
          % (pad, collisions))
        p("%s*** moving, not a corpus fact -- the three are a partition by" % pad)
        p("%s*** construction. Do not read either number until it is fixed." % pad)
        return
    if within:
        p("%s*** THE %d WITHIN-SESSION ONE(S) ARE WHAT THE DIRECTIVE IS"
          % (pad, within))
        p("%s*** ABOUT. Two subjects in one session share a handle, and no" % pad)
        p("%s*** session scoping can explain them apart." % pad)
    else:
        p("%s*** NONE OF THEM IS WITHIN A SESSION. The directive holds where" % pad)
        p("%s*** it was meant to: every index in the pass is keyed by" % pad)
        p("%s*** `base.session_id`, and so is NDI's own subject-by-handle" % pad)
        p("%s*** resolver, which reaches the database through" % pad)
        p("%s*** ndi.session.database_search. Not a refutation." % pad)
    if unclas:
        p("%s*** THE %d UNCLASSIFIABLE ONE(S) ARE NOT A THIRD VERDICT -- they"
          % (pad, unclas))
        p("%s*** are collisions nobody can place, and both mint sites are" % pad)
        p("%s*** supposed to refuse a session-less row before forming a" % pad)
        p("%s*** handle. A non-zero here means one of them stopped." % pad)


def _render_lawn_plate_reading(rep, p):
    """Say out loud how the lawn/plate subject counters should be read."""
    p("          THE TWO-TIER SUBJECTS -- the reading of the rows above")
    rows = _reading_denominator(
        rep, "ontology_table_rows_seen",
        "ontology_table_row document(s) in the batch", p,
        when_absent=[
            "The pass landed 2026-08-11, so a report from before then carries",
            "no counter of any kind for it.",
        ],
        when_zero=[
            "This corpus holds no ontology_table_row at all, so every counter",
            "above is VACUOUS -- including the spelling canary, which cannot",
            "fire without a recognised table to anchor it.",
        ])
    if not rows:
        return

    plate = _int_or_none(rep.get("plate_rows_seen")) or 0
    image = _int_or_none(rep.get("image_rows_seen")) or 0
    lawn = _int_or_none(rep.get("lawn_rows_seen")) or 0
    unclassified = _int_or_none(rep.get("unclassified_rows_in_those_sessions"))
    recognised = plate + image + lawn
    p("          %8d  of them recognised as a plate/image/lawn table"
      % recognised)
    if recognised == 0:
        p("          *** NOTHING RECOGNISED, AND THIS READING IS AMBIGUOUS BY")
        p("          *** CONSTRUCTION -- SAY SO RATHER THAN CALLING IT CLEAN.")
        p("          *** The six tables are written by ONE converter (NDI")
        p("          *** origin/main +setup/+conv/+haley/doImport.m), so a")
        p("          *** corpus not built by it recognises none, and that is")
        p("          *** the benign reading. BUT the spelling canary counts")
        p("          *** unclassified rows only in SESSIONS WHERE SOMETHING WAS")
        p("          *** RECOGNISED, so a column-token rule that is wrong")
        p("          *** EVERYWHERE forces it to 0 too and produces this exact")
        p("          *** output. The canary detects a PARTIALLY wrong rule; it")
        p("          *** cannot detect a wholly wrong one. Nothing in this")
        p("          *** report separates those two -- do not read this block")
        p("          *** as evidence the token rule works.")
        return
    if unclassified is None:
        p("          *** the spelling canary counter is absent, so whether the")
        p("          *** column-token rule matched everything it should have is")
        p("          *** UNMEASURED in this report.")
    elif unclassified > recognised:
        p("          *** SPELLING CANARY: %d unclassified row(s) beside %d"
          % (unclassified, recognised))
        p("          *** recognised, in the same sessions. That is what a WRONG")
        p("          *** column-token rule looks like -- the pass matches")
        p("          *** columns by a normalised term token because")
        p("          *** ndi.ontology.lookup could not be evaluated where it was")
        p("          *** written. Chase the tokens before reading any tier row")
        p("          *** below as a corpus fact.")
    else:
        p("          %8d  unclassified row(s) in the same sessions (the"
          % unclassified)
        p("                    spelling canary; small beside %d recognised)"
          % recognised)

    # THE PER-TIER PARTITIONS. Each row takes exactly one of three exits.
    for tier, seen_key, parts in (
            ("plate", "plate_rows_seen",
             ("plate_rows_with_measurements",
              "plate_rows_with_values_but_none_emittable",
              "plate_rows_with_no_values_at_all")),
            ("lawn", "lawn_rows_seen",
             ("lawn_rows_with_measurements",
              "lawn_rows_with_values_but_none_emittable",
              "lawn_rows_with_no_values_at_all"))):
        seen = _int_or_none(rep.get(seen_key))
        if seen is None or any(k not in rep for k in parts):
            continue
        total = sum(_int_or_none(rep.get(k)) or 0 for k in parts)
        if total != seen:
            p("          *** the three %s-row states sum to %d, not %s_rows_seen"
              % (tier, total, tier))
            p("          *** (%d). Every recognised row takes exactly one of"
              % seen)
            p("          *** them, so this is a counter that stopped moving.")

    withheld_plate = _int_or_none(rep.get("withheld_plate_tier_not_minted")) or 0
    withheld_lawn = _int_or_none(rep.get("withheld_lawn_tier_not_minted")) or 0
    if withheld_plate or withheld_lawn:
        p("          %8d  member_of edge(s) WITHHELD (%d plate tier, %d lawn"
          % (withheld_plate + withheld_lawn, withheld_plate, withheld_lawn))
        p("                    tier). THIS IS NOT A LOSS AND NOT A REFUSAL. The")
        p("                    team's refinement makes a tier CONDITIONAL ON THE")
        p("                    DATA -- \"it's only necessary to make all")
        p("                    subjects if we take measurements of both\" -- so")
        p("                    a tier with nothing measured about it warrants no")
        p("                    subject, and an edge needs BOTH ends.")

    collisions = _int_or_none(rep.get("local_identifier_collisions_within_batch"))
    if collisions:
        p("          *** %d HANDLE COLLISION(S). The team's directive asserts"
          % collisions)
        p("          *** the (experiment, plate, patch) combo is unique, and")
        p("          *** this is that premise measured on real data rather than")
        p("          *** assumed. A non-zero is a fact the TEAM needs; the pass")
        p("          *** builds the identifier exactly as directed and does not")
        p("          *** choose another scheme on its own.")
        _collision_split_reading(rep, collisions, "          ", p)
    elif collisions == 0:
        p("          %8d  handle collision(s) -- the directive's uniqueness"
          % 0)
        p("                    premise holds on THIS batch. The corpora are a")
        p("                    SAMPLE.")

    quar = [(k, _int_or_none(rep.get(k)) or 0) for k in
            ("subjects_quarantined", "statements_quarantined",
             "celegans_patch_relabel_quarantined") if k in rep]
    if any(v for _k, v in quar):
        p("          *** %s. A QUARANTINED SUBJECT TAKES ITS"
          % ", ".join("%s=%d" % (k, v) for k, v in quar))
        p("          *** OBSERVATIONS AND ITS member_of WITH IT: the pass emits")
        p("          *** nothing that points at a body which did not survive")
        p("          *** validation, so an observation count that looks short is")
        p("          *** explained here rather than upstream.")

    left = _int_or_none(rep.get("source_rows_left_in_place"))
    if left is not None:
        p("          %8d  source row(s) LEFT IN PLACE. This equals the three"
          % left)
        p("                    recognised-row counts by construction; it is the")
        p("                    verify-before-delete denominator, not a second")
        p("                    measurement. The typed measures are stored TWICE")
        p("                    -- once as an observation, once in the source")
        p("                    row's `data` block -- until a separate step")
        p("                    consumes the rows.")

    p("          NOTE `refused_total` EXCLUDES the C. elegans relabel rows: it")
    p("          sums the eleven E. coli refusals only. The relabel is a")
    p("          DIFFERENT POPULATION (patch subjects pass 1 already minted)")
    p("          and its 'left as a pair' outcomes are not failures -- that")
    p("          table never had an expID column to read.")


def _render_bounded_extent_reading(rep, p):
    """Say out loud how the bounded-extent counters above should be read.

    THREE DISTINCT STATES, and the first two both print `0` for every extent
    counter, which is why they have to be named rather than left to the reader:

      the counters are ABSENT     the report predates them (they landed
                                  2026-08-11). The quantity is UNMEASURED in
                                  this run, and a run whose numbers are quoted
                                  as evidence must say so itself.
      examined == 0               they exist and nothing reached them: this
                                  corpus has no bounded anchor that survived the
                                  session/relation gates. VACUOUS, not clean.
      examined > 0                the numbers mean what they say.

    THE REASON THIS BLOCK IS WORTH ITS LINES. These counters exist because a
    `session_bounded_reference` whose extent could not be read used to fold with
    its window discarded and no counter moving -- 20,411 documents did, and the
    corpus rollup that covered them reported `0 REFUSED` and was correct. An
    instrument added to catch a silent zero, printed in a way that produces its
    own indistinguishable zero, would be the same defect wearing the fix.
    """
    if "bounded_extents_examined" not in rep:
        p("          *** the bounded-extent counters are NOT IN THIS REPORT.")
        p("          *** It predates them (2026-08-11), so whether any window")
        p("          *** was dropped here is UNMEASURED -- it is not zero.")
        return
    try:
        examined = int(rep.get("bounded_extents_examined") or 0)
    except (TypeError, ValueError):
        p("          *** bounded_extents_examined is not a number; the extent")
        p("          *** counters above cannot be read.")
        return
    if examined == 0:
        p("          *** 0 bounded extents were EXAMINED, so every extent")
        p("          *** counter above is vacuous. This is 'nothing reached")
        p("          *** the extent read', NOT 'no window was dropped'.")
        return
    carried = _int_or_none(rep.get("bounded_window_carried"))
    with_start = _int_or_none(rep.get("bounded_with_start_field"))
    if carried is not None and with_start is not None and with_start > carried:
        # The shape of the original defect, stated as a comparison the reader
        # would otherwise have to make by eye: more bodies had a `start` field
        # than ended up with a window.
        p("          *** %d bod(ies) carried a `start` field and only %d kept a"
          % (with_start, carried))
        p("          *** window. The difference is refusals and half-windows")
        p("          *** above -- read them before quoting anchors_folded.")


def _int_or_none(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


ical = "moved_vintage_bodies_classified"

# The `ndi_document` block's four shapes, read from NDI origin/main history
# (`git log --all --follow -- ndi_common/database_documents/ndi_document.json`).
# (report key, label). ORDER IS CHRONOLOGICAL, because the reading is "how far
# back does this corpus go" and a sorted-by-size list destroys that.
LEGACY_VINTAGES = [
    ("moved_vintage_2019_05_unique_reference",
     "2019-05 experiment_unique_reference/document_unique_reference"
     "   NO identity survives"),
    ("moved_vintage_2019_11_experiment_document_id",
     "2019-11 experiment_id/document_id"
     "                              NO identity survives"),
    ("moved_vintage_2019_12_experiment_id_and_id",
     "2019-12 experiment_id/id"
     "                                       `id` lands, session_id does NOT"),
    ("moved_vintage_2020_05_session_id_and_id",
     "2020-05 session_id/id"
     "                             SOUND -- both identity fields land"),
    ("moved_vintage_unknown",
     "UNKNOWN field set -- NOT rounded to the nearest vintage"),
    ("moved_vintage_unreadable_block",
     "UNREADABLE block (not a scalar struct; no field set to read)"),
]


def render_legacy_vintages(L, p):
    """The vintage breakdown of the wholesale-move arm, denominator first.

    WHY THIS EXISTS SEPARATELY FROM THE ARM COUNT. `moved_wholesale_no_base` on
    its own cannot say whether anything broke. The `ndi_document` block had FOUR
    shapes, and the 2020-05-19 one -- which ran until base.json replaced it on
    2023-04-13, nearly three years, the longest-lived of the four -- already
    spells `id`/`session_id`, so the wholesale move lands identity CORRECTLY and
    only `type` + `database_version` arrive undeclared. The two 2019 shapes land
    with no usable identity at all. One number mixes a sound migration with a
    broken one.

    THE SIX PARTITION THE ARM by construction (did2.convert.v1_to_v2 raises
    did2:convert:legacyVintagePartitionBroken otherwise), so this prints the sum
    against the denominator and SAYS SO when they disagree rather than rendering
    a breakdown that does not add up. A report predating the counters is named
    UNMEASURED, never summed as zero.

    READ `unknown` FIRST WHEN IT IS NON-ZERO. It means a real block carried a
    field set the four-vintage account does not predict -- which is the way this
    measurement is most likely to be wrong, and it is deliberately not rounded
    into a neighbouring bucket.
    """
    if not any(k in L for k, _ in LEGACY_VINTAGES) and ical not in L:
        p("      *** VINTAGE BREAKDOWN: UNMEASURED -- this report predates the")
        p("      *** classifier. NOT the same as 'no legacy blocks'; the arm")
        p("      *** count above stands, its composition is simply unknown.")
        return
    den = _int_or_none(L.get(ical))
    p("      vintage of the %s moved block(s), classified on the FIELD SET:"
      % ("?" if den is None else den))
    total = 0
    for key, label in LEGACY_VINTAGES:
        v = _int_or_none(L.get(key))
        if v is None:
            p("          %8s  %s" % ("--", label))
        else:
            total += v
            p("          %8d  %s" % (v, label))
    if den is not None and total != den:
        p("      *** THE BUCKETS DO NOT PARTITION THE ARM: %d summed, %d "
          "classified." % (total, den))
        p("      *** A body reached no bucket. Do not read the breakdown above")
        p("      *** as a composition -- it is missing documents.")
    arm = _int_or_none(L.get("moved_wholesale_no_base"))
    if den is not None and arm is not None and den != arm:
        p("      *** %d body(ies) took the wholesale-move arm and %d reached "
          "the classifier." % (arm, den))


def render_legacy_ndi_document(r, out):
    """Render the legacy identity-block counter (`ndi_document` -> `base`).

    THE ZERO IS THE DELIVERABLE HERE, so this block prints whenever the key is
    present, all-zero included. did_v1 documents written before 2023 carried
    document identity under `ndi_document`, not `base`, and the six fields of
    the 2019 block are not the four of `base`:

        ndi_document.json, added 4f1a2b801 (2019-05-05)
          experiment_unique_reference, document_unique_reference,
          name, type, datestamp, database_version              SIX
        base.json, added 9783809c2 (2023-04-13), NDI origin/main today
          id, session_id, name, datestamp                      FOUR

    did2.convert.universalRenames handles that difference by MOVING THE BLOCK
    WHOLESALE -- it renames the container and does nothing to the contents, on
    the one code path that exists precisely because the contents differ. A
    genuine 2019 body therefore lands in `base` with four undeclared fields and
    both required identity fields missing, and quarantines.

    THREE READING INSTRUCTIONS, and the first two are the ones that matter:

    (1) THE DENOMINATOR IS `bodies_reaching_universal_renames`, NOT `total`.
        The dispatcher's idempotency short-circuit skips the rename pass for a
        body already at the target version, so a re-run over migrated bodies
        reports every arm at 0 having inspected nothing. `bodies_total`,
        `bodies_skipped_already_target` and `bodies_unreached` close the gap
        and sum to `bodies_total` by construction.
    (2) ALL-ZERO IS THE EXPECTED READING AND IT MEANS "NOT IN THIS SAMPLE".
        Corpus run 31464483119 inspected 633,432 documents across 6 corpora
        and quarantined 0, so no pre-`base` document is in any corpus we hold.
        That is a fact about the sample and NOT evidence none exist -- a
        2019-era NDI database is exactly what this migration is for. The size
        of the defect is UNMEASURED, not zero.
    (3) `moved_wholesale_no_base` MEANS NOTHING WITHOUT THE `moved_carrying_*`
        LINE UNDER IT. A 2020-vintage `ndi_document` block already spells
        `id`/`session_id` and moves soundly; only a block carrying
        `experiment_unique_reference` / `document_unique_reference` / `type` /
        `database_version` is the 2019 shape the defect is about.

    The two arms are NEVER SUMMED. `discarded_ndi_document_base_present` is a
    stale block dropped beside a good `base`; `moved_wholesale_no_base` is a
    block that IS the document's only identity. Different facts.
    """
    p = lambda s="": out.append(s)
    L = r.get("legacy_ndi_document")
    if not L:
        return
    p("  legacy ndi_document block: %s bod(ies) reached universalRenames "
      "(of %s; %s already at target, %s never reached it)"
      % (L.get("bodies_reaching_universal_renames", "?"),
         L.get("bodies_total", "?"),
         L.get("bodies_skipped_already_target", "?"),
         L.get("bodies_unreached", "?")))
    if L.get("bodies_reaching_universal_renames") == 0:
        p("  *** 0 bodies reached the rename pass -- every count below is")
        p("  *** vacuous. This is what a re-run over already-migrated bodies")
        p("  *** looks like; it is NOT 'no legacy blocks found'.")
    p("      %8s  carried an `ndi_document` block"
      % L.get("ndi_document_block_seen", "?"))
    p("      %8s  MOVED WHOLESALE into `base` (no `base` present)  <-- the defect"
      % L.get("moved_wholesale_no_base", "?"))
    p("      %8s  discarded (`base` present and wins)"
      % L.get("discarded_ndi_document_base_present", "?"))
    if not L.get("moved_wholesale_no_base"):
        return
    p("      of the moved: %s missing required `id`, %s missing `session_id`"
      % (L.get("moved_missing_id", "?"), L.get("moved_missing_session_id", "?")))
    p("                    %s carrying %s field(s) `base` does not declare"
      % (L.get("moved_with_any_undeclared_field", "?"),
         L.get("moved_undeclared_field_instances", "?")))
    p("                    field names present: %s experiment_unique_reference, "
      "%s document_unique_reference, %s type, %s database_version"
      % (L.get("moved_carrying_experiment_unique_reference", "?"),
         L.get("moved_carrying_document_unique_reference", "?"),
         L.get("moved_carrying_type", "?"),
         L.get("moved_carrying_database_version", "?")))
    render_legacy_vintages(L, p)
    for key, label in (("moved_by_class", "moved wholesale"),
                       ("discarded_by_class", "discarded")):
        for k, v in sorted((L.get(key) or {}).items(), key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s (%s)" % (v, k, label))


# --- THE OTHER HALF OF THE GATE: ORPHAN depends_on EDGES ------------------
#
# THE CORPUS GATE IS STATED EVERYWHERE IN THIS PROJECT AS "0 quarantine + 0
# orphans" -- DID-schema/CLAUDE.md puts it in exactly those words. This digest
# has rendered the quarantine half since it was written and has NEVER rendered
# the orphan half, in any run. The last full census (run 31522068566, job
# 93917442013) prints `quarantined: 0  fragments: 0` and the string "orphan"
# appears in its output only inside prose and inside openMINDS's
# `components_withheld (orphan guard)` counter, which counts something else
# entirely. So every "0 quarantine + 0 orphans" ever quoted from a digest has
# quoted one measurement and one silence.
#
# THE NUMBER EXISTS AND IS NOT IN THE ARTIFACT THIS DIGEST READS.
# `did2.validate.references` returns `orphan_count`, `edges_examined`,
# `total_docs` and an `orphans` row per dangling edge;
# `runCorpusDiscovery` calls it and hard-asserts `orphan_count == 0`. But it
# calls it AFTER `writeCorpusReport` has already written the *-summary.json,
# and `writeCorpusReport` persists no orphan field at all -- so the figure
# reaches the runner's log and dies there. `testCorpusPRED` never calls
# `did2.validate.references` at any point, so the corpus we hard-gate on is not
# orphan-checked even in its log.
#
# THIS BLOCK THEREFORE PRINTS "ABSENT", LOUDLY, RATHER THAN NOT PRINTING. An
# instrument that omits a counter it cannot find is indistinguishable from one
# reporting a zero, which is the failure this whole file exists to remove.
#
# AN ORPHAN IS NOT AN EMPTY EDGE, and the two must never stand in for each
# other. `+did2/+validate/references.m:90` SKIPS an edge whose document_id is
# empty (`if isempty(documentId), continue;`) -- that is why `mustBeNonEmpty`
# on a `depends_on` is decorative, and why the empty-required-edge census above
# says nothing whatever about dangling references. One is "the edge is blank",
# the other is "the edge names a document that is not there".
#
# THE BLOCK IS FOUND BY SHAPE, NOT BY NAME. Nothing has been persisted yet, so
# no key name is settled; guessing one and reporting ABSENT when the guess
# missed would be `demo_ndi` again -- a query against a string the input has
# never contained, reported as a fact about the input. Any top-level object
# carrying `orphan_count` is rendered, whatever it is called, and the key's
# name is printed so the reader knows what was read.
ORPHAN_MARKER_FIELD = "orphan_count"

# The shape `did2.validate.references` actually returns. Rendered in this
# order: both denominators before the finding, per Rule 5.
ORPHAN_BLOCK_ROWS = [
    ("total_docs", "document(s) inspected  <- DENOMINATOR"),
    ("edges_examined", "NON-EMPTY depends_on edge(s) examined  <- DENOMINATOR"),
    ("orphan_count", "ORPHAN(S): edge names a document not in the batch"),
]


def _orphan_keys_by_name(r):
    """Top-level keys whose NAME mentions an orphan, for the absent message.

    Reported so "no such counter" and "a counter is here in a shape this
    digest does not render" are different output. Name-matching is used ONLY
    to describe an absence, never to decide that one exists.
    """
    if not isinstance(r, dict):
        return []
    return sorted(k for k in r if isinstance(k, str) and "orphan" in k.lower())


def orphan_block(r):
    """Find one report's reference-integrity block BY SHAPE. Absent is not 0."""
    if not isinstance(r, dict):
        return {"measured": False, "key": None,
                "why": "the report itself is malformed (%s)" % type(r).__name__}
    found = [(k, v) for k, v in sorted(r.items())
             if isinstance(v, dict) and ORPHAN_MARKER_FIELD in v]
    if len(found) > 1:
        return {"measured": False, "key": None,
                "why": "%d top-level key(s) carry `%s` (%s) and the digest "
                       "will not choose between them"
                       % (len(found), ORPHAN_MARKER_FIELD,
                          ", ".join(k for k, _v in found))}
    if found:
        key, block = found[0]
    elif ORPHAN_MARKER_FIELD in r:
        key, block = "<top level>", r
    else:
        return {"measured": False, "key": None, "absent": True,
                "named": _orphan_keys_by_name(r),
                "why": "no top-level object in this report carries `%s`"
                       % ORPHAN_MARKER_FIELD}
    n = block.get(ORPHAN_MARKER_FIELD)
    if not isinstance(n, int) or isinstance(n, bool):
        return {"measured": False, "key": key,
                "why": "`%s.%s` is not a number (%s)"
                       % (key, ORPHAN_MARKER_FIELD, type(n).__name__)}
    return {"measured": True, "key": key, "block": block, "orphans": n}


def _orphan_rows(block):
    """Aggregate the `orphans` array to (class.edge -> count), desc."""
    rows = {}
    for o in aslist(block.get("orphans")):
        if not isinstance(o, dict):
            continue
        rows["%s.%s" % (o.get("doc_class", "?"), o.get("edge_name", "?"))] = (
            rows.get("%s.%s" % (o.get("doc_class", "?"),
                                o.get("edge_name", "?")), 0) + 1)
    return rows


def _orphan_absent_note(p, indent, plural):
    """Say what is missing, why it is not a zero, and what would change it."""
    p("%s*** THIS IS NOT A ZERO, AND IT IS NOT A CLEAN RESULT. It is the" % indent)
    p("%s*** HALF OF THE GATE THAT WAS NEVER RENDERED. The gate this" % indent)
    p("%s*** project quotes is '0 quarantine + 0 orphans'; the quarantine" % indent)
    p("%s*** half is printed above, the orphan half has never appeared in" % indent)
    p("%s*** any digest output." % indent)
    p("%sWHERE THE NUMBER IS TODAY: `did2.validate.references` computes" % indent)
    p("%s`orphan_count` / `edges_examined` and `runCorpusDiscovery` asserts it" % indent)
    p("%s-- but it runs AFTER `writeCorpusReport` has written this file, and" % indent)
    p("%s`writeCorpusReport` persists no orphan field, so the figure reaches" % indent)
    p("%sthe runner's log and stops. `testCorpusPRED` never calls it at all." % indent)
    p("%sTO CLOSE IT: persist the reference report into the *-summary.json" % indent)
    p("%s(any key -- this digest finds it by shape) and call the validator in" % indent)
    p("%sthe PRED path too. This digest renders it the moment it is there;" % indent)
    p("%sthat wiring is a MATLAB change and is deliberately not made here." % indent)
    p("%sNOT THE SAME FACT AS AN EMPTY EDGE: `references.m:90` SKIPS an edge" % indent)
    p("%swhose document_id is empty, so the empty-required-edge census above" % indent)
    p("%scannot substitute for %s." % (indent, plural))


def render_reference_integrity(r, out):
    """Render one corpus's orphan count -- or say ABSENT, in as many words."""
    p = lambda s="": out.append(s)
    m = orphan_block(r)
    if not m["measured"]:
        p("  ORPHAN depends_on EDGES: *** NOT MEASURED IN THIS REPORT ***")
        p("      %s." % m["why"])
        named = m.get("named")
        if named:
            p("      A key whose NAME mentions an orphan IS present (%s) and"
              % ", ".join(named))
            p("      is not in a shape this digest renders. That is a wiring "
              "mismatch,")
            p("      not an absent measurement -- look at it.")
        _orphan_absent_note(p, "      ", "one")
        return
    block = m["block"]
    p("  ORPHAN depends_on EDGES (the second half of the corpus gate), read")
    p("  from `%s`:" % m["key"])
    _ea_rows(block, ORPHAN_BLOCK_ROWS, out, indent="      ")
    examined = block.get("edges_examined")
    if isinstance(examined, int) and examined == 0:
        p("      *** 0 EDGES EXAMINED -- the sweep looked at nothing, so the")
        p("      *** orphan count above is VACUOUS rather than clean.")
    p("      NOT the empty-required-edge census above: `references.m:90` skips")
    p("      an edge whose document_id is empty, so the two counters can never")
    p("      substitute for one another.")
    rows = _orphan_rows(block)
    if rows:
        for key, n in sorted(rows.items(), key=lambda kv: (-kv[1], kv[0]))[:15]:
            p("      %8d  %s" % (n, key))
    elif m["orphans"]:
        p("      (%d orphan(s) counted and no `orphans` row array to name them)"
          % m["orphans"])


def rollup_reference_integrity(reports, out):
    """Cross-corpus orphan total -- or the absence of one, said once, loudly."""
    p = lambda s="": out.append(s)
    measured, unmeasured = [], []
    totals = {"total_docs": 0, "edges_examined": 0, ORPHAN_MARKER_FIELD: 0}
    rows = {}
    for i, r in enumerate(reports):
        name = str((r or {}).get("corpus") or "report #%d" % (i + 1))
        m = orphan_block(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        for key in totals:
            try:
                totals[key] += int(m["block"].get(key) or 0)
            except (TypeError, ValueError):
                pass
        for key, n in _orphan_rows(m["block"]).items():
            rows[key] = rows.get(key, 0) + n

    p("")
    p("  ORPHAN depends_on EDGES -- THE SECOND HALF OF THE '0 quarantine + 0")
    p("  orphans' GATE. An orphan is an edge naming a document that is not in")
    p("  the batch; an EMPTY edge is skipped by the validator and counted")
    p("  elsewhere. Never quote one for the other.")
    p("      DENOMINATOR: %d corpus report(s); %d carried an orphan count, "
      "%d did not" % (len(reports), len(measured), len(unmeasured)))
    if unmeasured:
        p("      NOT MEASURED in: %s" % ", ".join(unmeasured))
    if not measured:
        p("      *** NO REPORT IN THIS RUN CARRIES AN ORPHAN COUNT AT ALL.")
        _orphan_absent_note(p, "      ", "them")
        return
    if unmeasured:
        p("      *** the totals below are sums over %d corpora, not %d -- do"
          % (len(measured), len(reports)))
        p("      *** not quote them as a whole-corpus figure.")
    _ea_rows(totals, ORPHAN_BLOCK_ROWS, out, indent="        ")
    p("      %d orphan(s) across %d row(s)" % (sum(rows.values()), len(rows)))
    for key, n in sorted(rows.items(), key=lambda kv: (-kv[1], kv[0])):
        p("      %8d  %s" % (n, key))
    if not rows:
        p("      (none)")


# --- EPOCH-STRING RETENTION: DID A did_v1 EPOCH ID SURVIVE MIGRATION? ------
#
# `did2.validate.epochStringRetention` compares the (session, epoch-string)
# pairs on the did_v1 SIDE against the pairs still reachable after migration --
# either still spelled out on a migrated document, or turned into an `epoch`
# document by `did2.convert.epochMint`. It is the only instrument here that
# SUBTRACTS one side from the other, which is the only shape of measurement
# that can see a migrator which reads a field and simply does not write it.
# Every other counter inspects one side and looks for something MALFORMED.
#
# It was wired into both corpus-report producers at e9ef734, sited after every
# batch post-pass (so `retained_as_epoch_document` is read after epochMint has
# minted -- beside silentLoss in pass 1 it would be 0 by construction), and
# persisted by `writeCorpusReport` as `epoch_string_retention`. Which is where
# it stopped: the number lands in the artifact JSON and in the per-corpus log
# and NOT in this rollup, the same write-only condition `epoch_mint` and
# `session_anchor_fold` were in before their blocks landed here.
#
# THREE READING RULES, and they are not generic:
#
#   (1) THE DENOMINATOR IS `v1_pairs`, and `v1_classes_inspected` beside
#       `v1_classes_with_string` is the CLASS-level one. `pairs_dropped: 0`
#       with `v1_pairs: 0` is VACUOUS, not clean -- no v1 document in the
#       corpus carried an epoch string at all. Those two readings print
#       identically without the denominator, so the two counts print together
#       on one line here rather than in a column a reader can lose.
#   (2) `v1_by_class` IS WHERE "0 OF 0" LIVES. `vmspikefit` and `pyraview`
#       drop the string BY CONSTRUCTION (both migrators build new bodies and
#       never copy the `epochid` block), so their ABSENCE from the table means
#       "this corpus holds no such document", NOT "the drop is fixed". Both
#       get a printed row either way, per corpus and in the rollup.
#   (3) `v1_declined` is EXCLUDED from the denominator on purpose
#       (`syncrule_mapping`'s endpoint strings), and the output says so, so a
#       source this reader will not read can neither inflate the retention
#       rate nor be quietly forgotten.
#
# NOT ROWS. `ran` is a LINE, because false there means the instrument returned
# before reading anything and that is not a count. `dropped_by_v1_class` is a
# struct keyed by MANGLED class name carrying the same fact as
# `v1_by_class.pairs_dropped`; it is used as a CROSS-CHECK between two
# derivations of one number and never rendered as a second table.
ESR_DENOMINATOR_ROWS = [
    ("v1_documents_inspected", "v1 document(s) handed in  <- DENOMINATOR"),
    ("v1_documents_unreadable", "  UNREADABLE (counted, never dropped)"),
    ("migrated_documents_inspected", "migrated document(s) handed in"),
    ("migrated_documents_unreadable", "  UNREADABLE"),
]

ESR_RETENTION_ROWS = [
    ("retained_as_string", "RETAINED: still spelled out on a migrated document"),
    ("retained_as_epoch_document", "RETAINED: became a minted `epoch` document"),
    ("retained_total", "RETAINED: the union (a pair may be both)"),
    ("pairs_dropped", "DROPPED  <-- the number this instrument exists for"),
    ("epoch_documents_seen", "`epoch` document(s) in the migrated batch"),
]

# The two classes the 19-class survey says drop the string by construction.
# A row is printed for each whether or not the corpus holds one, because
# "absent from this sample" and "measured and clean" are the reading this
# whole block exists to keep apart.
ESR_KNOWN_DROPPERS = ("vmspikefit", "pyraview")


def epoch_string_retention(r):
    """Read one report's epoch-string retention block, or say why not.

    Four NOT-MEASURED conditions, each distinct from a zero and from each
    other -- absent / malformed / the audit threw / it returned before reading
    anything. `ran: false` is the one that matters most: a struct of zeros
    from an instrument that never read a document is not a clean corpus.
    """
    if not isinstance(r, dict):
        return {"measured": False,
                "why": "the report itself is malformed (%s)" % type(r).__name__}
    esr = r.get("epoch_string_retention")
    if esr is None:
        return {"measured": False,
                "why": "this report carries no `epoch_string_retention` block "
                       "-- the instrument was not wired into the run that "
                       "produced it"}
    if not isinstance(esr, dict):
        return {"measured": False,
                "why": "the `epoch_string_retention` block is malformed (%s)"
                       % type(esr).__name__}
    if "audit_failed" in esr:
        return {"measured": False,
                "why": "the retention audit FAILED (%s)" % esr["audit_failed"]}
    if not esr.get("ran"):
        return {"measured": False, "block": esr,
                "why": "it DID NOT RUN -- the instrument returned before "
                       "reading anything, which is not a clean zero"}
    return {"measured": True, "block": esr}


def _esr_int(block, key):
    try:
        return int(block.get(key) or 0)
    except (TypeError, ValueError):
        return None


def _esr_class_rows(block):
    """`v1_by_class` as a list of dicts, tolerating MATLAB's 1-row object."""
    return [c for c in aslist(block.get("v1_by_class")) if isinstance(c, dict)]


def _esr_dropper_line(p, indent, name, row, corpora=None):
    """One known-dropper row, printed present or absent. Absence is named."""
    where = "" if corpora is None else "  [%s]" % ", ".join(corpora)
    if row is None:
        p("%s%-30s 0 of 0 INSPECTED -- no such document carrying an epoch "
          "string%s" % (indent, name, "" if corpora is None else " anywhere"))
        p("%s%-30s in this sample. NOT a measured zero." % (indent, ""))
        return
    p("%s%-30s MEASURED: %s dropped of %s pair(s) carried%s"
      % (indent, name, row.get("pairs_dropped", "?"),
         row.get("distinct_pairs", "?"), where))


def render_epoch_string_retention(r, out):
    """Render one corpus's epoch-string retention. Denominators first."""
    p = lambda s="": out.append(s)
    p("  EPOCH-STRING RETENTION (report-only): did a did_v1 epoch id survive?")
    m = epoch_string_retention(r)
    if not m["measured"]:
        p("      NOT MEASURED -- %s." % m["why"])
        p("      No count is printed. A corpus that could not be measured and")
        p("      a corpus that measured a ZERO are different facts and must")
        p("      not print identically.")
        return
    b = m["block"]
    p("      ran: %s" % b.get("ran"))
    _ea_rows(b, ESR_DENOMINATOR_ROWS, out, indent="      ")
    # THE TWO CLASS COUNTS ON ONE LINE, deliberately. `v1_classes_with_string`
    # alone cannot distinguish "no class carried a string" from "no class was
    # inspected", and separating them into two rows is how that gets lost.
    p("      v1 classes: %s inspected, %s of them carried an epoch string"
      % (b.get("v1_classes_inspected", "(absent)"),
         b.get("v1_classes_with_string", "(absent)")))
    p("      v1 strings: %s document(s) carried one, %s string(s) read, "
      "%s distinct (session,string) pair(s)  <- THE DENOMINATOR"
      % (b.get("v1_documents_with_string", "(absent)"),
         b.get("v1_strings_read", "(absent)"),
         b.get("v1_pairs", "(absent)")))
    for s in aslist(b.get("v1_by_source")):
        if isinstance(s, dict):
            p("          %-38s %6s doc(s)  %6s distinct string(s)"
              % (s.get("source", "?"), s.get("documents", "?"),
                 s.get("distinct_strings", "?")))
    p("      declined (syncrule_mapping endpoints, out of scope by design): "
      "%s hit(s), %s distinct -- EXCLUDED FROM THE DENOMINATOR"
      % (b.get("v1_declined", "(absent)"),
         b.get("v1_declined_distinct", "(absent)")))
    if _esr_int(b, "v1_classes_inspected") == 0:
        p("      *** 0 CLASSES INSPECTED -- the class denominator is empty, so")
        p("      *** every per-class figure below is vacuous.")
    if _esr_int(b, "v1_pairs") == 0:
        p("      *** 0 OF 0 PAIRS -- NO v1 DOCUMENT IN THIS CORPUS CARRIED AN")
        p("      *** EPOCH STRING. Every retention figure below is VACUOUS,")
        p("      *** not clean: `pairs_dropped: 0` beside `v1_pairs: 0` means")
        p("      *** the instrument had nothing to lose.")
    _ea_rows(b, ESR_RETENTION_ROWS, out, indent="      ")
    rows = _esr_class_rows(b)
    p("      BY v1 CLASS (dropped / pairs carried). A pair carried by two")
    p("      classes is counted against BOTH, so this column does NOT sum to")
    p("      `pairs_dropped` above:")
    if not rows:
        p("          (no class carried an epoch string -- see the 0-of-0 line)")
    for c in sorted(rows, key=lambda c: (-(_esr_int(c, "pairs_dropped") or 0),
                                         str(c.get("class_name", "")))):
        p("          %-42s %6s dropped of %6s pair(s) carried, %6s doc(s)"
          % (c.get("class_name", "?"), c.get("pairs_dropped", "?"),
             c.get("distinct_pairs", "?"),
             c.get("documents_with_string", "?")))
    # THE CROSS-CHECK. `dropped_by_v1_class` and the column above are two
    # derivations of one fact, computed in two loops in the MATLAB. When they
    # disagree, that disagreement IS the signal and nothing else would show it.
    named = b.get("dropped_by_v1_class")
    if isinstance(named, dict):
        n_named = len(named)
        n_dropping = sum(1 for c in rows if (_esr_int(c, "pairs_dropped") or 0) > 0)
        if n_named != n_dropping:
            p("          *** THE TWO PER-CLASS DERIVATIONS DISAGREE:")
            p("          *** `dropped_by_v1_class` names %d class(es), the"
              % n_named)
            p("          *** table above shows %d with a non-zero drop. One of"
              % n_dropping)
            p("          *** them has drifted; do not take either as the answer.")
        else:
            p("          (%d class(es) with a non-zero drop; both derivations "
              "agree)" % n_named)
    by_name = dict((str(c.get("class_name")), c) for c in rows)
    p("      THE TWO KNOWN DROPPERS, printed present or absent:")
    for name in ESR_KNOWN_DROPPERS:
        _esr_dropper_line(p, "          ", name, by_name.get(name))
    for d in aslist(b.get("dropped_detail"))[:10]:
        if isinstance(d, dict):
            classes = d.get("v1_classes")
            if isinstance(classes, list):
                classes = ", ".join(str(x) for x in classes)
            p("          e.g. session %s / epoch \"%s\" (carried by: %s)"
              % (d.get("session_id", "?"), d.get("epoch_string", "?"),
                 classes if classes else "?"))


def rollup_epoch_string_retention(reports, out):
    """Cross-corpus retention rollup: SUM the pairs, UNITE the class table.

    THE UNION IS NOT A SUM, and this digest already carries a live example of
    what happens when the two are confused: `relaxed_classes` sums to 7 across
    the six corpora while the cross-corpus union is 3, because a rollup that
    adds per-corpus DISTINCT counts counts every overlap twice. The block
    above prints a `***` warning about exactly that. So `v1_by_class` is
    UNITED on `class_name` here, its distinct-pair columns are reported PER
    CORPUS beside the corpora that produced them, and nothing distinct is
    added up.

    `v1_pairs` and `pairs_dropped` ARE summed, and the reason is a property of
    the key rather than a convenience: a pair is (session_id, string), the
    session id is a document id, and no two corpora share one -- so the pair
    sets are disjoint by construction and the sum is the distinct count. That
    is an assumption about the corpora and it is written down here so it can
    be checked rather than inherited.
    """
    p = lambda s="": out.append(s)
    measured, unmeasured = [], []
    totals = dict((k, 0) for k, _l in
                  ESR_DENOMINATOR_ROWS + ESR_RETENTION_ROWS)
    totals["v1_pairs"] = 0
    totals["v1_documents_with_string"] = 0
    totals["v1_strings_read"] = 0
    totals["v1_declined"] = 0
    # class_name -> {"corpora": [...], "documents_with_string": int,
    #                "per_corpus": [(corpus, dropped, carried)]}
    union = {}
    disagreed = []
    for i, r in enumerate(reports):
        name = str((r or {}).get("corpus") or "report #%d" % (i + 1))
        m = epoch_string_retention(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        b = m["block"]
        for key in totals:
            v = _esr_int(b, key)
            if v is not None:
                totals[key] += v
        rows = _esr_class_rows(b)
        named = b.get("dropped_by_v1_class")
        if isinstance(named, dict):
            n_dropping = sum(1 for c in rows
                             if (_esr_int(c, "pairs_dropped") or 0) > 0)
            if len(named) != n_dropping:
                disagreed.append("%s (names %d, table shows %d)"
                                 % (name, len(named), n_dropping))
        for c in rows:
            cn = str(c.get("class_name", "?"))
            u = union.setdefault(cn, {"corpora": [], "documents_with_string": 0,
                                      "per_corpus": []})
            u["corpora"].append(name)
            docs = _esr_int(c, "documents_with_string")
            if docs is not None:
                u["documents_with_string"] += docs
            u["per_corpus"].append((name, c.get("pairs_dropped", "?"),
                                    c.get("distinct_pairs", "?")))

    p("")
    p("  EPOCH-STRING RETENTION -- did a did_v1 epoch id survive migration?")
    p("  The only instrument here that SUBTRACTS one side from the other. A")
    p("  migrator that reads a field and does not write it is malformed by no")
    p("  counter and smaller than its input; nothing else can see that.")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable retention "
      "block, %d did not" % (len(reports), len(measured), len(unmeasured)))
    if unmeasured:
        p("      NOT MEASURED in: %s" % ", ".join(unmeasured))
    if not measured:
        p("      *** NO REPORT IN THIS RUN CARRIED A RETENTION BLOCK. There is")
        p("      *** nothing to total. This is NOT '0 pairs were dropped' -- it")
        p("      *** is 'the subtraction was never performed on these corpora'.")
        return
    if unmeasured:
        p("      *** the totals below are sums over %d corpora, not %d -- do"
          % (len(measured), len(reports)))
        p("      *** not quote them as a whole-corpus figure.")
    _ea_rows(totals, ESR_DENOMINATOR_ROWS, out, indent="        ")
    p("      v1 strings: %d document(s) carried one, %d string(s) read, "
      "%d (session,string) pair(s)  <- THE DENOMINATOR"
      % (totals["v1_documents_with_string"], totals["v1_strings_read"],
         totals["v1_pairs"]))
    p("      declined and EXCLUDED from that denominator: %d hit(s)"
      % totals["v1_declined"])
    if totals["v1_pairs"] == 0:
        p("      *** 0 PAIRS ACROSS EVERY MEASURED CORPUS. `pairs_dropped: %d`"
          % totals["pairs_dropped"])
        p("      *** beside `v1_pairs: 0` is VACUOUS, not clean -- no v1")
        p("      *** document in this sample carried an epoch string at all.")
    _ea_rows(totals, ESR_RETENTION_ROWS, out, indent="        ")
    if disagreed:
        p("      *** PER-CLASS DERIVATIONS DISAGREE in: %s. `dropped_by_v1_class`"
          % ", ".join(disagreed))
        p("      *** and the `pairs_dropped` column are two derivations of one")
        p("      *** fact; a disagreement is the signal, not a rounding detail.")
    p("      BY v1 CLASS -- A UNION ON `class_name`, NOT A SUM. Distinct-pair")
    p("      counts are per corpus and are NOT added: adding per-corpus")
    p("      distinct counts is what makes `relaxed_classes` read 7 where the")
    p("      union is 3, two blocks above.")
    p("          DENOMINATOR: %d distinct class(es) carried an epoch string in "
      "the union, over %d readable report(s)" % (len(union), len(measured)))
    if not union:
        p("          (no class carried an epoch string in any measured corpus)")
    for cn in sorted(union):
        u = union[cn]
        p("          %-42s seen in: %s" % (cn, ", ".join(sorted(set(u["corpora"])))))
        p("          %-42s %d doc(s) with a string (summed); dropped/carried: %s"
          % ("", u["documents_with_string"],
             ", ".join("%s %s/%s" % t for t in u["per_corpus"])))
    p("      THE TWO KNOWN DROPPERS, printed present or absent:")
    for name in ESR_KNOWN_DROPPERS:
        u = union.get(name)
        if u is None:
            _esr_dropper_line(p, "          ", name, None, corpora=[])
            continue
        p("          %-30s MEASURED in %s -- dropped/carried: %s"
          % (name, ", ".join(sorted(set(u["corpora"]))),
             ", ".join("%s %s/%s" % t for t in u["per_corpus"])))


def render_report(r, out):
    """Render one corpus report. Raises on malformed input; the caller isolates."""
    p = lambda s="": out.append(s)

    p("")
    p("--- %s ---" % r.get("corpus", "(unnamed)"))
    p("  total=%s  migrated=%s  quarantine=%s"
      % (r.get("total", "?"), r.get("migrated_count", "?"),
         r.get("quarantine_count", "?")))
    # IMMEDIATELY BESIDE THE QUARANTINE COUNT, because the gate is quoted as
    # one thing -- "0 quarantine + 0 orphans" -- and for every run to date this
    # digest has printed the first half and nothing at all about the second.
    # Absent prints as ABSENT here rather than not printing.
    render_reference_integrity(r, out)

    sl = r.get("silent_loss") or {}
    if "audit_failed" in sl:
        p("  silent-loss: AUDIT FAILED (%s)" % sl["audit_failed"])
    elif sl:
        # total_docs FIRST and unconditionally. Without the denominator, a
        # census that inspected nothing and one that found nothing wrong print
        # identically -- see the module docstring.
        td = sl.get("total_docs", "?")
        p("  silent-loss: inspected %s doc(s), skipped %s"
          % (td, sl.get("skipped_docs", "?")))
        if td == 0:
            p("  *** total_docs=0 -- THE CENSUS INSPECTED NOTHING. The counts")
            p("  *** below are vacuous; do NOT read them as a clean result.")
        elif isinstance(td, int) and sl.get("skipped_docs", 0) == td:
            p("  *** every document was skipped -- counts below are vacuous.")
        p("  silent-loss: %s empty required edge(s), %s vacuous required field(s)"
          % (sl.get("empty_dependency_count", "?"),
             sl.get("vacuous_field_count", "?")))
        for e in aslist(sl.get("empty_required_dependency"))[:10]:
            p("      %8s  %s.%s" % (e.get("count", "?"),
                                    e.get("class_name", "?"),
                                    e.get("edge_name", "?")))
        for f in aslist(sl.get("vacuous_required_field"))[:10]:
            p("      %8s  %s / %s.%s" % (f.get("count", "?"),
                                         f.get("class_name", "?"),
                                         f.get("block", "?"),
                                         f.get("field_name", "?")))
        # The family-count number, printed UNCONDITIONALLY like the two above.
        # It was measured and written into the report from the first run, and
        # then never rendered -- so the one thing standing between it and a
        # decision was that nobody could see it without downloading an
        # artifact. That is the same write-only condition this whole file
        # exists to remove, one field further down.
        p("  silent-loss: %s edge-family cardinality violation(s)"
          % sl.get("family_violation_count", "?"))
        for v in aslist(sl.get("family_count_violation"))[:10]:
            p("      %8s  %s.%s  declared %s, found %s"
              % (v.get("count", "?"), v.get("class_name", "?"),
                 v.get("edge_name", "?"), v.get("declared", "?"),
                 v.get("found", "?")))
        # #52. A uniqueness violation is a DIFFERENT fact from a cardinality
        # one -- the count is legal and the members are indistinguishable --
        # so it gets its own line and its own denominators. Those denominators
        # are not decoration: this counter has four ways to read zero (the
        # rule fired and found nothing / no document carried two members / the
        # targets were not in the batch / the referents declare no clock), and
        # only the numbers below tell them apart.
        ud = sl.get("uniqueness_denominator") or {}
        p("  silent-loss: %s family-uniqueness violation(s)"
          % sl.get("family_uniqueness_violation_count", "?"))
        p("      DENOMINATOR: %s famil(ies) declare a uniqueness rule; "
          "%s doc-family pair(s) carry a member, %s carry MORE THAN ONE"
          % (ud.get("families_declared", "?"),
             ud.get("docs_with_family", "?"),
             ud.get("docs_multi_member", "?")))
        p("      DENOMINATOR: %s member(s) examined -- %s resolved, "
          "%s unresolved (target not in batch), %s with no key on the referent"
          % (ud.get("members_examined", "?"), ud.get("members_resolved", "?"),
             ud.get("members_unresolved", "?"), ud.get("members_no_key", "?")))
        p("      DENOMINATOR: compared on %s CURIE(s) and %s label(s) "
          "(labels because the NDIC clock terms are unminted -- #67)"
          % (ud.get("members_keyed_by_node", "?"),
             ud.get("members_keyed_by_name", "?")))
        if ud.get("docs_multi_member") == 0:
            p("      *** no document carries two members of a governed family,")
            p("      *** so the rule COULD NOT FIRE. Zero above means"
              " 'untested', not 'clean'.")
        for v in aslist(sl.get("family_uniqueness_violation"))[:10]:
            p("      %8s  %s.%s  two members share %s = %s"
              % (v.get("count", "?"), v.get("class_name", "?"),
                 v.get("edge_name", "?"), v.get("unique_by", "?"),
                 v.get("key", "?")))

    if "fragment_count" in r:
        fc = r["fragment_count"]
        p("  FRAGMENTS: %s migration(s) emitted only scaffolding%s"
          % (fc, "  <-- payload dropped, invisible to every other counter" if fc else ""))
        for k, v in sorted((r.get("fragment_by_class") or {}).items(),
                           key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s" % (v, k))

    if "unconverted_count" in r:
        p("  unconverted: %s document(s) returned unchanged" % r["unconverted_count"])
        for k, v in sorted((r.get("unconverted_by_class") or {}).items(),
                           key=lambda kv: -kv[1])[:15]:
            p("      %8s  %s" % (v, k))

    render_legacy_ndi_document(r, out)

    sc = r.get("source_census") or {}
    if "audit_failed" in sc:
        p("  v1 source census: AUDIT FAILED (%s)" % sc["audit_failed"])
    elif sc:
        # The three pre-build measurements. DENOMINATOR FIRST, same rule as the
        # silent-loss block above and for the same reason.
        std = sc.get("total_docs", "?")
        p("  v1 source census: read %s v1 doc(s), %s unreadable"
          % (std, sc.get("skipped_docs", "?")))
        if std == 0:
            p("  *** total_docs=0 -- THE SOURCE CENSUS READ NOTHING. Everything")
            p("  *** below is vacuous; do NOT quote it as a measurement.")
        else:
            p("      epoch ids: %s doc(s) carry one, %s distinct"
              % (sc.get("docs_with_epoch_id", "?"),
                 sc.get("distinct_epoch_ids", "?")))
            for e in aslist(sc.get("epoch_id_by_prefix")):
                p("          %-16s %6s distinct  %8s doc(s)"
                  % (e.get("prefix", "?"), e.get("distinct_ids", "?"),
                     e.get("doc_count", "?")))
            # THE EPOCH GROUPING HAZARD. One `epoch` per distinct id string is
            # correct only where the string is unique per epoch;
            # `whole_session_<ref>` is minted per ELEMENT and would fuse.
            p("      grouping hazard: %s synthetic (whole_session_) id(s), "
              "%s id(s) spanning >1 session"
              % (sc.get("synthetic_epoch_id_count", "?"),
                 sc.get("cross_session_epoch_id_count", "?")))
            for x in aslist(sc.get("synthetic_epoch_ids"))[:5]:
                p("          would fuse %4s element span(s): %s"
                  % (x.get("distinct_elements", "?"), x.get("epoch_id", "?")))
            p("      session documents: %s   (distinct base.session_id: %s)"
              % (sc.get("session_doc_count", "?"),
                 sc.get("distinct_session_ids", "?")))
            if sc.get("session_doc_count") == 0:
                p("      *** NONE -- a REQUIRED `relative_to` would have no")
                p("      *** referent in this corpus.")
            p("      stimulation approaches: %s doc(s) over %s epoch(s)"
              % (sc.get("approach_doc_count", "?"),
                 sc.get("approach_epochs", "?")))
            for d in aslist(sc.get("subjects_per_approach_epoch")):
                p("          %4s subject(s): %6s epoch(s)"
                  % (d.get("n_subjects", "?"), d.get("n_epochs", "?")))
            if sc.get("approach_doc_count"):
                p("          %s approach epoch(s) with NO presentation document"
                  % sc.get("approach_epochs_no_presentation", "?"))
            # WHY THE TWO SIDES DO NOT MEET. Rendered whenever either exists:
            # Dab has 635 approaches and 1,242 presentations sharing NO epoch
            # id, and the pooled prefix histogram cannot say why because it
            # mixes every class together.
            if sc.get("approach_doc_count") or sc.get("presentation_doc_count"):
                if "approach_presentation_shared_epochs" in sc:
                    p("          epoch ids carried by BOTH classes: %s"
                      % sc["approach_presentation_shared_epochs"])
                for label, key in (("approach", "approach_epoch_prefixes"),
                                   ("presentation", "presentation_epoch_prefixes")):
                    tally = aslist(sc.get(key))
                    if not tally:
                        continue
                    p("          %s epoch ids by prefix:" % label)
                    for t in tally:
                        p("            %-16s %4s distinct  %6s doc(s)"
                          % (t.get("prefix", "?"), t.get("n_distinct", "?"),
                             t.get("n_docs", "?")))

    render_ndi_required(r, out)
    # DIRECTLY AFTER the silent-loss block, and specifically after its
    # family-uniqueness lines: the two are the #52 pair and a reader compares
    # them. "The uniqueness rule fired and found nothing" and "the regime the
    # rule governs is occupied and nobody has named its edges" are different
    # facts about the same families, and separating them across three screens
    # is how the first one got quoted as if it were both.
    render_time_reference_families(r, out)
    render_epoch_association(r, out)
    # Immediately after, and never separated from it: the epoch-association
    # block's `epoch` counts are the ones that were being read beside the mint's
    # without anything saying they came from different batches.
    render_epoch_populations(r, out)
    # Immediately after the epoch populations, because that is what makes it
    # readable: `retained_as_epoch_document` and `epoch_documents_seen` count
    # the same minted documents those figures do, and the retention block is
    # sited after every batch post-pass precisely so they are commensurable.
    render_epoch_string_retention(r, out)
    render_metadata_tier(r, out)
    render_post_passes(r, out)

    for q in aslist(r.get("quarantine_reasons"))[:5]:
        p("  quarantine: %5s [%s] %s" % (q.get("count", "?"),
                                         q.get("class_name", "?"),
                                         str(q.get("reason", ""))[:90]))


def find_reports(reports_dirs):
    """Find every *-summary.json under each root in reports_dirs, at ANY depth.

    Return (chosen_paths, all_paths, dirs_walked).

    SEVERAL ROOTS because MATLAB's pwd during a corpus run is not fixed:
    `test-corpus.yml` downloads artifacts into `corpus-reports/` while
    `test-code.yml` runs the corpora in-process and they land in
    `tests/corpus-reports/`. That second workflow's digest step has been
    printing "NO CORPUS REPORTS FOUND" for the same reason, one directory off.
    A root that does not exist is reported, not fatal.

    RECURSIVE ON PURPOSE. The reports are written to `<pwd>/corpus-reports/`
    and MATLAB's pwd during a corpus run is `tests/`, so the report lands at
    `tests/corpus-reports/<NAME>-summary.json`. `upload-artifact` given two
    search paths takes their LEAST COMMON ANCESTOR as the artifact root -- the
    repo root -- so the zip carries `tests/corpus-reports/...`, and
    `download-artifact --path corpus-reports` unpacks it to
    `corpus-reports/tests/corpus-reports/...`. Run #3 (31315510527) downloaded
    5 artifacts, 10 files, and matched ZERO with the old one-level glob:

        Total of 5 artifact(s) downloaded
        NO CORPUS REPORTS FOUND (corpus-reports/*-summary.json)
        With the provided path, there will be 10 files uploaded

    Depth is an artifact-plumbing detail and must never again decide whether
    the census is seen. Duplicates (the same corpus found at two depths, which
    the two-path upload can produce) collapse to the shallowest path, and the
    collapse is REPORTED rather than silently applied.
    """
    all_paths, dirs_walked = [], 0
    for reports_dir in reports_dirs:
        for root, _dirs, names in os.walk(reports_dir):
            dirs_walked += 1
            for name in names:
                if name.endswith("-summary.json"):
                    all_paths.append(os.path.join(root, name))
    all_paths.sort()

    by_name, chosen = {}, []
    for path in all_paths:
        key = os.path.basename(path)
        if key in by_name:
            continue
        by_name[key] = path
        chosen.append(path)
    chosen.sort(key=lambda p: (os.path.basename(p), p))
    return chosen, all_paths, dirs_walked


def rollup(reports, out):
    """Sum the headline counters ACROSS corpora, with the denominator first.

    WHY THIS EXISTS
    ---------------
    Every number in this digest is per-corpus, and the number that actually gets
    quoted -- in a plan document, in a commit message, in CLAUDE.md -- is the
    TOTAL. Until now that total was produced by a human reading six blocks and
    adding them up, and the record shows what that costs:

      * The empty-required-edge table was written down as "12,296 documents,
        three classes" and stood for months. It was 26,406 across six, and the
        three it named were the three SMALLEST. The two largest rows were in the
        same report the three came from; nobody had read past the daq family.
      * The next re-derivation, on 2026-08-09, was right -- but only because
        someone re-summed it by hand a second time, and it had to carry a
        standing note telling the next reader to do it again.

    A total that must be recomputed by hand from a report is a total that goes
    stale silently, because nothing compares it to anything. So the digest
    computes it.

    The DENOMINATOR comes first and unconditionally, per the standing rule: how
    many corpora went into the sum, and how many of them actually carried the
    field being summed. A total over four corpora and a total over six are
    different facts and must not print identically -- which is exactly the
    failure mode that made "0 empty edges" believable while `silentLoss` was
    reading nothing.
    """
    p = lambda s="": out.append(s)

    edges, fields, families, uniques = {}, {}, {}, {}
    # #52 rollup denominators, summed the same way the counts are.
    uni_den = {"docs_with_family": 0, "docs_multi_member": 0,
               "members_examined": 0, "members_resolved": 0,
               "members_unresolved": 0, "members_no_key": 0,
               "members_keyed_by_node": 0, "members_keyed_by_name": 0}
    inspected = 0
    addends = []
    quarantine = 0
    fragments = 0
    with_silent_loss = 0
    for i, r in enumerate(reports):
        sl = r.get("silent_loss") or {}
        try:
            quarantine += int(r.get("quarantine_count") or 0)
        except (TypeError, ValueError):
            pass
        try:
            fragments += int(r.get("fragment_count") or 0)
        except (TypeError, ValueError):
            pass
        if not sl or "audit_failed" in sl:
            continue
        with_silent_loss += 1
        try:
            n = int(sl.get("total_docs") or 0)
            inspected += n
            addends.append((str(r.get("corpus") or "report #%d" % (i + 1)), n))
        except (TypeError, ValueError):
            pass
        for e in aslist(sl.get("empty_required_dependency")):
            key = "%s.%s" % (e.get("class_name", "?"), e.get("edge_name", "?"))
            edges[key] = edges.get(key, 0) + int(e.get("count") or 0)
        for f in aslist(sl.get("vacuous_required_field")):
            key = "%s / %s.%s" % (f.get("class_name", "?"), f.get("block", "?"),
                                  f.get("field_name", "?"))
            fields[key] = fields.get(key, 0) + int(f.get("count") or 0)
        for v in aslist(sl.get("family_count_violation")):
            key = "%s.%s" % (v.get("class_name", "?"), v.get("edge_name", "?"))
            families[key] = families.get(key, 0) + int(v.get("count") or 0)
        for v in aslist(sl.get("family_uniqueness_violation")):
            key = "%s.%s  (%s = %s)" % (v.get("class_name", "?"),
                                        v.get("edge_name", "?"),
                                        v.get("unique_by", "?"),
                                        v.get("key", "?"))
            uniques[key] = uniques.get(key, 0) + int(v.get("count") or 0)
        ud = sl.get("uniqueness_denominator") or {}
        for k in uni_den:
            try:
                uni_den[k] += int(ud.get(k) or 0)
            except (TypeError, ValueError):
                pass

    p("")
    p("=" * 72)
    p("ACROSS ALL CORPORA")
    p("=" * 72)
    p("  DENOMINATOR: %d corpus report(s) summed; %d carried a readable "
      "silent-loss audit; %d document(s) inspected in total"
      % (len(reports), with_silent_loss, inspected))
    # THE ADDENDS, NAMED. A total whose inputs are three screens up gets
    # re-derived by hand, and a hand re-derivation picks up the wrong line.
    # It already has: 562,422 was recorded in DID-schema/CLAUDE.md for corpus
    # run 31415147934, and 562,422 is EXACTLY the six `inspected` figures with
    # corpus B's `migrated_count` (13,778) substituted for its `inspected`
    # (13,804) -- the two numbers sit two lines apart in B's block. The true
    # sum is 562,448. (That run predates this rollup entirely, so the figure
    # could only have been hand-summed.) Printing the addends beside the total,
    # and naming which counter they are, makes that substitution visible
    # instead of a 26-document discrepancy nobody can source.
    p("      addends -- silent-loss `inspected`, NOT `migrated` and NOT "
      "`total`:")
    p("      %s = %d"
      % (" + ".join("%s %d" % (name, n) for name, n in addends) or "(none)",
         inspected))
    if with_silent_loss != len(reports):
        p("  *** %d report(s) contributed NO silent-loss numbers. The totals"
          % (len(reports) - with_silent_loss))
        p("  *** below are sums over %d corpora, not %d -- do not quote them"
          % (with_silent_loss, len(reports)))
        p("  *** as a whole-corpus figure.")
    p("  quarantined: %d       fragments: %d" % (quarantine, fragments))
    # THE OTHER HALF OF THE GATE, on the line after the half we have always
    # printed. It renders ABSENT when nothing carries it, which is the state
    # every run to date has been in.
    rollup_reference_integrity(reports, out)

    for label, table in (("EMPTY REQUIRED EDGES", edges),
                         ("VACUOUS REQUIRED FIELDS", fields),
                         ("EDGE-FAMILY CARDINALITY VIOLATIONS", families),
                         ("EDGE-FAMILY UNIQUENESS VIOLATIONS", uniques)):
        total = sum(table.values())
        p("")
        p("  %s: %d document(s) across %d row(s)" % (label, total, len(table)))
        if table is uniques:
            # The uniqueness row set is the one where an empty table is
            # AMBIGUOUS, so its denominators print beside it rather than three
            # screens up in the per-corpus blocks.
            p("      DENOMINATOR: %d doc-family pair(s) carried a member, "
              "%d carried MORE THAN ONE"
              % (uni_den["docs_with_family"], uni_den["docs_multi_member"]))
            p("      DENOMINATOR: %d member(s) examined -- %d resolved, "
              "%d unresolved, %d with no key on the referent"
              % (uni_den["members_examined"], uni_den["members_resolved"],
                 uni_den["members_unresolved"], uni_den["members_no_key"]))
            p("      DENOMINATOR: %d compared on a CURIE, %d on a label"
              % (uni_den["members_keyed_by_node"],
                 uni_den["members_keyed_by_name"]))
            if uni_den["docs_multi_member"] == 0:
                p("      *** NOTHING IN REACH CARRIES TWO MEMBERS OF A")
                p("      *** GOVERNED FAMILY. The rule could not fire; the")
                p("      *** zero is 'untested', not 'clean'.")
        for key, n in sorted(table.items(), key=lambda kv: (-kv[1], kv[0])):
            p("      %8d  %s" % (n, key))
        if not table:
            p("      (none)")

    # Immediately after the four tables above, and never merged into them: the
    # last of those is EDGE-FAMILY UNIQUENESS VIOLATIONS, whose zero the digest
    # already annotates as 'untested, not clean'. This block is what says
    # whether the regime that rule governs is occupied at all.
    rollup_time_reference_families(reports, out)
    rollup_legacy_ndi_document(reports, out)
    rollup_ndi_required(reports, out)
    rollup_epoch_association(reports, out)
    # RETURNS FINDINGS, unlike every other rollup here. A cross-corpus
    # disagreement between figures that count the same `epoch` documents over
    # the same batch is the one thing in this digest that is a claim about the
    # migration rather than about the reports, so it exits non-zero.
    findings = rollup_epoch_populations(reports, out)
    # Directly after the epoch populations, for the reason the per-corpus
    # renderer sits there: these are the same minted `epoch` documents.
    rollup_epoch_string_retention(reports, out)
    rollup_metadata_tier(reports, out)
    rollup_post_passes(reports, out)
    return findings


def rollup_legacy_ndi_document(reports, out):
    """Cross-corpus total for the legacy identity block, denominator first.

    THE TOTAL IS THE NUMBER THAT GETS QUOTED, and for this counter the number
    that will be quoted is "how many pre-`base` documents are there". It is
    expected to be 0 over every corpus we hold, and a 0 summed over four
    corpora is not the same fact as a 0 summed over six -- so the count of
    reports that CARRIED the block prints beside the count that were summed.
    A report predating the counter contributes nothing and is NAMED, never
    silently treated as a zero.
    """
    p = lambda s="": out.append(s)
    keys = ("bodies_reaching_universal_renames", "ndi_document_block_seen",
            "moved_wholesale_no_base", "discarded_ndi_document_base_present",
            "moved_missing_id", "moved_missing_session_id",
            "moved_undeclared_field_instances",
            "moved_carrying_experiment_unique_reference",
            "moved_carrying_document_unique_reference")
    totals = dict((k, 0) for k in keys)
    carried, missing = 0, []
    for i, r in enumerate(reports):
        L = r.get("legacy_ndi_document")
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        if not L:
            missing.append(name)
            continue
        carried += 1
        for k in keys:
            try:
                totals[k] += int(L.get(k) or 0)
            except (TypeError, ValueError):
                pass
    p("")
    p("  LEGACY IDENTITY BLOCK (`ndi_document` -> `base`)")
    p("      DENOMINATOR: %d of %d report(s) carried the counter; "
      "%d bod(ies) reached did2.convert.universalRenames"
      % (carried, len(reports), totals["bodies_reaching_universal_renames"]))
    if missing:
        p("      *** NOT SUMMED (no counter in the report): %s"
          % ", ".join(missing))
    if carried == 0:
        p("      *** nothing to sum. This is NOT '0 pre-base documents'.")
        return
    p("      %8d  carried an `ndi_document` block"
      % totals["ndi_document_block_seen"])
    p("      %8d  MOVED WHOLESALE into `base` (the defect); %d of them lost "
      "`id`, %d lost `session_id`"
      % (totals["moved_wholesale_no_base"], totals["moved_missing_id"],
         totals["moved_missing_session_id"]))
    p("      %8d  discarded (`base` present and wins) -- a DIFFERENT fact, "
      "never summed with the line above"
      % totals["discarded_ndi_document_base_present"])
    p("      %8d  field(s) moved into `base` that `base` does not declare"
      % totals["moved_undeclared_field_instances"])
    p("      %8d  block(s) carrying experiment_unique_reference, "
      "%d carrying document_unique_reference"
      % (totals["moved_carrying_experiment_unique_reference"],
         totals["moved_carrying_document_unique_reference"]))

    # THE VINTAGE ROLLUP, summed only over the reports that CARRIED it -- which
    # may be fewer than the reports carrying the parent block, because the
    # classifier landed later than the arm counter. That gap is printed and the
    # reports are NAMED; a report predating the classifier is UNMEASURED, never
    # a zero. Same rule as the parent, one level down.
    vcarried, vmissing, vtotals = 0, [], dict((k, 0) for k, _ in LEGACY_VINTAGES)
    vden = 0
    for i, r in enumerate(reports):
        L = r.get("legacy_ndi_document") or {}
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        if not L:
            continue
        if ical not in L and not any(k in L for k, _ in LEGACY_VINTAGES):
            vmissing.append(name)
            continue
        vcarried += 1
        vden += _int_or_none(L.get(ical)) or 0
        for k, _label in LEGACY_VINTAGES:
            vtotals[k] += _int_or_none(L.get(k)) or 0
    p("      VINTAGE BREAKDOWN: summed over %d of %d report(s) carrying the "
      "block; %d block(s) classified" % (vcarried, carried, vden))
    if vmissing:
        p("      *** NO CLASSIFIER (predates it, UNMEASURED not zero): %s"
          % ", ".join(vmissing))
    if vcarried == 0:
        p("      *** nothing to sum. The arm's COMPOSITION is unknown, which is")
        p("      *** not the same as the arm being empty.")
    else:
        for k, label in LEGACY_VINTAGES:
            p("          %8d  %s" % (vtotals[k], label))
        vsum = sum(vtotals.values())
        if vsum != vden:
            p("      *** THE BUCKETS DO NOT PARTITION THE ARM ACROSS THE "
              "SAMPLE: %d summed, %d classified." % (vsum, vden))
        if vtotals["moved_vintage_unknown"]:
            p("      *** %d block(s) carried a field set the four-vintage "
              "account does not predict." % vtotals["moved_vintage_unknown"])
            p("      *** READ THIS ROW FIRST. It is the way this measurement is")
            p("      *** most likely to be wrong, and it was NOT rounded into a")
            p("      *** neighbouring vintage.")

    if totals["moved_wholesale_no_base"] == 0:
        p("      *** 0 across the sample. Corpus run 31464483119 inspected")
        p("      *** 633,432 documents across 6 corpora and quarantined 0, so")
        p("      *** no pre-`base` document is in any corpus we hold. That is")
        p("      *** a fact about the SAMPLE and NOT evidence none exist: the")
        p("      *** size of this defect is UNMEASURED, not zero.")


def rollup_metadata_tier(reports, out):
    """Cross-corpus metadata tier: does ANY corpus have the graph and no editor?

    THE QUESTION THIS ANSWERS. `metadata_editor` and the openMINDS dataset
    graph are written by two independent NDI code paths (see METADATA_TIER
    above), and only the first has a migrator that produces the dataset /
    person / funding / publication tier. Whether the split actually occurs in
    real data is a per-corpus co-occurrence, so it cannot be read off any
    single corpus's block -- which is why the buckets below NAME their corpora
    rather than only counting them.

    The denominator is how many reports carried a readable v1 source census,
    printed before any count, and the corpora that carried none are named. A
    corpus missing from the measurement and a corpus contributing a zero are
    the two readings this whole block exists to keep apart.
    """
    p = lambda s="": out.append(s)

    measured, unmeasured = [], []
    totals = dict((cls, 0) for cls in METADATA_TIER_CLASSES)
    extras = {}
    source_docs = 0
    buckets = {"BOTH": [], "GRAPH WITHOUT EDITOR": [],
               "EDITOR WITHOUT GRAPH": [], "NEITHER": []}
    emitted_totals = dict((cls, 0) for cls in METADATA_TIER_EMITTED)
    with_by_class = 0

    for i, r in enumerate(reports):
        name = str(r.get("corpus") or "report #%d" % (i + 1))
        if isinstance(r.get("by_class"), dict):
            with_by_class += 1
            index = normalised_class_index(r["by_class"])
            for cls in METADATA_TIER_EMITTED:
                emitted_totals[cls] += class_count(index, cls)
        m = metadata_tier(r)
        if not m["measured"]:
            unmeasured.append("%s (%s)" % (name, m["why"]))
            continue
        measured.append(name)
        source_docs += m["source_total"]
        for cls in METADATA_TIER_CLASSES:
            totals[cls] += m["counts"][cls]
        for key, n in m["extras"].items():
            extras[key] = extras.get(key, 0) + n
        buckets[m["verdict"]].append(name)

    p("")
    p("  METADATA TIER (metadata_editor vs the openMINDS dataset graph)")
    p("      DENOMINATOR: %d corpus report(s); %d carried a readable v1 source "
      "census, %d did not; %d v1 source doc(s) read in total"
      % (len(reports), len(measured), len(unmeasured), source_docs))
    if unmeasured:
        p("      *** NOT MEASURED in: %s" % ", ".join(unmeasured))
        p("      *** the totals below are sums over %d corpora, not %d."
          % (len(measured), len(reports)))
    if not measured:
        p("      (nothing to total -- no corpus contributed a source census)")
        return

    for cls in METADATA_TIER_CLASSES:
        p("      %8d  %s" % (totals[cls], cls))
    for key, n in sorted(extras.items(), key=lambda kv: (-kv[1], kv[0])):
        p("      %8d  %s   <- ANOTHER openminds_* class, not in the expected "
          "list" % (n, key))

    p("      CO-OCCURRENCE over the %d measured corpus/corpora:" % len(measured))
    for verdict in ("BOTH", "GRAPH WITHOUT EDITOR", "EDITOR WITHOUT GRAPH",
                    "NEITHER"):
        names = buckets[verdict]
        p("      %8d  %-22s %s"
          % (len(names), verdict, ", ".join(names) if names else "--"))
    if buckets["GRAPH WITHOUT EDITOR"]:
        p("      *** %d corpus/corpora carry the openMINDS dataset graph with NO"
          % len(buckets["GRAPH WITHOUT EDITOR"]))
        p("      *** metadata_editor document. Their authors, funding and")
        p("      *** publications have NO migrator and migrate nowhere.")
        p("      *** The corpora are a SAMPLE: this is what these %d measured"
          % len(measured))
        p("      *** corpora hold, not a bound on how often the split occurs.")

    if with_by_class != len(reports):
        p("      migrated dataset tier: %d of %d report(s) carried a by_class"
          % (with_by_class, len(reports)))
    p("      migrated dataset tier (from the MIGRATED-OUTPUT by_class): %s"
      % ", ".join("%s=%d" % (cls, emitted_totals[cls])
                  for cls in METADATA_TIER_EMITTED))


def rollup_post_passes(reports, out):
    """Cross-corpus post-pass coverage: did each pass run EVERYWHERE?

    THE FAILURE THIS DETECTS. A batch pass wired into some call sites and not
    others is worse than one wired nowhere: the corpus goes green while another
    path does something else, and nothing in a per-corpus block says so, because
    each block only reports on itself. The equivalent at the data level is a
    pass present in four reports out of six -- which reads as perfectly healthy
    four times and is invisible twice.

    So the coverage line is the DENOMINATOR here, printed before any total: how
    many reports were summed, and how many carried each pass. A pass whose
    presence count is not the report count gets a *** banner naming the corpora
    that lack it.

    THE EXPECTED SET IS DERIVED, not read off POST_PASSES. This function's
    headline used to say "%d expected in a V_eta run" with POST_PASSES as the
    %d, and it printed 2 while the harness composed 9. A pass missing from the
    table produced no line at all here, so "ran and reported nothing" and "does
    not exist" were the same output -- which is the defect the whole block
    exists to prevent, arriving in the block itself.
    """
    p = lambda s="": out.append(s)

    chain = harness_pass_chain()
    exp = post_pass_expectations(chain)
    unmeasured = [e for e in exp if e["state"] == "unmeasured"]
    p("")
    p("  BATCH POST-PASSES: %d expected in a V_eta run%s, over %d corpus "
      "report(s)" % (len(exp), "" if chain["derived"] else
                     " (NOT DERIVED -- render-table floor)", len(reports)))
    p("      DENOMINATOR: %d measurable (they attach a report), %d UNMEASURED "
      "BY CONSTRUCTION" % (len(exp) - len(unmeasured), len(unmeasured)))
    for e in unmeasured:
        p("      *** did2.convert.%s RAN IN EVERY ONE OF THESE %d REPORT(S) AND"
          % (e["fn"], len(reports)))
        p("      *** ATTACHED NO REPORT STRUCT. Nothing below sums its work,")
        p("      *** and no total in this digest is evidence about it.")
    if not reports:
        p("      (no reports)")
        return

    def corpus_of(rep, i):
        return str(rep.get("corpus") or "report #%d" % (i + 1))

    for e in exp:
        if e["state"] in ("unmeasured", "unrendered", "not_in_chain"):
            if e["state"] == "unrendered":
                p("")
                p("    %s  (did2.convert.%s)" % (e["field"], e["fn"]))
                p("      NO ROWS IN THIS DIGEST'S RENDER TABLE -- the report")
                p("      carries this pass and nothing here reads it.")
            elif e["state"] == "not_in_chain":
                p("")
                p("    %s  (did2.convert.%s)" % (e["field"], e["fn"]))
                p("      *** NOT COMPOSED BY ANY REPORT-WRITING CALL SITE.")
                p("      *** Totals for it would be coverage of a pass that")
                p("      *** does not run; none are printed.")
            continue
        name, fn, rows = e["field"], "did2.convert.%s" % e["fn"], e["rows"]
        carried, missing, failed_in, noop_in = [], [], [], []
        totals = {}
        # PER-COUNTER presence, not just per-pass. A pass can be present in
        # every report while a COUNTER inside it is present in only some -- that
        # is what an older report looks like after a counter is added, and the
        # sum over the carriers then prints as a whole-corpus figure. Naming the
        # reports that contributed nothing is the same rule
        # rollup_legacy_ndi_document already applies one level up.
        key_missing_in = {}
        for i, r in enumerate(reports):
            rep = r.get(name)
            if not isinstance(rep, dict):
                missing.append(corpus_of(r, i))
                continue
            if rep.get("pass_failed"):
                failed_in.append(corpus_of(r, i))
                continue
            if rep.get("ran") is False:
                noop_in.append(corpus_of(r, i))
                continue
            carried.append(corpus_of(r, i))
            for key, _label in rows:
                if key in rep:
                    try:
                        totals[key] = totals.get(key, 0) + int(rep[key] or 0)
                    except (TypeError, ValueError):
                        pass
                else:
                    key_missing_in.setdefault(key, []).append(corpus_of(r, i))

        p("")
        p("    %s  (%s)" % (name, fn))
        p("      DENOMINATOR: ran in %d of %d report(s); %d absent, %d FAILED, "
          "%d no-op" % (len(carried), len(reports), len(missing),
                        len(failed_in), len(noop_in)))
        if failed_in:
            p("      *** FAILED in: %s" % ", ".join(failed_in))
            p("      *** those corpora's documents are in PASS-1 FORM for this")
            p("      *** pass; the totals below are sums over %d corpora only."
              % len(carried))
        if missing and carried:
            # MIXED presence: the trap. Healthy in every block it appears in,
            # invisible in the ones it does not.
            p("      *** NOT PRESENT in: %s" % ", ".join(missing))
            p("      *** a pass that ran on some corpora and not others is the")
            p("      *** trap this section exists to catch -- do not read the")
            p("      *** totals below as whole-corpus figures.")
        elif missing:
            # Absent EVERYWHERE. A different fact, and the one that means the
            # pass is not wired into the harness at all (or these reports
            # predate the wiring). Saying "some corpora and not others" here
            # would be false.
            p("      *** NOT PRESENT IN ANY REPORT: %s" % ", ".join(missing))
            p("      *** either the pass is not wired into the harness, or")
            p("      *** these reports predate the wiring. It measured nothing.")
        if noop_in:
            p("      no-op (non-V_eta target or empty batch) in: %s"
              % ", ".join(noop_in))
        if not carried:
            p("      (nothing to total)")
            continue
        partial = []
        for key, label in rows:
            if key in totals:
                absent_in = key_missing_in.get(key) or []
                mark = ""
                if absent_in:
                    mark = ("   <-- PARTIAL: summed over %d of %d report(s)"
                            % (len(carried) - len(absent_in), len(carried)))
                    partial.append((key, absent_in))
                p("          %10d  %s%s" % (totals[key], label, mark))
            else:
                p("          %10s  %s" % ("(absent)", label))
        # THE SITE OF THE ORIGINAL DEFECT. Run 31508009545 printed `8433 epochs
        # minted` and `8433 epoch documents to anchor to` HERE, in the rollup,
        # while the rollup's epoch-association block printed 0 a few lines
        # above. Both sides now name their batch.
        if name in ("epoch_mint", "valid_interval_decompose"):
            _render_post_pass_epoch_population(
                name, totals.get("documents_inspected"), p,
                scope=" (summed over %d report(s))" % len(carried))
        if partial:
            # NAMED, NOT TREATED AS ZEROS. A report that does not carry a
            # counter has not measured 0 of it; it has measured nothing. The
            # sum above is over the others, and this says which.
            p("      *** SOME COUNTERS ARE SUMMED OVER FEWER REPORTS THAN THE")
            p("      *** PASS RAN IN. A report with no such counter contributes")
            p("      *** NOTHING and is named here rather than counted as 0:")
            for key, absent_in in partial:
                p("      ***   %-32s no such counter in: %s"
                  % (key, ", ".join(absent_in)))
        if name == "openminds_citations":
            _rollup_openminds_citations_reading(totals, key_missing_in,
                                                carried, rows, reports, p)
        if name == "response_parameters_fold":
            _rollup_response_parameters_reading(totals, key_missing_in,
                                                carried, p)
        if name == "lawn_plate_subjects":
            _rollup_lawn_plate_reading(totals, key_missing_in, carried, p)
        if name == "session_anchor_fold":
            _rollup_bounded_extent_reading(totals, key_missing_in, carried, p)


def _rollup_denominator(totals, key_missing_in, carried, key, label, p,
                        when_absent, when_zero):
    """Cross-corpus denominator, in the SAME three states as the per-corpus one.

    THE MIDDLE STATE IS THE ONE THIS PROJECT KEEPS PAYING FOR. A rollup that
    reads 0 because no report carried the counter, and a rollup that reads 0
    because the counter really was 0 everywhere, print identically unless the
    first is named. A report contributing no counter has measured NOTHING; it
    has not measured zero, and it is NAMED here rather than summed in.

    Returns the total, or None when nothing carried it.
    """
    if key not in totals:
        absent_in = key_missing_in.get(key) or []
        p("      *** `%s` IS NOT CARRIED BY ANY OF THE %d REPORT(S) THAT RAN"
          % (key, len(carried)))
        p("      *** THE PASS%s."
          % (" (absent in: %s)" % ", ".join(absent_in) if absent_in else ""))
        for line in when_absent:
            p("      *** %s" % line)
        p("      *** That is UNMEASURED, and it is not the same as zero.")
        return None
    total = totals[key]
    absent_in = key_missing_in.get(key) or []
    p("      DENOMINATOR: %d %s across %d report(s)%s"
      % (total, label, len(carried) - len(absent_in),
         "; NOT CARRIED BY: %s" % ", ".join(absent_in) if absent_in else ""))
    if total == 0:
        for line in when_zero:
            p("      *** %s" % line)
    return total


def _rollup_openminds_citations_reading(totals, key_missing_in, carried, rows,
                                        reports, p):
    """The cross-corpus reading of the citation assembly."""
    p("      THE CITATION ASSEMBLY -- the reading of the totals above")
    seen = _rollup_denominator(
        totals, key_missing_in, carried, "openminds_documents_seen",
        "`openminds` document(s)", p,
        when_absent=["These counters landed 2026-08-11."],
        when_zero=[
            "No corpus in this run holds an openMINDS graph store, so every",
            "total above is VACUOUS -- 'the assembly could not fire', not",
            "'the assembly found nothing wrong'. The METADATA TIER rollup",
            "above is where the graph-vs-editor split is actually measured.",
        ])
    if not seen:
        return
    consumed = totals.get("components_consumed", 0)
    withheld = totals.get("components_withheld", 0)
    reverted = totals.get("components_reverted_on_validation", 0)
    p("      %8d  component(s) consumed, %d WITHHELD, %d REVERTED"
      % (consumed, withheld, reverted))
    if withheld or reverted:
        # NAMED PER CORPUS. A component withheld in one corpus and consumed in
        # five reads as healthy five times, which is the same trap the coverage
        # line above exists for, one level down.
        for field, label in (("components_withheld", "WITHHELD"),
                             ("components_reverted_on_validation", "REVERTED")):
            names = []
            for i, r in enumerate(reports):
                block = r.get("openminds_citations")
                if not isinstance(block, dict):
                    continue
                try:
                    if int(block.get(field) or 0) > 0:
                        names.append(str(r.get("corpus") or "report #%d" % (i + 1)))
                except (TypeError, ValueError):
                    pass
            if names:
                p("      *** %s in: %s" % (label, ", ".join(names)))
        p("      *** A withheld component leaves the corpus exactly as pass 1")
        p("      *** left it; a reverted one means a body this pass BUILT")
        p("      *** failed validation. The first is the orphan guard working,")
        p("      *** the second is a defect in the build.")
    if consumed == 0 and seen:
        p("      *** %d `openminds` document(s) seen and NOT ONE component" % seen)
        p("      *** consumed. Every one was either rootless, withheld or")
        p("      *** reverted -- the emitted totals below are all 0 for that")
        p("      *** reason and not because the graph was empty.")


def _rollup_response_parameters_reading(totals, key_missing_in, carried, p):
    """The cross-corpus reading of the #61 resolver."""
    p("      THE STIMULUS-RESPONSE FOLD -- the reading of the totals above")
    leaves = _rollup_denominator(
        totals, key_missing_in, carried, "leaves_seen",
        "harmonic_component_calculation leaf/leaves", p,
        when_absent=["These counters landed 2026-08-11."],
        when_zero=[
            "No leaf reached the fold in any corpus, so every INLINE and",
            "REFUSAL total above is VACUOUS. Read `suppressed_responses_seen`",
            "next: it is measured independently and is NOT vacuous.",
        ])
    if leaves is None:
        return
    suppressed = totals.get("suppressed_responses_seen")
    if leaves == 0:
        if suppressed is None:
            p("      *** and `suppressed_responses_seen` is carried by no report,")
            p("      *** so the reading that would distinguish 'no responses'")
            p("      *** from 'pass 1 suppressed every fold' is UNMEASURED.")
        elif suppressed:
            p("      *** %d v1 response(s) STILL SUPPRESSED across the run. The"
              % suppressed)
            p("      *** fold is BLOCKED UPSTREAM by pass 1's epoch gate, which")
            p("      *** is the expected state until #60 lands. The zeros above")
            p("      *** describe that gate, not this pass.")
        else:
            p("      *** 0 leaves beside 0 suppressed responses: no corpus in")
            p("      *** this run holds stimulus responses at all.")
    seen = totals.get("parameters_documents_seen")
    unref = totals.get("parameters_documents_unreferenced_after")
    if seen is None:
        p("      *** the deletion-gate denominator is carried by no report, so")
        p("      *** nothing here bears on retiring the parameters class.")
        return
    p("      DELETION GATE: %d parameters document(s) over %d report(s)"
      % (seen, len(carried)))
    if seen == 0:
        p("      *** 0 seen -- the gate rows are VACUOUS in this run.")
    elif unref is not None:
        p("      %8d  unreferenced after the fold. EVIDENCE, NEVER" % unref)
        p("                AUTHORISATION: the corpora are a SAMPLE, and a class")
        p("                absent from the ones we test may be well represented")
        p("                in a dataset still waiting to migrate.")


def _rollup_lawn_plate_reading(totals, key_missing_in, carried, p):
    """The cross-corpus reading of the two-tier subject mint."""
    p("      THE TWO-TIER SUBJECTS -- the reading of the totals above")
    rows = _rollup_denominator(
        totals, key_missing_in, carried, "ontology_table_rows_seen",
        "ontology_table_row document(s)", p,
        when_absent=["These counters landed 2026-08-11."],
        when_zero=[
            "No corpus in this run holds an ontology_table_row, so every total",
            "above is VACUOUS -- including the spelling canary, which has no",
            "recognised table to anchor it.",
        ])
    if not rows:
        return
    recognised = (totals.get("plate_rows_seen", 0)
                  + totals.get("image_rows_seen", 0)
                  + totals.get("lawn_rows_seen", 0))
    p("      %8d  of them recognised as a plate/image/lawn table" % recognised)
    if recognised == 0:
        p("      *** NOTHING RECOGNISED ANYWHERE. Two different facts produce")
        p("      *** this and the run cannot separate them: no corpus was built")
        p("      *** by NDI's +setup/+conv/+haley/doImport.m (benign), or the")
        p("      *** column-token rule is wrong everywhere (not benign, and it")
        p("      *** forces the spelling canary to 0 as well). Do not read this")
        p("      *** as the token rule confirmed.")
        return
    unclassified = totals.get("unclassified_rows_in_those_sessions")
    if unclassified is None:
        p("      *** the spelling canary is carried by no report; whether the")
        p("      *** token rule matched everything is UNMEASURED.")
    elif unclassified > recognised:
        p("      *** SPELLING CANARY: %d unclassified row(s) beside %d"
          % (unclassified, recognised))
        p("      *** recognised, in the same sessions -- what a wrong")
        p("      *** column-token rule looks like. Chase it before reading any")
        p("      *** tier total as a corpus fact.")
    collisions = totals.get("local_identifier_collisions_within_batch")
    if collisions:
        # THIS BLOCK USED TO SAY THE DIRECTIVE WAS "refuted on real data" AND
        # IT COULD NOT KNOW THAT. The counter is batch-scoped and a batch spans
        # both Haley sessions, so it conflated the case that refutes the
        # directive with the case that does not. The verdict now comes from the
        # split, and when the split is absent the block says UNMEASURED rather
        # than choosing a verdict.
        p("      *** %d HANDLE COLLISION(S) across the run, on the team's"
          % collisions)
        p("      *** (experiment, plate, patch) identifier. This is for the")
        p("      *** TEAM; the pass does not choose another scheme on its own.")
        _collision_split_reading(totals, collisions, "      ", p)
    elif collisions == 0:
        p("      %8d  handle collision(s) -- the uniqueness premise holds over"
          % 0)
        p("                these corpora, which are a SAMPLE.")


def _rollup_bounded_extent_reading(totals, key_missing_in, carried, p):
    """The cross-corpus reading of the bounded-extent group, denominator first.

    THE NUMBER THAT WILL GET QUOTED off this block is "how many encounter
    windows did the migration drop", and the honest answer has three forms. A
    total of 0 refusals is only the third of them:

      no report carried the counters   UNMEASURED. The quantity does not exist
                                       in this run and the rollup says so.
      0 extents examined               VACUOUS. Nothing reached the extent read
                                       anywhere, so the zeros below describe the
                                       instrument, not the corpus.
      extents examined > 0             a real 0, over a stated denominator.

    The distinction is not academic here. The previous cross-corpus rollup for
    this pass (6 corpora, 640,651 documents) reported 0 refused and 106,639
    folded, and 20,411 of those folds had discarded their window. Every counter
    was right; none of them was measuring the thing that went wrong.
    """
    p("      BOUNDED EXTENTS -- the reading of the group above")
    if "bounded_extents_examined" not in totals:
        n_missing = len(key_missing_in.get("bounded_extents_examined") or [])
        p("      *** NOT CARRIED BY ANY OF THE %d REPORT(S) THAT RAN THE PASS"
          % len(carried))
        p("      *** (absent in %d). These counters landed 2026-08-11, so this"
          % (n_missing or len(carried)))
        p("      *** run has NOT MEASURED whether any window was dropped.")
        p("      *** That is UNMEASURED, and it is not the same as zero.")
        return
    examined = totals.get("bounded_extents_examined", 0)
    p("      DENOMINATOR: %d bounded extent(s) examined across %d report(s)"
      % (examined, len(carried)))
    if examined == 0:
        p("      *** 0 examined -- every extent counter above is VACUOUS. No")
        p("      *** bounded anchor reached the extent read in any corpus, so")
        p("      *** this is 'the rule could not fire', not 'nothing dropped'.")
        return
    dropped = (totals.get("refused_unreadable_extent_unit", 0)
               + totals.get("refused_malformed_extent", 0)
               + totals.get("refused_extent_without_start", 0))
    p("      %8d  bod(ies) REFUSED because their extent could not be carried"
      % dropped)
    p("      %8d  window(s) carried intact, %d half-window(s), %d with no "
      "window stated"
      % (totals.get("bounded_window_carried", 0),
         totals.get("bounded_start_only_carried", 0),
         totals.get("bounded_no_window_stated", 0)))
    if dropped == 0:
        p("      *** 0 refused over %d examined. The only emitter of" % examined)
        p("      *** session_bounded_reference in DID-matlab hard-codes the")
        p("      *** literal 's', so 0 is the EXPECTED reading -- and the")
        p("      *** corpora are a SAMPLE, so it is a fact about them and not")
        p("      *** evidence that no other unit exists anywhere.")


def digest(reports_dirs):
    """Return (lines, failed_paths). Never raises on a malformed report.

    reports_dirs is a root or a list of roots.
    """
    if isinstance(reports_dirs, str):
        reports_dirs = [reports_dirs]
    out, failed = [], []
    files, all_paths, dirs_walked = find_reports(reports_dirs)

    # RULE 5, the digest's own denominator, printed FIRST and unconditionally.
    # Run #3 printed "NO CORPUS REPORTS FOUND" and exited 0 while five
    # artifacts sat unread one directory deeper. "Found nothing" and "looked
    # in the wrong place" have to be distinguishable from the output alone.
    out.append("REPORT SEARCH: %d file(s) matching *-summary.json under %s "
               "(%d director(ies) walked, %d duplicate(s) collapsed)"
               % (len(all_paths), ", ".join(repr(d) for d in reports_dirs),
                  dirs_walked, len(all_paths) - len(files)))
    for path in files:
        out.append("  read: %s" % path)

    # RULE 5, second half of the leading denominator: how many batch post-passes
    # a V_eta run is expected to have executed, where that number was derived
    # from, and how many of them CANNOT be measured however many reports are
    # read. It prints BEFORE the reports are parsed and before any per-pass
    # detail, and it prints even when there are no reports at all -- a pass that
    # measures nothing is a fact about the pipeline, not about this input.
    try:
        render_pass_census(out)
    except Exception:
        out.append("  *** BATCH POST-PASS CENSUS FAILED -- the expected set is")
        out.append("  *** UNKNOWN for this run, not empty:")
        out.append(traceback.format_exc())
        failed.append("<pass-census>")

    if not files:
        out.append("NO CORPUS REPORTS FOUND (no *-summary.json at any depth "
                   "under %s)" % ", ".join(reports_dirs))
        for d in reports_dirs:
            if not os.path.isdir(d):
                out.append("  the directory itself does not exist: %s" % d)
        return (out, [MISSING_REPORTS])

    out.append("=" * 72)
    out.append("CORPUS CENSUS DIGEST  (%d corpus report(s))" % len(files))
    out.append("=" * 72)

    parsed = []
    for path in files:
        try:
            with open(path) as fh:
                r = json.load(fh)
        except Exception as exc:
            out.append("")
            out.append("%s: UNREADABLE (%s)" % (path, exc))
            failed.append(path)
            continue
        parsed.append(r)
        try:
            render_report(r, out)
        except Exception:
            # Isolate per corpus: one malformed report must not suppress the
            # other five. Run #256 lost its two largest corpora to exactly this.
            out.append("  *** DIGEST FAILED for this corpus -- output above is partial:")
            out.append(traceback.format_exc())
            failed.append(path)

    # Isolated the same way, and for the same reason: a defect in the ROLLUP
    # must not destroy six corpora's per-corpus output. That is precisely how
    # run #256 lost its two largest reports.
    try:
        for _finding in rollup(parsed, out) or []:
            # One sentinel however many rows disagreed: `failed` is rendered as
            # a list of report paths and a finding is not a path. The rows
            # themselves are already printed, in full, above.
            if EPOCH_POPULATIONS_DISAGREE not in failed:
                failed.append(EPOCH_POPULATIONS_DISAGREE)
    except Exception:
        out.append("")
        out.append("  *** CROSS-CORPUS ROLLUP FAILED -- per-corpus output above stands:")
        out.append(traceback.format_exc())
        failed.append("<rollup>")

    out.append("")
    out.append("=" * 72)
    return out, failed


def main(argv):
    reports_dirs = argv[1:] or ["corpus-reports"]
    lines, failed = digest(reports_dirs)
    print("\n".join(lines))
    if failed:
        print("DIGEST FAILED on %d report(s): %s" % (len(failed), ", ".join(failed)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
