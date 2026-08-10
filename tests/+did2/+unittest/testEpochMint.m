function tests = testEpochMint
%TESTEPOCHMINT The `epoch` mint (#60): one entity per (session, epoch-id) PAIR.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   nothing in this file has been run. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion.
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
% answers '' in pass 1). The other two classes declaring the edge --
% `ingestion_manifest`, `acquisition_metadata_file` -- are not emitted yet.
% (Three DEPENDENCIES over 245 V_eta schema files; `epochfiles_ingested`'s
% `epoch_id` is a char FIELD, not an edge, and a grep for the name conflates
% them.)
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
% `time_reference_#` (the epoch's extent) and `instrument_id` (the recording
% device) are both OPTIONAL and neither is derivable from an epoch-id string:
% the per-clock extents live in `daqreader_epochdata_ingested.epochtable` and
% the device needs the daq graph (#59). Declaring them empty is the pattern that
% put 26,406 documents into the census while every gate stayed green, so the
% assertion is about PRESENCE, not value.
[out, ~] = mintFrom({ ...
    sessionBody('sd_A', 'sess_A', 'ts_2008'), ...
    elementEpochBody('ee_1', 'sess_A', 't00069', 'el_1')});
epochs = ofClass(out, 'epoch');
s = epochs{1}.toStruct();
verifyFalse(testCase, hasDep(s, 'time_reference_1'));
verifyFalse(testCase, hasDep(s, 'instrument_id'));
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
