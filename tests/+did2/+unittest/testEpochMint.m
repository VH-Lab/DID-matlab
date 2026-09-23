function tests = testEpochMint
%TESTEPOCHMINT The `epoch` mint (#60): one entity per (session, epoch-id) PAIR.
%
%   STATUS: WRITTEN 2026-08-10, EXTENDED 2026-08-11 (the ingested-metadata fold
%   section at the bottom), NEVER EXECUTED HERE. This container has no MATLAB
%   and no Octave -- `command -v matlab octave octave-cli` prints nothing and
%   exits 1 -- so nothing in this file has been run here. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion,
%   and the CI run ids in the commit message are the only durable evidence.
%
%   NEW FILE, deliberately. `testMigratorsJEpoch.m` pins PASS-ONE behaviour --
%   that no epoch is minted, that no `epoch_id` edge is ever emitted empty --
%   and every one of those assertions must keep passing after this build.
%   `testMigratorsJ.m` is owned by another session and is not touched.
%
%   WHAT IS UNDER TEST: did2.convert.epochMint, a BATCH post-pass beside
%   did2.convert.resolveDatasetEntities. A single-document migrator cannot mint
%   an epoch -- several documents share one, so a per-document mint emits one
%   entity per REFERENCING DOCUMENT. The mint is a find-or-create over the whole
%   corpus.
%
%   THE ONE MEASUREMENT THAT DRIVES THE DESIGN (corpus run 31415147934,
%   `02854c7`, 2026-08-10; did2.validate.sourceCensus, 6 corpora, 221,827 v1
%   documents, 0 unreadable):
%
%                synthetic (whole_session_) ids   ids spanning >1 session
%       20211116             0                             0
%       B                    0                           142   (of 149 distinct)
%       Dab                  0                           142   (of 1754 distinct)
%       JH                   0                             0
%       PRED                 0                             0
%       Soph                 0                            12   (of 18 distinct)
%
%   V_eta_epoch_plan.md predicted the synthetic-id hazard; it is ZERO
%   everywhere. The hazard the data HAS is string reuse across sessions. So the
%   mint key is the PAIR, and testKeyingOnTheStringAloneWouldHaveFused is the
%   test that fails if anyone ever keys on the string.
%
%   FIXTURES ARE BUILT FROM THE NDI WRITER, never from a V_eta schema -- the
%   standing rule after migrators were found to have been written against
%   DID-schema's own V_alpha snapshot. Each builder names its writer and its
%   template. The `element_epoch` and `epochfiles_ingested` builders are copied
%   verbatim from testMigratorsJEpoch.m, where they are documented as taken
%   from corpus B rather than composed.
%
%   Run with:  results = runtests('did2.unittest.testEpochMint');

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function [out, rep] = mintFrom(v1)
%MINTFROM Pass 1 then the batch mint, with validation OFF.
%   Validation needs the assembled V_eta schema set on DID_SCHEMA_PATH; the one
%   test that requires it says so and calls with Validate true.
out = runJ(v1);
[out, rep] = did2.convert.epochMint(out, ...
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

function v = depValue(b, name)
%DEPVALUE Read an edge off a body STRUCT, accepting both key spellings.
%   Copied from testMigratorsJEpoch: which key a body carries depends on where
%   it came from (a migrator that BUILT the edge still has `value`; one that
%   came through universalRenames has `document_id`). Returns '' for both
%   "absent" and "present and empty" -- use hasDep to tell those apart.
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

function tf = hasDep(b, name)
tf = false;
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(char(deps(k).name), name)
        tf = true; return;
    end
end
end

% ===================== fixtures, from the NDI writer ===================

% ============ #60 option A: the epoch carries its own extents ==============
% TEAM DECISION 2026-08-14. The #60 signature says acquisition_epoch's clocks
% become relative_reference documents and does NOT say who holds them. Option A:
% the EPOCH holds them (`epoch.time_reference_#`) and each reference is anchored
% to the SESSION. Anchoring to the epoch would point a document at its own
% holder; the session is the referent the extent is measured against, and #51
% established a session document exists in every corpus.

function testEpochGainsATimeReferencePerClock(testCase)
out = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), ...
    elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1')});
epochs = ofClass(out, 'epoch');
verifyEqual(testCase, numel(epochs), 1, 'one epoch for one epoch-id string');
refs = ofClass(out, 'relative_reference');
verifyEqual(testCase, numel(refs), 1, 'one reference for the one clock');

% THE EDGE DIRECTION IS THE DECISION, so it is asserted in both directions
% rather than inferred from the count.
% Read through depValueOf rather than by indexing the edge list directly:
% `depends_on` is a struct array on some paths and a cell on others, and the
% helper handles both. The first draft here read
% `epochs{1}.get('depends_on')(1).name`, which MATLAB cannot evaluate at all --
% you cannot index into the result of a function call.
verifyEqual(testCase, depValueOf(epochs{1}, 'time_reference_1'), ...
    char(refs{1}.get('base.id')), 'the epoch HOLDS the reference');
verifyEqual(testCase, depValueOf(refs{1}, 'relative_to'), 'sess_doc_1', ...
    'the reference is anchored to the SESSION, not to its own holder');
verifyNotEqual(testCase, depValueOf(refs{1}, 'relative_to'), ...
    char(epochs{1}.get('base.id')), 'anchoring to the epoch would be circular');

% the clock and the extent, carried from the v1 block
v = refs{1}.get('relative_reference.value');
verifyEqual(testCase, char(v.clock.name), 'dev_local_time');
verifyEqual(testCase, v.start.seconds, 0);
% CHANGE 1 of the time model: the EXTENT is t1 - t0, not the raw t1.
verifyEqual(testCase, v.duration.seconds, 452.709856, 'AbsTol', 1e-9);
end

function testTheInlineClocksBlockIsLeftInPlace(testCase)
% Row #60's own rule: "Nothing may be deleted until the corpus proves the fold."
% This pass ADDS and removes nothing, so the fact is stored twice for now --
% #69's defect, and the lesser evil against the 2,484 corpus-B quarantines that
% deleting ahead of a corpus run cost last time. If a later change clears the
% block, THIS test is the one that should fail and be inverted deliberately.
out = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), ...
    elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1')});
ae = ofClass(out, 'acquisition_epoch');
verifyEqual(testCase, numel(ae), 1);
clocks = ae{1}.get('acquisition_epoch.clocks');
verifyEqual(testCase, numel(clocks), 1);
verifyEqual(testCase, char(clocks(1).name), 'dev_local_time');
end

function testManyDocumentsSharingOneEpochGiveOneReferencePerClock(testCase)
% THE NORMAL CASE, not an edge case: corpus B carries 1,239 element_epoch
% documents over 149 distinct epoch-id strings. `epoch.json` declares
% referent_unique_by {time_reference_#, value.clock}, so a second copy of one
% clock would violate a rule the schema already states.
out = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), ...
    elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1'), ...
    elementEpochBody('ee_2', 'sess_1', 't00001', 'elem_2'), ...
    elementEpochBody('ee_3', 'sess_1', 't00001', 'elem_3')});
verifyEqual(testCase, numel(ofClass(out, 'epoch')), 1);
verifyEqual(testCase, numel(ofClass(out, 'relative_reference')), 1, ...
    'three documents, one epoch, one clock -> ONE reference');
[~, rep] = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), ...
    elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1'), ...
    elementEpochBody('ee_2', 'sess_1', 't00001', 'elem_2')});
verifyEqual(testCase, rep.epoch_extent_sources_seen, 2, 'the DENOMINATOR');
verifyEqual(testCase, rep.epoch_extent_references_emitted, 1);
verifyEqual(testCase, rep.epoch_extent_duplicate_clock, 1, ...
    'the dropped copy is COUNTED, not silently discarded');
verifyEqual(testCase, rep.epoch_extent_conflicting_clock, 0, ...
    'identical extents are a duplicate, not a conflict');
end

function testTwoSourcesDisagreeingAboutOneClockAreCountedSeparately(testCase)
% A duplicate that DISAGREES is not the same event as one that repeats. Neither
% source is authoritative, so picking a winner would invent a fact -- both are
% dropped, and the disagreement gets its own counter so it cannot hide inside
% the benign one.
a = elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1');
b = elementEpochBody('ee_2', 'sess_1', 't00001', 'elem_2');
b.element_epoch.t0_t1 = [0, 999.5];
[~, rep] = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), a, b});
verifyEqual(testCase, rep.epoch_extent_conflicting_clock, 1);
verifyEqual(testCase, rep.epoch_extent_duplicate_clock, 0);
verifyEqual(testCase, rep.epoch_extent_references_emitted, 1, ...
    'the first reading stands; the disagreeing one is dropped, not merged');
end

function testNoTimesMeansNoReference(testCase)
% "NO TIMES => NO REFERENCE" -- a NaN-valued reference is a hollow document,
% the exact thing silentLoss and isFragment exist to catch.
v1 = elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1');
v1.element_epoch.epoch_clock = 'no_time';
[out, rep] = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), v1});
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
verifyEqual(testCase, rep.epoch_extent_skipped_no_time, 1);
verifyEqual(testCase, rep.epoch_extent_sources_seen, 1, ...
    'it was SEEN and refused -- not invisible');
% and the epoch is still minted: identity does not depend on having an extent
verifyEqual(testCase, numel(ofClass(out, 'epoch')), 1);
end

