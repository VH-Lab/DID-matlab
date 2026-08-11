function tests = testTimeReferenceCollapse
%TESTTIMEREFERENCECOLLAPSE The time-reference collapse (#65): 8 classes -> 2.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   nothing in this file has been run. The quick gate (test-migrators-quick.yml)
%   is the first thing that will have an opinion.
%
%   STATUS 2026-08-11, for the two unit tests added at the end of the bounded
%   section: SAME. `command -v matlab octave octave-cli` returns nothing in the
%   container they were written in, so they have not been run either, and CI is
%   their first execution. Nothing below should be read as measured.
%
%   ALSO ADDED 2026-08-11: a docstring on `durationCell` recording that it is a
%   hand copy which ADDED a `seconds` the emitter never writes, which is why the
%   20,411-document extent loss survived this file. Read it before copying that
%   fixture; `emitterDurationCell` next to it is the emitter's real shape.
%
%   NEW FILE, deliberately. `testMigratorsJ.m` is owned by another session and is
%   not touched.
%
%   WHAT IS UNDER TEST: did2.convert.resolveSessionAnchors, the BATCH post-pass
%   that folds `session_relative_reference` (107,308 documents) and
%   `session_bounded_reference` (20,411) into `relative_reference`.
%
%   WHY A BATCH PASS. `relative_reference.relative_to` is REQUIRED, and a pass-1
%   migrator CANNOT fill it: it holds `base.session_id`, while the edge needs the
%   session DOCUMENT's `base.id`, and NDI mints those independently
%   (+ndi/document.m:57-58 vs +ndi/session.m:215). The two are visibly different
%   strings in every fixture below, on purpose, so a test that confused them
%   would FAIL rather than pass by coincidence.
%
%   THE TWO INVARIANTS THIS FILE EXISTS TO PROTECT, both of which have burned
%   this project before at smaller scale:
%
%     1. THE ID IS PRESERVED. Dissolving a document that other documents point at
%        dangles every edge -- Soph went red with 11,448 such orphans. Every
%        anchor here is pointed at by a `time_reference_#` edge, so the fold is
%        id-preserving 1 -> 1, the shape jCalculation already proved at 0 orphans.
%     2. NOTHING IS EMITTED WITH AN EMPTY REQUIRED EDGE. An anchor whose session
%        document is absent is LEFT ALONE and COUNTED, never given an empty
%        `relative_to`. `+did2/+validate/references.m:90` skips empty edges, so a
%        husk would validate clean and no gate would see it -- the
%        invented-empty-edge pattern, which at 127,719 documents would be ten
%        times the largest instance yet recorded.
%
%   FIXTURES ARE COPIED FROM THE LIVE EMITTERS, not composed from a V_eta schema
%   -- the standing rule after migrators were found to have been written against
%   DID-schema's own V_alpha snapshot. Each builder names its source line.
%
%   Run with:  results = runtests('did2.unittest.testTimeReferenceCollapse');

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function [out, rep] = foldFrom(v1)
%FOLDFROM Pass 1 then the batch fold, with validation OFF.
%   Validation needs the assembled V_eta schema set on DID_SCHEMA_PATH; the one
%   test that requires it says so and calls with Validate true.
out = runJ(v1);
[out, rep] = did2.convert.resolveSessionAnchors(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = char(out.migrated{k}.get('document_class.class_name'));
end
end

function docs = ofClass(out, className)
docs = {};
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('document_class.class_name')), className)
        docs{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
end

function d = oneOfClass(testCase, out, className)
docs = ofClass(out, className);
verifyNumElements(testCase, docs, 1, ...
    sprintf('expected exactly one %s, found %d', className, numel(docs)));
d = docs{1};
end

function v = depValue(b, name)
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if ~isfield(deps(k), 'name') || ~strcmp(char(deps(k).name), name); continue; end
    if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
    elseif isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v = char(deps(k).value);
    end
    return;
end
end

% ===================== fixtures ========================================

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 `session` document.
%
%   TEMPLATE (git show origin/main:src/ndi/ndi_common/database_documents/\
%   session.json): superclasses [base], no depends_on, ONE field
%   `session.reference`.
%
%   WRITER (+ndi/+session/dir.m:138-140):
%       g = ndi.document('session','session.reference',...reference) + ...
%           ndi_session_dir_obj.newdocument();
%       ndi_session_dir_obj.database_add(g);
%
%   DOCID AND SESSIONID ARE DIFFERENT STRINGS BY CONSTRUCTION. `ndi.document.m:57-58`
%   sets base.id from a fresh ndi.ido(); `+ndi/session.m:215` appends
%   base.session_id from session.id(). The whole reason this pass exists is that
%   only the batch can map one to the other.
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

function b = anchorBody(docId, sessionId, relation)
%ANCHORBODY A V_eta `session_relative_reference`, copied field-for-field from the
%   live emitter +migrators_j/private/jSessionAnchor.m:19-27. Tagged
%   schema_version V_eta so v1_to_v2 short-circuits it (isAlreadyTarget) to
%   ensureClassBlocks + validate -- the same door epochMint's rebuild uses.
b = struct();
b.document_class = struct('class_name', 'session_relative_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'migrated_session_anchor', 'datestamp', '2024-06-01T12:00:00.000Z');
b.time_reference = struct('is_approximate', true);
b.session_relative_reference = struct('relation', relation);
end

function b = boundedBody(docId, sessionId, onsetSeconds, offsetSeconds)
%BOUNDEDBODY A V_eta `session_bounded_reference`, copied from the live emitter
%   +migrators_j/ontology_table_row.m:262-269 (makeEncounterWindow): the
%   C. elegans encounter window, onset..offset relative to the session origin.
b = struct();
b.document_class = struct('class_name', 'session_bounded_reference', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'migrated_encounter_window', 'datestamp', '2024-06-01T12:00:00.000Z');
b.time_reference = struct('is_approximate', false);
b.session_bounded_reference = struct('relation', 'during', ...
    'start', durationCell(onsetSeconds), 'end', durationCell(offsetSeconds));
end

function c = durationCell(seconds)
%DURATIONCELL A duration cell carrying BOTH the canonical `seconds` and the
%   source pair.
%
%   READ THIS BEFORE COPYING IT. It is a HAND COPY of the emitter that ADDED a
%   field the emitter never writes. `ontology_table_row.m`'s `durationSeconds`
%   (its function, near the bottom of the file) writes exactly three keys:
%
%       d = struct('source_unit', 's', 'source_value', double(x), ...
%           'approximate', false);
%
%   -- no `seconds`. `cellField` used to require `seconds` and nothing else, so
%   every real bounded window in the corpus folded with its extent silently
%   dropped (20,411 documents) while this fixture, carrying the extra field,
%   stayed green. The defect lived in the gap between the two shapes.
%   testSessionAnchorEmitterContract.m found it by driving the real migrator.
%
%   This fixture is LEFT AS IT IS: it exercises the already-canonical cell,
%   which is a real shape (jClockAlignmentBodies, jEpochClockReferences and
%   resolveValidIntervals all write `seconds`), and changing it would weaken the
%   tests above that depend on it. What must not happen is a SECOND fixture with
%   the same flaw -- see `emitterDurationCell` below, which is the emitter's
%   three-key shape exactly.
c = struct('seconds', double(seconds), 'source_unit', 's', ...
    'source_value', double(seconds), 'approximate', false);
end

function c = emitterDurationCell(unit, value)
%EMITTERDURATIONCELL The emitter's duration cell EXACTLY -- three keys, NO
%   `seconds` -- with the unit string as a parameter.
%
%   THE THREE KEYS AND THEIR ORDER ARE THE EMITTER'S, copied from
%   src/did/+did2/+convert/+migrators_j/ontology_table_row.m `durationSeconds`:
%
%       d = struct('source_unit', 's', 'source_value', double(x), ...
%           'approximate', false);
%
%   THE UNIT IS THE ONLY THING THIS PARAMETERISES, and that is the point: the
%   sole emitter of `session_bounded_reference` in this repository hard-codes
%   the literal 's', so NO MIGRATOR CAN PRODUCE A NON-SECONDS UNIT TODAY and the
%   refusal branch in `isSecondsUnit` cannot be reached from any real document.
%   A HAND-BUILT BODY IS THEREFORE THE ONLY WAY TO DRIVE IT, and that is the
%   whole justification for departing from this file's standing rule that
%   fixtures are copied from the live emitter. It is stated here rather than
%   assumed because a hand-built fixture is exactly what hid the defect above.
c = struct('source_unit', unit, 'source_value', double(value), ...
    'approximate', false);
end

function b = emitterShapedBoundedBody(docId, sessionId, unit, onset, offset)
%EMITTERSHAPEDBOUNDEDBODY `boundedBody` with its two duration cells replaced by
%   the emitter's three-key shape in the named unit.
%
%   Built by MUTATING `boundedBody` rather than by re-transcribing it, so the
%   difference between the two fixtures is visible in these two lines and cannot
%   drift: everything else -- class name, version, superclasses, schema_version,
%   base, the empty depends_on, `is_approximate`, `relation` -- is whatever
%   `boundedBody` says, which is the emitter's `makeEncounterWindow`.
b = boundedBody(docId, sessionId, onset, offset);
b.session_bounded_reference.start = emitterDurationCell(unit, onset);
b.session_bounded_reference.end   = emitterDurationCell(unit, offset);
end

function b = pointerBody(docId, sessionId, anchorId)
%POINTERBODY A minimal already-V_eta document holding a `time_reference_1` edge,
%   standing in for every migrated subject_interaction / directed_relation. Its
%   only job is to make the ORPHAN question askable: after the fold, does this
%   edge still resolve?
b = struct();
b.document_class = struct('class_name', 'directed_relation', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'relation', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', 'time_reference_1', 'value', anchorId);
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'migrated_encounter', 'datestamp', '2024-06-01T12:00:00.000Z');
b.directed_relation = struct('relation', struct('node', '', 'name', 'encountered'));
end

% ===================== the report is an instrument =====================

function testTheReportStatesItsDenominatorFirst(testCase)
% Operating Rule 5. Every counter is defined before a document is read, so a
% pass that DID NOT RUN and a pass that ran and found nothing are different
% readings. silentLoss printed "0 empty edges" for two days while reading
% nothing; this is the check that stops the sequel.
[~, rep] = foldFrom({sessionBody('sess_doc_1', 'SID_1', 'ref')});
expected = {'documents_inspected', 'documents_unreadable', ...
    'session_documents_seen', 'anchors_seen', 'anchors_relative', ...
    'anchors_bounded', 'anchors_folded', 'refused_no_session_id', ...
    'refused_no_session_document', 'refused_ambiguous_session', ...
    'refused_ambiguous_relation', 'refused_unknown_relation', ...
    'refused_negative_extent', 'refused_total', 'fold_quarantined', 'ran'};
for k = 1:numel(expected)
    verifyTrue(testCase, isfield(rep, expected{k}), ...
        sprintf('report is missing the field %s', expected{k}));
end
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 1);
verifyEqual(testCase, rep.anchors_seen, 0);
end

function testAnEmptyBatchReportsRatherThanReturningSilently(testCase)
out = struct('migrated', {{}}, 'quarantine', {{}});
[out, rep] = did2.convert.resolveSessionAnchors(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyTrue(testCase, isfield(out, 'session_anchor_fold'));
end

function testANonEtaTargetIsUntouched(testCase)
% relative_reference exists only in V_eta. V_zeta / V_epsilon still have the
% eight-class family and their migrators (+migrators_i, +migrators_e) still emit
% into it, so this pass must be a no-op there -- `ran` false is the proof it
% declined rather than silently found nothing.
out = runJ({anchorBody('anchor_1', 'SID_1', 'during')});
[out, rep] = did2.convert.resolveSessionAnchors(out, ...
    'Validate', false, 'TargetVersion', 'V_zeta');
verifyFalse(testCase, rep.ran);
verifyEqual(testCase, classNames(out), {'session_relative_reference'});
end

% ===================== the fold itself =================================

function testTheAnchorBecomesARelativeReferenceOnTheSessionDOCUMENT(testCase)
% THE TEST. `relative_to` must carry the session DOCUMENT's base.id
% ('sess_doc_1'), NOT the session id every sibling document carries ('SID_1').
% Confusing them is the failure mode the whole pass exists to avoid, and the
% fixture makes the two strings visibly different so a mix-up cannot pass.
[out, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});

verifyEqual(testCase, rep.session_documents_seen, 1);
verifyEqual(testCase, rep.anchors_seen, 1);
verifyEqual(testCase, rep.anchors_relative, 1);
verifyEqual(testCase, rep.anchors_folded, 1);
verifyEqual(testCase, rep.refused_total, 0);

ref = oneOfClass(testCase, out, 'relative_reference');
verifyEqual(testCase, depValue(ref.toStruct(), 'relative_to'), 'sess_doc_1');
verifyNotEqual(testCase, depValue(ref.toStruct(), 'relative_to'), 'SID_1');
% and the old class is gone from the batch
verifyFalse(testCase, any(strcmp(classNames(out), 'session_relative_reference')));
end

function testTheIdIsPreservedSoNothingDangles(testCase)
% The anti-orphan invariant. A pointer document holds `time_reference_1` ->
% anchor_1 before the fold; after it, the same id must still name a document in
% the batch. Minting a replacement instead would have dangled it -- the
% 11,448-orphan dissolution failure, one order of magnitude larger.
[out, ~] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during'), ...
    pointerBody('rel_1', 'SID_1', 'anchor_1')});

