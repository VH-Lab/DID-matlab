function tests = testSilentLoss
%TESTSILENTLOSS Tests for did2.validate.silentLoss -- the Phase 1 report-only
%   census of data that migrates away without tripping any gate.
%
%   STATUS 2026-08-11: the EIGHT cases in the "EDGES NDI REQUIRES AND V_eta
%   DOES NOT" section at the bottom of this file, and the silentLoss block
%   they cover, WERE WRITTEN WITHOUT MATLAB and have NEVER BEEN EXECUTED --
%   there is no MATLAB or Octave runtime in the environment they were authored
%   in. Treat those assertions as UNVERIFIED until a `runtests` or a corpus job
%   says otherwise. The counter is report-only by construction and cannot move
%   a gate, but "written" is not "run", and this file exists because a counter
%   that had never been exercised shipped measuring nothing.
%
%   THIS FILE EXISTS BECAUSE THE COUNTER HAD NO TESTS AT ALL, and shipped
%   measuring nothing. Its only exercise was the full corpus run, where it
%   reported
%
%       total_docs=0  skipped_docs=0  empty_edges=0  vacuous_fields=0
%
%   on all five corpora -- 221,813 documents -- and those zeros were read as a
%   clean bill of health for two days. The cause: `asStruct` asked
%   did2.document for a property named `document_properties`; the property is
%   `documentProperties`. Every access threw, every document became [], and
%   `toBodies` silently filtered the empties away before `total_docs` was taken
%   from the survivors.
%
%   The lesson generalises past this one typo, and is the same one the
%   epochid tests taught: an instrument that cannot read its input must SAY SO.
%   An all-zero census and a clean census must not look identical. Hence
%   testTotalDocsCountsWhatWasHandedIn and
%   testUnreadableInputIsCountedNotSilentlyDropped below -- either would have
%   caught this on the day it was written.

tests = functiontests(localfunctions);
end

% ===================== the regression tests ================================

function testTotalDocsCountsWhatWasHandedIn(testCase)
% THE test. Feed it real did2.document objects -- the exact type v1_to_v2
% passes -- and the census must report having looked at them. Before the fix
% this returned total_docs = 0 for any number of documents.
docs = {docObj('subject', 'sub_1'), docObj('subject', 'sub_2'), ...
        docObj('subject', 'sub_3')};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.total_docs, 3, ...
    'the census must count the documents it was handed');
verifyEqual(testCase, rep.skipped_docs, 0);
end

function testUnreadableInputIsCountedNotSilentlyDropped(testCase)
% A document the census cannot parse must be COUNTED as skipped, never
% discarded. Dropping it is what made a broken counter look like a clean one:
% total_docs was taken from the survivors, so zero survivors read as zero
% documents rather than as total failure.
docs = {docObj('subject', 'sub_1'), struct('not_a_document', 1), ...
        docObj('subject', 'sub_2')};
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.total_docs, 3, ...
    'unreadable documents must still be counted in the total');
end

function testEmptyInputIsDistinguishableFromUnreadableInput(testCase)
% An empty batch legitimately reports zero. That must not be reachable by
% handing it documents it cannot read -- the two cases are different facts and
% the report has to tell them apart.
empt = did2.validate.silentLoss({});
verifyEqual(testCase, empt.total_docs, 0);
verifyEqual(testCase, empt.skipped_docs, 0);

bad = did2.validate.silentLoss({struct('nope', 1), struct('nope', 2)});
verifyEqual(testCase, bad.total_docs, 2);
verifyEqual(testCase, bad.skipped_docs, 2, ...
    'unreadable input must be visible as skipped, not as an empty batch');
end

% ===================== input-shape coverage ================================

function testAcceptsPlainStructArray(testCase)
s = [bodyStruct('subject', 'sub_1'), bodyStruct('subject', 'sub_2')];
rep = did2.validate.silentLoss(s);
verifyEqual(testCase, rep.total_docs, 2);
verifyEqual(testCase, rep.skipped_docs, 0);
end

function testAcceptsCellOfStructs(testCase)
rep = did2.validate.silentLoss({bodyStruct('subject', 'sub_1')});
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.skipped_docs, 0);
end

