function tests = testTimeReferenceFamilies
%TESTTIMEREFERENCEFAMILIES  Tests for did2.validate.timeReferenceFamilies --
%   the #52 EVIDENCE instrument: how many time references does one statement
%   carry, and what shapes occur when it carries more than one.
%
%   STATUS: WRITTEN WITHOUT MATLAB AND NOT EXECUTED LOCALLY. No MATLAB and no
%   Octave were available in the container this was written in, so nothing in
%   this file or in the function it tests has been run here. The quick gate
%   (test-migrators-quick.yml) is the first execution of both.
%
%   NEW FILE, deliberately. `testSilentLoss.m` and `testFamilyUniqueness.m` are
%   owned elsewhere and are not touched.
%
%   ------------------------------------------------------------------------
%   THE FIXTURES ARE COPIED FROM THE EMITTERS, NOT FROM A SCHEMA
%   ------------------------------------------------------------------------
%   The standing rule after migrators were found to have been written against
%   DID-schema's own V_alpha snapshot: build a fixture from what the WRITER
%   emits. Every body below is traced to a live emitter:
%
%     validityObservation()   +did2/+convert/resolveValidIntervals.m:851-871
%                             (makeValidityObservation) -- class
%                             `validity_observation` over {subject_observation,
%                             validity}, deps `subject_id` +
%                             `time_reference_1..N` numbered in the order given,
%                             base.name `migrated_valid_interval`.
%     splitAnchorPair()       resolveValidIntervals.m:544-551 + :787-816
%                             (makeReference with an EMPTY duration) -- the
%                             Decision C disagreeing case: two `relative_reference`
%                             INSTANTS, each anchored to its own epoch document,
%                             base.name `migrated_valid_interval_anchor`.
%     nClockPair()            +migrators_j/private/jEpochClockReferences.m:139-175
%                             -- one `relative_reference` per (clock, interval)
%                             pair, ALL anchored to the SAME epoch document,
%                             each carrying start AND duration, base.name
%                             `migrated_epoch_extent`.
%
%   The two multi-member shapes are therefore not invented: they are the only
%   two the tree can construct, and they differ on exactly the axes the shape
%   key reports.
%
%   ------------------------------------------------------------------------
%   WHAT THESE TESTS DO NOT ASSERT
%   ------------------------------------------------------------------------
%   NO ROLE NAME APPEARS ANYWHERE IN THIS FILE as an expected value. #52's role
%   vocabulary is a team decision; the instrument exists to supply the evidence
%   for it and the tests pin the evidence, not a naming. The shape labels that
%   ARE asserted (`clock=`, `relative_to=`, `extent=`) are field paths the schema
%   already declares, and testTheDiscriminatorLabelIsReadFromTheSchema pins that
%   they are read rather than typed.
%
%   ------------------------------------------------------------------------
%   THE ANTI-VACUITY DISCIPLINE
%   ------------------------------------------------------------------------
%   Almost every test asserts a DENOMINATOR alongside its count. An instrument
%   that stopped measuring reports zeros, and a suite that only ever asserts
%   "0 violations" goes green against it -- which is exactly how a partition
%   check in this repository was replaced with a constant and 76 tests stayed
%   green. testTheShapeTablePartitionsTheMultiReferenceStatements is built on a
%   batch where the partition is NON-TRIVIAL (two different shapes plus an
%   unshapeable one), so a constant cannot satisfy it.
%
%   ------------------------------------------------------------------------
%   THE MUTATION MATRIX -- MEASURED IN CI, NOT PREDICTED
%   ------------------------------------------------------------------------
%   A green suite proves nothing about a suite that cannot fail. No MATLAB was
%   available where this was written, so the mutations were run THROUGH CI: five
%   throwaway branches, one deliberate break each, one quick-gate run each. Every
%   run is quoted with its id so the claim is checkable rather than asserted.
%
%     BASELINE  run 31518220863 (b0fd606)
%               1041 run / 1041 passed / 0 FAILED / 0 incomplete
%
%     M1  trfShapeKey truncated to 5 chars, so every shape collapses to one row
%         run 31518666053  -> 1041 run, 1036 passed, 4 FAILED
%           testTheSplitAnchorAndNClockShapesAreDistinguishable
%           testAMixedAbsoluteAndRelativeFamilyIsItsOwnShape
%           testTheShapeTablePartitionsTheMultiReferenceStatements
%           testTheDiscriminatorLabelIsReadFromTheSchema
%
%     M2  an unresolvable referent stops incrementing nUnresolved, so a family
%         whose anchors are outside the batch is "shaped" from empty bodies
%         run 31518667609  -> 1 FAILED
%           testAnUnshapeableStatementIsCountedNeverGuessed
%         ONLY that one, which is the point: the partition still holds, so the
%         accounting test cannot see this and a dedicated test must.
%
%     M3  both vacuity flags forced false -- every zero reads as MEASURED
%         run 31518669835  -> 4 FAILED
%           testTheDenominatorsAndHeadlineExistOnAnEmptyBatch
%           testABatchWithNoStatementsReadsAsVACUOUSNotAsClean
%           testASingleReferenceIsTheWellDefinedCase
%           testAnUnshapeableStatementIsCountedNeverGuessed
%
%     M4  THE INSTRUMENT STOPS MEASURING: `bodies = {}` after the denominator is
%         set, so docs_inspected still prints and nothing is ever read
%         run 31518672214  -> 17 FAILED
%         Seventeen of the nineteen. The two that stay green are
%         testUnreadableDocumentsAreCountedNeverDropped (every document was
%         unreadable anyway) and testTheDenominatorsAndHeadlineExistOnAnEmptyBatch
%         (an empty batch returns before the mutated line) -- neither CAN detect
%         it, and saying which two is the honest form of the claim.
%
%     M5  the family filter stops restricting to TIME references, so
%         `derived_from_#` is counted as one
%         run 31518674401  -> 2 FAILED
%           testAStatementWithNoReferenceIsAMeasuredZeroNotAVacuousOne
%           testANonTimeFamilyContributesNothingNotEvenADenominator
%
%   `testBatchPassWiring/testCrossRepoDivergenceIsExactlyTheCheckedInTable` shows
%   as INCOMPLETE in all six runs. It is unrelated -- the NDI sibling checkout is
%   best-effort on this workflow -- and is named here so it is not read as fallout.
%
%   THE FIVE PROBE BRANCHES ARE STILL ON THE REMOTE, and the commit that added
%   this matrix said they were deleted. They are not: `git push --delete` returns
%   HTTP 403 from this environment, which permits creating and updating a ref and
%   not removing one. `claude/trf-mut1..5` exist in BOTH DID-matlab and DID-schema
%   (the sibling refs exist only because this workflow checks out did-schema at
%   the SAME branch name and fails outright when it is absent). They carry
%   deliberately broken code, are marked "do not merge" in their commit messages,
%   and someone with delete rights should remove all ten. The run ids above are
%   the durable record; nothing depends on the branches surviving.
%
%   Run with:  results = runtests('did2.unittest.testTimeReferenceFamilies');