ref = oneOfClass(testCase, out, 'relative_reference');
verifyEqual(testCase, char(ref.get('base.id')), 'anchor_1');

pointer = oneOfClass(testCase, out, 'directed_relation');
target = depValue(pointer.toStruct(), 'time_reference_1');
verifyEqual(testCase, target, 'anchor_1');
ids = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(ids, target)), ...
    'the time_reference_1 edge no longer resolves -- the fold orphaned it');
end

function testRelationBecomesAnOwlTimeTerm(testCase)
% CHANGE 3 / the T8 repair: the v1 `relation` was a bare char enum covering 6 of
% Allen's 13. `during` -- the value at all 14 live emitter sites -- becomes the
% real W3C CURIE. The `time:` prefix is registered in CURIE_lookups_meta.json
% (http://www.w3.org/2006/time#), so unlike the did_clocktype terms this node is
% NOT staged empty.
[out, ~] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});
ref = oneOfClass(testCase, out, 'relative_reference');
verifyEqual(testCase, char(ref.get('relative_reference.value.relation.node')), ...
    'time:intervalDuring');
verifyEqual(testCase, char(ref.get('relative_reference.value.relation.name')), ...
    'intervalDuring');
end

function testTheOrdinalAnchorCarriesNoMetric(testCase)
% NO TIMES => NO REFERENCE, applied inside a document. "During the session" is
% all jSessionAnchor knows, so the folded document must carry NO start and NO
% duration -- not zeros. A 0 s offset would be a fabricated fact and exactly the
% hollow value silentLoss exists to find.
[out, ~] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});
value = oneOfClass(testCase, out, 'relative_reference').get('relative_reference.value');
verifyFalse(testCase, isfield(value, 'start'));
verifyFalse(testCase, isfield(value, 'duration'));
end

