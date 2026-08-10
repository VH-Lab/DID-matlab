function tests = testMigratorsJStimulusModel
%TESTMIGRATORSJSTIMULUSMODEL The stimulus model family at V_eta (#31).
%
%   Exercises the two migrators that implement the signed stimulus decision
%   (V_eta_stimulus_model_plan.md, TEAM-SIGN-OFF [stimulus], 2026-08-08 --
%   `timed_sequence` + `timed_sequence_manipulation`; the presentation is
%   DECOMPOSED AROUND ITS PRESERVED ID, not dissolved):
%
%     stimulus_presentation
%         -> GUARDED PASSTHROUGH. The decompose needs the migrated graph (the
%            subject is only reachable through the response link) and a
%            corpus-wide dedup of the distinct stimuli, so it is deferred to the
%            NDI second pass. Pass 1 rejects the invented `element_id` edge and
%            carries everything else intact.
%     control_stimulus_ids
%         -> control_designation (id PRESERVED), guarded passthrough when the
%            presentation edge is absent.
%
%   EVERY FIXTURE IS BUILT FROM THE WRITER, NOT FROM A DID-SIDE SCHEMA. The
%   shapes below are the ones NDI-matlab constructs on origin/main:
%
%     +ndi/+app/+stimulus/decoder.m:103-140
%         mystim(k)  = struct('parameters', data.parameters{k});     the dictionary
%         presentation_time(...) = struct('clocktype','stimopen','onset',
%                                         'offset','stimclose','stimevents')
%         stimulus_presentation = struct('presentation_order', data.stimid(:), ...
%                                        'stimuli', mystim);
%         nd = E.newdocument('stimulus_presentation', ..., 'epochid.epochid', ...)
%                  + ndi_app_stimulus_decoder_obj.newdocument();      <- the app block
%         nd = set_dependency_value(nd,'stimulus_element_id',ndi_element_stim.id());
%         nd = nd.add_file('presentation_time.bin', ...);
%     +ndi/+mock/+fun/stimulus_presentation.m       the same shape, independently
%     +ndi/+app/+stimulus/tuning_response.m:652-656 the control_stimulus_ids writer
%
%   Building a fixture from our own schema is what produced ~2,078
%   distance_metadata quarantines from a migrator whose unit test was green.
%
%   TWO VINTAGES OF `presentation_time` ARE EXERCISED, because both are real.
%   The current writer puts the per-trial timing in `presentation_time.bin` (the
%   inline line is commented out at decoder.m:133, "we now put this in a file"),
%   but the READER still branches on the inline block at decoder.m:154-157 with a
%   deprecation warning, the shipped TEMPLATE still declares it with all six
%   sub-fields, and NDI keeps a migration checklist for the change
%   (docs/developer_notes/stimulus_presentation_change.m).
%
%   THE DEPRECATED VINTAGE IS DELIBERATELY NOT VALIDATED HERE. V_eta's
%   stimulus_presentation tombstone does not declare `presentation_time`, so such
%   a document raises `did2:validation:undeclaredField` -- which is exactly why
%   check_tombstones.py grades this class BLOCKING. That is a schema repair
%   (DID-schema tools/build_v_eta.py), not a migrator repair, so the test here
%   pins that the migrator CARRIES the block rather than pretending it validates.
%   When the tombstone lands, add the vintage to the Validate=true batch.
%
%   ***** UNVERIFIED: THESE TESTS HAVE NEVER BEEN EXECUTED. *****
%   There is no MATLAB in the environment they were written in. They are written
%   against the pipeline's observed conventions, but "written carefully" is not
%   "run", and this project's own record says a test written from the same
%   premise as the code cannot catch the code. Treat the first CI run as the
%   first real evidence.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJStimulusModel');

tests = functiontests(localfunctions);
end

% ===================== fixtures (from the WRITER) ==========================

function v1 = presentationFixture()
%PRESENTATIONFIXTURE A did_v1 stimulus_presentation as decoder.m builds it TODAY
%   (per-trial timing in the file, not in the block).
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_presentation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
% decoder.m:138 -- the ONE dependency the class has, under NDI's own name.
v1.depends_on = struct('name', {'stimulus_element_id'}, 'value', {'stimelem_5f10a2'});
v1.base = struct('id', 'pres_b671ff', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
% The `+ ..._obj.newdocument()` term (decoder.m:135-137). v1 spells these
% `name`/`version`; universalRenames maps them to app_name/app_version.
v1.app = struct('name', 'ndi_app_stimulus_decoder', 'version', '1.2.3', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'GLNXA64', ...
    'os_version', '5.15.0', 'interpreter', 'MATLAB');
v1.epochid = struct('epochid', 't00003');
% :131-133 -- presentation_order is data.stimid(:), a COLUMN vector of 1-based
% indexes into `stimuli`; three distinct stimuli, two repeats each.
v1.stimulus_presentation = struct( ...
    'presentation_order', [1; 2; 3; 1; 2; 3], ...
    'stimuli', struct('parameters', { ...
        struct('angle', 0,  'sFrequency', 0.5, 'tFrequency', 4, 'contrast', 1), ...
        struct('angle', 90, 'sFrequency', 0.5, 'tFrequency', 4, 'contrast', 1), ...
        struct('isblank', 1)}));
% :137-138 -- add_file('presentation_time.bin', ...)
v1.files = struct('file_list', {{'presentation_time.bin'}});
end

function v1 = deprecatedVintageFixture()
%DEPRECATEDVINTAGEFIXTURE The pre-file vintage: the per-trial timing lives on the
%   block. decoder.m:154-157 still reads it ("old way"), and the shipped template
%   still declares it, so documents in this shape exist.
v1 = presentationFixture();
v1 = rmfield(v1, 'files');
v1.stimulus_presentation.presentation_time = struct( ...
    'clocktype',  {'utc', 'utc', 'utc', 'utc', 'utc', 'utc'}, ...
    'stimopen',   { 15,  30,  45,  60,  75,  90}, ...
    'onset',      { 15,  30,  45,  60,  75,  90}, ...
    'offset',     { 25,  40,  55,  70,  85, 100}, ...
    'stimclose',  { 25,  40,  55,  70,  85, 100}, ...
    'stimevents', { [],  [],  [],  [],  [],  []});
end

function v1 = controlFixture(csIds)
%CONTROLFIXTURE A did_v1 control_stimulus_ids as tuning_response.m:652-656 builds
%   it. Its presentation edge points at the presentation fixture's id, so a batch
%   of the two is self-consistent.
%
%   csIds is ONE ENTRY PER TRIAL and each entry is an index INTO THE TRIAL
%   SEQUENCE naming the control trial to compare against (:619-644) -- stimulus 3
%   is the blank, so trials 3 and 6 are the controls.
if nargin < 1; csIds = [3; 3; 3; 6; 6; 6]; end
v1 = struct();
v1.document_class = struct('class_name', 'control_stimulus_ids', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'stimulus_presentation_id'}, 'value', {'pres_b671ff'});
v1.base = struct('id', 'ctrl_20e84c', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', 'ndi_app_stimulus_tuning_response', 'version', '1.2.3', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'GLNXA64', ...
    'os_version', '5.15.0', 'interpreter', 'MATLAB');
% :587-589 -- the three-field method struct, verbatim.
v1.control_stimulus_ids = struct('control_stimulus_ids', csIds, ...
    'control_stimulus_id_method', struct('method', 'pseudorandom', ...
        'controlid', 'isblank', 'controlid_value', 1));
end

% ===================== the presentation: a deferred decompose ==============

function testPresentationPassesThroughWithItsIdAndPayloadIntact(testCase)
% The whole decomposition hangs on this id. `stimulus_response_scalar` carries
% `stimulus_presentation_id` (tuning_response.m:326) and control_stimulus_ids
% carries it too (:656); reassigning it is the mistake that cost 11,448 orphans.
out = runJ(presentationFixture());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);