tests = functiontests(localfunctions);
end

% ===================== denominators and vacuity ============================

function testTheDenominatorsAndHeadlineExistOnAnEmptyBatch(testCase)
% Operating rule 5 at the boundary: the denominator prints FIRST and
% UNCONDITIONALLY, including on the early return an empty batch takes.
rep = did2.validate.timeReferenceFamilies({});
verifyEqual(testCase, rep.docs_inspected, 0);
verifyEqual(testCase, rep.slots_examined, 0);
verifyEqual(testCase, rep.statements_with_reference, 0);
verifyEqual(testCase, rep.statements_multi_reference, 0);
verifyNotEmpty(testCase, rep.headline, ...
    'the headline carries the denominators and must exist on every path out');
verifyTrue(testCase, contains(rep.headline, 'DENOMINATOR'));
verifyTrue(testCase, rep.reference_census_vacuous);
verifyTrue(testCase, contains(rep.reference_census_vacuous_reason, 'VACUOUS'));
verifyTrue(testCase, rep.shape_census_vacuous);
end

function testABatchWithNoStatementsReadsAsVACUOUSNotAsClean(testCase)
% THE CENTRAL HONESTY TEST. A batch of documents that could not carry a time
% reference must not report "0 multi-reference statements" as though it had
% looked at any -- that is the all-zero census that read as a clean one for two
% days.
docs = {did2.document(bodyOf('subject', 'sub_1')), ...
        did2.document(bodyOf('subject', 'sub_2'))};
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.docs_inspected, 2);
verifyEqual(testCase, rep.docs_classified, 2, ...
    'both documents must have been classified -- otherwise this is not a measurement');