function testTheDeprecatedApproximateFlagIsDropped(testCase)
% CHANGE 2. `time_reference.is_approximate` was a hardcoded `true` at all eleven
% writers, expressing "we do not know exactly when" -- which having no start and
% no duration already says. THE ABSENCE IS THE IMPRECISION. The folded document
% must not carry it, and the old class block must be gone too (a leftover would
% trip did2:validation:undeclaredBlock on the new class).
[out, ~] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});
s = oneOfClass(testCase, out, 'relative_reference').toStruct();
verifyFalse(testCase, isfield(s, 'session_relative_reference'));
if isfield(s, 'time_reference')
    verifyFalse(testCase, isfield(s.time_reference, 'is_approximate'), ...
        'the deprecated root flag survived the fold');
end
end

% ===================== the bounded window ==============================

function testTheBoundedWindowsEndBecomesADuration(testCase)
% CHANGE 1. `end` is replaced by `duration`, because a fuzzy anchor makes two
% offsets both fuzzy and the exactness of their DIFFERENCE unrecoverable. The
% window 12 s .. 47 s becomes start 12 s + duration 35 s -- informationally
% identical (end = start + duration) and separately qualifiable.
[out, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    boundedBody('window_1', 'SID_1', 12, 47)});

verifyEqual(testCase, rep.anchors_bounded, 1);
verifyEqual(testCase, rep.anchors_folded, 1);
ref = oneOfClass(testCase, out, 'relative_reference');
verifyEqual(testCase, ref.get('relative_reference.value.start.seconds'), 12);
verifyEqual(testCase, ref.get('relative_reference.value.duration.seconds'), 35);
verifyFalse(testCase, ...
    isfield(ref.get('relative_reference.value'), 'end'));
