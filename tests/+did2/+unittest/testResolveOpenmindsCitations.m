function tests = testResolveOpenmindsCitations
%TESTRESOLVEOPENMINDSCITATIONS did2.convert.resolveOpenmindsCitations and its
%   pass-1 partner did2.convert.migrators_j.openminds -- the openMINDS dataset
%   CITATION graph (TEAM DECISION 2026-08-11, "Do B").
%
%   STATUS: WRITTEN 2026-08-11 in a container with NO MATLAB AND NO OCTAVE.
%   NOT ONE LINE OF THIS FILE HAS BEEN EXECUTED HERE, and neither has the pass
%   it tests. CI is the first execution. Block structure was checked with a
%   bracket-aware token counter validated against known-good files in the same
%   directory; that is a syntax balance check, not a run, and it cannot see a
%   type mismatch -- which is exactly what made two first-run tests of an
%   earlier batch pass red (a uint64 Map.Count assigned into a double field).
%
%   ---------------------------------------------------------------------
%   WHAT THESE TESTS ARE FOR
%   ---------------------------------------------------------------------
%   Four properties, each chosen because a test written from the same premise
%   as the code would NOT catch its failure:
%
%     1. THE ORPHAN GUARD. Consumed `openminds` documents are referenced by
%        others through `openminds_1..n`, so consumption is all-or-none per
%        connected component. The failure to catch is a DANGLING EDGE, so
%        `testTheOrphanGuardWithholdsTheWholeComponent` asserts the sources
%        SURVIVE and `testEveryEdgeResolvesInBothOutcomes` runs the real
%        did2.validate.references over the batch -- the same gate the corpus
%        runs -- rather than trusting a counter this pass computed itself.
%     2. B IS ADDITIVE, SO NOTHING MAY BE FABRICATED. The graph holds only a
%        DOI for a related publication; NDI recovers title/PMID/PMCID over the
%        NETWORK. The failure to catch is a helpfully-invented title, so
%        `testThePublicationCarriesADoiAndNoTitle` asserts the title is EMPTY
%        -- a test that only checked the DOI would pass either way.
%     3. THE SUBJECT BRANCH IS OUT OF SCOPE. The failure to catch is the
%        citation walk quietly swallowing Subject/Species documents that the
%        openminds_subject route and the signed strain decision own. So the
%        test asserts they are still THERE afterwards, by id.
%     4. IDS PRESERVED WHERE THE MODEL ALLOWS. The failure to catch is a fresh
%        id that dangles nothing today and breaks a re-run tomorrow, so the
%        person/funding/publication ids are compared against the SOURCE
%        document ids, not merely against each other.
%     5. MORE THAN ONE COMPONENT IN ONE BATCH (added 2026-08-11, after corpus
%        run 31522068566). Properties 1-3 were each written against a batch
%        holding ONE component, and the pass's per-component loop is where
%        `removeMask`, the org dedup map and the rootless counter interact. So
%        `testEveryRootlessComponentIsCountedNotJustTheFirst` pins the shape JH
%        actually reports (several rootless components, no root anywhere) and
%        `testAStrainFamilyBesideACitationGraphIsNotEatenByIt` pins the mixed
%        batch NO CORPUS CURRENTLY HOLDS -- 0 of 6 carry both stores, so a
%        leak between a consumable and an untouchable component is unmeasured
%        by every corpus gate. The corpora are a sample, not the universe.
%
%   DENOMINATOR. Every test that asserts a zero asserts a non-zero beside it:
%   `openminds_documents_seen`, `components_planned` or `edges_examined`. A
%   pass that silently did nothing must not make an assertion vacuously true.
%
%   Run with:  results = runtests('did2.unittest.testResolveOpenmindsCitations');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the two readings of "nothing happened" ==============

function testAnEmptyBatchRanWithEveryCounterAtZero(testCase)
r = emptyResult();
[out, rep] = did2.convert.resolveOpenmindsCitations(r, ...
    'Validate', false, 'TargetVersion', 'did_v2');
verifyTrue(testCase, rep.ran);
verifyEqual(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, rep.openminds_documents_seen, 0);
verifyEqual(testCase, rep.components_planned, 0);
verifyEqual(testCase, out.migrated, {});
verifyTrue(testCase, out.openminds_citations.ran);
end

function testItRefusesANonVEtaTarget(testCase)
% V_eta is the only migration target; another one is an argument
% error rather than a no-op.
r = emptyResult();
verifyError(testCase, @() did2.convert.resolveOpenmindsCitations(r, ...
    'Validate', false, 'TargetVersion', 'V_none'), 'MATLAB:validators:mustBeMember');
end