d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'stimulus_presentation');
verifyEqual(testCase, d.get('base.id'), 'pres_b671ff');
verifyEqual(testCase, d.get('base.session_id'), 'sess_0001');
verifyEqual(testCase, d.get('stimulus_presentation.presentation_order'), ...
    [1; 2; 3; 1; 2; 3]);

% THE DICTIONARY MUST SURVIVE. It is the half `timed_sequence` has no slot for
% (that class declares only value.presentation_order), and it is what the
% second pass turns into the distinct, deduped, referenced data_type documents.
s = d.toStruct();
verifyEqual(testCase, numel(s.stimulus_presentation.stimuli), 3);
verifyEqual(testCase, s.stimulus_presentation.stimuli(2).parameters.angle, 90);
verifyEqual(testCase, s.stimulus_presentation.stimuli(3).parameters.isblank, 1);

% the epoch string -- the future relative_reference's `relative_to`
verifyEqual(testCase, d.get('epochid.epochid'), 't00003');
% ...and the deferral is VISIBLE rather than looking like a successful migration
verifyEqual(testCase, out.summary.unconverted_count, 1);
end

function testStimulusElementIdSurvivesUnderNdisOwnName(testCase)
% The repair this build carries. NDI names the edge `stimulus_element_id` in its
% template, its schema, decoder.m:138 and the mock; V_eta's tombstone declared
% `element_id`, which nothing ever filled -- 2,670 of 2,670 corpus documents
% (B 1242 / Dab 1242 / Soph 175 / 20211116 11). universalRenames normalises an
% entry's SHAPE and never its NAME, so the edge must arrive intact.
%
% It is the STIMULATOR, and per T7 it becomes `instrument_id` on the future
% timed_sequence_manipulation -- not a subject, which is why no leaf is minted
% here.
out = runJ(presentationFixture());
b   = out.migrated{1}.toStruct();
verifyEqual(testCase, depValue(b, 'stimulus_element_id'), 'stimelem_5f10a2');
verifyEmpty(testCase, depValue(b, 'element_id'));
verifyFalse(testCase, any(strcmp({b.depends_on.name}, 'element_id')));
end