end

function testTheExtentClaimsNoSourceProvenanceItDoesNotHave(testCase)
% The source wrote two OFFSETS, never a span. Filling `source_unit` /
% `source_value` on the computed duration would claim a provenance that does not
% exist -- the distance_metadata assumed-shape error, which is what a migrator
% inventing a shape looks like. The ANCHOR keeps its real provenance.
[out, ~] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    boundedBody('window_1', 'SID_1', 12, 47)});
ref = oneOfClass(testCase, out, 'relative_reference');
verifyEqual(testCase, char(ref.get('relative_reference.value.start.source_unit')), 's');
extent = ref.get('relative_reference.value.duration');
verifyFalse(testCase, isfield(extent, 'source_value'));
end

function testANegativeExtentIsRefusedNotStored(testCase)
% A window whose end precedes its start is not a window. Refusing it leaves the
% document exactly as it was and MOVES A NUMBER; storing a negative duration
% would be a silent corruption that validates.
[out, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    boundedBody('window_1', 'SID_1', 47, 12)});
verifyEqual(testCase, rep.refused_negative_extent, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, rep.refused_total, 1);
verifyEqual(testCase, classNames(out), ...
    {'session', 'session_bounded_reference'});
end

% ---- the unit the fold will not read --------------------------------------
%
% `cellField` derives the canonical `seconds` from a source pair ONLY when
% `isSecondsUnit` says the pair DECLARES seconds. The other arm of that `if` --
% the refusal -- had no driven coverage anywhere in this repository before the
% two tests below: every duration cell any emitter can produce carries either a
% canonical `seconds` already or `durationSeconds`'s literal 's'. So the branch
% is reachable only from a hand-built body, and these drive it with one that
% differs from the emitter's output in the unit string and in nothing else.