function testABatchWithNoOpenmindsDocumentsIsNotTheSameAsNotRunning(testCase)
% A corpus with no openMINDS graph at all -- 5 of the 6 gate corpora at the
% last measurement. `ran` TRUE, a NON-ZERO documents_inspected, and zero
% openminds documents: three facts that together say "looked, found none".
[~, rep] = runPass(testCase, {ontologyLabelDoc('lbl_1', 'nothing_at_all')});
verifyTrue(testCase, rep.ran);
verifyGreaterThan(testCase, rep.documents_inspected, 0);
verifyEqual(testCase, rep.openminds_documents_seen, 0);
verifyEqual(testCase, rep.openminds_components_seen, 0);
verifyEqual(testCase, rep.components_planned, 0);
end

% ===================== the happy path =====================================

function testTheCitationGraphBecomesTheSixEntityClasses(testCase)
% UPDATED for did-schema #88: the six are entity TYPES (dataset, person,
% organization, funding, publication, protocol -- #88 has no web_resource, so
% the documentation link is a protocol entity; the report keeps its counter
% name web_resources_emitted).
[out, rep] = runPass(testCase, citationGraph());
verifyEqual(testCase, rep.openminds_documents_seen, 12, ...
    'the denominator: the fixture graph is twelve openminds documents');
verifyEqual(testCase, rep.openminds_components_seen, 1);
verifyEqual(testCase, rep.dataset_versions_seen, 1);
verifyEqual(testCase, rep.components_planned, 1);
verifyEqual(testCase, rep.components_consumed, 1);
verifyEqual(testCase, rep.components_withheld, 0);
verifyEqual(testCase, rep.components_reverted_on_validation, 0);
verifyEqual(testCase, rep.documents_consumed, 12, ...
    'all twelve are the citation half, so the whole component goes');
verifyEqual(testCase, rep.datasets_emitted, 1);
verifyEqual(testCase, rep.persons_emitted, 1);
verifyEqual(testCase, rep.organizations_emitted, 2, ...
    'the affiliation org and the funder are different organizations');
verifyEqual(testCase, rep.funding_emitted, 1);
verifyEqual(testCase, rep.publications_emitted, 1);
verifyEqual(testCase, rep.web_resources_emitted, 1);
verifyEqual(testCase, rep.relations_emitted, 6);
verifyEqual(testCase, numel(classesOf(out, 'openminds')), 0);
for cls = {'dataset', 'person', 'organization', 'funding', 'publication', ...
        'protocol'}
    verifyGreaterThan(testCase, numel(classesOf(out, cls{1})), 0, ...
        sprintf('no `%s` entity was emitted', cls{1}));
end
end


function testTheFirstAuthorIsOrderZero(testCase)
% Decided by Jess Haley, 2026-10-21 [author order from 0] (did-schema
% V_eta_study_plan.md): "a `has_author` edge's `order` counts from 0 ... the
% first author is `order: 0`". The fixture has one author, so it is 0 (was 1).
[out, ~] = runPass(testCase, citationGraph());
n = 0;
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(b.document_class.class_name, 'directed_relation') ...
            && did2.build.isVocabulary(b.directed_relation.relation, 'relation', 'has_author')
        n = n + 1;
        verifyEqual(testCase, double(b.directed_relation.order), 0);
    end
end
verifyEqual(testCase, n, 1, 'DENOMINATOR: one has_author relation');
end


function testIdsArePreservedOneToOne(testCase)
[out, rep] = runPass(testCase, citationGraph());
verifyEqual(testCase, rep.persons_id_preserved, 1, 'denominator');
verifyEqual(testCase, idsOfClass(out, 'person'), {'om_person'});
verifyEqual(testCase, idsOfClass(out, 'funding'), {'om_funding'});
verifyEqual(testCase, idsOfClass(out, 'publication'), {'om_doi_pub'});
verifyEqual(testCase, idsOfClass(out, 'protocol'), {'om_webres'});   % #88: protocol
verifyEqual(testCase, rep.organizations_id_preserved, 2);
verifyEqual(testCase, sort(idsOfClass(out, 'organization')), ...
    {'om_funder', 'om_org'});
end


function testTheDatasetEntityIsKeyedOnTheDatasetIdNotTheDocumentId(testCase)
% UPDATED for #88: the dataset is an entity (name, description) and its other
% attributes are assertions about it.
[out, ~] = runPass(testCase, citationGraph());
verifyEqual(testCase, idsOfClass(out, 'dataset'), {'ds_01'}, ...
    'the dataset entity must carry the DATASET id, not `om_dsv`');
b = bodyOfClass(out, 'dataset');
verifyEqual(testCase, b.entity.name, 'A Real Dataset');
verifyEqual(testCase, textAbout(out, 'ds_01', 'Abbreviation'), 'ARD');
verifyEqual(testCase, textAbout(out, 'ds_01', 'version number'), '1.0.1');
rd = assertionAbout(out, 'ds_01', 'release date');
verifyEqual(testCase, rd.date.value.instant, '2024-05-05');
end


