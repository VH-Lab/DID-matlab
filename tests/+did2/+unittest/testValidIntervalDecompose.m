function tests = testValidIntervalDecompose
%TESTVALIDINTERVALDECOMPOSE `valid_interval` -> boolean `validity_observation`s.
%
%   STATUS: WRITTEN 2026-08-11, NEVER EXECUTED. There is no MATLAB and no
%   Octave in the container this file was written in (`command -v matlab octave
%   octave-cli` returns nothing), so every assertion below is UNVERIFIED. Read
%   it as a specification of intended behaviour, not as a passing suite. Run
%       results = runtests('did2.unittest.testValidIntervalDecompose');
%   and treat any red as a defect in the code or in these tests, not as a
%   surprise.
%
%   NEW FILE, deliberately: testMigratorsJ.m and testStrandedSourceTombstones.m
%   are owned by other sessions and are not touched. The v1 fixture builders
%   below duplicate that file's shapes ON PURPOSE -- its builders are local
%   functions, not shared helpers, and copying twelve lines is cheaper than
%   coupling two files two sessions are editing at once.
%
%   ---------------------------------------------------------------------
%   WHAT IS UNDER TEST
%   ---------------------------------------------------------------------
%   TEAM DECISION 2026-08-11 (DID-schema `schemas/V_eta_OPEN_WORK.md`):
%   `valid_interval` becomes a boolean-valued `subject_statement`.
%   did2.convert.resolveValidIntervals decomposes each v1 document's interval
%   ARRAY into one `validity_observation` per interval plus the
%   `relative_reference` it is anchored to.
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
%     HAZARD 2  ORDER IS LOAD-BEARING. One v1 document holds an ARRAY appended
%               to in call order (markgarbage.m:89), and
%               +app/+stimulus/tuning_response.m:253-256 reads
%               `interval(1,1)`..`interval(1,2)` -- the FIRST interval -- to
%               choose which stretch of signal to analyse. Losing the order
%               fails nothing and silently changes what gets analysed.
%     HAZARD 3  VALIDITY INHERITS (loadvalidinterval falls back to
%               `underlying_element`, markgarbage.m:146-155). THAT IS AN OPEN
%               TEAM QUESTION. The tests here assert that BOTH answers stay
%               buildable and that this pass picks NEITHER -- never that one is
%               right.
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
%   stable/ + draft/ + deprecated/ into one directory). `validity` and
%   `validity_observation` are in the DRAFT tier, so a stable-only path fails
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
v1.app = struct('name', 'ndi.app.markgarbage', 'version', '1.0', ...
    'url', '', 'os', '', 'os_version', '', ...
    'interpreter', '', 'interpreter_version', '');
v1.valid_interval = entries;
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
b = etaBody('session', {'entity'}, 'session_doc_1', 'session', ...
    struct('reference', 'fixture_session'), []);
end

function b = epochDoc(id, localIdentifier)
%EPOCHDOC What did2.convert.epochMint mints: one per (session, epoch-string).
b = etaBody('epoch', {'entity'}, id, 'epoch', ...
    struct('local_identifier', localIdentifier), ...
    struct('name', {'session_id'}, 'value', {'session_doc_1'}));
end

function b = elementSubject(id)
b = etaBody('subject', {'entity'}, id, 'subject', ...
    struct('local_identifier', 'ctx_probe_1', 'description', ''), []);
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
result = did2.convert.resolveValidIntervals(result, 'Validate', true, ...
    'TargetVersion', 'V_eta');
end

function out = docsOfClass(result, className)
out = {};
for k = 1:numel(result.migrated)
    if strcmp(result.migrated{k}.className(), className)
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
result = runPass(result);

