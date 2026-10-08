function tests = testFamilyUniqueness
%TESTFAMILYUNIQUENESS #52 -- what makes two members of a numbered edge family
%   different, and the census that measures it.
%
%   STATUS: WRITTEN 2026-08-10, NEVER EXECUTED. This container has no MATLAB, so
%   nothing in this file has been run. The quick gate
%   (test-migrators-quick.yml) is the first thing that will have an opinion.
%
%   NEW FILE, deliberately. `testSilentLoss.m` and `testMigratorsJ.m` are owned
%   elsewhere and are not touched.
%
%   ------------------------------------------------------------------------
%   THE RULE
%   ------------------------------------------------------------------------
%   #52's TITLE ("role-name the `time_reference_#` statement edges") IS STALE.
%   The row in did-schema/schemas/V_eta_OPEN_WORK.md shrank it on 2026-08-08 to
%   ONE rule, and `V_eta_time_reference_model_plan.md` CHANGE 5 records why:
%
%       Within a `time_reference_#` family every member describes the SAME
%       instant or extent, and `value.clock` is UNIQUE across the family.
%
%   Role names were dropped because the cases that would have needed them do not
%   exist. Split-anchored intervals in particular have NO INSTANCE -- every
%   `markvalidinterval` call site passes ONE reference for both ends -- so there
%   are no `start_anchor`/`end_anchor` edges and this file does not test for
%   any. If an instance ever appears, that is a REPORT, not a licence to build
%   them.
%
%   ------------------------------------------------------------------------
%   WHY THE CHECK IS IN silentLoss AND NOWHERE ELSE
%   ------------------------------------------------------------------------
%   `value.clock` is a property of the REFERENCED document. Nothing on the
%   document carrying `time_reference_2` says how it differs from
%   `time_reference_1`. So:
%
%     did2.schema.cache      sees ONE document; cannot resolve a target. A
%                            per-document version would have to pass whenever it
%                            could not resolve -- an all-zero census that reads
%                            as a clean one, which this repository has already
%                            paid for twice.
%     did2.validate.references  walks edges but is handed IDS (its 'Database'
%                            mode has only ids). It can say an edge resolves,
%                            not what it resolves TO.
%     did2.validate.silentLoss  is handed the whole migrated batch.
%
%   It is therefore a BATCH property and is tested as one. THERE IS NO
%   PER-DOCUMENT FORM OF THIS RULE, and no strictMode switch: enforcing it would
%   mean quarantining from a validator that cannot see the evidence.
%
%   ------------------------------------------------------------------------
%   WHAT THE KEY IS COMPARED ON TODAY
%   ------------------------------------------------------------------------
%   `relative_reference.value.clock` is an `ontology_term` {node, name} and the
%   NDIC clocktype terms are UNMINTED (#67; NDIC.txt was removed from NDI-matlab
%   in 2c19bf24c). So every real key today falls back to the LABEL, and the
%   report counts label-keyed and CURIE-keyed members separately so the
%   transition is visible rather than assumed. testKeyPrefersTheCurieOverTheLabel
%   pins the behaviour that takes over when #67 lands.
%
%   Run with:  results = runtests('did2.unittest.testFamilyUniqueness');

tests = functiontests(localfunctions);
end

% ===================== the rule fires ==================================

function testTwoMembersOnTheSameClockAreReported(testCase)
% THE test. An epoch pointing at two references that BOTH say `dev_local_time`
% is a document whose `_1`/`_2` index carries no information -- exactly the
% state #52 exists to make visible.
[docs, ~] = epochWithClocks({'dev_local_time', 'dev_local_time'});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.total_docs, 3);
verifyGreaterThanOrEqual(testCase, rep.family_uniqueness_violation_count, 1, ...
    'two members sharing value.clock must be reported');
edges = {rep.family_uniqueness_violation.edge_name};
verifyTrue(testCase, any(strcmp('time_reference_#', edges)));
keys = {rep.family_uniqueness_violation.key};
verifyTrue(testCase, any(contains(keys, 'dev_local_time')), ...
    'the report must name the clock the two members share');
end