function testAnEmptyBatchReportsVacuityRatherThanZeros(testCase)
% A run with nothing to do must not read as a run that did everything. Every
% `epoch_extent_*` zero is meaningless unless the denominator is non-zero, so
% the vacuity flag is what distinguishes them.
[~, rep] = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref')});
verifyTrue(testCase, rep.epoch_extent_vacuous);
verifyEqual(testCase, rep.epoch_extent_sources_seen, 0);
[~, rep2] = mintFrom({sessionBody('sess_doc_1', 'sess_1', 'ref'), ...
    elementEpochBody('ee_1', 'sess_1', 't00001', 'elem_1')});
verifyFalse(testCase, rep2.epoch_extent_vacuous);
end

function v = depValueOf(doc, name)
%DEPVALUEOF The value of one depends_on entry, over both wire spellings.
%   BOTH CONTAINER SHAPES, because the pipeline produces both: a struct array
%   from the re-fold, a cell where setDep had to grow one. Reading only the
%   struct form would fail on exactly the bodies this pass adds.
deps = doc.get('depends_on');
v = '';
for k = 1:numel(deps)
    if iscell(deps); e = deps{k}; else; e = deps(k); end
    if ~isstruct(e) || ~isfield(e, 'name'); continue; end
    if strcmp(char(e.name), name)
        if isfield(e, 'value'); v = char(e.value);
        elseif isfield(e, 'document_id'); v = char(e.document_id); end
        return;
    end
end
end

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 `session` document.
%
%   TEMPLATE (git show origin/main:src/ndi/ndi_common/database_documents/\
%   session.json): superclasses [base], no depends_on, and ONE field,
%   `session.reference`.
%
%   WRITER (+ndi/+session/dir.m:138):
%       g = ndi.document('session','session.reference',...reference) + ...
%           ndi_session_dir_obj.newdocument();
%       ndi_session_dir_obj.database_add(g);
%
%   THE TWO IDS ARE DIFFERENT STRINGS, and the mint depends on that.
%   `ndi.document.m:57` sets `base.id` from a fresh `ndi.ido()`;
%   `+ndi/session.m:215` (`newdocument`) appends `base.session_id` from
%   `session.id()`. So the session DOCUMENT's own id is not the session id its
%   siblings carry, and `epoch.session_id` must point at the former. The fixture
%   uses visibly different strings so a test that confused them would fail
%   rather than pass by coincidence.
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

function v1 = elementEpochBody(docId, sessionId, epochId, elementId)
%ELEMENTEPOCHBODY A did_v1 `element_epoch` body, verbatim in shape.
%   Copied from testMigratorsJEpoch.m, where it is documented as corpus B's
%   shape rather than composed: 1,239 documents over 149 distinct epoch-id
%   strings -- MANY documents share one epoch, which is the whole reason the
%   mint must be a find-or-create.
%
%   WRITER (+ndi/element.m:367-378):
%       epochdoc = E.newdocument('element_epoch', ...
%           'element_epoch.epoch_clock', epochclockstr, ...
%           'element_epoch.t0_t1', t0_t1_input, ...
%           'epochid.epochid', epochid);
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/element_epoch.json', ...
    'validation',         '$NDISCHEMAPATH/element_epoch_schema.json', ...
    'class_name',         'element_epoch', ...
    'property_list_name', 'element_epoch', ...
    'class_version',      1, ...
    'superclasses',       [ struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
                            struct('definition', '$NDIDOCUMENTPATH/epochid.json')]);
v1.depends_on = struct('name', 'element_id', 'value', elementId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochid = struct('epochid', epochId);
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0, 452.709856]);
end

function v1 = ingestedBody(docId, sessionId, epochId, navigatorId)
%INGESTEDBODY A did_v1 `epochfiles_ingested` body, verbatim in shape.
%   Copied from testMigratorsJEpoch.m (corpus B: across all 2,484 the block key
%   set is exactly {epoch_id, epochprobemap, files} and the dependency name set
%   is exactly {filenavigator_id}).
%
%   IT MATTERS HERE FOR ONE REASON: this class carries its epoch id as a plain
%   char field INSIDE ITS OWN BLOCK, not in an `epochid` mixin, and
%   did2.validate.sourceCensus's reader does not see it (its docstring records
%   that limit -- `epochfiles_ingested` contributed ZERO of corpus B's 6,207
%   counted documents). A mint that reused the census reader would silently
%   omit these epochs. testTheIngestedManifestIsAKeySource is that guard.
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/epochfiles_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/epochfiles_ingested_schema.json', ...
    'class_name',         'epochfiles_ingested', ...
    'property_list_name', 'epochfiles_ingested', ...
    'class_version',      1, ...
    'superclasses',       struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', 'filenavigator_id', 'value', navigatorId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
blk = struct();
blk.epoch_id = epochId;
blk.files = { ...
    ['epochid://' epochId]; ...
    ['/Users/vanhoosr/Desktop/2013_treeshrew_transLGNctx/2008-08-07/' epochId '/reference.txt']};
blk.epochprobemap = sprintf( ...
    'name\treference\ttype\tdevicestring\tsubjectstring\ntet\t7\tn-trode\tvhspike2:ai11-14\tts0820@fitzpatrick_duke\n');
v1.epochfiles_ingested = blk;
end

function v1 = oneEpochBody(docId, sessionId, reference, elementId)
%ONEEPOCHBODY A did_v1 `oneepoch` body -- the SYNTHETIC epoch id.
%
%   TEMPLATE (ndi_common/database_documents/oneepoch.json): its ONLY declared
%   superclass is `element_epoch`, and its own block has one field, `epoch_ids`.
%   `element_id`, `epoch_clock`, `t0_t1` and the `.vhsb` payload all arrive by
%   INHERITANCE.
%
%   WRITER (+ndi/element.m:387): E.newdocument('oneepoch', ...,
%   'oneepoch.epoch_ids', epochids). The epoch STRING comes from
%   +ndi/+element/oneepoch.m:42:
%
%       epoch_id = ['whole_session_' session.reference]
%
%   which is DETERMINISTIC -- every element in a session evaluates it to the
%   same string. That is the hazard the plan predicted, and the guard the mint
%   applies reads the STRING, not the carrier class.
%   THE BODY SHAPE IS COPIED FROM testMigratorsJ.m's `oneepoch` fixtures, which
%   were themselves MEASURED against the pipeline (scratch probe 8, DID-matlab
%   run 31423494433) rather than composed -- including the comma-joined
%   `epoch_clock` and the 2-by-N `t0_t1` that `oneepoch.m:109-124` writes and
%   the BASE `element_epoch` migrator parses. Reproducing a shape that is known
%   to survive the pipeline keeps this test failing only for its own reason.
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {elementId});
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', ['whole_session_' reference], 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', ['whole_session_' reference]);
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', 't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');
end

function v1 = extractionModificationBody(docId, sessionId, epochId, elementId)
%EXTRACTIONMODIFICATIONBODY A did_v1 `spike_extraction_parameters_modification`.
%
%   THE WRITER SETS AN EPOCH BLOCK THE TEMPLATE DOES NOT DECLARE, which is why
%   this class is the one place the mint can fill a declared edge today.
%
%   WRITER (+ndi/+app/spikeextractor.m:309-311):
%       doc = ndi.document('spike_extraction_parameters_modification',...
%           'spike_extraction_parameters_modification',appdoc_struct, ...
%           'epochid.epochid',epoch_string) + ...
%           ndi_app_spikeextractor_obj.newdocument() + ...
%           ndi.document('base','base.name',extraction_name);
%       doc = doc.set_dependency_value('extraction_parameters_id',...);
%       doc = doc.set_dependency_value('element_id',...);
%
%   TEMPLATE (ndi_common/database_documents/apps/spikeextractor/
%   spike_extraction_parameters_modification.json): superclasses [base, app],
%   depends_on [extraction_parameters_id, element_id], and the same fifteen
%   fields as its base class. NO `epochid` superclass -- the writer wins.
%
%   The migrator folds it to `method_parameters`, and
%   +migrators_j/private/jMethodParameters.m:112-119 PARKS the epoch string in
%   `other.epochid` because jEpochDocId cannot resolve an edge in pass 1. This
%   pass is what the parking was for.
%   THE BODY SHAPE IS COPIED FROM testMigratorsJMethodParams.m's
%   `modificationBody`, which already drives this migrator end to end -- so a
%   failure here is about the MINT and not about the fold. The v1 spelling of
%   the `app` block (`name`/`version`) is kept deliberately: universalRenames
%   rewrites those to `app_name`/`app_version` before any migrator sees them,
%   and a fixture that pre-renamed them would test a path no document takes.
v1 = struct();
v1.document_class = struct('class_name', 'spike_extraction_parameters_modification', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'app',  'class_version', '1.0.0')]);
v1.depends_on = [ ...
    struct('name', 'extraction_parameters_id', 'value', 'sep_1'), ...
    struct('name', 'element_id',               'value', elementId)];