function testAWindowInAUnitTheFoldCannotReadKeepsNoExtent(testCase)
% THE REFUSAL BRANCH. A source pair whose unit `isSecondsUnit` cannot read is
% NOT read as seconds: the cell stays ABSENT, so the folded document carries no
% `start` and no `duration` rather than a number rescaled by a guessed factor.
% Reading `source_value: 1249.72, source_unit: 'ms'` as 1249.72 SECONDS would be
% a 1000x error that validates cleanly -- the distance_metadata assumed-shape
% failure with a unit attached.
%
% WHAT THIS TEST DOES NOT CLAIM, stated because a green here is easy to
% over-read: an unreadable unit moves NO refusal counter. `anchors_folded` goes
% up, `refused_total` stays 0, and the window is absent from the folded
% document. That is the same instrument shape as the defect this branch was
% written during -- a loss every counter reports as clean -- and it is pinned
% here as the CURRENT BEHAVIOUR, not endorsed. It costs nothing today because no
% emitter can produce such a unit; it would cost a corpus the day one can.
units = {'ms', 'minutes', 'msec', ''};
for k = 1:numel(units)
    unit = units{k};
    label = unit;
    if isempty(label); label = '<empty>'; end
    [out, rep] = foldFrom({ ...
        sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
        emitterShapedBoundedBody('window_1', 'SID_1', unit, 12, 47)});

    % the document still folds -- the refusal is about the CELL, not the anchor
    verifyEqual(testCase, rep.anchors_bounded, 1, label);
    verifyEqual(testCase, rep.anchors_folded, 1, label);
    verifyEqual(testCase, rep.refused_total, 0, label);

    ref = oneOfClass(testCase, out, 'relative_reference');
    value = ref.get('relative_reference.value');
    verifyFalse(testCase, isfield(value, 'start'), sprintf( ...
        ['source_unit ''%s'' was read as seconds: the fold set `start` from a ' ...
         'unit isSecondsUnit refuses. An unreadable unit must leave the cell ' ...
         'ABSENT.'], label));
    verifyFalse(testCase, isfield(value, 'duration'), sprintf( ...
        ['source_unit ''%s'' produced a `duration`, so both offsets were read ' ...
         'as seconds and subtracted.'], label));