rep = result.valid_interval_decompose;
verifyTrue(testCase, rep.ran, 'the pass must report that it ran');
verifyEqual(testCase, rep.sources_seen, 0);
verifyEqual(testCase, rep.statements_emitted, 0);
verifyEqual(testCase, rep.documents_appended, 0);
verifyEmpty(testCase, docsOfClass(result, 'validity_observation'), ...
    ['a validity statement was minted for an element with NO valid_interval ' ...
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
result = runPass(result);
rep = result.valid_interval_decompose;
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, rep.sources_seen, 0);
end

function testTheSourceDocumentIsNeverRemoved(testCase)
% IT ADDS, IT NEVER REMOVES. The `valid_interval` document keeps validating
% against its own tombstone, so a wrong decomposition loses nothing and the
% deletion gate stays a MEASUREMENT rather than an assumption -- the
% verify-before-delete rule (epochfiles_ingested cost 2,484 quarantines by
% removing a class ahead of its evidence).
entries = intervalEntry(10, 100, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
kept = docsOfClass(result, 'valid_interval');
verifyNumElements(testCase, kept, 1, ...
    'the source valid_interval document must survive the decompose');
verifyEqual(testCase, char(kept{1}.get('base.id')), 'vi_1', ...
    'and it must keep its id');
verifyEqual(testCase, result.valid_interval_decompose.sources_fully_decomposed, 1);
end

% ===================== HAZARD 2: order is load-bearing =====================

function testThreeIntervalsKeepTheirV1AppendOrder(testCase)
% THE HAZARD-2 GATE. savevalidinterval APPENDS (markgarbage.m:89), so array
% position IS the order the curator marked them in, and
% +app/+stimulus/tuning_response.m:253-256 reads interval(1,:) -- the FIRST one.
% Decomposing to N statements destroys that unless the position is carried.
%
% The t0 values are deliberately NOT ascending: if `sequence` were derived from
% the times rather than from the array position, this test fails, and a test
% built on ascending times could not tell the two apart.
entries = [intervalEntry(50, 60, 'dev_local_time', 't00001'), ...
           intervalEntry(10, 20, 'dev_local_time', 't00001'), ...
           intervalEntry(30, 40, 'dev_local_time', 't00001')];
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);

stmts = docsOfClass(result, 'validity_observation');
verifyNumElements(testCase, stmts, 3, ...
    'one statement per interval; the v1 block is an ARRAY and accumulation is the normal path');

% sequence -> the t0 of the reference it anchors to, then compared against the
% SOURCE ARRAY's order.
seen = containers.Map('KeyType', 'double', 'ValueType', 'double');
for k = 1:numel(stmts)
    seq = double(stmts{k}.get('validity_observation.sequence'));
    refIds = allDepTargets(stmts{k}, 'time_reference_');
    verifyNumElements(testCase, refIds, 1, ...
        'agreeing anchors must produce exactly ONE reference document');
    ref = [];
    for r = 1:numel(result.migrated)
        if strcmp(char(result.migrated{r}.get('base.id')), refIds{1})
            ref = result.migrated{r};
        end
    end
    verifyNotEmpty(testCase, ref, 'the anchor a statement names must be in the batch');
    seen(seq) = double(ref.get('relative_reference.value.start.seconds'));
end
verifyEqual(testCase, sort(cell2mat(keys(seen))), [1 2 3], ...
    'sequence must be 1-based and contiguous over the source array');
verifyEqual(testCase, seen(1), 50, ...
    ['sequence 1 is not the FIRST APPENDED interval. tuning_response.m reads ' ...
     'interval(1,:) to choose the stretch of signal it analyses, so a ' ...
     'reordering here silently changes what a tuning re-run computes -- and ' ...
     'nothing fails: the documents still validate and the corpus is still ' ...
     '0-quarantine']);
verifyEqual(testCase, seen(2), 10);
verifyEqual(testCase, seen(3), 30);
end

function testASingleIntervalStillGetsSequenceOne(testCase)
% The template's own shape is one interval, and a scalar struct must not read as
% "no order". A `sequence` of 0 or empty here would make the single-interval
% case indistinguishable from a statement that came from no array at all.
entries = intervalEntry(10, 100, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
stmts = docsOfClass(result, 'validity_observation');
verifyNumElements(testCase, stmts, 1);
verifyEqual(testCase, double(stmts{1}.get('validity_observation.sequence')), 1);
end

% ===================== HAZARD 3: validity inherits (NOT DECIDED) ===========

function testInheritanceIsMEASUREDAndNothingIsMaterialised(testCase)
% HAZARD 3 IS AN OPEN TEAM QUESTION AND THIS TEST DOES NOT ANSWER IT.
%
% `loadvalidinterval` falls back to `underlying_element` when a derived element
% has none of its own (markgarbage.m:146-155) -- a QUERY-TIME rule in NDI.
% Whether V_eta re-derives that through `derived_from` or MATERIALISES copies
% onto derived subjects is for the team. What is asserted here is only that the
% pass picks NEITHER: it writes one statement, against the element the source
% named, and REPORTS how many subjects the question would affect.
%
% If a later decision is MATERIALISE, this test is the one to invert -- and
% inverting it is the point of writing it this way rather than leaving the
% behaviour unpinned.
entries = intervalEntry(10, 100, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), derivedSubject('element_2'), ...
    derivedFromRelation('rel_1', 'element_2', 'element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);

stmts = docsOfClass(result, 'validity_observation');
verifyNumElements(testCase, stmts, 1, ...
    ['exactly ONE statement: the derived element must not receive a ' ...
     'materialised copy. Which answer is right is a TEAM decision, and ' ...
     'emitting one here would make it silently']);
verifyEqual(testCase, depOf(stmts{1}, 'subject_id'), 'element_1', ...
    ['the statement belongs to the element the v1 document named. Attaching ' ...
     'it anywhere else destroys the graph a re-deriving answer would walk']);
verifyEmpty(testCase, allDepTargets(stmts{1}, 'derived_from_'), ...
    ['no derived_from edge is minted. It is the seam a materialising answer ' ...
     'would use; filling it now would pre-empt the decision']);
verifyEqual(testCase, result.valid_interval_decompose.inheritance_candidates, 1, ...
    ['the OPEN question must be MEASURED. This counter is how big it is on ' ...
     'real data -- subjects holding a derived_from edge to an element with ' ...
     'statements, i.e. the population NDI''s underlying_element fallback ' ...
     'serves. A decision made without it is a decision made on intuition']);
end

% ===================== the anchor (Decision C) =============================

function testAgreeingAnchorsProduceOneReferenceWithADuration(testCase)
% DECISION C, the case that actually occurs. One `relative_to` + one `clock`
% govern both ends. CHANGE 1 of the signed walkthrough: the EXTENT is a
% DURATION, not the raw t1, so a fuzzy anchor cannot contaminate the span.
entries = intervalEntry(10, 100, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);

refs = docsOfClass(result, 'relative_reference');
verifyNumElements(testCase, refs, 1);
verifyEqual(testCase, depOf(refs{1}, 'relative_to'), 'epoch_doc_1', ...
    ['the anchor is the EPOCH DOCUMENT. It is why this is a batch pass: the ' ...
     'v1 timeref names the epoch by STRING and relative_to is REQUIRED']);
verifyEqual(testCase, double(refs{1}.get('relative_reference.value.start.seconds')), 10);
verifyEqual(testCase, double(refs{1}.get('relative_reference.value.duration.seconds')), 90, ...
    'duration = t1 - t0, not t1 (CHANGE 1)');
verifyEqual(testCase, char(refs{1}.get('relative_reference.value.clock.name')), ...
    'dev_local_time');
verifyEqual(testCase, result.valid_interval_decompose.split_anchor_intervals, 0);
end

function testTheApproxPrefixBecomesAToleranceNotABoolean(testCase)
% CHANGE 4 of the signed time model. NDI states the magnitude only in prose
% (+ndi/+time/clocktype.m:21,23,26 -- "within 5 seconds"), so the 5 is
% TRANSCRIBED. Folding the prefix into a boolean throws the number away, which
% is the error CHANGE 4 exists to record.
entries = intervalEntry(0, 30, 'approx_dev_global_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
refs = docsOfClass(result, 'relative_reference');
verifyNumElements(testCase, refs, 1);
verifyEqual(testCase, char(refs{1}.get('relative_reference.value.clock.name')), ...
    'dev_global_time', 'the approx_ prefix is de-encoded off the clock name');
verifyEqual(testCase, double(refs{1}.get('time_reference.clock_tolerance.seconds')), 5, ...
    'and lands as a QUANTIFIED tolerance on the timeline, not as a flag');
end

function testDisagreeingAnchorsProduceTwoInstantReferences(testCase)
% DECISION C, the case that has NO KNOWN INSTANCE. CHANGE 5 of the signed plan
% measured every markvalidinterval call site -- the docstring (markgarbage.m:10),
% the in-tree test app (+test/+app/markgarbage.m:49) and all six calls in
% TestMarkGarbage.m -- and every one passes the SAME reference for both ends.
%
% So this asserts SHAPE, not modelling: two reference documents, each an
% INSTANT (no duration, because a span between two differently-anchored ends is
% not a quantity either anchor owns), and NEVER a nested anchor block per end --
% that is the inline structure removed from acquisition_epoch.clocks,
% epochclocktimes, distance_metadata and the tuning bag.
%
% NOTE THE #52 INTERACTION, which is NOT closed: the signed uniqueness rule says
% `value.clock` is unique across a `time_reference_#` family, and two anchors
% differing only by EPOCH share a clock. did2.validate.silentLoss reports that
% as `family_uniqueness_violation`. The counter below is what makes the case
% visible instead of quietly emitted.
entries = splitAnchoredEntry(10, 100, 't00001', 't00002');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    epochDoc('epoch_doc_2', 't00002'), elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);

verifyEqual(testCase, result.valid_interval_decompose.split_anchor_intervals, 1);
stmts = docsOfClass(result, 'validity_observation');
verifyNumElements(testCase, stmts, 1);
refIds = allDepTargets(stmts{1}, 'time_reference_');
verifyNumElements(testCase, refIds, 2, ...
    'an interval whose ends are anchored differently becomes TWO reference documents');
targets = {};
for k = 1:numel(result.migrated)
    if ~strcmp(result.migrated{k}.className(), 'relative_reference'); continue; end
    if ~any(strcmp(char(result.migrated{k}.get('base.id')), refIds)); continue; end
    targets{end+1} = depOf(result.migrated{k}, 'relative_to'); %#ok<AGROW>
    b = result.migrated{k}.toStruct();
    verifyFalse(testCase, isfield(b.relative_reference.value, 'duration'), ...
        ['each half is an INSTANT. A duration here would claim a span ' ...
         'measured on one timeline when its ends are on two']);
end
verifyEqual(testCase, sort(targets), {'epoch_doc_1', 'epoch_doc_2'});
end

% ===================== refusals ============================================

function testNoEpochDocumentRefusesAndLeavesTheSourceIntact(testCase)
% The pass anchors to `epoch` DOCUMENTS, which did2.convert.epochMint mints. Run
% without them -- or on an epoch string nothing minted -- it must REFUSE, count,
% and leave the document exactly as pass 1 produced it. Guessing an anchor, or
% emitting `relative_to` empty, would rebuild the invented-empty-edge pattern:
% +did2/+validate/references.m:90 SKIPS empty edges, so the husks would validate
% clean and no gate would see them.
entries = intervalEntry(10, 100, 'dev_local_time', 't99999');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
rep = result.valid_interval_decompose;
verifyEqual(testCase, rep.sources_seen, 1);
verifyEqual(testCase, rep.refused_no_epoch_document, 1);
verifyEqual(testCase, rep.statements_emitted, 0);
verifyEqual(testCase, rep.sources_fully_decomposed, 0, ...
    'the deletion gate must not read as satisfied when nothing was decomposed');
verifyNumElements(testCase, docsOfClass(result, 'valid_interval'), 1);
end

function testNoTimeClockRefuses(testCase)
% NO TIMES => NO REFERENCE (signed). `no_time` is a real, reachable value --
% ndi.time.clocktype lists it among its nine -- and a NaN-valued reference is
% the hollow document silentLoss and isFragment exist to catch.
entries = intervalEntry(10, 100, 'no_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
rep = result.valid_interval_decompose;
verifyEqual(testCase, rep.refused_no_clock, 1);
verifyEqual(testCase, rep.statements_emitted, 0);
end

function testPartialDecompositionIsCountedApartFromFull(testCase)
% Two intervals, one anchorable and one not. `sources_fully_decomposed` is the
% DELETION GATE, so a source that gave up only some of its intervals must not
% count toward it -- retiring the tombstone on a partial count would lose the
% intervals that never converted.
entries = [intervalEntry(10, 20, 'dev_local_time', 't00001'), ...
           intervalEntry(30, 40, 'dev_local_time', 't99999')];
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
rep = result.valid_interval_decompose;
verifyEqual(testCase, rep.intervals_seen, 2);
verifyEqual(testCase, rep.intervals_decomposed, 1);
verifyEqual(testCase, rep.sources_fully_decomposed, 0);
verifyEqual(testCase, rep.sources_partly_decomposed, 1);
end

% ===================== the value, and the graph ============================

function testTheMigratedValueIsTrueAndTheClassCanSayFalse(testCase)
% did_v1 encoded validity in the CLASS NAME, so "this stretch is bad" was
% expressible only as ABSENCE -- markgarbage.m:40 is its own author writing the
% gap down ("it would be great to have a 'markinvalidinterval' companion").
% Every migrated value is therefore TRUE, and that is a property of the SOURCE.
% The second half of this test is the one that matters: FALSE must be a legal,
% NON-VACUOUS value, or the symmetry the decision was made for does not exist.
% (`validity.value` is mustBeNonEmpty and #38's NonVacuousFields check is ARMED
% BY DEFAULT; a `false` that read as blank would quarantine.)
entries = intervalEntry(10, 100, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
stmts = docsOfClass(result, 'validity_observation');
verifyNumElements(testCase, stmts, 1);
verifyTrue(testCase, logical(stmts{1}.get('validity.value.value')), ...
    'a migrated interval is VALID; v1 cannot express anything else');

falseBody = etaBody('validity_observation', ...
    {'subject_observation', 'validity'}, 'stmt_false_1', ...
    'validity', struct('value', struct('value', false)), ...
    struct('name', {'subject_id'}, 'value', {'element_1'}));
falseBody.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'data validity'), ...
    'storage_mode', 'inline');
falseBody.subject_interaction = struct('method', struct('node', '', 'name', ''));
falseBody.validity_observation = struct('sequence', 1);
out = did2.convert.v1_to_v2({falseBody}, 'Validate', true, ...
    'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine, ...
    ['a FALSE validity statement must validate. If it does not, the class ' ...
     'cannot express invalidity and the whole point of the boolean is gone -- ' ...
     'v1 already had "valid or nothing"']);
end

function testEveryEmittedEdgeResolvesInsideTheBatch(testCase)
% The corpus gate is 0 quarantine AND 0 ORPHANS, and this pass emits documents
% that point at each other. A statement whose anchor quarantined would carry a
% `time_reference_1` edge naming a document that is not there -- so the pass
% validates the ANCHORS FIRST and WITHHOLDS any statement that lost one. This
% asserts the outcome directly rather than trusting that ordering.
entries = [intervalEntry(10, 20, 'dev_local_time', 't00001'), ...
           intervalEntry(30, 40, 'dev_local_time', 't00001')];
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
verifyEmpty(testCase, result.quarantine);
refRep = did2.validate.references(result.migrated);
verifyEqual(testCase, refRep.orphan_count, 0, ...
    sprintf('%d orphan edge(s) of %d examined after the decompose', ...
        refRep.orphan_count, refRep.edges_examined));
verifyEqual(testCase, result.valid_interval_decompose.statements_withheld_lost_anchor, 0);
end

function testTheAppBlockIsCountedBecauseItStaysOnTheSource(testCase)
% The v1 `app` block (which app marked these intervals) has no slot on the
% statement, and minting a `software` entity per statement here would produce
% one undeduplicated entity per interval -- did2.convert.resolveDatasetEntities,
% which does the software dedup, has already run by this point. So the
% provenance stays on the RETAINED source document and the pass counts it, so
% the gap is a number rather than a silence.
entries = intervalEntry(10, 100, 'dev_local_time', 't00001');
result = batchOf({sessionDoc(), epochDoc('epoch_doc_1', 't00001'), ...
    elementSubject('element_1'), ...
    validIntervalBody('vi_1', 'element_1', entries)});
result = runPass(result);
verifyEqual(testCase, result.valid_interval_decompose.sources_with_app_block, 1);
verifyEmpty(testCase, docsOfClass(result, 'software'), ...
    'no software entity is minted here; the dedup pass has already run');
end
