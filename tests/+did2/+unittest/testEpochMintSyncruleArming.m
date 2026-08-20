function tests = testEpochMintSyncruleArming
%TESTEPOCHMINTSYNCRULEARMING The THIRD armed fold in did2.convert.epochMint.
%
%   #60, the clock-alignment endpoints. `syncrule_mapping` is now armed: after
%   the epochs are minted the pass stamps `epoch_id_1` / `epoch_id_2` onto the
%   passed-through mapping and re-runs +migrators_j/syncrule_mapping, so its
%   BRANCH 1 (jClockAlignmentBodies) takes over from the #58 passthrough that has
%   been live on every did_v1 document since the gate was written. Branch 1 emits
%   a `clock_alignment` plus two `relative_reference` endpoints (1 -> 3).
%
%   THE EXACT ANALOG of the stimulus_response_scalar arming, adapted for TWO
%   endpoints and THREE output bodies. The differences that matter to a fixture:
%
%     * the mapping does NOT mint its own endpoint epochs. did2.validate.epochStrings
%       returns the sync endpoints in its DECLINED bucket, not HITS, so the mint
%       loop never makes an epoch from them. The endpoint epochs exist only
%       because OTHER documents in the batch carry the same (session, string)
%       pair -- here two `epochfiles_ingested` manifests. Omit them and the fold
%       correctly refuses (`syncrule_refused_no_epoch_document`).
%     * the passthrough mapping's `epoch_clock` is nested under
%       `epochnode_a.time_reference` (reshapeEpochNode); jClockAlignmentBodies'
%       referenceFor learned to read it there in this same build. `t0_t1` and
%       `objectname` stay at node level.
%
%   FIXTURES ARE BUILT FROM THE WRITER, never from a V_eta schema. `sessionBody`
%   and `ingestedBody` are copied verbatim from testEpochMint.m; `epochNodeFixture`
%   and `mappingFixture` from testMigratorsJClockAlignment.m -- the shape
%   syncgraph.m:296-320 writes, with the seven epochnode sub-fields the template
%   declares. The mapping is built in its did_v1 (flat) form and left to
%   did2.convert.v1_to_v2 to reshape into the passthrough, exactly as a real run
%   does -- rather than hand-building the reshaped shape.
%
%   STATUS: NEVER EXECUTED HERE. This container has no MATLAB -- `command -v
%   matlab octave octave-cli` prints nothing and exits 1 -- so every assertion
%   below is unexecuted; treat a first green CI run as the evidence, not this
%   header.
%
%   Run with:  results = runtests('did2.unittest.testEpochMintSyncruleArming');

tests = functiontests(localfunctions);
end

% ===================== harness =========================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function [out, rep] = mintFrom(v1)
%MINTFROM Pass 1 then the batch mint, with validation OFF.
out = runJ(v1);
[out, rep] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

function docs = ofClass(out, className)
docs = {};
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('document_class.class_name')), className)
        docs{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
end

function doc = docWithId(out, id)
doc = [];
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), id)
        doc = out.migrated{k};
        return;
    end
end
end

function v = depValueOf(doc, name)
%DEPVALUEOF The value of one depends_on entry, over both container shapes and
%   both wire spellings -- a struct array from the re-fold, a cell where setDep
%   had to grow one; `value` on a raw migrator body, `document_id` after
%   universalRenames. Copied from testEpochMint.m.
deps = doc.get('depends_on');
v = '';
for k = 1:numel(deps)
    if iscell(deps); e = deps{k}; else; e = deps(k); end
    if ~isstruct(e) || ~isfield(e, 'name'); continue; end
    if strcmp(char(e.name), name)
        if isfield(e, 'value') && ~isempty(e.value); v = char(e.value);
        elseif isfield(e, 'document_id') && ~isempty(e.document_id)
            v = char(e.document_id);
        end
        return;
    end
end
end

function tf = hasDep(doc, name)
tf = ~isempty(depValueOf(doc, name));
end