function testTwoMembersOnDifferentClocksAreSilent(testCase)
% The LIVE case the rule exists to license: one epoch, several clocks, one
% extent each. NDI's epochtable is exactly this (a cell of clocks with a
% matching t0_t1 column each), so this must NOT be a violation.
[docs, ~] = epochWithClocks({'dev_local_time', 'utc'});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0, ...
    'distinct clocks are what a multi-member family is FOR');
end

function testOneMemberCannotViolate(testCase)
% Every migrator in the tree writes only `time_reference_1` today. That must be
% silent, and the denominator must say the rule could not fire.
[docs, ~] = epochWithClocks({'dev_local_time'});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0);
verifyEqual(testCase, rep.uniqueness_denominator.docs_multi_member, 0, ...
    'a one-member family is not a multi-member document');
end

function testThreeMembersTwoOfWhichCollideCountOnce(testCase)
% One occurrence per DUPLICATE member, not per pair: the second member sharing
% a clock is the one nothing distinguishes from the first.
[docs, ~] = epochWithClocks({'utc', 'dev_local_time', 'utc'});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 1);
end

% ===================== the denominators ================================

function testAnUnresolvableTargetIsCountedNotPassed(testCase)
% THE HONESTY TEST. If the referenced documents are not in the batch (an
% incremental import), the rule CANNOT be evaluated. It must say so, not report
% a clean family. Silently passing here is the same defect as a census that
% drops what it cannot parse and then takes its total from the survivors.
[docs, ~] = epochWithClocks({'dev_local_time', 'dev_local_time'});
epochOnly = docs(1);          % the two references left out of the batch
rep = did2.validate.silentLoss(epochOnly);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0);
verifyEqual(testCase, rep.uniqueness_denominator.members_examined, 2);
verifyEqual(testCase, rep.uniqueness_denominator.members_unresolved, 2, ...
    'unresolvable members must be counted as unresolved, never as unique');
verifyEqual(testCase, rep.uniqueness_denominator.members_resolved, 0);
end

function testAReferentWithNoClockIsCountedAsNoKey(testCase)
% The COMMON case today: only `relative_reference` declares `value.clock`, and
% every live anchor is still a `session_relative_reference`. Those members are
% not comparable -- which is a third answer, distinct from "unique" and from
% "duplicate", and must be visible as its own number.
[docs, ~] = epochWithClocks({'', ''});   % blank ontology_term on both
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0, ...
    'two blank clocks are not two equal clocks -- there is nothing to compare');
verifyEqual(testCase, rep.uniqueness_denominator.members_no_key, 2);
end

function testTheDenominatorsExistEvenOnAnEmptyBatch(testCase)
% Operating rule 5, at the boundary: an instrument reports its denominator
% first and UNCONDITIONALLY.
rep = did2.validate.silentLoss({});
verifyTrue(testCase, isfield(rep, 'uniqueness_denominator'));
verifyEqual(testCase, rep.uniqueness_denominator.members_examined, 0);
verifyEqual(testCase, rep.uniqueness_denominator.docs_multi_member, 0);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0);
end

function testMembersKeyedByLabelAreCountedSeparatelyFromCuries(testCase)
% #67 is not done, so every real key is a LABEL. When the NDIC terms are minted
% these counts swap over on their own, and the number to watch is a MIXED
% family -- one member minted, one not -- which would key the same clock two
% ways and read as unique. Counting the two separately is what makes that
% visible instead of inferred.
[docs, ~] = epochWithClocks({'dev_local_time', 'utc'});
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.uniqueness_denominator.members_keyed_by_name, 2);
verifyEqual(testCase, rep.uniqueness_denominator.members_keyed_by_node, 0);
end

function testKeyPrefersTheCurieOverTheLabel(testCase)
% What changes when #67 mints the terms: two members whose LABELS differ but
% whose CURIEs agree are the SAME clock and must collide. Written now, while
% the decision is fresh, so the minting is not also a silent change of meaning.
[docs, refs] = epochWithClocks({'dev_local_time', 'device local time'});
refs{1}.relative_reference.value.clock.node = 'NDIC:0000123';
refs{2}.relative_reference.value.clock.node = 'ndic:0000123';   % case-folded
docs = [docs(1), {did2.document(refs{1})}, {did2.document(refs{2})}];
rep = did2.validate.silentLoss(docs);
verifyEqual(testCase, rep.uniqueness_denominator.members_keyed_by_node, 2);
verifyEqual(testCase, rep.family_uniqueness_violation_count, 1, ...
    'the CURIE is the identity; two labels for one node are one clock');
