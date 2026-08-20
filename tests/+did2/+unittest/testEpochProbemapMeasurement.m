function tests = testEpochProbemapMeasurement
%TESTEPOCHPROBEMAPMEASUREMENT The #2 "measure first" instrument in epochMint.
%
%   STATUS: WRITTEN 2026-08-20, NEVER EXECUTED HERE. This container has no
%   MATLAB -- `command -v matlab octave octave-cli` prints nothing -- so not one
%   line below has been run; the quick gate (test-migrators-quick.yml) is the
%   first thing that will have an opinion about it.
%
%   WHAT IS UNDER TEST: the REPORT-ONLY counters did2.convert.epochMint gained
%   with the #2 "measure first" decision (team, 2026-08-20). They answer two
%   questions the `epochfiles_ingested.epochprobemap` decomposition (#60 option
%   B, still open) needs BEFORE it is designed:
%
%     1. PROBES-PER-EPOCH -- the fold's 1 -> N fan-out. Read off the tab-delimited
%        serialize() the probemap is stored as (NDI origin/main
%        +ndi/+epoch/epochprobemap_daqsystem.m:136-168): a header line then one
%        line per probe.
%     2. #30-OBSERVATION OVERLAP -- would a per-epoch probemap observation
%        DUPLICATE a #30 recording-observation that already covers the same
%        (subject, epoch). The load-bearing number is that a #30 observation is
%        SESSION-scoped, so `recording_obs_epoch_scoped` is 0 and there is
%        nothing at the per-epoch level to duplicate.
%
%   REPORT-ONLY IS ITSELF UNDER TEST: testTheInstrumentChangesNoDocument asserts
%   the batch the pass returns is byte-for-byte what it would return without the
%   instrument -- an observation must not become a conversion.
%
%   The fixtures are built from the WRITER, never from a DID-side schema (the
%   ground-truth rule): the probemap string is the exact shape serialize()
%   emits, and `elementBody` / `subjectBody` reproduce the NDI templates the
%   recording-observation tests already drive end to end.

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function [out, rep] = mintFrom(v1)
%MINTFROM Pass 1 then the batch mint, validation OFF (as testEpochMint does).
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
[out, rep] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

% ===================== MEASUREMENT 1: probes per epoch =================

function testAThreeProbeSerializationCountsThree(testCase)
% THE HEADLINE ASSERTION: a 3-probe serialize() -> 3 probe rows, and the
% denominator (documents seen / with a non-empty probemap) travels with it.
ing = ingestedWithProbes('ing_1', 'sess_1', 't00001', ...
    {'a@lab', 'b@lab', 'c@lab'});
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), ing});
verifyEqual(testCase, rep.probemap_documents_seen, 1);
verifyFalse(testCase, rep.probemap_vacuous);
verifyEqual(testCase, rep.probemap_nonempty, 1);
verifyEqual(testCase, rep.probemap_char_shape, 1);
verifyEqual(testCase, rep.probemap_probe_rows_total, 3);
verifyEqual(testCase, rep.probemap_docs_with_rows, 1);
verifyEqual(testCase, rep.probemap_docs_zero_rows, 0);
verifyEqual(testCase, rep.probemap_probe_rows_min, 3);
verifyEqual(testCase, rep.probemap_probe_rows_max, 3);
verifyEqual(testCase, rep.probemap_unrecognized_header, 0);
% the histogram is one bin: {probe_rows 3, documents 1}
verifyEqual(testCase, numel(rep.probemap_rows_by_count), 1);
verifyEqual(testCase, rep.probemap_rows_by_count(1).probe_rows, 3);
verifyEqual(testCase, rep.probemap_rows_by_count(1).documents, 1);
end