v1.base = struct('id', docId, 'session_id', sessionId, 'name', 'default', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.app = struct('name', 'ndi_app_spikeextractor', 'version', '1.2.3', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', ...
    'os', 'MACA64', 'os_version', '14.5', ...
    'interpreter', 'MATLAB', 'interpreter_version', '24.1');
v1.epochid = struct('epochid', epochId);
v1.spike_extraction_parameters_modification = struct( ...
    'center_range_time',   0.0005, 'overlap', 0.5, 'read_time', 30, ...
    'refractory_time',     0.001,  'spike_start_time', -0.00045, ...
    'spike_end_time',      0.001,  'do_filter', 1, ...
    'filter_type',         'cheby1high', 'filter_low', 0, ...
    'filter_high',         300,    'filter_order', 4, ...
    'filter_ripple',       0.8,    'threshold_method', 'standard_deviation', ...
    'threshold_parameter', -4,     'threshold_sign', -1);
end

% ===================== the denominator =================================

function testTheReportStatesItsDenominatorFirst(testCase)
% OPERATING RULE 5, as a test. `silentLoss` printed "0 empty edges" for two days
% while reading nothing, and the digest that rendered it repeated the omission.
% A report whose counts are all zero must be distinguishable from a report that
% never ran, so `ran` and `documents_inspected` exist before any document is
% read and are asserted here on the smallest possible input.
[out, rep] = mintFrom({sessionBody('sd_A', 'sess_A', 'ts_2008')});
verifyTrue(testCase, rep.ran, 'the report must say it ran');
verifyEqual(testCase, rep.documents_inspected, numel(out.migrated), ...
    'documents_inspected is the denominator and must equal what was handed in');
verifyEqual(testCase, rep.documents_unreadable, 0);
verifyEqual(testCase, rep.epochs_minted, 0, ...
    'a session with no epoch-scoped document mints nothing');
verifyEqual(testCase, rep.session_documents_seen, 1);
end

function testAnEmptyBatchReportsRatherThanReturningSilently(testCase)
% Built field by field on purpose: struct('quarantine', struct([])) returns a
% 0-by-0 STRUCT ARRAY, not a scalar struct with an empty field, and the pass
% declares `result (1,1) struct`.
result = struct();
result.migrated = {};
result.quarantine = struct('original_body', {}, 'class_name', {}, ...
    'reason', {}, 'failed_at', {});
result.summary = struct('total', 0);
[result, rep] = did2.convert.epochMint(result, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyTrue(testCase, isfield(result, 'epoch_mint'), ...
    'the report rides on the result so a caller ignoring the 2nd output keeps it');
end

function testANonEtaTargetIsUntouched(testCase)
% `epoch` exists only in V_eta. Under any other target the pass must be a no-op
% that says so, not a silent return that looks identical to having run. The
% batch is migrated at V_eta and the PASS is asked for another target, so this
% tests the guard and not some other target's migration path.
out = runJ({sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
            elementEpochBody('ee_0', 'sess_A', 't00069', 'el_1')});
before = numel(out.migrated);
[out, rep] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_zeta');
verifyFalse(testCase, rep.ran, 'a non-V_eta target must report that it did not run');
verifyEqual(testCase, numel(out.migrated), before);
end

% ===================== the key is the PAIR =============================

function testOneEpochPerSessionEpochPair(testCase)
% Two sessions, ONE epoch-id string, two element_epochs. This is the ordinary
% case in corpus B (142 of 149 distinct ids appear under more than one session),
% not a contrived one: `t00070` restarts in every session directory.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    sessionBody('sd_B', 'sess_B', 'ts_2009'), ...
    elementEpochBody('ee_1', 'sess_A', 't00070', 'el_1'), ...
    elementEpochBody('ee_2', 'sess_B', 't00070', 'el_2')});
verifyEqual(testCase, rep.epochs_minted, 2, ...
    'one epoch-id string under two sessions is TWO epochs, never one');
epochs = ofClass(out, 'epoch');
verifyEqual(testCase, numel(epochs), 2);
lids = sort(cellfun(@(d) char(d.get('epoch.local_identifier')), epochs, ...
    'UniformOutput', false));
verifyEqual(testCase, lids, {'t00070', 't00070'}, ...
    'both keep the v1 handle -- 30 live NDI sites match that string');
sessEdges = sort(cellfun(@(d) depValue(d.toStruct(), 'session_id'), epochs, ...
    'UniformOutput', false));
verifyEqual(testCase, sessEdges, {'sd_A', 'sd_B'}, ...
    'each epoch points at ITS session document');
end

function testKeyingOnTheStringAloneWouldHaveFused(testCase)
% THE LOAD-BEARING TEST OF THIS FILE.
%
% `pairs_minus_strings` is the number of epochs the string key would have
% destroyed. It is the measured hazard restated as an assertion: if anyone ever
% groups on `epochid.epochid` alone, this goes to 0 and two recordings from
% different animals silently become one.
[~, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    sessionBody('sd_B', 'sess_B', 'ts_2009'), ...
    elementEpochBody('ee_1', 'sess_A', 't00070', 'el_1'), ...
    elementEpochBody('ee_2', 'sess_B', 't00070', 'el_2')});
verifyEqual(testCase, rep.distinct_epoch_id_strings, 1, ...
    'one distinct STRING');
verifyEqual(testCase, rep.distinct_session_epoch_pairs, 2, ...
    'two distinct PAIRS -- the key');
verifyEqual(testCase, rep.pairs_minus_strings, 1, ...
    'exactly one epoch would have been lost to fusion');
end

function testManyDocumentsOfOneEpochMintItOnce(testCase)
% The find-or-create half. Corpus B carries 1,239 element_epoch documents over
% 149 distinct strings, so a per-document mint would emit ~8 duplicate entities
% per epoch. Three documents of one epoch here; one epoch out.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1'), ...
    elementEpochBody('ee_2', 'sess_A', 't00069', 'el_2'), ...
    ingestedBody('efi_1', 'sess_A', 't00069', 'nav_1')});
verifyEqual(testCase, rep.epochs_minted, 1);
verifyEqual(testCase, numel(ofClass(out, 'epoch')), 1);
verifyEqual(testCase, rep.documents_with_epoch_id, 3, ...
    'three documents contributed the key; one epoch came out');
end

function testTheIngestedManifestIsAKeySource(testCase)
% `epochfiles_ingested` carries its epoch id as a plain char field in its OWN
% block. did2.validate.sourceCensus's reader visits only blocks NAMED `epochid`
% / `epoch_id` and so counts ZERO of them -- a documented limit for a census and
% a silent omission for a mint. If the mint ever reuses that reader, corpus B's
% 2,484 manifests stop contributing epochs and this fails.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    ingestedBody('efi_1', 'sess_A', 't00070', 'nav_1')});
verifyEqual(testCase, rep.documents_with_epoch_id, 1);
verifyEqual(testCase, rep.epochs_minted, 1);
epochs = ofClass(out, 'epoch');
verifyEqual(testCase, char(epochs{1}.get('epoch.local_identifier')), 't00070');
end

% ===================== the refusals, each counted ======================

function testNoSessionDocumentMintsNothing(testCase)
% `epoch.session_id` is REQUIRED. An epoch minted with that edge empty VALIDATES
% CLEAN -- +did2/+validate/references.m:90 short-circuits on an empty documentId
% -- so it would rebuild the invented-empty-edge pattern (6,921 documents, 100%
% empty) under the repair's own name. The refusal is the correct behaviour and
% the COUNT is what makes it auditable.
[out, rep] = mintFrom({elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')});
verifyEqual(testCase, rep.epochs_minted, 0);
verifyEqual(testCase, rep.skipped_no_session_document, 1, ...
    'the refusal must be counted, not merely performed');
verifyEmpty(testCase, ofClass(out, 'epoch'));
end

function testNoEpochEverCarriesAnEmptySessionEdge(testCase)
% The generalisation of the test above, asserted over whatever gets minted
% rather than over a case chosen to fail. Whatever the input, every emitted
% epoch has a populated `session_id`.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1'), ...
    elementEpochBody('ee_2', 'sess_X', 't00071', 'el_2'), ...
    ingestedBody('efi_1', '',       't00072', 'nav_1')});
epochs = ofClass(out, 'epoch');
% THE DENOMINATOR, asserted before the property. "every epoch has a populated
% session edge" is trivially true of zero epochs, and an empty pass is
% indistinguishable from a real one in the output -- the failure
% tools/check_vacuous_tests.py exists for. Exactly one of these four documents
% can be minted from (sess_A has a session document; sess_X does not; the third
% has no session id at all).
verifyEqual(testCase, numel(epochs), 1, ...
    'the loop below must have something to loop over');
for k = 1:numel(epochs)
    s = epochs{k}.toStruct();
    verifyTrue(testCase, hasDep(s, 'session_id'));
    verifyNotEmpty(testCase, depValue(s, 'session_id'), ...
        'a required edge emitted empty is the defect this repair exists to remove');
end
end

function testADocumentWithNoSessionIdIsRefusedAndCounted(testCase)
[~, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    ingestedBody('efi_1', '', 't00072', 'nav_1')});
verifyEqual(testCase, rep.skipped_no_session_id, 1);
verifyEqual(testCase, rep.epochs_minted, 0);
end

