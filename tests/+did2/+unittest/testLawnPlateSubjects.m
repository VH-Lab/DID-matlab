function tests = testLawnPlateSubjects
%TESTLAWNPLATESUBJECTS did2.convert.resolveLawnPlateSubjects -- the E. coli
%   lawn/plate subject tiers, their `member_of` join, and the
%   (experiment, plate, patch) identifier.
%
%   STATUS: WRITTEN 2026-08-11, NEVER EXECUTED. This container has no MATLAB and
%   no Octave, so not one line of this file has been run. Its assertions were
%   checked by transliterating the code under test into Python and driving it
%   with these same literal fixtures; that is a transliteration, not a run.
%   test-migrators-quick.yml is the first thing with an opinion.
%
%   ---------------------------------------------------------------------
%   WHAT THESE TESTS ARE FOR
%   ---------------------------------------------------------------------
%   Three team decisions of 2026-08-11 (V_eta_OPEN_WORK.md), each with a
%   property that a test written from the same premise as the code would not
%   catch:
%
%     1. TWO TIERS + `member_of`. The failure to catch is an edge that dangles,
%        so `testTheTwoTiersAndTheMemberOfEdge` asserts the edge VALUES resolve
%        to documents that are in the batch, not merely that an edge exists.
%     2. A TIER IS MINTED ONLY WHERE IT HAS MEASUREMENTS. The failure to catch
%        is a subject with nothing attached -- so the tests assert BOTH that no
%        subject was minted AND that the three "why not" states are counted
%        apart from each other. A single `plate_subjects_minted == 0` would pass
%        for a pass that never ran.
%     3. THE IDENTIFIER IS THE (experiment, plate, patch) TRIPLE, and "none
%        should be labeled just patch #". The failure to catch is a REGRESSION
%        to the bare number, so `testNoSubjectAnywhereIsLabelledJustAPatchNumber`
%        sweeps EVERY subject in the batch rather than checking the one the
%        other tests happen to look at.
%
%   DENOMINATOR. Every test that asserts a zero asserts a non-zero beside it
%   first: `rows_seen`, `chains_attempted` or `documents_inspected`, so a pass
%   that silently did nothing cannot make an assertion vacuously true. That is
%   this project's standing rule and it is the reason several of these tests are
%   two lines longer than they look like they need to be.
%
%   Run with:  results = runtests('did2.unittest.testLawnPlateSubjects');

tests = functiontests(localfunctions);
end

% ===================== the foundation: the token rule ======================

function testTheTokenRuleHoldsForEveryCorpusProvenSpelling(testCase)
%TESTTHETOKENRULEHOLDSFOREVERYCORPUSPROVENSPELLING The whole pass rests on one
%   claim: an `ontologyTableRow` `data` key (shortName(term)) and its term LABEL
%   normalise -- lowercase, non-alphanumerics dropped -- to the SAME string.
%
%   That claim cannot be checked directly here: `ndi.ontology.lookup` lives in
%   ndi-ontology-matlab, which is not checked out, so shortName cannot be
%   evaluated. What CAN be checked is every spelling already proven by a
%   corpus-green migrator against its label in +haley/tableDoc_dictionary.json.
%   Five independent pairs, from three different tables. If the rule is wrong,
%   it is wrong here first.
%
%   THIS IS THE TEST THAT MAKES THE OTHERS MEAN SOMETHING. Without it, every
%   fixture below would just be agreeing with the code about a spelling both
%   invented.
pairs = { ...
    'BacterialPatchIdentifier',                   'bacterial patch identifier'
    'BacterialOD600TargetAtSeeding',              'bacterial OD600 (target) at seeding'
    'BacterialPatchCenter_XCoordinate',           'bacterial patch center: X coordinate'
    'BacterialColonyFormingUnitsCFUMeasurement',  'bacterial colony forming units (CFU) measurement'
    'CElegansBehavioralAssay_EncounterIdentifier','C. elegans behavioral assay: encounter identifier'};
verifyEqual(testCase, size(pairs, 1), 5, ...
    'the denominator: five corpus-proven pairs are what this rule rests on');
for k = 1:size(pairs, 1)
    verifyEqual(testCase, normaliseHere(pairs{k, 1}), normaliseHere(pairs{k, 2}), ...
        sprintf('shortName %s and its label do not normalise alike', pairs{k, 1}));
end
% And the rule must not collapse things that are genuinely different, or the
% classifier would match anything.
verifyNotEqual(testCase, normaliseHere('BacterialPatchIdentifier'), ...
    normaliseHere('bacterial plate identifier'));
end

% ===================== the two readings of "nothing happened" ==============

function testAnEmptyBatchRanWithEveryCounterAtZero(testCase)
% "ran and found nothing" must be readable as such, and must NOT print the same
% as "did not run" (the off-target case below).
r = emptyResult();
[out, rep] = did2.convert.resolveLawnPlateSubjects(r, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, rep.lawn_rows_seen, 0);
verifyEqual(testCase, rep.refused_total, 0);
verifyEqual(testCase, out.migrated, {});
verifyTrue(testCase, out.lawn_plate_subjects.ran);
end

function testItIsANoOpOnANonVEtaTarget(testCase)
% `subject` v3.0.0 and the observation leaves exist only in V_eta, and this pass
% is wired into harnesses that also run V_delta/V_zeta. `ran` FALSE with every
% counter 0 is the off-target reading, distinct from the empty-batch one above.
r = emptyResult();
[out, rep] = did2.convert.resolveLawnPlateSubjects(r, ...
    'Validate', false, 'TargetVersion', 'V_zeta');