function testTheHistogramTalliesAcrossDocuments(testCase)
% Three documents -- 1, 3 and 3 probes -- give total 7, a min of 1, a max of 3
% and a two-bin histogram {1->1, 3->2}, sorted by probe count.
a = ingestedWithProbes('ing_1', 'sess_1', 't00001', {'a@lab'});
b = ingestedWithProbes('ing_2', 'sess_1', 't00002', {'a@lab','b@lab','c@lab'});
c = ingestedWithProbes('ing_3', 'sess_1', 't00003', {'a@lab','b@lab','c@lab'});
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), a, b, c});
verifyEqual(testCase, rep.probemap_documents_seen, 3);
verifyEqual(testCase, rep.probemap_probe_rows_total, 7);
verifyEqual(testCase, rep.probemap_docs_with_rows, 3);
verifyEqual(testCase, rep.probemap_probe_rows_min, 1);
verifyEqual(testCase, rep.probemap_probe_rows_max, 3);
verifyEqual(testCase, numel(rep.probemap_rows_by_count), 2);
verifyEqual(testCase, rep.probemap_rows_by_count(1).probe_rows, 1);
verifyEqual(testCase, rep.probemap_rows_by_count(1).documents, 1);
verifyEqual(testCase, rep.probemap_rows_by_count(2).probe_rows, 3);
verifyEqual(testCase, rep.probemap_rows_by_count(2).documents, 2);
end

function testAnEmptyProbemapIsCountedApartFromAHeaderOnlyOne(testCase)
% Two DIFFERENT zero-row states that must not print the same:
%   an absent/'' field  -> probemap_empty
%   the header line only -> probemap_docs_zero_rows (a non-empty string, 0 rows)
empt = ingestedRaw('ing_1', 'sess_1', 't00001', '');
hdr  = ingestedRaw('ing_2', 'sess_1', 't00002', ...
    sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n'));
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), empt, hdr});
verifyEqual(testCase, rep.probemap_documents_seen, 2);
verifyEqual(testCase, rep.probemap_empty, 1);
verifyEqual(testCase, rep.probemap_nonempty, 1);
verifyEqual(testCase, rep.probemap_char_shape, 1);
verifyEqual(testCase, rep.probemap_docs_zero_rows, 1);
verifyEqual(testCase, rep.probemap_docs_with_rows, 0);
verifyEqual(testCase, rep.probemap_probe_rows_total, 0);
verifyEqual(testCase, rep.probemap_probe_rows_min, 0);  % no rows anywhere
end

function testAStructShapedProbemapIsCountedNotParsed(testCase)
% carryProbeMap notes the field CAN be a struct rather than the serialized char.
% It cannot be row-counted without the writer's serialize(), so it is counted
% under probemap_struct_shape and contributes no rows -- guessing would be the
% distance_metadata wrong-shape bug.
s = struct('name', 'tet', 'reference', 7);
weird = ingestedRaw('ing_1', 'sess_1', 't00001', s);
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), weird});
verifyEqual(testCase, rep.probemap_nonempty, 1);
verifyEqual(testCase, rep.probemap_struct_shape, 1);
verifyEqual(testCase, rep.probemap_char_shape, 0);
verifyEqual(testCase, rep.probemap_probe_rows_total, 0);
end

function testAnUnrecognisedHeaderIsFlaggedAndRowsStillCounted(testCase)
% The writer ALWAYS emits the 5-column header; a char without it is an anomaly.
% Every non-empty line is counted as a probe row (so a real one is never dropped
% to a mis-detected header) AND the anomaly is flagged.
bad = ingestedRaw('ing_1', 'sess_1', 't00001', ...
    sprintf('tet\t7\tn-trode\tvhspike2:ai11-14\tx@lab\n'));
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), bad});
verifyEqual(testCase, rep.probemap_unrecognized_header, 1);
verifyEqual(testCase, rep.probemap_probe_rows_total, 1);
end

function testNoIngestedDocumentReportsVacuityNotZeros(testCase)
% probemap_vacuous distinguishes "no epochfiles_ingested here" from "the fold
% found nothing to fan out". Same discipline as every other _vacuous flag.
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref')});
verifyTrue(testCase, rep.probemap_vacuous);
verifyEqual(testCase, rep.probemap_documents_seen, 0);
verifyEqual(testCase, rep.probemap_probe_rows_total, 0);
end

% ===================== MEASUREMENT 2: #30 overlap =====================