function testInventedElementIdEdgeIsRejectedByName(testCase)
% No did_v1 document has this edge; a body carrying it came from DID-schema's
% V_alpha/V_zeta snapshot or a fixture built against it. Same stance as
% openminds_stimulus (`stimulus_id`) and epochfiles_ingested (`epochid`).
v1 = presentationFixture();
v1.depends_on(1).name = 'element_id';
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');

verifyEmpty(testCase, out.migrated);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).class_name, 'stimulus_presentation');
verifySubstring(testCase, out.quarantine(1).reason, 'stimulus_element_id');
end

function testDeprecatedInlinePresentationTimeIsCarriedNotDropped(testCase)
% Both vintages are real (decoder.m:133 vs :154-157; the template still declares
% the block). A passthrough that dropped it would lose every trial onset in the
% pre-file corpora -- the exact silent loss the census exists to catch.
%
% NOT validated: the tombstone does not declare `presentation_time`, so this
% document raises did2:validation:undeclaredField today. That is the BLOCKING
% row check_tombstones.py reports, and it is a schema repair.
out = runJ(deprecatedVintageFixture());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);

s = out.migrated{1}.toStruct();
verifyTrue(testCase, isfield(s.stimulus_presentation, 'presentation_time'));
pt = s.stimulus_presentation.presentation_time;
verifyEqual(testCase, numel(pt), 6);
verifyEqual(testCase, pt(1).onset, 15);
verifyEqual(testCase, pt(6).offset, 100);
verifyEqual(testCase, pt(1).clocktype, 'utc');
% `stimevents` stays UNTYPED (gate 4 of the signed plan) -- it must survive, not
% be interpreted.
verifyTrue(testCase, isfield(pt, 'stimevents'));
end

function testTheFileCarryingTheTimeAxisSurvives(testCase)
% Revision 2 of the signed plan routes these onsets through the body tier as an
% IRREGULAR TIME AXIS on a sampled_body. Pass 1 neither reads nor moves the
% bytes -- single-document migrators carry files but do not read them -- so the
% only requirement here is that the declaration is not dropped.
out = runJ(presentationFixture());
s   = out.migrated{1}.toStruct();
verifyTrue(testCase, isfield(s, 'files'));
verifyTrue(testCase, any(strcmp(s.files.file_list, 'presentation_time.bin')));
end