end
end

function testTheSameBodyInASecondsUnitIsRead(testCase)
% THE CONTROL, and it is load-bearing rather than decorative. Without it the
% test above would pass just as well if `emitterShapedBoundedBody` were broken in
% a way that had nothing to do with the unit -- a misspelled block, a class name
% the fold ignores -- and "the fold refused the unit" and "the fold never saw
% the document" are not the same finding. Here the SAME builder, differing only
% in the unit string, must produce the extent.
%
% It also drives the four accepted spellings other than the emitter's literal
% 's'. Those are as unemittable as the refused ones -- `durationSeconds`
% hard-codes 's' -- so the accept list and the refuse list are covered by the
% same hand-built body, which is the only thing that can reach either.
units = {'s', 'sec', 'secs', 'second', 'seconds'};
for k = 1:numel(units)
    unit = units{k};
    [out, rep] = foldFrom({ ...
        sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
        emitterShapedBoundedBody('window_1', 'SID_1', unit, 12, 47)});
    verifyEqual(testCase, rep.anchors_folded, 1, unit);
    verifyEqual(testCase, rep.refused_total, 0, unit);

    ref = oneOfClass(testCase, out, 'relative_reference');
    value = ref.get('relative_reference.value');
    verifyTrue(testCase, isfield(value, 'start'), sprintf( ...
        ['source_unit ''%s'' DECLARES seconds and the fold dropped the start ' ...
         'anyway -- the 20,411-document defect, in a spelling isSecondsUnit ' ...
         'accepts.'], unit));
    verifyEqual(testCase, value.start.seconds, 12, unit);
    verifyEqual(testCase, value.duration.seconds, 35, unit);
    % the derived canonical value does not disturb the provenance it was derived
    % FROM: the cell still says exactly what the source said.
    verifyEqual(testCase, char(value.start.source_unit), unit, unit);
    verifyEqual(testCase, value.start.source_value, 12, unit);
end
end

% ===================== what it refuses to guess ========================

function testNoSessionDocumentLeavesTheAnchorAloneAndCountsIt(testCase)
% The DELETION GATE, stated as a test. Without a session document there is no id
% to point at, so the anchor is left EXACTLY as it was and counted. It is NOT
% given an empty `relative_to`: references.m:90 skips empty edges, so 127,719
% husks would validate clean and no gate would see them.
%
% This is also why the six retiring classes may not be deleted yet -- a class
% with no schema and surviving documents is the epochfiles_ingested regression
% (2,484 quarantines).
[out, rep] = foldFrom({anchorBody('anchor_1', 'SID_1', 'during')});
verifyEqual(testCase, rep.refused_no_session_document, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, classNames(out), {'session_relative_reference'});
s = out.migrated{1}.toStruct();
verifyEmpty(testCase, depValue(s, 'relative_to'));
end