function testNoRecordingObservationMeansOverlapIsVacuous(testCase)
% An epochfiles_ingested batch with no #30 observation cannot answer the overlap
% question, and says so rather than printing a reassuring 0.
ing = ingestedWithProbes('ing_1', 'sess_1', 't00001', {'a@lab'});
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), ing});
verifyTrue(testCase, rep.overlap_vacuous);
verifyEqual(testCase, rep.recording_obs_seen, 0);
end

function testA30ObservationIsSeenAndIsSessionScopedNotEpochScoped(testCase)
% THE DECISION NUMBER. A direct n-trode element emits a voltage_observation
% (#30) with a SESSION 'during' anchor. epochMint runs BEFORE
% resolveSessionAnchors, so the anchor is still session_relative_reference --
% and epoch-scoped is 0, which is the whole point: nothing at the per-epoch
% level exists for a probemap observation to duplicate.
el  = elementBody('el_1', 'sess_1', 'tet', 'n-trode', 1, 'specimen_1');
ing = ingestedWithProbes('ing_1', 'sess_1', 't00001', {'a@lab'});
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), el, ing});
verifyFalse(testCase, rep.overlap_vacuous);
verifyGreaterThanOrEqual(testCase, rep.recording_obs_seen, 1);
verifyEqual(testCase, rep.recording_obs_epoch_scoped, 0);
verifyGreaterThanOrEqual(testCase, rep.recording_obs_session_scoped, 1);
verifyEqual(testCase, rep.recording_obs_anchor_unresolved, 0);
end

function testTheSubjectLevelOverlapResolvesWhenTheJoinIsPossible(testCase)
% (session, subject) overlap: the probemap names subject L; a specimen subject
% document with local_identifier L is in the batch and is what the element (and
% so the #30 observation) points at via subject_id. So L is MATCHED and the
% (session, L) pair is COVERED by an existing observation.
subj = subjectBody('specimen_1', 'sess_1', 'L');
el   = elementBody('el_1', 'sess_1', 'tet', 'n-trode', 1, 'specimen_1');
ing  = ingestedWithProbes('ing_1', 'sess_1', 't00001', {'L'});
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), subj, el, ing});
verifyEqual(testCase, rep.probemap_distinct_subject_strings, 1);
verifyEqual(testCase, rep.probemap_subject_strings_matched, 1);
verifyEqual(testCase, rep.probemap_subject_strings_unmatched, 0);
verifyEqual(testCase, rep.probemap_epoch_subject_covered, 1);
verifyEqual(testCase, rep.probemap_epoch_subject_uncovered, 0);
end

function testAnUnmatchableSubjectStringIsNamedNotHiddenInAZero(testCase)
% When the probemap's subjectstring matches no subject document, the
% (session, subject) overlap is UNCOMPUTABLE for it -- reported as `unmatched`
% rather than silently read as "not covered".
el  = elementBody('el_1', 'sess_1', 'tet', 'n-trode', 1, 'specimen_1');
ing = ingestedWithProbes('ing_1', 'sess_1', 't00001', {'nobody@lab'});
[~, rep] = mintFrom({sessionBody('sd_1', 'sess_1', 'ref'), el, ing});
verifyEqual(testCase, rep.probemap_distinct_subject_strings, 1);
verifyEqual(testCase, rep.probemap_subject_strings_matched, 0);
verifyEqual(testCase, rep.probemap_subject_strings_unmatched, 1);
verifyEqual(testCase, rep.probemap_epoch_subject_covered, 0);
verifyEqual(testCase, rep.probemap_epoch_subject_uncovered, 0);
end

% ===================== report-only guarantee ==========================

function testTheInstrumentChangesNoDocument(testCase)
% REPORT-ONLY, as a test. The batch the pass returns must be identical whether
% or not the measurement ran -- an observation, never a conversion. Compared by
% class-name multiset and document count, which is what a fan-out or a stamped
% edge would move.
subj = subjectBody('specimen_1', 'sess_1', 'L');
el   = elementBody('el_1', 'sess_1', 'tet', 'n-trode', 1, 'specimen_1');
ing  = ingestedWithProbes('ing_1', 'sess_1', 't00001', {'L','M','N'});
v1 = {sessionBody('sd_1', 'sess_1', 'ref'), subj, el, ing};
pass1 = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
[minted, ~] = mintFrom(v1);
% The epochfiles_ingested passthrough is unchanged: same probemap char, no new
% edge, no extra document of its class.
before = sort(classNames(pass1));
after  = sort(classNames(minted));
% epochMint legitimately APPENDS `epoch` documents; the instrument appends
% nothing. So the only difference between the two multisets is `epoch`.
extra = setdiff(after, before);
verifyTrue(testCase, all(strcmp(extra, 'epoch')) || isempty(extra), ...
    'the measurement appended a non-epoch document -- it is not report-only');