verifyFalse(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, out.migrated, {});
end

function testNoEcoliTablesIsDistinctFromTablesPresentAndJoinsFailing(testCase)
%TESTNOECOLITABLESISDISTINCTFROMTABLESPRESENTANDJOINSFAILING The team asked for
%   these two states to stay apart, and they are the ones a single "0 subjects
%   minted" would fuse.
%
%   A: a batch of ordinary documents with no lawn/plate table at all.
[~, repA] = runPass(testCase, {celegansBehaviourPlateRow()});
verifyEqual(testCase, repA.ontology_table_rows_seen, 1, ...
    'the denominator: the row WAS inspected');
verifyEqual(testCase, repA.lawn_rows_seen, 0);
verifyEqual(testCase, repA.plate_rows_seen, 0);
verifyEqual(testCase, repA.sessions_with_lawn_plate_tables, 0, ...
    'no table recognised anywhere -> no session is "live" -> did not look here');
verifyEqual(testCase, repA.unclassified_rows_in_those_sessions, 0, ...
    'a row in NO live session is not evidence of a wrong token rule');

%   B: the tables ARE here, and the chain cannot complete because the plate row
%   is missing. Same zero subjects; a completely different report.
[~, repB] = runPass(testCase, {ecoliLawnRow(), ecoliImageRow()});
verifyEqual(testCase, repB.lawn_rows_seen, 1);
verifyEqual(testCase, repB.image_rows_seen, 1);
verifyEqual(testCase, repB.sessions_with_lawn_plate_tables, 1);
verifyEqual(testCase, repB.chains_attempted, 1, ...
    'the denominator: a chain was tried');
verifyEqual(testCase, repB.chains_resolved, 0);
verifyEqual(testCase, repB.refused_no_plate_row, 1);
verifyEqual(testCase, repB.lawn_subjects_minted, 0);
verifyTrue(testCase, repB.refused_total >= 1);
end

% ===================== the decision itself =================================

function testTheTwoTiersAndTheMemberOfEdge(testCase)
%TESTTHETWOTIERSANDTHEMEMBEROFEDGE The happy path, asserted at the edge VALUES.
%
%   Not "a directed_relation exists": that would pass for an edge pointing at
%   nothing, which is a gating orphan and the one outcome this pass may not
%   produce. Both endpoints are resolved back to documents in the batch.
[out, rep] = runPass(testCase, ...
    {ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow()});

verifyEqual(testCase, rep.plate_rows_seen, 1);
verifyEqual(testCase, rep.image_rows_seen, 1);
verifyEqual(testCase, rep.lawn_rows_seen, 1);
verifyEqual(testCase, rep.plate_subjects_minted, 1);
verifyEqual(testCase, rep.lawn_subjects_minted, 1);
verifyEqual(testCase, rep.chains_attempted, 1);
verifyEqual(testCase, rep.chains_resolved, 1);
verifyEqual(testCase, rep.member_of_relations_emitted, 1);
verifyEqual(testCase, rep.withheld_plate_tier_not_minted, 0);
verifyEqual(testCase, rep.withheld_lawn_tier_not_minted, 0);

% the plate carries OD600Real, OD600, CFU and lawnVolume -> four observations;
% the lawn carries radius, circularity and six fluorescence measures -> eight.
verifyEqual(testCase, rep.plate_observations_emitted, 4);
verifyEqual(testCase, rep.lawn_observations_emitted, 8);

rel = firstOfClass(testCase, out, 'directed_relation');
verifyEqual(testCase, rel.directed_relation.relation.name, 'member_of');
verifyEqual(testCase, rel.directed_relation.relation.node, 'RO:0002350');

% THE ASSERTION THAT MATTERS: both ends resolve, and to the RIGHT tiers.
child  = documentById(out, depValue(rel, 'child'));
parent = documentById(out, depValue(rel, 'parent'));
verifyNotEmpty(testCase, child,  'the member end dangles -- a gating orphan');
verifyNotEmpty(testCase, parent, 'the group end dangles -- a gating orphan');
verifyEqual(testCase, child.subject.description,  'bacterial lawn (a bacterial patch)');
verifyEqual(testCase, parent.subject.description, 'bacterial plate (a plate of lawns)');

% every observation points at a subject that is in the batch
obsClasses = {'concentration_observation', 'volume_observation', ...
    'length_observation', 'score_observation', 'intensity_observation'};
nChecked = 0;
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if ~any(strcmp(b.document_class.class_name, obsClasses)); continue; end
    nChecked = nChecked + 1;
    verifyNotEmpty(testCase, documentById(out, depValue(b, 'subject_id')), ...
        'an observation whose subject is not in the batch is an orphan');
end
verifyEqual(testCase, nChecked, 12, ...
    'the denominator: 4 plate + 8 lawn observations were actually examined');
end

function testTheLawnIdentifierIsTheExperimentPlatePatchTriple(testCase)
%TESTTHELAWNIDENTIFIERISTHEEXPERIMENTPLATEPATCHTRIPLE Team directive 2026-08-11:
%   "each experiment #, plate #, and patch # combo should ... dictate the local
%   identifier for all patches."
%
%   Every component comes from a DIFFERENT source row -- patchID from the patch
%   row, plateID from the image row, expID from the plate row -- so this also
%   pins that the two-hop chain, not a guess, produced it.
[out, rep] = runPass(testCase, ...
    {ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow()});