verifyEqual(testCase, rep.docs_declaring_family, 0);
verifyTrue(testCase, rep.reference_census_vacuous);
verifyTrue(testCase, contains(rep.reference_census_vacuous_reason, 'VACUOUS'));
verifyTrue(testCase, contains(rep.reference_census_vacuous_reason, 'says nothing'));
end

function testUnreadableDocumentsAreCountedNeverDropped(testCase)
% The denominator is what was HANDED IN. Taking it from the survivors is the
% defect vBodies exists to document.
rep = did2.validate.timeReferenceFamilies({[], []});
verifyEqual(testCase, rep.docs_inspected, 2);
verifyEqual(testCase, rep.docs_unreadable, 2);
verifyEqual(testCase, rep.docs_classified, 0);
end

function testAStatementWithNoReferenceIsAMeasuredZeroNotAVacuousOne(testCase)
% The distinction the whole report turns on. A `validity_observation` that
% declares the family and carries no member IS a result: the family could have
% been populated and was not. It must NOT be reported as vacuous.
b = validityObservation('vo_1', {});
rep = did2.validate.timeReferenceFamilies({did2.document(b)});
verifyEqual(testCase, rep.docs_declaring_family, 1);
verifyEqual(testCase, rep.slots_examined, 1);
verifyEqual(testCase, rep.slots_with_no_member, 1);
verifyEqual(testCase, rep.statements_with_reference, 0);
verifyFalse(testCase, rep.reference_census_vacuous, ...
    'the family was declared and inspected -- this zero is measured, not vacuous');
verifyTrue(testCase, contains(rep.reference_census_vacuous_reason, 'MEASURED'));
end

function testABlankMemberIsNotAReference(testCase)
% `time_reference_1 = ''` satisfies min_count and names no document. Counting it
% as a reference would make "one anchor" and "one blank where an anchor goes"
% the same number, which is the hole #72 had to open in silentLoss.
b = validityObservation('vo_1', {});
b.depends_on(end+1) = struct('name', 'time_reference_1', 'value', '');
rep = did2.validate.timeReferenceFamilies({did2.document(b)});
verifyEqual(testCase, rep.members_examined, 1, ...
    'the blank member must be EXAMINED -- it is present');
verifyEqual(testCase, rep.members_blank, 1);
verifyEqual(testCase, rep.slots_with_blank_members_only, 1);
verifyEqual(testCase, rep.statements_with_reference, 0);
end

% ===================== the count distribution ==============================

function testASingleReferenceIsTheWellDefinedCase(testCase)
% What every migrator in the tree writes today: exactly one member. The count
% distribution must say so, and the SHAPE census must declare itself vacuous
% with a reason that distinguishes "does not occur" from "is fine".
docs = statementWithReferences('vo_1', nClockPair(1, 'a'));
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.statements_with_reference, 1);
verifyEqual(testCase, numel(rep.count_distribution), 1);
verifyEqual(testCase, rep.count_distribution(1).members, 1);
verifyEqual(testCase, rep.count_distribution(1).statements, 1);
verifyEqual(testCase, rep.statements_multi_reference, 0);
verifyTrue(testCase, rep.shape_census_vacuous);
verifyTrue(testCase, contains(rep.shape_census_vacuous_reason, 'exactly one'));
verifyFalse(testCase, rep.reference_census_vacuous);
end