function testTwoSessionDocumentsForOneSessionIdAreRefused(testCase)
% Not defensive noise: with two candidates the referent is a GUESS, and a wrong
% `session_id` on an epoch is a wrong graph that nothing downstream can audit.
% Corpus measurement says this does not happen (session documents are 1:1 with
% distinct base.session_id in all six corpora, #51), so the refusal costs
% nothing today -- and the count is what would tell us if that changed.
[~, rep] = mintFrom({ ...
    sessionBody('sd_A1', 'sess_A', 'ts_2008'), ...
    sessionBody('sd_A2', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')});
verifyEqual(testCase, rep.session_documents_seen, 2);
verifyEqual(testCase, rep.skipped_ambiguous_session, 1);
verifyEqual(testCase, rep.epochs_minted, 0);
end

function testTheSyntheticWholeSessionIdIsNotMinted(testCase)
% `whole_session_<reference>` (+ndi/+element/oneepoch.m:42) names a span nothing
% recorded as one epoch. V_eta_epoch_plan.md's fork A1 -- CHOSEN by the team
% 2026-08-10, NOT SIGNED -- says no `epoch` entity is minted for it, because
% that would make `epoch` mean both a recording and a derived aggregate.
%
% THIS TEST PINS AN UNSIGNED DECISION, and says so on purpose: if the team signs
% the other way, this is the test to delete, and `skipped_synthetic` is the
% count that says what it was suppressing. It measures 0 in all six corpora, so
% the guard changes nothing on real data today.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    oneEpochBody('oe_1', 'sess_A', 'ts_2008', 'el_1')});
verifyEqual(testCase, rep.skipped_synthetic, 1);
verifyEqual(testCase, rep.epochs_minted, 0);
verifyEmpty(testCase, ofClass(out, 'epoch'));
end

function testARealEpochAlongsideASyntheticOneStillMints(testCase)
% The guard must be per-id, not per-batch: one synthetic id must not suppress
% the real epochs sitting beside it.
[~, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    oneEpochBody('oe_1', 'sess_A', 'ts_2008', 'el_1'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_2')});
verifyEqual(testCase, rep.skipped_synthetic, 1);
verifyEqual(testCase, rep.epochs_minted, 1);
end

% ===================== find-or-create, not create ======================

function testRunningTwiceMintsNothingTheSecondTime(testCase)
% ndi.migrate.local documents itself as IDEMPOTENT: re-running on a dataset that
% already has a <target>.sqlite reads every document back and runs the second
% pass again. The source documents still carry their `epochid` string, so a pass
% that only ever CREATES would mint a second epoch for the same pair on every
% run -- silently, since nothing counts duplicates.
v1 = { sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
       elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1') };
[out, rep1] = mintFrom(v1);
verifyEqual(testCase, rep1.epochs_minted, 1);
firstEpochs = ofClass(out, 'epoch');
firstId = char(firstEpochs{1}.get('base.id'));

[out2, rep2] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep2.epochs_minted, 0, 'the second run must mint nothing');
verifyEqual(testCase, rep2.epochs_found_existing, 1, ...
    'and must say it FOUND the epoch rather than that there was none');
secondEpochs = ofClass(out2, 'epoch');
verifyEqual(testCase, numel(secondEpochs), 1);
verifyEqual(testCase, char(secondEpochs{1}.get('base.id')), firstId, ...
    'the epoch id must be stable across runs -- everything else points at it');
end

function testTheEpochIndexIsTheSeamOtherPassesUse(testCase)
% #66 (ingested payload), #74 (settings) and #57 (clock alignment) each need to
% resolve (session, epoch string) -> epoch document id. That lookup is published
% here rather than re-derived by each of them, which is how three copies of a
% grouping rule end up disagreeing.
[~, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    sessionBody('sd_B', 'sess_B', 'ts_2009'), ...
    elementEpochBody('ee_1', 'sess_A', 't00070', 'el_1'), ...
    elementEpochBody('ee_2', 'sess_B', 't00070', 'el_2')});
verifyEqual(testCase, numel(rep.epoch_index), 2);
verifyEqual(testCase, sort({rep.epoch_index.session_id}), {'sess_A', 'sess_B'});
for k = 1:numel(rep.epoch_index)
    verifyEqual(testCase, rep.epoch_index(k).local_identifier, 't00070');
    verifyNotEmpty(testCase, rep.epoch_index(k).epoch_document_id);
end
end

% ===================== the one declared, fillable edge =================

function testMethodParametersGetsItsEpochEdge(testCase)
% `method_parameters` is the ONLY class that (a) declares an `epoch_id` edge,
% (b) is emitted by pass 1, and (c) has the epoch string parked for this moment
% (jMethodParameters.m:112-119 writes it to `other.epochid` because jEpochDocId
% answers '' in pass 1). `ingestion_manifest` and `acquisition_metadata_file`
% declare the edge and are not emitted yet.
% (`epochfiles_ingested`'s `epoch_id` is a char FIELD, not an edge, and a grep
% for the name conflates them.)
%
% CORRECTED 2026-08-11. This said "the ONLY class that declares an epoch_id edge
% AND is emitted by pass 1", and enumerated "three DEPENDENCIES over 245 V_eta
% schema files". Both counts were wrong and the conjunction was false:
%
%     DENOMINATOR: 243 V_eta class schemas parsed (not 245)
%     declaring an `epoch_id` DEPENDENCY: 4 -- acquisition_metadata_file,
%       directed_relation, ingestion_manifest, method_parameters
%
% `directed_relation` was missing from the list AND is emitted by pass 1 at nine
% sites (subject_group, neuron_extracellular, treatment_transfer, jTuningFold,
% jEntityRelation, metadata_editor, element, ontology_table_row, ...). It gained
% its epoch_id in the epoch build; the comment predates that and closed an
% enumeration that had since grown.
%
% NOT a new invented-empty-edge instance: directed_relation.epoch_id is
% mustBeNonEmpty:false and documented as empty for timeless relations. The defect
% is the closed enumeration, which is what a reader would trust when deciding
% whether a new emitter needs epoch handling.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    extractionModificationBody('sepm_1', 'sess_A', 't00069', 'el_1')});
verifyEqual(testCase, rep.epochs_minted, 1);
verifyEqual(testCase, rep.method_parameters_seen, 1);
verifyEqual(testCase, rep.method_parameters_edges_filled, 1);
mp = ofClass(out, 'method_parameters');
verifyEqual(testCase, numel(mp), 1);
epochs = ofClass(out, 'epoch');
epochDocId = char(epochs{1}.get('base.id'));
verifyEqual(testCase, depValue(mp{1}.toStruct(), 'epoch_id'), epochDocId, ...
    'the edge must point at the minted epoch, not at the v1 string');
end

function testTheParkedStringLeavesWhenTheEdgeArrives(testCase)
% One fact, one place. Leaving `other.epochid` beside the edge would store the
% epoch association twice with nothing saying which is authoritative -- open
% item #69's defect, created deliberately.
out = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    extractionModificationBody('sepm_1', 'sess_A', 't00069', 'el_1')});
mp = ofClass(out, 'method_parameters');
other = mp{1}.get('method_parameters.other');
verifyFalse(testCase, isstruct(other) && isfield(other, 'epochid'), ...
    'the parked string must not survive alongside its edge');
end

function testAnUnresolvableEpochLeavesTheStringParked(testCase)
% No session document -> no epoch -> no edge. The string must STAY parked: it is
% the only record that these settings were scoped to one epoch, and
% spikeextractor.m:388-391 does a live three-way lookup that includes it.
[out, rep] = mintFrom({ ...
    extractionModificationBody('sepm_1', 'sess_A', 't00069', 'el_1')});
verifyEqual(testCase, rep.epochs_minted, 0);
verifyEqual(testCase, rep.method_parameters_edges_filled, 0);
verifyEqual(testCase, rep.method_parameters_unresolved, 1);
mp = ofClass(out, 'method_parameters');
s = mp{1}.toStruct();
verifyFalse(testCase, hasDep(s, 'epoch_id'), ...
    'an edge that cannot be filled must not be declared empty');
verifyEqual(testCase, char(mp{1}.get('method_parameters.other.epochid')), 't00069', ...
    'and the string must not be dropped in exchange for nothing');
end

% ===================== validation ======================================