function testTheRichEntityBeatsABareStubInTheDedupThatRunsNext(testCase)
out = did2.convert.v1_to_v2([citationGraph(), {datasetRemoteDoc()}], ...
    'Validate', false, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
[out, rep] = did2.convert.resolveOpenmindsCitations(out, ...
    'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, rep.components_consumed, 1, 'denominator');
out = did2.convert.resolveDatasetEntities(out, ...
    'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, numel(classesOf(out, 'dataset')), 1);
b = bodyOfClass(out, 'dataset');
verifyEqual(testCase, b.base.id, 'ds_01');
verifyEqual(testCase, b.entity.name, 'A Real Dataset', ...
    'the bare dataset_remote stub won the richness ranking');
end


% ===================== B IS ADDITIVE: nothing is fabricated ===============

function testThePublicationCarriesADoiAndNoTitle(testCase)
% UPDATED for #88: a global identifier is a CURIE string; no name is invented.
[out, ~] = runPass(testCase, citationGraph());
b = bodyOfClass(out, 'publication');
verifyFalse(testCase, isfield(b.entity, 'name') && ~isempty(b.entity.name), ...
    'a title was invented for a graph that does not carry one');
verifyEqual(testCase, cellstr(b.entity.global_identifier), {'doi:10.1234/example.2024'}, ...
    'only the DOI is knowable here -- no PMID, no PMCID');
end


function testTheOrcidPrefixIsStrippedTheWayTheReaderStripsIt(testCase)
% UPDATED for #88: the ORCID is the CURIE `ORCID:<id>` (the https://orcid.org/
% prefix stripped); given name, family name and e-mail are assertions about the
% person.
[out, ~] = runPass(testCase, citationGraph());
b = bodyOfClass(out, 'person');
verifyEqual(testCase, cellstr(b.entity.global_identifier), {'ORCID:0000-0002-1825-0097'});
verifyEqual(testCase, textAbout(out, 'om_person', 'given name'), 'Ada');
verifyEqual(testCase, textAbout(out, 'om_person', 'family name'), 'Lovelace');
verifyEqual(testCase, textAbout(out, 'om_person', 'E-mail Address'), 'ada@example.org', ...
    'the email lives in a SEPARATE ContactInformation document');
end


function testFullDocumentationIsReadInBothOfItsTwoShapes(testCase)
% UPDATED for #88: the documentation link is a protocol entity whose global
% identifier is the URL (IRI shape) or the DOI CURIE (DOI shape).
[outA, repA] = runPass(testCase, citationGraph());          % WebResource / IRI
verifyEqual(testCase, repA.web_resources_from_iri, 1);
verifyEqual(testCase, repA.web_resources_from_doi, 0);
gA = cellstr(bodyOfClass(outA, 'protocol').entity.global_identifier);
verifyEqual(testCase, gA, {'https://example.org/docs'});
[outB, repB] = runPass(testCase, citationGraphDocumentedByDoi());
verifyEqual(testCase, repB.web_resources_from_iri, 0);
verifyEqual(testCase, repB.web_resources_from_doi, 1);
gB = cellstr(bodyOfClass(outB, 'protocol').entity.global_identifier);
verifyEqual(testCase, numel(gB), 1);
verifyTrue(testCase, strcmpi(gB{1}, 'doi:10.5555/docs'));
end


% ===================== out of scope: the subject branch ===================

function testTheSubjectBranchIsLeftExactlyWhereItWas(testCase)
%TESTTHESUBJECTBRANCHISLEFTEXACTLYWHEREITWAS Subject-side openMINDS types are
%   OUT OF SCOPE (they overlap the openminds_subject route and the signed
%   strain decision), and the exclusion is by FIELD NAME -- `studiedSpecimen` is
%   the DatasetVersion's only route into that half of the graph.
%
%   The failure this catches is the citation walk swallowing them, which would
%   look like success in every other counter. So it asserts they are STILL
%   THERE, by id, and that the citation half went anyway.
[out, rep] = runPass(testCase, citationGraphWithSubject());
verifyEqual(testCase, rep.components_consumed, 1, ...
    'the citation half must still be assembled');
verifyEqual(testCase, rep.components_withheld, 0);
survivors = idsOfClass(out, 'openminds');
verifyEqual(testCase, sort(survivors), {'om_species', 'om_subject'}, ...
    'the subject branch was consumed, or something else was left behind');
end

% ===================== THE ORPHAN GUARD ===================================

function testTheOrphanGuardWithholdsTheWholeComponent(testCase)
%TESTTHEORPHANGUARDWITHHOLDSTHEWHOLECOMPONENT The thing most likely to turn a
%   green corpus run red. A SURVIVING document -- here an `ontology_label`,
%   whose only dependency is a `document_id` pointing at whatever it labels --
%   references a planned member. Consuming it would dangle that edge, so the
%   ENTIRE component is withheld: nothing consumed, nothing emitted.
%
%   Withholding is the safe direction and it is not silent: the reason names
%   the component and the id.
[out, rep] = runPass(testCase, ...
    [citationGraph(), {ontologyLabelDoc('lbl_1', 'om_person')}]);
verifyEqual(testCase, rep.openminds_documents_seen, 12, 'denominator');
verifyEqual(testCase, rep.components_planned, 1);
verifyEqual(testCase, rep.components_withheld, 1);
verifyEqual(testCase, rep.components_consumed, 0);
verifyEqual(testCase, rep.documents_consumed, 0);
verifyEqual(testCase, rep.documents_appended, 0);
verifyEqual(testCase, numel(rep.withheld_reasons), 1);
verifyTrue(testCase, ischar(rep.withheld_reasons{1}) ...
    && ~isempty(rep.withheld_reasons{1}), ...
    'a withheld component with no stated reason is a silent refusal');
% NOTHING WAS EMITTED, so nothing points at a document that is not there.
verifyEqual(testCase, numel(classesOf(out, 'dataset')), 0);
verifyEqual(testCase, numel(classesOf(out, 'person')), 0);
% AND EVERY SOURCE SURVIVES -- the corpus is exactly as pass 1 left it.
verifyEqual(testCase, numel(classesOf(out, 'openminds')), 12);
end

function testAComponentWithASecondAffiliationIsWithheldAndCarried(testCase)
% [generic stage is lossless] / [partly placed is carried as v1] (Jess Haley,
% 2026-10-25): an author's second affiliation has no place in the build (it
% used to be dropped and counted in affiliations_beyond_first_dropped), so the
% whole component is withheld: nothing consumed, every openminds document
% left in the batch for the end of ndi.migrate.local to stamp as v1.
bodies = citationGraph();
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, 'om_person')
        bodies{k}.openminds.fields.affiliation = {'ndi://om_affil', 'ndi://om_affil'};
    end