verifyEqual(testCase, rep.lawn_subjects_minted, 1, 'denominator');
lawn = subjectByDescription(testCase, out, 'bacterial lawn (a bacterial patch)');
verifyEqual(testCase, lawn.subject.local_identifier, ...
    'exp/0007/plate/0061/patch/0003');
plate = subjectByDescription(testCase, out, 'bacterial plate (a plate of lawns)');
verifyEqual(testCase, plate.subject.local_identifier, 'exp/0007/plate/0061');
verifyEqual(testCase, rep.local_identifier_collisions_within_batch, 0);
verifyEqual(testCase, rep.local_identifier_fallback_to_document_id, 0);
end

function testALawnIsNotMintedWhenAComponentOfTheTripleCannotBeRead(testCase)
%TESTALAWNISNOTMINTEDWHENACOMPONENTOFTHETRIPLECANNOTBEREAD The directive says
%   derive every component from the source rows and invent none. A subject that
%   cannot be named cannot be minted (`local_identifier` is REQUIRED), so the
%   mint is REFUSED -- not made partial, and not given a bare patch number.
%
%   Here the plate row exists but has lost its `expID` column, which is the ONLY
%   component that is not on the patch or the image row.
plate = ecoliPlateRow();
plate = dropColumn(plate, 'ExperimentSessionIdentifier');
[out, rep] = runPass(testCase, {plate, ecoliImageRow(), ecoliLawnRow()});
verifyEqual(testCase, rep.chains_attempted, 1, 'denominator: the chain was tried');
verifyEqual(testCase, rep.refused_lawn_no_exp_id, 1);
verifyEqual(testCase, rep.lawn_subjects_minted, 0);
verifyEqual(testCase, rep.member_of_relations_emitted, 0);
% and the PLATE tier is refused for the same reason and counted on its own line
verifyEqual(testCase, rep.plate_rows_refused_no_exp_id, 1);
verifyEqual(testCase, rep.plate_subjects_minted, 0);
% NOT SILENT: the row was recognised and measured; only the naming failed.
verifyEqual(testCase, rep.plate_rows_with_measurements, 1);
verifyEqual(testCase, rep.lawn_rows_with_measurements, 1);
verifyEmpty(testCase, subjectsOf(out), 'no subject may be minted unnamed');
end

function testAPlateWithNoMeasurementsMintsNoSubjectAndWithholdsMemberOf(testCase)
%TESTAPLATEWITHNOMEASUREMENTSMINTSNOSUBJECTANDWITHHOLDSMEMBEROF The refinement:
%   "It's only necessary to make all subjects if we take measurements of both".
%
%   The plate row keeps its identity and its timestamps but loses all four
%   typed measures. The LAWN still mints (it has its own measurements and the
%   chain still resolves through the plate ROW for expID), and the `member_of`
%   is withheld because both ends must exist.
plate = ecoliPlateRow();
for name = {'BacterialOD600Measurement', 'BacterialOD600TargetAtSeeding', ...
        'BacterialColonyFormingUnitsCFUMeasurement', 'BacterialPatchVolume'}
    plate = dropColumn(plate, name{1});
end
[out, rep] = runPass(testCase, {plate, ecoliImageRow(), ecoliLawnRow()});
verifyEqual(testCase, rep.plate_rows_seen, 1, 'denominator: the row was seen');
verifyEqual(testCase, rep.plate_rows_with_measurements, 0);
verifyEqual(testCase, rep.plate_rows_with_values_but_none_emittable, 1, ...
    'the timestamps and the strain string are values -- this is not "empty"');
verifyEqual(testCase, rep.plate_rows_with_no_values_at_all, 0);
verifyEqual(testCase, rep.plate_subjects_minted, 0);
verifyEqual(testCase, rep.lawn_subjects_minted, 1);
verifyEqual(testCase, rep.chains_resolved, 1);
verifyEqual(testCase, rep.member_of_relations_emitted, 0, ...
    'both ends must exist -- a one-ended member_of is a gating orphan');
verifyEqual(testCase, rep.withheld_plate_tier_not_minted, 1, ...
    'and WHICH tier was missing is a counter, not a silence');
verifyEmpty(testCase, findClass(out, 'directed_relation'));
end

function testARowWithNoValuesAtAllIsCountedApartFromOneWithUntypableValues(testCase)
%TESTAROWWITHNOVALUESATALLISCOUNTEDAPARTFROMONEWITHUNTYPABLEVALUES The two
%   states the team asked to keep distinct, asserted as two different counters
%   on two different fixtures. Summing them is the failure this pins.
bare = ecoliLawnRow();
for name = {'BacterialPatchRadius', 'BacterialPatchCircularity', ...
        'BacterialPatchBorderPeakFluorescenceIntensity', ...
        'BacterialPatchBorderEdgeFluorescenceIntensity', ...
        'BacterialPatchBorderFluorescenceAmplitude', ...
        'BacterialPatchMeanFluorescenceAmplitude', ...
        'BacterialPatchCenterFluorescenceAmplitude', ...
        'BacterialPatchBorderToCenterFluorescenceRatio'}
    bare = dropColumn(bare, name{1});
end
[~, repBare] = runPass(testCase, {ecoliPlateRow(), ecoliImageRow(), bare});
verifyEqual(testCase, repBare.lawn_rows_seen, 1, 'denominator');
verifyEqual(testCase, repBare.lawn_rows_with_no_values_at_all, 1);
verifyEqual(testCase, repBare.lawn_rows_with_values_but_none_emittable, 0);