% ===================== the headline ====================================

function testTheMintArmsTheSyncruleFold(testCase)
% THE HEADLINE. Before this build every did_v1 syncrule_mapping passed through
% whole (5,316 documents in the last census) because branch 1's REQUIRED
% relative_reference.relative_to had no epoch to point at. The endpoint epochs
% now exist -- minted from the two manifests that share their (session, string)
% pairs -- so the fold runs and the mapping becomes a clock_alignment.
[out, rep] = mintFrom(batchWithBothEndpointEpochs());

verifyEqual(testCase, rep.syncrule_seen, 1, ...
    'the source document must be SEEN before any other count means anything');
verifyFalse(testCase, rep.syncrule_fold_vacuous, ...
    'a batch that held a source document is not a vacuous run');
verifyEqual(testCase, rep.syncrule_edges_stamped, 1, ...
    'both endpoint epochs resolved, so the two edges were stamped');
verifyEqual(testCase, rep.syncrule_folds_emitted, 1);
verifyEqual(testCase, rep.syncrule_folds_withheld, 0);
verifyEqual(testCase, rep.syncrule_refused_total, 0);

% the mapping is gone; a clock_alignment stands in its place, id PRESERVED.
verifyEmpty(testCase, ofClass(out, 'syncrule_mapping'), ...
    'the fold is 1 -> 3: the source class must not also survive');
align = ofClass(out, 'clock_alignment');
verifyNumElements(testCase, align, 1, ...
    'one clock_alignment per folded mapping');
verifyEqual(testCase, char(align{1}.get('base.id')), 'map_0001', ...
    'base.id is preserved, or syncgraph_id/syncrule_id into it break');

% ...and the two relative_reference endpoints appear. The epoch sources here are
% passthrough manifests that emit no references of their own, so the two are the
% ONLY relative_references in the batch.
refs = ofClass(out, 'relative_reference');
verifyNumElements(testCase, refs, 2, ...
    'branch 1 emits exactly two endpoint references');
end

function testTheAlignmentAnchorsEachEndpointAtItsMintedEpoch(testCase)
% Not merely "two references arrived". The clock_alignment's from_reference and
% to_reference must resolve to relative_reference documents whose `relative_to`
% names the epoch this pass MINTED for each endpoint's (session, string) pair --
% read back out of the batch, so the test cannot pass by agreeing with a constant.
[out, ~] = mintFrom(batchWithBothEndpointEpochs());
align = ofClass(out, 'clock_alignment');
verifyNumElements(testCase, align, 1);

% epoch local_identifier -> minted epoch document id
epochId = containers.Map('KeyType', 'char', 'ValueType', 'char');
for e = ofClass(out, 'epoch')
    epochId(char(e{1}.get('epoch.local_identifier'))) = char(e{1}.get('base.id'));
end
verifyTrue(testCase, isKey(epochId, 't00001') && isKey(epochId, 't00002'), ...
    'both endpoint epochs must have been minted');

fromId = depValueOf(align{1}, 'from_reference');
toId   = depValueOf(align{1}, 'to_reference');
verifyNotEmpty(testCase, fromId);
verifyNotEmpty(testCase, toId);
fromRef = docWithId(out, fromId);
toRef   = docWithId(out, toId);
verifyNotEmpty(testCase, fromRef, 'from_reference names no document in the batch');
verifyNotEmpty(testCase, toRef, 'to_reference names no document in the batch');
verifyEqual(testCase, char(fromRef.get('document_class.class_name')), ...
    'relative_reference');
verifyEqual(testCase, char(toRef.get('document_class.class_name')), ...
    'relative_reference');

% each reference anchored to ITS endpoint's minted epoch, and NOT left empty.
anchors = sort({depValueOf(fromRef, 'relative_to'), depValueOf(toRef, 'relative_to')});
expected = sort({epochId('t00001'), epochId('t00002')});
verifyEqual(testCase, anchors, expected, ...
    'the endpoints must anchor at the two minted epochs, not at any epoch');