end
[out, rep] = runPass(testCase, bodies);
verifyEqual(testCase, rep.components_planned, 1);
verifyEqual(testCase, rep.components_consumed, 0);
verifyEqual(testCase, rep.components_withheld, 1);
verifyEqual(testCase, rep.components_withheld_unplaced, 1);
verifyEqual(testCase, rep.documents_consumed, 0);
verifyEqual(testCase, rep.affiliations_beyond_first_dropped, 0, 'nothing dropped');
verifyEqual(testCase, numel(classesOf(out, 'openminds')), 12, ...
    'every openminds document is still in the batch');
verifyEqual(testCase, numel(classesOf(out, 'person')), 0, 'no entity emitted');
end

function testEveryEdgeResolvesInBothOutcomes(testCase)
%TESTEVERYEDGERESOLVESINBOTHOUTCOMES The real gate, not a counter this pass
%   computed about itself: did2.validate.references over the whole batch, which
%   is the same instrument the corpus runs. Both the consumed outcome and the
%   withheld one must be orphan-free, because "safe" is not a property of one
%   branch.
consumed = runPass(testCase, citationGraph());
withheld = runPass(testCase, ...
    [citationGraph(), {ontologyLabelDoc('lbl_1', 'om_person')}]);
for r = {consumed, withheld}
    refRep = did2.validate.references(r{1}.migrated, ...
        'KnownIds', did2.unittest.helpers.sessionKnownIds(r{1}.migrated));
    verifyGreaterThan(testCase, refRep.edges_examined, 0, ...
        'zero edges examined would make the zero below meaningless');
    verifyEqual(testCase, refRep.orphan_count, 0, sprintf( ...
        '%d orphan edge(s) of %d examined', refRep.orphan_count, ...
        refRep.edges_examined));
end
end

function testAComponentWithNoDatasetVersionIsLeftAlone(testCase)
%TESTACOMPONENTWITHNODATASETVERSIONISLEFTALONE The Haley strain family reaches
%   the same class from a different writer, and ndi.migrate.internal
%   .strainAssembly owns it. This pass must not touch it, and must SAY it did
%   not -- `components_without_dataset_version` beside a non-zero
%   `openminds_documents_seen` is the difference between "left alone by design"
%   and "skipped by accident".
[out, rep] = runPass(testCase, strainFragmentGraph());
verifyEqual(testCase, rep.openminds_documents_seen, 2, 'denominator');
verifyEqual(testCase, rep.openminds_components_seen, 1);
verifyEqual(testCase, rep.components_without_dataset_version, 1);
verifyEqual(testCase, rep.components_planned, 0);
verifyEqual(testCase, rep.documents_consumed, 0);
verifyEqual(testCase, numel(classesOf(out, 'openminds')), 2);
end