function testTheDistributionSeparatesOneTwoAndThree(testCase)
% THE NUMBER THAT MATTERS is how many statements are in the undefined regime, so
% the distribution has to distinguish the counts rather than report a total.
docs = [ statementWithReferences('vo_1', nClockPair(1, 'a')), ...
         statementWithReferences('vo_2', nClockPair(2, 'b')), ...
         statementWithReferences('vo_3', nClockPair(3, 'c')) ];
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.statements_with_reference, 3);
verifyEqual(testCase, [rep.count_distribution.members], [1 2 3], ...
    'the distribution must be per-count and in ascending order');
verifyEqual(testCase, [rep.count_distribution.statements], [1 1 1]);
verifyEqual(testCase, rep.statements_multi_reference, 2, ...
    'two of the three statements are in the undefined regime');
end

% ===================== the shapes ==========================================

function testTheSplitAnchorAndNClockShapesAreDistinguishable(testCase)
% THE SUBSTANCE. These are the only two multi-member shapes the tree can build,
% and they are DIFFERENT modelling situations that the #52 uniqueness rule alone
% cannot tell apart -- both families have "unique" members.
%
%   split anchor : same clock, DIFFERENT relative_to, two INSTANTS
%   N clocks     : DIFFERENT clocks, same relative_to, two SPANS
docs = [ statementWithReferences('vo_split', splitAnchorPair()), ...
         statementWithReferences('vo_clocks', nClockPair(2, 'k')) ];
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.statements_multi_reference, 2);
verifyEqual(testCase, rep.shape_denominator.multi_slots_shaped, 2, ...
    'both statements had every referent in the batch, so both are shapeable');
verifyEqual(testCase, numel(rep.shape), 2, ...
    'the two situations must not collapse into one row');
keys = {rep.shape.shape_key};
% Assert PRESENCE before indexing: an absent row must fail as a verification,
% not error out of the test on an empty subscript.
verifyTrue(testCase, any(contains(keys, 'relative_to=distinct')), ...
    sprintf('no split-anchor shape among: %s', strjoin(keys, ' ;; ')));
verifyTrue(testCase, any(contains(keys, 'relative_to=same')), ...
    sprintf('no shared-anchor shape among: %s', strjoin(keys, ' ;; ')));

splitKey = keys{find(contains(keys, 'relative_to=distinct'), 1)};
verifyTrue(testCase, contains(splitKey, 'kind=2rel'));
verifyTrue(testCase, contains(splitKey, 'clock=same'));
verifyTrue(testCase, contains(splitKey, 'extent=2instant'));

clockKey = keys{find(contains(keys, 'relative_to=same'), 1)};
verifyTrue(testCase, contains(clockKey, 'kind=2rel'));
verifyTrue(testCase, contains(clockKey, 'clock=distinct'));
verifyTrue(testCase, contains(clockKey, 'extent=2span'));
end

function testAMixedAbsoluteAndRelativeFamilyIsItsOwnShape(testCase)
% "is one an absolute_reference and the other relative" is one of the properties
% the team asked to be grouped on. It must not be folded in with two relatives.
refs = nClockPair(1, 'm');
abs1 = bodyOf('absolute_reference', 'ref_abs');
abs1.document_class.class_version = '2.0.0';
abs1.document_class.superclasses = struct('class_name', {'time_reference'}, ...
    'class_version', {'4.0.0'});
abs1.base.name = 'migrated_session_anchor';
abs1.absolute_reference = struct('value', struct( ...
    'start', struct('utc', '2024-06-01T12:00:00.000Z', ...
                    'source_value', '2024-06-01T12:00:00.000Z', ...
                    'source_timezone', 'UTC', 'source_utc_offset', '+00:00', ...
                    'approximate', false)));
refs{end+1} = abs1;
docs = statementWithReferences('vo_mixed', refs);
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.statements_multi_reference, 1);
verifyEqual(testCase, numel(rep.shape), 1);
verifyTrue(testCase, contains(rep.shape(1).shape_key, 'kind=1abs+1rel'), ...
    sprintf('mixed families must be their own shape; got "%s"', rep.shape(1).shape_key));
