function tests = testValidIntervalDecompose
%TESTVALIDINTERVALDECOMPOSE `valid_interval` -> boolean `logical_observation`s.
%
%   STATUS: WRITTEN 2026-08-11, NEVER EXECUTED. There is no MATLAB and no
%   Octave in the container this file was written in (`command -v matlab octave
%   octave-cli` returns nothing), so every assertion below is UNVERIFIED. Read
%   it as a specification of intended behaviour, not as a passing suite. Run
%       results = runtests('did2.unittest.testValidIntervalDecompose');
%   and treat any red as a defect in the code or in these tests, not as a
%   surprise.
%   EXTENDED 2026-08-11 with "the verb (subject_interaction.method)" -- seven
%   tests -- in the same container under the same condition: `command -v matlab
%   octave octave-cli` still returns nothing, so those are unexecuted too. CI is
%   their first run.
%
%   NEW FILE, deliberately: testMigratorsJ.m and testStrandedSourceTombstones.m
%   are owned by other sessions and are not touched. The v1 fixture builders
%   below duplicate that file's shapes ON PURPOSE -- its builders are local
%   functions, not shared helpers, and copying twelve lines is cheaper than
%   coupling two files two sessions are editing at once.
%
%   ---------------------------------------------------------------------
%   THE PASS IS DORMANT BY DECISION. THESE TESTS ARM IT ON PURPOSE.
%   ---------------------------------------------------------------------
%   TEAM DECISION 2026-08-12 (jess@walthamdatascience.com): the target model is
%   ONE statement holding an ARRAY of booleans against a TIME AXIS, and the
%   team chose to WAIT for `axes[]` (DID-schema OPEN_WORK #45 -> #32) rather
%   than ship the 1->N decomposition as an interim step. So
%   `did2.convert.resolveValidIntervals` runs as a CENSUS by default and emits
%   nothing.
%
%   EVERY TEST BELOW EXCEPT THE DORMANCY ONES PASSES `'Decompose', true`
%   THROUGH `runPass`. That is deliberate, and it is the reason the pass was
%   guarded rather than deleted: the anchor resolution, the (session, epoch-id)
%   pair keying, Decision C's split-anchor branch, the verb and the eight
%   refusal reasons are all needed unchanged when the array model is built, and
%   preserved code that nothing exercises rots. Read a green run here as "the
%   preserved logic still works", NOT as "the pass emits in production" -- it
%   does not, and `testTheDefaultIsDormantAndSaysSo` is the gate on that.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST
%   ---------------------------------------------------------------------
%   With the emission path ARMED, did2.convert.resolveValidIntervals decomposes
%   each v1 document's interval ARRAY into one `logical_observation` per
%   interval plus the `relative_reference` it is anchored to. THAT SHAPE IS NOT
%   THE AGREED MODEL (see above); it is preserved work.
%
%   THE DECISION NAMED THREE HAZARDS -- three ways to go green while destroying
%   meaning -- and this file is organised around them, one section each, so a
%   failure names the hazard it re-opened rather than a field:
%
%     HAZARD 1  ABSENCE MUST KEEP MEANING "VALID". ndi.app.markgarbage is
%               OPT-IN: no document means the whole epoch is good data
%               (markgarbage.m:172-176). A corpus with no markgarbage documents
%               is 0-quarantine and 0-orphan both before AND after a change that
%               reclassifies every epoch in it as "unknown", so NOTHING WE GATE
%               ON WOULD CATCH IT. These tests are the gate.
%     HAZARD 2  ORDER IS *NOT* LOAD-BEARING -- AND THIS FILE ASSERTED THAT IT
%               WAS. Two tests here pinned a `sequence` ordinal, on the reading
%               that +app/+stimulus/tuning_response.m:253-256 takes the FIRST
%               entry of the STORED array. It does not: `interval` at :254 is
%               the RETURN VALUE of `identifyvalidintervals`, the stored `vi`
%               loaded at :253 is never read again, and
%               `identifyvalidintervals` (markgarbage.m:178-204) iterates every
%               row accumulating through `vlt.math.interval_add`, a SET UNION,
%               never indexing by position. The schema, the pass and these
%               tests were all written from that one unchecked premise --
%               CLAUDE.md's "a test written from the same premise as the code
%               cannot catch the code". `sequence` is DELETED and the two tests
%               are replaced by one that pins the deletion.
%     HAZARD 3  VALIDITY INHERITS (loadvalidinterval falls back to
%               `underlying_element`, markgarbage.m:146-155). THAT IS AN OPEN
%               TEAM QUESTION. The tests here assert that BOTH answers stay
%               buildable and that this pass picks NEITHER -- never that one is
%               right.
%
%   A FOURTH SECTION was added when `subject_interaction.method` stopped being
%   emitted blank, and it belongs beside the three hazards because it has their
%   shape: a validity `logical_observation` is a CURATORIAL JUDGEMENT, not a measurement,
%   and an empty `method` validates (mustBeNonEmpty:false) while reading as the
%   default observation verb the schema itself names -- `measurement`. Nothing we
%   gate on distinguishes the two. See "the verb" below.
%
%   ---------------------------------------------------------------------
%   WHAT THESE TESTS DELIBERATELY DO NOT ASSERT
%   ---------------------------------------------------------------------
%   That the split-anchor branch is correct MODELLING. Decision C of the signed
%   time model says an interval whose ends are anchored differently becomes TWO
%   reference documents, and CHANGE 5 of the same plan measured that NO INSTANCE
%   EXISTS -- every markvalidinterval call site passes one reference for both
%   ends. So the branch is tested for SHAPE (two references, each an instant)
%   and its counter is a prediction under test, not a modelled case.
%
%   Requires the V_eta schema set on DID_SCHEMA_PATH (the quick gate assembles
%   stable/ + draft/ + deprecated/ into one directory). `logical` and
%   `logical_observation` are in the DRAFT tier, so a stable-only path fails
%   these with did2:schema:missingClass -- which is a path problem, not a bug in
%   the pass.

tests = functiontests(localfunctions);
end

% ===================== v1 fixtures =========================================

function s = timerefStruct(clockType, epochValue)
%TIMEREFSTRUCT ndi_timereference_struct(), timereference.m:106-111 -- SIX
%   fields. `session_ID` is the one no NDI template declares and the writer
%   always writes; it stays in its CAMEL spelling because universalRenames
%   snake_cases only a block's IMMEDIATE field names and this one is nested.
s = struct( ...
    'referent_epochsetname', 'ctx_probe_1', ...
    'referent_classname', 'ndi.probe.timeseries.mfdaq', ...
    'clocktypestring', clockType, ...
    'epoch', epochValue, ...
    'session_ID', 'sess_v1', ...
    'time', 0);
end

function e = intervalEntry(t0, t1, clockType, epochValue)
%INTERVALENTRY One entry as markvalidinterval builds it (markgarbage.m:55-58).
%   BOTH ends get the SAME reference, which is what every call site does.
e = struct( ...
    'timeref_structt0', timerefStruct(clockType, epochValue), ...
    't0', t0, ...
    'timeref_structt1', timerefStruct(clockType, epochValue), ...
    't1', t1);
end

function e = splitAnchoredEntry(t0, t1, epoch0, epoch1)
%SPLITANCHOREDENTRY The signature markvalidinterval permits and no caller uses.
e = struct( ...
    'timeref_structt0', timerefStruct('dev_local_time', epoch0), ...
    't0', t0, ...
    'timeref_structt1', timerefStruct('dev_local_time', epoch1), ...
    't1', t1);
end

function v1 = validIntervalBody(id, elementId, entries)
%VALIDINTERVALBODY THE WRITER, markgarbage.m:93-96.
%   ENTRIES is a struct ARRAY: a 1-element array is the single-interval
%   document, an N-element array is what savevalidinterval writes after N calls
%   (it reads the array back, APPENDS, and replaces the document).
v1 = struct();
v1.document_class = struct('class_name', 'valid_interval', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'app'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {elementId});
v1.base = struct('id', id, 'session_id', 'sess_v1', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% v1 spells these `name` / `version`; universalRenames maps them to
% app_name / app_version.
%
% THE VALUE IS `ndi_app_markgarbage`, AND THIS FIXTURE SAID `ndi.app.markgarbage`
% UNTIL 2026-08-11. The dotted form is what markgarbage.m's own class docstring
% claims ("The app is named 'ndi.app.markgarbage'"); the WRITER sets
% `name = 'ndi_app_markgarbage'` in the constructor, and ndi.app/newdocument
% (app.m:105-114) copies that property into `app.name`. Ground-truth rule: where
% template or prose and WRITER disagree, the writer wins. A fixture built from
% the docstring is the same defect as a fixture built from our own schema, one
% source over.
v1.app = struct('name', 'ndi_app_markgarbage', 'version', '1.0', ...
    'url', '', 'os', '', 'os_version', '', ...
    'interpreter', '', 'interpreter_version', '');
v1.valid_interval = entries;
end

function v1 = validIntervalBodyNoApp(id, elementId, entries)
%VALIDINTERVALBODYNOAPP The same document with NO `app` block at all.
%   Not a shape NDI writes -- savevalidinterval always adds `+ newdocument()`,
%   so every markgarbage document carries the block. It is the shape a document
%   arrives in when the block was lost upstream, or when something other than
%   markgarbage produced the class, and it is what makes the fall-back-to-a-
%   constant branch of `curationMethod` reachable from a test. The point is that
%   such a statement still STATES its verb; a blank there is the defect the
%   method work exists to remove.
%   The superclass list is left ALONE. The tombstone declares base + app and
%   every app field is optional, so ensureClassBlocks pads the block back with
%   blank values -- which is the OTHER half of the same branch (`app_name`
%   present but empty, the template's own default). Both halves must land on
%   `method_from_class_default`, and asserting through this fixture covers
%   whichever of the two the padding produces without the test having to know.
v1 = validIntervalBody(id, elementId, entries);
v1 = rmfield(v1, 'app');
end

% ===================== V_eta fixtures ======================================

function b = etaBody(className, superChain, id, blockName, block, deps)
b = struct();
supers = struct('class_name', {}, 'class_version', {});
for k = 1:numel(superChain)
    supers(end+1) = struct('class_name', superChain{k}, ...
        'class_version', '1.0.0'); %#ok<AGROW>
end
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', supers, 'schema_version', 'V_eta');
if isempty(deps)
    b.depends_on = struct('name', {}, 'value', {});
else
    b.depends_on = deps;
end
b.base = struct('id', id, 'session_id', 'sess_v1', 'name', 'fixture', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
b.(blockName) = block;
end

function b = sessionDoc()
% did-schema #88: the session is an `entity` of type session whose base.id IS
% its session id (V_eta_relation_inheritance_plan.md).
b = did2.build.document('entity', struct('type', did2.build.term('', 'session'), ...
    'local_identifier', 'fixture_session'), 'SessionId', 'session_doc_1', ...
    'Id', 'session_doc_1', 'Validate', false);
end

function b = epochDoc(id, localIdentifier)
%EPOCHDOC What did2.convert.epochMint mints on did-schema #88: an `entity` of
%   type epoch, one per (session, epoch-string).
b = did2.build.document('entity', struct('type', did2.build.term('', 'epoch'), ...
    'local_identifier', localIdentifier), 'SessionId', 'session_doc_1', ...
    'Id', id, 'Validate', false);
end

function b = elementSubject(id)
% did-schema #88: an element is an `entity` (a probe is a device).
b = did2.build.document('entity', struct('type', did2.build.term('', 'device'), ...
    'local_identifier', 'ctx_probe_1'), 'SessionId', 'session_doc_1', ...
    'Id', id, 'Validate', false);
end

function b = derivedSubject(id)
b = etaBody('subject', {'entity'}, id, 'subject', ...
    struct('local_identifier', 'ctx_probe_1_filtered', 'description', ''), []);
end

function b = derivedFromRelation(id, childId, parentId)
%DERIVEDFROMRELATION What migrators_j/element.m:131 emits for a derived element.
%   HAZARD 3's population: a subject whose validity NDI would inherit from its
%   underlying element.
b = etaBody('directed_relation', {'relation'}, id, 'directed_relation', ...
    struct('relation', struct('node', '', 'name', 'derived_from')), ...
    struct('name', {'child', 'parent'}, 'value', {childId, parentId}));
end

% ===================== harness =============================================

function result = batchOf(bodies)
%BATCHOF Convert a mixed v1/V_eta body list into a `result` struct.
%   V_eta-tagged bodies short-circuit to ensureClassBlocks + validate; the v1
%   `valid_interval` goes through the identity migrator onto its tombstone,
%   which is exactly the state the pass finds it in on the real path.
result = did2.convert.v1_to_v2(bodies, 'Validate', true, ...
    'TargetVersion', 'V_eta');
end

function result = runPass(result)
%RUNPASS Run the pass WITH THE EMISSION PATH ARMED.
%   `Decompose` is FALSE by default -- the pass is dormant by team decision,
%   2026-08-12, waiting on `axes[]`. Every test that exercises the preserved
%   decomposition logic goes through here and arms it explicitly; the dormancy
%   tests call the function directly, without the flag, so the DEFAULT is what
%   they measure.
result = did2.convert.resolveValidIntervals(result, 'Validate', true, ...
    'TargetVersion', 'V_eta', 'Decompose', true);
end

function out = docsOfClass(result, className)
out = {};
for k = 1:numel(result.migrated)
    if strcmp(did2.unittest.helpers.classKey(result.migrated{k}), className)
        out{end+1} = result.migrated{k}; %#ok<AGROW>
    end
end
end

function v = depOf(d, name)
%DEPOF The target id of dependency NAME, read off the document struct.
%   Read tolerantly across the three spellings a `depends_on` entry can carry
%   (`value`, `document_id`, `id`) -- the same three
%   +migrators_j/private/jEpochDocId.m reads. did2.document has no
%   dependency_value accessor, so this goes through toStruct rather than
%   through a method call that would only work by throwing.
v = '';
b = d.toStruct();
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if isstruct(deps); items = num2cell(deps(:)'); else; items = deps; end
for k = 1:numel(items)
    if ~strcmp(char(items{k}.name), name); continue; end
    for key = {'value', 'document_id', 'id'}
        if isfield(items{k}, key{1}) && ~isempty(items{k}.(key{1}))
            v = char(items{k}.(key{1}));
            return;
        end
    end
    return;
end
end

function ids = allDepTargets(d, prefix)
%ALLDEPTARGETS Every dependency target whose name starts with PREFIX.
ids = {};
b = d.toStruct();
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if isstruct(deps); items = num2cell(deps(:)'); else; items = deps; end
for k = 1:numel(items)
    nm = char(items{k}.name);
    if numel(nm) < numel(prefix) || ~strcmp(nm(1:numel(prefix)), prefix)
        continue;
    end
    for key = {'value', 'document_id', 'id'}
        if isfield(items{k}, key{1}) && ~isempty(items{k}.(key{1}))
            ids{end+1} = char(items{k}.(key{1})); %#ok<AGROW>
            break;
        end
    end
end
end

% ===================== DORMANT BY DECISION (2026-08-12) ====================
%
% THE DEFAULT IS "COUNT, DO NOT EMIT", AND THAT IS A DECISION, NOT A BUG.
% Team, 2026-08-12: the target model is ONE statement holding an ARRAY of
% booleans against a TIME AXIS, and we WAIT for `axes[]` (DID-schema OPEN_WORK
% #45 -> #32) rather than ship the 1->N shape as an interim. Every other test in
% this file passes `'Decompose', true` through `runPass` to exercise the
% preserved logic; THESE TWO CALL THE PASS THE WAY PRODUCTION CALLS IT.
%
% WITHOUT THESE, RE-ARMING THE PASS WOULD BE A ONE-CHARACTER CHANGE NOTHING
% NOTICES: the emitted documents validate, the corpus stays 0-quarantine and
% 0-orphan, and the only visible difference is a model the team declined.

function testTheDefaultIsDormantAndSaysSo(testCase)
% The pass runs, reports, and appends NOTHING -- with real source documents in
% the batch, which is the only version of this test worth having. A dormant
% pass on an empty batch proves nothing.
entries = [intervalEntry(10, 20, 'dev_local_time', 't00001'), ...
           intervalEntry(30, 40, 'dev_local_time', 't00001')];
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
before = numel(result.migrated);

% NO `Decompose` ARGUMENT -- the production call.
result = did2.convert.resolveValidIntervals(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');

rep = result.valid_interval_decompose;
verifyTrue(testCase, rep.ran, 'the pass must report that it ran');
verifyTrue(testCase, rep.dormant, ...
    ['the pass emitted by default. The 1->N decomposition is NOT the agreed ' ...
     'model -- the team chose one statement with a boolean ARRAY on a time ' ...
     'axis and chose to wait for axes[] -- so arming it by default ships a ' ...
     'shape nobody approved, and every gate we own stays green while it does']);
verifyEqual(testCase, rep.statements_emitted, 0, ...
    'statements_emitted must be 0 BY DECISION, not by accident');
verifyEqual(testCase, rep.references_emitted, 0);
verifyEqual(testCase, rep.intervals_decomposed, 0);
verifyEqual(testCase, rep.documents_appended, 0);
verifyEmpty(testCase, docsOfClass(result, 'observation+logical'));
verifyEmpty(testCase, docsOfClass(result, 'relative_time_reference'));
verifyEqual(testCase, numel(result.migrated), before, ...
    'the dormant pass changed the batch');
end

function testTheDormantPassStillReportsItsDenominator(testCase)
% OPERATING RULE 5. A pass that emits nothing and counts nothing is
% indistinguishable from a pass that read nothing -- `silentLoss` printed
% "0 empty edges" for two days while reading nothing at all. The whole reason
% this pass still RUNS instead of being unwired is that `sources_seen` tells us
% how much work is waiting on `axes[]`.
entries = [intervalEntry(10, 20, 'dev_local_time', 't00001'), ...
           intervalEntry(30, 40, 'dev_local_time', 't00001'), ...
           intervalEntry(50, 60, 'dev_local_time', 't00001')];
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries), ...
    elementSubject('element_2'), ...
    validIntervalBody('vi_2', 'element_2', intervalEntry(0, 5, 'dev_local_time', 't00001'))});
result = did2.convert.resolveValidIntervals(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');
rep = result.valid_interval_decompose;
verifyEqual(testCase, rep.sources_seen, 2, ...
    'the dormant pass stopped counting its source documents');
verifyEqual(testCase, rep.intervals_seen, 4, ...
    ['the dormant pass stopped counting intervals. This is the CEILING on ' ...
     'what a re-armed pass would decompose -- not a prediction of it, since ' ...
     'the refusal reasons are only computable by the path that is off']);
verifyTrue(testCase, rep.documents_inspected > 0, ...
    'documents_inspected is 0 with documents in the batch -- the census read nothing');
verifyEqual(testCase, rep.epoch_documents_seen, 1, ...
    ['the dormant branch was placed before the epoch index, so a denominator ' ...
     'that costs nothing to keep was thrown away']);
end

% ===================== HAZARD 1: absence must keep meaning "valid" =========

function testNoSourceDocumentsMeansNoStatementsAndNoChange(testCase)
% THE HAZARD-1 GATE, and the reason it is first. `ndi.app.markgarbage` is
% opt-in, so most datasets have NO valid_interval documents at all and that
% means "every epoch is entirely good data" -- markgarbage.m:172-176:
%
%     vi = loadvalidinterval(...); if isempty(vi); intervals = [t0 t1]; return; end
%
% A pass that minted an "unknown" statement per element, or that made anything
% require one, would reclassify every epoch of every such dataset. Nothing we
% gate on would notice: this batch is 0-quarantine and 0-orphan either way.
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1')});
before = numel(result.migrated);
result = did2.convert.resolveValidIntervals(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');

rep = result.valid_interval_decompose;
verifyTrue(testCase, rep.ran, 'the pass must report that it ran');
verifyEqual(testCase, rep.sources_seen, 0);
verifyEqual(testCase, rep.statements_emitted, 0);
verifyEqual(testCase, rep.documents_appended, 0);
verifyEmpty(testCase, docsOfClass(result, 'observation+logical'), ...
    ['a logical statement was minted for an element with NO valid_interval ' ...
     'document. Absence means the data is VALID; minting anything here turns ' ...
     'every markgarbage-free dataset from "all good" into "annotated", and ' ...
     'no corpus gate can see the difference']);
verifyEqual(testCase, numel(result.migrated), before, ...
    'the pass changed a batch it had nothing to do in');
end

function testAnEmptyBatchIsNotAnErrorAndReportsItsDenominator(testCase)
% "did not run" and "ran and found nothing" must be different readings of the
% report, not the same one. Operating Rule 5; silentLoss is what happens
% without it.
result = struct('migrated', {{}}, 'quarantine', {{}});
result = did2.convert.resolveValidIntervals(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');
rep = result.valid_interval_decompose;
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, rep.sources_seen, 0);
end

function testDecomposeIsRefusedBecauseItsTargetWasRetired(testCase)
% did-schema #88 RETIRED `logical_observation` (#73 review item 52), the class
% the 1 -> N decomposition emitted, so asking for it is an error that names the
% retirement, not a shape the schema no longer has. The decomposition tests that
% stood here pinned that retired emission and were removed with it (port to
% did-schema #88, 2026-10-21); the dormant census above is what still runs.
entries = intervalEntry(10, 20, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), validIntervalBody('vi_1', 'element_1', entries)});
verifyError(testCase, @() runPass(result), ...
    'did2:convert:validIntervalTargetRetired');
end