function testEveryRootlessComponentIsCountedNotJustTheFirst(testCase)
%TESTEVERYROOTLESSCOMPONENTISCOUNTEDNOTJUSTTHEFIRST The shape the JH corpus
%   actually presents, which the single-component test above does not reach.
%
%   MEASURED, corpus run 31522068566 (`7ed9cda`), JH's openminds_citations
%   block, quoted from the digest verbatim:
%
%           8  `openminds` documents  <- THE DENOMINATOR
%           2  connected components of them
%           0  DatasetVersion roots seen
%           2  components with NO root (untouched)
%           0  components PLANNED
%
%   SEVERAL disjoint rootless components, because the bare `openminds` class
%   has MORE THAN ONE writer and JH's are not the citation graph at all:
%   +ndi/+setup/+conv/+haley/doImport.m calls openMINDSobj2ndi_document with NO
%   dependency_type -- so docName is 'openminds' -- at :87 for OP50 and at :706
%   for OP50-GFP, i.e. E. coli strains. (What JH's two components are composed
%   of is NOT asserted here; only the counter behaviour is. The composition was
%   not read -- the corpus is not in this repository.)
%
%   THE FAILURE TO CATCH is `components_without_dataset_version` being SET
%   rather than INCREMENTED, or the loop returning at the first rootless
%   component. Either bug leaves a 1 where JH reports a 2, and a rootless
%   component that is never visited is a component whose documents nothing
%   proves survived. So the count is asserted at 2 AND the survivors at 4.
[out, rep] = runPass(testCase, twoRootlessComponents());
verifyEqual(testCase, rep.openminds_documents_seen, 4, 'denominator');
verifyEqual(testCase, rep.openminds_components_seen, 2);
verifyEqual(testCase, rep.dataset_versions_seen, 0);
verifyEqual(testCase, rep.components_without_dataset_version, 2, ...
    'a rootless component after the first was not counted');
verifyEqual(testCase, rep.components_planned, 0);
verifyEqual(testCase, rep.documents_consumed, 0);
verifyEqual(testCase, rep.documents_appended, 0);
verifyEqual(testCase, numel(classesOf(out, 'openminds')), 4, ...
    'a rootless component lost documents');
end

function testAStrainFamilyBesideACitationGraphIsNotEatenByIt(testCase)
% UPDATED for #88: the citation component now appends 21 documents (7 entities
% + 8 assertions + 6 relations).
[out, rep] = runPass(testCase, [citationGraph(), strainFragmentGraph()]);
verifyEqual(testCase, rep.openminds_documents_seen, 14, 'denominator');
verifyEqual(testCase, rep.openminds_components_seen, 2);
verifyEqual(testCase, rep.dataset_versions_seen, 1);
verifyEqual(testCase, rep.components_without_dataset_version, 1);
verifyEqual(testCase, rep.components_planned, 1);
verifyEqual(testCase, rep.components_consumed, 1);
verifyEqual(testCase, rep.documents_consumed, 12, ...
    'the closure reached outside its own component');
verifyEqual(testCase, rep.documents_appended, 21);
verifyEqual(testCase, rep.persons_emitted, 1);
survivors = idsOfClass(out, 'openminds');
verifyEqual(testCase, numel(survivors), 2, ...
    'the strain component did not survive intact');
verifyTrue(testCase, any(strcmp(survivors, 'om_strain')), ...
    'the Strain document was consumed by the citation walk');
verifyTrue(testCase, any(strcmp(survivors, 'om_ecoli')), ...
    'the Species fragment was consumed by the citation walk');
refRep = did2.validate.references(out.migrated, ...
    'KnownIds', did2.unittest.helpers.sessionKnownIds(out.migrated));
verifyGreaterThan(testCase, refRep.edges_examined, 0, 'denominator');
verifyEqual(testCase, refRep.orphan_count, 0, sprintf( ...
    '%d orphan edge(s) of %d examined', refRep.orphan_count, ...
    refRep.edges_examined));
end


% ===================== the pass-1 guarded passthrough =====================

function testTheGuardedPassthroughCarriesTheBodyVerbatim(testCase)
%TESTTHEGUARDEDPASSTHROUGHCARRIESTHEBODYVERBATIM Both batch assemblers depend
%   on pass 1 changing NOTHING -- strainAssembly reads `fields.species`,
%   `fields.backgroundStrain`; this pass reads `fields.author` and the rest. A
%   migrator that reshaped or renamed anything would break both.
in = omDoc('om_person', 'openminds.core.actors.Person', ...
    'https://openminds.om-i.org/types/Person', personFields(), {});
out = did2.convert.migrators_j.openminds(in);
verifyTrue(testCase, iscell(out) && isscalar(out));
verifyEqual(testCase, out{1}, in, 'the body was not carried verbatim');
end

function testABodyWithNoOpenmindsBlockIsRefused(testCase)
verifyError(testCase, ...
    @() did2.convert.migrators_j.openminds(struct('base', struct('id', 'x'))), ...
    'did2:convert:missingBlock');
end

function testAnUnclassifiableOpenmindsBodyIsRefused(testCase)
%TESTANUNCLASSIFIABLEOPENMINDSBODYISREFUSED Neither `matlab_type` nor
%   `openminds_type`: no consumer can tell what the document holds, and
%   schemas/V_eta/stable/openminds.json declares openminds_type mustBeNonEmpty,
%   so the document could not have validated either way. Erroring changes the
%   reason, not the outcome -- which is why this guard costs the 0-quarantine
%   baseline nothing.
b = omDoc('om_x', '', '', struct(), {});
verifyError(testCase, @() did2.convert.migrators_j.openminds(b), ...
    'did2:convert:openmindsUnknownShape');
end