end

function testTheRestoredEdgesResolveAndTheStampsDoNotPersist(testCase)
% syncgraph_id -> clock_alignment_policy_id and syncrule_id ->
% clock_alignment_configuration_id are the two edges v1 already writes; branch 1
% restores them. And the transient `epoch_id_1` / `epoch_id_2` this pass stamped
% must NOT survive on the emitted clock_alignment -- jClockAlignmentBodies builds
% depends_on BY NAME and never copies the stamped body's edges, so the stamp
% cannot leak (which is why armingIsSafe's undeclared_edge refusal cannot fire on
% the fold).
[out, ~] = mintFrom(batchWithBothEndpointEpochs());
align = ofClass(out, 'clock_alignment');
verifyEqual(testCase, depValueOf(align{1}, 'clock_alignment_policy_id'), ...
    'graph_0001', 'syncgraph_id must be restored as the policy edge');
verifyEqual(testCase, depValueOf(align{1}, 'clock_alignment_configuration_id'), ...
    'rule_ctoe', 'syncrule_id must be restored as the configuration edge');
verifyFalse(testCase, hasDep(align{1}, 'epoch_id_1'), ...
    'the stamped epoch_id_1 must not persist onto the fold');
verifyFalse(testCase, hasDep(align{1}, 'epoch_id_2'), ...
    'the stamped epoch_id_2 must not persist onto the fold');
end

% ===================== refusal, not invention ==========================

function testNoEndpointEpochDocumentIsRefusedNotFilledEmpty(testCase)
% Neither endpoint epoch exists (the manifests are omitted), so there is nothing
% to anchor to. The fold must refuse and keep the passthrough -- never a
% clock_alignment whose references have an empty required `relative_to` (the
% invented-empty-edge pattern the sync sign-off REMOVED).
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_0001', 'exp1'), ...
    mappingFixture(false)});
verifyEqual(testCase, rep.syncrule_seen, 1);
verifyEqual(testCase, rep.syncrule_refused_no_epoch_document, 1);
verifyEqual(testCase, rep.syncrule_refused_total, 1);
verifyEqual(testCase, rep.syncrule_edges_stamped, 0);
verifyEqual(testCase, rep.syncrule_folds_emitted, 0);
verifyEmpty(testCase, ofClass(out, 'clock_alignment'), ...
    'no epoch means no honest referent -- refuse, do not emit a hollow reference');
kept = ofClass(out, 'syncrule_mapping');
verifyNumElements(testCase, kept, 1, ...
    'the source document survives as the #58 passthrough');
verifyFalse(testCase, hasDep(kept{1}, 'epoch_id_1'), ...
    'a refused fold must leave no stamped edge behind on the passthrough');
end

function testOnlyOneEndpointResolvingIsStillARefusal(testCase)
% BRANCH 1 is gated on BOTH endpoints. A mapping with only endpoint A's epoch in
% the batch cannot anchor endpoint B, so the whole fold refuses -- one endpoint
% is never enough, exactly as syncrule_mapping.m/epochDocIds requires two ids.
[out, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_0001', 'exp1'), ...
    ingestedBody('efi_1', 'sess_0001', 't00001', 'nav_1'), ...
    mappingFixture(false)});
verifyEqual(testCase, rep.syncrule_seen, 1);
verifyEqual(testCase, rep.syncrule_refused_no_epoch_document, 1);
verifyEqual(testCase, rep.syncrule_folds_emitted, 0);
verifyNumElements(testCase, ofClass(out, 'syncrule_mapping'), 1);
verifyEmpty(testCase, ofClass(out, 'clock_alignment'));
end

% ===================== the denominator is reported =====================

function testTheFoldIsVacuousNotCleanWhenNoMappingIsPresent(testCase)
% A ZERO OVER A ZERO DENOMINATOR MUST SAY SO. A corpus holding no
% syncrule_mapping produces the same all-zero block as one where the fold ran and
% refused on every document; `syncrule_fold_vacuous` is what tells them apart.
[~, rep] = mintFrom({ ...
    sessionBody('sd_A', 'sess_0001', 'exp1'), ...
    ingestedBody('efi_1', 'sess_0001', 't00001', 'nav_1')});