% The same row, but carrying a LOGICAL -- a real recorded fact with no typed
% home in this tier. It must not read as "nothing was recorded", and it must not
% become a score of 1 either.
%
% THE LOGICAL GOES IN A MEASURE COLUMN, and that is the whole test. A flag
% parked in a column this tier never looks at would exercise nothing: the value
% has to reach `scalarNumber` for "a logical is not a number" to be under test
% at all. `circularity` is a real column of this table (doImport.m:721) and a
% real double; a logical there is the shape a writer bug would produce.
flagged = addColumn(bare, 'BacterialPatchCircularity', ...
    'bacterial patch circularity', true);
[out, repFlag] = runPass(testCase, {ecoliPlateRow(), ecoliImageRow(), flagged});
verifyEqual(testCase, repFlag.lawn_rows_seen, 1, 'denominator');
verifyEqual(testCase, repFlag.lawn_rows_with_values_but_none_emittable, 1);
verifyEqual(testCase, repFlag.lawn_rows_with_no_values_at_all, 0);
verifyEqual(testCase, repFlag.lawn_subjects_minted, 0);
verifyEqual(testCase, repFlag.lawn_observations_emitted, 0);
verifyEmpty(testCase, findClass(out, 'score_observation'), ...
    'a logical must not be laundered into a numeric observation');
end

% ===================== the join is session-scoped ==========================

function testTheJoinNeverCrossesASessionBoundary(testCase)
%TESTTHEJOINNEVERCROSSESASESSIONBOUNDARY `plateID` COLLIDES across the two Haley
%   sessions -- doImport.m:166 adds `expType*1000`, :729 does not -- and both
%   land in ONE ndi.dataset.dir. An unscoped join would attach the wrong plate
%   and look entirely plausible doing it, which is why this is asserted on the
%   VALUE of the identifier rather than on a count: a count would be identical
%   either way.
otherPlate = ecoliPlateRow();
otherPlate.base.id = 'otr_plate_other';
otherPlate.base.session_id = 'sess_celegans';
otherPlate = setColumn(otherPlate, 'ExperimentSessionIdentifier', '9999');

[out, rep] = runPass(testCase, ...
    {otherPlate, ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow()});
verifyEqual(testCase, rep.plate_rows_seen, 2, 'denominator: both plates seen');
% ASSERTED BEFORE THE HANDLE IS READ, deliberately. An unscoped index would put
% both plates on the key '0061' and the chain would refuse as AMBIGUOUS -- which
% is safe but is a DIFFERENT failure from the one this test is about, and
% without these two lines the test would die dereferencing a subject that was
% never minted instead of saying which thing broke.
verifyEqual(testCase, rep.refused_plate_row_ambiguous, 0);
verifyEqual(testCase, rep.chains_resolved, 1);
verifyEqual(testCase, rep.lawn_subjects_minted, 1);
lawn = subjectByDescription(testCase, out, 'bacterial lawn (a bacterial patch)');
verifyEqual(testCase, lawn.subject.local_identifier, ...
    'exp/0007/plate/0061/patch/0003', ...
    'the other session''s expID 9999 must not reach this lawn');
end

% ===================== the C. elegans relabel ==============================

function testTheCelegansPatchSubjectIsRelabelledToTheTriple(testCase)
%TESTTHECELEGANSPATCHSUBJECTISRELABELLEDTOTHETRIPLE Directive part 2: "None
%   should be labeled just patch #", which reaches the subjects
%   `applyPatchGeometryMap` mints in pass 1.
%
%   That table has no `expID` column (doImport.m:290-292), so pass 1 can only
%   form the PAIR; this pass upgrades it by joining plateID -> the behaviour
%   plate row, which carries expID.
[out, rep] = runPass(testCase, ...
    {celegansPatchGeometryRow(), celegansBehaviourPlateRow()});
verifyEqual(testCase, rep.celegans_patch_subjects_seen, 1, 'denominator');
verifyEqual(testCase, rep.celegans_patch_subjects_relabelled, 1);
verifyEqual(testCase, rep.celegans_patch_subjects_refused_no_exp_id, 0);
verifyEqual(testCase, rep.celegans_patch_subjects_unparseable_handle, 0);

patch = subjectByDescription(testCase, out, 'bacterial patch');
verifyEqual(testCase, patch.subject.local_identifier, ...
    'exp/0001/plate/0017/patch/0017');
% THE ID IS PRESERVED. The encounter table's directed_relation names this
% document as its parent (20,411 of them), so a relabel that re-ided it would
% trade a naming problem for a gating orphan failure.
verifyEqual(testCase, patch.base.id, 'otr_patch');
end

function testTheCelegansPatchKeepsThePairWhenNoExperimentNumberExists(testCase)
%TESTTHECELEGANSPATCHKEEPSTHEPAIRWHENNOEXPERIMENTNUMBEREXISTS With no plate row
%   to join to, the expID cannot be READ and may not be invented. The pair
%   stands -- which still is not "just patch #" -- and the count says so rather
%   than the report reading as if the upgrade had happened.
[out, rep] = runPass(testCase, {celegansPatchGeometryRow()});
verifyEqual(testCase, rep.celegans_patch_subjects_seen, 1, 'denominator');
verifyEqual(testCase, rep.celegans_patch_subjects_relabelled, 0);
verifyEqual(testCase, rep.celegans_patch_subjects_refused_no_exp_id, 1);
patch = subjectByDescription(testCase, out, 'bacterial patch');
verifyEqual(testCase, patch.subject.local_identifier, 'plate/0017/patch/0017');
end