function testPassOneMintsNoTimedSequenceAndNoManipulation(testCase)
% DELIBERATE DEFERRAL, PINNED -- four independent blockers, any one sufficient:
%   1. `timed_sequence_manipulation.subject_id` is required by tier and the v1
%      document names a STIMULATOR, not a subject. Who watched the sequence is
%      reachable only through the response link, i.e. the migrated graph
%      (ndi.migrate.internal.bodyResolver/subjectsForPresentation).
%   2. `timed_sequence` declares only value.presentation_order, so minting it
%      here would drop the `stimuli` dictionary while validating clean.
%   3. Deduping the distinct stimuli is corpus-wide (precedent:
%      ndi.migrate.internal.pathSPromotion).
%   4. V_eta/draft/timed_sequence.json is `"abstract": true`, and the cache
%      raises did2:validation:abstractInstantiation for abstract class names.
%
% When the second pass lands, this test should FAIL and be replaced.
out = runJ(presentationFixture());
names = classNames(out);
verifyFalse(testCase, any(strcmp(names, 'timed_sequence')));
verifyFalse(testCase, any(strcmp(names, 'timed_sequence_manipulation')));
% ...and NOT the superseded #19 dissolve either. That model
% (ndi.migrate.internal.stimulusPresentationToManipulation) folded the stimuli
% into one visual_grating_manipulation and reassigned the id.
verifyFalse(testCase, any(strcmp(names, 'visual_grating_manipulation')));
verifyEqual(testCase, names, {'stimulus_presentation'});
end

% ===================== the control designation =============================

function testControlIdsFoldToControlDesignationWithTheIdPreserved(testCase)
out = runJ(controlFixture());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);

d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'control_designation');
verifyEqual(testCase, d.get('document_class.schema_version'), 'V_eta');
verifyEqual(testCase, d.get('base.id'), 'ctrl_20e84c');
verifyEqual(testCase, d.get('control_designation.control_stimulus'), [3; 3; 3; 6; 6; 6]);
verifyEqual(testCase, d.get('control_designation.method.method'), 'pseudorandom');
verifyEqual(testCase, d.get('control_designation.method.controlid'), 'isblank');
verifyEqual(testCase, d.get('control_designation.method.controlid_value'), 1);
end

function testControlDesignationPointsAtThePresentationBothWays(testCase)
% `timed_sequence_id` is the thing annotated; `derived_from_1` is the provenance
% (T10). They are the same id today and stay the same id after the decompose,
% because the presentation is decomposed AROUND its preserved id.
%
% `derived_from_1` is the DOCUMENT naming an instance of the `derived_from_#`
% FAMILY the schema declares (revision 3 of the signed plan). A document names
% instances; a schema declares the template name.
out = runJ(controlFixture());
b   = out.migrated{1}.toStruct();
verifyEqual(testCase, depValue(b, 'timed_sequence_id'), 'pres_b671ff');
verifyEqual(testCase, depValue(b, 'derived_from_1'),    'pres_b671ff');
% the v1 spelling is gone -- a body still carrying it would be claiming the fold
% happened while leaving the old edge to be re-read
verifyEmpty(testCase, depValue(b, 'stimulus_presentation_id'));
end

function testTheAppBlockIsDroppedNotCarriedIntoAnUndeclaredBlock(testCase)
% The signed naming pass drops the `app` straggler; control_designation's chain
% is `base` alone, so a carried `app` block would raise
% did2:validation:undeclaredBlock. `software_id` (T10) is a tracked deferral --
% the schema declares no such edge yet.
out = runJ(controlFixture());
s   = out.migrated{1}.toStruct();
verifyFalse(testCase, isfield(s, 'app'));
verifyFalse(testCase, any(strcmp({s.depends_on.name}, 'software_id')));
end

function testAnAllNaNControlArrayIsARealDocumentAndSurvives(testCase)
% tuning_response.m:627-629 -- when the presentation has no control stimulus at
% all the writer emits `cs_ids = nan(size(stimids))`. That is a normal document,
% which is why control_designation.control_stimulus is mustNotHaveNaN: false.
% "Cleaning" it would delete the fact that the control lookup was attempted and
% found nothing.
out = runJ(controlFixture(nan(6, 1)));
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
verifyEqual(testCase, d.get('document_class.class_name'), 'control_designation');
verifyEqual(testCase, size(d.get('control_designation.control_stimulus')), [6 1]);
verifyTrue(testCase, all(isnan(d.get('control_designation.control_stimulus'))));
end

function testControlIdsWithoutAPresentationPassThroughInsteadOfBecomingAHusk(testCase)
% Every number in the document is an index INTO a presentation. Emitting a
% control_designation with no `timed_sequence_id` would give indices into
% nothing while validating clean -- references.m:90 skips empty edges, so the
% husk would be invisible. NDI marks the edge mustbenotempty and sets it
% unconditionally at :656, so this cannot fire on a real document.
v1 = controlFixture();
v1.depends_on = struct('name', {}, 'value', {});
out = runJ(v1);

verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'control_stimulus_ids');
verifyEqual(testCase, out.summary.unconverted_count, 1);
% the payload survives intact for the second pass
verifyEqual(testCase, out.migrated{1}.get( ...
    'control_stimulus_ids.control_stimulus_ids'), [3; 3; 3; 6; 6; 6]);
end

function testTheEdgeIsReadUnderEitherKeySpelling(testCase)
% `depends_on` entries are `value` on a raw migrator body and `document_id` once
% universalRenames has normalised them; a v1 body straight off disk uses `id`.
% Reading one spelling only is how openminds_stimulus lost 635 referents.
v1 = controlFixture();
v1.depends_on = struct('name', {'stimulus_presentation_id'}, 'id', {'pres_b671ff'});
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), ...
    'control_designation');
verifyEqual(testCase, depValue(out.migrated{1}.toStruct(), 'timed_sequence_id'), ...
    'pres_b671ff');
end

% ===================== the batch: no orphans ===============================

function testTheMigratedPairHasNoOrphanEdges(testCase)
% The gate that actually matters on a corpus. The control_designation's two
% edges must resolve INSIDE the batch -- which is only true because the
% presentation keeps its id -- and the presentation's own stimulator edge is
% supplied as a KnownId (elements migrate in their own right; element.m promotes
% them to subjects with ids preserved).
out = did2.convert.v1_to_v2({presentationFixture(), controlFixture()}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);

report = did2.validate.references(out.migrated, 'KnownIds', {'stimelem_5f10a2'});
% DENOMINATOR FIRST: an orphan count means nothing without the edges inspected.
verifyGreaterThanOrEqual(testCase, report.edges_examined, 3);
if report.orphan_count > 0
    verifyFail(testCase, sprintf('%d orphan edge(s), first: %s.%s -> %s', ...
        report.orphan_count, report.orphans(1).doc_class, ...
        report.orphans(1).edge_name, report.orphans(1).edge_document_id));
end
end

% ===================== validation ==========================================

function testPassOneValidatesAgainstTheRealVEtaSchema(testCase)
% The only test here that proves the migrators and the schema agree. Needs the
% assembled V_eta set on DID_SCHEMA_PATH (stable + draft + deprecated) -- the
% quick gate builds exactly that, and control_designation is in the DRAFT tier,
% so a stable-only schema path will FAIL here rather than skip. Deliberate: a
% skip reads as success.
%
% The presentation fixture is the CURRENT writer vintage. The deprecated inline
% `presentation_time` vintage is not in this batch because the tombstone does
% not declare that field yet (the BLOCKING row); add it when the schema lands.
out = did2.convert.v1_to_v2({presentationFixture(), controlFixture()}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined under validation: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 2);
verifyEqual(testCase, sort(classNames(out)), ...
    {'control_designation', 'stimulus_presentation'});

% ...and no silent loss on anything this pass emitted. NOTE what this does NOT
% assert: `stimulus_presentation.element_id` is still declared REQUIRED by the
% tombstone, so the empty-required-edge counter will report it until the schema
% repair lands. That row is produced by the SCHEMA, not by these migrators --
% asserting zero here would make a green test the reason nobody fixed it.
if isfield(out, 'silent_loss') && isfield(out.silent_loss, 'total_docs')
    verifyGreaterThan(testCase, out.silent_loss.total_docs, 0);
end
end

% ===================== helpers =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function names = classNames(out)
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
end

function v = depValue(b, name)
% Read an edge off a RAW BODY STRUCT, tolerant of all three key spellings. An
% entry is `value` on a body a migrator built, `document_id` once universalRenames
% has normalised it, and `id` on an untouched v1 body. Precedence copied from
% +did2/+validate/references.m.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on) || ~isstruct(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    d = b.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name)
        continue;
    end
    for key = {'value', 'document_id', 'id'}
        if isfield(d, key{1}) && ~isempty(d.(key{1}))
            v = char(d.(key{1}));
            return;
        end
    end
end
end

function verifySubstring(testCase, actual, needle)
verifyTrue(testCase, contains(char(actual), needle), ...
    sprintf('expected "%s" to contain "%s"', char(actual), needle));
end