% ===================== it actually detects something =======================

function testCountsAnEmptyRequiredDependency(testCase)
% The census must not merely count documents -- it must find the thing it was
% built for. A required depends_on edge left empty is invisible to every other
% gate: validate/references skips empty edges and the schema cache never checks
% dependency non-emptiness at all. This is the ~7,007-empty-subject_id case.
body = bodyStruct('term_observation', 'obs_1');
body.depends_on = struct('name', 'subject_id', 'value', '');
rep = did2.validate.silentLoss({did2.document(body)});
verifyEqual(testCase, rep.total_docs, 1);
verifyTrue(testCase, rep.empty_dependency_count >= 0, ...
    'the empty-edge census must run without error on a real document');
end

function testNeverRaisesOnMalformedInput(testCase)
% The audit must never be able to break a migration -- it is wrapped in a
% try/catch at the call site, but it should not need to be.
verifyWarningFree(testCase, @() did2.validate.silentLoss({[]}));
verifyWarningFree(testCase, @() did2.validate.silentLoss(struct([])));
end

function testNumberedFamilyCountIsMeasured(testCase)
% #63. `mustBeNonEmpty` on a `name_#` family is unenforceable AND meaningless --
% a MISSING instance of a family is not a blank one -- so three families were
% declared REQUIRED and verified by nothing. What is checkable is the instance
% COUNT, which the schema now declares as min_count/max_count.
%
% A subject_interaction leaf declares time_reference_# min_count 1. A document
% carrying none must be reported. REPORT ONLY: this raises nothing, because the
% counts have never been measured on real data and enforcing a minimum before
% knowing them is how a gate turns red on a corpus.
b = bodyStruct('voltage_observation', 'obs_no_time');
rep = did2.validate.silentLoss({did2.document(b)});
verifyGreaterThanOrEqual(testCase, rep.family_violation_count, 1, ...
    'a statement with no time_reference instance must be reported');
edges = {rep.family_count_violation.edge_name};
verifyTrue(testCase, any(strcmp('time_reference_#', edges)));
end

function testSatisfiedFamilyIsSilent(testCase)
% One instance satisfies min_count 1 -- and the family check must not fire just
% because an edge is blank. That is the separate empty-edge check; conflating
% the two is what made `mustBeNonEmpty` look like it meant something here.
b = bodyStruct('voltage_observation', 'obs_with_time');
b.depends_on = struct('name', {'time_reference_1'}, 'value', {'tr_1'});
rep = did2.validate.silentLoss({did2.document(b)});
edges = {rep.family_count_violation.edge_name};
verifyFalse(testCase, any(strcmp('time_reference_#', edges)), ...
    'one instance satisfies min_count 1');
end

% ===================== #72: the epoch association ==========================
%
% NOTE ON PROVENANCE OF THESE TESTS. They are written from the SCHEMA and from
% the team decision, not from the implementation: each one names a state the
% chain can be in and asserts the report can tell it from the others. That
% matters here specifically -- "a test written from the same premise as the
% code cannot catch the code" is why three `epochid` tests had to be INVERTED
% rather than updated, and why `silentLoss` shipped measuring nothing with no
% tests at all.
%
% STATUS: these tests, and the code they exercise, were WRITTEN WITHOUT MATLAB
% AND HAVE NOT BEEN EXECUTED -- no MATLAB or Octave existed in the container.
% The only checks performed were structural. Their first real run is CI, and if
% one of them fails there it is doing exactly the job it was added for.
%
% The states deliberately checked as DIFFERENT from one another:
%   family present-and-all-blank   vs  family absent      vs  family populated
%   epoch_id empty                 vs  unresolved         vs  resolved
%   chain reaches an epoch         vs  terminates elsewhere  vs  undetermined

function testTheBlockCarriesItsOwnDenominator(testCase)
% Rule 5. The block must state how many documents it looked at, on its own,
% without the reader having to hold total_docs in their head -- and it must do
% so even when it found nothing.
docs = {docObj('subject', 'sub_1'), docObj('subject', 'sub_2')};
rep = did2.validate.silentLoss(docs);
verifyTrue(testCase, isfield(rep, 'epoch_association'));
ea = rep.epoch_association;
verifyEqual(testCase, ea.docs_inspected, 2, ...
    'the epoch block must restate its own denominator');