function testNoSubjectAnywhereIsLabelledJustAPatchNumber(testCase)
%TESTNOSUBJECTANYWHEREISLABELLEDJUSTAPATCHNUMBER The directive's own gate, and
%   deliberately the crudest test in the file.
%
%   "None should be labeled just patch #" is a property of the WHOLE batch, so
%   this sweeps every subject rather than the one another test happens to look
%   at -- the shape that would survive someone adding a third mint site later.
%   It runs over the union of both populations (E. coli lawns and plates, and
%   the C. elegans patch), including the case where the expID hop FAILS, because
%   that is where a lazy fallback to the bare number would be written.
batches = { ...
    {ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow()}, ...
    {celegansPatchGeometryRow(), celegansBehaviourPlateRow()}, ...
    {celegansPatchGeometryRow()}, ...
    {ecoliImageRow(), ecoliLawnRow()}};
nSubjects = 0;
for b = 1:numel(batches)
    [out, ~] = runPass(testCase, batches{b});
    subs = subjectsOf(out);
    for k = 1:numel(subs)
        nSubjects = nSubjects + 1;
        handle = subs{k}.subject.local_identifier;
        verifyNotEmpty(testCase, handle, 'local_identifier is REQUIRED');
        verifyEmpty(testCase, regexp(handle, '^\d+$', 'once'), ...
            sprintf(['subject %s is labelled with a bare number -- the ' ...
                     'directive forbids exactly this'], handle));
        verifyEmpty(testCase, regexp(handle, '^patch/', 'once'), ...
            sprintf('subject %s is labelled by patch alone', handle));
    end
end
% THE DENOMINATOR, without which every verify above is vacuously true: three of
% the four batches mint at least one subject.
verifyGreaterThanOrEqual(testCase, nSubjects, 4, ...
    'fewer subjects examined than the fixtures mint -- the sweep is broken');
end

% ===================== the pass touches nothing else =======================

function testTheSourceRowsAreLeftExactlyWhereTheyWere(testCase)
%TESTTHESOURCEROWSARELEFTEXACTLYWHERETHEYWERE This pass is ADDITIVE: nothing is
%   removed, re-ided or re-classed. A dropped column is the one loss no
%   instrument sees -- no empty edge for silentLoss, no scaffolding for
%   isFragment, no vacuous field -- and the source rows are what makes the
%   partial measure enumeration safe.
[out, rep] = runPass(testCase, ...
    {ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow()});
verifyEqual(testCase, rep.source_rows_left_in_place, 3);
rows = findClass(out, 'ontology_table_row');
verifyEqual(testCase, numel(rows), 3, 'a source row was consumed');
ids = sort(cellfun(@(b) b.base.id, rows, 'UniformOutput', false));
verifyEqual(testCase, ids, {'otr_ecoli_image', 'otr_ecoli_lawn', 'otr_ecoli_plate'});
% the strain document-id string is NOT typed by this pass and must therefore
% still be on the row -- constraint 4 says do not mint a strain edge, and a
% dropped column would be worse than an unminted one
plateRow = documentById(out, 'otr_ecoli_plate');
rowData = plateRow.ontology_table_row.data;
verifyEqual(testCase, rowData.BacterialStrainDocumentIdentifier, 'strain_doc_1');
% and nothing minted a strain edge anywhere
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    verifyEmpty(testCase, depValue(b, 'strain_id'), ...
        'constraint 4: no strain edge is minted from a data string');
end
end

% ===================== the spelling canary =================================

function testAColumnResolvesByTermNameWhenTheKeyIsUnrecognisable(testCase)
%TESTACOLUMNRESOLVESBYTERMNAMEWHENTHEKEYISUNRECOGNISABLE The shortName spellings
%   cannot be evaluated in the session that wrote this pass, so the pass matches
%   on the key OR the term name. This drives the second channel: the keys are
%   deliberate nonsense and only `names` carries the truth.
%
%   It also pins that the report SAYS which channel did the work -- a corpus
%   reporting everything resolved by name would mean the shortName rule in the
%   header is wrong, and that has to be visible rather than merely harmless.
lawn = scrambleKeys(ecoliLawnRow());
[~, rep] = runPass(testCase, {ecoliPlateRow(), ecoliImageRow(), lawn});
verifyEqual(testCase, rep.lawn_rows_seen, 1, ...
    'the name channel did not classify the row');
verifyEqual(testCase, rep.lawn_subjects_minted, 1);
verifyGreaterThan(testCase, rep.columns_resolved_by_term_name, 0);
verifyGreaterThan(testCase, rep.columns_resolved_by_key, 0, ...
    'the other two rows still resolve by key');
end

function testAnUnrecognisedRowInALiveSessionIsCountedAsTheCanary(testCase)
%TESTANUNRECOGNISEDROWINALIVESESSIONISCOUNTEDASTHECANARY If the token rule were
%   wrong, this pass would report all zeros and read as "nothing to do". The
%   canary is what separates those: rows recognised in a session, beside rows in
%   the SAME session that matched nothing.
stray = celegansBehaviourPlateRow();
stray.base.id = 'otr_stray';
stray.base.session_id = 'sess_ecoli';   % same session as the E. coli tables
[~, rep] = runPass(testCase, ...
    {ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow(), stray});