function testMintedEpochValidatesAgainstItsSchema(testCase)
% Validation ON. This is the test that fails if `epoch`'s built schema and the
% minted body ever disagree -- e.g. if `local_identifier` moved block, or if a
% future required field arrived that the mint cannot fill.
%
% Requires the assembled V_eta schema set on DID_SCHEMA_PATH (the quick gate
% assembles it), which is why the rest of this file runs with Validate false.
out = did2.convert.v1_to_v2({ ...
        sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
        elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
[out, rep] = did2.convert.epochMint(out, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.mint_quarantined, 0, ...
    'a minted epoch that cannot validate is a build defect, not a data problem');
verifyEqual(testCase, rep.epochs_minted, 1);
epochs = ofClass(out, 'epoch');
d = epochs{1};
verifyEqual(testCase, char(d.get('epoch.local_identifier')), 't00069');
verifyEqual(testCase, depValue(d.toStruct(), 'session_id'), 'sd_A');
end

function testTheMintEmitsNoEdgeItCannotPopulate(testCase)
% SPLIT 2026-08-14, and the `time_reference_1` half is INVERTED rather than
% deleted. This test asserted BOTH edges were absent, on the stated premise that
% "neither is derivable from an epoch-id string: the per-clock extents live in
% `daqreader_epochdata_ingested.epochtable`".
%
% THAT PREMISE WAS INCOMPLETE, and #60 option A is the team recognising it: the
% extents ALSO live in `acquisition_epoch.clocks`, which this very fixture
% carries. So the mint CAN now populate `time_reference_#` -- with a real
% relative_reference document in the same batch -- and the half of this test
% covering it moved to testEpochGainsATimeReferencePerClock.
%
% THE TEST'S INTENT SURVIVES UNCHANGED and is why the split is a split rather
% than a deletion: no edge may be emitted that cannot be populated. That is
% still asserted here for `instrument_id`, which genuinely is not derivable --
% it needs the daq graph (#59). Declaring an edge empty is the pattern that put
% 26,406 documents into the census while every gate stayed green.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')});
epochs = ofClass(out, 'epoch');
s = epochs{1}.toStruct();
verifyFalse(testCase, hasDep(s, 'instrument_id'), ...
    'instrument_id needs the daq graph (#59) and must stay absent');
% AND THE EDGE THAT IS NOW EMITTED MUST NOT DANGLE -- which is the defect this
% inversion was paid for. The first version of option A put the references in
% `extraBodies` without an arming entry, so they were validated and then dropped
% while the epoch kept pointing at them. Asserting the edge EXISTS is not
% enough; the document it names has to be in the batch.
verifyTrue(testCase, hasDep(s, 'time_reference_1'));
target = depValueOf(epochs{1}, 'time_reference_1');
refIds = cellfun(@(d) char(d.get('base.id')), ofClass(out, 'relative_reference'), ...
    'UniformOutput', false);
verifyTrue(testCase, any(strcmp(refIds, target)), ...
    'the epoch names a relative_reference that is NOT in the batch -- a dangling edge');
end

function testPassOneBehaviourIsUnchangedByTheMint(testCase)
% The mint ADDS; it must not disturb what pass 1 produced. In particular
% `element_epoch` still renames to `acquisition_epoch` and keeps its `epochid`
% string -- #60's own ordering constraint is that the string may not leave
% before every epoch-scoped document carries its replacement edge, and that
% rewire is NOT part of this build.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')});
verifyTrue(testCase, any(strcmp(classNames(out), 'acquisition_epoch')));
ae = ofClass(out, 'acquisition_epoch');
verifyEqual(testCase, char(ae{1}.get('epochid.epochid')), 't00069', ...
    'the v1 handle stays until the 15-class rewire lands');
verifyFalse(testCase, hasDep(ae{1}.toStruct(), 'epoch_id'), ...
    ['acquisition_epoch declares no epoch_id edge, so the mint must not ' ...
     'stamp one -- an undeclared edge is the invented-edge pattern reversed']);
end

% ===================== the ingested-metadata fold ======================
%
%   WHAT THESE PIN. `daqmetadatareader_epochdata_ingested` ->
%   `acquisition_metadata_file` is TEAM-SIGNED (V_eta_ingested_payload_findings
%   .md, TEAM-SIGN-OFF [daq ingested payloads], 2026-08-08). The fold itself
%   lives in +migrators_j/daqmetadatareader_epochdata_ingested.m and is pinned
%   by testMigratorsJIngested; what is pinned HERE is the ARMING -- that this
%   pass stamps the `epoch_id` edge the migrator is guarded on, that it stamps
%   the RIGHT one, and that it refuses rather than stamping a wrong or empty
%   one.
%
%   THE ARMING IS NOT A NEW DESIGN. jEpochDocId's own header states the
%   handoff: "The day the epoch pass stamps an `epoch_id` edge, these migrators
%   convert with no further change; the tests drive both branches." These are
%   the tests for the day that happened.
%
%   NEVER EXECUTED HERE (no MATLAB in this container -- `command -v matlab
%   octave octave-cli` prints nothing and exits 1). CI is the first run.

function v1 = metadataIngestedBody(docId, sessionId, epochId, readerId, files)
%METADATAINGESTEDBODY A did_v1 `daqmetadatareader_epochdata_ingested`.
%
%   TEMPLATE (git show origin/main:src/ndi/ndi_common/database_documents/\
%   ingestion/daqmetadatareader_epochdata_ingested.json):
%       superclasses  base, epochid
%       depends_on    [ { "name": "daqmetadatareader_id", "value": "" } ]
%       files         { "file_list": [ "data.bin" ] }
%       daqmetadatareader_epochdata_ingested { }        <- NO FIELDS AT ALL
%
%   WRITER (+ndi/+daq/metadatareader.m, ingest_epochfiles):
%       134  epochid_struct.epochid = epoch_id;
%       136  d = ndi.document('daqmetadatareader_epochdata_ingested', ...
%                             'epochid', epochid_struct);
%       137  d = d.set_dependency_value('daqmetadatareader_id', obj.id());
%       144  d = d.add_file('data.bin',[metadatafile '.nbf.tgz']);
%
%   So the writer sets exactly three things, and the fixture sets exactly those
%   three. FILES is a parameter only so the no-bytes branch can be driven; every
%   real document has one, and `data.bin`'s bytes are a `.nbf.tgz` archive under
%   a generic name -- NOT typed here, deliberately (the plan: "Do not type
%   `data.bin`").
v1 = struct();
v1.document_class = struct( ...
    'definition',         '$NDIDOCUMENTPATH/ingestion/daqmetadatareader_epochdata_ingested.json', ...
    'validation',         '$NDISCHEMAPATH/ingestion/daqmetadatareader_epochdata_ingested_schema.json', ...
    'class_name',         'daqmetadatareader_epochdata_ingested', ...
    'property_list_name', 'daqmetadatareader_epochdata_ingested', ...
    'class_version',      1, ...
    'superclasses',       [ struct('definition', '$NDIDOCUMENTPATH/base.json'), ...
                            struct('definition', '$NDIDOCUMENTPATH/epochid.json')]);
v1.depends_on = struct('name', 'daqmetadatareader_id', 'value', readerId);
v1.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.epochid = struct('epochid', epochId);
v1.daqmetadatareader_epochdata_ingested = struct();
v1.files = struct('file_list', {files});
end

function testTheMintArmsTheIngestedMetadataFold(testCase)
% THE HEADLINE. Before this build these documents passed through whole -- 2,659
% of them (B 1,242 / Dab 1,242 / Soph 175, the volumes in the findings
% document) -- because the fold's REQUIRED `epoch_id` had nothing to point at.
% The epoch now exists, so the fold runs.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})});

verifyEqual(testCase, rep.metadata_ingested_seen, 1, ...
    'the source document must be SEEN before any other count means anything');
verifyFalse(testCase, rep.metadata_fold_vacuous, ...
    'a batch that held a source document is not a vacuous run');
verifyEqual(testCase, rep.metadata_ingested_edges_stamped, 1);
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 1);
verifyEqual(testCase, rep.metadata_ingested_folds_withheld, 0);
verifyEqual(testCase, rep.metadata_refused_total, 0);

folded = ofClass(out, 'acquisition_metadata_file');
verifyNumElements(testCase, folded, 1, ...
    'the signed target is one acquisition_metadata_file per source document');
verifyEmpty(testCase, ofClass(out, 'daqmetadatareader_epochdata_ingested'), ...
    'the fold is 1 -> 1: the source class must not also survive');
end

function testTheFoldedFilePointsAtTheEpochThatWasMinted(testCase)
% The edge must resolve to the `epoch` this pass minted for THIS document's
% (session, string) pair -- not to any epoch, and not to a fresh id. Asserted by
% reading the minted epoch's own base.id back out of the batch, so the test
% cannot pass by agreeing with a constant.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})});
epochs = ofClass(out, 'epoch');
verifyNumElements(testCase, epochs, 1);
epochDocId = char(epochs{1}.get('base.id'));
verifyEqual(testCase, char(epochs{1}.get('epoch.local_identifier')), 't00001');

folded = ofClass(out, 'acquisition_metadata_file');
s = folded{1}.toStruct();
verifyEqual(testCase, depValue(s, 'epoch_id'), epochDocId, ...
    'epoch_id must be the minted epoch document, read back from the batch');
verifyEqual(testCase, depValue(s, 'acquisition_metadata_reader_id'), 'mdr_1', ...
    'the reader edge is carried verbatim -- daqmetadatareader preserves base.id');
end

function testTheFoldPreservesTheIdAndCarriesTheBytes(testCase)
% base.id PRESERVED (T10) and `data.bin` carried. The bytes are the ENTIRE
% content of this class -- it declares no fields -- so a fold that dropped them
% would emit a document that is valid, smaller than its input, and empty of the
% only thing it exists to hold. That is the fragment mode no counter sees.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})});
folded = ofClass(out, 'acquisition_metadata_file');
verifyEqual(testCase, char(folded{1}.get('base.id')), 'amf_1', ...
    'base.id is preserved, so the migrated document stays traceable to its source');
s = folded{1}.toStruct();
verifyTrue(testCase, isfield(s, 'files') && isfield(s.files, 'file_list'), ...
    'the folded document must still declare a file list');
verifyTrue(testCase, any(strcmp(s.files.file_list, 'data.bin')), ...
    'data.bin is the whole content of an acquisition_metadata_file');
end

function testTheEpochStringLeavesInTheSameStepTheEdgeArrives(testCase)
% `acquisition_metadata_file` does NOT inherit `epochid`, so the string has
% nowhere to live on it and the epoch attribution survives only as the edge.
% Storing both would be one fact in two places with nothing saying which is
% authoritative (open item #69); storing NEITHER is the fragment this pass
% refuses. So: edge present, block gone, in one step.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})});
s = ofClass(out, 'acquisition_metadata_file');
s = s{1}.toStruct();
verifyTrue(testCase, hasDep(s, 'epoch_id'));
verifyFalse(testCase, isfield(s, 'epochid'), ...
    'the v1 epochid block must not survive alongside the edge that replaces it');
