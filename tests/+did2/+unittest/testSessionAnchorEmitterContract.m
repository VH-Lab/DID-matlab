function tests = testSessionAnchorEmitterContract
%TESTSESSIONANCHOREMITTERCONTRACT The pass-1 emitters against the pass-2 fold.
%
%   STATUS: WRITTEN 2026-08-11, NEVER EXECUTED. EXTENDED 2026-08-11 (bounded
%   arm), ALSO NEVER EXECUTED. This container has no MATLAB and no Octave --
%
%       $ command -v matlab octave octave-cli
%       $ echo $?
%       1
%
%   -- so no line in this file has been run, by either session. CI is the first
%   execution.
%
%   TWO TESTS IN THE BOUNDED SECTION ARE EXPECTED TO FAIL ON THAT FIRST RUN, and
%   they are the point of the extension rather than an accident of it:
%   `testTheBoundedWindowExtentSurvivesTheFold` and
%   `testAReversedBoundedWindowIsRefusedNotSilentlyFolded`. Both fail for ONE
%   cause, recorded under DEFECT below: the real emitter writes a duration cell
%   with no `seconds`, and the fold reads only `seconds`. The fix belongs in a
%   SEPARATE commit from this coverage so the two stay separable.
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
%   class to `document_class`. RE-DERIVED 2026-08-11 rather than carried over --
%
%       $ grep -rn "session_relative_reference\|session_bounded_reference" \
%             --include=*.m src/did/+did2/+convert/+migrators_j/ \
%         | grep "document_class ="
%       .../vmspikefit.m:141           classBlock('session_relative_reference', ...
%       .../fitcurve.m:147             classBlock('session_relative_reference', ...
%       .../neuron_extracellular.m:118 classBlock('session_relative_reference', ...
%       .../treatment_transfer.m:109   struct('class_name', 'session_relative_...
%       .../private/jSessionAnchor.m:60 struct('class_name', 'session_relative_...
%       .../pyraview.m:105             classBlock('session_relative_reference', ...
%       .../ontology_table_row.m:275   struct('class_name', 'session_bounded_...
%       .../ontology_table_row.m:867   struct('class_name', 'session_relative_...
%       .../image_stack.m:279          classBlock('session_relative_reference', ...
%       .../jrclust_clusters.m:88      classBlock('session_relative_reference', ...
%
%       session_relative_reference   9
%       session_bounded_reference    1   ontology_table_row.m:275 ONLY
%
%   A CORRECTION TO THIS FILE'S OWN PREVIOUS DENOMINATOR PARAGRAPH, which said
%   ontology_table_row.m:867 was the second `session_bounded_reference` site and
%   that "these are the ONLY two sites of session_bounded_reference in the
%   repository". POSITIVE EVIDENCE THAT IT IS NOT -- :867 is the RELATIVE class,
%   inside the local `makeSessionAnchor`:
%
%       $ sed -n '866,876p' .../+migrators_j/ontology_table_row.m
%       anchor.document_class = struct('class_name', 'session_relative_reference', ...
%       ...
%       anchor.session_relative_reference = struct('relation', relation);
%
%   `session_bounded_reference` is minted at ONE site in the entire repository:
%   ontology_table_row.m:275, inside `makeEncounterWindow`. The grep above is the
%   whole of +migrators_j; the sweep over `src/` finds the string nowhere else
%   except resolveSessionAnchors.m, which CONSUMES it.
%
%   ALL TEN SITES ARE NOW DRIVEN -- 9 by the relative roster, 1 by the bounded
%   roster -- across BOTH code paths (the shared helper and the hand-rolled
%   duplicates). image_stack.m:279 and pyraview.m:105 were previously listed as
%   NOT DRIVEN because those migrators were being rebuilt elsewhere; they are
%   driven now, and DELIBERATELY ONLY FOR THEIR ANCHOR. Nothing here asserts the
%   shape of an image_observation, a sampled_body or an opaque_body, so a rebuild
%   of either fold is free to change everything except the anchor contract.
%
%   ---------------------------------------------------------------------
%   DEFECT FOUND WHILE BUILDING THE BOUNDED ARM -- NOT FIXED HERE
%   ---------------------------------------------------------------------
%   THE ENCOUNTER WINDOW'S START AND END ARE SILENTLY DISCARDED BY THE FOLD.
%   Three facts, each read from the code rather than inferred:
%
%     1. The emitter's duration cell has NO `seconds` field.
%          ontology_table_row.m:559-561
%            function d = durationSeconds(x)
%            d = struct('source_unit', 's', 'source_value', double(x), ...
%                'approximate', false);
%
%     2. The fold reads ONLY `seconds`, and treats a cell without one as ABSENT.
%          resolveSessionAnchors.m:466-475 (cellField)
%            if ~isfield(x, 'seconds') || ~isnumeric(x.seconds) || ...
%                    ~isscalar(x.seconds) || ~isfinite(x.seconds)
%                return;     % c stays []
%
%     3. Nothing between them backfills it. `ensureClassBlocks`
%        (v1_to_v2.m:453-520) manufactures empty top-level BLOCKS only, never
%        nested fields, and no code path in +did2 writes `blank_value` or
%        `default_value` into a body (the only three references to either key in
%        src/ are +did2/+schema/cache.m:1588/1617/1674, all READS, in the
%        vacuous-composite check).
%
%   So `value.start` is never set and `value.duration` is never computed: the
%   folded `relative_reference` carries `relation` and nothing else, and the
%   `refused_negative_extent` branch is unreachable because the extent is never
%   read. NO COUNTER SEES THIS. The document is counted `anchors_folded`, no
%   refusal counter moves, and it does not quarantine.
%
%   DENOMINATOR: every `session_bounded_reference` in the corpus comes from this
%   one emitter, and resolveSessionAnchors.m:19-22 records the measured
%   cross-corpus rollup (run 31441923369, `caf710b`, 6 corpora, 627,526 docs):
%
%       106,639  anchors seen  =  86,228 session_relative_reference
%                               + 20,411 session_bounded_reference
%       106,639  FOLDED to relative_reference
%             0  REFUSED (total), across all six refusal reasons
%
%   -- so 20,411 documents were folded with their onset/offset window dropped,
%   and the run reported it as a clean fold. (ontology_table_row.m:194 gives the
%   same 20,411 as the JH encounter table's row count, from the other side.)
%
%   WHICH SIDE IS WRONG IS NOT DECIDED HERE. What is not in doubt is that the two
%   sides disagree and that every OTHER duration cell in the converter writes
%   `seconds` -- jClockAlignmentBodies.m:242, jEpochClockReferences.m:287,
%   resolveValidIntervals.m:957 -- while ontology_table_row.m:559 alone does not.
%   `seconds` is documented in the schema as *"Canonical duration value -- the
%   normalised, cross-document comparable number"*, and the fold writes its own
%   output through it (`value.duration = struct('seconds', span, ...)`,
%   resolveSessionAnchors.m:304). The two tests below assert the CONTRACT the
%   fold's own header states --
%
%       session_bounded_reference  { relation, start, end }
%          -> relative_reference   { relation, start, duration = end-start }
%                                            resolveSessionAnchors.m:144-145
%
%   -- so they FAIL until one side is changed. They are deliberately not written
%   to the current behaviour: a test that pinned the drop would make this file
%   the thing certifying the loss.
%
%   HOW testTimeReferenceCollapse MISSED IT, which is this file's whole thesis in
%   one case. Its bounded fixture is a HAND COPY of makeEncounterWindow, and the
%   copy added a field the emitter never wrote:
%
%       testTimeReferenceCollapse.m:164-167
%         function c = durationCell(seconds)
%         c = struct('seconds', double(seconds), 'source_unit', 's', ...
%             'source_value', double(seconds), 'approximate', false);
%
%   The fold passes against that fixture and drops the data in production. A copy
%   cannot drift when the emitter does -- and here it did not even have to drift,
%   because it was never identical to begin with.
%
%   Run with:  results = runtests('did2.unittest.testSessionAnchorEmitterContract');

tests = functiontests(localfunctions);
end

% ===================== the emitter roster ==============================

function roster = emitterRoster()
%EMITTERROSTER The pass-1 emitters of `session_relative_reference` this file
%   drives, and the mint site each one exercises. `path` is the code path:
%   'shared' = private/jSessionAnchor.m, 'local' = a hand-rolled duplicate inside
%   the migrator itself.
%
%   NINE entries for the nine relative mint sites in the header's denominator.
%   ontology_table_row.m:867 appears TWICE, once per caller of its local
%   `makeSessionAnchor`, because the two callers are the whole realizable value
%   set of that site's VARIABLE `relation` -- see relationValueSet() below.
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
           'path', 'local',  'build', @neuronExtracellularBody), ...
    struct('name', 'image_stack',          'site', 'image_stack.m:279', ...
           'path', 'local',  'build', @imageStackBody), ...
    struct('name', 'pyraview',             'site', 'pyraview.m:105', ...
           'path', 'local',  'build', @pyraviewBody), ...
    struct('name', 'otr_percolumn',        'site', 'ontology_table_row.m:867 (caller :119)', ...
           'path', 'local',  'build', @tableRowWithSubjectBody), ...
    struct('name', 'otr_patchgeometry',    'site', 'ontology_table_row.m:867 (caller :409)', ...
           'path', 'local',  'build', @patchGeometryRowBody)};
end

function roster = boundedEmitterRoster()
%BOUNDEDEMITTERROSTER The pass-1 emitters of `session_bounded_reference`.
%
%   ONE ENTRY, AND THAT IS THE WHOLE POPULATION, not a sample of it. The header's
%   grep over +migrators_j finds exactly one `document_class` assignment of this
%   class (ontology_table_row.m:275, inside makeEncounterWindow), and the sweep
%   over `src/` finds the string nowhere else but resolveSessionAnchors.m, which
%   consumes it. So driving this one emitter drives the bounded arm entirely --
%   and the 20,411 bounded anchors the corpus rollup counted all came through
%   here.
roster = { ...
    struct('name', 'ontology_table_row_encounter', 'site', 'ontology_table_row.m:275', ...
           'path', 'local', 'build', @encounterRowBody)};
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

function v1 = imageStackBody(sessionId)
% Exercises image_stack.m:279 (local classBlock anchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:959-991 (babuImageStack) --
% the +setup/+conv/+babu/import.m:474 population, which sets `subject_id` and no
% `document_id`, so it reaches the fold arm rather than the passthrough guard.
%
% ONLY THE ANCHOR IS ASSERTED ANYWHERE IN THIS FILE. image_stack's observation /
% body shape is another session's to change; the anchor contract is not.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subjgrp_babu_3'});
v1.base = struct('id', 'is_babu_01', 'session_id', sessionId, ...
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C190180', ...
    'label', 'A video recording of a behaving animal');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXT', 'dimension_size', [480 640 900], ...
    'dimension_scale', [1 1 30], ...
    'dimension_scale_units', 'pixel,pixel,second', ...
    'clocktype', 'exp_global_time', 'timestamp', 739000);
v1.files = struct('file_list', {{'imageStack'}});
end

function v1 = pyraviewBody(sessionId)
% Exercises pyraview.m:105 (local classBlock anchor).
% Shape from tests/+did2/+unittest/testMigratorsJ.m:2442-2454.
%
% Same restraint as image_stack: the sampled_body-per-level fold is another
% session's, and nothing here asserts it.
v1 = struct();
v1.document_class = struct('class_name', 'pyraview', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'filter',  'class_version', '1.0.0'), ...
                      struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'sub_7'});
v1.base = struct('id', 'pv_1', 'session_id', sessionId, ...
    'name', 'pyr', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.pyraview = struct('label', 'lfp', 'native_rate', 1000, ...
    'native_start_time', 0, 'channels', 4, 'data_type', 'int16', ...
    'decimation_sampling_rates', [1000 500]);
v1.files = struct('file_list', {{'level1.bin', 'level2.bin'}});
end

% ---- the two callers of ontology_table_row's VARIABLE-relation anchor -------
%
%   ontology_table_row.m:875 is the ONE emitter in +migrators_j that writes a
%   `relation` it was HANDED instead of a literal:
%
%       $ sed -n '857,876p' .../+migrators_j/ontology_table_row.m
%       function anchor = makeSessionAnchor(preBody, relation)
%       ...
%       anchor.session_relative_reference = struct('relation', relation);
%
%   A parameter is a value set, not a value, so the two fixtures below reach its
%   two callers -- the per-column fallback (:119) and the patch-geometry map
%   (:409) -- and the tests read the relation off what the migrator ACTUALLY
%   emitted rather than off the call site.

function v1 = tableRowWithSubjectBody(sessionId)
%TABLEROWWITHSUBJECTBODY Reaches ontology_table_row.m:119, the per-column path.
%
%   THE SUBJECT EDGE IS THE WHOLE POINT OF THIS FIXTURE AND IT IS NOT WHAT A REAL
%   ontologyTableRow LOOKS LIKE. `resolvedSubject` (ontology_table_row.m:814)
%   scans the source document for a `subject_id` dependency, and the real NDI
%   template declares only `document_id` (tableDocMaker.m:231), so a production
%   row takes the guarded passthrough at :106 and mints NO anchor. That guard is
%   deliberate and is not under test here. This fixture supplies the subject so
%   the :119 caller is reachable at all -- without it, one of the two callers of
%   the variable-relation site would be undrivable and the value set below would
%   be a claim about half the code.
%
%   The single column is a body weight so `migrateRow` classifies it as a timed
%   numeric observation (dispatchNumeric's mass arm, :675-677) and `usedAnchor`
%   becomes true -- an assertion-only column would emit no anchor at all.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'worm_x'});
v1.base = struct('id', 'otr_percol', 'session_id', sessionId, ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_table_row = struct( ...
    'variable_names', 'BodyWeight', ...
    'names',          'body weight', ...
    'ontology_nodes', 'EMPTY:0', ...
    'data',           struct('BodyWeight', 3.25));
end

function v1 = patchGeometryRowBody(sessionId)
%PATCHGEOMETRYROWBODY Reaches ontology_table_row.m:409, the patch-geometry map.
%   Column set from tests/+did2/+unittest/testMigratorsJ.m:1334-1350, which is
%   the JH bacterial-patch geometry table (doImport.m:291-293). It satisfies
%   isPatchGeometryTable's four clauses: OD600-at-seeding present, patch
%   identifier present, patch DOCUMENT identifier absent, and geometry evidence
%   (radius / circularity / centre) present.
keys = {'BacterialPlateIdentifier', 'BacterialPatchIdentifier', ...
    'BacterialOD600TargetAtSeeding', 'BacterialPatchVolume', ...
    'BacterialPatchCenter_XCoordinate', 'BacterialPatchCenter_YCoordinate', ...
    'BacterialPatchRadius', 'BacterialPatchCircularity'};
data = struct();
data.BacterialPlateIdentifier = '0061';
data.BacterialPatchIdentifier = '0017';
data.BacterialOD600TargetAtSeeding = 0.05;
data.BacterialPatchVolume = 0.5;
data.BacterialPatchCenter_XCoordinate = 806.3578700078308;
data.BacterialPatchCenter_YCoordinate = 684.8410336726703;
data.BacterialPatchRadius = 28.512513907289925;
data.BacterialPatchCircularity = 0.9847680561323107;
v1 = struct();
v1.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'otr_patch', 'session_id', sessionId, ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_table_row = struct( ...
    'variable_names', strjoin(keys, ','), ...
    'names',          strjoin(keys, ','), ...
    'ontology_nodes', strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ','), ...
    'data',           data);
end

% ---- the bounded emitter ---------------------------------------------------

function v1 = encounterRowBody(sessionId)
%ENCOUNTERROWBODY The ONLY emitter of `session_bounded_reference` in the
%   repository, driven for real: the JH C. elegans encounter table
%   (ontology_table_row.m:202-244, isEncounterTable / applyEncounterMap).
%
%   Onset 1249.72 s and offset 1265.39 s are the values testMigratorsJ.m:1270-1271
%   already uses, which came off the Haley import. The window is 15.67 s wide, so
%   `end - start` is a number a test can name.
v1 = encounterRowBodyWindow(sessionId, 1249.72, 1265.39);
end

function v1 = encounterRowBodyWindow(sessionId, onset, offset)
%ENCOUNTERROWBODYWINDOW encounterRowBody with the window under the caller's
%   control, so a REVERSED window (offset < onset) can be produced by the REAL
%   migrator rather than by hand. Nothing in applyEncounterMap orders the two --
%   `colNum` reads each column independently (ontology_table_row.m:603-610) and
%   `makeEncounterWindow` writes them straight through (:281-282) -- so a
%   reversed row is emitter-reachable, not a fabricated shape.
P = 'CElegansBehavioralAssay_';
keys = {'SubjectDocumentIdentifier', [P 'EncounterIdentifier'], ...
    'BacterialPatchDocumentIdentifier', [P 'EncounterOnsetTime'], ...
    [P 'EncounterOffsetTime'], [P 'DecelerationUponEncounter'], ...
    [P 'MinimumVelocityDuringEncounter'], [P 'PeakVelocityBeforeEncounterOnset'], ...
    [P 'MinimumVelocityAfterEncounterOffset'], [P 'PosteriorProbabilityOfExploitation'], ...
    [P 'PosteriorProbabilityOfSensing'], [P 'RelativeDensityOfEncounteredBacteria'], ...
    [P 'RelativeDensityOfCultivationBacteria']};
data = struct();
data.SubjectDocumentIdentifier = 'worm_1';
data.([P 'EncounterIdentifier']) = 5;
data.BacterialPatchDocumentIdentifier = 'patch_1';
data.([P 'EncounterOnsetTime'])  = onset;
data.([P 'EncounterOffsetTime']) = offset;
data.([P 'DecelerationUponEncounter']) = 3.15;
data.([P 'MinimumVelocityDuringEncounter']) = 130.4;
data.([P 'PeakVelocityBeforeEncounterOnset']) = 196.3;
data.([P 'MinimumVelocityAfterEncounterOffset']) = 130.4;
data.([P 'PosteriorProbabilityOfExploitation']) = 1.99e-5;
data.([P 'PosteriorProbabilityOfSensing']) = 7.5e-4;
data.([P 'RelativeDensityOfEncounteredBacteria']) = 0.557;
data.([P 'RelativeDensityOfCultivationBacteria']) = 2.238;
v1 = struct();
v1.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'otr_enc', 'session_id', sessionId, ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_table_row = struct( ...
    'variable_names', strjoin(keys, ','), ...
    'names',          strjoin(keys, ','), ...
    'ontology_nodes', strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ','), ...
    'data',           data);
end

% ===================== the roster is an instrument =====================

function testTheRosterStatesItsDenominatorBeforeAnythingIsDriven(testCase)
% Operating Rule 5. A per-emitter loop that silently iterated over an empty or
% half-built roster would report six green assertions about nothing -- which is
% exactly how silentLoss printed "0 empty edges" for two days. The count is
% checked before any migrator runs, and the fixed roster of 6 is the number the
% header's denominator paragraph claims.
roster = emitterRoster();
verifyEqual(testCase, numel(roster), 10, ...
    'the roster changed size -- update the DENOMINATOR block in the header');
shared = 0;
for k = 1:numel(roster)
    verifyTrue(testCase, isa(roster{k}.build, 'function_handle'));
    verifyNotEmpty(testCase, roster{k}.site);
    if strcmp(roster{k}.path, 'shared'); shared = shared + 1; end
end
% BOTH code paths must stay covered. The shared helper is one site serving 14
% callers; the hand-rolled duplicates are independent chances to drift.
verifyEqual(testCase, shared, 1);
verifyEqual(testCase, numel(roster) - shared, 9);

% THE BOUNDED ROSTER IS SEPARATE AND ITS SIZE IS A CLAIM, NOT A CONVENIENCE. It
% is 1 because the repository mints `session_bounded_reference` at exactly one
% site (header grep). If a second mint site ever appears and is not added here,
% the bounded arm goes back to being partly undriven -- silently, since every
% assertion below would still pass on the one emitter it knows about.
bounded = boundedEmitterRoster();
verifyEqual(testCase, numel(bounded), 1, ...
    ['the bounded roster changed size -- re-run the header grep over ' ...
     '+migrators_j and correct the DENOMINATOR block']);
verifyTrue(testCase, isa(bounded{1}.build, 'function_handle'));
verifyEqual(testCase, bounded{1}.site, 'ontology_table_row.m:275');

% and the two rosters together are the header's ten sites
verifyEqual(testCase, numel(roster) + numel(bounded), 11, ...
    ['9 relative sites + 1 bounded site = 10 mint sites; the relative roster ' ...
     'carries ontology_table_row.m:867 twice (one entry per caller of its ' ...
     'variable-relation helper), so the roster count is 10 + 1']);
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
bounded = boundedEmitterRoster();
batch = {sessionBody('sess_doc_1', 'SID_1', 'exp1')};
for k = 1:numel(roster)
    make = roster{k}.build;
    batch{end+1} = make('SID_1'); %#ok<AGROW>
end
for k = 1:numel(bounded)
    make = bounded{k}.build;
    batch{end+1} = make('SID_1'); %#ok<AGROW>
end

[out, rep] = foldBatch(batch);

verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.session_documents_seen, 1);
verifyEqual(testCase, rep.anchors_seen, numel(roster) + numel(bounded), ...
    'one anchor per driven emitter was expected');
verifyEqual(testCase, rep.anchors_relative, numel(roster));
% THE HEADER GAP IS CLOSED. This used to read `anchors_bounded == 0` with the
% comment "no driven emitter mints session_bounded_reference". It does now.
verifyEqual(testCase, rep.anchors_bounded, numel(bounded), ...
    'the bounded arm is driven by ontology_table_row.m:275');
verifyEqual(testCase, rep.anchors_folded, numel(roster) + numel(bounded));
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

% and BOTH retired classes are gone from the batch entirely
verifyFalse(testCase, any(strcmp(classNames(out), 'session_relative_reference')), ...
    'a retired class survived pass 2 -- the deletion gate cannot open');
verifyFalse(testCase, any(strcmp(classNames(out), 'session_bounded_reference')), ...
    'a retired class survived pass 2 -- the deletion gate cannot open');
verifyEqual(testCase, numel(ofClass(out, 'relative_reference')), ...
    numel(roster) + numel(bounded));
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

% ===================== the VARIABLE relation ===========================
%
%   Every other emitter hardcodes 'during'. `ontology_table_row.m:875` writes
%   whatever its caller handed `makeSessionAnchor`, which makes it the one place
%   a value the fold REFUSES could enter without anybody noticing -- the fold
%   would count `refused_unknown_relation`, leave the document in the retired
%   class, and go green.
%
%   THE REALIZABLE VALUE SET IS {'during'}, AND THAT IS READ, NOT ASSUMED. The
%   helper is a LOCAL function, so its callers cannot be anywhere but this file:
%
%       $ grep -n "makeSessionAnchor" \
%             src/did/+did2/+convert/+migrators_j/ontology_table_row.m
%       119:anchor = makeSessionAnchor(preBody, 'during');
%       409:anchor = makeSessionAnchor(preBody, 'during');
%       857:function anchor = makeSessionAnchor(preBody, relation)
%
%   Two callers, both a literal. The tests below do not read those call sites --
%   they DRIVE both callers and read the relation off what the migrator emitted,
%   so the day a third caller appears with a different literal, the value-set
%   test fails and names it.
%
%   WHAT THE FOLD DOES WITH EACH MEMBER OF THAT SET: 'during' maps to
%   `time:intervalDuring` with verdict 'ok' (resolveSessionAnchors.m:414), so it
%   folds. NOTHING THIS SITE CAN PRODUCE TODAY IS REFUSED. The paste that
%   prompted this work expected a refusal here; there is none, and the honest
%   report is the empty one. The two values that WOULD be refused --
%   'concurrent_with' (ambiguous) and anything outside v1's six-member enum
%   (unknown) -- are unreachable from either caller.

function rels = relationValueSet(testCase, sitePrefix)
%RELATIONVALUESET The distinct `relation` values the driven emitters of one site
%   actually produce, collected from their OUTPUT.
rels = {};
roster = emitterRoster();
for k = 1:numel(roster)
    e = roster{k};
    if ~contains(e.site, sitePrefix); continue; end
    make = e.build;
    out = passOne({make('SID_1')});
    anchors = ofClass(out, 'session_relative_reference');
    verifyEqual(testCase, numel(anchors), 1, sprintf( ...
        '%s (%s) minted %d anchors, so its relation cannot be read', ...
        e.name, e.site, numel(anchors)));
    rels{end+1} = char(anchors{1}.get('session_relative_reference.relation')); %#ok<AGROW>
end
rels = unique(rels);
end

function testTheVariableRelationSiteCanOnlyProduceDuring(testCase)
% DENOMINATOR FIRST: two callers reach ontology_table_row.m:867, and both are
% driven here (the per-column fallback at :119 and the patch-geometry map at
% :409). If either stopped minting an anchor, relationValueSet raises rather than
% returning a shorter list, so a shrunken denominator cannot pass as a narrow
% value set.
rels = relationValueSet(testCase, 'ontology_table_row.m:867');
verifyEqual(testCase, numel(rels), 1, ...
    ['the variable-relation site produced a value set of a size other than 1. ' ...
     'MORE than one is not automatically wrong -- check each new value against ' ...
     'resolveSessionAnchors.m:389 owlTimeTerm before widening this test. ZERO ' ...
     'means the roster no longer reaches this site at all, which is a hole, ' ...
     'not a pass.']);
% assert, not verify: an empty set makes every line below meaningless, and a
% vacuous green is the one outcome this file exists to prevent.
assertNotEmpty(testCase, rels);
verifyEqual(testCase, rels{1}, 'during', ...
    ['ontology_table_row.m:875 emitted a relation other than "during". If it ' ...
     'is one of before/after/at_start_of/at_end_of the fold maps it and this ' ...
     'test should widen; if it is concurrent_with or anything outside v1''s ' ...
     'six-member enum the fold REFUSES it and those documents stay in the ' ...
     'retired class -- that is a defect to report, not a test to relax.']);
end

function testEveryRelationEveryDrivenEmitterProducesIsMappedNotRefused(testCase)
% The same question asked across ALL driven emitters at once, relative and
% bounded, so the answer has a denominator: 11 emitters, and the set of distinct
% relations they produce between them.
mappable = {'before', 'after', 'at_start_of', 'at_end_of', 'during'};
refused  = {'concurrent_with'};   % ambiguous; resolveSessionAnchors.m:415-417

seen = {};
roster = emitterRoster();
for k = 1:numel(roster)
    make = roster{k}.build;
    out = passOne({make('SID_1')});
    a = ofClass(out, 'session_relative_reference');
    assertNotEmpty(testCase, a, sprintf('%s minted no anchor', roster{k}.name));
    seen{end+1} = char(a{1}.get('session_relative_reference.relation')); %#ok<AGROW>
end
bounded = boundedEmitterRoster();
for k = 1:numel(bounded)
    make = bounded{k}.build;
    out = passOne({make('SID_1')});
    a = ofClass(out, 'session_bounded_reference');
    assertNotEmpty(testCase, a, sprintf('%s minted no window', bounded{k}.name));
    seen{end+1} = char(a{1}.get('session_bounded_reference.relation')); %#ok<AGROW>
end

verifyEqual(testCase, numel(seen), numel(roster) + numel(bounded), ...
    'one relation per driven emitter was expected');
distinct = unique(seen);
for k = 1:numel(distinct)
    verifyFalse(testCase, any(strcmp(refused, distinct{k})), sprintf( ...
        'an emitter writes relation "%s", which the fold REFUSES as ambiguous', ...
        distinct{k}));
    verifyTrue(testCase, any(strcmp(mappable, distinct{k})), sprintf( ...
        'an emitter writes relation "%s", which is outside v1''s enum -- the fold counts refused_unknown_relation', ...
        distinct{k}));
end
% and today the whole set is one value, which is what the signed plan's
% "`relation` is 'during' at all 14 emitter call sites" records
verifyEqual(testCase, distinct, {'during'});
end

% ===================== the bounded arm =================================
%
%   Everything above this line drives `session_relative_reference`. Everything
%   below drives `session_bounded_reference`, from its ONE emitter, in the same
%   shape: ids collected from the emitter's own output, every refusal counter
%   checked separately, and each refusal path driven from the real migrator
%   rather than from a hand-built body.

function [out, rep, windowIds] = foldEncounter(sessionDocs, sessionId, onset, offset)
%FOLDENCOUNTER Drive the real encounter map, then the real fold.
%   Returns the ids of the bounded windows the EMITTER minted -- they are freshly
%   minted uids (freshBase -> did.ido.unique_id(), ontology_table_row.m:555), so
%   nothing outside pass 1 can know them, which is the whole reason they are
%   collected from the output instead of being written into a fixture.
batch = sessionDocs;
batch{end+1} = encounterRowBodyWindow(sessionId, onset, offset);
before = passOne(batch);
windowIds = {};
for k = 1:numel(before.migrated)
    if strcmp(char(before.migrated{k}.get('document_class.class_name')), ...
            'session_bounded_reference')
        windowIds{end+1} = char(before.migrated{k}.get('base.id')); %#ok<AGROW>
    end
end
[out, rep] = did2.convert.resolveSessionAnchors(before, ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

function testTheBoundedEmitterActuallyMintsAWindow(testCase)
% The precondition for the whole section, and it is not decoration: if the
% encounter map stopped dispatching -- a tightened isEncounterTable, a renamed
% column -- every bounded assertion below would pass vacuously on 0 documents.
% That is the silentLoss failure exactly, and Operating Rule 5 is the answer.
roster = boundedEmitterRoster();
for k = 1:numel(roster)
    e = roster{k};
    make = e.build;
    out = passOne({make('SID_1')});
    windows = ofClass(out, 'session_bounded_reference');
    verifyEqual(testCase, numel(windows), 1, sprintf( ...
        ['%s (%s) minted %d bounded windows, expected exactly 1. If the ' ...
         'encounter map legitimately stopped anchoring, correct the header ' ...
         'denominator -- do not weaken this count.'], ...
        e.name, e.site, numel(windows)));
    % and the encounter's OTHER bodies point at it, which is what makes the
    % window load-bearing rather than decorative: 8 measures + 1 relation.
    verifyEqual(testCase, numel(ofClass(out, 'directed_relation')), 1);
end
end

function testTheBoundedWindowCarriesTheSessionIdTheFoldJoinsOn(testCase)
% `base.session_id` is the ONLY handle the fold has (resolveSessionAnchors.m:255),
% and `freshBase` (ontology_table_row.m:547-557) defaults it to '' when the
% source body has none -- so an empty one is a real path, not a hypothetical.
roster = boundedEmitterRoster();
for k = 1:numel(roster)
    e = roster{k};
    make = e.build;
    out = passOne({make('SID_1')});
    w = ofClass(out, 'session_bounded_reference');
    verifyEqual(testCase, char(w{1}.get('base.session_id')), 'SID_1', sprintf( ...
        '%s (%s) lost base.session_id -- the fold cannot join it', e.name, e.site));
end
end

function testTheBoundedWindowFoldsWithNoRefusals(testCase)
% THE BOUNDED COUNTERPART OF THE MAIN TEST. A refusal here is not a caught error:
% it is a `session_bounded_reference` that SURVIVES the migration and holds the
% deletion gate shut ("refused_total == 0 AND zero surviving
% session_*_reference in by_class", resolveSessionAnchors.m:132-135).
[out, rep, windowIds] = foldEncounter( ...
    {sessionBody('sess_doc_1', 'SID_1', 'exp1')}, 'SID_1', 1249.72, 1265.39);

verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.session_documents_seen, 1);
verifyEqual(testCase, numel(windowIds), 1, ...
    'the emitter minted no window -- every assertion below would be vacuous');
verifyEqual(testCase, rep.anchors_seen, 1);
verifyEqual(testCase, rep.anchors_bounded, 1);
verifyEqual(testCase, rep.anchors_relative, 0, ...
    'the encounter map mints a bounded window only -- no relative anchor');
verifyEqual(testCase, rep.anchors_folded, 1);
verifyEqual(testCase, rep.fold_quarantined, 0);

% Every refusal counter separately, so a failure names its own cause.
verifyEqual(testCase, rep.refused_no_session_id, 0);
verifyEqual(testCase, rep.refused_no_session_document, 0);
verifyEqual(testCase, rep.refused_ambiguous_session, 0);
verifyEqual(testCase, rep.refused_ambiguous_relation, 0);
verifyEqual(testCase, rep.refused_unknown_relation, 0);
verifyEqual(testCase, rep.refused_negative_extent, 0);
verifyEqual(testCase, rep.refused_total, 0);

% THE ID IS PRESERVED -- collected from the emitter's own output, then required
% to still name a document. Eight observations and one directed_relation point
% at this id through `time_reference_1`; a minted replacement dangles all nine.
afterIds = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(afterIds, windowIds{1})), sprintf( ...
    'window id %s vanished in the fold -- every time_reference_# edge to it dangles', ...
    windowIds{1}));

% and the retired class is gone, replaced 1:1
verifyFalse(testCase, any(strcmp(classNames(out), 'session_bounded_reference')), ...
    'the retired bounded class survived pass 2 -- the deletion gate cannot open');
refs = ofClass(out, 'relative_reference');
assertEqual(testCase, numel(refs), 1);
verifyEqual(testCase, char(refs{1}.get('base.id')), windowIds{1});
verifyEqual(testCase, depValue(refs{1}.toStruct(), 'relative_to'), 'sess_doc_1');
verifyNotEqual(testCase, depValue(refs{1}.toStruct(), 'relative_to'), 'SID_1');
end

function testEveryEncounterEdgeStillResolvesAfterTheBoundedFold(testCase)
% The orphan question for the bounded arm, asked end to end. applyEncounterMap
% wires `time_reference_1` onto EIGHT observations and ONE directed_relation
% (ontology_table_row.m:237-243), all naming the window's own base.id. After the
% fold every one of those edges must still name a document in the batch.
[out, ~, windowIds] = foldEncounter( ...
    {sessionBody('sess_doc_1', 'SID_1', 'exp1')}, 'SID_1', 1249.72, 1265.39);
verifyEqual(testCase, numel(windowIds), 1);

ids = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
pointers = 0;
for k = 1:numel(out.migrated)
    target = depValue(out.migrated{k}.toStruct(), 'time_reference_1');
    if isempty(target); continue; end
    pointers = pointers + 1;
    verifyTrue(testCase, any(strcmp(ids, target)), sprintf( ...
        'time_reference_1 on %s no longer resolves -- the fold orphaned it', ...
        char(out.migrated{k}.get('document_class.class_name'))));
    verifyEqual(testCase, target, windowIds{1});
end
% DENOMINATOR, so "every edge resolved" cannot mean "there were no edges".
verifyEqual(testCase, pointers, 9, ...
    ['expected 8 encounter measurements + 1 directed_relation pointing at the ' ...
     'window (ontology_table_row.m:220-243)']);
end

function testTheBoundedWindowExtentSurvivesTheFold(testCase)
% EXPECTED RED ON THE FIRST CI RUN. This is the DEFECT block in the header, and
% it is the finding this extension exists to surface.
%
% The fold's own header states the mapping (resolveSessionAnchors.m:144-145):
%
%     session_bounded_reference  { relation, start, end }
%        -> relative_reference   { relation, start, duration = end-start }
%
% What actually happens is that `start` and `duration` are both absent, because
% the emitter's duration cell carries no `seconds` (ontology_table_row.m:559-561)
% and `cellField` treats a cell without one as ABSENT (resolveSessionAnchors.m:
% 466-475). Nothing counts it: `anchors_folded` goes up, no refusal counter
% moves, nothing quarantines. 20,411 documents in the last cross-corpus rollup
% (resolveSessionAnchors.m:19-22) were folded this way and reported clean.
%
% THIS TEST IS DELIBERATELY WRITTEN TO THE CONTRACT AND NOT TO THE BEHAVIOUR.
% Pinning the current output would make this file the thing certifying the loss,
% which is the failure mode the whole repository keeps paying for. The fix --
% whether the emitter starts writing `seconds` or the fold starts reading
% `source_value` -- is a SEPARATE commit, so the coverage and the repair stay
% separable and either can be reverted alone.
onset = 1249.72; offset = 1265.39;
[out, rep] = foldEncounter( ...
    {sessionBody('sess_doc_1', 'SID_1', 'exp1')}, 'SID_1', onset, offset);
verifyEqual(testCase, rep.anchors_folded, 1);

refs = ofClass(out, 'relative_reference');
assertEqual(testCase, numel(refs), 1);
value = refs{1}.get('relative_reference.value');

% The checks are nested so that a missing field FAILS with its own message
% instead of ERRORING on the read below it -- an error hides the assertion's
% text, and the text is the whole finding.
hasStart = isfield(value, 'start');
verifyTrue(testCase, hasStart, ...
    ['the encounter window START was dropped by the fold. The emitter wrote ' ...
     'it (ontology_table_row.m:282) and the fold could not read it: ' ...
     'durationSeconds omits `seconds`, cellField requires it.']);
if hasStart && isfield(value.start, 'seconds')
    verifyEqual(testCase, value.start.seconds, onset, 'AbsTol', 1e-9);
elseif hasStart
    verifyFail(testCase, 'relative_reference.value.start carries no `seconds`');
end

hasDuration = isfield(value, 'duration');
verifyTrue(testCase, hasDuration, ...
    ['the encounter window EXTENT was dropped by the fold -- same cause as ' ...
     'the start above. A 15.67 s encounter became a reference with no width.']);
if hasDuration && isfield(value.duration, 'seconds')
    verifyEqual(testCase, value.duration.seconds, offset - onset, 'AbsTol', 1e-9);
elseif hasDuration
    verifyFail(testCase, 'relative_reference.value.duration carries no `seconds`');
end
end

function testAReversedBoundedWindowIsRefusedNotSilentlyFolded(testCase)
% EXPECTED RED ON THE FIRST CI RUN, SAME ROOT CAUSE AS THE TEST ABOVE, and worth
% asserting separately because it is a different guarantee: not "the extent is
% carried" but "a nonsense extent is REFUSED rather than folded".
%
% `refused_negative_extent` is one of the six refusal reasons the deletion gate
% counts (resolveSessionAnchors.m:125), and it is UNREACHABLE from the only
% emitter that can produce a negative extent -- the guard at :294 is behind
% `~isempty(startCell) && ~isempty(endCell)`, and both are empty for every real
% bounded document. So the counter reads 0 not because no such document exists
% but because the branch is never entered. A refusal counter that cannot fire is
% indistinguishable from a clean corpus, which is precisely the shape of every
% instrument failure recorded in this project.
%
% The reversed window is produced by the REAL migrator: nothing in
% applyEncounterMap orders onset against offset.
[out, rep] = foldEncounter( ...
    {sessionBody('sess_doc_1', 'SID_1', 'exp1')}, 'SID_1', 1265.39, 1249.72);

verifyEqual(testCase, rep.anchors_bounded, 1);
verifyEqual(testCase, rep.refused_negative_extent, 1, ...
    ['a window ending before it starts was FOLDED, not refused: the fold never ' ...
     'read the extent, so the negative-extent guard could not fire. See the ' ...
     'DEFECT block in this file''s header.']);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, rep.refused_total, 1);

% and the refused document is left EXACTLY as it is -- never dropped, never
% given an empty required edge
windows = ofClass(out, 'session_bounded_reference');
verifyEqual(testCase, numel(windows), 1, ...
    'the refused window must survive untouched, not be dropped');
if ~isempty(windows)
    verifyEmpty(testCase, depValue(windows{1}.toStruct(), 'relative_to'));
end
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
end

% ---- the bounded refusal paths, each driven from the real emitter ----------

function testABoundedWindowWithNoSessionDocumentIsLeftIntactNotHollowed(testCase)
% Discovery mode hands the fold a subset batch that need not contain the session
% document -- jSessionAnchor's own note about discovery-mode orphans, which this
% project has recorded as CORRECT. The window must be left exactly as it is and
% counted, never given an empty required edge: `references.m:90` skips empty
% edges, so a hollowed one would validate clean and no gate would see it.
[out, rep, windowIds] = foldEncounter({}, 'SID_1', 1249.72, 1265.39);   % no session doc

verifyEqual(testCase, numel(windowIds), 1);
verifyEqual(testCase, rep.session_documents_seen, 0);
verifyEqual(testCase, rep.anchors_seen, 1);
verifyEqual(testCase, rep.anchors_bounded, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, rep.refused_no_session_document, 1);
verifyEqual(testCase, rep.refused_no_session_id, 0);
verifyEqual(testCase, rep.refused_total, 1);

windows = ofClass(out, 'session_bounded_reference');
assertEqual(testCase, numel(windows), 1, ...
    'the refused window must survive untouched, not be dropped');
verifyEqual(testCase, char(windows{1}.get('base.id')), windowIds{1});
verifyEmpty(testCase, depValue(windows{1}.toStruct(), 'relative_to'));
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
end

function testABoundedWindowWithNoSessionIdIsRefusedNotGuessed(testCase)
% `refused_no_session_id`, driven from the real emitter rather than asserted from
% a hand-built body with the field deleted. `freshBase` (ontology_table_row.m:
% 547-557) defaults `session_id` to '' when the SOURCE body carries none, so a
% source document with an empty session_id produces a window the fold cannot
% join. It must refuse, not guess -- there is exactly one session document in
% this batch and picking it because it is the only one is inventing a fact.
[out, rep] = foldEncounter( ...
    {sessionBody('sess_doc_1', 'SID_1', 'exp1')}, '', 1249.72, 1265.39);

verifyEqual(testCase, rep.session_documents_seen, 1);
verifyEqual(testCase, rep.anchors_seen, 1);
verifyEqual(testCase, rep.anchors_bounded, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, rep.refused_no_session_id, 1);
verifyEqual(testCase, rep.refused_no_session_document, 0);
verifyEqual(testCase, rep.refused_total, 1);

verifyEqual(testCase, numel(ofClass(out, 'session_bounded_reference')), 1);
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
end

function testTwoSessionDocumentsClaimingOneSessionIdRefuseTheBoundedWindow(testCase)
% `refused_ambiguous_session`, driven from the real emitter. Two `session`
% documents claiming one `base.session_id` is a corpus the fold cannot resolve
% honestly: `relative_to` would name one of two candidates and nothing on the
% anchor says which. The DOCUMENT IDS DIFFER and the SESSION IDS MATCH, which is
% the only arrangement that reaches this counter.
[out, rep] = foldEncounter({ ...
    sessionBody('sess_doc_1', 'SID_1', 'exp1'), ...
    sessionBody('sess_doc_2', 'SID_1', 'exp1-again')}, 'SID_1', 1249.72, 1265.39);

verifyEqual(testCase, rep.session_documents_seen, 2);
verifyEqual(testCase, rep.anchors_bounded, 1);
verifyEqual(testCase, rep.anchors_folded, 0);
verifyEqual(testCase, rep.refused_ambiguous_session, 1);
verifyEqual(testCase, rep.refused_no_session_id, 0);
verifyEqual(testCase, rep.refused_no_session_document, 0);
verifyEqual(testCase, rep.refused_total, 1);

verifyEqual(testCase, numel(ofClass(out, 'session_bounded_reference')), 1);
verifyEmpty(testCase, ofClass(out, 'relative_reference'));
end