function testAnUnrecognisedTypeIsCarriedRatherThanRefused(testCase)
%TESTANUNRECOGNISEDTYPEISCARRIEDRATHERTHANREFUSED The deliberate departure from
%   the ontology_image pattern. Technique instances are constructed as
%   openminds.controlledterms.<schemaName> with schemaName parsed out of a
%   user-entered string (convertFormDataToDocuments.convertTechnique), so an
%   allow-list cannot be complete and a missing name would be a NEW quarantine
%   against a measured 0-quarantine gate.
b = omDoc('om_t', 'openminds.controlledterms.SomeFutureTechnique', ...
    'https://openminds.om-i.org/types/SomeFutureTechnique', ...
    struct('name', 'a technique nobody has enumerated'), {});
out = did2.convert.migrators_j.openminds(b);
verifyEqual(testCase, out{1}, b);
end

% ===================== against the real schema ============================

function testTheEmittedDocumentsValidateAgainstTheRealVEtaSchema(testCase)
if isempty(getenv('DID_SCHEMA_PATH'))
    assumeFail(testCase, ...
        'DID_SCHEMA_PATH not set; run under the quick gate (assembled V_eta schema).');
end
out = did2.convert.v1_to_v2(citationGraph(), ...
    'Validate', true, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
[out, rep] = did2.convert.resolveOpenmindsCitations(out, ...
    'Validate', true, 'TargetVersion', 'did_v2');
verifyEqual(testCase, rep.components_reverted_on_validation, 0, ...
    'a component reverted: an emitted body does not validate');
verifyEqual(testCase, rep.bodies_quarantined, 0);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, rep.components_consumed, 1);
verifyEqual(testCase, rep.documents_appended, 21, ...
    '7 entities (dataset, person, 2 organizations, funding, publication, protocol) + 8 assertions + 6 relations');
refRep = did2.validate.references(out.migrated, ...
    'KnownIds', did2.unittest.helpers.sessionKnownIds(out.migrated));
verifyGreaterThan(testCase, refRep.edges_examined, 0);
verifyEqual(testCase, refRep.orphan_count, 0, sprintf( ...
    '%d orphan edge(s) of %d examined', refRep.orphan_count, ...
    refRep.edges_examined));
end


% ===================== helpers ============================================

function [out, rep] = runPass(testCase, v1Bodies)
%RUNPASS Pass 1 (validation OFF -- these tests assert the TRANSFORM) then the
%   batch pass. Pass-1 quarantine is asserted empty here rather than left to
%   each test: a batch-pass test that silently ran on an empty batch would pass
%   every assertion about a count being 0.
out = did2.convert.v1_to_v2(v1Bodies, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine, 'pass 1 quarantined a fixture');
[out, rep] = did2.convert.resolveOpenmindsCitations(out, ...
    'Validate', false, 'TargetVersion', 'did_v2');
end

function r = emptyResult()
r = struct('migrated', {{}}, 'quarantine', [], ...
    'summary', struct('total', 0, 'migrated_count', 0, 'quarantine_count', 0));
end

function idx = classesOf(out, className)
% #88: a class name OR a leaf name (`dataset`, `person`, ... are entity types)
idx = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.className(), className) ...
            || strcmp(did2.unittest.helpers.classKey(out.migrated{k}), className)
        idx(end+1) = k; %#ok<AGROW>
    end
end
end


function ids = idsOfClass(out, className)
idx = classesOf(out, className);
ids = cell(1, numel(idx));
for k = 1:numel(idx)
    ids{k} = char(out.migrated{idx(k)}.get('base.id'));
end
end

function b = bodyOfClass(out, className)
idx = classesOf(out, className);
b = struct();
if isempty(idx); return; end
b = out.migrated{idx(1)}.toStruct();
end

% ----- fixture builders ----------------------------------------------------
%
% Built to the shape ndi.database.fun.openMINDSobj2ndi_document actually writes:
% one document per openMINDS object, every child replaced by an `ndi://<id>`
% string in `openminds.fields`, and one `openminds_#` dependency per reference.
% The `fields` keys stay camelCase because universalRenames snake-cases only
% ONE level and `fields` is nested inside the `openminds` block.