verifyEqual(testCase, rep.sessions_with_lawn_plate_tables, 1, 'denominator');
verifyEqual(testCase, rep.unclassified_rows_in_those_sessions, 1);
verifyEqual(testCase, rep.ontology_table_rows_seen, 4);
end

% ===================== against the real schema =============================

function testTheMintedDocumentsValidateAgainstTheRealVEtaSchema(testCase)
%TESTTHEMINTEDDOCUMENTSVALIDATEAGAINSTTHEREALVETASCHEMA The only test here that
%   proves the pass and the schema agree; every other one would pass just as
%   happily against a `member_of` shape the validator rejects. Needs the
%   assembled V_eta set on DID_SCHEMA_PATH, which the quick gate builds.
%
%   THE 0-QUARANTINE GATE IS THE POINT. This pass appends documents to a corpus
%   that is green at 0 quarantined over 627,526; a body it emits that the schema
%   rejects turns that red. Asserting `quarantine` empty here is the cheapest
%   place to find out.
if isempty(getenv('DID_SCHEMA_PATH'))
    assumeFail(testCase, ...
        'DID_SCHEMA_PATH not set; run under the quick gate (assembled V_eta schema).');
end
out = did2.convert.v1_to_v2( ...
    {ecoliPlateRow(), ecoliImageRow(), ecoliLawnRow()}, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
[out, rep] = did2.convert.resolveLawnPlateSubjects(out, ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.subjects_quarantined, 0);
verifyEqual(testCase, rep.statements_quarantined, 0);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, rep.member_of_relations_emitted, 1);
verifyEqual(testCase, rep.documents_appended, 15, ...
    '2 subjects + 12 observations + 1 member_of');
% and the whole batch is reference-clean, which is the gate that actually runs
refRep = did2.validate.references(out.migrated);
verifyEqual(testCase, refRep.orphan_count, 0, ...
    sprintf('%d orphan edge(s) of %d examined', refRep.orphan_count, ...
        refRep.edges_examined));
verifyGreaterThan(testCase, refRep.edges_examined, 0, ...
    'zero edges examined makes the zero above meaningless');
end

% ===================== helpers =============================================

function [out, rep] = runPass(testCase, v1Bodies)
%RUNPASS Pass 1 (validation OFF -- these tests assert the TRANSFORM) then the
%   batch pass. Pass-1 quarantine is asserted empty here rather than left to
%   each test: a batch-pass test that silently ran on an empty batch would pass
%   every assertion about counts being 0.
out = did2.convert.v1_to_v2(v1Bodies, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
[out, rep] = did2.convert.resolveLawnPlateSubjects(out, ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

function r = emptyResult()
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));
end

function out = normaliseHere(s)
%NORMALISEHERE The rule under test, written INDEPENDENTLY of the pass.
%   Deliberately not calling the pass's own normaliser: a test that asks the
%   code to confirm its own rule confirms nothing.
s = lower(char(s));
keep = (s >= 'a' & s <= 'z') | (s >= '0' & s <= '9');
out = s(keep);
end

function subs = subjectsOf(out)
subs = findClass(out, 'subject');
end

function found = findClass(out, className)
found = {};
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(b.document_class.class_name, className)
        found{end+1} = b; %#ok<AGROW>
    end
end
end

function b = firstOfClass(testCase, out, className)
found = findClass(out, className);
if isempty(found)
    assertFail(testCase, sprintf('no %s document in the batch', className));
end
b = found{1};
end

function b = subjectByDescription(testCase, out, description)
subs = findClass(out, 'subject');
b = struct();
for k = 1:numel(subs)
    if strcmp(subs{k}.subject.description, description); b = subs{k}; return; end
end
assertFail(testCase, sprintf('no subject described "%s"', description));
end

function b = documentById(out, id)
b = [];
if isempty(id); return; end
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    if isfield(s, 'base') && isfield(s.base, 'id') && strcmp(s.base.id, id)
        b = s; return;
    end
end
end

function v = depValue(b, name)
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if ~isfield(deps(k), 'name') || ~strcmp(char(deps(k).name), name); continue; end
    for key = {'document_id', 'value', 'id'}
        f = key{1};
        if isfield(deps(k), f) && ~isempty(deps(k).(f)) && ischar(deps(k).(f))
            v = deps(k).(f); return;
        end
    end
end
end

% ---- fixture surgery --------------------------------------------------

function otr = dropColumn(otr, key)
keys  = strsplit(otr.ontology_table_row.variable_names, ',');
names = strsplit(otr.ontology_table_row.names, ',');
nodes = strsplit(otr.ontology_table_row.ontology_nodes, ',');
keep = ~strcmp(keys, key);
otr.ontology_table_row.variable_names = strjoin(keys(keep), ',');
otr.ontology_table_row.names = strjoin(names(keep), ',');
otr.ontology_table_row.ontology_nodes = strjoin(nodes(keep), ',');
if isfield(otr.ontology_table_row.data, key)
    otr.ontology_table_row.data = rmfield(otr.ontology_table_row.data, key);
end
end

function otr = addColumn(otr, key, termName, value)
otr.ontology_table_row.variable_names = ...
    [otr.ontology_table_row.variable_names ',' key];
otr.ontology_table_row.names = [otr.ontology_table_row.names ',' termName];
otr.ontology_table_row.ontology_nodes = ...
    [otr.ontology_table_row.ontology_nodes ',EMPTY:0'];
