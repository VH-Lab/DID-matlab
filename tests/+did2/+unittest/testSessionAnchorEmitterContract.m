function tests = testSessionAnchorEmitterContract
%TESTSESSIONANCHOREMITTERCONTRACT The pass-1 emitters against the pass-2 fold.
%
%   STATUS: WRITTEN 2026-08-11, NEVER EXECUTED. This container has no MATLAB and
%   no Octave (`command -v matlab octave octave-cli` exits 1 with no output), so
%   no line in this file has been run. CI is the first execution.
%
%   NEW FILE, deliberately. `testMigratorsJ.m`, `testFixtureCorpus.m` and
%   `testCorpusPRED.m` are owned by other sessions and are not touched.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST, AND WHY IT IS NOT WHAT testTimeReferenceCollapse TESTS
%   ---------------------------------------------------------------------
%   `did2.convert.resolveSessionAnchors` is already pinned, thoroughly, by
%   tests/+did2/+unittest/testTimeReferenceCollapse.m. Every fixture in that file
%   is a HAND COPY of an emitter -- its own header says so: *"FIXTURES ARE COPIED
%   FROM THE LIVE EMITTERS ... Each builder names its source line."* A copy is
%   the right way to test the fold and the wrong way to test the SEAM, because
%   the copy cannot drift when the emitter does. That is this repository's
%   recorded trap in its exact shape:
%
%       "A TEST WRITTEN FROM THE SAME PREMISE AS THE CODE CANNOT CATCH THE CODE."
%       (DID-schema/CLAUDE.md)
%
%   So this file asserts nothing about the fold's internals. It drives the REAL
%   pass-1 migrators, takes whatever anchor documents they actually mint, and
%   asserts the fold can consume every one of them with ZERO refusals.
%
%   ---------------------------------------------------------------------
%   WHY THE MIGRATORS STILL MINT A RETIRED CLASS -- IT IS NOT AN OVERSIGHT
%   ---------------------------------------------------------------------
%   The signed model (DID-schema/schemas/V_eta_time_reference_model_plan.md,
%   TEAM-SIGN-OFF [time_reference], jess@walthamdatascience.com / 2026-08-08)
%   collapses eight reference classes to `absolute_reference` +
%   `relative_reference`. A reader who greps for `session_relative_reference` in
%   +migrators_j finds it alive at eight mint sites and concludes the migrators
%   were left behind. They were not. The SAME plan forbids the obvious change,
%   in its own words:
%
%       "A pass-1 migrator knows the epoch string ... but not the
%        acquisition_epoch document id, so it cannot populate `relative_to`."
%                                     -- plan, "Pass 1 vs pass 2"
%       "A: `relative_to` is REQUIRED (team call)."
%                                     -- plan, fork A
%
%   and the landed schema says the same thing on the field itself
%   (DID-schema/schemas/V_eta/stable/relative_reference.json, depends_on
%   relative_to, `mustBeNonEmpty: true`):
%
%       "NOT fillable in pass 1: a migrator holds `base.session_id`, and the edge
%        needs the session DOCUMENT's `base.id`, which is a different, freshly
%        minted uid (NDI-matlab +ndi/document.m:57-58).
%        did2.convert.resolveSessionAnchors is the batch pass that resolves it."
%
%   Verified in NDI-matlab (3b351efe0) rather than taken on trust:
%     +ndi/document.m:57-58   ndiido = ndi.ido();
%                             document_properties.base.id = ndiido.id();
%     +ndi/session.m:215      inputs = cat(2,varargin,
%                                 {'base.session_id', ndi_session_obj.id()});
%     +ndi/session.m:35       ndi_session_obj.identifier = ndiido.id();
%   -- the session object's identifier is minted in the session constructor, the
%   document's id in the document constructor. Two independent uids. A pass-1
%   migrator holding one cannot produce the other.
%
%   Emitting `relative_reference` with an EMPTY `relative_to` is not the fallback
%   it looks like: `+did2/+validate/references.m:90` SKIPS empty edges, so the
%   husks would validate clean and no gate would ever see them -- the
%   invented-empty-edge pattern at ~106k documents, an order of magnitude past
%   the previous record of 11,440.
%
%   So the pass-1 mint is the HANDLE and the batch pass is the RESOLUTION, which
%   is the shape the plan itself prescribes. What that costs is a load-bearing
%   dependency between two files nothing was checking: if an emitter drifts to a
%   `relation` the fold refuses, or stops carrying `base.session_id`, the fold
%   quietly refuses those documents, the retired class SURVIVES the migration,
%   and the deletion gate in resolveSessionAnchors.m ("refused_total == 0 AND
%   zero surviving session_*_reference in by_class") never opens. Nothing
%   subtracts and nothing goes red. This file is that check.
%
%   ---------------------------------------------------------------------
%   DENOMINATOR -- STATED FIRST AND UNCONDITIONALLY (Operating Rule 5)
%   ---------------------------------------------------------------------
%   TEN sites in +did2/+convert/+migrators_j assign a retired time-reference
%   class to `document_class`:
%
%       session_relative_reference   9   private/jSessionAnchor.m:60  (shared,
%                                          13 call sites), treatment_transfer.m:109,
%                                          fitcurve.m:147, jrclust_clusters.m:88,
%                                          image_stack.m:279, pyraview.m:105,
%                                          vmspikefit.m:141,
%                                          neuron_extracellular.m:118,
%                                          ontology_table_row.m:867
%       session_bounded_reference    1   ontology_table_row.m:275
%
%   SIX of the ten are exercised below, covering BOTH code paths (the shared
%   helper and the hand-rolled duplicates). The four that are not, and why:
%
%       ontology_table_row.m:867   NOT DRIVEN -- the file is owned by another
%       ontology_table_row.m:275     session and was not opened. These are the
%                                    ONLY two sites of `session_bounded_reference`
%                                    in the repository, so the BOUNDED arm of the
%                                    fold has no emitter-driven coverage at all.
%                                    A named gap, not a silent one.
%       image_stack.m:279          NOT DRIVEN -- image_stack is mid-rebuild by
%                                    another session (the subject-less
%                                    passthrough guard at image_stack.m:78, and
%                                    the phase-8 restoration of both tombstones).
%                                    Driving it here would assert a shape that is
%                                    being changed underneath.
%       pyraview.m:105              NOT DRIVEN -- its fold runs through the data
%                                    body tier (`opaque_body` / `sampled_body`),
%                                    which another session is rebuilding.
%
%   Run with:  results = runtests('did2.unittest.testSessionAnchorEmitterContract');

tests = functiontests(localfunctions);
end

% ===================== the emitter roster ==============================

function roster = emitterRoster()
%EMITTERROSTER The pass-1 emitters this file drives, and the mint site each one
%   exercises. `path` is the code path: 'shared' = private/jSessionAnchor.m,
%   'local' = a hand-rolled duplicate inside the migrator itself.
roster = { ...
    struct('name', 'probe_location',       'site', 'private/jSessionAnchor.m:60', ...
           'path', 'shared', 'build', @probeLocationBody), ...
    struct('name', 'treatment_transfer',   'site', 'treatment_transfer.m:109', ...
           'path', 'local',  'build', @treatmentTransferBody), ...
    struct('name', 'fitcurve',             'site', 'fitcurve.m:147', ...
           'path', 'local',  'build', @fitcurveBody), ...
    struct('name', 'jrclust_clusters',     'site', 'jrclust_clusters.m:88', ...
           'path', 'local',  'build', @jrclustClustersBody), ...
    struct('name', 'vmspikefit',           'site', 'vmspikefit.m:141', ...
           'path', 'local',  'build', @vmspikefitBody), ...
    struct('name', 'neuron_extracellular', 'site', 'neuron_extracellular.m:118', ...
           'path', 'local',  'build', @neuronExtracellularBody)};
end

% ===================== harness =========================================

function out = passOne(v1cells)
%PASSONE The migrators, exactly as the corpus runs them.
%   Validation is OFF: it needs the assembled V_eta schema set on
%   DID_SCHEMA_PATH, and nothing here is asserting schema conformance -- that is
%   testTimeReferenceCollapse's testTheFoldedDocumentValidatesAgainstItsSchema.
out = did2.convert.v1_to_v2(v1cells, 'Validate', false, 'TargetVersion', 'V_eta');
end

function [out, rep] = foldBatch(v1cells)
out = passOne(v1cells);
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

function v = depValue(s, name)
%DEPVALUE Read one depends_on entry off a body STRUCT. v1 writes `document_id`,
%   V_eta writes `value`; both spellings are read because a migrated batch holds
%   documents of both vintages at once.
v = '';
if ~isstruct(s) || ~isfield(s, 'depends_on'); return; end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if isfield(d, 'name') && strcmp(char(d.name), name)
        if isfield(d, 'value') && ~isempty(d.value)
            v = char(d.value);
        elseif isfield(d, 'document_id') && ~isempty(d.document_id)
            v = char(d.document_id);
        end
        return;
    end
end
end

% ===================== fixtures ========================================

function v1 = sessionBody(docId, sessionId, reference)
%SESSIONBODY A did_v1 `session` document.
%
%   TEMPLATE: src/ndi/ndi_common/database_documents/session.json -- superclasses
%   [base], no depends_on, one field `session.reference`.
%   WRITER (+ndi/+session/dir.m:138-140):
%       g = ndi.document('session','session.reference',...reference) + ...
%           ndi_session_dir_obj.newdocument();
%       ndi_session_dir_obj.database_add(g);
%   `session` has NO migrator in +migrators_j, so it passes through with its
%   class and id intact -- which is what the coverage ledger row
%   `| session | session | persist | ndi |` records.
%
%   docId AND sessionId ARE DELIBERATELY DIFFERENT STRINGS. That is the whole
%   reason the fold exists, and a fixture that made them equal would let a
%   confusion between them pass.
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

function v1 = probeLocationBody(sessionId)
% Exercises the SHARED helper, private/jSessionAnchor.m:60 (13 call sites).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:606-611.
v1 = struct();
v1.document_class = struct('class_name', 'probe_location', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_42'});
v1.base = struct('id', 'pl_01', 'session_id', sessionId, ...
    'name', 'pl', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_location = struct('ontology_name', 'uberon:0002436', ...
    'name', 'primary visual cortex');
end

function v1 = treatmentTransferBody(sessionId)
% Exercises treatment_transfer.m:109 (local makeSessionAnchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:365-374.
v1 = struct();
v1.document_class = struct('class_name', 'treatment_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = [ ...
    struct('name', 'recipient_id', 'document_id', 'rec_001'), ...
    struct('name', 'donor_id',     'document_id', 'don_002')];
v1.base = struct('id', 'tt_01', 'session_id', sessionId, ...
    'name', 'graft', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_transfer = struct( ...
    'entity_ontologyNode', 'uberon:0000922', 'entity_name', 'embryonic tissue', ...
    'method_name', 'transplantation');
end

function v1 = fitcurveBody(sessionId)
% Exercises fitcurve.m:147 (local jAnchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:3603-3608 -- fit_equation and
% fit_sse are the NDI template's own field names.
v1 = struct();
v1.document_class = struct('class_name', 'fitcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {'sub_9'});
v1.base = struct('id', 'fc_1', 'session_id', sessionId, 'name', 'fc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.fitcurve = struct('fit_equation', 'gaussian', 'fit_sse', 12.5);
end

function v1 = jrclustClustersBody(sessionId)
% Exercises jrclust_clusters.m:88 (local classBlock anchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:3207-3213.
v1 = struct();
v1.document_class = struct('class_name', 'jrclust_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {'sub_8'});
v1.base = struct('id', 'jc_1', 'session_id', sessionId, ...
    'name', 'jc', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.jrclust_clusters = struct('res_mat_md5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');
v1.files = struct('file_list', {{'clusters.mat'}});
end

function v1 = vmspikefitBody(sessionId)
% Exercises vmspikefit.m:141 (local jAnchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:3683-3689.
v1 = struct();
v1.document_class = struct('class_name', 'vmspikefit', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {'sub_a'});
v1.base = struct('id', 'vf_1', 'session_id', sessionId, 'name', 'vf', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.vmspikefit = struct('fit_equation', 'exp2', 'fit_sse', 3.25);
end

function v1 = neuronExtracellularBody(sessionId)
% Exercises neuron_extracellular.m:118 (local classBlock anchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:3520-3527.
v1 = struct();
v1.document_class = struct('class_name', 'neuron_extracellular', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
v1.base = struct('id', 'ne_1', 'session_id', sessionId, ...
    'name', 'ne', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.neuron_extracellular = struct('cluster_index', 7, 'quality_number', 3, ...
    'number_of_channels', 4);
end

% ===================== the roster is an instrument =====================

function testTheRosterStatesItsDenominatorBeforeAnythingIsDriven(testCase)
% Operating Rule 5. A per-emitter loop that silently iterated over an empty or
% half-built roster would report six green assertions about nothing -- which is
% exactly how silentLoss printed "0 empty edges" for two days. The count is
% checked before any migrator runs, and the fixed roster of 6 is the number the
% header's denominator paragraph claims.
roster = emitterRoster();
verifyEqual(testCase, numel(roster), 6, ...
    'the roster changed size -- update the DENOMINATOR block in the header');
shared = 0;
for k = 1:numel(roster)
    verifyTrue(testCase, isa(roster{k}.build, 'function_handle'));
    verifyNotEmpty(testCase, roster{k}.site);
    if strcmp(roster{k}.path, 'shared'); shared = shared + 1; end
end
% BOTH code paths must stay covered. The shared helper is one site serving 13
% callers; the five hand-rolled duplicates are five independent chances to drift.
verifyEqual(testCase, shared, 1);
verifyEqual(testCase, numel(roster) - shared, 5);
end

% ===================== the seam ========================================

function testEveryDrivenEmitterActuallyMintsAnAnchor(testCase)
% The precondition for everything below. If a migrator stopped emitting an
% anchor entirely, every fold assertion in this file would pass vacuously (0
% seen, 0 refused, 0 folded) -- a green run measuring nothing. So the anchor is
% counted per emitter, by name, before the fold is asked anything.
roster = emitterRoster();
for k = 1:numel(roster)
    e = roster{k};
    make = e.build;
    out = passOne({make('SID_1')});
    anchors = ofClass(out, 'session_relative_reference');
    verifyEqual(testCase, numel(anchors), 1, sprintf( ...
        ['%s (%s) minted %d session anchors, expected exactly 1. If this ' ...
         'migrator legitimately stopped anchoring, remove it from the roster ' ...
         'and correct the header denominator -- do not weaken this count.'], ...
        e.name, e.site, numel(anchors)));
end
end

function testEveryEmittedAnchorCarriesTheSessionIdTheFoldJoinsOn(testCase)
% `base.session_id` is the ONLY handle the fold has: resolveSessionAnchors.m:255
% reads it, and an empty one is `refused_no_session_id`. Every emitter defaults
% it to '' when the source body has none, so this is a real path, not a
% hypothetical one.
roster = emitterRoster();
for k = 1:numel(roster)
    e = roster{k};
    make = e.build;
    out = passOne({make('SID_1')});
    anchor = ofClass(out, 'session_relative_reference');
    verifyEqual(testCase, char(anchor{1}.get('base.session_id')), 'SID_1', ...
        sprintf('%s (%s) lost base.session_id -- the fold cannot join it', ...
        e.name, e.site));
end
end

function testEveryEmittedRelationIsOneTheFoldCanMap(testCase)
% The drift the fold cannot defend itself against. `owlTimeTerm`
% (resolveSessionAnchors.m:389) maps five of v1's six relations; the sixth,
% `concurrent_with`, is REFUSED because it is genuinely ambiguous between
% OWL-Time's intervalEquals and intervalOverlaps. An emitter that started
% writing it -- or anything outside the enum -- would silently strand its
% documents in the retired class. All emitters write 'during' today; this
% asserts that, rather than assuming it.
mappable = {'before', 'after', 'at_start_of', 'at_end_of', 'during'};
roster = emitterRoster();
for k = 1:numel(roster)
    e = roster{k};
    make = e.build;
    out = passOne({make('SID_1')});
    anchor = ofClass(out, 'session_relative_reference');
    rel = char(anchor{1}.get('session_relative_reference.relation'));
    verifyTrue(testCase, any(strcmp(mappable, rel)), sprintf( ...
        '%s (%s) writes relation "%s", which the fold REFUSES', ...
        e.name, e.site, rel));
end
end

function testEveryEmittedAnchorFoldsWithNoRefusals(testCase)
% THE TEST. One batch, every driven emitter plus the session document, through
% pass 1 and then the batch fold. anchors_folded must equal anchors_seen and
% every refusal counter must be zero -- because a refusal here is not a caught
% error, it is a `session_relative_reference` that SURVIVES the migration and
% holds the deletion gate shut forever.
roster = emitterRoster();
batch = {sessionBody('sess_doc_1', 'SID_1', 'exp1')};
for k = 1:numel(roster)
    make = roster{k}.build;
    batch{end+1} = make('SID_1'); %#ok<AGROW>
end

[out, rep] = foldBatch(batch);

verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.session_documents_seen, 1);
verifyEqual(testCase, rep.anchors_seen, numel(roster), ...
    'one anchor per driven emitter was expected');
verifyEqual(testCase, rep.anchors_relative, numel(roster));
verifyEqual(testCase, rep.anchors_bounded, 0, ...
    'no driven emitter mints session_bounded_reference -- see the header gap');
verifyEqual(testCase, rep.anchors_folded, numel(roster));
verifyEqual(testCase, rep.fold_quarantined, 0);

% Each refusal counter separately, so a failure names its cause instead of
% making the reader re-derive it from a total.
verifyEqual(testCase, rep.refused_no_session_id, 0);
verifyEqual(testCase, rep.refused_no_session_document, 0);
verifyEqual(testCase, rep.refused_ambiguous_session, 0);
verifyEqual(testCase, rep.refused_ambiguous_relation, 0);
verifyEqual(testCase, rep.refused_unknown_relation, 0);
verifyEqual(testCase, rep.refused_negative_extent, 0);
verifyEqual(testCase, rep.refused_total, 0);

% and the retired class is gone from the batch entirely
verifyFalse(testCase, any(strcmp(classNames(out), 'session_relative_reference')), ...
    'a retired class survived pass 2 -- the deletion gate cannot open');
verifyEqual(testCase, numel(ofClass(out, 'relative_reference')), numel(roster));
end

function testTheIdOfEveryEmittedAnchorSurvivesTheFold(testCase)
% THE ID MUST BE PRESERVED. Every migrated statement points at its anchor
% through `time_reference_#`, so a fold that minted a replacement would dangle
% all of them -- the 11,448-orphan dissolution failure at ten times the size.
% The ids are collected from the EMITTERS' own output (they are freshly minted
% uids, unknown until pass 1 runs) and each one must still name a document
% afterwards.
roster = emitterRoster();
batch = {sessionBody('sess_doc_1', 'SID_1', 'exp1')};
for k = 1:numel(roster)
    make = roster{k}.build;
    batch{end+1} = make('SID_1'); %#ok<AGROW>
end

before = passOne(batch);
anchorIds = {};
for k = 1:numel(before.migrated)
    if strcmp(char(before.migrated{k}.get('document_class.class_name')), ...
            'session_relative_reference')
        anchorIds{end+1} = char(before.migrated{k}.get('base.id')); %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(anchorIds), numel(roster));

[after, ~] = did2.convert.resolveSessionAnchors(before, ...
    'Validate', false, 'TargetVersion', 'V_eta');
afterIds = cellfun(@(d) char(d.get('base.id')), after.migrated, ...
    'UniformOutput', false);
for k = 1:numel(anchorIds)
    verifyTrue(testCase, any(strcmp(afterIds, anchorIds{k})), sprintf( ...
        'anchor id %s vanished in the fold -- every time_reference_# edge to it dangles', ...
        anchorIds{k}));
end
end

function testTheStatementEdgeStillResolvesAfterTheFold(testCase)
% The orphan question asked end to end rather than through a stand-in pointer:
% treatment_transfer wires `time_reference_1` onto the act it emits
% (treatment_transfer.m:84) using the anchor's own base.id. After the fold that
% edge must still name a document in the batch.
[out, rep] = foldBatch({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    treatmentTransferBody('SID_1')});
verifyEqual(testCase, rep.anchors_folded, 1);

acts = ofClass(out, 'term_manipulation');
verifyEqual(testCase, numel(acts), 1);
target = depValue(acts{1}.toStruct(), 'time_reference_1');
verifyNotEmpty(testCase, target, 'the act lost its time_reference_1 edge');

ids = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(ids, target)), ...
    'time_reference_1 no longer resolves -- the fold orphaned the statement');
% and what it now points at is the folded reference, on the session DOCUMENT
ref = ofClass(out, 'relative_reference');
verifyEqual(testCase, char(ref{1}.get('base.id')), target);
verifyEqual(testCase, depValue(ref{1}.toStruct(), 'relative_to'), 'sess_doc_1');
verifyNotEqual(testCase, depValue(ref{1}.toStruct(), 'relative_to'), 'SID_1');
end

function testAnEmitterAnchorWithNoSessionDocumentIsLeftIntactNotHollowed(testCase)
% The refusal path, driven from a REAL emitter rather than a copied fixture.
% Discovery mode hands the fold a subset batch that need not contain the session
% document -- jSessionAnchor's own note about discovery-mode orphans, which this
% project has recorded as CORRECT. The document must be left exactly as it is
% and counted, never given an empty required edge: `references.m:90` skips empty
% edges, so a hollowed one would validate clean and no gate would see it.
[out, rep] = foldBatch({probeLocationBody('SID_1')});   % no session document

verifyEqual(testCase, rep.session_documents_seen, 0);
verifyEqual(testCase, rep.anchors_seen, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, rep.refused_no_session_document, 1);
verifyEqual(testCase, rep.refused_total, 1);

anchors = ofClass(out, 'session_relative_reference');
verifyEqual(testCase, numel(anchors), 1, ...
    'the refused anchor must survive untouched, not be dropped');
verifyEmpty(testCase, depValue(anchors{1}.toStruct(), 'relative_to'));
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
end