% The absolute reference has no `relative_to` and the relative one does, so the
% anchor verdict is partly_absent -- NOT `same`, and not silently dropped.
verifyTrue(testCase, contains(rep.shape(1).shape_key, 'relative_to=partly_absent'));
end

function testAnUnshapeableStatementIsCountedNeverGuessed(testCase)
% An incremental import can hand over the statement without its anchors. The
% shape is then UNKNOWN, and "unknown" must be its own row -- this is the one
% zero that must never read as clean.
docs = statementWithReferences('vo_1', splitAnchorPair());
statementOnly = docs(1);          % the two references left out of the batch
rep = did2.validate.timeReferenceFamilies(statementOnly);
verifyEqual(testCase, rep.statements_multi_reference, 1);
verifyEqual(testCase, rep.shape_denominator.multi_members_examined, 2);
verifyEqual(testCase, rep.shape_denominator.multi_members_unresolved, 2);
verifyEqual(testCase, rep.shape_denominator.multi_members_resolved, 0);
verifyEqual(testCase, rep.shape_denominator.multi_slots_shaped, 0);
verifyEqual(testCase, rep.shape_denominator.multi_slots_unresolved, 1);
verifyEqual(testCase, numel(rep.shape), 1);
verifyTrue(testCase, contains(rep.shape(1).shape_key, 'NOT SHAPEABLE'));
verifyTrue(testCase, rep.shape_census_vacuous);
verifyTrue(testCase, contains(rep.shape_census_vacuous_reason, 'UNMEASURED'), ...
    'an occupied but unmeasurable regime must say so in words');
end

function testTheShapeTablePartitionsTheMultiReferenceStatements(testCase)
% THE ACCOUNTING TEST, on a batch where the partition is NON-TRIVIAL: two
% different shapes plus one that cannot be shaped at all. A statement that falls
% out of the shape table has dropped into a silence, and a constant-returning
% implementation cannot satisfy this together with the distinctness test above.
docs = [ statementWithReferences('vo_split',  splitAnchorPair()), ...
         statementWithReferences('vo_clocks', nClockPair(2, 'k')) ];
orphan = statementWithReferences('vo_orphan', nClockPair(2, 'ORPHAN'));
docs = [docs, orphan(1)];         % statement only -- its anchors stay out

rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.statements_multi_reference, 3);
verifyEqual(testCase, rep.shape_denominator.multi_slots_examined, 3);
verifyEqual(testCase, sum([rep.shape.statements]), rep.statements_multi_reference, ...
    'the shape rows must PARTITION the multi-reference statements');
verifyEqual(testCase, rep.shape_denominator.multi_slots_shaped ...
    + rep.shape_denominator.multi_slots_unresolved, ...
    rep.shape_denominator.multi_slots_examined, ...
    'shaped + unshapeable must account for every multi-reference statement');
verifyEqual(testCase, rep.shape_denominator.multi_members_resolved ...
    + rep.shape_denominator.multi_members_unresolved, ...
    rep.shape_denominator.multi_members_examined, ...
    'resolved + unresolved must account for every member');
verifyEqual(testCase, numel(rep.shape), 3, ...
    'two real shapes plus the not-shapeable row');
end

function testEachShapeCarriesAnExampleStatementIdThatCanBeOpened(testCase)
% The team asked for an example id per shape so a row can be looked at rather
% than believed.
docs = statementWithReferences('vo_split', splitAnchorPair());
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, numel(rep.shape), 1);
verifyEqual(testCase, rep.shape(1).example_document_id, 'vo_split');
verifyEqual(testCase, rep.shape(1).example_class_name, 'validity_observation');
verifyEqual(testCase, rep.shape(1).members, 2);
verifyEqual(testCase, rep.shape(1).family, 'time_reference_#');
end

% ===================== emitter attribution =================================