function d = omDoc(id, matlabType, omType, fields, refs)
d = struct();
d.document_class = struct('class_name', 'openminds', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
deps = struct('name', {}, 'value', {});
for k = 1:numel(refs)
    deps(end+1) = struct('name', sprintf('openminds_%d', k), ...
        'value', refs{k}); %#ok<AGROW>
end
d.depends_on = deps;
d.base = struct('id', id, 'session_id', 'ds_01', 'name', 'openminds', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
d.openminds = struct('openminds_type', omType, 'matlab_type', matlabType, ...
    'openminds_id', ['https://openminds.om-i.org/instances/' id]);
d.openminds.fields = fields;
end

function f = personFields()
f = struct();
f.givenName = 'Ada';
f.familyName = 'Lovelace';
f.affiliation = {'ndi://om_affil'};
f.digitalIdentifier = {'ndi://om_orcid'};
f.contactInformation = {'ndi://om_contact'};
end

function bodies = citationGraph()
%CITATIONGRAPH Twelve documents: Dataset -> DatasetVersion -> Person (with its
%   Affiliation -> Organization, ORCID and ContactInformation) + Funding (with
%   its funder Organization) + a related-publication DOI + a WebResource + a
%   License. The shape convertFormDataToDocuments produces.
dv = struct();
dv.fullName = 'A Real Dataset';
dv.shortName = 'ARD';
dv.description = 'A dataset with real citation metadata.';
dv.versionIdentifier = '1.0.1';
dv.versionInnovation = 'first public release';
dv.releaseDate = '2024-05-05';
dv.author = {'ndi://om_person'};
dv.funding = {'ndi://om_funding'};
dv.relatedPublication = {'ndi://om_doi_pub'};
dv.fullDocumentation = {'ndi://om_webres'};
dv.license = {'ndi://om_license'};

bodies = { ...
    omDoc('om_dataset', 'openminds.core.products.Dataset', ...
        'https://openminds.om-i.org/types/Dataset', ...
        struct('fullName', 'A Real Dataset'), {'om_dsv'}), ...
    omDoc('om_dsv', 'openminds.core.products.DatasetVersion', ...
        'https://openminds.om-i.org/types/DatasetVersion', dv, ...
        {'om_person', 'om_funding', 'om_doi_pub', 'om_webres', 'om_license'}), ...
    omDoc('om_person', 'openminds.core.actors.Person', ...
        'https://openminds.om-i.org/types/Person', personFields(), ...
        {'om_affil', 'om_orcid', 'om_contact'}), ...
    omDoc('om_affil', 'openminds.core.actors.Affiliation', ...
        'https://openminds.om-i.org/types/Affiliation', ...
        struct('memberOf', {{'ndi://om_org'}}), {'om_org'}), ...
    omDoc('om_org', 'openminds.core.actors.Organization', ...
        'https://openminds.om-i.org/types/Organization', ...
        struct('fullName', 'Brandeis University'), {}), ...
    omDoc('om_orcid', 'openminds.core.digitalIdentifier.ORCID', ...
        'https://openminds.om-i.org/types/ORCID', ...
        struct('identifier', 'https://orcid.org/0000-0002-1825-0097'), {}), ...
    omDoc('om_contact', 'openminds.core.actors.ContactInformation', ...
        'https://openminds.om-i.org/types/ContactInformation', ...
        struct('email', 'ada@example.org'), {}), ...
    omDoc('om_funding', 'openminds.core.actors.Funding', ...
        'https://openminds.om-i.org/types/Funding', ...
        fundingFields(), {'om_funder'}), ...
    omDoc('om_funder', 'openminds.core.actors.Organization', ...
        'https://openminds.om-i.org/types/Organization', ...
        struct('fullName', 'National Institutes of Health'), {}), ...
    omDoc('om_doi_pub', 'openminds.core.digitalIdentifier.DOI', ...
        'https://openminds.om-i.org/types/DOI', ...
        struct('identifier', 'https://doi.org/10.1234/example.2024'), {}), ...
    omDoc('om_webres', 'openminds.core.data.WebResource', ...
        'https://openminds.om-i.org/types/WebResource', ...
        struct('IRI', 'https://example.org/docs'), {}), ...
    omDoc('om_license', 'openminds.core.data.License', ...
        'https://openminds.om-i.org/types/License', ...
        struct('shortName', 'CC-BY-4.0', 'fullName', ...
            'Creative Commons Attribution 4.0'), {})};
end

function f = fundingFields()
f = struct();
f.awardTitle = 'A grant with a name';
f.awardNumber = 'R01-NS-000000';
f.funder = {'ndi://om_funder'};
end

function bodies = citationGraphDocumentedByDoi()
%CITATIONGRAPHDOCUMENTEDBYDOI The other arm of the bimodal field: the writer
%   succeeded in building an openminds.core.DOI, so the document carries
%   `identifier` and no `IRI` -- which NDI's own reader would fail on.
bodies = citationGraph();
for k = 1:numel(bodies)
    if strcmp(bodies{k}.base.id, 'om_webres')
        bodies{k} = omDoc('om_webres', 'openminds.core.digitalIdentifier.DOI', ...
            'https://openminds.om-i.org/types/DOI', ...
            struct('identifier', 'https://doi.org/10.5555/docs'), {});
    end
end
end

function bodies = citationGraphWithSubject()
%CITATIONGRAPHWITHSUBJECT The same graph plus the subject branch the app also
%   writes: DatasetVersion -> studiedSpecimen -> Subject -> species -> Species.
bodies = citationGraph();
for k = 1:numel(bodies)
    if ~strcmp(bodies{k}.base.id, 'om_dsv'); continue; end
    f = bodies{k}.openminds.fields;
    f.studiedSpecimen = {'ndi://om_subject'};
    bodies{k}.openminds.fields = f;
    bodies{k}.depends_on(end+1) = struct('name', 'openminds_6', ...
        'value', 'om_subject');
end
bodies{end+1} = omDoc('om_subject', 'openminds.core.research.Subject', ...
    'https://openminds.om-i.org/types/Subject', ...
    struct('lookupLabel', 'animal_1', 'species', {{'ndi://om_species'}}), ...
    {'om_species'});
bodies{end+1} = omDoc('om_species', 'openminds.controlledterms.Species', ...
    'https://openminds.om-i.org/types/Species', ...
    struct('name', 'Mus musculus', ...
        'preferredOntologyIdentifier', 'NCBITaxon:10090'), {});
end

function bodies = strainFragmentGraph()
%STRAINFRAGMENTGRAPH A Haley strain component: no DatasetVersion anywhere, so
%   this pass must leave it entirely alone for strainAssembly.
bodies = { ...
    omDoc('om_strain', 'openminds.core.research.Strain', ...
        'https://openminds.om-i.org/types/Strain', ...
        struct('name', 'Escherichia coli OP50', ...
            'species', {{'ndi://om_ecoli'}}, ...
            'geneticStrainType', 'wild type'), {'om_ecoli'}), ...
    omDoc('om_ecoli', 'openminds.controlledterms.Species', ...
        'https://openminds.om-i.org/types/Species', ...
        struct('name', 'Escherichia coli', ...
            'preferredOntologyIdentifier', 'NCBITaxon:562'), {})};
end

function bodies = twoRootlessComponents()
%TWOROOTLESSCOMPONENTS Two DISJOINT strain components -- no DatasetVersion in
%   either, and no edge between them, so the partition must find 2.
%
%   The second pair is deliberately given its OWN Species document rather than
%   sharing the first one: sharing would fuse the two into a single component
%   and the test would assert 1 while claiming to test 2. That is the shape
%   error this fixture exists to avoid, so it is stated rather than left to be
%   re-derived. Whether JH's real pair shares a Species is NOT known here --
%   the corpus reports 2 components over 8 documents and this repository does
%   not hold the corpus to check.
bodies = strainFragmentGraph();
bodies{end+1} = omDoc('om_strain_gfp', 'openminds.core.research.Strain', ...
    'https://openminds.om-i.org/types/Strain', ...
    struct('name', 'OP50-GFP', ...
        'species', {{'ndi://om_ecoli_gfp'}}, ...
        'geneticStrainType', 'transgenic'), {'om_ecoli_gfp'});
bodies{end+1} = omDoc('om_ecoli_gfp', 'openminds.controlledterms.Species', ...
    'https://openminds.om-i.org/types/Species', ...
    struct('name', 'Escherichia coli', ...
        'preferredOntologyIdentifier', 'NCBITaxon:562'), {});
end

function d = ontologyLabelDoc(id, targetId)
%ONTOLOGYLABELDOC A surviving referrer of ANY class. `ontology_label`'s only
%   dependency is `document_id`, pointing at whatever document it labels -- so
%   it is the realistic way a non-openminds document comes to reference one,
%   and did2.convert.migrators_j.ontology_label passes it through with that
%   edge intact.
d = struct();
d.document_class = struct('class_name', 'ontology_label', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
d.depends_on = struct('name', {'document_id'}, 'value', {targetId});
d.base = struct('id', id, 'session_id', 'ds_01', 'name', 'label', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
d.ontology_label = struct('ontologyNode', 'UBERON:0000955');
end

function d = datasetRemoteDoc()
%DATASETREMOTEDOC The bare stub the richness ranking must LOSE to.
%   Field names taken from NDI origin/main
%   ndi_common/database_documents/dataset_remote.json -- `dataset_id` and
%   `organization_id`, both empty, which is what makes
%   did2.convert.migrators_j.dataset_remote emit ONLY the bare `dataset`
%   entity (jBareDataset) and nothing else. Both keyed on base.session_id, so
%   the stub and the citation entity collide on ONE id, which is the collision
%   resolveDatasetEntities exists to resolve.
d = struct();
d.document_class = struct('class_name', 'dataset_remote', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
d.depends_on = struct('name', {}, 'value', {});
d.base = struct('id', 'dsr_01', 'session_id', 'ds_01', 'name', 'remote', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
d.dataset_remote = struct('dataset_id', '', 'organization_id', '');
end

function a = assertionAbout(out, entityId, varName)
% #88: the first assertion (as a struct) about entityId whose variable is varName
a = [];
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if ~strcmp(d.className(), 'assertion'); continue; end
    s = d.toStruct();
    e = '';
    for j = 1:numel(s.depends_on)
        if strcmp(s.depends_on(j).name, 'entity_id'); e = s.depends_on(j).document_id; end
    end
    if strcmp(e, entityId) && strcmpi(s.statement.variable.name, varName)
        a = s; return;
    end
end
end


function t = textAbout(out, entityId, varName)
t = '';
a = assertionAbout(out, entityId, varName);
if ~isempty(a); t = char(a.text.value(1).text); end
end