otr.ontology_table_row.data.(key) = value;
end

function otr = setColumn(otr, key, value)
otr.ontology_table_row.data.(key) = value;
end

function otr = scrambleKeys(otr)
%SCRAMBLEKEYS Replace every `data` key and `variable_names` entry with a name
%   this pass cannot possibly know, leaving `names` (the term names) intact. The
%   row must still classify and still mint -- via the name channel.
keys = strsplit(otr.ontology_table_row.variable_names, ',');
data = struct();
newKeys = cell(size(keys));
for k = 1:numel(keys)
    newKeys{k} = sprintf('opaque%d', k);
    if isfield(otr.ontology_table_row.data, keys{k})
        data.(newKeys{k}) = otr.ontology_table_row.data.(keys{k});
    end
end
otr.ontology_table_row.variable_names = strjoin(newKeys, ',');
otr.ontology_table_row.data = data;
end

% ---- the fixtures ------------------------------------------------------
%
% Built from the WRITER, never from a DID-side schema. Every column name is a
% column NDI actually writes -- +setup/+conv/+haley/doImport.m:714-723 for the
% three E. coli tables, :101-106 for the C. elegans behaviour plate and :290-292
% for the C. elegans patch geometry -- and every `data` KEY is that column's
% dictionary term label rendered as shortName. Those spellings CANNOT be
% evaluated here (`ndi.ontology.lookup` lives in ndi-ontology-matlab, which is
% not checked out), which is why testTheTokenRuleHoldsForEveryCorpusProvenSpelling
% comes first: it is the only thing standing between these fixtures and a
% private agreement between the code and its own test.
%
% Every row carries `depends_on: [{document_id, ''}]`, because that is what the
% WRITER produces: the NDI template declares exactly that one dependency and NOT
% ONE of doImport.m's nine `table2ontologyTableRowDocs` calls passes
% `dependencyVariable` (tableDocMaker.m:227-235), so every row reaches pass 1's
% guarded passthrough exactly as a corpus row does.

function otr = ecoliPlateRow()
%ECOLIPLATEROW doImport.m:714-717 -- all 14 columns of `plateVariables`.
keys = {'ExperimentSessionIdentifier', 'BacterialPlateIdentifier', ...
    'BacterialOD600Label', 'BacterialPlatePeptoneInclusionFlag', ...
    'AgarPlatePouringTimestamp', 'AgarPlateColdStorageTimestamp', ...
    'BacterialStrainDocumentIdentifier', 'BacterialPlateSeedingTimestamp', ...
    'BacterialPlateColdStorageTimestamp', ...
    'BacterialPlateRoomTemperatureTimestamp', ...
    'BacterialOD600Measurement', ...
    'BacterialColonyFormingUnitsCFUMeasurement', ...
    'BacterialOD600TargetAtSeeding', 'BacterialPatchVolume'};
names = {'experiment session identifier', 'bacterial plate identifier', ...
    'bacterial OD600 label', 'bacterial plate peptone inclusion flag', ...
    'agar plate pouring timestamp', 'agar plate cold storage timestamp', ...
    'bacterial strain document identifier', 'bacterial plate seeding timestamp', ...
    'bacterial plate cold storage timestamp', ...
    'bacterial plate room temperature timestamp', ...
    'bacterial OD600 measurement', ...
    'bacterial colony forming units (CFU) measurement', ...
    'bacterial OD600 (target) at seeding', 'bacterial patch volume'};
data = struct();
data.ExperimentSessionIdentifier = '0007';
data.BacterialPlateIdentifier = '0061';
data.BacterialOD600Label = '1.00';
data.BacterialPlatePeptoneInclusionFlag = true;         % logical: not typable
data.AgarPlatePouringTimestamp = '2024-05-01T09:00:00';
data.AgarPlateColdStorageTimestamp = '2024-05-01T13:00:00';
data.BacterialStrainDocumentIdentifier = 'strain_doc_1';  % a STRING, not an edge
data.BacterialPlateSeedingTimestamp = '2024-05-02T09:00:00';
data.BacterialPlateColdStorageTimestamp = '2024-05-02T13:00:00';
data.BacterialPlateRoomTemperatureTimestamp = '2024-05-03T09:00:00';
data.BacterialOD600Measurement = 0.98;
data.BacterialColonyFormingUnitsCFUMeasurement = 1.96e9;
data.BacterialOD600TargetAtSeeding = 1.0;
data.BacterialPatchVolume = 0.5;
otr = tableRowDoc('otr_ecoli_plate', 'sess_ecoli', keys, names, data);
end

function otr = ecoliImageRow()
%ECOLIIMAGEROW doImport.m:718-719 -- all 4 columns of `imageVariables`.
keys = {'BacterialPlateIdentifier', 'MicroscopyImageIdentifier', ...
    'BacteriaGrowthDurationAfterSeeding', 'MicroscopyImageExposureTime'};
names = {'bacterial plate identifier', 'microscopy image identifier', ...
    'bacteria growth duration after seeding', 'microscopy image exposure time'};
data = struct();
data.BacterialPlateIdentifier = '0061';
data.MicroscopyImageIdentifier = '0042';
data.BacteriaGrowthDurationAfterSeeding = 12;
data.MicroscopyImageExposureTime = 0.25;
otr = tableRowDoc('otr_ecoli_image', 'sess_ecoli', keys, names, data);
end