verifyTrue(testCase, rep.syncrule_fold_vacuous, ...
    'no source mappings: the zeros below are untested, not clean');
verifyEqual(testCase, rep.syncrule_seen, 0);
verifyEqual(testCase, rep.syncrule_folds_emitted, 0);
verifyEqual(testCase, rep.syncrule_refused_total, 0);
end

function testTheReportCarriesTheFullSyncruleCounterSet(testCase)
% RULE 5, as a field-presence check: every counter this fold reconciles against
% must EXIST on the report before any document is read, so an all-zero run is
% distinguishable from a run that never touched the fold.
[~, rep] = mintFrom(batchWithBothEndpointEpochs());
for f = {'syncrule_seen', 'syncrule_already_folded', 'syncrule_edges_stamped', ...
         'syncrule_folds_emitted', 'syncrule_folds_withheld', ...
         'syncrule_refused_no_epoch_string', 'syncrule_refused_no_epoch_document', ...
         'syncrule_refused_migrator_declined', 'syncrule_refused_unsafe_output', ...
         'syncrule_refused_total', 'syncrule_fold_vacuous'}
    verifyTrue(testCase, isfield(rep, f{1}), ...
        sprintf('the report is missing the `%s` counter', f{1}));
end
end

% ===================== find-or-create, not create ======================

function testRunningTwiceFoldsOnceAndRecognisesTheAlignment(testCase)
% IDEMPOTENCE. ndi.migrate.local re-reads every document on a second pass over
% the same dataset. The second run must see the clock_alignment as ALREADY
% FOLDED rather than as a stranger, and mint no second epoch for a pair that
% already has one.
v1 = batchWithBothEndpointEpochs();
[out, rep1] = mintFrom(v1);
verifyEqual(testCase, rep1.syncrule_folds_emitted, 1);
verifyEqual(testCase, rep1.epochs_minted, 2);

[out2, rep2] = did2.convert.epochMint(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep2.syncrule_already_folded, 1, ...
    'the second run must RECOGNISE the folded clock_alignment');
verifyEqual(testCase, rep2.syncrule_seen, 0, ...
    'the source mapping is gone, so nothing new is seen');
verifyEqual(testCase, rep2.epochs_minted, 0, ...
    'find-or-create: the epochs already in the batch are found, not re-minted');
verifyNumElements(testCase, ofClass(out2, 'clock_alignment'), 1);
verifyEmpty(testCase, ofClass(out2, 'syncrule_mapping'));
end

% ===================== validation ======================================

function testTheFoldedAlignmentValidatesAgainstItsSchema(testCase)
% Validation ON. Fails if the built clock_alignment / relative_reference schemas
% and the folded bodies ever disagree. The four target classes are in the DRAFT
% tier, so this needs the assembled V_eta set (stable + draft) on
% DID_SCHEMA_PATH; the quick gate assembles exactly that, which is why the rest
% of this file runs with Validate false.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the clock_alignment validation test');
try
    did2.schema.cache.shared().getClass('clock_alignment');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve clock_alignment (' err.message ').']);
end
out = did2.convert.v1_to_v2(batchWithBothEndpointEpochs(), ...
    'Validate', false, 'TargetVersion', 'V_eta');
[out, rep] = did2.convert.epochMint(out, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.mint_quarantined, 0, ...
    'a folded document that cannot validate is a build defect, not a data problem');
verifyEqual(testCase, rep.syncrule_folds_emitted, 1);
verifyEqual(testCase, rep.syncrule_folds_withheld, 0);
verifyNumElements(testCase, ofClass(out, 'clock_alignment'), 1);
end

% ===================== fixtures, from the WRITER =======================