function testTheEmitterIsAttributedFromWhatTheDocumentsActuallyCarry(testCase)
% `base.name` is the only provenance a migrated document carries, and the ANCHOR
% names are the sharper fingerprint -- a split-anchor pair is two
% `migrated_valid_interval_anchor` documents, which names the pass.
docs = statementWithReferences('vo_split', splitAnchorPair());
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, numel(rep.emitter), 1);
verifyEqual(testCase, rep.emitter(1).statement_class, 'validity_observation');
verifyEqual(testCase, rep.emitter(1).statement_name, 'migrated_valid_interval');
verifyEqual(testCase, rep.emitter(1).anchor_names, 'migrated_valid_interval_anchor');
verifyEqual(testCase, rep.emitter(1).statements, 1);
verifyEqual(testCase, rep.emitter_denominator.multi_slots_with_statement_name, 1);
verifyEqual(testCase, rep.emitter_denominator.multi_slots_without_statement_name, 0);
end

function testTwoEmittersProducingOneShapeAreSeparateRows(testCase)
% Question 4 is whether a shape is one migrator's habit or a real pattern, so
% two emitters landing on the same shape must NOT be summed into one row.
a = statementWithReferences('vo_a', nClockPair(2, 'k'));
b = statementWithReferences('vo_b', nClockPair(2, 'k'));
% Re-stamp the second statement as if a different pass had written it. Real
% distinct emitter names, both taken from the tree.
bodyB = b{1}.documentProperties;
bodyB.base.name = 'migrated_epoch_extent';
b{1} = did2.document(bodyB);
rep = did2.validate.timeReferenceFamilies([a, b]);
verifyEqual(testCase, numel(rep.shape), 1, 'one shape ...');
verifyEqual(testCase, numel(rep.emitter), 2, '... produced by two emitters');
names = sort({rep.emitter.statement_name});
verifyEqual(testCase, names, {'migrated_epoch_extent', 'migrated_valid_interval'});
end

function testAnUnattributableStatementIsCountedAsSuch(testCase)
% A batch whose documents carry no name must be visibly UNATTRIBUTED, not
% silently attributed to ''.
docs = statementWithReferences('vo_1', splitAnchorPair());
body = docs{1}.documentProperties;
body.base.name = '';
docs{1} = did2.document(body);
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.emitter_denominator.multi_slots_with_statement_name, 0);
verifyEqual(testCase, rep.emitter_denominator.multi_slots_without_statement_name, 1);
end

% ===================== scope and schema-driven discovery ===================

function testTheFamilyIsFoundThroughASubclassReferent(testCase)
% NO NAME MATCHING. `epoch.time_reference_#` declares
% `must_refer_to_document_class: relative_reference` -- a SUBCLASS of
% time_reference -- so a sweep that looked for the referent class literally
% would miss the epoch family entirely.
ep = bodyOf('epoch', 'ep_host');
ep.document_class.superclasses = struct('class_name', {'entity'}, ...
    'class_version', {'1.0.0'});
refs = nClockPair(2, 'e');
deps = struct('name', {}, 'value', {});
for k = 1:numel(refs)
    deps(end+1) = struct('name', sprintf('time_reference_%d', k), ...
        'value', refs{k}.base.id); %#ok<AGROW>
end
ep.depends_on = deps;
docs = {did2.document(ep)};
for k = 1:numel(refs)
    docs{end+1} = did2.document(refs{k}); %#ok<AGROW>
end
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, rep.docs_declaring_family, 1, ...
    'epoch declares the family via a SUBCLASS referent and must be found');
verifyEqual(testCase, rep.statements_multi_reference, 1);
end

function testANonTimeFamilyContributesNothingNotEvenADenominator(testCase)
% `derived_from_#` is N different inputs and is not a time reference. A
% `subject_calculation` DOES declare `time_reference_#` (it is a
% subject_interaction), so the class is in scope -- but its derived_from members
% must not enter any counter. Asserting only "0 shapes" would pass even if they
% had been examined, which is the vacuous half of the assertion.
b = bodyOf('subject_calculation', 'calc_1');
b.document_class.superclasses = struct('class_name', {'subject_interaction'}, ...
    'class_version', {'1.0.0'});
b.depends_on = struct('name', {'derived_from_1', 'derived_from_2'}, ...
    'value', {'src_1', 'src_2'});