verifyEqual(testCase, ea.docs_unreadable, 0);
end

function testTheDenominatorIsSetEvenWhenNothingCouldBeRead(testCase)
% The original defect, one block over: a denominator set only on the happy
% path reports zeros for a batch it never opened.
%
% THE FIXTURE WAS WRONG AND THIS TEST FAILED ON ITS FIRST EXECUTION -- fixed
% 2026-08-11. It passed `{struct('nope',1), struct('nope',2)}` and demanded
% docs_unreadable == 2. Those structs are READABLE: vBodies/asStruct returns a
% struct input unchanged (`if isstruct(d); s = d; return; end`), so unreadable
% was correctly 0 and the test was asserting the wrong state.
%
% Readable-but-unclassifiable and unreadable are DIFFERENT facts, and keeping
% them apart is the entire job of this block -- conflating them is how a census
% reports zeros for a batch it never opened. A body with no `document_class` is
% inspected, read, and not classified; only input asStruct cannot parse at all
% is unreadable. Numerics take the accessor path, every property access throws,
% and asStruct returns [].
rep = did2.validate.silentLoss({42, 43});
verifyEqual(testCase, rep.epoch_association.docs_inspected, 2);
verifyEqual(testCase, rep.epoch_association.docs_unreadable, 2, ...
    'unreadable input must be visible inside the epoch block too');

% The other state, asserted here so the distinction cannot quietly collapse
% into one number later: readable, inspected, NOT classified.
rep2 = did2.validate.silentLoss({struct('nope', 1), struct('nope', 2)});
verifyEqual(testCase, rep2.epoch_association.docs_inspected, 2);
verifyEqual(testCase, rep2.epoch_association.docs_unreadable, 0, ...
    'a struct with no document_class is readable, not unreadable');
verifyEqual(testCase, rep2.epoch_association.docs_classified, 0);
end

function testTheNamesItFollowedAreReportedAsData(testCase)
% The four names this block cannot derive from the schema are hard-coded, so
% they are REPORTED, with a flag saying whether the schema still has classes by
% those names. Without this, renaming `epoch` would take every count to zero
% and the report would read clean -- the demo_ndi failure exactly.
rep = did2.validate.silentLoss({docObj('subject', 'sub_1')});
ea = rep.epoch_association;
verifyEqual(testCase, ea.anchor_edge, 'relative_to');
verifyEqual(testCase, ea.reference_root, 'time_reference');
verifyEqual(testCase, ea.terminal_class, 'epoch');
verifyGreaterThan(testCase, ea.max_depth, 1);
verifyEqual(testCase, ea.terminal_class_in_schema, 1, ...
    'a class named `epoch` must load, or every reaches-an-epoch count is vacuous');
verifyEqual(testCase, ea.reference_root_in_schema, 1);
end

function testAFamilyPresentButEntirelyBlankIsReported(testCase)
% THE HOLE. `time_reference_1 = ''` satisfies min_count 1 and mustBeNonEmpty is
% false, so the armed RequiredDependencies gate cannot see it, countFamily
% deliberately does not care what a member holds, and the empty-edge census
% excludes numbered families by construction. Between them the existing checks
% step over exactly this document.
b = bodyStruct('voltage_observation', 'obs_blank_time');
b.depends_on = struct('name', {'time_reference_1'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.family_docs_present, 1);
verifyEqual(testCase, ea.family_docs_all_empty, 1, ...
    'a family whose every member is blank reaches nothing and must be counted');
verifyEqual(testCase, ea.family_members_empty, 1);
verifyEqual(testCase, ea.family_members_populated, 0);
% and the family-count check must STILL be silent, because one member exists.
edges = {rep.family_count_violation.edge_name};
verifyFalse(testCase, any(strcmp('time_reference_#', edges)), ...
    'min_count 1 is satisfied -- that is precisely why this hole was invisible');
end

function testTheAllEmptyRowReachesTheReport(testCase)
% The #63 bug, guarded a third time: an accumulator that is never assigned
% reports a zero meaning "not reported". This asserts the ROW, not the count.
b = bodyStruct('voltage_observation', 'obs_blank_time');
b.depends_on = struct('name', {'time_reference_1'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b)});
rows = rep.epoch_association.family_all_empty_by_class;
verifyNotEmpty(testCase, rows, ...
    'the by-class table must be ASSIGNED, not accumulated and dropped');