function v1 = batchWithBothEndpointEpochs()
%BATCHWITHBOTHENDPOINTEPOCHS A session, the two manifests whose (session, string)
%   pairs mint the mapping's endpoint epochs, and one did_v1 syncrule_mapping.
%   The manifest epoch strings (t00001, t00002) and session (sess_0001) MATCH the
%   epochnode ids and base.session_id the mapping fixture carries, so the fold
%   resolves both endpoints.
v1 = { ...
    sessionBody('sd_A', 'sess_0001', 'exp1'), ...
    ingestedBody('efi_1', 'sess_0001', 't00001', 'nav_1'), ...
    ingestedBody('efi_2', 'sess_0001', 't00002', 'nav_2'), ...
    mappingFixture(false)};
end

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 `session` document. Copied verbatim from testEpochMint.m.
%   The two ids are DIFFERENT strings: ndi.document.m:57 sets base.id from a
%   fresh ido, ndi.session.m:215 sets base.session_id separately. epoch.session_id
%   must point at the former, so the fixture uses visibly different strings.
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

function v1 = ingestedBody(docId, sessionId, epochId, navigatorId)
%INGESTEDBODY A did_v1 `epochfiles_ingested` body. Copied verbatim from
%   testEpochMint.m (corpus B: across all 2,484 the block key set is exactly
%   {epoch_id, epochprobemap, files} and the dependency name set is exactly
%   {filenavigator_id}). Chosen as the epoch source because it is a deliberate
%   passthrough (epochfiles_ingested.m:277 `bodies = {preBody}`) -- it mints its
%   epoch via the string but emits no references of its own, so the only
%   relative_references in the batch are the fold's two endpoints.
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

function node = epochNodeFixture(suffix, objectName)
%EPOCHNODEFIXTURE One epochnode, with all seven sub-fields the template declares.
%   Copied verbatim from testMigratorsJClockAlignment.m. `epochprobemap` is a
%   CHAR (syncgraph.m:313 serialises it; the template's default is ""); a struct
%   is what made the old reader look correct while dropping the field on every
%   real document.
node = struct( ...
    'epoch_id',         ['t0000' suffix], ...
    'epoch_session_id', 'sess_0001', ...
    'epochprobemap',    sprintf('name\treference\ttype\ndev%s\t1\tn-trode\n', suffix), ...
    'epoch_clock',      'dev_local_time', ...
    't0_t1',            [0 100 + str2double(suffix)], ...
    'objectname',       objectName, ...
    'objectclass',      'ndi.daq.system.mfdaq');
end

function v1 = mappingFixture(withEpochEdges)
%MAPPINGFIXTURE A did_v1 syncrule_mapping as syncgraph.m:296-320 writes it.
%   Copied verbatim from testMigratorsJClockAlignment.m. `mapping` is documented
%   as "[1xN] coefficients of a polynomial, HIGH EXPONENTS FIRST" -- the same
%   order polynomial.value.coefficients declares. With withEpochEdges=false it is
%   the ordinary did_v1 shape that v1_to_v2 reshapes into the #58 passthrough;
%   the arming stamps `epoch_id_1` / `epoch_id_2` afterwards.
if nargin < 1; withEpochEdges = false; end
v1 = struct();
v1.document_class = struct('class_name', 'syncrule_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
names  = {'syncgraph_id', 'syncrule_id'};
values = {'graph_0001', 'rule_ctoe'};
if withEpochEdges
    names  = [names,  {'epoch_id_1', 'epoch_id_2'}];
    values = [values, {'epochdoc_a', 'epochdoc_b'}];
end
v1.depends_on = struct('name', names, 'value', values);
v1.base = struct('id', 'map_0001', 'session_id', 'sess_0001', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.syncrule_mapping = struct('cost', 1, 'mapping', [1.0002 -0.5], ...
    'epochnode_a', epochNodeFixture('1', 'vhtaste_sync'), ...
    'epochnode_b', epochNodeFixture('2', 'vhtaste_bpod'));
end