src1 = bodyOf('subject', 'src_1');
src2 = bodyOf('subject', 'src_2');
rep = did2.validate.timeReferenceFamilies({did2.document(b), ...
    did2.document(src1), did2.document(src2)});
verifyEqual(testCase, rep.docs_declaring_family, 1, ...
    'subject_calculation is a subject_interaction and declares the time family');
verifyEqual(testCase, rep.slots_examined, 1, 'exactly ONE slot -- the time family');
verifyEqual(testCase, rep.members_examined, 0, ...
    'derived_from_# members must not be counted as time references');
verifyEqual(testCase, rep.statements_with_reference, 0);
end

function testTheDiscriminatorLabelIsReadFromTheSchema(testCase)
% The shape label for the discriminator is the LAST SEGMENT of the family's
% declared `referent_unique_by`, not a word typed into the instrument. Read the
% declaration out of the same cache the instrument uses and assert the key
% follows it, so a schema rename cannot leave a stale label behind.
uniqueBy = declaredUniqueBy('subject_interaction');
assumeNotEmpty(testCase, uniqueBy, ...
    'subject_interaction declares no referent_unique_by in this schema set');
parts = strsplit(uniqueBy, '.');
expected = [parts{end} '='];
docs = statementWithReferences('vo_split', splitAnchorPair());
rep = did2.validate.timeReferenceFamilies(docs);
verifyEqual(testCase, numel(rep.shape), 1);
verifyTrue(testCase, contains(rep.shape(1).shape_key, expected), ...
    sprintf('shape key "%s" must label the discriminator "%s" as declared', ...
        rep.shape(1).shape_key, uniqueBy));
end

function testTheAuditNeverRaises(testCase)
% A report-only census must never be able to break a migration.
verifyWarningFree(testCase, @() did2.validate.timeReferenceFamilies({[]}));
verifyWarningFree(testCase, @() did2.validate.timeReferenceFamilies(struct([])));
verifyWarningFree(testCase, @() did2.validate.timeReferenceFamilies({}));
b = validityObservation('vo_bad', {});
b.depends_on(end+1) = struct('name', 'time_reference_1', 'value', 'nope');
verifyWarningFree(testCase, ...
    @() did2.validate.timeReferenceFamilies({did2.document(b)}));
b2 = bodyOf('a_class_that_does_not_exist', 'x_1');
rep = did2.validate.timeReferenceFamilies({did2.document(b2)});
verifyEqual(testCase, rep.docs_inspected, 1);
verifyGreaterThanOrEqual(testCase, rep.docs_classified, 1);
end

% ===================== fixtures ============================================
%
% EVERY BODY BELOW IS TRACED TO A LIVE EMITTER -- see the file header. Nothing
% here is composed from a V_eta schema or from a docstring.

function docs = statementWithReferences(stmtId, refs)
%STATEMENTWITHREFERENCES A `validity_observation` wired to REFS as
%   `time_reference_1..N`, followed by the reference documents themselves.
%   The numbering is resolveValidIntervals.m:857-860 verbatim: the family is
%   numbered in the order given, and the order is the ONLY thing distinguishing
%   the members -- which is #52.
b = validityObservation(stmtId, refs);
docs = {did2.document(b)};
for k = 1:numel(refs)
    docs{end+1} = did2.document(refs{k}); %#ok<AGROW>
end
end

function b = validityObservation(stmtId, refs)
%VALIDITYOBSERVATION resolveValidIntervals.m:851-871 (makeValidityObservation).
b = bodyOf('validity_observation', stmtId);
b.document_class.superclasses = struct( ...
    'class_name',    {'subject_observation', 'validity'}, ...
    'class_version', {'1.0.0', '1.0.0'});
b.base.name = 'migrated_valid_interval';
deps = struct('name', {'subject_id'}, 'value', {'element_sub_1'});
for k = 1:numel(refs)
    deps(end+1) = struct('name', sprintf('time_reference_%d', k), ...
        'value', refs{k}.base.id); %#ok<AGROW>