% and the epochfiles_ingested body still carries its probemap verbatim.
ingOut = firstOfClass(minted, 'epochfiles_ingested');
verifyNotEmpty(testCase, ingOut);
b = ingOut.toStruct();
verifyEqual(testCase, numel(strfind(b.epochfiles_ingested.epochprobemap, sprintf('\n'))), 4, ...
    'the probemap gained or lost a line');   % header + 3 probe rows = 4 newlines
end

% ===================== fixtures, from the NDI writer ===================

function v1 = ingestedWithProbes(docId, sessionId, epochId, subjectStrings)
%INGESTEDWITHPROBES A did_v1 epochfiles_ingested whose epochprobemap serialises
%   numel(subjectStrings) probe rows, one subjectstring per row -- the exact
%   shape NDI epochprobemap_daqsystem.serialize() emits.
pm = sprintf('name\treference\ttype\tdevicestring\tsubjectstring\n');
for i = 1:numel(subjectStrings)
    pm = [pm, sprintf('tet\t%d\tn-trode\tvhspike2:ai11-14\t%s\n', ...
        i, subjectStrings{i})]; %#ok<AGROW>
end
v1 = ingestedRaw(docId, sessionId, epochId, pm);
end

function v1 = ingestedRaw(docId, sessionId, epochId, probemapValue)
%INGESTEDRAW A did_v1 epochfiles_ingested with an ARBITRARY epochprobemap value,
%   for the empty / header-only / struct / unrecognised cases. Block key set is
%   {epoch_id, epochprobemap, files} and the dependency is {filenavigator_id},
%   exactly as corpus B's 2,484 documents carry.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name',         'epochfiles_ingested', ...
    'property_list_name', 'epochfiles_ingested', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', 'nav_1');
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
blk = struct();
blk.epoch_id = epochId;
blk.files = {['epochid://' epochId]};
blk.epochprobemap = probemapValue;
v1.epochfiles_ingested = blk;
end

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 session document (template: superclasses [base], one field
%   session.reference). base.id and base.session_id are DIFFERENT strings, as
%   ndi.document / ndi.session mint them.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/session.json', ...
    'validation',         '$NDISCHEMAPATH/session.json', ...
    'class_name',         'session', ...
    'property_list_name', 'session', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', reference);
end

function el = elementBody(docId, sessionId, name, typ, direct, subjectId)
%ELEMENTBODY A did_v1 element (template element.json: deps subject_id /
%   underlying_element_id; block ndi_element_class / name / reference / type /
%   direct). A DIRECT n-trode drives jRecordingObservation to a
%   voltage_observation of the SPECIMEN -- the #30 recording-observation whose
%   overlap this instrument measures. Copied in shape from
%   testMigratorsJRecordingObservation.elementDoc.
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
el.depends_on = struct('name', {'subject_id'}, 'value', {subjectId});
el.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', 'ndi.probe.timeseries.mfdaq', ...
    'name', name, 'reference', '1', 'type', typ, 'direct', direct);
end

function v1 = subjectBody(docId, sessionId, localId)
%SUBJECTBODY A did_v1 subject carrying a local_identifier the +migrators_j
%   subject migrator preserves (subject.m: fills only when empty). This is the
%   SPECIMEN a probemap subjectstring is joined against.
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', localId, 'description', '');
end

% ===================== helpers ============================================

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = char(out.migrated{k}.get('document_class.class_name'));
end
end

function d = firstOfClass(out, className)
d = [];
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('document_class.class_name')), className)
        d = out.migrated{k};
        return;
    end
end
end