end

function testTwoSessionsReusingOneEpochStringFoldToDifferentEpochs(testCase)
% THE TEST THAT FAILS IF ANYONE KEYS THE LOOKUP ON THE STRING ALONE. An
% `epochid.epochid` string is REUSED ACROSS SESSIONS -- 142 of corpus B's 149
% distinct ids (did2.validate.sourceCensus, corpus run 31415147934) -- because
% vhlab ids restart at t00001 in every session directory. Keying the fold's
% lookup on `t00001` would point BOTH of these metadata files at whichever
% epoch happened to be minted first, silently attributing one session's
% spreadsheet to another session's recording. Both documents validate either
% way; only this assertion can see it.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    sessionBody('sd_B', 'sess_B', 'ts_2009'), ...
    metadataIngestedBody('amf_A', 'sess_A', 't00001', 'mdr_A', {'data.bin'}), ...
    metadataIngestedBody('amf_B', 'sess_B', 't00001', 'mdr_B', {'data.bin'})});
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 2);
verifyEqual(testCase, rep.epochs_minted, 2, ...
    'one string, two sessions, two epochs -- the pair is the key');

folded = ofClass(out, 'acquisition_metadata_file');
verifyNumElements(testCase, folded, 2);
edges = containers.Map('KeyType', 'char', 'ValueType', 'char');
for k = 1:numel(folded)
    s = folded{k}.toStruct();
    edges(char(s.base.id)) = depValue(s, 'epoch_id');
end
verifyNotEqual(testCase, edges('amf_A'), edges('amf_B'), ...
    ['both files were pointed at ONE epoch: the lookup fused two sessions ' ...
     'that share an epoch-id string']);

% ... and each at the epoch belonging to ITS OWN session. Inequality alone
% would still pass if the two were simply swapped.
epochOwner = containers.Map('KeyType', 'char', 'ValueType', 'char');
epochs = ofClass(out, 'epoch');
for k = 1:numel(epochs)
    e = epochs{k}.toStruct();
    epochOwner(char(e.base.id)) = depValue(e, 'session_id');
end
verifyEqual(testCase, epochOwner(edges('amf_A')), 'sd_A');
verifyEqual(testCase, epochOwner(edges('amf_B')), 'sd_B');
end

function testAnUnresolvableEpochLeavesTheDocumentAsItWas(testCase)
% NO SESSION DOCUMENT => NO EPOCH => NO FOLD. The refusal is the point: the
% alternative is an `acquisition_metadata_file` whose REQUIRED `epoch_id` is
% empty, which VALIDATES CLEAN because +did2/+validate/references.m:90 skips
% empty edges -- the mechanism behind the whole invented-empty-edge census. It
% would also destroy the only record of which epoch the bytes belong to, since
% the target class cannot carry the string.
[out, rep] = mintFrom({ ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})});
verifyEqual(testCase, rep.metadata_ingested_seen, 1);
verifyEqual(testCase, rep.metadata_refused_no_epoch_document, 1);
verifyEqual(testCase, rep.metadata_refused_total, 1);
verifyEqual(testCase, rep.metadata_ingested_edges_stamped, 0);
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 0);

verifyEmpty(testCase, ofClass(out, 'acquisition_metadata_file'), ...
    'no epoch means no carrier -- refuse, do not emit an observation about nobody');
kept = ofClass(out, 'daqmetadatareader_epochdata_ingested');
verifyNumElements(testCase, kept, 1, ...
    'the source document survives untouched under its restored tombstone');
s = kept{1}.toStruct();
verifyFalse(testCase, hasDep(s, 'epoch_id'), ...
    'a refused fold must leave no stamped edge behind on the passthrough');
verifyEqual(testCase, char(s.epochid.epochid), 't00001', ...
    'the epoch attribution stays as the string it arrived as');
end

function testNoFoldedFileEverCarriesAnEmptyEpochEdge(testCase)
% The invariant, asserted over the WHOLE batch rather than over the one
% document a test happened to build: whatever the mix of resolvable and
% unresolvable sources, every `acquisition_metadata_file` in the result has a
% populated epoch_id. This is the assertion that survives a future refactor of
% the loop above.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_ok',   'sess_A', 't00001', 'mdr_1', {'data.bin'}), ...
    metadataIngestedBody('amf_nosess', 'sess_Z', 't00002', 'mdr_2', {'data.bin'})});
folded = ofClass(out, 'acquisition_metadata_file');
verifyNumElements(testCase, folded, 1, ...
    'exactly the resolvable one folds; the other stays did_v1');
for k = 1:numel(folded)
    s = folded{k}.toStruct();
    verifyNotEmpty(testCase, depValue(s, 'epoch_id'), ...
        'an acquisition_metadata_file with an empty epoch_id is a hollow carrier');
    verifyNotEmpty(testCase, depValue(s, 'acquisition_metadata_reader_id'), ...
        'both edges are REQUIRED on the signed class');
end
end

function testTheMigratorsOwnGuardsStillDecide(testCase)
% This pass supplies the epoch and NOTHING ELSE. The migrator's other two
% guards -- no reader edge, no bytes -- remain the authority on whether a fold
% is safe, and a decline is COUNTED rather than absorbed. A document with no
% bytes has nothing this class can hold: `data.bin` is REQUIRED on both the NDI
% schema document and the V_eta class, and unlike `depends_on` nothing skips an
% empty `file`.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {})});
verifyEqual(testCase, rep.metadata_ingested_seen, 1);
verifyEqual(testCase, rep.metadata_ingested_edges_stamped, 1, ...
    'the epoch WAS resolvable -- the refusal came from the migrator, not from here');
verifyEqual(testCase, rep.metadata_refused_migrator_declined, 1);
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 0);
verifyEmpty(testCase, ofClass(out, 'acquisition_metadata_file'));
kept = ofClass(out, 'daqmetadatareader_epochdata_ingested');
verifyNumElements(testCase, kept, 1);
verifyFalse(testCase, hasDep(kept{1}.toStruct(), 'epoch_id'), ...
    'the stamped edge is discarded with the declined body, so a decline is a no-op');
end

function testTheFoldIsVacuousNotCleanWhenNoSourceIsPresent(testCase)
% A ZERO OVER A ZERO DENOMINATOR MUST SAY SO. Every corpus that holds no
% `daqmetadatareader_epochdata_ingested` document produces the same all-zero
% block as a corpus where the fold ran and failed on every document. Without
% `metadata_fold_vacuous` those two readings are identical -- which is the
% silentLoss defect exactly, and the reason operating rule 5 exists.
[~, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')});
verifyTrue(testCase, rep.metadata_fold_vacuous, ...
    'no source documents: the zeros below are untested, not clean');
verifyEqual(testCase, rep.metadata_ingested_seen, 0);
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 0);
verifyEqual(testCase, rep.metadata_refused_total, 0);
verifyEqual(testCase, rep.epochs_minted, 1, ...
    'the rest of the pass is unaffected by having nothing to fold');
end

function testRunningTwiceFoldsOnceAndSaysSo(testCase)
% IDEMPOTENCE, and it is not hypothetical: ndi.migrate.local documents itself as
% idempotent -- a re-run on a dataset that already has a <target>.sqlite reads
% every document back and runs the second pass again. The second run must see
% the folded documents as ALREADY DONE rather than as strangers, and must not
% mint a second epoch for a pair that already has one.
v1 = { ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})};
[out, rep1] = mintFrom(v1);
verifyEqual(testCase, rep1.metadata_ingested_folds_emitted, 1);
verifyEqual(testCase, rep1.epochs_minted, 1);

[out2, rep2] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep2.metadata_ingested_already_folded, 1, ...
    'the second run must RECOGNISE the folded document, not ignore it');
verifyEqual(testCase, rep2.metadata_ingested_seen, 0);
verifyEqual(testCase, rep2.epochs_minted, 0, ...
    'find-or-create: the epoch already in the batch is found, not re-minted');
verifyEqual(testCase, rep2.epochs_found_existing, 1);
verifyNumElements(testCase, ofClass(out2, 'acquisition_metadata_file'), 1);
verifyNumElements(testCase, ofClass(out2, 'epoch'), 1);
end

function testTheFoldedFileValidatesAgainstItsSchema(testCase)
% Validation ON. This is the test that fails if the built
% `acquisition_metadata_file` schema and the folded body ever disagree -- a new
% required field, a renamed edge, a changed file declaration. It is also the
% only test here that would catch the fold emitting a body the validator
% rejects, in which case the ORIGINAL passthrough is what stays in the batch
% (the replacement is keyed on the id coming back out of v1_to_v2) and
% `metadata_ingested_folds_withheld` is the number that says so.
%
% Requires the assembled V_eta schema set on DID_SCHEMA_PATH, which is why the
% rest of this file runs with Validate false.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the acquisition_metadata_file validation test');
try
    did2.schema.cache.shared().getClass('acquisition_metadata_file');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve acquisition_metadata_file (' ...
         err.message ').']);