function otr = ecoliLawnRow()
%ECOLILAWNROW doImport.m:720-723 -- all 10 columns of `patchVariables`.
%   NOTE it has NO OD600 column, which is why `isPatchGeometryTable` cannot
%   claim it in pass 1 and it arrives here as a passthrough.
keys = {'MicroscopyImageIdentifier', 'BacterialPatchIdentifier', ...
    'BacterialPatchRadius', 'BacterialPatchCircularity', ...
    'BacterialPatchBorderPeakFluorescenceIntensity', ...
    'BacterialPatchBorderEdgeFluorescenceIntensity', ...
    'BacterialPatchBorderFluorescenceAmplitude', ...
    'BacterialPatchMeanFluorescenceAmplitude', ...
    'BacterialPatchCenterFluorescenceAmplitude', ...
    'BacterialPatchBorderToCenterFluorescenceRatio'};
names = {'microscopy image identifier', 'bacterial patch identifier', ...
    'bacterial patch radius', 'bacterial patch circularity', ...
    'bacterial patch border peak fluorescence intensity', ...
    'bacterial patch border edge fluorescence intensity', ...
    'bacterial patch border fluorescence amplitude', ...
    'bacterial patch mean fluorescence amplitude', ...
    'bacterial patch center fluorescence amplitude', ...
    'bacterial patch border-to-center fluorescence ratio'};
data = struct();
data.MicroscopyImageIdentifier = '0042';
data.BacterialPatchIdentifier = '0003';       % 1:numPatch WITHIN the image
data.BacterialPatchRadius = 28.5125;
data.BacterialPatchCircularity = 0.9848;
data.BacterialPatchBorderPeakFluorescenceIntensity = 1204;
data.BacterialPatchBorderEdgeFluorescenceIntensity = 880;
data.BacterialPatchBorderFluorescenceAmplitude = 324;
data.BacterialPatchMeanFluorescenceAmplitude = 611;
data.BacterialPatchCenterFluorescenceAmplitude = 502;
data.BacterialPatchBorderToCenterFluorescenceRatio = 0.6456;
otr = tableRowDoc('otr_ecoli_lawn', 'sess_ecoli', keys, names, data);
end

function otr = celegansBehaviourPlateRow()
%CELEGANSBEHAVIOURPLATEROW doImport.m:101-106. It carries plateID + expID, so it
%   FEEDS the expID index -- and it must NOT be classified as an E. coli plate:
%   it has no `timePoured`, which is the discriminator, and that table's OD600 +
%   CFU + plateID overlap is the misfire commit 112bcf1 was written for.
keys = {'ExperimentSessionIdentifier', 'CElegansAssayPhase', ...
    'BacterialPlateIdentifier', 'BacterialOD600Label', ...
    'BacterialOD600Measurement', 'BacterialColonyFormingUnitsCFUMeasurement', ...
    'AmbientTemperature', 'AmbientHumidity'};
names = {'experiment session identifier', 'C. elegans assay phase', ...
    'bacterial plate identifier', 'bacterial OD600 label', ...
    'bacterial OD600 measurement', ...
    'bacterial colony forming units (CFU) measurement', ...
    'ambient temperature', 'ambient humidity'};
data = struct();
data.ExperimentSessionIdentifier = '0001';
data.CElegansAssayPhase = 'behavior';
data.BacterialPlateIdentifier = '0017';
data.BacterialOD600Label = '1.00';
data.BacterialOD600Measurement = 0.98;
data.BacterialColonyFormingUnitsCFUMeasurement = 1.96e9;
data.AmbientTemperature = 20;
data.AmbientHumidity = 45;
otr = tableRowDoc('otr_celegans_plate', 'sess_celegans', keys, names, data);
end

function otr = celegansPatchGeometryRow()
%CELEGANSPATCHGEOMETRYROW doImport.m:290-292. Pass 1's `applyPatchGeometryMap`
%   consumes this into a bacterial-patch SUBJECT with the source id preserved;
%   this pass only relabels that subject. Its plateID is '0017', matching the
%   behaviour plate row above so the expID hop has somewhere to land.
keys = {'BacterialPlateIdentifier', 'BacterialPatchIdentifier', ...
    'BacterialOD600TargetAtSeeding', 'BacterialPatchVolume', ...
    'BacterialPatchCenter_XCoordinate', 'BacterialPatchCenter_YCoordinate', ...
    'BacterialPatchRadius', 'BacterialPatchCircularity'};
names = {'bacterial plate identifier', 'bacterial patch identifier', ...
    'bacterial OD600 (target) at seeding', 'bacterial patch volume', ...
    'bacterial patch center: X coordinate', 'bacterial patch center: Y coordinate', ...
    'bacterial patch radius', 'bacterial patch circularity'};
data = struct();
data.BacterialPlateIdentifier = '0017';
data.BacterialPatchIdentifier = '0017';
data.BacterialOD600TargetAtSeeding = 0.05;
data.BacterialPatchVolume = 0.5;
data.BacterialPatchCenter_XCoordinate = 806.3579;
data.BacterialPatchCenter_YCoordinate = 684.8410;
data.BacterialPatchRadius = 28.5125;
data.BacterialPatchCircularity = 0.9848;
otr = tableRowDoc('otr_patch', 'sess_celegans', keys, names, data);
end

function otr = tableRowDoc(docId, sessionId, keys, names, data)
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {'document_id'}, 'value', {''});
otr.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(names, ','), 'ontology_nodes', nodes, 'data', data);
end