end

% ===================== scope guards ====================================

function testAFamilyWithNoRuleIsNotChecked(testCase)
% `derived_from_#` members are N DIFFERENT inputs and no uniqueness rule has
% been decided for them. The check is driven by the SCHEMA key
% `referent_unique_by`, not by the word "time_reference", so a family that does
% not declare the rule must contribute nothing -- not even a denominator.
b = bodyOf('subject_calculation', 'calc_1');
b.depends_on = struct( ...
    'name',  {'derived_from_1', 'derived_from_2'}, ...
    'value', {'src_1', 'src_1'});          % the SAME target twice
src = bodyOf('subject', 'src_1');
rep = did2.validate.silentLoss({did2.document(b), did2.document(src)});
verifyEqual(testCase, rep.family_uniqueness_violation_count, 0, ...
    'a family that declares no uniqueness rule must not be checked');
% And not merely "no violation" -- the members must not have been EXAMINED at
% all. Asserting only the count would pass even if the rule had been applied
% and happened to find nothing, which is the vacuous half of the assertion.
verifyEqual(testCase, rep.uniqueness_denominator.members_examined, 0, ...
    'derived_from_# must not enter the uniqueness denominator');
end

function testTheAuditStillNeverRaises(testCase)
% The census must never be able to break a migration, and #52 added a whole new
% resolution path to it.
verifyWarningFree(testCase, @() did2.validate.silentLoss({[]}));
verifyWarningFree(testCase, @() did2.validate.silentLoss(struct([])));
b = bodyOf('epoch', 'ep_bad');
b.depends_on = struct('name', {'time_reference_1'}, 'value', {'nope'});
verifyWarningFree(testCase, @() did2.validate.silentLoss({did2.document(b)}));
end

% ===================== fixtures ========================================

function [docs, refs] = epochWithClocks(clockNames)
%EPOCHWITHCLOCKS An `epoch` plus one `relative_reference` per entry of
%   CLOCKNAMES, wired as `time_reference_1..N`.
%
%   THE SHAPE IS COPIED FROM THE LIVE EMITTER, not composed from a V_eta schema
%   -- the standing rule after migrators were found to have been written against
%   DID-schema's own V_alpha snapshot. See
%   +did2/+convert/+migrators_j/private/jEpochClockReferences.m:139-175: class
%   `relative_reference` over superclass `time_reference`, a `relative_to` edge
%   to the epoch document, and `relative_reference.value` carrying
%   {clock, start, duration}. An empty CLOCKNAMES entry produces the all-blank
%   ontology_term that jOntologyTerm emits while #67 is unminted.
refs = {};
epochBody = bodyOf('epoch', 'ep_1');
deps = struct('name', {}, 'value', {});
for k = 1:numel(clockNames)
    refId = sprintf('ref_%d', k);
    r = bodyOf('relative_reference', refId);
    r.document_class.superclasses = struct('class_name', {'time_reference'}, ...
        'class_version', {'4.0.0'});
    r.depends_on = struct('name', {'relative_to'}, 'value', {'ep_1'});
    r.relative_reference = struct('value', struct( ...
        'clock',    struct('node', '', 'name', clockNames{k}), ...
        'start',    struct('seconds', 0,  'source_unit', 's', ...
                           'source_value', 0,  'approximate', false), ...
        'duration', struct('seconds', 10, 'source_unit', 's', ...
                           'source_value', 10, 'approximate', false)));
    refs{end+1} = r; %#ok<AGROW>
    deps(end+1) = struct('name', sprintf('time_reference_%d', k), ...
        'value', refId); %#ok<AGROW>
end
epochBody.depends_on = deps;
docs = {did2.document(epochBody)};
for k = 1:numel(refs)
    docs{end+1} = did2.document(refs{k}); %#ok<AGROW>
end
end

function b = bodyOf(className, id)
b = struct();
b.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', {}, 'value', {});
b.base = struct('id', id, 'session_id', 'sess_1', 'name', id, ...
    'datestamp', '2024-06-01T12:00:00.000Z');
end