end
out = did2.convert.v1_to_v2({ ...
        sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
        metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'})}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
[out, rep] = did2.convert.epochMint(out, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.mint_quarantined, 0, ...
    'a folded document that cannot validate is a build defect, not a data problem');
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 1);
verifyEqual(testCase, rep.metadata_ingested_folds_withheld, 0);
verifyNumElements(testCase, ofClass(out, 'acquisition_metadata_file'), 1);
end

% ===================== the 1 -> N arming path ==========================
%
%   ADDED 2026-08-12. Until then every arming loop in did2.convert.epochMint was
%   1 -> 1 and the file said so in as many words -- `:641 isscalar(folded)` and
%   `:689 "this batch is 1 -> 1 throughout"`. All three migrators waiting on the
%   epoch pass return MORE THAN ONE BODY on their armed branch, re-derived
%   2026-08-12 by reading the branch rather than the note:
%
%     +migrators_j/stimulus_response_scalar.m:287,307-310  {leaf, anchor[, sw]}
%     +migrators_j/daqreader_epochdata_ingested.m:105      [{preBody}, refs]
%     +migrators_j/daqreader_image_epochdata_ingested.m:103  same
%
%   so reusing the scalar assertion would have DROPPED the minted references and
%   left `time_reference_1` pointing outside the batch -- an ORPHAN, which the
%   corpus digest prints no counter for (open item #95).
%
%   NOTHING IN PRODUCTION RETURNS N TODAY, and that is a SCHEMA fact, not an
%   omission: re-derived 2026-08-12 over the built tree (247 JSON files, 241
%   with a document_class, deps read by JSON path and not by grep) exactly FOUR
%   classes declare an `epoch_id` dependency -- acquisition_metadata_file,
%   ingestion_manifest, directed_relation, method_parameters -- and none of the
%   three migrators above emits one of them on the arm. So the 1 -> N path is
%   driven here through `ArmingMigrators`, which exists for exactly that. A path
%   that ships without ever executing is this project's signature defect: a zero
%   that is a property of never having run.
%
%   THE STUB IS NOT AN INVENTION. It calls the REAL fold for the primary and the
%   REAL +migrators_j/daqreader_epochdata_ingested for the extras, so the extra
%   bodies are built by jEpochClockReferences -- the very helper both daqreader
%   arms use. Fixtures come from the emitter, never from a schema.

function tbl = armingTable(fcn)
%ARMINGTABLE The ArmingMigrators override, one row, same key epochMint arms.
tbl = struct('daqmetadatareader_epochdata_ingested', fcn);
end

function refs = realEpochExtentReferences(nClocks)
%REALEPOCHEXTENTREFERENCES N `relative_reference` bodies from the REAL emitter.
%   +migrators_j/daqreader_epochdata_ingested returns [{preBody}, refs] on its
%   armed branch; refs is what jEpochClockReferences built, one per clock. Take
%   everything after the pre-body.
refs = {};
if nClocks < 1
    % The migrator returns the BARE pre-body (not a cell) when there is nothing
    % to reference -- daqreader_epochdata_ingested.m:101-104 -- so `bodies(2:end)`
    % below would not be a cell. Short-circuit rather than special-case it after.
    return;
end
clocks = cell(1, nClocks);
t0t1   = zeros(2, nClocks);
for k = 1:nClocks
    clocks{k}  = sprintf('dev_local_time_%d', k);
    t0t1(:, k) = [0; 10 * k];
end
v1 = struct();
v1.document_class = struct('class_name', 'daqreader_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0') ]);
v1.depends_on = [ struct('name', 'daqreader_id', 'value', 'dr_1'), ...
                  struct('name', 'epoch_id',     'value', 'epoch_doc_stub') ];
v1.base = struct('id', 'ing_stub', 'session_id', 'sess_A', ...
    'name', 'ingested', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00001');
v1.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {clocks}, 't0_t1', t0t1));
bodies = did2.convert.migrators_j.daqreader_epochdata_ingested(v1);
refs = bodies(2:end);
end

function fcn = foldPlusNReferences(nExtras)
%FOLDPLUSNREFERENCES The production fold, then N real reference bodies.
%   The SHAPE all three waiting migrators return: body 1 replaces the source,
%   bodies 2..N are new documents the source points at.
fcn = @(b) [ {realFoldPrimary(b)}, realEpochExtentReferences(nExtras) ];
end

function primary = realFoldPrimary(b)
%REALFOLDPRIMARY The production fold's single body -- unchanged, not simulated.
primary = did2.convert.migrators_j.daqmetadatareader_epochdata_ingested(b);
if iscell(primary); primary = primary{1}; end
end

function [out, rep] = mintWithArming(v1, fcn)
out = runJ(v1);
[out, rep] = did2.convert.epochMint(out, 'Validate', false, ...
    'TargetVersion', 'V_eta', 'ArmingMigrators', armingTable(fcn));
end

function v1 = oneMetadataBatch()
v1 = { sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
       metadataIngestedBody('amf_1', 'sess_A', 't00001', 'mdr_1', {'data.bin'}) };
end

function testTheArmingPathStatesItsDenominatorBeforeItsResult(testCase)
% RULE 5. `arming_bodies_offered` is the denominator -- every body every armed
% migrator handed back -- and `..._carried` and `..._dropped` are only readable
% against it. On the production table this is the 1 -> 1 case and must be
% EXACTLY what it was before the rebuild.
[~, rep] = mintFrom(oneMetadataBatch());
verifyFalse(testCase, rep.arming_vacuous, ...
    'a batch that armed a migrator is not a vacuous run');
verifyEqual(testCase, rep.arming_calls, 1);
verifyEqual(testCase, rep.arming_bodies_offered, 1);
verifyEqual(testCase, rep.arming_bodies_carried, 1);
verifyEqual(testCase, rep.arming_bodies_dropped, 0, ...
    'a MEASURED zero: one body was offered and that same body was carried');
verifyEqual(testCase, rep.arming_extra_bodies_offered, 0);
verifyEqual(testCase, rep.arming_extra_bodies_carried, 0);
verifyEqual(testCase, rep.arming_max_bodies_per_call, 1, ...
    'the 1 -> N witness reads 1 while the only armed migrator returns one body');
verifyEqual(testCase, rep.arming_calls_returning_multiple, 0);
end