function testAnAnchorWithNoSessionIdIsRefused(testCase)
[out, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', '', 'during')});
verifyEqual(testCase, rep.refused_no_session_id, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyTrue(testCase, any(strcmp(classNames(out), 'session_relative_reference')));
end

function testTwoSessionDocumentsForOneSessionIdAreRefused(testCase)
% Two documents claiming one session id is a corpus this pass does not
% understand. Picking the first would be a guess with a 50% error rate.
[~, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    sessionBody('sess_doc_2', 'SID_1', 'exp1_again'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});
verifyEqual(testCase, rep.session_documents_seen, 2);
verifyEqual(testCase, rep.refused_ambiguous_session, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
end

function testConcurrentWithIsRefusedBecauseItIsGenuinelyAmbiguous(testCase)
% One of the three defects that put `relation` on an ontology: `concurrent_with`
% is ambiguous between OWL-Time's intervalEquals and intervalOverlaps. Choosing
% one would invent a fact. No live emitter writes it -- all 14 sites write
% 'during' -- so this costs nothing today and refuses to be wrong tomorrow.
[out, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'concurrent_with')});
verifyEqual(testCase, rep.refused_ambiguous_relation, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyTrue(testCase, any(strcmp(classNames(out), 'session_relative_reference')));
end

function testTheFiveUnambiguousRelationsAllMap(testCase)
% The other five members of the v1 enum map cleanly onto Allen's relations. They
% have no live emitter today, but the corpora are a SAMPLE of datasets, not the
% universe -- a value absent from the six we run may be well represented in a
% dataset still waiting to migrate, which is what this migration is for.
expected = { ...
    'before',      'time:intervalBefore'; ...
    'after',       'time:intervalAfter'; ...
    'at_start_of', 'time:intervalStarts'; ...
    'at_end_of',   'time:intervalFinishes'; ...
    'during',      'time:intervalDuring'};
for k = 1:size(expected, 1)
    [out, rep] = foldFrom({ ...
        sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
        anchorBody('anchor_1', 'SID_1', expected{k, 1})});
    verifyEqual(testCase, rep.anchors_folded, 1, expected{k, 1});
    ref = oneOfClass(testCase, out, 'relative_reference');
    verifyEqual(testCase, ...
        char(ref.get('relative_reference.value.relation.node')), ...
        expected{k, 2}, expected{k, 1});
end
end

function testAnUnknownRelationIsRefusedNotDefaultedToDuring(testCase)
% Defaulting an unrecognised value to 'during' would turn a value we do not
% understand into a confident claim -- the recurring epistemic error, in one
% line of code.
[~, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'sometime_around')});
verifyEqual(testCase, rep.refused_unknown_relation, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
end

% ===================== idempotence + validation ========================

function testRunningTwiceFoldsNothingTheSecondTime(testCase)
% ndi.migrate.local documents itself as idempotent: a re-run reads every
% document back and runs the post-passes again. After the first fold the
% documents are `relative_reference`, which this pass does not touch, so the
% second run must report zero anchors -- not fold them again.
[out, rep1] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});
verifyEqual(testCase, rep1.anchors_folded, 1);

[out2, rep2] = did2.convert.resolveSessionAnchors(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep2.anchors_seen, 0);
verifyEqual(testCase, rep2.anchors_folded, 0);
verifyEqual(testCase, numel(out2.migrated), numel(out.migrated));
end

function testTheFoldedDocumentValidatesAgainstItsSchema(testCase)
% The only test here that needs the assembled V_eta schema set on
% DID_SCHEMA_PATH. A fold that produced an invalid document would be worse than
% no fold, so this asserts the real validator accepts it.
out = runJ({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during')});
[out, rep] = did2.convert.resolveSessionAnchors(out, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.fold_quarantined, 0);
verifyEqual(testCase, rep.anchors_folded, 1);
verifyTrue(testCase, any(strcmp(classNames(out), 'relative_reference')));
end

function testAQuarantinedFoldKeepsTheOriginalDocument(testCase)
% Degrade to "not folded", never to "lost". The swap-back matches on base.id
% rather than on position precisely so a quarantined body cannot shift the
% others -- silent document loss is the failure this project has paid for most
% often.
[out, rep] = foldFrom({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    anchorBody('anchor_1', 'SID_1', 'during'), ...
    anchorBody('anchor_2', 'SID_1', 'during')});
verifyEqual(testCase, numel(out.migrated), 3);
verifyEqual(testCase, rep.anchors_seen, 2);
verifyEqual(testCase, rep.anchors_folded + rep.fold_quarantined, 2);
end