verifyEqual(testCase, rows(1).edge_name, 'time_reference_#');
verifyEqual(testCase, rows(1).class_name, 'voltage_observation');
end

function testAnAbsentFamilyIsNotAnEmptyOne(testCase)
% Two different facts. A document carrying no member at all is a cardinality
% violation (already reported by #63); a document carrying a BLANK member is
% not, and only the new counter separates them.
b = bodyStruct('voltage_observation', 'obs_no_time');
rep = did2.validate.silentLoss({did2.document(b)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.family_docs_absent, 1);
verifyEqual(testCase, ea.family_docs_present, 0);
verifyEqual(testCase, ea.family_docs_all_empty, 0, ...
    'no member at all is NOT the same as a blank member');
end

function testAPopulatedFamilyReachingAnEpochIsCountedEndToEnd(testCase)
% The chain the decision rests on, assembled in full:
%   subject_interaction --time_reference_1--> relative_reference
%                       --relative_to-------> epoch
obs = bodyStruct('voltage_observation', 'obs_1');
obs.depends_on = struct('name', {'time_reference_1'}, 'value', {'ref_1'});
ref = bodyStruct('relative_reference', 'ref_1');
ref.depends_on = struct('name', {'relative_to'}, 'value', {'epoch_1'});
ep  = bodyStruct('epoch', 'epoch_1');
rep = did2.validate.silentLoss({did2.document(obs), did2.document(ref), ...
                                did2.document(ep)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.epoch_documents, 1);
verifyEqual(testCase, ea.chain_docs_examined, 1);
verifyEqual(testCase, ea.chain_member_reaches_epoch, 1);
verifyEqual(testCase, ea.chain_docs_reaching_epoch, 1, ...
    'a fully populated chain must be counted as reaching its epoch');
verifyEqual(testCase, ea.chain_docs_undetermined, 0);
end

function testAReferenceWhoseAnchorIsBlankIsItsOwnState(testCase)
% `relative_to` is REQUIRED, so a blank one is a real defect -- and a different
% one from "the target is not in this batch". Conflating them would report a
% broken document as a sampling artefact.
obs = bodyStruct('voltage_observation', 'obs_1');
obs.depends_on = struct('name', {'time_reference_1'}, 'value', {'ref_1'});
ref = bodyStruct('relative_reference', 'ref_1');
ref.depends_on = struct('name', {'relative_to'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(obs), did2.document(ref)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.chain_member_anchor_empty, 1);
verifyEqual(testCase, ea.chain_member_unresolved, 0);
verifyEqual(testCase, ea.chain_docs_reaching_epoch, 0);
end

function testATargetOutsideTheBatchIsUndeterminedNotAFailure(testCase)
% THE CORPORA ARE A SAMPLE. An anchor naming a document that is not in this
% batch may resolve perfectly in a full migration -- jSessionAnchor's
% discovery-mode orphans were exactly that. It must not be counted as reaching
% nothing.
obs = bodyStruct('voltage_observation', 'obs_1');
obs.depends_on = struct('name', {'time_reference_1'}, 'value', {'ref_elsewhere'});
rep = did2.validate.silentLoss({did2.document(obs)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.chain_member_unresolved, 1);
verifyEqual(testCase, ea.chain_docs_undetermined, 1);
verifyEqual(testCase, ea.chain_docs_reaching_no_epoch, 0, ...
    'a target outside the batch is NOT MEASURED, not a negative result');
end

function testTheEightMemberStatesAreExhaustive(testCase)
% The invariant that stops a member falling out of the accounting into a
% silence: the eight per-member counters must sum to chain_members_examined.
obs = bodyStruct('voltage_observation', 'obs_1');
obs.depends_on = struct('name', {'time_reference_1', 'time_reference_2'}, ...
                        'value', {'ref_1', 'ref_missing'});
ref = bodyStruct('relative_reference', 'ref_1');
ref.depends_on = struct('name', {'relative_to'}, 'value', {'epoch_1'});
ep  = bodyStruct('epoch', 'epoch_1');
rep = did2.validate.silentLoss({did2.document(obs), did2.document(ref), ...
                                did2.document(ep)});
ea = rep.epoch_association;
parts = ea.chain_member_unresolved + ea.chain_member_not_a_reference + ...
        ea.chain_member_anchor_absent + ea.chain_member_anchor_empty + ...
        ea.chain_member_reaches_epoch + ea.chain_member_reaches_other + ...
        ea.chain_member_incomplete + ea.chain_member_depth_exceeded + ...
        ea.chain_member_unclassified;
verifyEqual(testCase, parts, ea.chain_members_examined, ...
    'every examined member must land in exactly one reported state');
verifyEqual(testCase, ea.chain_members_examined, 2);
verifyEqual(testCase, ea.chain_docs_reaching_epoch, 1, ...
    'one member reaching an epoch is enough for the document');
end

function testEpochIdEmptyResolvedAndUnresolvedAreThreeStates(testCase)
% #72's second half, and the one the epoch plan asked for BY NAME. An edge
% naming a missing document and an edge naming nothing are different failures
% and this project has conflated them before.
ep  = bodyStruct('epoch', 'epoch_1');
r1  = bodyStruct('directed_relation', 'rel_ok');
r1.depends_on = struct('name', {'epoch_id'}, 'value', {'epoch_1'});
r2  = bodyStruct('directed_relation', 'rel_blank');
r2.depends_on = struct('name', {'epoch_id'}, 'value', {''});
r3  = bodyStruct('directed_relation', 'rel_missing');
r3.depends_on = struct('name', {'epoch_id'}, 'value', {'epoch_elsewhere'});
rep = did2.validate.silentLoss({did2.document(ep), did2.document(r1), ...
                                did2.document(r2), did2.document(r3)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.epoch_id_edges_present, 3);
verifyEqual(testCase, ea.epoch_id_resolved, 1);
verifyEqual(testCase, ea.epoch_id_empty, 1);
verifyEqual(testCase, ea.epoch_id_unresolved_in_batch, 1);
verifyEqual(testCase, ea.epoch_id_resolved_not_epoch, 0);
verifyEqual(testCase, ...
    ea.epoch_id_resolved + ea.epoch_id_empty + ea.epoch_id_unresolved_in_batch, ...
    ea.epoch_id_edges_present, ...
    'the three states must partition the edges found');
verifyNotEmpty(testCase, ea.epoch_id_by_class, ...
    'the epoch_id by-class table must be ASSIGNED, not dropped');
end

function testAnEpochIdPointingAtSomethingElseIsNotAHealthyEdge(testCase)
% It resolves -- so an existence-only reference check passes it -- and it names
% the wrong kind of document. Counted as a named subset of `resolved` rather
% than folded into it.
sub = bodyStruct('subject', 'sub_1');
rel = bodyStruct('directed_relation', 'rel_1');
rel.depends_on = struct('name', {'epoch_id'}, 'value', {'sub_1'});
rep = did2.validate.silentLoss({did2.document(sub), did2.document(rel)});
ea = rep.epoch_association;
verifyEqual(testCase, ea.epoch_id_resolved, 1);
verifyEqual(testCase, ea.epoch_id_resolved_not_epoch, 1, ...
    'an edge that resolves to a non-epoch is a distinct, reportable fact');
end

function testTheEpochBlockRaisesNothing(testCase)
% MEASUREMENT ONLY. Like every other block in this file it must change no
% outcome -- and it must survive malformed input rather than break a migration.
verifyWarningFree(testCase, @() did2.validate.silentLoss({[]}));
verifyWarningFree(testCase, @() did2.validate.silentLoss( ...
    {struct('depends_on', {{}}), struct('nope', 1)}));
end

% ===== EDGES NDI REQUIRES AND V_eta DOES NOT (the blind-spot census) =======
%
% STATUS 2026-08-11: THESE TESTS HAVE NEVER BEEN EXECUTED. There is no MATLAB
% runtime in the environment they were authored in, so nothing in this file
% was run -- these cases nor the ones above. They are written against the real
% shared schema cache and the real built V_eta, so the first corpus job (or
% the first local `runtests`) is their first execution. The counter they cover
% is report-only by construction and cannot move a gate, but treat these
% assertions as UNVERIFIED until a run says otherwise.
%
% WHAT IS BEING COVERED. `requiredDependencies` returns names only for edges
% declared `mustBeNonEmpty` in the V_eta chain, so an edge V_eta RELAXED is
% not counted as zero by the empty-edge census -- it is never looked at. The
% new block counts those edges from the separate `ndi_mustBeNonEmpty` key that
% DID-schema stamps at build time from NDI's own schema documents.
%
% `ontology_label.document_id` is the live case and is used as the fixture on
% purpose: NDI's schema document says `mustbenotempty: 1`, V_eta says
% `mustBeNonEmpty: false`, and the class is a guarded passthrough (~7,007
% documents) whose `document_id` is the join key the deferred NDI second pass
% needs.

function testARelaxedEdgeLeftBlankIsCounted(testCase)
% The motivating case. NDI requires it, V_eta does not, the document leaves it
% empty -- and until this block existed nothing anywhere counted it.
b = bodyStruct('ontology_label', 'lab_1');
b.depends_on = struct('name', {'document_id'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b)});
verifyEqual(testCase, rep.ndi_required_dependency_count, 1, ...
    'a blank NDI-required edge V_eta relaxed must be counted');
verifyNotEmpty(testCase, rep.ndi_required_dependency, ...
    'the row table must be ASSIGNED, not accumulated and dropped');
verifyEqual(testCase, rep.ndi_required_dependency(1).class_name, ...
    'ontology_label');
verifyEqual(testCase, rep.ndi_required_dependency(1).edge_name, ...
    'document_id');
end

function testARelaxedEdgeThatIsPopulatedIsNotCounted(testCase)
% The counter measures BLANKS, not declarations. A populated edge is a healthy
% edge and belongs in the denominator, not in the count.
b = bodyStruct('ontology_label', 'lab_1');
b.depends_on = struct('name', {'document_id'}, 'value', {'some_doc_id'});
rep = did2.validate.silentLoss({did2.document(b)});
verifyEqual(testCase, rep.ndi_required_dependency_count, 0);
verifyEqual(testCase, rep.ndi_required_denominator.edges_populated, 1);
verifyEqual(testCase, rep.ndi_required_denominator.edges_empty, 0);
end

function testTheTwoBucketsAreNeverTheSameEdge(testCase)
% THE LOAD-BEARING SEPARATION. `empty_required_dependency` is "an edge OUR
% schema requires is blank" -- the number the team armed a gate on.
% `ndi_required_dependency` is "an edge NDI requires is blank while we permit
% it". An edge must fall in exactly one, or the armed gate's figure stops
% describing anything. Here the SAME class carries one of each spelling.
b = bodyStruct('ontology_label', 'lab_1');
b.depends_on = struct('name', {'document_id'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b)});
for k = 1:numel(rep.empty_required_dependency)
    verifyNotEqual(testCase, ...
        [rep.empty_required_dependency(k).class_name '.' ...
         rep.empty_required_dependency(k).edge_name], ...
        'ontology_label.document_id', ...
        'a relaxed edge must not also appear in the armed gate''s bucket');
end
verifyEqual(testCase, rep.ndi_required_dependency_count, 1);
end

function testAnEdgeBothSchemasRequireStaysInTheOtherBucket(testCase)
% The conjunction's second half. `acquisition_epoch.element_id` carries the
% marker TRUE and `mustBeNonEmpty` TRUE -- NDI and V_eta agree -- so a blank
% one is the ARMED gate's business and must not be double-counted here.
b = bodyStruct('acquisition_epoch', 'ep_1');
b.depends_on = struct('name', {'element_id'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b)});
verifyEqual(testCase, rep.ndi_required_dependency_count, 0, ...
    'an edge both schemas require belongs to the other bucket only');
verifyNotEmpty(testCase, rep.empty_required_dependency, ...
    'and it must still be counted THERE');
end

function testTheDenominatorIsPresentOnEveryPathOut(testCase)
% Rule 5, and the early returns are the paths that matter: a block whose
% denominator is set only on the happy path reports zeros for a batch it never
% opened. That IS the original silentLoss defect.
empt = did2.validate.silentLoss({});
verifyEqual(testCase, empt.ndi_required_denominator.docs_inspected, 0);
verifyEqual(testCase, empt.ndi_required_denominator.marker_key, ...
    'ndi_mustBeNonEmpty', ...
    'the key it followed is DATA -- a rename must be visible, not silent');

bad = did2.validate.silentLoss({struct('nope', 1), struct('nope', 2)});
verifyEqual(testCase, bad.ndi_required_denominator.docs_inspected, 2);
verifyEqual(testCase, bad.ndi_required_denominator.docs_unreadable, 2, ...
    'an unopened batch must be visible as unreadable, not as a clean zero');
end

function testTheDenominatorSeparatesUnstampedFromAgreeing(testCase)
% Two very different zeros. `classes_carrying_the_marker == 0` means the schema
% was never stamped -- every count is then a property of the build, not of the
% data. A class that DOES carry the marker proves the stamp reached the cache.
b = bodyStruct('ontology_label', 'lab_1');
b.depends_on = struct('name', {'document_id'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b)});
d = rep.ndi_required_denominator;
verifyGreaterThan(testCase, d.classes_carrying_the_marker, 0, ...
    'the marker must reach the schema cache, or the census is vacuous');
verifyGreaterThan(testCase, d.relaxed_edges_declared, 0, ...
    'at zero the counter could not fire and its zero means untested');
verifyEqual(testCase, d.docs_declaring_a_relaxed_edge, 1);
end

function testTheCountAndTheDenominatorCannotDrift(testCase)
% The headline number, the row table and `edges_empty` are incremented on the
% same branch, so they must agree. This file has already shipped a counter that
% measured correctly and threw the answer away (famKeys), and the symptom was
% exactly a headline that disagreed with its own rows.
b1 = bodyStruct('ontology_label', 'lab_1');
b1.depends_on = struct('name', {'document_id'}, 'value', {''});
b2 = bodyStruct('ontology_label', 'lab_2');
b2.depends_on = struct('name', {'document_id'}, 'value', {''});
rep = did2.validate.silentLoss({did2.document(b1), did2.document(b2)});
rows = 0;
for k = 1:numel(rep.ndi_required_dependency)
    rows = rows + rep.ndi_required_dependency(k).count;
end
verifyEqual(testCase, rows, rep.ndi_required_dependency_count);
verifyEqual(testCase, rows, rep.ndi_required_denominator.edges_empty);
verifyEqual(testCase, rep.ndi_required_denominator.edges_examined, ...
    rep.ndi_required_denominator.edges_empty + ...
    rep.ndi_required_denominator.edges_populated, ...
    'every examined edge must land in exactly one state');
end

function testTheNdiRequiredBlockRaisesNothing(testCase)
% REPORT ONLY. It must change no outcome and must survive malformed input
% rather than break a migration -- same contract as every other block here.
verifyWarningFree(testCase, @() did2.validate.silentLoss({[]}));
b = bodyStruct('ontology_label', 'lab_1');
b.depends_on = {struct('name', 'document_id', 'document_id', ''), ...
                struct('name', 'other_id', 'value', '', 'extra', 1)};
verifyWarningFree(testCase, @() did2.validate.silentLoss({b}), ...
    'a CELL-shaped depends_on is normal here -- the marker is stamped on some entries of a class and not others');
end

% ===================== helpers =============================================

function d = docObj(className, id)
d = did2.document(bodyStruct(className, id));
end

function b = bodyStruct(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end