function testNoArmedMigratorAtAllIsVACUOUSNotZero(testCase)
% "did not run" and "ran and found nothing" must not read the same. With no
% source document the arming path never fires, and `arming_vacuous` is what says
% so -- every arming zero below it is then a zero over a zero denominator.
[~, rep] = mintFrom({ sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
                      elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1') });
verifyTrue(testCase, rep.arming_vacuous);
verifyEqual(testCase, rep.arming_calls, 0);
verifyEqual(testCase, rep.arming_bodies_offered, 0);
verifyEqual(testCase, rep.arming_bodies_carried, 0);
verifyEqual(testCase, rep.arming_bodies_dropped, 0);
end

function testAMigratorReturningThreeBodiesLandsAllThree(testCase)
% THE HEADLINE OF THIS BUILD. The old path unwrapped a 1-cell and treated
% anything else as a refusal, so two of these three would have been built,
% and silently discarded.
[out, rep] = mintWithArming(oneMetadataBatch(), foldPlusNReferences(2));

verifyEqual(testCase, rep.arming_calls, 1);
verifyEqual(testCase, rep.arming_bodies_offered, 3, ...
    'the DENOMINATOR: the migrator handed back three bodies');
verifyEqual(testCase, rep.arming_bodies_carried, 3, ...
    'all three must reach the batch -- this is the assertion the rebuild is for');
verifyEqual(testCase, rep.arming_bodies_dropped, 0);
verifyEqual(testCase, rep.arming_extra_bodies_offered, 2);
verifyEqual(testCase, rep.arming_extra_bodies_carried, 2);
verifyEqual(testCase, rep.arming_max_bodies_per_call, 3);
verifyEqual(testCase, rep.arming_calls_returning_multiple, 1);

verifyNumElements(testCase, ofClass(out, 'acquisition_metadata_file'), 1, ...
    'body 1 still takes the source document''s slot');
verifyEmpty(testCase, ofClass(out, 'daqmetadatareader_epochdata_ingested'), ...
    'the source class must not survive alongside the fold');
verifyNumElements(testCase, ofClass(out, 'relative_reference'), 2, ...
    'bodies 2..N must be APPENDED -- the half that did not exist before');
end

function testTheMintedReferencesAreTheEmittersOwnAndKeepTheirIds(testCase)
% Not merely "two documents of the right class arrived". The bodies the migrator
% built must be the bodies that landed, id for id, or the batch holds something
% nobody minted.
[out, ~] = mintWithArming(oneMetadataBatch(), foldPlusNReferences(2));
landed = ofClass(out, 'relative_reference');
ids = sort(cellfun(@(d) char(d.get('base.id')), landed, 'UniformOutput', false));
verifyNumElements(testCase, unique(ids), 2, ...
    'two distinct reference documents, not one document counted twice');
for k = 1:numel(landed)
    verifyNotEmpty(testCase, depValue(landed{k}.toStruct(), 'relative_to'), ...
        'a reference with no referent is the empty-required-edge pattern');
end
end

function testAddingOneMoreBodyAddsOneMoreDocument(testCase)
% THE MUTATION-SHAPED ASSERTION, and the one that fails the day anyone
% reintroduces `if iscell(folded) && isscalar(folded); folded = folded{1}; end`.
% Under that line every N would land the same single document, so the count
% would not move with N. It is asked as a DIFFERENCE so no constant can satisfy
% it.
[outA, repA] = mintWithArming(oneMetadataBatch(), foldPlusNReferences(1));
[outB, repB] = mintWithArming(oneMetadataBatch(), foldPlusNReferences(3));
verifyEqual(testCase, repA.arming_bodies_offered, 2);
verifyEqual(testCase, repB.arming_bodies_offered, 4);
verifyEqual(testCase, numel(outB.migrated) - numel(outA.migrated), 2, ...
    'two extra bodies offered must be two extra documents in the batch');
verifyEqual(testCase, repB.arming_extra_bodies_carried ...
    - repA.arming_extra_bodies_carried, 2);
end

function testDroppedEqualsOfferedMinusCarriedAndTheReasonsSumToIt(testCase)
% An instrument whose parts do not add up is not an instrument. Checked on a
% batch that carries AND on one that refuses, so the identity cannot hold by
% both sides being zero.
for nExtras = [0 2]
    [~, rep] = mintWithArming(oneMetadataBatch(), foldPlusNReferences(nExtras));
    verifyEqual(testCase, rep.arming_bodies_dropped, ...
        rep.arming_bodies_offered - rep.arming_bodies_carried);
    verifyEqual(testCase, rep.arming_bodies_dropped, ...
        rep.arming_bodies_dropped_declined ...
        + rep.arming_bodies_dropped_id_not_preserved ...
        + rep.arming_bodies_dropped_undeclared_edge ...
        + rep.arming_bodies_dropped_not_rebuilt ...
        + rep.arming_bodies_dropped_epoch_lost, ...
        'every dropped body must be dropped for a NAMED reason');
end
[~, repBad] = mintWithArming(oneMetadataBatch(), @(b) reIdentifiedFold(b));
verifyEqual(testCase, repBad.arming_bodies_dropped, ...
    repBad.arming_bodies_offered - repBad.arming_bodies_carried);
verifyEqual(testCase, repBad.arming_bodies_dropped, ...
    repBad.arming_bodies_dropped_declined ...
    + repBad.arming_bodies_dropped_id_not_preserved ...
    + repBad.arming_bodies_dropped_undeclared_edge ...
    + repBad.arming_bodies_dropped_not_rebuilt ...
    + repBad.arming_bodies_dropped_epoch_lost);
end

function bodies = reIdentifiedFold(b)
%REIDENTIFIEDFOLD The production fold with the primary's base.id REPLACED.
%   A fold that does not preserve `base.id` deletes the source id from the batch
%   and dangles every inbound reference to it -- the 11,448-orphan dissolution
%   failure recorded in CLAUDE.md, arriving as a fold instead of a migrator.
primary = realFoldPrimary(b);
primary.base.id = did.ido.unique_id();
bodies = [ {primary}, realEpochExtentReferences(1) ];
end

function testAPrimaryThatDoesNotPreserveTheIdIsRefusedWHOLE(testCase)
% The refusal is per CALL, not per body: the extras are minted for a primary
% that is not going to be carried, so carrying them would leave two documents
% referenced by nothing.
[out, rep] = mintWithArming(oneMetadataBatch(), @(b) reIdentifiedFold(b));
verifyEqual(testCase, rep.arming_bodies_offered, 2);
verifyEqual(testCase, rep.arming_bodies_carried, 0);
verifyEqual(testCase, rep.arming_bodies_dropped_id_not_preserved, 2, ...
    'BOTH bodies are dropped, and counted -- not just the offending one');
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 0);
verifyEqual(testCase, rep.metadata_ingested_folds_withheld, 1);
verifyEqual(testCase, rep.metadata_refused_unsafe_output, 1);
verifyNumElements(testCase, ofClass(out, 'daqmetadatareader_epochdata_ingested'), 1, ...
    'the ORIGINAL passthrough stays in the batch; nothing is lost');
verifyEmpty(testCase, ofClass(out, 'relative_reference'), ...
    'and the extras minted for it do not land');
end

function testAMigratorThatDeclinesStillReportsItsBodies(testCase)
% The declined body was still OFFERED. Counting only what is carried would make
% the denominator move with the outcome, which is the defect Rule 5 names.
[~, rep] = mintWithArming(oneMetadataBatch(), @(b) b);
verifyEqual(testCase, rep.arming_bodies_offered, 1);
verifyEqual(testCase, rep.arming_bodies_carried, 0);
verifyEqual(testCase, rep.arming_bodies_dropped_declined, 1);
verifyEqual(testCase, rep.metadata_refused_migrator_declined, 1);
end

function testAnArmingTableWithNoRowForTheClassIsAnError(testCase)
% A caller that overrode the table meant to override it. Falling back to the
% production migrator would let a test that thinks it is driving 1 -> N pass
% while driving 1 -> 1 -- a green result from machinery that never ran.
out = runJ(oneMetadataBatch());
verifyError(testCase, @() did2.convert.epochMint(out, 'Validate', false, ...
        'TargetVersion', 'V_eta', 'ArmingMigrators', struct('something_else', @(b) b)), ...
    'did2:convert:epochMint:noArmingMigrator');
end

function testAnExtraThatDoesNotSurviveTakesTHEWHOLECALLWithIt(testCase)
% THE ORPHAN GUARD, and the reason the carry is atomic. The primary references
% the bodies minted beside it, so emitting it while a sibling quarantined would
% put `time_reference_1` (or here `relative_to`'s referent) outside the batch.
% #37 RequiredDependencies is ARMED, so a `relative_reference` with an empty
% `relative_to` quarantines -- which is exactly the sibling failure to drive.
%
% VALIDATION ON. Needs the assembled V_eta schema set on DID_SCHEMA_PATH, like
% testMintedEpochValidatesAgainstItsSchema; the rest of this block runs with it
% off because the machinery, not the schema, is what those assert.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the atomic-carry validation test');
try
    did2.schema.cache.shared().getClass('relative_reference');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve relative_reference (' ...
         err.message ').']);
end
out = runJ(oneMetadataBatch());
[out, rep] = did2.convert.epochMint(out, 'Validate', true, ...
    'TargetVersion', 'V_eta', ...
    'ArmingMigrators', armingTable(@(b) foldPlusUnreferencedExtent(b)));

verifyEqual(testCase, rep.arming_bodies_offered, 2);
verifyEqual(testCase, rep.arming_bodies_carried, 0, ...
    'the primary validated, and is STILL not carried -- they live or die together');
verifyEqual(testCase, rep.arming_bodies_dropped_not_rebuilt, 2);
verifyEqual(testCase, rep.metadata_ingested_folds_emitted, 0);
verifyEqual(testCase, rep.metadata_ingested_folds_withheld, 1, ...
    'withheld is read off the CARRY DECISION, not off whether the primary came back');
verifyGreaterThan(testCase, rep.mint_quarantined, 0, ...
    'the bad extra is quarantined loudly, on a 0-quarantine gate');
verifyNumElements(testCase, ofClass(out, 'daqmetadatareader_epochdata_ingested'), 1, ...
    'the ORIGINAL passthrough stays -- valid under its own restored tombstone');
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
end

function bodies = foldPlusUnreferencedExtent(b)
%FOLDPLUSUNREFERENCEDEXTENT The fold, plus one reference with NO referent.
%   `relative_to` is mustBeNonEmpty (schemas/V_eta/stable/relative_reference.json),
%   so with #37 armed this body cannot validate. It is the invented-empty-edge
%   pattern used deliberately, as the sibling that must take the call down.
primary = realFoldPrimary(b);
refs = realEpochExtentReferences(1);
bad = refs{1};
bad.depends_on = struct('name', {'relative_to'}, 'value', {''});
bodies = { primary, bad };
end

function testTheMintCarriesTheSchemaAuthoritysOwnCounters(testCase)
% did2.convert.epochIndex is the schema authority the `undeclared_edge` refusal
% reads, and it answers FALSE both for "this class does not declare the edge"
% and for "I could not look". Those are different problems with different
% owners, so its own counters ride out with the report and
% `arming_edge_declaration_unchecked` is readable against them.
[~, rep] = mintFrom(oneMetadataBatch());
verifyTrue(testCase, isfield(rep, 'epoch_index_report'));
verifyTrue(testCase, isfield(rep.epoch_index_report, 'schema_lookups_unavailable'));
verifyTrue(testCase, isfield(rep.epoch_index_report, 'schema_lookups_failed'));
verifyTrue(testCase, isfield(rep, 'arming_edge_declaration_unchecked'));
end

function testTheEdgeDeclarationCheckIsSkippedNotFAKEDWhenValidationIsOff(testCase)
% Validate false says the caller turned schema checking off for this call. The
% guard does not then pretend to have checked: every body carrying `epoch_id`
% is counted UNCHECKED. A guard whose verdict depended on whether a schema path
% happened to resolve would let a configuration difference change the DATA.
[~, rep] = mintFrom(oneMetadataBatch());
verifyEqual(testCase, rep.arming_edge_declaration_unchecked, 1, ...
    'the folded acquisition_metadata_file carries epoch_id and was not checked');
verifyEqual(testCase, rep.arming_bodies_dropped_undeclared_edge, 0, ...
    'an unchecked body is not a refused body');
end