end
b.depends_on = deps;
b.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'data validity'), ...
    'storage_mode', 'inline');
b.subject_interaction = struct('method', struct('node', '', 'name', 'curation'));
b.subject_observation = struct();
b.validity = struct('value', struct('value', true));
b.validity_observation = struct('sequence', 1);
end

function refs = splitAnchorPair()
%SPLITANCHORPAIR resolveValidIntervals.m:544-551 -- Decision C's DISAGREEING
%   case. Two `relative_reference` INSTANTS (start, no duration) on the SAME
%   clock, each anchored to a DIFFERENT epoch document. This is the branch the
%   signed model predicts never fires; the pass counts it as
%   `split_anchor_intervals`.
refs = { relativeReference('ref_s0', 'dev_local_time', 'ep_a', 10, []), ...
         relativeReference('ref_s1', 'dev_local_time', 'ep_b', 45, []) };
for k = 1:numel(refs)
    refs{k}.base.name = 'migrated_valid_interval_anchor';
end
end

function refs = nClockPair(n, tag)
%NCLOCKPAIR jEpochClockReferences.m:139-175 -- one `relative_reference` per
%   (clock, interval) pair, ALL anchored to the SAME epoch document, each
%   carrying start AND duration. NDI's `epochtable` is exactly this shape: a
%   cell of clock names with a matching t0_t1 column each.
%
%   TAG NAMESPACES THE DOCUMENT IDS, and it is a required argument rather than a
%   convenience. Two calls that both minted `ref_c1` would put one id on two
%   bodies, and the batch index keeps the first -- so a statement meant to have
%   its anchors OUTSIDE the batch would silently resolve against another
%   statement's anchors, and the not-shapeable path would never be exercised by
%   the test written to exercise it.
clocks = {'dev_local_time', 'utc', 'exp_global_time'};
refs = cell(1, n);
for k = 1:n
    refs{k} = relativeReference(sprintf('ref_%s_c%d', tag, k), clocks{k}, ...
        ['ep_' tag], 0, 30);
    refs{k}.base.name = 'migrated_epoch_extent';
end
end

function r = relativeReference(refId, clockName, anchorId, startSeconds, durationSeconds)
%RELATIVEREFERENCE resolveValidIntervals.m:787-816 (makeReference) and
%   jEpochClockReferences.m:139-175, which build the identical body. An EMPTY
%   DURATIONSECONDS is an INSTANT -- `duration` is not written at all, which is
%   how the split case says "a point, not a span".
r = bodyOf('relative_reference', refId);
r.document_class.class_version = '2.0.0';
r.document_class.superclasses = struct('class_name', {'time_reference'}, ...
    'class_version', {'4.0.0'});
r.depends_on = struct('name', {'relative_to'}, 'value', {anchorId});
value = struct('clock', struct('node', '', 'name', clockName), ...
    'start', durationCell(startSeconds));
if ~isempty(durationSeconds)
    value.duration = durationCell(durationSeconds);
end
r.relative_reference = struct('value', value);
end

function c = durationCell(seconds)
%DURATIONCELL The T14 one-`value` duration cell, resolveValidIntervals.m:782-786.
c = struct('seconds', double(seconds), 'source_unit', 's', ...
    'source_value', double(seconds), 'approximate', false);
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

function uq = declaredUniqueBy(className)
%DECLAREDUNIQUEBY The `referent_unique_by` the SCHEMA declares for the
%   time-reference family of CLASSNAME, read from the same cache the instrument
%   reads. '' when the class or the key is absent.
uq = '';
try
    c = did2.schema.cache.shared().getClass(className);
catch
    return;
end
if ~isfield(c, 'depends_on'); return; end
deps = c.depends_on;
if isstruct(deps)
    items = num2cell(deps(:)');
elseif iscell(deps)
    items = deps(:)';
else
    return;
end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~isfield(d, 'name'); continue; end
    if ~contains(char(d.name), '#'); continue; end
    if isfield(d, 'referent_unique_by') && ~isempty(d.referent_unique_by)
        uq = char(d.referent_unique_by);
        return;
    end
end
end
