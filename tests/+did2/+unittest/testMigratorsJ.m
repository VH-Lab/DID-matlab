function tests = testMigratorsJ
%TESTMIGRATORSJ Brainstorm-J split/fold migrator tests (TargetVersion 'V_eta').
%
%   Exercises the did_v1 -> V_eta migrators routed by did2.convert.v1_to_v2
%   when TargetVersion == 'V_eta'. Covers:
%     - subject_group      -> bare `subject` (v3.0.0; no is_group/is_biological)
%     - treatment_transfer -> carried whole as v1 ([treatment transfer stays v1])
%                             + session anchor (1 -> 3, D4)
%     - ontology_table_row -> per-column assertions/observations (1 -> N), and
%                             the per-table map for the C. elegans encounter
%                             (worm obs + shared time_reference + patch relation)
%     - treatment          -> temperature_/dose_/term_manipulation by structure,
%                             + a site term_observation for a located site (D3)
%     - treatment_drug     -> dose_manipulation (mixture -> dose composite)
%     - virus_injection    -> dose_manipulation (virus + dilution)
%     - probe_location     -> term_observation about the probe-subject (D5)
%     - ontology_label     -> DEFERRED passthrough (the label value was fine; the
%                             referent was not -- see the migrator header)
%     - image_stack        -> body-backed image_observation + sampled_body (§C.4)
%   D10/D11 are decided (parameters on subject_statement; per-table subject
%   maps; multi-party events bind via a shared time_reference). Tables are moved
%   off the naive per-column seed onto their maps one at a time (see Contents.m).
%
%   Runs with Validate=false so they assert the TRANSFORM (routing + field
%   placement) without a V_eta schema cache at the runner working directory.
%
%   STATUS of the 2026-08-11 ontology_label pair
%   (testOntologyLabelKeepsExactlyTheOneRealEdge,
%   testOntologyLabelDocumentIdSurvivesTheWholePipeline): WRITTEN WITHOUT
%   MATLAB -- there is neither MATLAB nor Octave in the environment they were
%   authored in, and NEITHER TEST HAS BEEN EXECUTED. Their mutation sensitivity
%   was checked by transcribing the three real code paths they depend on
%   (universalRenames.renameDependsOnEntries, the migrator body, the edge
%   reader) and breaking each in turn; that is a transcription, not a run. CI is
%   the gate.
%
%   STATUS of the 2026-08-11 ontology_table_row patch/cultivation set
%   (testCultivationPlateIsNotMigratedAsABacterialPatch,
%   testPatchGeometryCarriesUnenumeratedColumns,
%   testPatchGeometryStillDispatchesOnGeometryEvidence, and the amended document
%   count in testPatchGeometryTableMap): SAME CAVEAT -- WRITTEN WITHOUT MATLAB,
%   NOT EXECUTED. The property they pin (that the C. elegans CULTIVATION-PLATE
%   table and the bacterial-patch GEOMETRY table produce identical answers for
%   all three of the old dispatch clauses) was settled outside MATLAB, from NDI
%   origin/main `+haley/doImport.m` + `+haley/tableDoc_dictionary.json`, with a
%   transliteration of extractColumns/colByKey/isPatchGeometryTable driven by
%   the real column sets of all nine ontologyTableRow-producing tables. CI is
%   the gate.
%
%   STATUS of the 2026-08-11 image_stack `document_id` set
%   (testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot -- which is
%   the INVERSION of testImageStackFoldDropsDocumentIdForWantOfASlot, not a
%   patch of it; testImageStackDocumentIdReferentSurvivesTheBatch, rewritten to
%   grade the REAL emitted edge instead of a synthetic probe;
%   testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank and
%   testImageStackBlankDocumentIdIsOmittedNotCarriedThrough, both new; plus the
%   behaviourImageStack / behaviourPlateRow / babuImageStack fixtures): SAME
%   CAVEAT -- WRITTEN WITHOUT MATLAB. There is neither MATLAB nor Octave in the
%   environment they were authored in and NOTHING IN THIS REPO WAS EXECUTED
%   there. What they assert was settled from NDI origin/main (+haley/doImport.m,
%   +babu/import.m, +NDIMaker/tableDocMaker.m, the ontologyTableRow template),
%   from the did-schema working tree (image_observation's new
%   `ontology_table_row_id` slot, 6cf31f2) and from this repo's own sources and
%   `git log`; the migrator header names each command. Their MUTATION
%   SENSITIVITY was proven on CI, not by transcription --
%   `test-migrators-quick.yml` on a throwaway branch, one mutation per run:
%
%       CONTROL     31463389188  259d4ca  SUCCESS
%       MUTATION A  31463723277  305bf07  carry DELETED    -> 2 FAILED of 885
%                   ...FoldCarriesDocumentIdIntoTheOntologyTableRowSlot
%                   ...DocumentIdReferentSurvivesTheBatch
%       MUTATION B  31463724722  b03a411  carry UNCONDITIONAL (blank edge)
%                                                          -> 2 FAILED of 885
%                   ...BabuShapeOmitsTheSlotRatherThanEmittingItBlank
%                   ...BlankDocumentIdIsOmittedNotCarriedThrough
%
%   TWO mutations, opposite directions, because ONE would not distinguish a
%   test that sees the carry from a test that sees the CONDITION on it.
%   CI is the gate.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJ');

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

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runJUnit(v1)
% a sorted unit (element el_1) whose sorting run labels it a single unit:
% [sorted units are cells or groups] (Jess Haley, 2026-10-26); without a label
% it is carried ([unlabelled units need a map], testRawV1RoundTripElement)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', ...
    'UnitQualityLabels', {'el_1', 'single'});
end

function v = depVal(doc, name)
%DEPVAL Read an edge off a CONVERTED document.
%
%   BOTH SPELLINGS ARE ACCEPTED, and that is a repair rather than a
%   convenience. A did2 edge is `document_id` after universalRenames
%   (universalRenames.m:372-380) and `value` on a raw migrator body, and BOTH
%   reach this helper depending on which document is under test -- the
%   `oneepoch` fold failed twice on exactly this before the tolerant read was
%   used. `+did2/+validate/references.m:176-179` already resolves it the same
%   way and in the same order, so this mirrors the validator rather than
%   inventing a second convention. Reading `.value` alone did not merely miss
%   the edge, it ERRORED on a struct that carries only the other field.
v = '';
deps = doc.get('depends_on');
for k = 1:numel(deps)
    if isfield(deps(k), 'name') && strcmp(deps(k).name, name)
        if isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
            v = deps(k).document_id;
        elseif isfield(deps(k), 'value')
            v = deps(k).value;
        end
        return;
    end
end
end

function names = depNamesOf(doc)
%DEPNAMESOF The `name` of every edge on a CONVERTED document, as a cellstr.
%
%   depVal answers "what is this edge's value" and returns '' for BOTH "the
%   edge is missing" and "the edge is present and empty". Those two are not the
%   same thing: an emitted-but-blank edge is the invented-empty-edge pattern
%   (7,233 documents in the last census, every one of them validating clean
%   because references.m:90 skips empty edges). Any test that has to tell them
%   apart reads the names instead.
names = {};
deps = doc.get('depends_on');
for k = 1:numel(deps)
    if isfield(deps(k), 'name')
        names{end+1} = deps(k).name; %#ok<AGROW>
    end
end
end

% ===================== subject_group -> bare subject ===================

function testSubjectGroupBecomesBareSubject(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'aa_11', 'session_id', 'aa_99', ...
    'name', 'cohortA', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortA', 'description', 'the treated cohort');
out = runJ(v1);

verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
% did-schema #88: a subject_group is an `entity` of type group
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'group');
verifyEqual(testCase, doc.get('document_class.schema_version'), 'did_v2');
verifyEqual(testCase, doc.get('entity.local_identifier'), 'cohortA');
% bare identity: is_group / is_biological must NOT be present in V_eta
sub = doc.get('entity');
verifyFalse(testCase, isfield(sub, 'is_group'));
verifyFalse(testCase, isfield(sub, 'is_biological'));
end

function testSubjectGroupEmptyNameIsCarriedWholeAsV1(testCase)
% INVERTED 2026-10-25 (was testSubjectGroupEmptyNameFallsBackToId: the required
% local_identifier was filled with the document id). [no invented values] /
% [generic stage is lossless] (Jess Haley): the group is carried whole as v1.
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'grp_noname', 'session_id', 'aa_99', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', '', 'description', '');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, out.migrated{1}.className(), 'subject_group');
end

function testSubjectWithNoLocalIdIsCarriedWholeAsV1(testCase)
% INVERTED 2026-10-25 (was testSubjectCarryForwardFillsLocalId: an empty
% local_identifier was filled from the document id). [no invented values] /
% [generic stage is lossless] (Jess Haley): the subject is carried whole as v1.
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'sub_bare', 'session_id', 'sess_09', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', '', 'description', '');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, out.migrated{1}.className(), 'subject');
end

function testSubjectCarryForwardPreservesLocalId(testCase)
% A v1 subject that already has a handle keeps it (fallback only fires when empty).
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'sub_named', 'session_id', 'sess_09', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', 'mouse_42@lab', 'description', '');
out = runJ(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('entity.local_identifier'), 'mouse_42@lab');
end

function testSubjectGroupMintsMemberRelations(testCase)
% A subject_group carrying member links (subject_id_1..N) becomes the bare
% subject PLUS one member_of directed_relation per member (child = member,
% parent = the group), so the membership is preserved rather than dropped.
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id_1', 'subject_id_2', 'subject_id_3'}, ...
    'value', {'m_1', 'm_2', 'm_3'});
v1.base = struct('id', 'grp_1', 'session_id', 'aa_99', ...
    'name', 'cohortB', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortB', 'description', '');
out = runJ(v1);

% 1 subject + 3 member_of relations
verifyEqual(testCase, numel(out.migrated), 4);
sub = firstOfClassJ(out.migrated, 'group');   % #88: an entity of type group
verifyEqual(testCase, sub.get('base.id'), 'grp_1');   % group id preserved
verifyEqual(testCase, out.summary.by_class.directed_relation, 3);
% each relation is member --member_of--> group
children = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation')
        verifyEqual(testCase, did2.build.vocabularyHandle('relation', d.get('directed_relation.relation')), 'member_of');
        verifyEqual(testCase, depVal(d, 'parent_id'), 'grp_1');   % the group
        children{end+1} = depVal(d, 'child_id'); %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(children), {'m_1', 'm_2', 'm_3'});
end

% ============ openminds_subject -> term_assertion (decompose) ==========

function testOpenmindsSubjectBecomesTermAssertion(testCase)
% Brainstorm J does not store the openMINDS bundle: each openMINDS entity about
% a subject (Species / Strain / Sex) decomposes into one term_assertion on that
% subject. The entity type names the variable; the ontology id is the value.
v1 = struct();
v1.document_class = struct('class_name', 'openminds_subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id', 'openminds'}, 'value', {'subj_007', ''});
v1.base = struct('id', 'om_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239', 'synonym', 'C. elegans'));
out = runJ(v1);

verifyEqual(testCase, numel(out.migrated), 1);
a = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(a), 'assertion+term');
% the entity type -> the asserted variable; the ontology id + label -> the value
% the registry label for NCIT:C45293 is 'Species' (#88 writes registry labels)
verifyEqual(testCase, a.get('statement.variable').name, 'Species');
verifyEqual(testCase, a.get('term.value').node, 'NCBITaxon:6239');
verifyEqual(testCase, a.get('term.value').name, 'Caenorhabditis elegans');
verifyEqual(testCase, depVal(a, 'entity_id'), 'subj_007');
% an assertion is timeless: #88 class `assertion`, not an interaction
verifyEqual(testCase, a.get('document_class.class_name'), 'assertion');
end

function testOpenmindsGeneticStrainTypeVariableIsDeCamelCased(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'openminds_subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'om_2', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/GeneticStrainType', ...
    'fields', struct('name', 'knockout', 'ontologyIdentifier', 'X:1'));
out = runJ(v1);
a = out.migrated{1};
verifyEqual(testCase, a.get('statement.variable').name, 'genetic strain type');
verifyEqual(testCase, a.get('term.value').node, 'X:1');
end

function testAnOpenmindsIdThatDoesNotRebuildIsCarried(testCase)
% [openMINDS subject leftovers] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): a controlled term's openminds_id is rebuilt
% from the term through the registry's `equivalent` list, "and a document whose
% id does not rebuild is carried"; a lab-made strain's id belongs on the strain
% entity's global_identifier, which pass 1 does not mint, so it carries too.
% The register rows are carry-116 and carry-117.
v1 = struct();
v1.document_class = struct('class_name', 'openminds_subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'om_3', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'openminds_id', 'https://openminds.om-i.org/instances/species/caenorhabditisElegans', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239'));
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-116] '), d);
lab = v1;
lab.base.id = 'om_4';
lab.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Strain', ...
    'matlab_type', 'openminds.core.research.Strain', ...
    'openminds_id', 'https://openminds.om-i.org/instances/strain/abc123', ...
    'fields', struct('name', 'OP50-GFP'));
out = runJ(lab);
verifyCarriedWholeAsV1(testCase, lab, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-117] '), d);
end

function testAnOpenmindsIdRebuildsThroughTheEquivalentList(testCase)
% the rebuild reads the registry row's `equivalent` list ([term equivalents
% recorded]); a stub registry stands in until did-schema adds the column
reg = struct('terms', {{struct('name', 'Caenorhabditis elegans', 'node', 'NCBITaxon:6239', ...
    'equivalent', {{'openminds:caenorhabditisElegans', 'wikidata:Q91703'}}), ...
    struct('name', 'Mus musculus', 'node', 'NCBITaxon:10090')}});
ix = did2.schema.termIndex(reg);
verifyTrue(testCase, ix.present);
verifyTrue(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:6239', ...
    'https://openminds.om-i.org/instances/species/caenorhabditisElegans', ix));
verifyTrue(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:6239', ...
    'caenorhabditisElegans', ix));
verifyFalse(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:6239', ...
    'https://openminds.om-i.org/instances/species/musMusculus', ix));
verifyFalse(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:10090', ...
    'musMusculus', ix), 'a row with no equivalent list rebuilds nothing');
end

function testAnOpenmindsIriRebuildsThroughItsRegisteredCurie(testCase)
% [term equivalents recorded] (Jess Haley, 2026-10-27): a filled `equivalent`
% list holds CURIEs in a registered prefix and spelling (did-schema
% check_term_registry R13). did-schema's CURIE registry writes the openMINDS
% instance https://openminds.om-i.org/instances/<terminology>/<name> as
% `openminds:<terminology>/<name>`, so v1's IRI id rebuilds through that form
reg = struct('terms', {{struct('name', 'Caenorhabditis elegans', 'node', 'NCBITaxon:6239', ...
    'equivalent', {{'openminds:species/caenorhabditisElegans'}})}});
ix = did2.schema.termIndex(reg);
base = 'https://openminds.om-i.org/instances/';
verifyTrue(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:6239', ...
    'https://openminds.om-i.org/instances/species/caenorhabditisElegans', ix, base));
verifyTrue(testCase, did2.convert.openmindsIdRebuilds('ncbitaxon:6239', ...
    'https://openminds.om-i.org/instances/species/caenorhabditisElegans', ix, base), ...
    'a CURIE''s prefix case is notation');
verifyFalse(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:6239', ...
    'https://openminds.om-i.org/instances/species/musMusculus', ix, base));
verifyFalse(testCase, did2.convert.openmindsIdRebuilds('NCBITaxon:6239', ...
    'https://openminds.ebrains.eu/instances/species/caenorhabditisElegans', ix, base), ...
    'an IRI outside the registered uri_base does not rebuild');
end

% ============ element -> subject (+ kind assertions + lineage) =========

function el = elementDoc(name, typ, ndiClass, direct, subjectId, underlyingId)
el = struct();
el.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
deps = struct('name', {'subject_id'}, 'value', {subjectId});
if ~isempty(underlyingId)
    deps(end+1) = struct('name', 'underlying_element_id', 'value', underlyingId);
end
el.depends_on = deps;
el.base = struct('id', 'el_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
el.element = struct('ndi_element_class', ndiClass, 'name', name, ...
    'reference', '1', 'type', typ, 'direct', direct);
end

function testElementDerivedBecomesSubjectDerivedFrom(testCase)
% A derived element (direct=0 with an underlying element) -> a subject (id
% preserved) + kind assertions (nothing dropped) + a derived_from lineage edge.
%
% 2026-10-21: a derived `spikes` element emits NO observation (a recording is
% one observation per epoch with its files as bodies; the spike train's
% per-epoch body is an open question). From 2026-08-18 it emitted a value-less
% time_observation, refused by rule value_inline_or_body. Every
% assertion below still holds -- the term_assertion count is unchanged at 2,
% because the observation is not an assertion -- so this test keeps passing and
% would keep passing if that emission regressed. It is NOT the gate for it:
% testMigratorsJRecordingObservation.m owns that, and the note is here so the
% next reader does not mistake a green run of this test for coverage of it.
out = runJUnit(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1'));
sub = firstOfClassJ(out.migrated, 'cell');   % #88: a spikes element is an entity of type cell
verifyEqual(testCase, sub.get('base.id'), 'el_1');                 % id preserved
% [element local identifier is name and reference] (Jess Haley, 2026-10-26)
verifyEqual(testCase, sub.get('entity.local_identifier'), 'unit3 | 1');
% type + ndi_element_class preserved as term_assertions (no silent drop)
verifyEqual(testCase, nLeafJ(out.migrated, 'assertion+term'), 2);
% lineage: derived_from the underlying element (safe computational lineage)
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyTrue(testCase, did2.build.isVocabulary(rel.get('directed_relation.relation'), 'relation', 'derived_from'));   % by node (L1)
verifyEqual(testCase, depVal(rel, 'child_id'), 'el_1');
verifyEqual(testCase, depVal(rel, 'parent_id'), 'probe_1');
end

function testElementKeepsTheSortingRunItWasDerivedFrom(testCase)
% [neuron derived from its sorting run] (Jess Haley, 2026-10-25): a sorted
% neuron whose `jrclust_clusters_id` names a JRCLUST run keeps that link as a
% `prov:wasDerivedFrom` relation from the neuron entity to the JRCLUST
% calculation (whose id jrclust_clusters.m keeps), beside its `derived_from`
% the electrode. INVERTS the old behaviour: element.m read only `subject_id`
% and `underlying_element_id`, and the edge was dropped (1,554 Soph and 21
% 20211116 elements, drop census).
v1 = elementDoc('leftcortex_17', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1');
v1.depends_on(end+1) = struct('name', 'jrclust_clusters_id', 'value', 'jrc_run_1');
out = runJUnit(v1);
rels = allOfClassJ(out.migrated, 'directed_relation');
parents = cellfun(@(r) depVal(r, 'parent_id'), rels, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(parents, 'probe_1')), 'the electrode lineage is still there');
ix = find(strcmp(parents, 'jrc_run_1'));
verifyNumElements(testCase, ix, 1, 'the sorting-run edge was dropped');
if isscalar(ix)
    r = rels{ix};
    verifyEqual(testCase, depVal(r, 'child_id'), 'el_1');
    t = r.get('directed_relation.relation');
    verifyEqual(testCase, char(t.node), 'prov:wasDerivedFrom');
    verifyEqual(testCase, char(t.name), 'wasDerivedFrom');
end
end

function testElementWithNoSortingRunEmitsNoSortingRunEdge(testCase)
% the other half: no `jrclust_clusters_id`, so exactly the one lineage edge
out = runJUnit(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1'));
verifyNumElements(testCase, allOfClassJ(out.migrated, 'directed_relation'), 1);
end

function testElementDirectDeviceObservesSpecimen(testCase)
% INVERTED AGAIN 2026-10-21 -- the name is true again. From 2026-08-10 this
% asserted that pass 1 drops the loose `observes` relation because element.m
% emitted the replacement: a session-wide voltage_observation carrying the
% probe as `instrument_id`. Decided by Jess Haley, 2026-10-21 (did-schema
% V_eta_recording_observation_plan.md): a recording is ONE observation per
% element PER EPOCH whose value is that epoch's files (data bodies). An element
% names no epoch and carries no file, so pass 1 emits no observation, and with
% nothing in its place `observes` is KEPT (dropping a link with no replacement
% is loss, not retirement). did2.convert.resolveEpochProbemap retires it when it
% emits the per-epoch observation (testMigratorsJRecordingObservation's
% testObservesRelationIsGoneForAMappedRecordingElement pins that half).
out = runJ(elementDoc('probeA', 'n-trode', 'ndi.probe.timeseries', 1, 'subj_007', ''));

rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyNotEmpty(testCase, rel, 'pass 1 dropped `observes` with nothing in its place');
verifyEqual(testCase, did2.build.vocabularyHandle('relation', rel.get('directed_relation.relation')), 'observes');
verifyEqual(testCase, depVal(rel, 'child_id'), 'el_1');
verifyEqual(testCase, depVal(rel, 'parent_id'), 'subj_007');

verifyEmpty(testCase, firstOfClassJ(out.migrated, 'observation+voltage'), ...
    'pass 1 emitted a recording observation; it is per epoch, minted by the batch pass');

% The element itself is still promoted to a subject with its id PRESERVED --
% ~50 documents reference `element_id`, and moving it is the 11,448-orphan
% shape.
subj = firstOfClassJ(out.migrated, 'device');   % #88: an entity of type device
verifyNotEmpty(testCase, subj, 'the element must still become a subject');
verifyEqual(testCase, subj.get('base.id'), 'el_1');
end

% ============ treatment_transfer -> term_manipulation + relation =======

function v1 = babuTransferV1(id, timestamp)
% A did_v1 treatment_transfer as the Babu importer writes it
% (+setup/+conv/+babu/TreatmentCreator.m: clocktype 'dev_local_time',
% timestamp = seconds(hours(-TransferTime)), a NUMBER of seconds; the
% treatmentMaker sets recipient_id and donor_id).
v1 = struct();
v1.document_class = struct('class_name', 'treatment_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = [ ...
    struct('name', 'recipient_id', 'value', 'worm_1'), ...
    struct('name', 'donor_id',     'value', 'plate_1')];
v1.base = struct('id', id, 'session_id', 'sess_babu', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_transfer = struct('timestamp', timestamp, 'clocktype', 'dev_local_time', ...
    'entity_name', 'Caenorhabditis elegans', 'entity_ontologyNode', 'NCBITaxon:6239', ...
    'method_name', 'pick', 'method_ontologyNode', 'EMPTY:0000001');
end

function testATransferIsCarriedWholeAsV1(testCase)
% [treatment transfer stays v1] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): "a v1 `treatment_transfer` is carried whole
% as v1 with a needs-mapping register row, for the Babu reimport; the generic
% stage converts none". INVERTS the conversion tests that stood here
% (testTransferAnchoredAtItsTimestampOnTheSessionClock,
% testAGlobalClockTransferTimeIsInDays,
% testTransferWithNoTimestampIsDuringTheSession,
% testTreatmentTransferBecomesTermManipulationPlusProvenance) and
% testATransferWithNoClocktypeIsCarried, whose carry now has the one reason.
cases = {babuTransferV1('tt_ts', -72000), babuTransferV1('tt_glob', 739000.5), ...
    babuTransferV1('tt_nots', NaN), babuTransferV1('tt_noclk', -72000)};
cases{2}.treatment_transfer.clocktype = 'exp_global_time';
cases{4}.treatment_transfer.clocktype = '';
for k = 1:numel(cases)
    v1 = cases{k};
    out = runJ(v1);
    verifyCarriedWholeAsV1(testCase, v1, out);
    verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+term'), 0);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-107] needs_mapping: '), d);
end
end

% ============ ontology_table_row -> assertions/observations (1 -> N) ====

function otr = tableRow()
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {'subject_id'}, 'value', {'subj_001'});
otr.base = struct('id', 'otr_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct( ...
    'variable_names', 'BodyWeight,StartleAmplitude,TrialType,SubjectLocalIdentifier', ...
    'names', 'body weight,acoustic startle maximum amplitude,trial type,subject local identifier', ...
    'ontology_nodes', 'EMPTY:1,EMPTY:2,EMPTY:3,EMPTY:4', ...
    'data', struct('BodyWeight', 24.3, 'StartleAmplitude', 38, ...
        'TrialType', 'Startle 95 dB', 'SubjectLocalIdentifier', 'rat_1'));
end

function testAnOntologyTableRowWithASubjectIsCarriedNeedingAMapping(testCase)
% INVERTS testOntologyTableRowSplitsByShape, ...PreservesSourceIdOnFirstBody,
% ...NumericColumn, ...StringColumnIsTermObservation and ...AmplitudeIsIntensity:
% each column's direction and value kind was chosen from words in its label
% ("body weight" -> mass, an unrecognised number -> intensity, a string -> a
% term observation). Decided by Jess Haley, 2026-10-26 [one correct reading],
% [dataset audit batch 1 and 2] (4): the row is carried whole as v1, its note
% naming the V2 homes and what decides between them.
v1 = tableRow();
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'ontology_table_row');
verifyEqual(testCase, out.migrated{1}.get('ontology_table_row.data'), v1.ontology_table_row.data);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-026] needs_mapping: assertion | observation | manipulation'), d);
end

% ===================== treatment -> manipulation leaves ================

function v1 = treatmentDoc(node, name, numeric, stringValue)
v1 = struct();
v1.document_class = struct('class_name', 'treatment', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'tr_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
t = struct('ontology_name', node, 'name', name);
if ~isempty(numeric); t.numeric_value = numeric; end
if nargin >= 4 && ~isempty(stringValue); t.string_value = stringValue; end
v1.treatment = t;
end

function testATreatmentRoutedByLabelWordsIsCarriedNeedingAMapping(testCase)
% INVERTS testTreatmentTemperatureIsTemperatureManipulation,
% testTreatmentProcedureIsTermManipulation and
% testUnlabelledTreatmentNumberOnATermManipulation: a treatment whose reading
% was chosen from words in its label ("cold" -> a temperature in degrees C,
% "craniotomy" -> a term manipulation) is carried whole as v1 with a
% `needs_mapping` note (Decided by Jess Haley, 2026-10-26 [one correct
% reading], [dataset audit batch 1 and 2] (4)).
cases = {treatmentDoc('', 'cold exposure', 4.0, ''), ...
    treatmentDoc('', 'craniotomy', [], ''), ...
    treatmentDoc('', 'craniotomy', 3, ''), ...
    treatmentDoc('NCIT:C1', 'drug injection', [], '')};
for k = 1:numel(cases)
    v1 = cases{k};
    out = runJ(v1);
    verifyCarriedWholeAsV1(testCase, v1, out);
    verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'treatment');
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-022] needs_mapping: manipulation'), d);
    verifyFalse(testCase, isfield(out.summary.migration_notes, 'treatment_number_unlabelled'));
end
end

function testTreatmentSubstanceIsDoseManipulation(testCase)
% (Located at a body site since 2026-10-26: with no location a treatment is
% carried as v1, [one-reading quick answers] (Q1),
% testATreatmentWithNoLocationIsCarried.)
out = runJ(treatmentDoc('CHEBI:5613', 'haloperidol', 2.5, 'uberon:0002436'));
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(m), 'manipulation+dose');
% did-schema #88: the dose names a `formulation` document (formulation_id),
% whose ingredient_id edges name `chemical` documents; the amount rides on the
% formulation's ingredient entry.
fId = depVal(m, 'formulation_id');
verifyNotEmpty(testCase, fId, 'the dose must name its formulation');
f = []; c = [];
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('base.id'), fId); f = d; end
    if strcmp(d.get('document_class.class_name'), 'chemical'); c = d; end
end
verifyNotEmpty(testCase, c, 'no chemical document was emitted');
if ~isempty(c)
    verifyEqual(testCase, c.get('chemical.value').substance.name, 'haloperidol');
end
verifyNotEmpty(testCase, f, 'the formulation the dose names is not in the batch');
verifyEqual(testCase, m.get('statement.variable').node, 'CHEBI:5613');
% No amount recorded: NaN in the dose's volume.
% numeric_value is NEVER an amount -- not the dose's, not the ingredient's
% (Jess Haley, 2026-10-21, "yes"): the term (haloperidol) does not say what
% kind of number 2.5 is, so it is an unlabelled condition, and noted.
verifyTrue(testCase, isnan(m.get('dose.value').volume.liters), ...
    'an unrecorded amount is NaN in the dose''s volume');
if ~isempty(f)
    verifyTrue(testCase, isnan(f.get('formulation.value').ingredients(1).concentration.source_value), ...
        'numeric_value is not the ingredient''s amount');
end
p = m.toStruct();
cnd = p.statement.conditions;
verifyEqual(testCase, cnd.variable.name, regName('numeric value'));
verifyEqual(testCase, cnd.quantity.value, 2.5, 'AbsTol', 1e-12);
verifyFalse(testCase, isfield(cnd, 'unit'), 'an unlabelled number has no unit');
n = out.summary.migration_notes.treatment_number_unlabelled;
verifyEqual(testCase, n.ids, {'tr_01'});
verifyEqual(testCase, n.details, {'haloperidol: 2.5'});
verifyEqual(testCase, routeUnknownCount(out, 'treatment'), 0);
end

function testATreatmentWithNoLocationIsCarried(testCase)
% [one-reading quick answers] (Q1) (Jess Haley, 2026-10-26): a treatment with
% no recorded location is carried as v1 instead of becoming a dose with a NaN
% amount (it was "a dose with NaN ... listed as route unknown", 2026-10-21).
v1 = treatmentDoc('CHEBI:5613', 'haloperidol', 2.5, '');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-023] needs_mapping: manipulation (immersion | dose)'), d);
verifyEqual(testCase, routeUnknownCount(out, 'treatment'), 0);
end

function testVhlabGratingTrainingHoursIsADurationOfTheTerm(testCase)
% NDI origin/main +setup/+conv/+vhlab/treatmentTable.m row 1:
%   {'EMPTY:Treatment: Grating direction-of-motion visual stimulation', "", duration_hours}
% written by treatmentMaker.create_treatment_doc as ontologyName (the looked-up
% id, EMPTY:0000199) + name + numeric_value. The term's definition says the
% number is "provided in hours", so it is a duration (time) of that term, in
% hours (Jess Haley, 2026-10-21, "yes") -- not an amount, not quarantined.
out = runJ(treatmentDoc('EMPTY:0000199', ...
    'treatment: grating direction-of-motion visual stimulation', 6.5, ''));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 2);   % manip + anchor
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(m), 'manipulation+time');
verifyEqual(testCase, m.get('base.id'), 'tr_01');
verifyEqual(testCase, m.get('statement.variable').node, 'EMPTY:0000199');
t = m.get('time.value');
verifyEqual(testCase, t(1).source_value, 6.5);
verifyEqual(testCase, t(1).seconds, 6.5 * 3600, 'AbsTol', 1e-9);
verifyEqual(testCase, t(1).source_unit.name, 'hour');
notes = out.summary.migration_notes;
verifyFalse(testCase, isfield(notes, 'treatment_number_unlabelled'));
verifyFalse(testCase, isfield(notes, 'route_unknown'));
end

function testTreatmentDrugAnchoredAtItsAdministrationOnset(testCase)
% Jess Haley, 2026-10-21 ("a"): a treatment is anchored at the recorded
% administration_onset_time, and at the session only when none is recorded.
% Babu writes the onset as a time of day (+babu/TreatmentCreator.m:70,
% string(..., 'hh:mm:ss')). (On a dose since 2026-10-26: Babu's heat pulse is
% carried as v1, testBabuHeatRowIsCarriedNeedingAMapping.)
v1 = treatmentDrugDoc('td_onset', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'UBERON:0001179', 'peritoneal cavity');
v1.treatment_drug.administration_onset_time = '10:32:00';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(m), 'manipulation+dose');
a = firstOfClassJ(out.migrated, 'absolute_time_reference');
verifyEqual(testCase, a.get('document_class.class_name'), 'absolute_time_reference');
verifyEqual(testCase, a.get('absolute_time_reference.value.start.source_value'), '10:32:00');
verifyEqual(testCase, depVal(m, 'time_reference_id'), a.get('base.id'));
% an ISO-8601 UTC onset on a dose: the instant is normalised; the site
% observation shares the anchor
v1 = treatmentDrugDoc('td_onset_iso', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'UBERON:0001179', 'peritoneal cavity');
v1.treatment_drug.administration_onset_time = '2024-06-01T09:15:00Z';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
a = firstOfClassJ(out.migrated, 'absolute_time_reference');
verifyNotEmpty(testCase, a);
verifyEqual(testCase, a.get('absolute_time_reference.value.start.source_value'), '2024-06-01T09:15:00Z');
verifyNotEmpty(testCase, a.get('absolute_time_reference.value.start.utc'));
verifyEqual(testCase, depVal(d, 'time_reference_id'), a.get('base.id'));
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, depVal(site, 'time_reference_id'), a.get('base.id'));
end

function testTreatmentDrugWithNoOnsetIsAnchoredDuringTheSession(testCase)
% No administration_onset_time (the template blank []): "during the session".
v1 = treatmentDrugDoc('td_no_onset', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'UBERON:0001179', 'peritoneal cavity');
v1.treatment_drug.administration_onset_time = [];
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
a = firstOfClassJ(out.migrated, 'relative_time_reference');
verifyNotEmpty(testCase, a);
verifyEqual(testCase, depVal(d, 'time_reference_id'), a.get('base.id'));
verifyEmpty(testCase, firstOfClassJ(out.migrated, 'absolute_time_reference'));
end

function testTreatmentTargetLocationLabelIsKeptAsTheVariableName(testCase)
% INVERTS testTreatmentTargetLocationLabelIsCarriedWholeAsV1. [one-reading
% quick answers] (Q4) (Jess Haley, 2026-10-26): the name is kept unchanged as
% the variable's name -- the "Target Location" suffix is not stripped -- so the
% row is no longer carried for it.
v1 = treatmentDoc('CHEBI:7035', 'muscimol Target Location', [], 'uberon:0002436');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+dose'), 1);
verifyEqual(testCase, out.migrated{1}.get('statement.variable').name, 'muscimol Target Location');
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, site.get('term.value').node, regNode('uberon:0002436'));
end

function testTreatmentTargetLocationEmitsSiteObservation(testCase)
% Dab "Target Location" idiom: the site rides in string_value; strict J has no
% target_structure, so a located site becomes a term_observation (D3). UPDATED
% 2026-10-25: driven by a label with no " Target Location" suffix (a suffixed
% label is carried as v1, the test above); the CURIE string_value alone still
% routes the site.
out = runJ(treatmentDoc('CHEBI:7035', 'muscimol', [], 'uberon:0002436'));
% #88: dose manip + its chemical + formulation + anchor + site obs
verifyEqual(testCase, numel(out.migrated), 5);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+dose'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+term'), 1);
verifyEqual(testCase, out.migrated{1}.get('statement.variable').name, 'muscimol');
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, did2.unittest.helpers.classKey(site), 'observation+term');
verifyEqual(testCase, site.get('term.value').node, regNode('uberon:0002436'));
% a body site makes it a dose; no amount recorded -> NaN; the route is known
verifyTrue(testCase, isnan(out.migrated{1}.get('dose.value').volume.liters));
% the formulation still carries its ingredient inline (NaN concentration)
fT = doseChainJ(out.migrated, out.migrated{1});
verifyTrue(testCase, isnan(fT.get('formulation.value').ingredients(1).concentration.source_value));
verifyEqual(testCase, routeUnknownCount(out, 'treatment'), 0);
end

% ===================== treatment_drug / virus_injection ================

function testTreatmentDrugBecomesDoseManipulation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'td_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_drug = struct('mixture_table', 'CHEBI:5613,haloperidol,5', ...
    'location_ontologyNode', 'uberon:0002436', 'location_name', 'primary visual cortex');
out = runJ(v1);
% #88: dose + chemical + formulation + site obs + anchor
verifyEqual(testCase, numel(out.migrated), 5);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'manipulation+dose');
% #88 dose chain: dose -> formulation_id -> formulation (ingredient entry carries
% the amount) -> ingredient_id -> chemical (the substance)
[f, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, c.get('chemical.value').substance.name, 'haloperidol');
verifyEqual(testCase, f.get('formulation.value').ingredients(1).concentration.source_value, 5);
verifyEqual(testCase, d.get('statement.variable').name, 'haloperidol');
% a body site (a brain area) -> a dose; the row gives no amount unit -> NaN
verifyTrue(testCase, isnan(d.get('dose.value').volume.liters), ...
    'an unrecorded amount is NaN in the dose''s volume');
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 0);
% the site node survives the universalRenames snake-casing (location_ontologyNode
% -> location_ontology_node)
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, did2.unittest.helpers.classKey(site), 'observation+term');
verifyEqual(testCase, site.get('term.value').node, regNode('uberon:0002436'));
end

function v1 = virusInjectionV1(id, adminDate)
% A did_v1 virus_injection in the shape NDI's writer makes it
% (+setup/+NDIMaker/treatmentMaker.m create_virus_injection_doc: every column
% set, virus_AdministrationDate as char, virus_AdministrationPND as double).
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', id, 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'pAAV-hSyn-hChR2(H134R)-EYFP', ...
    'virusLocation_OntologyName', 'uberon:0002436', 'virusLocation_name', 'V1', ...
    'virus_AdministrationDate', adminDate, 'virus_AdministrationPND', 21, ...
    'dilution', 1000, 'diluent_OntologyName', '', 'diluent_name', '');
end

function testVirusInjectionAnchoredAtItsAdministrationDate(testCase)
% Jess Haley, 2026-10-21 ("a") [virus injection onset]: virus_AdministrationDate
% is the onset, so the dose (and its site observation) is anchored there.
out = runJ(virusInjectionV1('vi_date', '2024-05-02'));
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
a = firstOfClassJ(out.migrated, 'absolute_time_reference');
assertNotEmpty(testCase, a, 'no absolute time reference at the administration date');
verifyEqual(testCase, a.get('absolute_time_reference.value.start.source_value'), '2024-05-02');
verifyEqual(testCase, depVal(d, 'time_reference_id'), a.get('base.id'));
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, depVal(site, 'time_reference_id'), a.get('base.id'));
end

function testVirusInjectionWithNoAdministrationDateIsDuringTheSession(testCase)
% The date blank (the template's ""): "during the session", as before.
out = runJ(virusInjectionV1('vi_nodate', ''));
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
verifyEmpty(testCase, firstOfClassJ(out.migrated, 'absolute_time_reference'));
a = firstOfClassJ(out.migrated, 'relative_time_reference');
assertNotEmpty(testCase, a);
verifyEqual(testCase, depVal(d, 'time_reference_id'), a.get('base.id'));
end

function testVirusInjectionAdministrationDateCamelCaseIsRead(testCase)
% Read as written too (a path that does not snake_case the block).
v1 = virusInjectionV1('vi_camel', '');
v1.virus_injection = rmfield(v1.virus_injection, 'virus_AdministrationDate');
v1.virus_injection.virusAdministrationDate = '2024-05-03';
out = runJ(v1);
a = firstOfClassJ(out.migrated, 'absolute_time_reference');
assertNotEmpty(testCase, a);
verifyEqual(testCase, a.get('absolute_time_reference.value.start.source_value'), '2024-05-03');
end

function testVirusInjectionBecomesDoseManipulation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'vi_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'pAAV-hSyn-hChR2(H134R)-EYFP', 'dilution', 1000, ...
    'virusLocation_OntologyName', 'uberon:0002436', 'virusLocation_name', 'V1');
out = runJ(v1);
% #88: dose + chemical + formulation + site obs + anchor
verifyEqual(testCase, numel(out.migrated), 5);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'manipulation+dose');
[f, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, c.get('chemical.value').substance.name, 'pAAV-hSyn-hChR2(H134R)-EYFP');
conc = f.get('formulation.value').ingredients(1).concentration;
verifyEqual(testCase, conc.source_value, 1000);
verifyEqual(testCase, conc.source_unit.name, 'dilution');
verifyEqual(testCase, d.get('statement.variable').node, 'addgene:26973');
% a body site makes a virus_injection a dose, its volume NaN when unrecorded,
% its dilution staying on the formulation (Jess Haley, 2026-10-21
% [treatment-location], [virus-location])
verifyTrue(testCase, isnan(d.get('dose.value').volume.liters));
verifyEqual(testCase, routeUnknownCount(out, 'virus_injection'), 0);
% site node survives snake-casing (virusLocation_OntologyName -> virus_location_ontology_name)
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, site.get('term.value').node, regNode('uberon:0002436'));
end

function testTreatmentDrugInTheBathIsAnImmersion(testCase)
% Birren writes chronic CNO as a treatment_drug located in the bath
% (+birren/TreatmentCreator.m: location NCIm:C0179246 'bath', mixture_table by
% writetablechar, HEADER row first). "a bath location makes the treatment an
% immersion (a manipulation valued by its formulation through value_id)"
% (Jess Haley, 2026-10-21): no dose, no location observation (the bath is no
% site on the subject), and the Molar row stays the ingredient's concentration.
v1 = treatmentDrugDoc('td_bath', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIm:C0212364,clozapine N-oxide,1e-05,OM:MolarVolumeUnit,Molar'), ...
    'NCIm:C0179246', 'bath');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
% manipulation + chemical + formulation + anchor
verifyEqual(testCase, numel(out.migrated), 4);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+formulation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+dose'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+term'), 0);
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(m), 'manipulation+formulation');
verifyEqual(testCase, m.get('base.id'), 'td_bath');
verifyEmpty(testCase, depVal(m, 'formulation_id'));
formId = depVal(m, 'value_id');
verifyNotEmpty(testCase, formId, 'an immersion takes its value through value_id');
form = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), formId); form = out.migrated{k}; end
end
verifyNotEmpty(testCase, form);
if ~isempty(form)
    verifyEqual(testCase, form.get('document_class.class_name'), 'formulation');
    conc = form.get('formulation.value').ingredients(1).concentration;
    verifyEqual(testCase, conc.source_value, 1e-5, 'AbsTol', 1e-12);
    verifyEqual(testCase, conc.source_unit.name, 'Molar');
end
% the header row is not a chemical
verifyEqual(testCase, m.get('statement.variable').name, 'clozapine N-oxide');
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 0);
end

function testANonUberonLocationIsNotABodySiteAndCarries(testCase)
% [one-reading quick answers] (Q1) (Jess Haley, 2026-10-26): a treatment at a
% non-body location is carried as v1. The body-site test is UBERON ([region
% parts]; the UBERON decision, 2026-10-21 "b"): Hunsberger's
% SNOMED:783351009 "Intraperitoneal" and Babu's agar plate medium are not
% UBERON terms, so neither is placed as a dose.
for loc = {{'SNOMED:783351009', 'Intraperitoneal'}, {'MICRO:0000480', 'agar plate medium'}}
    v1 = treatmentDrugDoc('td_loc', ...
        sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
        loc{1}{1}, loc{1}{2});
    out = runJ(v1);
    verifyCarriedWholeAsV1(testCase, v1, out);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-028] needs_mapping: manipulation (dose | exposure | temperature)'), d);
end
end

function testTreatmentDrugIntraperitonealTakesTheSourcesAmount(testCase)
% (Located at UBERON:0001179 peritoneal cavity since 2026-10-26: the writer's
% SNOMED "Intraperitoneal" is not an UBERON term and carries,
% testANonUberonLocationIsNotABodySiteAndCarries.)
% Hunsberger writes alprazolam as a treatment_drug at Intraperitoneal
% (SNOMED:783351009) with a mixture row `0.25 mg/kg` (SNOMED:396163008)
% (+hunsberger/TreatmentCreator.m). A body site -> a dose "with the source's
% amount when it has one": the mg/kg row is the amount per body mass OF THE
% ALPRAZOLAM, not of the solution (Jess Haley, 2026-10-21 [dose per
% ingredient]): a `value.ingredients` entry with an `ingredient_id` edge to the
% alprazolam chemical, taken off the formulation's ingredient entry (it is not a
% concentration). The whole solution's injected volume is unrecorded: NaN.
v1 = treatmentDrugDoc('td_ip', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
% dose + chemical + formulation + site obs + anchor
verifyEqual(testCase, numel(out.migrated), 5);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'manipulation+dose');
dv = d.get('dose.value');
verifyTrue(testCase, isnan(dv.volume.liters), 'the solution''s volume is unrecorded');
assertEqual(testCase, numel(dv.ingredients), 1, 'one per-ingredient amount');
a = dv.ingredients(1).amount_per_body_mass;
verifyEqual(testCase, a.source_value, 0.25);
verifyEqual(testCase, a.grams_per_gram, 0.25e-6, 'AbsTol', 1e-15);
verifyEqual(testCase, a.source_unit.node, 'SNOMED:396163008');
[f, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, c.get('chemical.value').substance.name, 'alprazolam');
verifyEqual(testCase, depVal(d, 'ingredient_id'), c.get('base.id'), ...
    'the ingredient_id edge names the alprazolam chemical');
% the per-body-mass amount is the dose's, not the ingredient's concentration:
% the ingredient's own amount is unrecorded, NaN (a blank entry would leave the
% formulation's value empty, which value_inline_or_body refuses)
e = f.get('formulation.value').ingredients(1);
verifyTrue(testCase, isnan(e.concentration.source_value));
site = firstOfClassJ(out.migrated, 'observation+term');
verifyEqual(testCase, site.get('term.value').node, 'UBERON:0001179');
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 0);
end

function testSalinePerBodyMassIsAPlaceholderNotAnAmount(testCase)
% Hunsberger's control group is written `saline, 1 mg/kg` (EFO:0002677,
% +hunsberger/TreatmentCreator.m): the drug group's per-body-mass number copied
% onto a vehicle. It is the amount of NO active ingredient (Jess Haley,
% 2026-10-21 [dose per ingredient]), so it is not an ingredient amount and not
% a concentration, and the migration report carries `amount_placeholder`.
% INVERTED 2026-10-25: the dose used to be built with the placeholder written
% nowhere (volume NaN). [generic stage is lossless] (Jess Haley, audit item 6):
% the treatment is carried whole as v1, the placeholder still noted.
v1 = treatmentDrugDoc('td_saline', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nEFO:0002677,saline,1,SNOMED:396163008,mg/kg'), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, out.migrated{1}.className(), 'treatment_drug');
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'amount_placeholder'), 'the placeholder was not reported');
verifyEqual(testCase, notes.amount_placeholder.count, 1);
verifyEqual(testCase, notes.amount_placeholder.ids, {'td_saline'});
verifyEqual(testCase, notes.amount_placeholder.details, {'saline: 1 mg/kg'});
verifyTrue(testCase, contains(notes.carried_as_v1.distinct_details{1}, ...
    'vehicle amount placeholder: saline: 1 mg/kg'));
end

function testEachAmountRowFillsItsOwnDoseSlot(testCase)
% Jess Haley, 2026-10-21 ("a"): when a treatment has more than one amount row,
% EACH amount goes in its matching dose slot -- not only when exactly one row
% exists. INVERTED for the refinement of the same day ("a"): a MASS row that
% NAMES a chemical is that chemical's, so the alprazolam 2 mg goes into its
% `value.ingredients` entry (with an `ingredient_id` edge to it), not the top
% level; the saline 0.5 mL (a volume) stays the top-level amount. Both are taken
% off the formulation's rows (they are amounts, not concentrations); nothing noted.
v1 = treatmentDrugDoc('td_two_kinds', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,2,UO:0000022,mg\n' ...
    'NCIT:C62467,saline,0.5,UO:0000098,mL']), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'manipulation+dose');
v = d.get('dose.value');
verifyFalse(testCase, isfield(v, 'mass') && isstruct(v.mass) && ~isempty(v.mass) ...
    && isfield(v.mass, 'grams') && ~isempty(v.mass.grams), ...
    'a mass row naming a chemical is not the top-level mass');
assertEqual(testCase, numel(v.ingredients), 1);
verifyEqual(testCase, v.ingredients(1).mass.grams, 2e-3, 'AbsTol', 1e-15);
verifyEqual(testCase, v.ingredients(1).mass.source_value, 2);
verifyEqual(testCase, v.volume.liters, 0.5e-3, 'AbsTol', 1e-15);
verifyEqual(testCase, v.volume.source_value, 0.5);
[f, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, depVal(d, 'ingredient_id'), c.get('base.id'), ...
    'the entry is paired with the alprazolam chemical');
ing = f.get('formulation.value').ingredients;
verifyEqual(testCase, numel(ing), 2);
verifyTrue(testCase, all(arrayfun(@(e) isnan(e.concentration.source_value), ing)), ...
    'an amount taken by the dose is not also an ingredient concentration');
verifyFalse(testCase, isfield(out.summary.migration_notes, 'dose_amount_conflict'));
end

function testSubstanceAmountRowFillsSubstanceAmount(testCase)
% A row in a substance-amount unit (mmol) that names a chemical is that
% chemical's substance_amount: its `value.ingredients` entry (Jess Haley,
% 2026-10-21, "a"). INVERTED from the top-level substance_amount.
v1 = treatmentDrugDoc('td_mol', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,3,UO:0000040,mmol']), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
v = out.migrated{1}.get('dose.value');
assertEqual(testCase, numel(v.ingredients), 1);
verifyEqual(testCase, v.ingredients(1).substance_amount.moles, 3e-3, 'AbsTol', 1e-15);
verifyEqual(testCase, v.ingredients(1).substance_amount.source_value, 3);
verifyTrue(testCase, isnan(v.volume.liters), 'the whole formulation''s amount is unrecorded');
end

function testDoseIngredientsAreCheckedAgainstTheirFormulationInBatch(testCase)
% did-schema rule ingredient_in_formulation (Jess Haley, 2026-10-21 [dose per
% ingredient]) needs the formulation, so it runs as a BATCH census
% (did2.validate.doseIngredients -> did2.build.checkDoseIngredients) and counts.
v1 = treatmentDrugDoc('td_ing_chk', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg']), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
rep = did2.validate.doseIngredients(out.migrated);
verifyEqual(testCase, rep.docs_inspected, numel(out.migrated));
verifyEqual(testCase, rep.doses_inspected, 1);
verifyEqual(testCase, rep.doses_with_ingredients, 1);
verifyEqual(testCase, rep.doses_checked, 1);
verifyEqual(testCase, rep.violations, 0, 'the migrated dose names its own ingredient');
% the same batch with the dose pointing at something its formulation lacks
docs = cellfun(@(d) d.toStruct(), out.migrated, 'UniformOutput', false);
dep = docs{1}.depends_on;
k = find(strcmp({dep.name}, 'ingredient_id'), 1);
if isfield(dep, 'value'); dep(k).value = 'not_an_ingredient'; end
if isfield(dep, 'document_id'); dep(k).document_id = 'not_an_ingredient'; end
docs{1}.depends_on = dep;
rep = did2.validate.doseIngredients(docs);
verifyEqual(testCase, rep.doses_checked, 1);
verifyEqual(testCase, rep.violations, 1, 'a foreign ingredient_id is counted');
verifyEqual(testCase, rep.violation_examples(1).id, 'td_ing_chk');
end

function testANamedDrugMassRowIsThatIngredientsMass(testCase)
% Jess Haley, 2026-10-21 ("a"): a mass row naming a drug -> that chemical's
% ingredient entry `.mass`, with an `ingredient_id` edge to its chemical; a
% per-body-mass row on the same chemical merges into the SAME entry.
v1 = treatmentDrugDoc('td_named_mass', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,0.5,UO:0000022,mg']), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
v = d.get('dose.value');
assertEqual(testCase, numel(v.ingredients), 1);
verifyEqual(testCase, v.ingredients(1).mass.grams, 0.5e-3, 'AbsTol', 1e-15);
[~, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, c.get('chemical.value').substance.name, 'alprazolam');
verifyEqual(testCase, depVal(d, 'ingredient_id'), c.get('base.id'));
verifyTrue(testCase, isnan(v.volume.liters));
end

function testTwoDisagreeingRowsOfOneKindAreCarriedWholeAsV1(testCase)
% Two volume rows that disagree. INVERTED 2026-10-25 (was
% testTwoDisagreeingRowsOfOneKindKeepTheFirstAndReportTheRest: the dose kept
% the first and the second was written nowhere). [generic stage is lossless]
% (Jess Haley): the treatment is carried whole as v1; the disagreement is still
% reported (`dose_amount_conflict`).
v1 = treatmentDrugDoc('td_two_vols', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,1,UO:0000098,mL\n' ...
    'NCIT:C62467,saline,2,UO:0000098,mL']), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'dose_amount_conflict'), 'the disagreement was not reported');
n = notes.dose_amount_conflict;
verifyEqual(testCase, n.count, 1);
verifyEqual(testCase, n.ids, {'td_two_vols'});
verifyEqual(testCase, n.by_class.treatment_drug, 1);
verifyEqual(testCase, n.details, {'volume: kept 1 mL, not 2 mL'});
end

function testTwoAgreeingRowsOfOneKindAreNotAConflict(testCase)
% The same amount twice (1 mL and 1000 uL) is one amount: kept once, no note.
v1 = treatmentDrugDoc('td_same_vols', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,1,UO:0000098,mL\n' ...
    'NCIT:C62467,saline,1000,UO:0000101,uL']), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
v = out.migrated{1}.get('dose.value');
verifyEqual(testCase, v.volume.source_value, 1);
verifyFalse(testCase, isfield(out.summary.migration_notes, 'dose_amount_conflict'));
end

function testAStatedAmountKindWithNoNumberPutsTheNaNInThatKind(testCase)
% "...where the kind is known ... the NaN goes in that quantity instead" (Jess
% Haley, 2026-10-21 [unknown-amount-slot]). INVERTED by [blank per-body-mass on
% the ingredient] (Jess Haley, 2026-10-21): a mg/kg row that NAMES a chemical
% but has no number is that CHEMICAL's unrecorded amount -- its
% value.ingredients entry, amount_per_body_mass NaN with the unit, paired with
% an ingredient_id edge -- and the whole formulation's amount stays NaN in
% volume at the top level.
v1 = treatmentDrugDoc('td_kind', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,,SNOMED:396163008,mg/kg'), ...
    'UBERON:0001179', 'peritoneal cavity');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'manipulation+dose');
v = d.get('dose.value');
assertEqual(testCase, numel(v.ingredients), 1);
verifyTrue(testCase, isnan(v.ingredients(1).amount_per_body_mass.grams_per_gram));
verifyEqual(testCase, v.ingredients(1).amount_per_body_mass.source_unit.node, 'SNOMED:396163008');
verifyFalse(testCase, isfield(v, 'amount_per_body_mass') && isstruct(v.amount_per_body_mass) ...
    && ~isempty(v.amount_per_body_mass) && isfield(v.amount_per_body_mass, 'grams_per_gram') ...
    && ~isempty(v.amount_per_body_mass.grams_per_gram), ...
    'the blank per-body-mass is the ingredient''s, not the dose''s top level');
verifyTrue(testCase, isnan(v.volume.liters));
[~, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, depVal(d, 'ingredient_id'), c.get('base.id'));
end

function testTreatmentDrugWithNoLocationIsCarried(testCase)
% INVERTS testTreatmentDrugWithNoLocationIsRouteUnknown: [one-reading quick
% answers] (Q1) (Jess Haley, 2026-10-26) -- no location, carried as v1.
v1 = treatmentDrugDoc('td_none', 'CHEBI:5613,haloperidol,5', '', '');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyTrue(testCase, startsWith(out.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
    '[carry-027] needs_mapping:'));
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 0);
end

function testVirusInjectionAtTheBathIsAnImmersion(testCase)
% INVERTED from testVirusInjectionAtTheBathIsStillADose. Birren records AAV
% DREADDs for cell cultures as virus_injection located in the bath
% (+birren/TreatmentCreator.m, createSayaTreatments.m), with dilution 0, the
% template blank. "virus_injection follows the same location rule as the other
% treatments: a bath location makes it an immersion (a manipulation of the
% subject valued by the virus formulation through value_id, no location
% observation) ... A dilution of 0 is treated as not recorded (NaN), not as a
% measured 0." (Jess Haley, 2026-10-21 [virus-location])
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'vi_bath', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:50474', ...
    'virus_name', 'AAV9-hSyn-hM3D(Gq)-mCherry', 'dilution', 0, ...
    'virusLocation_OntologyName', 'NCIm:C0179246', 'virusLocation_name', 'bath', ...
    'diluent_OntologyName', 'NCIm:C0043047', 'diluent_name', 'Water');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
% manipulation + virus chemical + diluent chemical + formulation + anchor
verifyEqual(testCase, numel(out.migrated), 5);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+formulation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+dose'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+term'), 0);
m = out.migrated{1};
verifyEqual(testCase, m.get('base.id'), 'vi_bath');
verifyEqual(testCase, m.get('statement.variable').node, 'addgene:50474');
formId = depVal(m, 'value_id');
verifyNotEmpty(testCase, formId, 'an immersion takes its value through value_id');
verifyEmpty(testCase, depVal(m, 'formulation_id'));
form = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), formId); form = out.migrated{k}; end
end
verifyNotEmpty(testCase, form);
if ~isempty(form)
    % dilution 0 is not recorded: NaN, and no "dilution" unit is claimed
    conc = form.get('formulation.value').ingredients(1).concentration;
    verifyTrue(testCase, isnan(conc.source_value), 'a dilution of 0 is NaN, not a measured 0');
    verifyFalse(testCase, isfield(conc, 'source_unit') && isstruct(conc.source_unit) ...
        && ~isempty(conc.source_unit) && strcmp(conc.source_unit.name, 'dilution'));
end
verifyEqual(testCase, routeUnknownCount(out, 'virus_injection'), 0);
end

function testVirusInjectionWithNoLocationIsCarried(testCase)
% INVERTS testVirusInjectionWithNoLocationIsRouteUnknown: [one-reading quick
% answers] (Q1) (Jess Haley, 2026-10-26) -- no location, carried as v1.
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'vi_none', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'pAAV-hSyn-hChR2(H134R)-EYFP', 'dilution', 1000);
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, routeUnknownCount(out, 'virus_injection'), 0);
end

function testBabuAgarMediumIsCarriedNeedingAMapping(testCase)
% INVERTS testBabuAgarMediumIsAnExposure: the Babu media routing left the
% generic stage (Decided by Jess Haley, 2026-10-26 [dataset audit batch 1 and
% 2] (2), superseding [babu-media] there; [one correct reading]: "a medium the
% worms live on written as a dose" is never written). A treatment_drug at agar
% plate medium is carried whole as v1, its note naming the V2 homes.
v1 = treatmentDrugDoc('td_agar', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nCHEBI:82021,imazapyr,0.08,OM:MolarVolumeUnit,Molar'), ...
    'MICRO:0000480', 'agar plate medium');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-028] needs_mapping: manipulation (dose | exposure | temperature)'), d);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+dose'), 0);
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 0);
end

function testBabuAmbientAirIsCarriedNeedingAMapping(testCase)
% INVERTS testBabuAmbientAirIsAnExposure (same decision): Babu's odour training
% rows, located in ambient air (XCO:0000918), are carried whole as v1.
v1 = treatmentDrugDoc('td_air', ...
    sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
             'CHEBI:16583,"butane-2,3-dione",1,NCIT:C48571,Percent Volume per Volume\n' ...
             'CHEBI:16236,ethanol,99,NCIT:C48571,Percent Volume per Volume']), ...
    'XCO:0000918', 'ambient air');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-028] needs_mapping:'), d);
end

function testBabuHeatRowIsCarriedNeedingAMapping(testCase)
% INVERTS testBabuHeatRowIsATemperatureManipulation (same decision): Babu's
% heat pulse (one mixture row OM:Heat, 37 Degree Celsius) is carried whole as
% v1, its note naming a temperature manipulation as a V2 home.
v1 = treatmentDrugDoc('td_heat', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nOM:Heat,heat,37,NCIT:C42559,Degree Celsius'), ...
    'MICRO:0000480', 'agar plate medium');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-028] needs_mapping: manipulation (dose | exposure | temperature)'), d);
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+temperature'), 0);
end

function v1 = treatmentDrugDoc(id, mixtureTable, locNode, locName)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', id, 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_drug = struct('mixture_table', mixtureTable, ...
    'location_ontologyNode', locNode, 'location_name', locName);
end

function n = routeUnknownCount(out, className)
% did2.convert.reportNote's `route_unknown` count for one source class.
n = 0;
if ~isfield(out.summary, 'migration_notes'); n = -1; return; end
notes = out.summary.migration_notes;
if isfield(notes, 'route_unknown') && isfield(notes.route_unknown.by_class, className)
    n = notes.route_unknown.by_class.(className);
end
end

% ===================== probe_location / ontology_label =================

function testProbeLocationBecomesTermObservation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'probe_location', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_42'});
v1.base = struct('id', 'pl_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_location = struct('ontology_name', 'uberon:0002436', 'name', 'primary visual cortex');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % obs + anchor
o = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(o), 'observation+term');
verifyEqual(testCase, o.get('term.value').node, regNode('uberon:0002436'));
% variable "anatomical location" is NCIT:C13717 "Anatomic Site" (Jess Haley,
% 2026-10-21 [anatomy variable terms])
verifyEqual(testCase, o.get('statement.variable').node, 'NCIT:C13717');
verifyEqual(testCase, o.get('statement.variable').name, 'Anatomic Site');
% the probe is the subject (device-as-subject, D2)
verifyEqual(testCase, depVal(o, 'entity_id'), 'probe_42');
end

function v1 = ontologyLabelBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/data/
% ontologyLabel.json), not from our schema. ONE property field, ONE dependency.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_label', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'document_id'}, 'value', {'imstack_9'});
v1.base = struct('id', 'ol_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
% ontologyNode, snake_cased by universalRenames
v1.ontology_label = struct('ontology_node', 'uberon:3373');
end

function testOntologyLabelDefersToSecondPass(testCase)
% The label value was never the problem -- the REFERENT was. The real class has
% one dependency, `document_id`, pointing at the document being labelled (an
% image stack, typically), and the old migrator asked for element_id/subject_id/
% probe_id instead. jStartInteraction ASSIGNS depends_on rather than extending
% it, so every real document came out with an EMPTY subject_id and the
% document_id edge DISCARDED: the term survived, what it was about did not.
% Reaching the subject means following document_id through the migrated-id
% graph, so the document is carried through intact for the second pass.
out = did2.convert.migrators_j.ontology_label(ontologyLabelBody());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'ontology_label');
verifyEqual(testCase, out{1}.ontology_label.ontology_node, 'uberon:3373');
% the link to the labelled document is kept, and no husk observation is minted
verifyEqual(testCase, depValue(out{1}, 'document_id'), 'imstack_9');
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testOntologyLabelKeepsExactlyTheOneRealEdge(testCase)
% THE OTHER HALF OF THE OLD BUG, asserted directly rather than by proxy.
%
% `testOntologyLabelDefersToSecondPass` above checks that `document_id` is
% PRESENT. That alone does not catch the regression that actually happened: the
% pre-fix body ASSIGNED `body.depends_on = jCarrySubject(...)`
% (+migrators_j/private/jStartInteraction.m:38), which both discarded
% `document_id` AND minted a `subject_id` entry whose value was '' -- because
% none of the {element_id, subject_id, probe_id} it looked for exists on this
% class (+migrators_j/private/jCarrySubject.m, last line:
% `deps = struct('name','subject_id','value',subjectVal)`).
%
% So the property is not "document_id is there", it is "the edge set is EXACTLY
% the one edge the source had". An invented empty edge is invisible to
% did2.validate.references (:90 skips empty edges) and, on this class, invisible
% to did2.validate.silentLoss too -- the V_eta tombstone declares
% `mustBeNonEmpty: false` on document_id, and silentLoss.m:930-961 only counts
% edges declared mustBeNonEmpty. Nothing but this assertion is watching.
out = did2.convert.migrators_j.ontology_label(ontologyLabelBody());
verifyEqual(testCase, numel(out{1}.depends_on), 1, ...
    'ontology_label must carry exactly the one edge the source had');
verifyEqual(testCase, out{1}.depends_on(1).name, 'document_id');
verifyEqual(testCase, depValue(out{1}, 'subject_id'), '', ...
    'no subject_id edge may be minted: the referent is not a subject');
end

function testOntologyLabelDocumentIdSurvivesTheWholePipeline(testCase)
% THE GAP THIS TEST EXISTS TO CLOSE. Every ontology_label assertion above calls
% the migrator DIRECTLY, so none of them touches the one function in the
% pipeline that rewrites `depends_on`: universalRenames' renameDependsOnEntries
% (universalRenames.m:369+), which converts v1's {name, value} to
% {name, document_id}. If that step ever dropped the entry, renamed it, or lost
% the `name`, every direct-call test would still pass and the loss would be
% silent -- +did2/+schema/cache.m accepts depends_on wholesale and never checks
% that a SOURCE edge survived, which is why a dropped edge is invisible in a way
% an invented one is not.
%
% This runs the real V_eta route (did2.convert.v1_to_v2 -> universalRenames ->
% +migrators_j.ontology_label) and reads the edge off the converted document.
%
% MUTATION MATRIX (transcription harness, NOT MATLAB -- 3 transcribed code
% paths, 3 tests, 14 assertions, 6 mutations = 1 control + 5 breaks). Each row
% is a mutation; each column a test. The point is the two columns of PASS:
%
%   mutation                     defers  keepsOneEdge  survivesPipeline
%   none (control)                PASS      PASS            PASS
%   restore jStartInteraction     FAIL      FAIL            FAIL   <- historical
%   rename the edge subject_id    FAIL      FAIL            FAIL
%   renameDependsOn drops entry   PASS      PASS            FAIL   <- only here
%   renameDependsOn loses `name`  PASS      PASS            FAIL   <- only here
%   extend with empty subject_id  PASS      FAIL            FAIL   <- near-miss
%
% The two universalRenames mutations are caught by NOTHING except this test,
% which is the whole reason it exists.
out = runJ(ontologyLabelBody());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'ontology_label');
% the load-bearing assertion: the referent id, after the rename step
verifyEqual(testCase, depVal(doc, 'document_id'), 'imstack_9', ...
    'the document_id edge must survive universalRenames + the migrator');
verifyEqual(testCase, numel(did2.unittest.helpers.dropSessionEdge(doc.get('depends_on'))), 1);
% and the passthrough is counted as one -- a DELIBERATE one, per class, so an
% accidental fall-through to a fallback would show up here as well
verifyEqual(testCase, out.summary.unconverted_by_class.ontology_label, 1);
end

function testOntologyLabelRejectsInventedShape(testCase)
% ontology_name/label_id/label came from the false provenance line in the
% V2 conversion doc (since corrected). None exists on the real class.
v1 = ontologyLabelBody();
v1.ontology_label = struct('ontology_name', 'Allen CCF v3', 'label_id', 12345, ...
    'label', 'primary visual cortex');
verifyError(testCase, @() did2.convert.migrators_j.ontology_label(v1), ...
    'did2:convert:ontologyLabelInventedShape');
end

% ===================== image_stack -> body-backed observation ==========

function testDidV1ImageMigratesSoTheNameCollisionCannotBite(testCase)
% A did_v1 `image` with a subject folds exactly as image_stack does. UPDATED for
% did-schema #88: the fold emits an intensity_observation (variable 'image
% intensity', value.data_type from the parameters block, value.data_body true)
% whose pixels live on a sampled_body; the v1 `image` name is now the
% deprecated tombstone (#73 item 51), so a fold never re-uses it.
v1 = struct();
v1.document_class = struct('class_name', 'image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
% 2026-10-26: the collection edge is empty (the template's own placeholder): an
% image that names a collection is carried whole as v1 ([image file details
% placed]; testDidV1ImageInACollectionIsCarriedAsV1)
v1.depends_on = [ struct('name', 'subject_id', 'value', 'subj_007'), ...
                  struct('name', 'imageCollection_id', 'value', '')];
v1.base = struct('id', 'img_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
% (no label: an image that states one is carried whole as v1, 2026-10-26;
% testDidV1ImageWithALabelIsCarriedAsV1)
v1.image = struct('label', '', 'format', 'tiff', ...
    'compression', 'lzw');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXC', 'dimension_size', [1024 1024 3], ...
    'dimension_scale', [0.25 0.25 1], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 3);   % observation + sampled_body + anchor
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+intensity');
verifyEqual(testCase, obs.get('base.id'), 'img_01');     % id PRESERVED
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subj_007');
verifyTrue(testCase, logical(obs.get('value.data_body')));
% dtype comes from the parameters block, never guessed from the pixels
verifyEqual(testCase, obs.get('value.data_type'), 'uint8');
names = cellfun(@(d) did2.unittest.helpers.classKey(d), out.migrated, ...
    'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'image')));
% [image file details placed] (Jess Haley, 2026-10-26): the file's format and
% compression are the body's (they were dropped as "deferred")
body = out.migrated{strcmp(names, 'sampled_body')};
fmt = body.get('data_body.format');
% [migrator writes the registry spelling] (Jess Haley, 2026-10-26): 'tiff' is
% the registry's TIFF, EDAM:format_3591 (its media type on a char-format schema)
if isstruct(fmt)
    verifyEqual(testCase, char(fmt.node), 'EDAM:format_3591');
    verifyEqual(testCase, char(fmt.name), 'TIFF');
else
    verifyEqual(testCase, char(fmt), 'image/tiff');
end
verifyEqual(testCase, body.get('data_body.compression'), 'lzw');
end


function testDidV1ImageWithALabelIsCarriedAsV1(testCase)
% `image.label` has no V2 home decided yet (image_stack reads its own block's
% label only), so an image that states one is carried whole as v1 rather than
% losing it ([generic stage is lossless], Jess Haley, 2026-10-25).
v1 = struct();
v1.document_class = struct('class_name', 'image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'img_05', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', 'a histology section', 'format', 'tiff', 'compression', '');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YX', 'dimension_size', [8 8], ...
    'dimension_scale', [1 1], 'clocktype', 'no_time', 'timestamp', 0);
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyTrue(testCase, contains(out.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
    'image.label'));
end

function testDidV1ImageInACollectionIsCarriedAsV1(testCase)
% INVERTED 2026-10-26 (was testDidV1ImageDoesNotMintADanglingCollectionEdge,
% which folded the image and dropped the edge). [image file details placed]
% (Jess Haley, 2026-10-26): the imageCollection_id edge becomes a `member_of`
% relation to a group entity -- a later step -- so until then an image that
% names a collection is carried whole as v1. Still no dangling edge: the v1
% document is carried, not a V2 one naming a document that does not exist.
v1 = struct();
v1.document_class = struct('class_name', 'image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = [ struct('name', 'subject_id', 'value', 'subj_007'), ...
                  struct('name', 'imageCollection_id', 'value', 'coll_1')];
v1.base = struct('id', 'img_02', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', '', 'format', 'tiff', 'compression', '');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXC', 'dimension_size', [8 8 3], ...
    'dimension_scale', [1 1 1], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'image');
verifyTrue(testCase, contains(out.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
    'imageCollection_id'));
end

function testImageStackDataLimitsOtherThanItsTypeRangeAreAValueRange(testCase)
% INVERTS testImageStackDataLimitsOtherThanItsTypeRangeAreCarriedAsV1 (the term
% was not registered then). [image file details placed] (Jess Haley,
% 2026-10-26): `data_limits` is left unwritten when it is its data type's range;
% another range is a body condition with variable EMPTY:0000402 "value range"
% ([census terms] T3), its value the [minimum maximum] pair.
v1 = foldableBehaviourImageStack();
v1.image_stack_parameters.data_type = 'uint8';
v1.image_stack_parameters.data_limits = [0 255];
out = runJ(v1);
b = firstOfClassJ(out.migrated, 'sampled_body');
assertNotEmpty(testCase, b, 'the type''s range folds');
bs = b.toStruct();
verifyFalse(testCase, isfield(bs.data_body, 'conditions') && ~isempty(bs.data_body.conditions), ...
    'the type''s range is not written');
v1.image_stack_parameters.data_limits = [10 200];
out = runJ(v1);
b = firstOfClassJ(out.migrated, 'sampled_body');
assertNotEmpty(testCase, b, 'another range folds too');
c = b.toStruct().data_body.conditions;
if iscell(c); c = c{1}; end
verifyEqual(testCase, char(c(1).variable.node), 'EMPTY:0000402');
verifyEqual(testCase, double(c(1).matrix(:)'), [10 200]);
end

function testACarriedImageStackIsTheV1SourceNotTheSuperclassReshape(testCase)
% A carry emits the v1 source: the image_stack_parameters superclass override
% strips an EMPTY `timestamp` before the concrete migrator runs, and a carried
% stack used to come out with it stripped, unrecorded as a passthrough (so
% stamped did_v2 under its tombstone). It is now the universalRenames output,
% recorded as a pass-1 passthrough, the timestamp still there.
v1 = foldableBehaviourImageStack();
v1.image_stack_parameters.timestamp = [];
v1.image_stack_parameters.data_limits = 'not a pair';   % carried: not a [min max] pair
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyTrue(testCase, isfield(out.migrated{1}.get('image_stack_parameters'), 'timestamp'), ...
    'the carried document lost what the superclass override strips');
end

function testImageStackFormatOntologyIsTheBodysFormat(testCase)
% [image file details placed]: an imageStack's `formatOntology` is the body's
% `format` (it was dropped as derivable)
v1 = foldableBehaviourImageStack();
v1.image_stack.format_ontology = 'NCIT:C85437';
out = runJ(v1);
body = firstOfClassJ(out.migrated, 'sampled_body');
assertNotEmpty(testCase, body);
fmt = body.get('data_body.format');
if isstruct(fmt); fmt = fmt.node; end
verifyEqual(testCase, char(fmt), 'NCIT:C85437');
end

% ---- the subject-less did_v1 `image`: refused, because it cannot pass through --

function testDidV1ImageWithNoSubjectIsRefusedLoudlyBecauseItsNameIsTaken(testCase)
% INVERTED for did-schema #88. This test pinned a REFUSAL that existed because
% V_eta spent the name `image` on an abstract raster data_type, so a subject-less
% did_v1 image could not pass through under its own name. #88 retired that
% data_type and restated `image` as the did_v1 TOMBSTONE in deprecated/ (#73
% item 51), so the reason for the refusal is gone: a subject-less image now
% passes through unchanged, exactly as a subject-less image_stack does (Jess's
% rule: pass through, never invent a subject). The function name is kept so the
% history is searchable; the assertion is the passthrough.
v1 = struct();
v1.document_class = struct('class_name', 'image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'imageCollection_id'}, 'value', {'coll_1'});
v1.base = struct('id', 'img_03', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', 'a lawn plate', 'format', 'tiff', 'compression', '');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YX', 'dimension_size', [512 512], ...
    'dimension_scale', [0.5 0.5], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, out.summary.total, 1);
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, numel(out.migrated), 1, ...
    'a subject-less did_v1 image passes through as exactly one document');
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'image');
verifyEqual(testCase, doc.get('base.id'), 'img_03');
verifyEqual(testCase, out.summary.unconverted_by_class.image, 1);
end


function testDidV1ImageWithABlankSubjectEdgeIsRefusedToo(testCase)
% INVERTED for #88 with the test above: the blank-subject image passes through
% to the deprecated `image` tombstone too, so "absent" and "present but empty"
% still land on the same arm.
v1 = struct();
v1.document_class = struct('class_name', 'image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = [ struct('name', 'subject_id', 'value', ''), ...
                  struct('name', 'imageCollection_id', 'value', '')];
v1.base = struct('id', 'img_04', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', '', 'format', 'tiff', 'compression', 'lzw');
v1.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YX', 'dimension_size', [64 64], ...
    'dimension_scale', [1 1], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, out.summary.total, 1);
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'image');
end


% RETIRED 2026-10-28 with did-schema's deprecated/ tombstones (Decided by Jess
% Haley, 2026-10-27 [carried v1 validates against NDI templates], did-schema
% V_eta_go_forward_class_audit.md): a carried or passed-through v1 document is
% checked against NDI's v1 templates (did2.validate.v1Document), not a
% did-schema tombstone, and one whose class has no V2 schema is counted
% (summary.passthrough_unvalidated_no_schema_count), never quarantined
% (v1_to_v2.m). This test asserted the `image` / `image_stack` schema EXISTS, which
% that decision removes; the passthrough tests beside it, which assert no
% quarantine, are the guard now.

function testImageStackWithNoSubjectPassesThroughInsteadOfObservingNobody(testCase)
% THE 4,563. NDI's own writer leaves subject_id empty on three of its seven
% imageStack sites (+setup/+conv/+haley/doImport.m:789,811,827 -- the image /
% mask / closest-patch loop set only document_id), so this fixture carries
% `document_id` and NO subject, which is what a real JH document of that kind
% looks like. Before the guard this emitted an image_observation with an empty
% required subject_id: an observation about nobody, invisible to every gate
% because references.m skips empty edges.
%
% The passthrough is safe without a V2 schema: since 2026-10-28 ([carried v1
% validates against NDI templates]) a passed-through document whose class V2
% does not hold is counted, not quarantined.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'document_id'}, 'value', {'otr_42'});
v1.base = struct('id', 'is_02', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C70631', 'label', 'an image');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YX', 'dimension_size', [512 512], ...
    'dimension_scale', [0.5 0.5], 'clocktype', 'exp_global_time', 'timestamp', 0);

out = runJ(v1);

verifyEqual(testCase, numel(out.migrated), 1, ...
    'a subject-less image_stack must pass through as exactly one document');
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+intensity'), 0, ...
    'must NOT emit an observation with no subject');
% NOTE THE ACCESSOR. v1_to_v2 returns did2.document OBJECTS, read with
% .get('dotted.path') -- NOT structs. The first draft of these two tests used
% struct field access, carried over from the fitcurve tests, which call the
% migrator DIRECTLY and so really do get structs back. Two green CI jobs went
% red on that alone.
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'image_stack');
verifyEqual(testCase, doc.get('base.id'), 'is_02');
% the payload survives for the second pass
verifyEqual(testCase, doc.get('image_stack_parameters.data_type'), 'uint8');
end

function testImageStackWithAnEmptySubjectEdgeIsAlsoGuarded(testCase)
% Edge PRESENT but blank -- the shape the invented-empty-edge pattern produces.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {''});
v1.base = struct('id', 'is_03', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C70631', 'label', 'an image');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YX', 'dimension_size', [512 512], ...
    'dimension_scale', [0.5 0.5], 'clocktype', 'exp_global_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'image_stack');
end

function testImageStackBecomesBodyBackedObservation(testCase)
% UPDATED for did-schema #88: an image stack folds to an intensity_observation
% (variable 'image intensity'; the v1 label rides on statement.notes; the
% acquisition timestamp is a whole-statement condition) + a sampled_body whose
% data.keys carry one key per dimension in dimension_order, owned by the
% observation (owner_id), datum_order 'F' (a MATLAB array, column-major) + the
% session anchor.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'is_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'EDAM:format_3591', ...
    'label', 'a two-photon stack', 'format', 'tiff');
v1.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YXCZT', 'dimension_size', [512 512 1 1 10], ...
    'dimension_scale', [0.5 0.5 1 1 1], 'clocktype', 'dev_local_time', 'timestamp', 0);
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 3);
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+intensity'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'sampled_body'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 1);
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+intensity');
verifyEqual(testCase, obs.get('statement.variable').name, 'image intensity');
verifyEqual(testCase, obs.get('statement.notes'), 'a two-photon stack');
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subj_007');
verifyEqual(testCase, obs.get('value.data_type'), 'uint16');
verifyTrue(testCase, logical(obs.get('value.data_body')));
sb = out.migrated{2};
verifyEqual(testCase, did2.unittest.helpers.classKey(sb), 'sampled_body');
verifyEqual(testCase, depVal(sb, 'owner_id'), obs.get('base.id'));
verifyEqual(testCase, sb.get('data.datum_order'), 'F');
% the stack's formatOntology is a format term: EDAM:format_3591 TIFF (the
% fixture's node was edam:3382, which is EDAM topic_3382 "Imaging", not a format)
fmt = sb.get('data_body.format');
if isstruct(fmt)
    verifyEqual(testCase, char(fmt.node), 'EDAM:format_3591');
    verifyEqual(testCase, char(fmt.name), 'TIFF');
else
    verifyEqual(testCase, char(fmt), 'image/tiff');
end
keys = did2.unittest.helpers.axesOf(sb.toStruct());   % AMENDMENT 6: dimensions + covariates
verifyEqual(testCase, numel(keys), 5);               % YXCZT
verifyEqual(testCase, did2.convert.axisKey(keys(1).term), 'y');
verifyEqual(testCase, keys(1).term.name, did2.convert.axisTerm('y').name);   % Y-Coordinate where registered
verifyEqual(testCase, keys(1).n, 512);
verifyTrue(testCase, ~isempty(keys(1).cov.origin));
verifyEqual(testCase, keys(1).cov.spacing.value, 0.5);
verifyEqual(testCase, keys(1).cov.origin.value, 0);
% C/Z/T carry a recorded scale of 1, so they are calibrated, not index axes
verifyEqual(testCase, keys(3).cov.spacing.value, 1);
verifyEqual(testCase, keys(3).cov.origin.value, 0);
verifyEqual(testCase, did2.convert.axisKey(keys(5).term), 'time');   % 't' is time (om:Time) where registered
verifyEqual(testCase, keys(5).term.name, did2.convert.axisTerm('t').name);
verifyEqual(testCase, keys(5).n, 10);
end


function testAxisTermsAreTheRegistrysWhereItHoldsThem(testCase)
% [migrator writes the registry spelling] and [term labels stay as the
% ontology spells them] (Jess Haley, 2026-10-26): an axis letter is written as
% the registry's term -- x NCIT:C44477 X-Coordinate, y NCIT:C44478
% Y-Coordinate, z NCIT:C44479 Z-Coordinate, t/time om:Time time -- ONLY where
% the loaded registry holds that node; otherwise by name, as before.
want = {'x', 'NCIT:C44477', 'X-Coordinate'; 'y', 'NCIT:C44478', 'Y-Coordinate'; ...
    'z', 'NCIT:C44479', 'Z-Coordinate'; 't', 'om:Time', 'time'; 'time', 'om:Time', 'time'};
nHeld = 0;
for r = 1:size(want, 1)
    t = did2.convert.axisTerm(want{r, 1});
    held = did2.convert.registeredTerm(want{r, 2}, '');
    if isempty(held.name)
        % not registered: by name, never with an unregistered node
        verifyFalse(testCase, strcmpi(t.node, want{r, 2}), ...
            [want{r, 1} ': an unregistered node is not written']);
    else
        nHeld = nHeld + 1;
        verifyEqual(testCase, t.node, want{r, 2}, want{r, 1});
        verifyEqual(testCase, t.name, want{r, 3}, want{r, 1});
        verifyEqual(testCase, t.name, held.name, [want{r, 1} ': the registry''s label']);
    end
    % read back to its axis, whichever way it was written
    k = did2.convert.axisKey(t);
    if strcmp(want{r, 1}, 't'); verifyEqual(testCase, k, 'time');
    else; verifyEqual(testCase, k, want{r, 1}); end
end
% any other axis name is written as before
verifyEqual(testCase, did2.convert.axisTerm('axis_3').name, 'axis_3');
verifyEqual(testCase, did2.convert.axisKey(struct('node', '', 'name', 'axis_3')), 'axis_3');
fprintf('axis terms: %d of %d axis spellings resolved to a registered node\n', ...
    nHeld, size(want, 1));
end

% ---- [no invented values] (Jess Haley, 2026-10-25) ---------------------
%
% A value the v1 source does not state is not invented: no assumed
% dimension order or data type, and a document with no creation time carries
% the time the migration ran, never the old '2024-01-01T00:00:00.000Z'.

function v1 = imageStackNoInventionDoc()
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'is_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'EDAM:format_3591', ...
    'label', 'a two-photon stack', 'format', 'tiff');
v1.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YXCZT', 'dimension_size', [512 512 1 1 10], ...
    'dimension_scale', [0.5 0.5 1 1 1], 'clocktype', 'dev_local_time', 'timestamp', 0);
end

function testImageStackWithNoDimensionOrderPassesThroughAsV1(testCase)
% No dimension order: no key can be built honestly, so the document passes
% through unchanged. It used to be given 'YXCZT'.
v1 = imageStackNoInventionDoc();
v1.image_stack_parameters = rmfield(v1.image_stack_parameters, 'dimension_order');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'image_stack');
end

function testImageStackWithNoDataTypeLeavesDatumTypeEmpty(testCase)
% No data type: value.data_type is left empty ("not stated"). It used to be
% given 'uint16'.
v1 = imageStackNoInventionDoc();
v1.image_stack_parameters = rmfield(v1.image_stack_parameters, 'data_type');
out = runJ(v1);
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+intensity'), 1);
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+intensity');
s = obs.toStruct();   % not stated: the field is absent or empty
verifyTrue(testCase, ~isfield(s.value, 'data_type') || isempty(s.value.data_type));
end

function testSourceDatestampIsKept(testCase)
% A v1 document that states its creation time keeps it.
out = runJ(imageStackNoInventionDoc());
verifyEqual(testCase, out.migrated{1}.get('base.creation_timestamp'), ...
    '2024-06-01T12:00:00.000Z');
end

function testNoSourceDatestampGetsTheMigrationTime(testCase)
% A v1 document with no creation time carries the time the migration ran:
% the pinned run time, the same on every document of the run.
v1 = imageStackNoInventionDoc();
v1.base = rmfield(v1.base, 'datestamp');
verifyEmpty(testCase, did2.convert.migrationTime('get'));
pinned = did2.convert.migrationTime('pin');
unpin = onCleanup(@() did2.convert.migrationTime('unpin')); %#ok<NASGU>
out = runJ(v1);
verifyGreaterThan(testCase, numel(out.migrated), 1);
for k = 1:numel(out.migrated)
    ts = out.migrated{k}.get('base.creation_timestamp');
    verifyEqual(testCase, ts, pinned, sprintf('document %d', k));
    verifyNotEqual(testCase, ts, '2024-01-01T00:00:00.000Z');
end
end

function testMigrationTimeIsPinnedPerCallAndReleased(testCase)
% v1_to_v2 pins one time for its own call when nothing is pinned, and
% releases it after; an explicit pin is kept and survives the call.
verifyEmpty(testCase, did2.convert.migrationTime('get'));
v1 = imageStackNoInventionDoc();
v1.base = rmfield(v1.base, 'datestamp');
out = runJ(v1);
verifyEmpty(testCase, did2.convert.migrationTime('get'));   % released
ts = cellfun(@(d) d.get('base.creation_timestamp'), out.migrated, ...
    'UniformOutput', false);
verifyEqual(testCase, numel(unique(ts)), 1);                % one time per call
verifyMatches(testCase, ts{1}, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$');
verifyNotEqual(testCase, ts{1}, '2024-01-01T00:00:00.000Z');
p = did2.convert.migrationTime('pin');
unpin = onCleanup(@() did2.convert.migrationTime('unpin')); %#ok<NASGU>
runJ(v1);
verifyEqual(testCase, did2.convert.migrationTime('get'), p); % kept
end


% ---- image_stack: the `document_id` edge on the FOLD arm ---------------
%
% The guard arm (subject-less, E. coli) passes the document through INTACT and
% therefore keeps `document_id`. The fold arm REBUILDS `depends_on` from
% scratch (image_stack.m: `obs.depends_on = [...]`) and USED TO lose it; since
% did-schema 6cf31f2 gave `image_observation` an `ontology_table_row_id` slot it
% carries it instead. The fixtures below are the haley BEHAVIOUR shape --
% doImport.m:421-441, which sets BOTH edges -- because every fold-arm fixture
% that existed before them carried `subject_id` only, so the drop was
% structurally invisible to the suite. That is the same hole the `files`-block
% defect used (testTemplateLiteralTypeTraps' image_stack fixtures declare no
% files, and a tombstone declaring a file no document has went green for it),
% arriving one key over on `depends_on`.
%
% THE CARRY IS CONDITIONAL, so ONE fixture cannot gate it. The fold arm sees
% TWO of NDI's three imageStack populations and they disagree about the edge:
% haley behaviour has it, babu (+setup/+conv/+babu/import.m:474) does not. The
% babu fixture below is what proves the absent case OMITS the entry rather than
% emitting it blank -- and blank is not a cosmetic difference, it is the
% invented-empty-edge pattern that put 7,233 documents in the census while the
% RequiredDependencies gate is armed and the corpus is at 0 quarantine /
% 0 orphans.

function testImageStackScaleUnitsAreSplitPerAxis(testCase)
% v1's `dimension_scale_units` is per-axis and positionally aligned with
% `dimension_order`. UPDATED for #88: each key on the sampled_body carries its
% own source_unit, written with the registry label ('micrometer' is the
% registry's om:micrometre 'micrometre'; 'second' is om:second-Time).
out = runJ(foldableBehaviourImageStack());
sb = firstOfClassJ(out.migrated, 'sampled_body');
keys = did2.unittest.helpers.axesOf(sb.toStruct());   % AMENDMENT 6: dimensions + covariates
verifyEqual(testCase, numel(keys), 3, 'dimension_order YXT is three dimensions');
verifyEqual(testCase, keys(1).term.name, did2.convert.axisTerm('y').name);
verifyEqual(testCase, keys(3).term.name, did2.convert.axisTerm('t').name);
verifyEqual(testCase, keys(1).cov.source_unit.name, 'micrometre');
verifyEqual(testCase, keys(2).cov.source_unit.name, 'micrometre');
verifyEqual(testCase, keys(3).cov.source_unit.name, 'second');
verifyEqual(testCase, keys(1).cov.spacing.value, 1.5);
verifyEqual(testCase, keys(3).cov.spacing.value, 0.2);
end


function testRegisteredSourceUnitsCarryTheirNode(testCase)
% jSourceUnit: a unit spelling the term registry holds is written with the
% registry's node and name (V_eta_source_unit_plan.md item 4): degree, radian
% and hertz are om:degree, om:radian, om:hertz; volt, millivolt, microvolt,
% kilogram, kilohertz, ampere, milliampere, microampere, nanoampere and
% picoampere are their om: terms. A spelling the table does not know stays
% {node '', name SPELLING}. (The micro-sign spelling of microvolt is in the
% table too; it is not exercised here because Octave, which runs these tests
% in session tooling, rejects char(181) as invalid UTF-8 in regexp.)
cases = { ...
    'degrees,radians,Hz', {'om:degree', 'degree'; 'om:radian', 'radian'; 'om:hertz', 'hertz'}; ...
    'deg,rad,kHz',        {'om:degree', 'degree'; 'om:radian', 'radian'; 'om:kilohertz', 'kilohertz'}; ...
    'V,mV,uV',            {'om:volt', 'volt'; 'om:millivolt', 'millivolt'; 'om:microvolt', 'microvolt'}; ...
    'volts,millivolt,microvolt', {'om:volt', 'volt'; 'om:millivolt', 'millivolt'; 'om:microvolt', 'microvolt'}; ...
    'volt,microvolt,kg',  {'om:volt', 'volt'; 'om:microvolt', 'microvolt'; 'om:kilogram', 'kilogram'}; ...
    'A,mA,uA',            {'om:ampere', 'ampere'; 'om:milliampere', 'milliampere'; 'om:microampere', 'microampere'}; ...
    'nA,pA,furlong',      {'om:nanoampere', 'nanoampere'; 'om:picoampere', 'picoampere'; '', 'furlong'}};
for c = 1:size(cases, 1)
    v1 = foldableBehaviourImageStack();
    v1.image_stack_parameters.dimension_scale_units = cases{c, 1};
    out = runJ(v1);
    sb = firstOfClassJ(out.migrated, 'sampled_body');
    keys = did2.unittest.helpers.axesOf(sb.toStruct());
    assertEqual(testCase, numel(keys), 3, cases{c, 1});
    want = cases{c, 2};
    for k = 1:3
        u = keys(k).cov.source_unit;
        verifyEqual(testCase, termNodeJ(u), want{k, 1}, sprintf('%s axis %d node', cases{c, 1}, k));
        verifyEqual(testCase, char(u.name), want{k, 2}, sprintf('%s axis %d name', cases{c, 1}, k));
    end
end
end


function testImageStackAxisWithNoRecordedScaleIsABareDimension(testCase)
% INVERTED 2026-10-22 (was testImageStackAxisWithNoRecordedScaleIsAnIndexAxis:
% origin 1, spacing 1, no unit). A dimension with no recorded scale has only
% its own positions, and a covariate that only repeats them (0..n-1 or 1..n)
% is not written (Jess Haley 2026-10-22 [covariate rules named] 6.2a, and
% "yes" to 1..n): three bare dimensions. A recorded scale, even 1, is still a
% covariate (testImageStackBecomesBodyBackedObservation).
v1 = foldableBehaviourImageStack();
v1.image_stack_parameters.dimension_scale = [];        % nothing recorded
v1.image_stack_parameters.dimension_scale_units = '';
out = runJ(v1);
keys = did2.unittest.helpers.axesOf(firstOfClassJ(out.migrated, 'sampled_body').toStruct());
verifyEqual(testCase, numel(keys), 3, 'every dimension is still written');
verifyEqual(testCase, [keys.nCov], [0 0 0], 'no covariate repeats the positions');
end


function v1 = arenaMaskImageStack()
%ARENAMASKIMAGESTACK The JH arena mask, as NDI's writer builds it
%   (+setup/+conv/+haley/doImport.m, "Arena mask imageStack"): YX, logical,
%   label = the definition ndi.ontology.lookup('EMPTY:0000130') returns,
%   document_id = the plate row, subject_id = the subject group, no app block.
%   The plate row is left out here: a mask naming one is carried whole as v1
%   (testImageStackNamingATableRowIsCarriedWholeAsV1); these tests are of the
%   mask fold, which runs on a mask it can place whole.
v1 = foldableBehaviourImageStack();
v1.base.id = 'is_mask_01';
v1.image_stack = struct('format_ontology', 'NCIT:C85437', 'label', ...
    ['A binary image (logical matrix) where pixels within the experimental ' ...
     'arena for C. elegans are marked (true) and pixels outside are unmarked ' ...
     '(false). This mask defines the region of interest for worm tracking ' ...
     'and behavioral analysis.']);
v1.image_stack_parameters = struct('data_type', 'logical', ...
    'dimension_order', 'YX', 'dimension_labels', 'height,width', ...
    'dimension_size', [1024 1024], 'dimension_scale', [1.5 1.5], ...
    'dimension_scale_units', 'micrometer,micrometer', 'data_limits', [0 1]);
end

function testAMaskIsCarriedWholeAsV1NamingItsHome(testCase)
% INVERTS testImageStackMaskIsALogicalCalculationOfItsRegion and
% testABacterialPatchMaskMarksTheBacterialLawnRegion: the region a mask marks
% was read from Haley label words ("arena", "bacteria" / "lawn"), which left the
% generic migration (Decided by Jess Haley, 2026-10-26 [dataset-specific logic
% leaves the generic migration], [one correct reading]). Every mask -- the arena
% mask, the bacterial-patch mask and one whose label names no region -- is
% carried whole as v1 with a `needs_mapping` note naming its V2 home.
labels = {arenaMaskImageStack().image_stack.label, ...
    ['A binary image mask (logical matrix) representing the union of all ' ...
     'individually detected bacterial patch areas on an assay plate. This ' ...
     'mask defines all food-containing regions.'], ...
    'a mask'};
for k = 1:numel(labels)
    v1 = arenaMaskImageStack();
    v1.image_stack.label = labels{k};
    out = runJ(v1);
    verifyCarriedWholeAsV1(testCase, v1, out);
    verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'image_stack');
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-025] needs_mapping: calculation'), d);
end
end

function testAClosestPatchMapIsCarriedNeedingAMapping(testCase)
% INVERTS testAClosestPatchMapIsNotAMaskAndStaysALabel: a map is recognised by
% words in its label ("each pixel's value is the identifier"), so it is carried
% as v1 with a needs_mapping note ([one-reading quick answers] (Q3), Jess Haley,
% 2026-10-26).
v1 = arenaMaskImageStack();
v1.image_stack.label = ['An image or map where each pixel''s value is the ' ...
    'identifier of the bacterial patch closest to that pixel''s location.'];
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyTrue(testCase, startsWith(out.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
    '[carry-025] needs_mapping:'));
end

function testAnIntensityImageStackIsStillAnObservation(testCase)
% THE OTHER DIRECTION: the behaviour video is not a mask.
out = did2.convert.migrators_j.image_stack(foldableBehaviourImageStack());
names = cellfun(@did2.unittest.helpers.classKey, out, 'UniformOutput', false);
verifyTrue(testCase, ismember('observation+intensity', names));
verifyFalse(testCase, ismember('calculation+label', names));
end

function v1 = behaviourImageStack()
%BEHAVIOURIMAGESTACK The JH C. elegans behaviour-plate imageStack, as NDI's own
%   writer builds it: +setup/+conv/+haley/doImport.m:421-441.
%
%       :429-430   set_dependency_value('document_id', dataTable.plate_id{p})
%       :431-432   set_dependency_value('subject_id',  subjectGroup_id)
%       :441       add_file('imageStack', videoFileName)
%
%   `plate_id` is the id of an `ontologyTableRow` document (doImport.m:233-237
%   -> tableDocMaker.table2ontologyTableRowDocs -> tableDocMaker.m:221), so the
%   edge names a real document, not a bare label.
%
%   THE `files` BLOCK IS DELIBERATE and is NDI's own spelling, `imageStack` --
%   the file key is one of the four structural keys universalRenames skips
%   (universalRenames.m:308), so it is NOT snake_cased on the way through.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'document_id', 'subject_id'}, ...
                       'value', {'otr_plate_1', 'subjgrp_7'});
v1.base = struct('id', 'is_beh_01', 'session_id', 'sess_celegans', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C190180', ...
    'label', 'A video recording capturing the behavior of C. elegans');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXT', 'dimension_size', [1024 1024 30], ...
    'dimension_scale', [1.5 1.5 0.2], ...
    'dimension_scale_units', 'micrometer,micrometer,second', ...
    'clocktype', 'exp_global_time', 'timestamp', 739000);
v1.files = struct('file_list', {{'imageStack'}});
end

function v1 = foldableBehaviourImageStack()
%FOLDABLEBEHAVIOURIMAGESTACK behaviourImageStack without its `document_id`
%   (the plate row). Since [generic stage is lossless] (Jess Haley, 2026-10-25)
%   a stack that names a row is carried whole as v1 (#88 has no edge for it:
%   testImageStackNamingATableRowIsCarriedWholeAsV1), so the tests of the fold
%   itself (axes, units, masks) drive a stack the fold can place whole.
v1 = behaviourImageStack();
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subjgrp_7'});
end

function v1 = babuImageStack()
%BABUIMAGESTACK The OTHER fold-arm population: +setup/+conv/+babu/import.m:474.
%
%   It is the reason the carry has to be conditional rather than
%   unconditional, and it is the site the migrator header missed when it said
%   there were SEVEN imageStack sites -- there are EIGHT:
%
%       $ git grep -n "ndi\.document('imageStack'" origin/main -- '*.m'
%       .../+babu/import.m:474
%       .../+haley/doImport.m:421,461,477,496,789,811,827
%
%       import.m:478-479   set_dependency_value('subject_id', ...
%                              imStackTable.SubjectGroupIdentifier_Column{i})
%       import.m:483       add_file('imageStack', imStackFile, ...)
%
%   NO `document_id` IS SET ANYWHERE IN THAT LOOP, so this document reaches the
%   fold arm (it has a subject) with nothing to carry. The parameters block is
%   the real one from import.m:455-464 -- a compressed .mp4, hence the T axis
%   and the frame-rate scale.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subjgrp_babu_3'});
v1.base = struct('id', 'is_babu_01', 'session_id', 'sess_babu', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C190180', ...
    'label', 'A video recording of a behaving animal');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXT', 'dimension_size', [480 640 900], ...
    'dimension_scale', [1 1 30], ...
    'dimension_scale_units', 'pixel,pixel,second', ...
    'clocktype', 'exp_global_time', 'timestamp', 739000);
v1.files = struct('file_list', {{'imageStack'}});
end

function otr = behaviourPlateRow()
%BEHAVIOURPLATEROW The `ontologyTableRow` the fixture above points at: the JH
%   behaviour-plate table (doImport.m:230-237; columns doImport.m:101-106).
%
%   IT MUST REACH THE GUARDED PASSTHROUGH, and it does so for the reason the
%   real corpus documents do, not by construction: `tableDocMaker` sets exactly
%   one dependency in the whole file and it is `document_id`
%   (tableDocMaker.m:231), so there is no `subject_id` for
%   `resolvedSubject` to find. It is not an encounter table (no
%   EncounterIdentifier) and not a patch-geometry table (behaviorPlateVariables
%   has no `patchID` column, so no BacterialPatchIdentifier, and no radius /
%   circularity / centre), so neither per-table map claims it.
%
%   The `data` KEYS are shortName(term) and cannot be evaluated here --
%   `ndi.ontology.lookup` lives in ndi-ontology-matlab, which is not checked
%   out. They are derived from +haley/tableDoc_dictionary.json's term labels
%   (e.g. "temp" -> "EMPTY:ambient temperature") the same way
%   cultivationPlateRow's are, and NOTHING below turns on their spelling: the
%   test asserts id survival and dispatch, both of which are decided by the
%   ABSENCE of the map signatures.
keys = {'ExperimentSessionIdentifier', 'CElegansAssayPhase', ...
    'BacterialPlateIdentifier', 'BacterialOD600Label', ...
    'BacterialOD600Measurement', 'BacterialColonyFormingUnitsCFUMeasurement', ...
    'AmbientTemperature', 'AmbientHumidity', ...
    'CElegansBehavioralAssay_PlateOrArenaDiameter', 'BacterialPatchSpacingTarget'};
data = struct();
data.ExperimentSessionIdentifier = '0001';
data.CElegansAssayPhase = 'behavior';
data.BacterialPlateIdentifier = '0017';
data.BacterialOD600Label = '1.00';
data.BacterialOD600Measurement = 0.98;
data.BacterialColonyFormingUnitsCFUMeasurement = 1.96e9;
data.AmbientTemperature = 20;
data.AmbientHumidity = 45;
data.CElegansBehavioralAssay_PlateOrArenaDiameter = 90;
data.BacterialPatchSpacingTarget = 0;
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
% THE EDGE IS PRESENT AND EMPTY, which is what the WRITER produces, not a
% convenience. The NDI template ships `depends_on: [{"name":"document_id",
% "value":""}]`, and NOT ONE of the nine `table2ontologyTableRowDocs` calls in
% doImport.m passes `dependencyVariable` (200, 234, 295, 351, 533, 688, 741,
% 757, 855) -- the only thing that would fill it in
% (tableDocMaker.m:227-235). So every JH row carries the declared edge unset.
otr.depends_on = struct('name', {'document_id'}, 'value', {''});
otr.base = struct('id', 'otr_plate_1', 'session_id', 'sess_celegans', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function testImageStackNamingATableRowIsCarriedWholeAsV1(testCase)
% INVERTS testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot, which
% asserted the fold arm's output WITHOUT the v1 `document_id` (#88 has no edge
% for it). Since [generic stage is lossless] and [partly placed is carried as
% v1] (Jess Haley, 2026-10-25) a stack that names its ontologyTableRow is
% carried whole as v1: one document, the source, the edge kept.
v1 = behaviourImageStack();
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.migrated{1};
verifyEqual(testCase, char(d.get('document_class.class_name')), 'image_stack');
verifyEqual(testCase, depVal(d, 'document_id'), 'otr_plate_1', 'the edge is kept');
verifyEqual(testCase, depVal(d, 'subject_id'), 'subjgrp_7');
verifyEqual(testCase, out.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
    '[carry-052] unplaced: depends_on document_id');
end

function testImageStackFoldWithNoTableRowStillPlacesTheStack(testCase)
% the fold arm itself, on a stack it can place whole (no plate row): the edge
% set is exactly entity_id + time_reference_id, the bytes land on the body
out = runJ(foldableBehaviourImageStack());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3, ...
    'the fold arm is 1 -> intensity_observation + sampled_body + anchor');
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+intensity');
verifyEqual(testCase, sort(did2.unittest.helpers.dropSessionEdge(depNamesOf(obs))), ...
    {'entity_id', 'time_reference_id'});
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subjgrp_7');
verifyEqual(testCase, obs.get('base.id'), 'is_beh_01');
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{2}), 'sampled_body');
sbStruct = out.migrated{2}.toStruct();
verifyTrue(testCase, isfield(sbStruct, 'files'), 'the carried bytes must land on the sampled_body');
verifyEqual(testCase, sbStruct.files.file_list{1}, 'imageStack', ...
    'and under NDI''s own spelling -- universalRenames skips file keys');
verifyFalse(testCase, isfield(obs.toStruct(), 'files'), ...
    'the observation is the handle; the bytes belong to the body');
end


function testImageStackDocumentIdReferentSurvivesTheBatch(testCase)
% UPDATED for did-schema #88 (see the test above: the plate-row edge is not
% carried). What still holds, and is asserted: in a self-contained batch (image,
% plate row, subject group) the plate row survives on exactly one document,
% passes through, and nothing orphans; and without the row nothing orphans
% either, because no emitted edge names it.
group = struct();
group.document_class = struct('class_name', 'subject_group', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
group.depends_on = struct('name', {}, 'value', {});
group.base = struct('id', 'subjgrp_7', 'session_id', 'sess_celegans', ...
    'name', 'plate_worms', 'datestamp', '2024-06-01T12:00:00.000Z');
group.subject_group = struct('group_name', 'plate_worms', 'description', '');

out = runJ({behaviourImageStack(), behaviourPlateRow(), group});
verifyEmpty(testCase, out.quarantine);
% UPDATED for [generic stage is lossless] (Jess Haley, 2026-10-25): the image
% names the row, so it is carried whole as v1 (1 -> 1), edge and all
verifyEqual(testCase, numel(out.migrated), 3);   % image 1->1 (v1), row 1->1, group 1->1
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_plate_1')), 1);
classes = cellfun(@(d) did2.unittest.helpers.classKey(d), out.migrated, ...
    'UniformOutput', false);
verifyTrue(testCase, any(strcmp(classes, 'ontology_table_row')));
rep = did2.validate.references(out.migrated, ...
    'KnownIds', did2.unittest.helpers.sessionKnownIds(out.migrated));
verifyGreaterThan(testCase, rep.edges_examined, 0);
verifyEqual(testCase, rep.orphan_count, 0);

% INVERTED with the carry: the v1 image keeps its `document_id`, so a batch
% that leaves the row out has exactly that one edge dangling (the v1 truth,
% not an invented edge); with the row present (above) nothing orphans.
outNoRow = runJ({behaviourImageStack(), group});
repMissing = did2.validate.references(outNoRow.migrated, ...
    'KnownIds', did2.unittest.helpers.sessionKnownIds(outNoRow.migrated));
verifyGreaterThan(testCase, repMissing.edges_examined, 0);
verifyEqual(testCase, repMissing.orphan_count, 1, ...
    'the carried v1 image names the absent plate row');
end


function testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank(testCase)
% A babu imageStack (subject, no document_id) folds like any other. UPDATED for
% #88: leaf intensity_observation; edges exactly entity_id + time_reference_id.
out = runJ(babuImageStack());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3);
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+intensity');
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subjgrp_babu_3');
verifyNotEmpty(testCase, depVal(obs, 'time_reference_id'));
verifyEqual(testCase, sort(did2.unittest.helpers.dropSessionEdge(depNamesOf(obs))), ...
    {'entity_id', 'time_reference_id'});
end


function testImageStackBlankDocumentIdIsOmittedNotCarriedThrough(testCase)
% An empty source document_id must not become an empty edge. UPDATED for #88.
v1 = babuImageStack();
v1.depends_on = struct('name', {'subject_id', 'document_id'}, ...
                       'value', {'subjgrp_babu_3', ''});
out = runJ(v1);
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+intensity');
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subjgrp_babu_3');
verifyEqual(testCase, sort(did2.unittest.helpers.dropSessionEdge(depNamesOf(obs))), ...
    {'entity_id', 'time_reference_id'});
end

% ===== ontology_table_row: the JH encounter table is not mapped here ====

function otr = encounterRow()
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
data.([P 'EncounterOnsetTime']) = 1249.72;
data.([P 'EncounterOffsetTime']) = 1265.39;
data.([P 'DecelerationUponEncounter']) = 3.15;
data.([P 'MinimumVelocityDuringEncounter']) = 130.4;
data.([P 'PeakVelocityBeforeEncounterOnset']) = 196.3;
data.([P 'MinimumVelocityAfterEncounterOffset']) = 130.4;
data.([P 'PosteriorProbabilityOfExploitation']) = 1.99e-5;
data.([P 'PosteriorProbabilityOfSensing']) = 7.5e-4;
data.([P 'RelativeDensityOfEncounteredBacteria']) = 0.557;
data.([P 'RelativeDensityOfCultivationBacteria']) = 2.238;
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {}, 'value', {});
otr.base = struct('id', 'otr_enc', 'session_id', 'sess_1', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function d = firstOfClassJ(migrated, className)
d = [];
for k = 1:numel(migrated)
    % #88: a class name OR a leaf name (`observation+term`, `organism`, ...; classKey)
    if strcmp(migrated{k}.get('document_class.class_name'), className) ...
            || strcmp(did2.unittest.helpers.classKey(migrated{k}), className)
        d = migrated{k}; return;
    end
end
end

function otr = placeableEncounterRow()
%PLACEABLEENCOUNTERROW An encounter row the retired JH encounter map placed
%   WHOLE: the EncounterIdentifier column is present but empty, and no column
%   carries an ontology node. Kept to show the generic stage maps neither shape.
otr = encounterRow();
otr.ontology_table_row.data.CElegansBehavioralAssay_EncounterIdentifier = [];
otr.ontology_table_row.ontology_nodes = '';
end

function verifyCarriedWholeAsV1(testCase, v1, out)
%VERIFYCARRIEDWHOLEASV1 [generic stage is lossless] / [partly placed is carried
%   as v1] (Jess Haley, 2026-10-25): the source comes back as ONE document, the
%   v1 body unchanged, recorded in pass 1's passthrough list (which
%   ndi.migrate.local stamps 'did_v1'), and noted `carried_as_v1`.
verifyEqual(testCase, numel(out.migrated), 1, 'one document: the v1 source');
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, numel(out.passthrough), 1, 'recorded as a pass-1 passthrough');
verifyEqual(testCase, char(out.passthrough(1).id), char(v1.base.id));
verifyEqual(testCase, char(out.migrated{1}.get('base.id')), char(v1.base.id));
notes = out.summary.migration_notes;
verifyTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry is noted');
if isfield(notes, 'carried_as_v1')
    verifyEqual(testCase, notes.carried_as_v1.count, 1);
end
end

function testAnEncounterRowIsNotMappedByTheGenericStage(testCase)
% INVERTS testEncounterTableMap / testAnEncounterRowTheMapCannotPlaceIs...:
% the JH C. elegans encounter map left the generic migration (Decided by Jess
% Haley, 2026-10-26 [dataset-specific logic leaves the generic migration],
% [dataset audit batch 1 and 2]). An encounter row -- even one the old map
% placed whole -- is now an ordinary row: with no `subject_id` edge it comes
% back as the v1 row, every cell kept, for the NDI second pass; no window, no
% `encountered` relation and no worm observation is written.
rows = {encounterRow(), placeableEncounterRow()};
for r = 1:numel(rows)
    v1 = rows{r};
    out = runJ(v1);
    verifyEqual(testCase, numel(out.migrated), 1, 'the v1 row, alone');
    verifyEqual(testCase, out.summary.quarantine_count, 0);
    d = out.migrated{1};
    verifyEqual(testCase, char(d.get('document_class.class_name')), 'ontology_table_row');
    verifyEqual(testCase, char(d.get('base.id')), 'otr_enc');
    verifyEqual(testCase, d.get('ontology_table_row.data'), v1.ontology_table_row.data);
    verifyEqual(testCase, nLeafJ(out.migrated, 'directed_relation'), 0);
    verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 0);
end
end

% ==== ontology_table_row: the JH patch geometry table is not mapped here ==

function otr = patchGeometryRow()
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
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {}, 'value', {});
otr.base = struct('id', 'otr_patch', 'session_id', 'sess_1', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function testAPatchGeometryRowIsNotMappedByTheGenericStage(testCase)
% INVERTS testPatchGeometryTableMap: the JH bacterial-patch geometry map (a
% `culture` entity named plate/<p>/patch/<q> and six fixed measures) left the
% generic migration (Decided by Jess Haley, 2026-10-26 [dataset-specific logic
% leaves the generic migration], [dataset audit batch 1 and 2]). The row comes
% back as the v1 row, every cell kept; no patch entity is minted under any
% handle.
v1 = patchGeometryRow();
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1, 'the v1 row, alone');
verifyEqual(testCase, out.summary.quarantine_count, 0);
d = out.migrated{1};
verifyEqual(testCase, char(d.get('document_class.class_name')), 'ontology_table_row');
verifyEqual(testCase, char(d.get('base.id')), 'otr_patch');
verifyEqual(testCase, d.get('ontology_table_row.data'), v1.ontology_table_row.data);
verifyEqual(testCase, nLeafJ(out.migrated, 'culture'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 0);
end

% ==== ontology_table_row: the C. elegans CULTIVATION PLATE is not a patch ===

function otr = cultivationPlateRow()
%CULTIVATIONPLATEROW The JH C. elegans cultivation-plate table
%   (+setup/+conv/+haley/doImport.m:179-201), which is NOT the bacterial-patch
%   geometry table and must not be migrated as one.
%
%   THE THREE SIGNATURE KEYS ARE THE POINT, and they are corpus-proven (the
%   patch map fires on them today). The cultivation table earns all three:
%
%     BacterialOD600TargetAtSeeding  <- doImport.m:100 `growthOD600`. The
%         dictionary maps THREE columns -- patchOD600, growthOD600, OD600 --
%         to the ONE term "EMPTY:bacterial OD600 (target) at seeding", and a
%         `data` key is shortName(term), so all three are the same key.
%     BacterialPatchIdentifier       <- doImport.m:192 `patchID`, set to the
%         CONSTANT '0001' for every cultivation-plate row.
%     BacterialPatchDocumentIdentifier -- absent, as on the geometry table.
%
%   What it does NOT have is patch GEOMETRY: no radius, no circularity, no
%   centre. That is the discriminator.
%
%   The plate-level column keys below are DERIVED from the dictionary's term
%   labels, NOT verified -- `ndi.ontology.lookup` (ndi-ontology-matlab) is not
%   in this repo, so shortName cannot be evaluated here. Nothing this test
%   asserts depends on their spelling: they are filler that makes the row the
%   right WIDTH, and the dispatch turns only on the four keys named above.
keys = {'ExperimentSessionIdentifier', 'CElegansAssayPhase', ...
    'BacterialPlateIdentifier', 'BacterialPatchIdentifier', ...
    'BacterialOD600TargetAtSeeding', 'BacterialPatchVolume', ...
    'BacterialOD600Measurement', 'BacterialColonyFormingUnitsCFUMeasurement', ...
    'AmbientTemperature', 'CElegansBehavioralAssay_PlateOrArenaDiameter'};
data = struct();
data.ExperimentSessionIdentifier = '0001';
data.CElegansAssayPhase = 'cultivation';
data.BacterialPlateIdentifier = '0901';
data.BacterialPatchIdentifier = '0001';        % constant, doImport.m:192
data.BacterialOD600TargetAtSeeding = 1.0;      % `growthOD600`
data.BacterialPatchVolume = 200;               % `lawnVolume`, doImport.m:193
data.BacterialOD600Measurement = 0.98;         % `OD600Real` -- currently dropped
data.BacterialColonyFormingUnitsCFUMeasurement = 1.96e9;   % `CFU` -- dropped
data.AmbientTemperature = 20;                  % `temp` -- dropped
data.CElegansBehavioralAssay_PlateOrArenaDiameter = 90;    % dropped
nodes = strjoin(repmat({'EMPTY:0'}, 1, numel(keys)), ',');
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {}, 'value', {});
otr.base = struct('id', 'otr_cultivation', 'session_id', 'sess_1', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function testCultivationPlateIsNotMigratedAsABacterialPatch(testCase)
%TESTCULTIVATIONPLATEISNOTMIGRATEDASABACTERIALPATCH Regression for a live loss.
%
%   `isPatchGeometryTable` used to be three clauses, and the cultivation-plate
%   table satisfied all three (see cultivationPlateRow). Every cultivation
%   plate was therefore minted as a bacterial-patch SUBJECT -- with
%   local_identifier '0001', the same string on every such row in the corpus --
%   and read against a 6-measure enumeration it does not have: of the REAL
%   table's 22 columns, 2 were carried, 1 was spent as the identity, and 19 were
%   dropped in silence. (The fixture below is a 10-column stand-in; only the
%   four dispatch-relevant keys have to be exact.)
%
%   With no `subject_id` dependency on the source document (the NDI
%   ontologyTableRow template declares only `document_id`), the correct
%   behaviour is the guarded passthrough: carry the document intact for the NDI
%   second pass, which can see the migrated-id graph.
out = runJ(cultivationPlateRow());
verifyEqual(testCase, numel(out.migrated), 1, ...
    'the cultivation plate was fanned out instead of passed through');
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'ontology_table_row');
verifyEqual(testCase, d.get('base.id'), 'otr_cultivation');
bc = out.summary.by_class;
% NOT a patch: no minted subject, and none of the geometry-map outputs
% #88: by_class counts raw classes, so the leaves are counted directly
verifyEqual(testCase, nLeafJ(out.migrated, 'culture'), 0, ...
    'a cultivation plate was minted as a bacterial-patch subject');
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+concentration'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'observation+volume'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 0);
verifyFalse(testCase, isfield(bc, 'entity'));
% and nothing was quarantined to achieve that
verifyEmpty(testCase, out.quarantine);
end

% ==== deferred stimulus_bath -> manipulation valued by its formulation =====

function testDeferredBathIsAManipulationValuedByItsFormulation(testCase)
% A stimulus_bath defers per-document (needsSessionContext). At V_eta the
% resolveDeferredBaths pass assembles it (D8 retired the `bath` /
% `pharmacological_manipulation` family) as a `manipulation` whose value kind
% is `formulation` and whose value is the bath's formulation document, through
% `value_id`: "A bath is a manipulation whose value is the formulation
% (pointed at through `value_id`), not a dose; a dose always has an amount"
% (Jess Haley, 2026-10-21; did-schema V_eta_go_forward_class_audit.md).
% INVERTED from testDeferredBathBecomesDoseManipulation, which asserted a
% `dose_manipulation` naming its formulation by `formulation_id`: that dose had
% an empty `dose.value`, which the value rule (`value_inline_or_body`,
% did-schema data_body AMENDMENT 5) refuses.
subjId = 'aabb1122ccdd3344_5500000000000001';
stimId = 'aabb1122ccdd3344_5500000000000002';

elem = struct();
elem.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
elem.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
elem.base = struct('id', stimId, 'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'stimulator', 'datestamp', '2024-06-01T12:00:00.000Z');
% a stimulator element is an ndi.probe.timeseries.stimulator (NDI
% probetype2object.json): [element types have no default] makes a probe type a
% device only on an ndi.probe.* class (Jess Haley, 2026-10-26)
elem.element = struct('ndi_element_class', 'ndi.probe.timeseries.stimulator', 'name', 'stim', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);

bath = struct();
bath.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
bath.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
bath.base = struct('id', 'aabb1122ccdd3344_5500000000000004', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
bath.epochid = struct('epochid', 'epoch_t00001');
bath.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');

out = did2.convert.v1_to_v2({jsonencode(elem), jsonencode(bath)}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
verifyTrue(testCase, any(arrayfun(@(q) strcmp(q.class_name, 'stimulus_bath'), ...
    out.quarantine)), 'stimulus_bath was not deferred');

out = did2.convert.resolveDeferredBaths(out, 'Validate', false, ...
    'TargetVersion', 'V_eta');

% a manipulation valued by its formulation; never a dose, never the retired `bath`
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+formulation'), 1, ...
    'no formulation-valued manipulation produced');
verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+dose'), 0, ...
    'a bath is not a dose (a dose always has an amount)');
verifyFalse(testCase, isfield(out.summary.by_class, 'bath'), ...
    'retired `bath` class must not be emitted at V_eta');
for k = 1:numel(out.quarantine)
    verifyEmpty(testCase, regexp(out.quarantine(k).reason, ...
        'needsSessionContext|NDI layer|class "bath"', 'once'), ...
        sprintf('bath left unresolved: %s', out.quarantine(k).reason));
end

m = firstOfClassJ(out.migrated, 'manipulation+formulation');
verifyNotEmpty(testCase, m);
if isempty(m); return; end
verifyEqual(testCase, m.get('document_class.class_name'), 'manipulation');
verifyEqual(testCase, m.get('base.id'), 'aabb1122ccdd3344_5500000000000004', ...
    'the bath keeps the stimulus_bath id');
verifyEqual(testCase, depVal(m, 'entity_id'), subjId);
verifyNotEmpty(testCase, depVal(m, 'time_reference_id'));
verifyEmpty(testCase, depVal(m, 'formulation_id'), ...
    'the formulation is the value (value_id), not a dose''s formulation_id');
% the primary chemical is the spine identity
verifyEqual(testCase, m.get('statement.variable').name, 'muscimol');
% its value is the formulation document, through value_id; its own value is empty
formId = depVal(m, 'value_id');
verifyNotEmpty(testCase, formId, 'the bath must take its value through value_id');
form = []; chem = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), formId); form = out.migrated{k}; end
end
verifyNotEmpty(testCase, form);
if ~isempty(form)
    verifyEqual(testCase, form.get('document_class.class_name'), 'formulation');
    chemId = depVal(form, 'ingredient_id');
    for k = 1:numel(out.migrated)
        if strcmp(out.migrated{k}.get('base.id'), chemId); chem = out.migrated{k}; end
    end
    % the mixture row's amount rides on the formulation's ingredient entry
    verifyEqual(testCase, form.get('formulation.value').ingredients(1).concentration.source_value, 5);
end
verifyNotEmpty(testCase, chem, 'the formulation must name its chemical');
if ~isempty(chem)
    verifyEqual(testCase, chem.get('chemical.value').substance.name, 'muscimol');
end
% the anchor is an ordinal relative_time_reference (#88; it was a
% session_relative_reference with relation 'during')
anchor = firstOfClassJ(out.migrated, 'relative_time_reference');
verifyNotEmpty(testCase, anchor);
rel = anchor.get('relative_time_reference.value').relation;
verifyEqual(testCase, rel.name, 'intervalDuring');
% the bath location is carried as a term_observation (not dropped)
locObs = firstOfClassJ(out.migrated, 'observation+term');
verifyNotEmpty(testCase, locObs);
verifyEqual(testCase, locObs.get('term.value').name, 'CNS');
verifyEqual(testCase, depVal(locObs, 'entity_id'), subjId);
end

function testDeferredGenericBathHasNoLocationObservation(testCase)
% "A statement about the whole subject (a whole-prep or whole-slice bath, i.e.
% the generic 'bath' location NCIm:C0179246) targets the subject" (Jess Haley,
% 2026-10-21): the generic bath is no site on the subject, so no `anatomical
% location` observation is emitted and the NDI second pass has nothing to
% promote. Dabrowska writes this location on every bath
% (dabrowska_bathtargets.json), with the name 'Baths, Water, Laboratory'.
subjId = 'aabb1122ccdd3344_5500000000000011';
stimId = 'aabb1122ccdd3344_5500000000000012';
elem = struct();
elem.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
elem.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
elem.base = struct('id', stimId, 'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'stimulator', 'datestamp', '2024-06-01T12:00:00.000Z');
% a stimulator element is an ndi.probe.timeseries.stimulator (NDI
% probetype2object.json): [element types have no default] makes a probe type a
% device only on an ndi.probe.* class (Jess Haley, 2026-10-26)
elem.element = struct('ndi_element_class', 'ndi.probe.timeseries.stimulator', 'name', 'bath_x', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);
for loc = {struct('ontologyNode', 'NCIm:C0179246', 'name', 'Baths, Water, Laboratory'), ...
           struct('ontologyNode', '', 'name', 'bath')}
    bath = struct();
    bath.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
        'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                          struct('class_name', 'epochid', 'class_version', '1.0.0')]);
    bath.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
    bath.base = struct('id', 'aabb1122ccdd3344_5500000000000014', ...
        'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
        'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
    bath.epochid = struct('epochid', 'epoch_t00001');
    bath.stimulus_bath = struct('location', loc{1}, ...
        'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');
    out = did2.convert.v1_to_v2({jsonencode(elem), jsonencode(bath)}, ...
        'Validate', false, 'TargetVersion', 'V_eta');
    out = did2.convert.resolveDeferredBaths(out, 'Validate', false, ...
        'TargetVersion', 'V_eta');
    verifyEqual(testCase, nLeafJ(out.migrated, 'manipulation+formulation'), 1);
    verifyEmpty(testCase, firstOfClassJ(out.migrated, 'observation+term'), ...
        sprintf('the generic bath (%s) is no site on the subject', loc{1}.name));
    m = firstOfClassJ(out.migrated, 'manipulation+formulation');
    verifyEqual(testCase, depVal(m, 'entity_id'), subjId, ...
        'the generic bath is about the whole subject');
end
end

function testDeferredBathKeepsItsStimulatorAndItsEpoch(testCase)
% Decided by Jess Haley, 2026-10-27 [one bath shape] (did-schema
% V_eta_go_forward_class_audit.md): DID's bath step keeps the bath's link to
% its stimulator and to its epoch, in the shape NDI-matlab's
% ndi.migrate.internal.stimulusBathToBath writes: the stimulator is the
% manipulation's `instrument_id`, and the anchor, built "during the session",
% is re-pointed at the epoch entity once epochMint holds it (NDI's
% epochAnchorFold), with the stimulator's clock, its id preserved.
subjId = 'aabb1122ccdd3344_5500000000000021';
stimId = 'aabb1122ccdd3344_5500000000000022';
sessId = 'aabb1122ccdd3344_9900aabbccddeeff';
epochId = 'aabb1122ccdd3344_55000000000000e1';
elem = struct();
elem.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
elem.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
elem.base = struct('id', stimId, 'session_id', sessId, ...
    'name', 'stimulator', 'datestamp', '2024-06-01T12:00:00.000Z');
elem.element = struct('ndi_element_class', 'ndi.probe.timeseries.stimulator', 'name', 'bath_y', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);
% the stimulator's element_epoch for that epoch: its clock (+ndi/element.m)
ee = struct();
ee.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
ee.depends_on = struct('name', {'element_id'}, 'value', {stimId});
ee.base = struct('id', 'aabb1122ccdd3344_5500000000000023', 'session_id', sessId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
ee.epochid = struct('epochid', 'epoch_t00007');
ee.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0 10]);
bath = struct();
bath.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
bath.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
bath.base = struct('id', 'aabb1122ccdd3344_5500000000000024', 'session_id', sessId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
bath.epochid = struct('epochid', 'epoch_t00007');
bath.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'NCIm:C0179246', 'name', 'Baths, Water, Laboratory'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');

out = did2.convert.v1_to_v2({jsonencode(elem), jsonencode(ee), jsonencode(bath)}, ...
    'Validate', false, 'TargetVersion', 'V_eta');
out = did2.convert.resolveDeferredBaths(out, 'Validate', false, 'TargetVersion', 'V_eta');
rep = out.deferred_bath_resolution;
verifyEqual(testCase, rep.baths_resolved, 1);
verifyEqual(testCase, rep.baths_with_instrument, 1);
verifyEqual(testCase, rep.bath_anchors_handed_over, 1);
verifyEqual(testCase, rep.bath_clocks_from_element_epoch, 1, ...
    'the clock was not read off the stimulator''s element_epoch');
m = firstOfClassJ(out.migrated, 'manipulation+formulation');
assertNotEmpty(testCase, m);
% THE STIMULATOR LINK: instrument_id, as NDI's vetaBath ('InstrumentId')
verifyEqual(testCase, depVal(m, 'instrument_id'), stimId);
anchorId = depVal(m, 'time_reference_id');
a = out.deferred_bath_anchors;
assertEqual(testCase, numel(a), 1);
verifyEqual(testCase, a.anchor_id, anchorId);
verifyEqual(testCase, a.epoch_string, 'epoch_t00007');
verifyEqual(testCase, a.epoch_clock, 'dev_local_time');

% THE EPOCH: epochMint holds the epoch entity for (session, string) and
% re-points the anchor at it (an existing entity here: the find half)
epochType = did2.convert.registeredTerm( ...
    did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch');
e = did2.build.document('entity', ...
    struct('type', epochType, 'local_identifier', 'epoch_t00007'), ...
    'Id', epochId, 'SessionId', sessId, ...
    'CreationTimestamp', '2024-06-01T12:00:00.000Z', 'Validate', false);
out.migrated{end+1} = did2.document(e);
out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.epoch_mint.bath_anchors_handed_over, 1);
verifyEqual(testCase, out.epoch_mint.bath_anchors_repointed, 1);
anchor = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('base.id'), anchorId); anchor = out.migrated{k}; end
end
assertNotEmpty(testCase, anchor, 'the anchor left the batch');
verifyEqual(testCase, anchor.get('document_class.class_name'), 'relative_time_reference');
verifyEqual(testCase, depVal(anchor, 'referent_id'), epochId, 'the anchor does not name the epoch');
v = anchor.get('relative_time_reference.value');
verifyEqual(testCase, v.relation.name, 'intervalDuring');
verifyEqual(testCase, v.clock.name, 'dev_local_time');
% the bath still names the same anchor (id preserved)
m = firstOfClassJ(out.migrated, 'manipulation+formulation');
verifyEqual(testCase, depVal(m, 'time_reference_id'), anchorId);
end

% ============ metadata_editor -> dataset + entities + relations =========

function ds = allOfClassJ(migrated, className)
ds = {};
for k = 1:numel(migrated)
    if strcmp(migrated{k}.get('document_class.class_name'), className) ...
            || strcmp(did2.unittest.helpers.classKey(migrated{k}), className)
        ds{end+1} = migrated{k}; %#ok<AGROW>
    end
end
end

function v1 = metadataEditorDoc()
% A representative metadata_editor: the NDIMetaDataEditorApp `metadata_structure`
% blob (built by metadata_ds_core.convertDatasetInfoToDocument). Nested field
% names are PascalCase and are LEFT UNTOUCHED by universalRenames (only immediate
% block-field names are snake-cased), so the migrator reads them as-is.
v1 = struct();
v1.document_class = struct('class_name', 'metadata_editor', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'me_01', 'session_id', 'sess_09', ...
    'name', 'ds_meta', 'datestamp', '2024-06-01T12:00:00.000Z');
ms = struct();
ms.DatasetFullName = 'The Big Worm Dataset';
ms.DatasetShortName = 'BigWorm';
ms.VersionIdentifier = '1.0.0';
ms.Description = 'A dataset of worms.';
ms.License = 'CC-BY-4.0';
ms.ReleaseDate = '2024-01-15';
ms.VersionInnovation = 'first release';        % bucket 1 (dataset metadata) -> kept
ms.Keyword = {'worm', 'calcium imaging'};      % bucket 1 (repeatable) -> kept
ms.ExperimentalApproach = {'electrophysiology', 'behavior'};  % -> term assertions ([dataset form terms])
% two authors, both affiliated to the SAME organization (dedup to one org)
a1 = struct('givenName', 'Ada', 'familyName', 'Lovelace', ...
    'digitalIdentifier', struct('identifier', '0000-0001-2345-6789'), ...
    'contactInformation', struct('email', 'ada@example.org'), ...
    'affiliation', struct('memberOf', struct('fullName', 'Analytical Society')), ...
    'authorRole', '');   % a role is read by no migrator: since the raw-v1
                         % switch a stated one carries the form (testRawV1RoundTripSession)
a2 = struct('givenName', 'Alan', 'familyName', 'Turing', ...
    'digitalIdentifier', struct('identifier', ''), ...
    'contactInformation', struct('email', ''), ...
    'affiliation', struct('memberOf', struct('fullName', 'Analytical Society')), ...
    'authorRole', '');
ms.Author = [a1 a2];
ms.Funding = struct('funder', 'NIH', 'awardTitle', 'BRAIN Initiative', ...
    'awardNumber', 'R01-12345');
ms.RelatedPublication = struct('Publication', 'On Worms', 'DOI', '10.1/worm', ...
    'PMID', '123', 'PMCID', 'PMC9');
ms.FullDocumentation = 'https://example.org/docs';
ms.TechniquesEmployed = 'patch clamp';     % -> a Technique assertion, openMINDS term
% subjects: a non-empty list carries the form ([dataset form lists carried
% until homed], testANonEmptyFormListCarriesTheForm); none here
ms.Subjects = [];
v1.metadata_editor = struct('metadata_structure', ms);
end

function testANonEmptyFormListCarriesTheForm(testCase)
% [dataset form lists carried until homed] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): a dataset form whose subject,
% species, strain or sex list is non-empty is carried whole as v1 with a
% needs-home register row (carry-105), not dropped.
lists = {'Subjects', struct('SubjectName', 'worm_1', 'BiologicalSexList', 'male'); ...
    'SpeciesList', struct('name', 'Caenorhabditis elegans', 'preferredOntologyIdentifier', 'NCBITaxon:6239'); ...
    'StrainList', struct('name', 'N2'); ...
    'BiologicalSexList', 'hermaphrodite'};
for k = 1:size(lists, 1)
    v1 = metadataEditorDoc();
    v1.metadata_editor.metadata_structure.(lists{k, 1}) = lists{k, 2};
    v1 = jsondecode(jsonencode(v1));
    out = runJ(v1);
    verifyCarriedWholeAsV1(testCase, v1, out);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, contains(d, ['[carry-105] ' ...
        'awaiting_home: ' lists{k, 1}]), d);
end
% an empty list states nothing: the form converts
out = runJ(jsondecode(jsonencode(metadataEditorDoc())));
verifyEmpty(testCase, out.passthrough);
end

function testMetadataEditorDecomposes(testCase)
% UPDATED for did-schema #88: every thing the editor names is an `entity` with a
% type (dataset, person, organization, funding, publication, protocol); the
% dataset's and each person's own attributes become assertions ABOUT that
% entity (abbreviation, version number, version innovation, License, release
% date, Keyword; given name, family name, E-mail Address). The documentation
% link is a `protocol` entity (#88 has no web_resource). Experimental approach,
% techniques and subjects are still not stored (projections).
out = runJ(metadataEditorDoc());
m = out.migrated;
% 8 entities + 14 assertions + 8 relations
verifyEqual(testCase, numel(m), 30);   % + 3 dataset form term assertions ([dataset form terms])
verifyEqual(testCase, nLeafJ(m, 'dataset'), 1);
verifyEqual(testCase, nLeafJ(m, 'person'), 2);
verifyEqual(testCase, nLeafJ(m, 'organization'), 2);   % Analytical Society (deduped) + NIH
verifyEqual(testCase, nLeafJ(m, 'funding'), 1);
verifyEqual(testCase, nLeafJ(m, 'publication'), 1);
verifyEqual(testCase, nLeafJ(m, 'protocol'), 1);
verifyEqual(testCase, nLeafJ(m, 'directed_relation'), 8);
verifyEqual(testCase, out.summary.by_class.assertion, 14);
% no subject is minted and nothing about the editor's Subjects is asserted
verifyEqual(testCase, nLeafJ(m, 'organism'), 0);
ds = firstOfClassJ(m, 'dataset');
for k = 1:numel(m)
    if strcmp(m{k}.get('document_class.class_name'), 'assertion')
        verifyTrue(testCase, any(strcmp(depVal(m{k}, 'entity_id'), ...
            [{ds.get('base.id')}, cellfun(@(p) p.get('base.id'), allOfClassJ(m, 'person'), ...
            'UniformOutput', false)])), 'an assertion is about something the editor named');
    end
end
end


function testMetadataEditorDatasetEntity(testCase)
% UPDATED for #88: the dataset is an entity (name, description) whose id is the
% session id, and its other attributes are assertions about it.
out = runJ(metadataEditorDoc());
ds = firstOfClassJ(out.migrated, 'dataset');
id = ds.get('base.id');
verifyEqual(testCase, id, 'sess_09');
verifyEqual(testCase, ds.get('entity.name'), 'The Big Worm Dataset');
verifyEqual(testCase, ds.get('entity.description'), 'A dataset of worms.');
verifyEqual(testCase, textAboutJ(out.migrated, id, 'Abbreviation'), {'BigWorm'});
verifyEqual(testCase, textAboutJ(out.migrated, id, 'version number'), {'1.0.0'});
verifyEqual(testCase, textAboutJ(out.migrated, id, 'version innovation'), {'first release'});
lic = assertionAboutJ(out.migrated, id, 'License');
% [migrator writes the registry spelling] (Jess Haley, 2026-10-26): the SPDX id
% is the node, and a licence the registry holds carries the registry's label
verifyEqual(testCase, lic.get('term.value').node, 'spdx:CC-BY-4.0');
reg = did2.convert.registeredTerm('spdx:CC-BY-4.0', '');
if isempty(reg.name)
    verifyEqual(testCase, lic.get('term.value').name, 'CC-BY-4.0');
else
    verifyEqual(testCase, reg.name, 'Creative Commons Attribution 4.0 International');
    verifyEqual(testCase, lic.get('term.value').name, reg.name);
end
rd = assertionAboutJ(out.migrated, id, 'release date');
verifyEqual(testCase, rd.get('date.value').instant, '2024-01-15');
kw = textAboutJ(out.migrated, id, 'Keyword');
verifyEqual(testCase, sort(kw), {'calcium imaging', 'worm'});
% INVERTED 2026-10-26 (they were dropped as projections): [dataset form terms]
% (Jess Haley, 2026-10-25) -- term assertions about the dataset entity, each value
% a term of the binding's closed list
ea = assertionAboutJ(out.migrated, id, 'experimental approach');
assertNotEmpty(testCase, ea);
verifyTrue(testCase, startsWith(char(ea.get('term.value').node), 'ILX:'));
te = assertionAboutJ(out.migrated, id, 'Technique');
assertNotEmpty(testCase, te);
verifyEqual(testCase, char(te.get('term.value').node), 'openminds:technique/patchClamp');
end

function testADatasetFormValueOutsideTheClosedListCarriesTheForm(testCase)
% [dataset form terms]: "A form value that is not in the list carries the form
% whole as v1 rather than being dropped." Soph's "derivedData" is openMINDS's own
% id for semanticDataType derivedData, so it is in the list.
v1 = metadataEditorDoc();
v1.metadata_editor.metadata_structure.DataType = 'derivedData';
out = runJ(v1);
dt = assertionAboutJ(out.migrated, 'sess_09', 'Scientific Data Type');
assertNotEmpty(testCase, dt);
verifyEqual(testCase, char(dt.get('term.value').node), 'openminds:semanticDataType/derivedData');
v1.metadata_editor.metadata_structure.TechniquesEmployed = 'interpretive dance';
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, contains(d, 'interpretive dance'), d);
end


function testAFormFieldWithNoBindingInTheLoadedSchemaFailsLoudly(testCase)
% [pipeline defects are not carries] (Jess Haley, 2026-10-26, did-schema
% V_eta_go_forward_class_audit.md): a form field whose binding the LOADED
% SCHEMA lacks is a pipeline defect, not a fact about the v1 document. It used
% to carry the form whole as v1 (with no carry register row); now the run fails
% loudly, naming the missing binding. The schema here is a copy of the loaded
% one without its binding registry.
src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
copyfile(fullfile(src, '*.json'), tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
if isfile(fullfile(tmp, 'binding_registry_meta.json'))
    delete(fullfile(tmp, 'binding_registry_meta.json'));
end
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
v1 = metadataEditorDoc();
verifyError(testCase, @() did2.convert.migrators_j.metadata_editor(v1), ...
    'did2:convert:schemaTooOld');
try
    did2.convert.migrators_j.metadata_editor(v1);
catch err
    verifySubstring(testCase, err.message, 'loaded schema is too old');
    verifySubstring(testCase, err.message, 'EMPTY:0000356');   % ExperimentalApproach
end
% through the pipeline: a quarantine with that identifier, never a carry
out = runJ(v1);
assertEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:schemaTooOld');
verifyFalse(testCase, isfield(out.summary.migration_notes, 'carried_as_v1'), ...
    'a schema defect is not a carry');
end

function testMetadataEditorAuthorWithTwoAffiliationsIsCarriedWholeAsV1(testCase)
% [generic stage is lossless] / [partly placed is carried as v1] (Jess Haley,
% 2026-10-25): only a scalar affiliation was read, so an author with two lost
% both (the header's "OPEN" note). The document is now carried whole as v1.
v1 = metadataEditorDoc();
two = struct('memberOf', {struct('fullName', 'Analytical Society'), ...
    struct('fullName', 'Royal Society')});
v1.metadata_editor.metadata_structure.Author(1).affiliation = two;
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
authors = out.migrated{1}.get('metadata_editor.metadata_structure.Author');
verifyEqual(testCase, numel(authors(1).affiliation), 2);
end

function testMetadataEditorEthicsAssessmentIsTheJurisdiction(testCase)
% Jess Haley 2026-10-22 [ethics assessment to jurisdiction]
% (V_eta_term_registry_plan.md): the editor's EthicsAssessment becomes an
% `ethics jurisdiction` (EMPTY:0000359) assertion about the dataset, through
% did2.convert.ethicsJurisdiction; the obsolete EMPTY:0000355 `ethics
% assessment` is never written. "EU compliant +" is the European Union with the
% "+" kept as a note; "US compliant" the United States. INVERTED 2026-10-25
% for "not required" (and any other value): it made no statement and was
% dropped; since [generic stage is lossless] / [partly placed is carried as
% v1] (Jess Haley) the whole metadata_editor document is carried as v1.
values = {'EU compliant', 'EU compliant +', 'US compliant', 'not required'};
nodes = {'wikidata:Q458', 'wikidata:Q458', 'wikidata:Q30', ''};
for k = 1:numel(values)
    v1 = metadataEditorDoc();
    v1.metadata_editor.metadata_structure.EthicsAssessment = values{k};
    out = runJ(v1);
    if isempty(nodes{k})
        verifyCarriedWholeAsV1(testCase, v1, out);
        verifyEqual(testCase, out.migrated{1}.get( ...
            'metadata_editor.metadata_structure.EthicsAssessment'), values{k});
        continue;
    end
    m = out.migrated;
    id = firstOfClassJ(m, 'dataset').get('base.id');
    hits = {};
    for j = 1:numel(m)
        d = m{j};
        txt = jsonencode(d.toStruct());
        verifyFalse(testCase, contains(txt, 'EMPTY:0000355'), ...
            sprintf('%s: the obsolete ethics assessment term is written', values{k}));
        if strcmp(d.get('document_class.class_name'), 'assertion') ...
                && strcmp(depVal(d, 'entity_id'), id)
            var = d.get('statement.variable');
            verifyFalse(testCase, strcmpi(char(var.name), 'ethics assessment'), values{k});
            if strcmp(termNodeJ(var), 'EMPTY:0000359')
                hits{end+1} = d; %#ok<AGROW>
            end
        end
    end
    assertEqual(testCase, numel(hits), 1, sprintf('%s: one jurisdiction', values{k}));
    verifyEqual(testCase, hits{1}.get('term.value').node, nodes{k}, values{k});
    if contains(values{k}, '+')
        verifySubstring(testCase, hits{1}.get('statement.notes'), ...
            'additional ethics assessment');
    end
end
end


function testMetadataEditorAuthorsAndOrcid(testCase)
% UPDATED for #88: a person is an entity named 'given family', its ORCID a
% `ORCID:` global identifier; given name, family name and e-mail are assertions
% about it; authorship is has_author (dataset -> person) with an order
% (`directed_relation.order`, `sequence` until did-schema T20).
out = runJ(metadataEditorDoc());
persons = allOfClassJ(out.migrated, 'person');
verifyEqual(testCase, numel(persons), 2);
ada = personByFamily(persons, 'Lovelace');
verifyEqual(testCase, textAboutJ(out.migrated, ada.get('base.id'), 'given name'), {'Ada'});
verifyEqual(testCase, textAboutJ(out.migrated, ada.get('base.id'), 'E-mail Address'), {'ada@example.org'});
gid = cellstr(ada.get('entity.global_identifier'));
verifyEqual(testCase, gid, {'ORCID:0000-0001-2345-6789'});
alan = personByFamily(persons, 'Turing');
verifyEmpty(testCase, globalIdsJ(alan));
ds = firstOfClassJ(out.migrated, 'dataset');
seqs = [];
adaOrder = [];
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(did2.build.vocabularyHandle('relation', d.get('directed_relation.relation')), 'has_author')
        verifyEqual(testCase, depVal(d, 'child_id'), ds.get('base.id'));
        seqs(end+1) = d.get('directed_relation.order'); %#ok<AGROW>
        verifyFalse(testCase, isfield(d.documentProperties.directed_relation, 'sequence'));
        if strcmp(depVal(d, 'parent_id'), ada.get('base.id'))
            adaOrder = d.get('directed_relation.order');
        end
    end
end
% UPDATED 2026-10-21. Decided by Jess Haley, 2026-10-21 [author order from 0]
% (did-schema V_eta_study_plan.md): "the first author is `order: 0`". Was [1 2].
verifyEqual(testCase, sort(seqs), [0 1]);
verifyEqual(testCase, adaOrder, 0, 'Ada is the first author in the source');
end


function p = personByFamily(persons, family)
% #88: a person entity is named 'given family'
p = [];
for k = 1:numel(persons)
    if endsWith(char(persons{k}.get('entity.name')), [' ' family]); p = persons{k}; return; end
end
end


function testMetadataEditorOrgDedupAndAffiliation(testCase)
% One organization per distinct name, and both authors' affiliated_with point at
% the same one. UPDATED for #88: an organization is an entity; its name is
% entity.name.
out = runJ(metadataEditorDoc());
orgs = allOfClassJ(out.migrated, 'organization');
names = cellfun(@(o) o.get('entity.name'), orgs, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'Analytical Society')), 1);
verifyEqual(testCase, sum(strcmp(names, 'NIH')), 1);
society = orgs{strcmp(names, 'Analytical Society')};
affParents = {};
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(did2.build.vocabularyHandle('relation', d.get('directed_relation.relation')), 'affiliated_with')
        affParents{end+1} = depVal(d, 'parent_id'); %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(affParents), 2);
verifyEqual(testCase, unique(affParents), {society.get('base.id')});
end


function testMetadataEditorFundingPublicationDocumentation(testCase)
% UPDATED for #88: the award is a `funding` entity (title -> entity.name, award
% number -> entity.local_identifier); the publication's DOI/PMID/PMCID are
% CURIE global identifiers; the documentation URL is a `protocol` entity whose
% global identifier is the URL.
out = runJ(metadataEditorDoc());
ds = firstOfClassJ(out.migrated, 'dataset');
award = firstOfClassJ(out.migrated, 'funding');
verifyEqual(testCase, award.get('entity.name'), 'BRAIN Initiative');
verifyEqual(testCase, award.get('entity.local_identifier'), 'R01-12345');
funded = relByName(out.migrated, 'funded_by');
verifyEqual(testCase, depVal(funded, 'child_id'), ds.get('base.id'));
verifyEqual(testCase, depVal(funded, 'parent_id'), award.get('base.id'));
issued = relByName(out.migrated, 'issued_by');
verifyEqual(testCase, depVal(issued, 'child_id'), award.get('base.id'));
pub = firstOfClassJ(out.migrated, 'publication');
verifyEqual(testCase, pub.get('entity.name'), 'On Worms');
verifyEqual(testCase, sort(globalIdsJ(pub)), sort({'doi:10.1/worm', 'PMID:123', 'PMCID:PMC9'}));
cites = relByName(out.migrated, 'cites');
verifyEqual(testCase, depVal(cites, 'parent_id'), pub.get('base.id'));
wr = firstOfClassJ(out.migrated, 'protocol');
verifyEqual(testCase, globalIdsJ(wr), {'https://example.org/docs'});
documented = relByName(out.migrated, 'documented_by');
verifyEqual(testCase, depVal(documented, 'child_id'), ds.get('base.id'));
verifyEqual(testCase, depVal(documented, 'parent_id'), wr.get('base.id'));
end


% ---- metadata_editor THROUGH A JSON ROUND TRIP -------------------------
%
% STATUS 2026-08-11: the five tests below
%   testMetadataEditorSurvivesTheJsonRoundTrip
%   testMetadataEditorAuthorsSurviveTheCellDecode
%   testMetadataEditorFundingAndPublicationSurviveTheCellDecode
%   testMetadataEditorEmptyStructureStillYieldsTheUnnamedDataset
%   testMetadataEditorStructureInsideACellIsStillRead
% and the `runJRoundTrip` helper were WRITTEN WITHOUT MATLAB -- there is neither
% MATLAB nor Octave in the container they were authored in, and NONE OF THEM
% HAS BEEN EXECUTED. Their mutation sensitivity was checked by transcribing
% jsondecode's documented array rule together with the two readers changed in
% migrators_j/metadata_editor.m (getScalarStruct, getStructArray); that is a
% transcription, not a run. CI is the gate.
%
% WHY THEY EXIST. Every other fixture in this file hands `v1_to_v2` a
% hand-written MATLAB struct. A CORPUS body is raw JSON text
% (helpers/runCorpusDiscovery.m:59 `fileread`) that ensureStruct pushes
% through `jsondecode` (v1_to_v2.m:332-341), and jsondecode does NOT return a
% struct array for every JSON array of objects: it returns a CELL unless all
% the objects carry the same field names in the same order. `getStructArray`
% used to answer `struct([])` for a cell, so the Author / Funding /
% RelatedPublication loops ran zero times and the migrator emitted a lone
% `dataset` -- with no error and no counter, and invisible to all four
% detectors (unconverted_by_class sees output ~= input, isFragment sees a
% substantive dataset, the empty-required-edge census sees no edges because
% dataset/person declare `depends_on: []`, and the vacuous-required-field
% census was defeated by the old `(unnamed dataset)` fallback). A struct fixture
% cannot see any of that. The round trip is the point of these tests, so do
% NOT "simplify" them by dropping the jsonencode/jsondecode pair.
%
% TRANSCRIBED MUTATION RESULT (guard reverted to the struct-only readers vs
% the readers as committed). NOT a MATLAB run -- see the STATUS above.
%
%   DENOMINATOR: 5 tests, each evaluated twice
%   test                                  mutated -> guarded   sensitive?
%   SurvivesTheJsonRoundTrip              16 -> 16             no, by design
%   AuthorsSurviveTheCellDecode            9 -> 16   person 0 -> 2      YES
%   FundingAndPublicationSurvive...       10 -> 22   funding 0 -> 2,
%                                                    publication 0 -> 2 YES
%   EmptyStructureYieldsADataset...        1 ->  1             no, by design
%   StructureInsideACellIsStillRead        1 -> 16             YES
%
% The two insensitive ones are PINS, not proofs: the baseline pins that the
% round trip alone changes nothing, and the empty-structure one pins that the
% NDI template's own default yields one dataset with no invented name.

function out = runJRoundTrip(v1)
%RUNJROUNDTRIP Run the migrator on the shape the CORPUS delivers, not the
%   shape a MATLAB fixture is written in: serialise the fixture and decode it
%   back exactly as `v1_to_v2/ensureStruct` does for a corpus file.
out = did2.convert.v1_to_v2(jsondecode(jsonencode(v1)), ...
    'Validate', false, 'TargetVersion', 'V_eta');
end

function n = countRelsByName(migrated, relName)
n = 0;
for k = 1:numel(migrated)
    d = migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(did2.build.vocabularyHandle('relation', d.get('directed_relation.relation')), relName)
        n = n + 1;
    end
end
end

function testMetadataEditorSurvivesTheJsonRoundTrip(testCase)
% The decomposition is unchanged by a jsonencode/jsondecode round trip.
% UPDATED for #88 (entity types, assertions; 27 documents).
out = runJRoundTrip(metadataEditorDoc());
m = out.migrated;
verifyEqual(testCase, numel(m), 30);   % + 3 dataset form term assertions ([dataset form terms])
verifyEqual(testCase, nLeafJ(m, 'dataset'), 1);
verifyEqual(testCase, nLeafJ(m, 'person'), 2);
verifyEqual(testCase, nLeafJ(m, 'organization'), 2);
verifyEqual(testCase, nLeafJ(m, 'funding'), 1);
verifyEqual(testCase, nLeafJ(m, 'publication'), 1);
verifyEqual(testCase, nLeafJ(m, 'protocol'), 1);
verifyEqual(testCase, nLeafJ(m, 'directed_relation'), 8);
ds = firstOfClassJ(m, 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'sess_09');
verifyEqual(testCase, ds.get('entity.name'), 'The Big Worm Dataset');
verifyEqual(testCase, sort(textAboutJ(m, 'sess_09', 'Keyword')), {'calcium imaging', 'worm'});
ada = personByFamily(allOfClassJ(m, 'person'), 'Lovelace');
verifyNotEmpty(testCase, ada);
verifyEqual(testCase, textAboutJ(m, ada.get('base.id'), 'E-mail Address'), {'ada@example.org'});
end


function v1 = metadataEditorDocCellShapedAuthors()
% Two authors whose objects DIFFER IN FIELD ORDER, which is one of the two
% documented triggers for jsondecode returning a cell instead of a struct
% array (the other is a differing field-name set; author 2 also omits
% `authorRole`, so both triggers are present). Author 1 is written in the
% order ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem
% produces (affiliation, contactInformation, digitalIdentifier, familyName,
% givenName, authorRole). Assigned as a CELL because a MATLAB struct array
% cannot hold elements with different fields -- and a cell is precisely what
% comes back out of jsondecode.
v1 = metadataEditorDoc();
ms = v1.metadata_editor.metadata_structure;
a1 = struct( ...
    'affiliation',        struct('memberOf', struct('fullName', 'Analytical Society')), ...
    'contactInformation', struct('email', 'ada@example.org'), ...
    'digitalIdentifier',  struct('identifier', '0000-0001-2345-6789'), ...
    'familyName',         'Lovelace', ...
    'givenName',          'Ada', ...
    'authorRole',         '');   % a stated role carries the form (see metadataEditorDoc)
a2 = struct( ...
    'givenName',          'Alan', ...
    'familyName',         'Turing', ...
    'contactInformation', struct('email', ''), ...
    'digitalIdentifier',  struct('identifier', ''), ...
    'affiliation',        struct('memberOf', struct('fullName', 'Analytical Society')));
ms.Author = {a1, a2};
v1.metadata_editor.metadata_structure = ms;
end

function testMetadataEditorAuthorsSurviveTheCellDecode(testCase)
% Authors given as a cell (heterogeneous structs) decode the same as a struct
% array. UPDATED for #88.
out = runJRoundTrip(metadataEditorDocCellShapedAuthors());
m = out.migrated;
verifyEqual(testCase, numel(m), 30);   % + 3 dataset form term assertions ([dataset form terms])
verifyEqual(testCase, nLeafJ(m, 'person'), 2);
verifyEqual(testCase, nLeafJ(m, 'organization'), 2);      % Analytical Society + NIH
verifyEqual(testCase, countRelsByName(m, 'has_author'), 2);
verifyEqual(testCase, countRelsByName(m, 'affiliated_with'), 2);
persons = allOfClassJ(m, 'person');
ada = personByFamily(persons, 'Lovelace');
verifyNotEmpty(testCase, ada);
verifyEqual(testCase, textAboutJ(m, ada.get('base.id'), 'given name'), {'Ada'});
verifyEqual(testCase, textAboutJ(m, ada.get('base.id'), 'E-mail Address'), {'ada@example.org'});
verifyEqual(testCase, globalIdsJ(ada), {'ORCID:0000-0001-2345-6789'});
alan = personByFamily(persons, 'Turing');
verifyNotEmpty(testCase, alan);
verifyEqual(testCase, textAboutJ(m, alan.get('base.id'), 'given name'), {'Alan'});
verifyEmpty(testCase, globalIdsJ(alan));
orgs = allOfClassJ(m, 'organization');
names = cellfun(@(o) o.get('entity.name'), orgs, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'Analytical Society')), 1);
end


function v1 = metadataEditorDocCellShapedFundingAndPublications()
% The same cell trigger on the other two lists the migrator reads with
% getStructArray. Two funders and two publications, each pair differing in
% field order / field set.
v1 = metadataEditorDoc();
ms = v1.metadata_editor.metadata_structure;
f1 = struct('funder', 'NIH', 'awardTitle', 'BRAIN Initiative', ...
    'awardNumber', 'R01-12345');
f2 = struct('awardTitle', 'Neural Circuits', 'funder', 'NSF');   % no awardNumber
ms.Funding = {f1, f2};
p1 = struct('Publication', 'On Worms', 'DOI', '10.1/worm', ...
    'PMID', '123', 'PMCID', 'PMC9');
p2 = struct('DOI', '10.1/worms-again', 'Publication', 'On Worms, Again');
ms.RelatedPublication = {p1, p2};
v1.metadata_editor.metadata_structure = ms;
end

function testMetadataEditorFundingAndPublicationSurviveTheCellDecode(testCase)
% Funding and publications given as cells decode in full. UPDATED for #88.
out = runJRoundTrip(metadataEditorDocCellShapedFundingAndPublications());
m = out.migrated;
verifyEqual(testCase, nLeafJ(m, 'funding'), 2);
verifyEqual(testCase, nLeafJ(m, 'publication'), 2);
verifyEqual(testCase, nLeafJ(m, 'organization'), 3);      % Analytical Society + NIH + NSF
verifyEqual(testCase, countRelsByName(m, 'funded_by'), 2);
verifyEqual(testCase, countRelsByName(m, 'issued_by'), 2);
verifyEqual(testCase, countRelsByName(m, 'cites'), 2);
verifyEqual(testCase, numel(m), 36);   % 11 entities + 11 assertions + 11 relations + 3 dataset form term assertions ([dataset form terms])
awards = allOfClassJ(m, 'funding');
titles = cellfun(@(a) a.get('entity.name'), awards, 'UniformOutput', false);
verifyEqual(testCase, sort(titles), {'BRAIN Initiative', 'Neural Circuits'});
nsf = awards{strcmp(titles, 'Neural Circuits')};
verifyEmpty(testCase, globalIdsJ(nsf));
pubs = allOfClassJ(m, 'publication');
ptitles = cellfun(@(p) p.get('entity.name'), pubs, 'UniformOutput', false);
again = pubs{strcmp(ptitles, 'On Worms, Again')};
verifyEqual(testCase, globalIdsJ(again), {'doi:10.1/worms-again'});
end


function testMetadataEditorEmptyStructureYieldsADatasetWithNoName(testCase)
% An editor with no structure still yields the dataset entity, with no name:
% [dataset name not invented] (Jess Haley, 2026-10-25) retired the
% '(unnamed dataset)' fallback. INVERTED: this test used to pin that name.
v1 = metadataEditorDoc();
v1.metadata_editor = struct('metadata_structure', []);
out = runJRoundTrip(v1);
verifyEqual(testCase, numel(out.migrated), 1);
ds = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(ds), 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'sess_09');
s = ds.toStruct();    % not stated: the field is absent or empty
verifyTrue(testCase, ~isfield(s.entity, 'name') || isempty(s.entity.name));
end


function testMetadataEditorStructureInsideACellIsStillRead(testCase)
% A structure wrapped in a cell beside other keys is still read. UPDATED for #88.
v1 = metadataEditorDoc();
ms = v1.metadata_editor.metadata_structure;
other = struct('SomeOtherKey', 'ignored');
v1.metadata_editor.metadata_structure = {ms, other};
out = runJRoundTrip(v1);
verifyEqual(testCase, numel(out.migrated), 30);   % + 3 dataset form term assertions ([dataset form terms])
ds = firstOfClassJ(out.migrated, 'dataset');
verifyEqual(testCase, ds.get('entity.name'), 'The Big Worm Dataset');
end


function r = relByName(migrated, relName)
r = [];
for k = 1:numel(migrated)
    d = migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(did2.build.vocabularyHandle('relation', d.get('directed_relation.relation')), relName)
        r = d; return;
    end
end
end

% ============ dataset containers -> entity + relations (D-F) ============

function v1 = datasetRemoteDoc()
v1 = struct();
v1.document_class = struct('class_name', 'dataset_remote', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'dr_01', 'session_id', 'dsid_1', ...
    'name', 'remote', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.dataset_remote = struct('dataset_id', 'd-12345', 'organization_id', 'ndicloud-lab');
end

function testDatasetRemoteDissolves(testCase)
% UPDATED for did-schema #88: the remote copy's cloud id is a CURIE global
% identifier on the dataset entity itself (ndicloud:<id>), and the hosting
% organization is an entity the dataset is hosted_by. #88 has no web_resource,
% so there is no stored_at hop.
out = runJ(datasetRemoteDoc());
m = out.migrated;
verifyEqual(testCase, nLeafJ(m, 'dataset'), 1);
verifyEqual(testCase, nLeafJ(m, 'organization'), 1);
verifyEqual(testCase, nLeafJ(m, 'directed_relation'), 1);   % hosted_by
ds = firstOfClassJ(m, 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'dsid_1');
verifyEqual(testCase, globalIdsJ(ds), {'ndicloud:d-12345'});
hosted = relByName(m, 'hosted_by');
verifyEqual(testCase, depVal(hosted, 'child_id'), 'dsid_1');
org = firstOfClassJ(m, 'organization');
% [cloud organization id is a global identifier] (Decided by Jess Haley,
% 2026-10-27): the v1 organization_id is the NDI Cloud organization's id, so it
% is the organization's global_identifier `ndicloud:<org id>`, not its name; no
% name (no v1 name states one) and no local_identifier
verifyEqual(testCase, globalIdsJ(org), {'ndicloud:ndicloud-lab'});
e = org.get('entity');
verifyFalse(testCase, isfield(e, 'name') && ~isempty(e.name), 'the id is not a name');
verifyFalse(testCase, isfield(e, 'local_identifier') && ~isempty(e.local_identifier));
verifyEqual(testCase, depVal(hosted, 'parent_id'), org.get('base.id'));
end


function v1 = sessionInADatasetDoc(memberSession)
% An INGESTED membership the generic stage places whole: no session_reference
% and no opener class (both open cases carry the document as v1 for now,
% testSessionMembershipOpenCasesAreCarried).
v1 = writerSessionInADatasetDoc(memberSession);
v1.session_in_a_dataset = struct('session_id', memberSession, 'is_linked', 0);
end

function v1 = writerSessionInADatasetDoc(memberSession)
% session_in_a_dataset as NDI's writer fills it.
v1 = struct();
v1.document_class = struct('class_name', 'session_in_a_dataset', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'sid_01', 'session_id', 'dsid_1', ...
    'name', 'sid', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session_in_a_dataset = struct('session_id', memberSession, ...
    'session_reference', 'exp_demo', 'is_linked', 0, ...
    'session_creator', 'ndi.session.dir', 'session_creator_input1', 'exp_demo', ...
    'session_creator_input2', '', 'session_creator_input3', '', ...
    'session_creator_input4', '', 'session_creator_input5', '', ...
    'session_creator_input6', '');
end

function testAnIngestedSessionsMembershipSaysSo(testCase)
% [session membership records linked or ingested] (Jess Haley, 2026-10-25):
% the relation's method.term says how the session joined -- EMPTY:0000399
% "database ingestion" ([census terms]).
out = runJ(sessionInADatasetDoc('member_sess_9'));
rel = firstOfClassJ(out.migrated, 'directed_relation');
assertNotEmpty(testCase, rel);
m = rel.get('relation.method');
verifyEqual(testCase, char(m.term.node), 'EMPTY:0000399');
end

function testALinkedSessionsMembershipKeepsItsOpenerAndPath(testCase)
% A LINKED session: method EMPTY:0000400 "database linking", parameters its
% opener class (EMPTY:0000401 "software class") and its path (NCIT:C47922
% Pathname); an input restating the session id is dropped as a copy.
v1 = sessionInADatasetDoc('member_sess_9');
v1.session_in_a_dataset = struct('session_id', 'member_sess_9', 'is_linked', 1, ...
    'session_creator', 'ndi.session.dir', 'session_creator_input1', '', ...
    'session_creator_input2', '/data/exp_demo', 'session_creator_input3', 'member_sess_9');
out = runJ(v1);
rel = firstOfClassJ(out.migrated, 'directed_relation');
assertNotEmpty(testCase, rel);
m = rel.get('relation.method');
verifyEqual(testCase, char(m.term.node), 'EMPTY:0000400');
p = m.parameters;
if iscell(p); p = [p{:}]; end
nodes = arrayfun(@(x) char(x.variable.node), p, 'UniformOutput', false);
verifyEqual(testCase, sort(nodes), sort({'EMPTY:0000401', 'NCIT:C47922'}));
texts = arrayfun(@(x) char(x.text), p, 'UniformOutput', false);
verifyEqual(testCase, sort(texts), sort({'ndi.session.dir', '/data/exp_demo'}));
end

function testSessionMembershipOpenCasesAreCarried(testCase)
% The open cases carry the document whole as v1 ([generic stage is lossless]):
% an ingested session's `session_reference` whose session is not in the batch
% (it cannot be compared with the session's local_identifier). The linked half
% of this test (a LINKED session's reference was always carried) is INVERTED
% 2026-10-29 into testALinkedSessionsEqualReferenceIsDropped.
v1 = writerSessionInADatasetDoc('member_sess_9');
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyTrue(testCase, contains(out.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
    '[carry-069] session_reference (the session is not in the batch'), ...
    'the note cites its carry register row');
end

function testALinkedSessionsEqualReferenceIsDropped(testCase)
% INVERTED 2026-10-29 from the linked half of
% testSessionMembershipOpenCasesAreCarried (which pinned: a LINKED session's
% reference is carried). [linked session reference follows the ingested rule]
% (Jess Haley, 2026-10-27, did-schema V_eta_go_forward_class_audit.md): "a
% linked session's `session_in_a_dataset.session_reference` is dropped when it
% equals the session entity's `local_identifier`, else carried
% `needs_mapping`" (carry-074).
v1 = writerSessionInADatasetDoc('member_sess_9');
v1.session_in_a_dataset.is_linked = 1;
v1.session_in_a_dataset.session_creator_input2 = '/data/exp_demo';
out = runJ({v1sessionDoc('member_sess_9', 'exp_demo'), v1});
verifyFalse(testCase, isfield(out.summary.migration_notes, 'carried_as_v1'), ...
    'the membership was carried');
rel = firstOfClassJ(out.migrated, 'directed_relation');
assertNotEmpty(testCase, rel);
m = rel.get('relation.method');
verifyEqual(testCase, char(m.term.node), 'EMPTY:0000400');
p = m.parameters;
if iscell(p); p = [p{:}]; end
texts = arrayfun(@(x) char(x.text), p, 'UniformOutput', false);
verifyEqual(testCase, sort(texts), sort({'ndi.session.dir', '/data/exp_demo'}), ...
    'the reference is not a parameter: it is the session entity''s local_identifier');
% differs: carried, carry-074
out = runJ({v1sessionDoc('member_sess_9', 'another_name'), v1});
n = out.summary.migration_notes.carried_as_v1;
verifyEqual(testCase, n.count, 1);
verifyTrue(testCase, contains(n.distinct_details{1}, '[carry-074]'), n.distinct_details{1});
verifyEqual(testCase, n.register_rows, {'carry-074'});
% not in the batch: carried (no register row yet)
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
end

function testAMembershipsOtherOpenerOrLaterInputIsCarried(testCase)
% [session opener inputs] (Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): "a membership whose `session_creator` is
% not `ndi.session.dir` is carried whole as v1, `needs_mapping`" (carry-119);
% "a non-empty `session_creator_input4..6` (never read by NDI-matlab
% `+ndi/dataset.m`) carries the membership whole as v1" (carry-075). Both on
% an ingested and on a linked membership whose session is in the batch.
for linked = [0 1]
    base = writerSessionInADatasetDoc('member_sess_9');
    base.session_in_a_dataset.is_linked = linked;
    v1 = base;
    v1.session_in_a_dataset.session_creator = 'ndi.session.other';
    out = runJ({v1sessionDoc('member_sess_9', 'exp_demo'), v1});
    n = out.summary.migration_notes.carried_as_v1;
    verifyEqual(testCase, n.count, 1);
    verifyTrue(testCase, contains(n.distinct_details{1}, '[carry-119]'), n.distinct_details{1});
    verifyEqual(testCase, n.register_rows, {'carry-119'});
    for k = 4:6
        v1 = base;
        % a copy of the reference is still carried: input 4..6 is never read
        v1.session_in_a_dataset.(sprintf('session_creator_input%d', k)) = 'exp_demo';
        out = runJ({v1sessionDoc('member_sess_9', 'exp_demo'), v1});
        n = out.summary.migration_notes.carried_as_v1;
        verifyEqual(testCase, n.count, 1);
        verifyTrue(testCase, contains(n.distinct_details{1}, ...
            sprintf('[carry-075] session_creator_input%d', k)), n.distinct_details{1});
        verifyEqual(testCase, n.register_rows, {'carry-075'});
    end
end
end

function testAnIngestedSessionsEqualReferenceIsDroppedAndItsCreatorKept(testCase)
% [ingested session membership] (Jess Haley, 2026-10-26): for an INGESTED
% session, `session_reference` equal to the session entity's local_identifier
% is dropped, and the creator class is a "software class" (EMPTY:0000401)
% parameter of the "database ingestion" (EMPTY:0000399) method.
v1 = writerSessionInADatasetDoc('member_sess_9');
out = runJ({v1sessionDoc('member_sess_9', 'exp_demo'), v1});
verifyFalse(testCase, isfield(out.summary.migration_notes, 'carried_as_v1'), ...
    'the membership was carried');
rel = firstOfClassJ(out.migrated, 'directed_relation');
assertNotEmpty(testCase, rel);
m = rel.get('relation.method');
verifyEqual(testCase, char(m.term.node), 'EMPTY:0000399');
p = m.parameters;
if iscell(p); p = [p{:}]; end
verifyEqual(testCase, numel(p), 1);
verifyEqual(testCase, char(p(1).variable.node), 'EMPTY:0000401');
verifyEqual(testCase, char(p(1).text), 'ndi.session.dir');
end

function testAnIngestedSessionsDifferingReferenceIsCarried(testCase)
% [ingested session membership]: a `session_reference` that differs from the
% session entity's local_identifier carries the document as v1 (carry-060).
v1 = writerSessionInADatasetDoc('member_sess_9');
out = runJ({v1sessionDoc('member_sess_9', 'another_name'), v1});
n = out.summary.migration_notes.carried_as_v1;
verifyEqual(testCase, n.count, 1);
verifyTrue(testCase, contains(n.distinct_details{1}, '[carry-060]'), n.distinct_details{1});
verifyEqual(testCase, n.register_rows, {'carry-060'});
end

function v1 = v1sessionDoc(sessionId, reference)
v1 = struct();
v1.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', sessionId, 'session_id', sessionId, ...
    'name', 'sess', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.session = struct('reference', reference);
end

function [name, node] = membershipRelation()
% the record-membership relation as the schema in use spells it: `included_in`
% (schema:isPartOf) where `session_id` is an edge -- the two arrived together
% (did-schema V_eta_relation_inheritance_plan.md, 2026-10-20) -- else `part_of`
if did2.schema.cache.shared().sessionIdIsEdge()
    name = 'included_in'; node = 'schema:isPartOf';
else
    name = 'part_of'; node = '';
end
end

function testSessionInADatasetMembership(testCase)
% UPDATED for #88: the dataset is an entity; membership is the relation
% membershipRelation() names; V_eta writes no base.name (#73 item 54).
out = runJ(sessionInADatasetDoc('member_sess_9'));
verifyEqual(testCase, nLeafJ(out.migrated, 'dataset'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'directed_relation'), 1);
ds = firstOfClassJ(out.migrated, 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'dsid_1');
rel = firstOfClassJ(out.migrated, 'directed_relation');
[relName, relNode] = membershipRelation();
verifyEqual(testCase, did2.build.vocabularyHandle('relation', rel.get('directed_relation.relation')), relName);
verifyEqual(testCase, rel.get('directed_relation.relation').node, relNode);
verifyEqual(testCase, depVal(rel, 'child_id'), 'member_sess_9');   % the member session
verifyEqual(testCase, depVal(rel, 'parent_id'), 'dsid_1');          % the dataset
end


function testDatasetSessionInfoAggregate(testCase)
% INVERTED 2026-10-27 (was: one membership relation per listed session).
% [fit classes kept; session list rebuilt] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): a dataset_session_info "writes
% no V2 document: the round trip rebuilds it from the session entities'
% `included_in` relations to the dataset, and one that does not rebuild
% exactly is carried whole as v1" (carry-118)
info = struct();
info.document_class = struct('class_name', 'dataset_session_info', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
info.depends_on = struct('name', {}, 'value', {});
info.base = struct('id', 'dsi_01', 'session_id', 'dsid_1', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
e1 = struct('session_id', 'member_a', 'is_linked', 0);
e2 = struct('session_id', 'member_b', 'is_linked', 0);
info.dataset_session_info = struct('dataset_session_info', [e1 e2]);
m1 = sessionInADatasetDoc('member_a');
m1.base.id = 'sid_a';
m1.base.name = '';
m2 = sessionInADatasetDoc('member_b');
m2.base.id = 'sid_b';
m2.base.name = '';
% rebuilt exactly by the two memberships: nothing written, nothing carried
out = did2.convert.v1_to_v2({m1, m2, info}, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
ids = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(ids, 'dsi_01')), 'the list writes no V2 document');
verifyFalse(testCase, any(strcmp({out.passthrough.id}, 'dsi_01')), 'not carried');
% alone, another order, or another value: carried whole as v1
v = info;
v.dataset_session_info.dataset_session_info(2).is_linked = 1;
% [a rebuilt document may lose its id] (Decided by Jess Haley, 2026-10-27):
% a list that rebuilds may lose its id only when nothing references it; one
% another document names is carried
ref = struct();
ref.document_class = struct('class_name', 'unknown_class', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
ref.depends_on = struct('name', {'session_list_id'}, 'value', {'dsi_01'});
ref.base = struct('id', 'ref_01', 'session_id', 'dsid_1', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
ref.unknown_class = struct('foo', 'bar');
for c = {{info}, {m2, m1, info}, {m1, m2, v}, {m1, m2, info, ref}}
    batch = c{1};
    out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine);
    hit = strcmp({out.passthrough.id}, 'dsi_01');
    verifyEqual(testCase, nnz(hit), 1, 'carried');
    d = strjoin(cellstr(out.summary.migration_notes.carried_as_v1.distinct_details), ' || ');
    verifyTrue(testCase, contains(d, '[carry-118] awaiting_home: '), d);
end
end


function testResolveDatasetEntitiesDedupAndPrune(testCase)
% Three sources each mint a dataset entity on dsid_1; the batch pass keeps ONE
% (the editor's, which carries a name) and prunes membership edges to sessions
% not in the batch. UPDATED for #88: the dataset is an entity of type dataset.
editor = metadataEditorDoc();                 % base.session_id = sess_09
editor.base.session_id = 'dsid_1';            % put it on the same dataset id
remote = datasetRemoteDoc();                  % base.session_id = dsid_1 (bare stub)
member = sessionInADatasetDoc('absent_sess'); % member session NOT in the batch
batch = {jsonencode(editor), jsonencode(remote), jsonencode(member)};
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
verifyGreaterThan(testCase, nLeafJ(out.migrated, 'dataset'), 1);
out = did2.convert.resolveDatasetEntities(out, 'Validate', false, 'TargetVersion', 'V_eta');
datasets = allOfClassJ(out.migrated, 'dataset');
verifyEqual(testCase, numel(datasets), 1);
verifyEqual(testCase, datasets{1}.get('base.id'), 'dsid_1');
verifyEqual(testCase, datasets{1}.get('entity.name'), 'The Big Worm Dataset');
relName = membershipRelation();
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(did2.build.vocabularyHandle('relation', d.get('directed_relation.relation')), relName)
        verifyNotEqual(testCase, depVal(d, 'child_id'), 'absent_sess');
    end
end
end


function testADatasetsOwnSessionDoesNotDuplicateTheDatasetId(testCase)
% REGRESSION (NDI e2e run 39688367871, NDI:migrate:duplicateIds
% "4126900def47f5c1_40bc968437441768 x2: entity, entity"). A dataset's own
% session has the dataset's id as its session id (NDI: D.id() is the
% base.session_id of everything stored with the dataset), so a v1 `session`
% document stored there makes +migrators_j/session mint a session entity under
% the SAME id as the dataset entity. did-schema base.json `session_id`: "The
% session or dataset this document is stored with: the `entity` document of
% type session or dataset", so that id already has its entity -- the dataset.
% The batch must end with ONE entity per id.
ses = struct();
ses.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
ses.base = struct('id', 'sess_doc_ds', 'session_id', 'dsid_1', ...
    'name', 'ts', 'datestamp', '2024-06-01T12:00:00.000Z');
ses.session = struct('reference', 'the_dataset_session');
remote = datasetRemoteDoc();                    % dataset entity dsid_1
member = sessionInADatasetDoc('dsid_1');        % lists its own session (jMembershipBodies skips it)
batch = {jsonencode(ses), jsonencode(remote), jsonencode(member)};
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
[out, rep] = did2.convert.resolveDatasetEntities(out, 'Validate', false, 'TargetVersion', 'V_eta');
ids = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
[u, ~, j] = unique(ids);
dup = u(accumarray(j(:), 1) > 1);
verifyEmpty(testCase, dup, sprintf('duplicate ids: %s', strjoin(dup, ', ')));
hits = out.migrated(strcmp(ids, 'dsid_1'));
assertEqual(testCase, numel(hits), 1);
verifyEqual(testCase, did2.build.vocabularyHandle('entity_type', hits{1}.get('entity.type')), 'dataset');
verifyEqual(testCase, rep.session_entities_dropped_dataset_id, 1);
% Decided by Jess Haley, 2026-10-22 [dataset session reference]: the dropped
% session's reference becomes the dataset entity's local_identifier
verifyEqual(testCase, char(hits{1}.get('entity.local_identifier')), 'the_dataset_session');
verifyEqual(testCase, rep.dataset_local_identifier_from_session, 1);
verifyEqual(testCase, rep.dataset_local_identifier_conflicts, 0);
% and no relation is left pointing from that id to itself
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation')
        verifyNotEqual(testCase, depVal(d, 'child_id'), depVal(d, 'parent_id'), ...
            'a relation from the dataset to itself');
    end
end
end


function testADifferentDatasetLocalIdentifierIsKeptAndCounted(testCase)
% [dataset session reference], the other direction: "if the dataset already
% has a different `local_identifier`, nothing is overwritten and the conflict
% is counted". Two v1 session documents stored with the dataset: the first
% reference fills the slot, the second differs and is counted, not written.
mk = @(id, ref) struct('document_class', struct('class_name', 'session', ...
        'class_version', '1.0.0', 'superclasses', struct('class_name', {'base'}, ...
        'class_version', {'1.0.0'})), ...
    'base', struct('id', id, 'session_id', 'dsid_1', 'name', 'ts', ...
        'datestamp', '2024-06-01T12:00:00.000Z'), ...
    'session', struct('reference', ref));
batch = {jsonencode(datasetRemoteDoc()), jsonencode(mk('s_a', 'first_ref')), ...
    jsonencode(mk('s_b', 'second_ref'))};
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
[out, rep] = did2.convert.resolveDatasetEntities(out, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, rep.session_entities_dropped_dataset_id, 2, 'DENOMINATOR');
verifyEqual(testCase, rep.dataset_local_identifier_from_session, 1);
verifyEqual(testCase, rep.dataset_local_identifier_conflicts, 1);
ds = allOfClassJ(out.migrated, 'dataset');
assertEqual(testCase, numel(ds), 1);
verifyEqual(testCase, char(ds{1}.get('entity.local_identifier')), 'first_ref', ...
    'the first reference is kept; the second does not overwrite it');
end


% ============ regression: relations carry no stale subject_relation block =====

function testDirectedRelationsHaveNoSubjectRelationBlock(testCase)
% subject_relation was renamed to `relation` (abstract, no fields) -> migrators
% must NOT emit a subject_relation property block, or the doc fails validation
% with "undeclared top-level block subject_relation" and quarantines (the JH
% 163k-orphan regression). Check the element + subject_group relation emitters.
outs = {runJUnit(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1')), ...
        runJ(subjectGroupWithMembers())};
for i = 1:numel(outs)
    for k = 1:numel(outs{i}.migrated)
        d = outs{i}.migrated{k};
        if strcmp(d.get('document_class.class_name'), 'directed_relation')
            verifyError(testCase, @() d.get('subject_relation'), ?MException, ...
                'a directed_relation still carries a subject_relation block');
            supers = d.get('document_class.superclasses');
            verifyEqual(testCase, supers(1).class_name, 'relation');
        end
    end
end
end

function v1 = subjectGroupWithMembers()
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id_1', 'subject_id_2'}, 'value', {'m_1', 'm_2'});
v1.base = struct('id', 'grp_9', 'session_id', 'aa_99', ...
    'name', 'cohortC', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', 'cohortC', 'description', '');
end

function testDaqreaderNdrWithADifferentNdrClassIsCarriedAsV1(testCase)
% [restated values checked] (Jess Haley, 2026-10-26): `ndi_daqreader_ndr_class`
% is dropped only when it restates `daqreader.ndi_daqreader_class` (equal in
% the one Dab document); one that differs is carried whole as v1.
body = struct();
body.document_class = struct('class_name', 'daqreader_ndr', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',      'class_version', '1.0.0'), ...
                      struct('class_name', 'daqreader', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 'ndr_2', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.mfdaq.ndr');
body.daqreader_ndr = struct('ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.other', ...
    'ndr_reader_string', 'intan');
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.daqreader_ndr(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyTrue(testCase, iscell(out) && isscalar(out) && isequaln(out{1}, body), ...
    'returned unchanged');
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
verifyTrue(testCase, contains(notes.carried_as_v1.distinct_details{1}, ...
    'ndi_daqreader_ndr_class'));
end

function testDaqreaderNdrWithAFileExtensionIsCarriedAsV1(testCase)
% [generic stage is lossless] (Jess Haley, 2026-10-25): `file_extension` is
% written nowhere on the V2 output (acquisition_reader declares software_id
% and reader_string only) and restated nowhere, so a document that sets one
% is carried whole as v1 instead of losing it.
body = struct();
body.document_class = struct('class_name', 'daqreader_ndr', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',      'class_version', '1.0.0'), ...
                      struct('class_name', 'daqreader', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 'ndr_3', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.mfdaq.ndr');
body.daqreader_ndr = struct('ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr', ...
    'ndr_reader_string', 'intan', 'file_extension', '.rhd');
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.daqreader_ndr(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyTrue(testCase, iscell(out) && isscalar(out) && isequaln(out{1}, body));
verifyTrue(testCase, isfield(notes, 'carried_as_v1') && ...
    contains(notes.carried_as_v1.distinct_details{1}, 'file_extension'));
end

function testDaqreaderNdrDeEncodesToDaqreader(testCase)
% Chunk c: daqreader_ndr de-encodes onto daqreader -- the ndr subtype fields move
% (ndr_reader_string -> reader_string, ndi_daqreader_ndr_class dropped) and the
% daqreader_ndr block is removed. Tested on the migrator FUNCTION
%
% THIS COMMENT SAID "file_extension carried" AND THIS TEST ASSERTS THE OPPOSITE
% ~29 LINES BELOW. Corrected 2026-08-12. The field is DELETED by the signed
% daq-configuration decision, no V_eta schema declares it (0 of 247), and the
% migrator makes no assignment to it -- every remaining mention in that file is
% a comment. The same wrong clause was in the migrator's own docstring and in
% DID-schema's build_v_eta.py (deleted 2026-10-21), each a few lines from something contradicting it.
% directly (the quick CI's V_zeta schema still has daqreader_ndr; under the V_eta
% corpus run daqreader_ndr is gone and the folded daqreader validates).
body = struct();
body.document_class = struct('class_name', 'daqreader_ndr', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',      'class_version', '1.0.0'), ...
                      struct('class_name', 'daqreader', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 'ndr_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.mfdaq.ndr');
% 2026-10-26: no `file_extension` here; one that is set is carried whole as
% v1, since nothing on the V2 output restates it
% (testDaqreaderNdrWithAFileExtensionIsCarriedAsV1)
body.daqreader_ndr = struct('ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr', ...
    'ndr_reader_string', 'intan');
out = did2.convert.migrators_j.daqreader_ndr(body);
% THE CONTRACT CHANGED 2026-08-13 AND SO DID THESE ASSERTIONS. This used to
% assert the INTERMEDIATE -- a body whose class_name had become `daqreader` --
% and that intermediate was the defect: v1_to_v2 dispatches once on the SOURCE
% class, so nothing ever handed it on to daqreader.m and the document came to
% rest as `daqreader`, a class the signed daq decision retires. daqreader_ndr.m
% now delegates, so the de-encode and the fold are one step and the output is a
% CELL of bodies rather than one struct.
verifyClass(testCase, out, 'cell');
verifyEqual(testCase, numel(out), 2, ...
    'expected the acquisition_reader + its software entity');
reader = out{1};
software = out{2};
% The READER leads and keeps the source id: acquisition_system.reader_id points
% at `acquisition_reader`, and v1 daqsystem.daqreader_id names the v1 daqreader
% document, so this is the body every reader_id edge still resolves to.
verifyEqual(testCase, did2.unittest.helpers.classKey(reader), 'acquisition_reader');
verifyEqual(testCase, reader.base.id, 'ndr_1', ...
    'base.id must be preserved on the reader or reader_id edges dangle');
verifyEqual(testCase, reader.acquisition_reader.reader_string, 'intan');
% The implementation class became a `software` entity with its OWN id -- which
% is what lets the deferred dedup pass merge rigs sharing one class (#25).
verifyEqual(testCase, did2.unittest.helpers.classKey(software), 'software');
verifyEqual(testCase, software.entity.name, 'ndi.daq.reader.mfdaq.ndr');
verifyNotEqual(testCase, software.base.id, reader.base.id);
% The edge is PRESENT and POPULATED, never present-and-blank.
% #88 builders write {name, document_id}; read the edge by name
verifyEqual(testCase, depValue(reader, 'software_id'), software.base.id);
% INVERTED 2026-08-10. This asserted that `file_extension` is carried across.
% It is an INVENTED field -- `git grep -l "file_extension" origin/main --
% '*.m' '*.json'` returns ZERO files, so no NDI template declares it and no
% NDI writer sets it. DID-schema deleted the declaration (4815882), so
% carrying it would emit an undeclared field and quarantine the document.
%
% The DID-schema pytest twin (test_daqreader_ndr_de_encoded) was inverted when
% the field was deleted; this MATLAB twin was missed, and the migrator kept
% copying the field with a test standing guard over the copy. Latent, not live
% -- the source field cannot appear on a real document -- which is exactly why
% it survived. (The fixture SET it until 2026-10-26, when a set extension
% began carrying the document as v1; the sweep below still guards the output.)
% The invented field must not survive ANYWHERE now, which is a stronger claim
% than the old one: it used to be checked on the intermediate's `daqreader`
% block, and that block no longer exists on either emitted body.
verifyFalse(testCase, isfield(reader, 'daqreader'), ...
    'the daqreader block dissolves; it is not carried onto the reader');
for k = 1:numel(out)
    verifyFalse(testCase, isfield(out{k}, 'daqreader_ndr'), ...
        'the subtype block is gone');
    verifyFalse(testCase, isfield(out{k}, 'file_extension'), ...
        'file_extension is invented; carrying it emits an undeclared field');
end
% The implementation class is not LOST by dissolving -- it is the software
% entity's name, which is where the signed decision puts it.
verifyEqual(testCase, software.entity.name, ...   % #88: the one entity class
    'ndi.daq.reader.mfdaq.ndr');
end

function testMfdaqIngestedDeEncodesToDaqreaderEpochdataIngested(testCase)
% Chunk c: daqreader_mfdaq_epochdata_ingested de-encodes onto the generic
% daqreader_epochdata_ingested -- the mfdaq subtype `parameters` block moves onto
% the parent (kept) and the mfdaq block is removed. Tested on the migrator
% FUNCTION directly (the quick CI's V_zeta schema still has the class; under the
% V_eta corpus run the class is gone and the folded parent validates).
%
% THE `epochid` ASSERTION IS INVERTED FROM WHAT IT USED TO BE. This test
% required `epochid` to be ABSENT, on chunk (b)'s premise that "the epoch link is
% the epochid dep". There is no epochid dependency in did_v1 -- all three NDI
% ingest templates declare exactly one, daqreader_id, and epochid is a
% SUPERCLASS whose block holds the epoch-id STRING, set by both concrete
% writers. The migrator was deleting it outright, destroying the only record of
% which epoch the ingested bytes belong to, and this test was pinning that
% behaviour in place. A test written from the same wrong reading as the code
% cannot catch the code.
body = struct();
body.document_class = struct('class_name', 'daqreader_mfdaq_epochdata_ingested', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
        struct('class_name', 'daqreader_epochdata_ingested', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'daqreader_id'}, 'value', {'dr_1'});
body.base = struct('id', 'mfdaq_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0, 10]));
body.daqreader_mfdaq_epochdata_ingested = struct('parameters', ...
    struct('sample_analog_segment', 1000000, 'sample_digital_segment', 1000000));
out = did2.convert.migrators_j.daqreader_mfdaq_epochdata_ingested(body);
verifyEqual(testCase, did2.unittest.helpers.classKey(out), 'daqreader_epochdata_ingested');
% the mfdaq `parameters` de-encoded onto the parent, epochtable preserved
verifyEqual(testCase, out.daqreader_epochdata_ingested.parameters.sample_analog_segment, 1000000);
verifyTrue(testCase, isfield(out.daqreader_epochdata_ingested, 'epochtable'));
% the subtype block is gone
verifyFalse(testCase, isfield(out, 'daqreader_mfdaq_epochdata_ingested'));
% the epochid block SURVIVES -- it is the epoch identity, not a stale duplicate
verifyTrue(testCase, isfield(out, 'epochid'), ...
    'epochid is a did_v1 superclass block, not a dependency -- it must survive');
verifyEqual(testCase, out.epochid.epochid, 't00001');
end

function testElementEpochRenamedToAcquisitionEpoch(testCase)
% Chunk e: element is retired, so element_epoch is renamed to acquisition_epoch.
% The V_eta migrator reuses the base clocks-block transform (epoch_clock/t0_t1 ->
% clocks array-of-records) and then renames the class and its property block.
body = struct();
body.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_1'});
body.base = struct('id', 'ee_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0; 930.35]);
out = did2.convert.migrators_j.element_epoch(body);
verifyEqual(testCase, did2.unittest.helpers.classKey(out), 'acquisition_epoch');
% the property block is renamed too, and the base clocks transform ran
verifyTrue(testCase, isfield(out, 'acquisition_epoch'));
verifyFalse(testCase, isfield(out, 'element_epoch'));
verifyEqual(testCase, out.acquisition_epoch.clocks(1).name, 'dev_local_time');
verifyEqual(testCase, out.acquisition_epoch.clocks(1).t0, 0);
verifyEqual(testCase, out.acquisition_epoch.clocks(1).t1, 930.35);
end

function testDistanceMetadataReshapesFlatEndpoints(testCase)
% The v1 distance_metadata is FLAT (ontologyNode_A/_B, integerIDs_A/_B,
% ontologyStringValues_A/_B, ontologyNumericValues_A/_B empty by design, units).
% The J migrator reshapes it into the nested `endpoints` array the V_eta schema
% requires -- 1 -> 1. It does NOT emit a length_observation (no scalar distance in
% the metadata doc; the value is the linked element's timeseries -- deferred Part
% B) and does NOT mint an endpoint relation (the endpoint ids are pre-migration
% ids that dangle single-doc -- Part A reverted). See
% schemas/V_eta_distance_metadata_plan.md.
v1 = struct();
v1.document_class = struct('class_name', 'distance_metadata', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'dm_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.distance_metadata = struct( ...
    'ontologyNode_A', 'animal_9',   'integerIDs_A', 1, ...
    'ontologyNumericValues_A', [],  'ontologyStringValues_A', 'uid_a1,uid_a2', ...
    'ontologyNode_B', 'patch_9',    'integerIDs_B', [2 3], ...
    'ontologyNumericValues_B', [],  'ontologyStringValues_B', 'uid_b1', ...
    'units', 'NCIT:C48367');

out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(doc), 'distance_metadata');

blk = doc.get('distance_metadata');
% two endpoint records, labelled A and B, in order
verifyEqual(testCase, numel(blk.endpoints), 2);
verifyEqual(testCase, blk.endpoints(1).label, 'A');
verifyEqual(testCase, blk.endpoints(2).label, 'B');
% the ontologyNode CURIE -> measurement.node; comma-split string ids -> array
verifyEqual(testCase, blk.endpoints(1).measurement.node, 'animal_9');
verifyEqual(testCase, blk.endpoints(2).measurement.node, 'patch_9');
verifyEqual(testCase, numel(blk.endpoints(1).string_ids), 2);
verifyEqual(testCase, blk.endpoints(2).integer_ids, [2 3]);
% units CURIE -> ontology_term node
verifyEqual(testCase, blk.units.node, 'NCIT:C48367');
% the flat per-endpoint fields are gone (strict schema: only endpoints + units)
verifyFalse(testCase, isfield(blk, 'ontologyNode_A'));
verifyFalse(testCase, isfield(blk, 'ontology_node_a'));
% NOT a length_observation and no endpoint relation minted (single-doc)
names = cellfun(@(d) did2.unittest.helpers.classKey(d), out.migrated, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'observation+length')));
verifyFalse(testCase, any(strcmp(names, 'directed_relation')));
end

function testPyraviewFoldsToObservationPlusSampledBody(testCase)
% #9 pattern-setter: pyraview (a multi-resolution signal pyramid) dissolves into a
% body-backed voltage_observation + ONE sampled_body PER RESOLUTION LEVEL + a
% session anchor. 1 -> 2+N.
%
% The levels are KEPT, not dropped. All level bodies share the statement (the
% observation) -- the multi-body-per-statement stream sampled_body was designed
% for -- and are told apart by the time axis spacing, the per-level rate, level 1
% native. Each body owns exactly its level_k.bin. A pyramid is a precomputed
% performance cache, not a disposable thumbnail, so nothing is discarded.
% (Decided in review; commit 7ce8e8c superseded the earlier drop-the-levels fold.)
%
% This comment previously read "The decimated levels are dropped (regenerable
% cache)" -- text left over from the superseded design, sitting nineteen lines
% above assertions that require the opposite. It was read as the decision.
body = struct();
body.document_class = struct('class_name', 'pyraview', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'filter',  'class_version', '1.0.0'), ...
                      struct('class_name', 'base',    'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_7'});
body.base = struct('id', 'pv_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.pyraview = struct('label', 'lfp', 'nativeRate', 1000, ...
    'nativeStartTime', 0, 'channels', 4, 'dataType', 'int16', ...
    'decimationSamplingRates', [1000 500]);
% THE EPOCH INTERVAL IS PART OF THE FIXTURE BECAUSE IT IS PART OF THE DOCUMENT:
% pyraview.json declares `epochclocktimes` as a superclass, and the real PRED
% document carries it. The fixture omitted it, which mattered once the axis fold
% landed -- v1 records NO sample count anywhere, so the per-level extent is
% derivable only from this interval and the level's rate, and a fixture without
% it silently exercises the no-axes path instead of the one the assertions below
% are about. 10 s at 1000 Hz -> 10000 samples; the decimated level, 500 Hz -> 5000.
body.epochclocktimes = struct('clocktype', 'dev_local_time', 't0_t1', [0 10]);
body.files = struct('file_list', {{'level1.bin', 'level2.bin'}});

out = did2.convert.migrators_j.pyraview(body);
verifyClass(testCase, out, 'cell');
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'observation+voltage')));
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));
% ONE sampled_body per stored level (2 here) -> 1 obs + 2 bodies + 1 anchor
sbods = out(strcmp(names, 'sampled_body'));
verifyEqual(testCase, numel(sbods), 2);

obs = out{find(strcmp(names, 'observation+voltage'), 1)};
verifyEqual(testCase, obs.base.id, 'pv_1');
verifyTrue(testCase, logical(obs.value.data_body));   % #88: the value lives in bodies
verifyEqual(testCase, obs.value.data_type, 'int16');
verifyEqual(testCase, obs.statement.variable.name, 'lfp');
verifyEqual(testCase, depValue(obs, 'entity_id'), 'sub_7');
% every level body shares the statement (the observation) and owns one file;
% levels are told apart by dt (native 1/1000 vs decimated 1/500)
for j = 1:numel(sbods)
    verifyEqual(testCase, depValue(sbods{j}, 'owner_id'), 'pv_1');   % #88: owner_id
    % `datum` collapsed (signed sec.5); the encoding is on the STATEMENT now,
    % normalised -- 'int16' is already canonical, so no source spelling is kept.
    verifyFalse(testCase, isfield(sbods{j}.data, 'datum'));   % #88: the `data` block
    verifyEqual(testCase, numel(sbods{j}.files.file_list), 1);
end
% THE AXES ARE POSITIONAL, AND THIS IS THE ASSERTION THAT SAYS SO. The schema's
% `axes` documentation is `axes[k] IS array dimension k`, so the ORDER is load
% bearing and not a presentation detail. ccfb1eb shipped a one-entry list
% holding `channel`, which asserts that array dimension 1 is channels; the NDI
% writer slices `data(start_idx:end_idx, :)`, so dimension 1 is SAMPLES. The
% whole MATLAB suite was green over that defect because nothing here looked at
% axes at all -- the file's own lesson, that a test written from the same
% premise as the code cannot catch the code, in its weaker form: there was no
% test, so there was no premise to be wrong about.
for j = 1:numel(sbods)
    % #88: `axes` became `data.keys`; AMENDMENT 6: `data.dimensions`, each
    % with its positions as a covariate along it
    ax = did2.unittest.helpers.axesOf(sbods{j});
    verifyEqual(testCase, numel(ax), 2, ...
        'both dimensions or neither -- a positional list has no partial mode');
    verifyEqual(testCase, ax(1).term.name, 'time');
    verifyEqual(testCase, lower(ax(2).term.name), 'channel');   % the registry's label (NCIT:C44170 'Channel', did-schema 34a15e2 [channel types])
    verifyEqual(testCase, ax(2).n, 4);          % the `channels` field
    % the channel's 1..4 numbering only repeated the positions: a bare
    % dimension (Jess Haley 2026-10-22, 6.2a and "yes" to 1..n)
    verifyEqual(testCase, ax(2).nCov, 0, 'no index covariate along channel');
    verifyNotEmpty(testCase, ax(1).cov.origin, 'the time covariate is origin + spacing');
end
% Levels are told apart by the TIME axis spacing now, not by sample_time.dt --
% that block is no longer written here (step 5 of the signed build order), and
% writing the cadence into both would store one fact twice.
dts = sort(arrayfun(@(k) sbods{k}.data.covariates(1).spacing.source_value, ...
    1:numel(sbods)));
verifyEqual(testCase, dts, [1e-3 2e-3], 'AbsTol', 1e-9);
% and by extent: 10 s at 1000 Hz and at 500 Hz. `n` was hardcoded 0 on every
% body until this change, on bodies with real bytes attached.
ns = sort(arrayfun(@(k) sbods{k}.data.dimensions(1).n, 1:numel(sbods)));
verifyEqual(testCase, ns, [5000 10000]);
verifyFalse(testCase, isfield(sbods{1}, 'sampled_body') ...
    && isfield(sbods{1}.sampled_body, 'sample_time'));
end

function body = spikewavesBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/apps/
% spikeextractor/spikewaves.json). ONE property field; both counts the old
% fixture carried live in the spikewaves.vsw binary header, not in the document.
body = struct();
body.document_class = struct('class_name', 'spikewaves', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'epochid', 'app'}, ...
                           'class_version', {'1.0.0', '1.0.0', '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_5'), ...
                    struct('name', 'extraction_parameters_id', 'value', 'sep_1')];
body.base = struct('id', 'sw_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.spikewaves = struct('extraction_name', 'thresh_5sd');
body.files = struct('file_list', {{'spikewaves.vsw', 'spiketimes.bin'}});
end

function testSpikewavesDefersToSecondPass(testCase)
% The old fold declared a sampled_body of n = num_spikes data of shape
% samples_per_spike. Neither field exists, so both defaulted to 0 and every
% document described an extraction of ZERO spikes of ZERO samples -- a
% fabricated measurement that validates cleanly and that neither Phase 1
% counter can see. The real counts are in the .vsw header, and single-document
% migrators carry files without reading their bytes.
out = did2.convert.migrators_j.spikewaves(spikewavesBody());
verifyClass(testCase, out, 'cell');
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'spikewaves');
verifyEqual(testCase, out{1}.spikewaves.extraction_name, 'thresh_5sd');
% the bytes ride along untouched, and no stray anchor is left behind
verifyEqual(testCase, numel(out{1}.files.file_list), 2);
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testSpikewavesRejectsInventedShape(testCase)
body = spikewavesBody();
body.spikewaves = struct('extraction_name', 'thresh_5sd', ...
    'num_spikes', 120, 'samples_per_spike', 32, 'sample_rate', 30000);
verifyError(testCase, @() did2.convert.migrators_j.spikewaves(body), ...
    'did2:convert:spikewavesInventedShape');
end

function body = binnedSpikeRateBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/apps/
% vhlab_voltage2firingrate/binnedspikeratevm.json). The bin width is
% parameters.binsize -- nested, and spelled without the underscore -- and there
% is no bin count anywhere in the class.
body = struct();
body.document_class = struct('class_name', 'binnedspikeratevm', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'epochid', 'app'}, ...
                           'class_version', {'1.0.0', '1.0.0', '1.0.0'}));
body.depends_on = [ struct('name', 'vmspikefilteringparameters_id', 'value', 'vfp_1'), ...
                    struct('name', 'element_id', 'value', 'sub_3')];
body.base = struct('id', 'br_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.binnedspikeratevm = struct( ...
    'parameters', struct('binsize', 0.030, 'vm_baseline_correction', 0, ...
        'vm_baseline_correct_time', 0, 'vm_baseline_correct_func', 'median', ...
        'number_of_points', 0), ...
    'voltage_observations', '', 'firingrate_observations', '', ...
    'stimids', '', 'timepoints', '', 'exactbintime', '');
end

function testBinnedSpikeRateDefersToSecondPass(testCase)
% Two reasons this cannot be repaired by renaming, both from a missing writer:
% the payload fields are "string"-typed with an undocumented encoding, and
% nothing states whether the binned values are rates or spikes-per-bin -- at the
% template's 0.030 s binsize those differ by 33x. The old code hardcoded Hz on a
% series of ZERO samples at dt = 0. NDI-matlab, NDIcalc-vis/-ephys/-marder/
% -birren and vhlab-toolbox were all searched; no writer exists in any of them.
out = did2.convert.migrators_j.binnedspikeratevm(binnedSpikeRateBody());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'binnedspikeratevm');
verifyEqual(testCase, out{1}.binnedspikeratevm.parameters.binsize, 0.030, 'AbsTol', 1e-12);
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testBinnedSpikeRateRejectsInventedShape(testCase)
% bin_size and the real parameters.binsize differ by one underscore and one
% nesting level; the guard is on the flat, underscored spelling only.
body = binnedSpikeRateBody();
body.binnedspikeratevm = struct('bin_size', 0.05, 'num_bins', 600);
verifyError(testCase, @() did2.convert.migrators_j.binnedspikeratevm(body), ...
    'did2:convert:binnedSpikeRateInventedShape');
end

function body = vmSpikeSummaryBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/apps/
% vhlab_voltage2firingrate/vmspikesummary.json). The class is a mean spike
% WAVEFORM plus eight spike-shape medians -- not the four firing-summary scalars
% the old fixture carried, none of which exist. Everything is an ARRAY.
body = struct();
body.document_class = struct('class_name', 'vmspikesummary', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'epochid'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_2'), ...
                    struct('name', 'spike_extraction_id', 'value', 'se_1')];
body.base = struct('id', 'vs_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.vmspikesummary = struct( ...
    'mean_spikewave', [0 -0.5 -62.5 10 0], 'sample_times', [0 1 2 3 4], ...
    'number_of_spikes', 249, ...
    'median_spikekink_vm', -45.2, 'median_voltageofhalfmaximum', -20.1, ...
    'median_fullwidthhalfmaximum', 0.0011, ...
    'median_presk_halfwidthmaximum', 0.0004, ...
    'median_postsk_halfwidthmaximum', 0.0007, ...
    'median_max_dvdt', 180.4, 'median_kink_index', 2.3, ...
    'slope_criterion', '20');
end

function testVmSpikeSummaryDefersToSecondPass(testCase)
% The old fold dispatched on mean_vm / mean_firing_rate / num_spikes /
% recording_duration, emitting one inline scalar observation per hit. The real
% class shares NO field name with that. num_spikes vs number_of_spikes is the
% only near-miss, and even corrected it would have failed: the real field is an
% ARRAY and the migrator required isscalar. All four reads missed, so the
% document already fell through to carry-unchanged -- a passthrough the counter
% can see, which is why this was wrong rather than destructive.
out = did2.convert.migrators_j.vmspikesummary(vmSpikeSummaryBody());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'vmspikesummary');
verifyEqual(testCase, out{1}.vmspikesummary.number_of_spikes, 249);
verifyEqual(testCase, out{1}.vmspikesummary.median_max_dvdt, 180.4, 'AbsTol', 1e-9);
% the extraction edge the old tombstone did not declare is carried
verifyEqual(testCase, depValue(out{1}, 'spike_extraction_id'), 'se_1');
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testVmSpikeSummaryRejectsInventedShape(testCase)
body = vmSpikeSummaryBody();
body.vmspikesummary = struct('mean_vm', -62.5, 'mean_firing_rate', 8.3, ...
    'num_spikes', 249, 'recording_duration', 30.0);
verifyError(testCase, @() did2.convert.migrators_j.vmspikesummary(body), ...
    'did2:convert:vmSpikeSummaryInventedShape');
end

function testContrastTuningFoldsToCalculationLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% contrast_tuning -> the contrast_tuning_calculation leaf, id-preserved (did-schema
% #88). UPDATED for #88: a calculation REQUIRES operating_system_id, read from the
% v1 `app.os`, so the fixture now carries the `app` block every real calculator
% document has (ndi.app.newdocument stamps it; all Soph *_calc samples carry it).
% (Since 2026-10-21 a document without it still folds, with no
% operating_system_id -- see testCalculationWithNoOperatingSystemFoldsWithoutTheEdge.) Out: leaf + session anchor +
% three software entities (app, os, interpreter), each with a version assertion.
body = struct();
body.document_class = struct('class_name', 'contrast_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'ct_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.contrast');
body.contrast_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s', 'response_type', 'mean'), ...
    'tuning_curve', struct('contrast', [0 0.25 0.5 1], 'mean', [2 5 9 12]));

out = foldPlaceable(testCase, @did2.convert.migrators_j.contrast_tuning, body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'contrast_tuning_calculation', 'ct_1', 'sub_8');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_1');
verifyEqual(testCase, char(leaf.interaction.method.term.node), 'OBI:0200072');   % [tuning fits use curve fitting now], Jess Haley 2026-10-27
verifyEqual(testCase, leaf.tuning_curve.value.mean, [2 5 9 12]);
verifyEqual(testCase, leaf.data.covariates(1).quantity.value, [0 0.25 0.5 1]);
verifyEqual(testCase, lower(leaf.data.dimensions(1).term.name), 'contrast');
end


function testOrientationDirectionTuningFoldsToCalculationLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% orientation_direction_tuning -> orientation_direction_tuning_calculation,
% id-preserved (#88). UPDATED for #88: app block added (operating_system_id is
% required); `vector` lands on the leaf's circular_statistics, significance on
% tuning_curve_calculation, the `fit` block on model_fit, the direction axis on
% data.keys, and the consumed curve on input_id (was derived_from_1).
body = struct();
body.document_class = struct('class_name', 'orientation_direction_tuning', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_1'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'odt_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.oridir');
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5, 'circular_variance', 0.3), ...
    'significance', struct('visual_response_anova_p', 0.002), ...
    'fit', struct('hwhh', 22.0));

out = foldPlaceable(testCase, @did2.convert.migrators_j.orientation_direction_tuning, body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'observation+frequency')));   % not decomposed
verifyFalse(testCase, any(strcmp(names, 'observation+angle')));
leaf = calcLeafJ(testCase, out, 'orientation_direction_tuning_calculation', 'odt_1', 'neuron_1');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_1');
verifyEqual(testCase, char(leaf.interaction.method.term.node), 'OBI:0200072');   % [tuning fits use curve fitting now], Jess Haley 2026-10-27
verifyEqual(testCase, leaf.data.covariates(1).quantity.value, [0 90 180 270]);
verifyEqual(testCase, leaf.tuning_curve.value.mean, [10 2 9 3]);
verifyEqual(testCase, leaf.tuning_curve.value.significance.visual_response_anova_p, ...
    0.002, 'AbsTol', 1e-9);
cs = leaf.orientation_direction_tuning_calculation.circular_statistics;
verifyEqual(testCase, cs.orientation_preference, 47.5, 'AbsTol', 1e-9);
verifyEqual(testCase, cs.circular_variance, 0.3, 'AbsTol', 1e-9);
mf = leaf.tuning_curve.value.model_fit;   % [one fit entry], Jess Haley 2026-10-22
verifyEqual(testCase, numel(mf), 1);
verifyEqual(testCase, mf(1).metrics.half_width_at_half_maximum, 22.0, 'AbsTol', 1e-9);
end


function testOridirtuningCalcUndefersToLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% The ndi.calc.vis.oridir OUTPUT document folds 1 -> 1, id-preserved, into the
% SAME leaf as its result sibling. UPDATED for #88: input_parameters ->
% interaction.method.parameters (a list of entries); the app block -> a software
% entity (software_id), the os -> operating_system_id and the interpreter ->
% interpreter_id, each a `software` entity with a version text_assertion (the
% runtime_environment entity was deleted, #73 item 53); the consumed curve ->
% input_id.
body = struct();
body.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'orientation_direction_tuning'; 'tuning_fit'}, ...
                           'class_version', {'1.0.0'; '1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_9'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_9')];
body.base = struct('id', 'oc_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.oridir', 'version', '1.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
% (a setting the name table holds: [parameter names map by table], Jess Haley,
% 2026-10-27; a name outside it carries the document)
body.oridirtuning_calc = struct('input_parameters', ...
    struct('independent_label', 'direction'));
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5));

out = foldPlaceable(testCase, @did2.convert.migrators_j.oridirtuning_calc, body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'orientation_direction_tuning_calculation', 'oc_1', 'neuron_9');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_9');
verifyEqual(testCase, paramTextJ(leaf, 'independent label'), 'direction');
sw = entityByNameJ(out, 'ndi.calc.vis.oridir');
verifyEqual(testCase, sw.entity.local_identifier, 'ndi.calc.vis.oridir@1.2');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
os = entityByNameJ(out, 'Linux');
verifyEqual(testCase, depValue(leaf, 'operating_system_id'), os.base.id);
it = entityByNameJ(out, 'MATLAB');
verifyEqual(testCase, depValue(leaf, 'interpreter_id'), it.base.id);
verifyEqual(testCase, leaf.data.covariates(1).quantity.value, [0 90 180 270]);
end


function testACalculatorsInnerDependsOnThatRestatesTheEdgesIsNotACarry(testCase)
% [restated values checked] (Jess Haley, 2026-10-26): the calculator block's
% inner `depends_on` copy is left unwritten when it restates the top-level
% edges (measured equal on every held document), so it is never the reason a
% document is carried.
body = oridirCalcInnerDepsBodyJ();
did2.convert.reportNote('reset');
did2.convert.migrators_j.oridirtuning_calc(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
if isfield(notes, 'carried_as_v1')
    verifyFalse(testCase, contains(notes.carried_as_v1.distinct_details{1}, 'depends_on'), ...
        notes.carried_as_v1.distinct_details{1});
end
end

function testACalculatorsInnerDependsOnThatDiffersIsCarriedAsV1(testCase)
% ... and one that does NOT restate them is carried whole as v1, the copy named.
body = oridirCalcInnerDepsBodyJ();
body.oridirtuning_calc.depends_on(2).value = 'tc_OTHER';
did2.convert.reportNote('reset');
out = did2.convert.migrators_j.oridirtuning_calc(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, body), 'returned unchanged');
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
d = notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, contains(d, 'oridirtuning_calc.depends_on (stimulus_tuningcurve_id'), d);
end

function body = oridirCalcInnerDepsBodyJ()
% testOridirtuningCalcUndefersToLeaf's body, with the inner copy NDI's
% calculator writes on its own block (equal to the top-level edges).
body = struct();
body.document_class = struct('class_name', 'oridirtuning_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'orientation_direction_tuning'; 'tuning_fit'}, ...
                           'class_version', {'1.0.0'; '1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_9'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_9')];
body.base = struct('id', 'oc_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.oridir', 'version', '1.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.oridirtuning_calc = struct('input_parameters', ...
    struct('independent_label', 'direction'), ...
    'depends_on', body.depends_on);
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5));
end

function testContrastSensitivityCalcUndefersToLeaf(testCase)
% The aggregate ndi.calc.vis.contrast_sensitivity output folds 1 -> 1,
% id-preserved, into contrast_sensitivity_calculation. UPDATED for #88: the
% spatial frequencies are the statement's key (data.keys), each RB/RBN/RBNS
% Naka-Rushton variant is one value.model_fit entry whose coefficients are a
% {variable, value} list, input_parameters -> method.parameters, the consumed
% responses -> input_id. INVERTED 2026-10-23 (Jess Haley [contrast sensitivity
% lossless]): the stimulus_presentation_id is an input too (after the
% responses), and `is_modulated_response` 1 -> significance.modulated_response
% true (was dropped). The 0 and absent cases are
% testContrastSensitivityModulatedResponseFalseAndAbsent.
body = struct();
body.document_class = struct('class_name', 'contrast_sensitivity_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'calculator'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_cs'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_cs'), ...
                    struct('name', 'stimulus_presentation_id', 'value', 'pres_cs')];
body.base = struct('id', 'cs_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.contrast_sensitivity', 'version', '1.0', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.contrast_sensitivity_calc = struct('spatial_frequencies', [0.5 1 2 4], ...
    'sensitivity_rb', [10 20 15 5], 'empirical_c50_rb', [0.2 0.3 0.4 0.5], ...
    'parameters_rb', [12 0.25 2], ...
    'sensitivity_rbns', [9 18 14 4], 'parameters_rbns', [11 0.27 2.1], ...
    'fitless_interpolated_c50', [0.21 0.31 0.41 0.51], ...
    'visual_response_p_bonferroni', [0.01 0.02 0.03 0.04], ...
    'is_modulated_response', 1, 'response_type', 'mean', ...
    'input_parameters', struct('threshold', 1));

out = did2.convert.migrators_j.contrast_sensitivity_calc(body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'contrast_sensitivity_calculation', 'cs_1', 'neuron_cs');
verifyEqual(testCase, depValuesJ(leaf, 'input_id'), {'resp_cs', 'pres_cs'});
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.vis.contrast_sensitivity');
verifyEqual(testCase, paramValueJ(leaf, 'threshold'), 1);
verifyEqual(testCase, leaf.data.covariates(1).quantity.value, [0.5 1 2 4]);
csv = leaf.contrast_sensitivity.value;
verifyEqual(testCase, numel(csv.model_fit), 2);            % rb and rbns, not rbn
models = arrayfun(@(e) lower(char(e.model.name)), csv.model_fit, 'UniformOutput', false);
rbAt = find(endsWith(models, ' rb'), 1);
verifyNotEmpty(testCase, find(endsWith(models, ' rbns'), 1));
verifyEmpty(testCase, find(endsWith(models, ' rbn'), 1));
assertNotEmpty(testCase, rbAt);
rb = csv.model_fit(rbAt);
verifyEqual(testCase, rb.sensitivity, [10 20 15 5]);       % metric rides INSIDE its fit
verifyEqual(testCase, rb.c50, [0.2 0.3 0.4 0.5]);
verifyEqual(testCase, [rb.coefficients.value], [12 0.25 2]);
verifyEqual(testCase, csv.interpolated_values.c50, [0.21 0.31 0.41 0.51]);
verifyEqual(testCase, csv.significance.visual_response_p_bonferroni, [0.01 0.02 0.03 0.04]);
verifyEqual(testCase, csv.significance.modulated_response, true);
verifyEqual(testCase, lower(csv.response_type.name), 'mean');
% contrast_sensitivity_calc carries no response_units, so what the response
% measured is not stated: INVERTED 2026-10-23 (Jess Haley [unstated response
% variable]) -- the variable is the general term EMPTY:0000398 "neural
% response", not the calculator label 'contrast sensitivity'
v = leaf.statement.variable;
verifyEqual(testCase, char(v.node), 'EMPTY:0000398');
verifyEqual(testCase, char(v.name), 'neural response');
sw = entityByNameJ(out, 'ndi.calc.vis.contrast_sensitivity');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
end


function testContrastSensitivityModulatedResponseFalseAndAbsent(testCase)
% Jess Haley 2026-10-23 [contrast sensitivity lossless]: v1
% is_modulated_response 0 -> significance.modulated_response false; ABSENT ->
% no field at all (the schema's blank is null, so missing never reads as
% false). Neither case leaves a field_dropped note for it.
body = struct();
body.document_class = struct('class_name', 'contrast_sensitivity_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'calculator'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_cs'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_cs'), ...
                    struct('name', 'stimulus_presentation_id', 'value', 'pres_cs')];
body.base = struct('id', 'cs_2', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.contrast_sensitivity', 'version', '1.0', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.contrast_sensitivity_calc = struct('spatial_frequencies', [0.5 1 2 4], ...
    'sensitivity_rb', [10 20 15 5], 'parameters_rb', [12 0.25 2], ...
    'visual_response_p_bonferroni', [0.01 0.02 0.03 0.04], ...
    'is_modulated_response', 0, 'response_type', 'mean', ...
    'input_parameters', struct('threshold', 1));

did2.convert.reportNote('reset');
cleanup = onCleanup(@() did2.convert.reportNote('reset'));
out = did2.convert.migrators_j.contrast_sensitivity_calc(body);
leaf = calcLeafJ(testCase, out, 'contrast_sensitivity_calculation', 'cs_2', 'neuron_cs');
verifyEqual(testCase, leaf.contrast_sensitivity.value.significance.modulated_response, false);
verifyEqual(testCase, depValuesJ(leaf, 'input_id'), {'resp_cs', 'pres_cs'});

body.contrast_sensitivity_calc = rmfield(body.contrast_sensitivity_calc, 'is_modulated_response');
body.base.id = 'cs_3';
out = did2.convert.migrators_j.contrast_sensitivity_calc(body);
leaf = calcLeafJ(testCase, out, 'contrast_sensitivity_calculation', 'cs_3', 'neuron_cs');
sig = leaf.contrast_sensitivity.value.significance;
verifyTrue(testCase, ~isfield(sig, 'modulated_response') || isempty(sig.modulated_response), ...
    'an absent is_modulated_response must not be written (never false)');
notes = did2.convert.reportNote('collect');
if isfield(notes, 'field_dropped')
    verifyFalse(testCase, any(contains(notes.field_dropped.distinct_details, 'is_modulated_response')), ...
        'is_modulated_response is carried now, never reported as field_dropped');
end
end


function v = depValuesJ(b, name)
% Every edge named NAME on a raw body, in order, as a 1xN cellstr (depValue
% returns the first only). Same document_id-then-value precedence as depValue.
v = {};
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    if ~strcmp(b.depends_on(k).name, name); continue; end
    if isfield(b.depends_on(k), 'document_id') && ~isempty(b.depends_on(k).document_id)
        v{end+1} = char(b.depends_on(k).document_id); %#ok<AGROW>
    elseif isfield(b.depends_on(k), 'value')
        v{end+1} = char(b.depends_on(k).value); %#ok<AGROW>
    end
end
end


function testTuningcurveCalcUndefersToLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% The ndi.calc.stimulus.tuningcurve OUTPUT folds 1 -> 1, id-preserved, into the
% concrete tuning_curve_calculation leaf (#88). element_id -> entity_id; the
% inherited stimulus_tuningcurve block is reshaped (response_mean -> value.mean,
% the independent variable -> data.keys); input_parameters -> method.parameters;
% the consumed stimulus_response_scalar -> input_id.
body = struct();
body.document_class = struct('class_name', 'tuningcurve_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'stimulus_tuningcurve'}, ...
        'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_tc'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_tc')];
body.base = struct('id', 'tcc_1', 'session_id', 'sess_11', 'name', '', ...
    'datestamp', '2024-07-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.stimulus.tuningcurve', 'version', '1.0', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', 'contrast', ...
    'independent_variable_value', [0 0.25 0.5 1], ...
    'response_mean', [1 4 8 11], 'response_units', 'Spikes/s');
body.tuningcurve_calc = struct('log', 'ok', ...
    'input_parameters', struct('best_algorithm', 'empirical_maximum'));

out = foldPlaceable(testCase, @did2.convert.migrators_j.tuningcurve_calc, body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'tuning_curve_calculation', 'tcc_1', 'neuron_tc');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'resp_tc');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.stimulus.tuningcurve');
verifyEqual(testCase, paramTextJ(leaf, 'best algorithm'), 'empirical_maximum');
verifyEqual(testCase, leaf.tuning_curve.value.mean, [1 4 8 11]);
verifyEqual(testCase, leaf.data.covariates(1).quantity.value, [0 0.25 0.5 1]);
sw = entityByNameJ(out, 'ndi.calc.stimulus.tuningcurve');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
os = entityByNameJ(out, 'Linux');
verifyEqual(testCase, depValue(leaf, 'operating_system_id'), os.base.id);
end


function testStimulusTuningcurveRawFoldsToCalculationLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% A raw ndi.app.stimulus.tuning_response curve folds to the SAME leaf class as
% tuningcurve_calc, so stimulus_tuningcurve_id refs resolve to either. UPDATED for
% #88: the fixture carries the `app` block ndi.app.newdocument stamps (an
% operating system is required); a raw curve has no input_parameters, so the
% method carries its term and no parameters.
body = struct();
body.document_class = struct('class_name', 'stimulus_tuningcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_rt'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_rt')];
body.base = struct('id', 'stc_1', 'session_id', 'sess_11', 'name', '', ...
    'datestamp', '2024-07-01T12:00:00.000Z');
body.app = calcAppJ('ndi.app.stimulus.tuning_response');
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', 'direction', ...
    'independent_variable_value', [0 90 180 270], ...
    'response_mean', [10 2 9 3], 'response_units', 'Spikes/s');

out = foldPlaceable(testCase, @did2.convert.migrators_j.stimulus_tuningcurve, body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'tuning_curve_calculation', 'stc_1', 'neuron_rt');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'resp_rt');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.app.stimulus.tuning_response');
verifyEqual(testCase, leaf.tuning_curve.value.mean, [10 2 9 3]);
verifyEqual(testCase, nParamsJ(leaf), 0);
end


function d = firstByVariable(migrated, varName)
d = [];
for k = 1:numel(migrated)
    m = migrated{k};
    if isfield(m, 'subject_statement') && isfield(m.subject_statement, 'variable') ...
            && strcmp(m.statement.variable.name, varName)
        d = m; return;
    end
end
end

function testSpeedTuningFoldsToCalculationLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% speed_tuning -> speed_tuning_calculation, id-preserved (#88). UPDATED for #88:
% app block added (an operating system is required); the two stimulus axes
% (SF, TF) become ONE key whose positions are labelled by both values.
body = struct();
body.document_class = struct('class_name', 'speed_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_s'});
body.base = struct('id', 'sp_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.speed');
body.speed_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('spatial_frequency', [0.5 0.5 1], ...
        'temporal_frequency', [2 4 4], 'mean', [5 8 6]));

out = foldPlaceable(testCase, @did2.convert.migrators_j.speed_tuning, body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'observation+frequency')));
leaf = calcLeafJ(testCase, out, 'speed_tuning_calculation', 'sp_1', 'sub_s');
verifyEqual(testCase, char(leaf.interaction.method.term.node), 'OBI:0200072');   % [tuning fits use curve fitting now], Jess Haley 2026-10-27
verifyEqual(testCase, leaf.tuning_curve.value.mean, [5 8 6]);
% AMENDMENT 6, [tuning grid] (Jess Haley 2026-10-22): the 3 sampled points
% are not a full grid of the 2 x 2 frequencies, so ONE dimension of 3, its term
% XCO:0000000 "experimental condition" ([stimulus condition term]; no longer
% the joined 'spatial frequency x temporal frequency'), with one quantity
% covariate PER VARIABLE along it
verifyEqual(testCase, numel(leaf.data.dimensions), 1);
verifyEqual(testCase, leaf.data.dimensions(1).n, 3);
verifyEqual(testCase, leaf.data.dimensions(1).term.node, 'XCO:0000000');
verifyEqual(testCase, leaf.data.dimensions(1).term.name, 'experimental condition');
covs = leaf.data.covariates;
verifyEqual(testCase, numel(covs), 2);
verifyEqual(testCase, arrayfun(@(c) char(c.variable.name), covs, 'UniformOutput', false), ...
    {regName('spatial frequency'), regName('temporal frequency')});
verifyEqual(testCase, [covs.along], [0 0]);
verifyEqual(testCase, covs(1).quantity.value, [0.5 0.5 1]);
verifyEqual(testCase, covs(2).quantity.value, [2 4 4]);
end


function v1 = ontologyImageVintageA()
% VINTAGE A (legacy, DID-schema V_alpha/V_beta ancestry): the region is two
% coordinated chars and `element_id` supplies the subject. Shape taken from
% schemas/V_alpha/ontologyImage.json, NOT from our own V_eta schema.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'oi_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_name', 'uberon:0002436', ...
    'ontology_region', 'primary visual cortex');
end

function v1 = ontologyImageVintageB()
% VINTAGE B (current NDI production): `ontology_nodes` is a comma-joined list
% of CURIEs and the only edge is `ontology_table_row_id` -- NOT a subject.
% Shape taken from NDI's ndi_common/database_documents/data/ontologyImage.json
% plus +ndi/+setup/+NDIMaker/imageDocMaker (which writes the PLURAL key).
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'ngrid'}, 'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = struct('name', {'ontology_table_row_id'}, 'value', {'otr_3'});
v1.base = struct('id', 'oi_2', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.ontology_image = struct('ontology_nodes', 'uberon:0000955,uberon:0002436');
v1.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', [1;2;3;4;1;2;3;4]);
end

function testUnconvertedCounterSeesAPassthrough(testCase)
% Phase 1 report-only counter. site2channelmap now DEFERS explicitly (its `map`
% only has meaning joined to the probe_geometry it references), so it hands its
% input straight back. That document still lands in migrated_count, because
% nothing errored -- which is exactly why a passthrough used to be
% indistinguishable from a real migration. The counter is what separates them,
% whether the passthrough is deliberate (as here) or accidental (as it was when
% the migrator was reading the non-existent `num_sites`).
v1 = struct();
v1.document_class = struct('class_name', 'site2channelmap', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_1'});
v1.base = struct('id', 's2c_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% the REAL field, per the NDI template -- so the migrator's num_sites read
% finds nothing and falls through to its carry-unchanged branch
v1.site2channelmap = struct('map', [1 2; 2 3; 3 4]);

out = runJ(v1);
verifyEqual(testCase, out.summary.unconverted_count, 1, ...
    'a migrator returning its input unchanged must be counted');
verifyTrue(testCase, isfield(out.summary.unconverted_by_class, 'site2channelmap'));
% and it is still reported as migrated -- that is the camouflage this counter exists to strip
verifyEqual(testCase, out.summary.quarantine_count, 0);
end

function testUnconvertedCounterIgnoresARealMigration(testCase)
% A migrator that actually converts must NOT be counted as unconverted,
% otherwise the census is noise. ontology_image's older layout converts to a
% term_observation plus a session anchor.
out = runJ(ontologyImageVintageA());
verifyEqual(testCase, out.summary.unconverted_count, 0);
end

function testOntologyImageVintageABecomesTermObservation(testCase)
% VINTAGE A is fully resolvable single-doc: term from the two coordinated
% chars, subject from element_id. 1 -> 2 (observation + session anchor).
out = did2.convert.migrators_j.ontology_image(ontologyImageVintageA());
verifyEqual(testCase, numel(out), 2);
o = out{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(o), 'observation+term');
verifyEqual(testCase, o.statement.variable.name, 'imaged region');
verifyEqual(testCase, o.term.value.node, regNode('uberon:0002436'));
verifyEqual(testCase, o.term.value.name, 'primary visual cortex');
verifyEqual(testCase, depValue(o, 'entity_id'), 'elem_9');
end

function testOntologyImageVintageBPassesThroughForSecondPass(testCase)
% VINTAGE B is DEFERRED: its only edge is a table row, not a subject, so the
% subject needs the migrated-id graph. The document must pass through INTACT
% (ngrid block and all) so the NDI second pass can decompose it -- and must
% NOT become a term_observation with an empty subject_id.
v1 = ontologyImageVintageB();
out = did2.convert.migrators_j.ontology_image(v1);
verifyEqual(testCase, numel(out), 1);
o = out{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(o), 'ontology_image');
verifyEqual(testCase, o.ontology_image.ontology_nodes, 'uberon:0000955,uberon:0002436');
% the raster block must survive for the second pass. NOTE: this calls the
% migrator directly, so `coordinates` is still present here -- in the real
% pipeline the ngrid SUPERCLASS migrator runs first and deletes it. That
% deletion is a known, separate data loss (see V_eta_ngrid_family_findings.md);
% this assertion only proves THIS migrator strips nothing.
verifyTrue(testCase, isfield(o, 'ngrid'));
verifyEqual(testCase, o.ngrid.coordinates, [1;2;3;4;1;2;3;4]);
% and no husk observation was minted
verifyFalse(testCase, isfield(o, 'subject_statement'));
end

function testOntologyImageRejectsBaseMigratorRegionShape(testCase)
% THE GUARD. `region` is the base (+migrators) migrator's OUTPUT, not a did_v1 field.
% The previous implementation read it, so it matched only a fixture built to
% our own schema and silently emitted an empty observation about nobody.
% Reading it again must be loud, not silent.
v1 = ontologyImageVintageA();
v1.ontology_image = struct('region', ...
    struct('node', 'uberon:0002436', 'name', 'primary visual cortex'));
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ontologyImageBaseMigratorShape');
end

function testOntologyImageRejectsUnknownShape(testCase)
% A block matching no known vintage must quarantine rather than migrate to a
% content-free husk (an empty ontology_term still has fieldnames, so it
% satisfies mustBeNonEmpty, and an empty depends_on edge is skipped by
% did2.validate.references -- neither gate would have caught it).
v1 = ontologyImageVintageA();
v1.ontology_image = struct('something_else', 'x');
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ontologyImageUnknownShape');
end

function testElectrodeOffsetVoltageBecomesVoltageObservation(testCase)
% electrode_offset_voltage -> a voltage_observation of the probe-subject,
% qualified by the temperature it was measured at, + anchor. 1 -> 2.
%
% Fixture built from the NDI TEMPLATE + writer
% (+ndi/+setup/+conv/+marder/makeVoltageOffsets.m). The previous one used
% offset_voltages and voltage_units -- neither exists -- so the isempty guard
% always fired and every real document was carried through unconverted while
% this test passed.
%
% The real class is {offset, temperature}, both SCALARS: the writer makes one
% document per CSV row, not a per-channel array.
v1 = struct();
v1.document_class = struct('class_name', 'electrode_offset_voltage', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_7'});
v1.base = struct('id', 'eo_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.electrode_offset_voltage = struct('offset', 0.5, 'temperature', 11);

out = did2.convert.migrators_j.electrode_offset_voltage(v1);
verifyEqual(testCase, numel(out), 2);
o = out{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(o), 'observation+voltage');
verifyEqual(testCase, depValue(o, 'entity_id'), 'probe_7');
% a single reading, expressed as a length-1 array
vals = o.voltage.value;
verifyEqual(testCase, numel(vals), 1);
verifyEqual(testCase, vals(1).source_value, 0.5, 'AbsTol', 1e-9);
% #88: a bound term; 'V' is the registry's om:volt 'volt' (jSourceUnit)
verifyEqual(testCase, vals(1).source_unit.node, 'om:volt');
verifyEqual(testCase, vals(1).source_unit.name, 'volt');
verifyEqual(testCase, vals(1).volts, 0.5, 'AbsTol', 1e-9);
% temperature qualifies the SAME statement rather than becoming its own doc
c = o.statement.conditions;   % #88: conditions live on `statement`
verifyEqual(testCase, c.variable.name, regName('temperature'));
verifyEqual(testCase, c.quantity.value, 11, 'AbsTol', 1e-9);
verifyEqual(testCase, c.quantity.source_value, '11', ...
    'a condition''s source_value is text');
% no unit is asserted for temperature -- the source states no scale
verifyFalse(testCase, isfield(c, 'source_unit') && ~isempty(c.source_unit));
verifyFalse(testCase, isfield(c, 'unit'));
end

function testElectrodeOffsetVoltageOmitsUnrecordedTemperature(testCase)
% The writer stores NaN when no temperature was recorded. NaN means "not
% measured", so no condition should be minted for it.
v1 = struct();
v1.document_class = struct('class_name', 'electrode_offset_voltage', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_7'});
v1.base = struct('id', 'eo_2', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.electrode_offset_voltage = struct('offset', -0.3, 'temperature', NaN);

out = did2.convert.migrators_j.electrode_offset_voltage(v1);
o = out{1};
verifyEqual(testCase, o.voltage.value(1).source_value, -0.3, 'AbsTol', 1e-9);
verifyFalse(testCase, isfield(o.statement, 'conditions'));
end

function testElectrodeOffsetVoltageRejectsInventedShape(testCase)
% offset_voltages/voltage_units are V_alpha inventions. Reading them again must
% be loud, not a silent carry-through.
v1 = struct();
v1.document_class = struct('class_name', 'electrode_offset_voltage', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_7'});
v1.base = struct('id', 'eo_3', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.electrode_offset_voltage = struct('offset_voltages', [0.5 -0.3], 'voltage_units', 'mV');
verifyError(testCase, @() did2.convert.migrators_j.electrode_offset_voltage(v1), ...
    'did2:convert:electrodeOffsetInventedShape');
end
function testOpenmindsElementBecomesTermAssertion(testCase)
% openminds_element mirrors openminds_subject, but the openMINDS entity is about
% an ELEMENT/DEVICE: the subject is carried from element_id (fallback subject_id).
% Each openMINDS controlled-term entity decomposes into one term_assertion on the
% element-subject: the entity type names the variable; the ontology id is the value.
body = struct();
body.document_class = struct('class_name', 'openminds_element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'element_id', 'openminds'}, 'value', {'elem_9', ''});
body.base = struct('id', 'ome_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', ...
    'fields', struct('name', 'Caenorhabditis elegans', ...
        'preferredOntologyIdentifier', 'NCBITaxon:6239', 'synonym', 'C. elegans'));

out = did2.convert.migrators_j.openminds_element(body);
verifyEqual(testCase, numel(out), 1);
a = out{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(a), 'assertion+term');
verifyEqual(testCase, a.statement.variable.name, 'Species');   % the registry label of NCIT:C45293
verifyEqual(testCase, a.term.value.node, 'NCBITaxon:6239');
verifyEqual(testCase, a.term.value.name, 'Caenorhabditis elegans');
verifyEqual(testCase, depValue(a, 'entity_id'), 'elem_9');
verifyEqual(testCase, a.document_class.class_name, 'assertion');   % #88
end

function testOpenmindsStimulusPassesThroughForSecondPass(testCase)
% INVERTED, not updated. This test used to assert the document became a
% `term_assertion` whose subject_id came from a `stimulus_id` dependency -- and
% it passed, because the fixture invented the same edge name the migrator read.
% A test written from the same premise as the code cannot catch the code.
%
% The real document (stimulusDocMaker.m:407-412) is a StimulationApproach term +
% a stimulator + an EPOCH, with the edge named `stimulus_element_id`. It is not a
% statement about a subject: the assertion tier is timeless, so an assertion
% cannot carry the epoch, and calling the stimulator a spatial-frequency-tuning
% is false. Destination is `interaction_purpose` via the NDI second pass, so
% pass 1 carries the document intact.
body = struct();
body.document_class = struct('class_name', 'openminds_stimulus', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'epochid'; 'openminds'}, ...
                           'class_version', {'1.0.0'; '1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'stimulus_element_id'}, 'value', {'stim_042'});
body.base = struct('id', 'om_s1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/StimulationApproach', ...
    'matlab_type', 'openminds.controlledterms.StimulationApproach', ...
    'fields', struct('name', 'Purpose: Assessing spatial frequency tuning', ...
        'preferredOntologyIdentifier', 'NDIC:00000012', ...
        'description', 'Assessing spatial frequency tuning'));

out = did2.convert.migrators_j.openminds_stimulus(body);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'openminds_stimulus');
% carried INTACT -- the epoch and the referent both survive for the second pass
verifyEqual(testCase, out{1}.epochid.epochid, 't00001');
verifyEqual(testCase, out{1}.depends_on(1).name, 'stimulus_element_id');
verifyEqual(testCase, out{1}.depends_on(1).value, 'stim_042');
verifyEqual(testCase, out{1}.openminds.fields.name, ...
    'Purpose: Assessing spatial frequency tuning');
end

function testOpenmindsStimulusRejectsInventedStimulusIdEdge(testCase)
% The guard. `stimulus_id` is a DID-side invention -- NDI's template, schema and
% writer all name the edge `stimulus_element_id` -- so a body carrying it was
% built against our snapshot rather than a real document, and must fail loudly
% instead of migrating to something plausible.
body = struct();
body.document_class = struct('class_name', 'openminds_stimulus', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'stimulus_id'}, 'value', {'stim_042'});
body.base = struct('id', 'om_s1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/StimulationApproach', ...
    'matlab_type', 'openminds.controlledterms.StimulationApproach', 'fields', struct());

verifyError(testCase, @() did2.convert.migrators_j.openminds_stimulus(body), ...
    'did2:convert:openmindsStimulusInventedEdge');
end

function testJrclustClustersFoldsToCountObservation(testCase)
% #9 (pattern 1, body-backed): jrclust_clusters (per-spike JRCLUST cluster
% labels) -> count_observation + sampled_body (one datum per spike) + anchor.
% 1->3. No num_spikes metadata on this class, so sample_time.n == 0.
body = struct();
body.document_class = struct('class_name', 'jrclust_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_8'});
body.base = struct('id', 'jc_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.jrclust_clusters = struct('res_mat_md5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');
body.files = struct('file_list', {{'clusters.mat'}});

out = did2.convert.migrators_j.jrclust_clusters(body);
% UPDATED 2026-10-21: a calculation with the `label` value kind (TEAM-SIGN-OFF
% [spike-sorter output] 2026-09-29), which requires its software; this fixture
% has no app block, so the software is 'jrclust' by name. 3 -> 4.
verifyEqual(testCase, numel(out), 4);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'calculation+label')));
% #88: the .mat is an OPAQUE body (format EDAM:format_2333), not a sampled one
verifyTrue(testCase, any(strcmp(names, 'opaque_body')));
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));

obs = out{find(strcmp(names, 'calculation+label'), 1)};
verifyEqual(testCase, depValue(obs, 'entity_id'), 'sub_8');

% #88: the .mat payload is an OPAQUE body owned by the observation; it states no
% extent at all (the real spike count lives in the payload), so there is no key
% to assert and none is invented.
sbod = out{find(strcmp(names, 'opaque_body'), 1)};
verifyEqual(testCase, depValue(sbod, 'owner_id'), obs.base.id);   % == 'jc_1'
% data_body AMENDMENT 5: the value is in the opaque body; no data_type (opaque)
verifyTrue(testCase, logical(obs.value.data_body));
verifyFalse(testCase, isfield(obs.value, 'data_type') && ~isempty(obs.value.data_type));
verifyEqual(testCase, sbod.data_body.format.node, 'EDAM:format_2333');
verifyTrue(testCase, contains(sbod.data_body.description, 'd41d8cd9'));   % MD5 noted
verifyEqual(testCase, sbod.files.file_list{1}, 'clusters.mat');
end

function testKilosortClustersFoldsToCountObservationPlusOpaqueBody(testCase)
% #9 D-C (spike-sorting family, external-directory variant): kilosort_clusters (a
% Kilosort RUN referencing a session-relative output DIRECTORY + curated MD5) ->
% an id-preserved count_observation handle on the recording subject + an
% opaque_body (the directory) + a session anchor. 1->3. Sibling of
% jrclust_clusters, but the sorter output is an external dir (opaque_body), not
% attached bytes (sampled_body).
body = struct();
body.document_class = struct('class_name', 'kilosort_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_ks'});
body.base = struct('id', 'ks_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.app.kilosort', 'version', '1.0');
body.kilosort_clusters = struct('kilosort_directory', 'ks_out/session1', ...
    'curated_output_MD5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');

out = did2.convert.migrators_j.kilosort_clusters(body);
% 3 -> 4 (2026-08-10): the fold now also mints a `software` entity from the
% v1 `app` block, which this fixture carries. It was being DROPPED ON THE
% FLOOR -- jSorterOutput built its bodies from scratch and never read the
% block -- and NO COUNTER SAW IT: silentLoss counts empty edges, vacuous
% fields and fragments, and a dropped SOURCE BLOCK is none of the three.
% The edge lands on count_observation, which is the only one of the three
% bodies that declares software_id (via subject_observation ->
% subject_interaction); the opaque_body and the anchor do not.
verifyEqual(testCase, numel(out), 5);   % #88: + the software version text_assertion
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'calculation+label')));
verifyTrue(testCase, any(strcmp(names, 'opaque_body')));
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    'the app block must become a software entity, not vanish');
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));

obs = out{find(strcmp(names, 'calculation+label'), 1)};
verifyEqual(testCase, obs.base.id, 'ks_1');                            % id preserved
verifyEqual(testCase, obs.interaction.method.term.name, 'kilosort');% method = algorithm
verifyEqual(testCase, depValue(obs, 'entity_id'), 'sub_ks');
% data_body AMENDMENT 5: no inline value, so the value is in data bodies; and
% no data_type, because the body is opaque (Jess Haley, 2026-10-21)
verifyTrue(testCase, logical(obs.value.data_body));
verifyFalse(testCase, isfield(obs.value, 'data_type') && ~isempty(obs.value.data_type));

ob = out{find(strcmp(names, 'opaque_body'), 1)};
verifyEqual(testCase, depValue(ob, 'owner_id'), 'ks_1');              % body -> the obs
verifyEqual(testCase, ob.data_body.filename, 'ks_out/session1');    % directory preserved
% Jess Haley, 2026-10-21 ("a"): the directory BY LOCATION (body_data_0, not
% ingested) and the curated MD5 as the body's checksum, not in the description
verifyEqual(testCase, ob.files.file_info(1).name, 'body_data_0');
verifyEqual(testCase, ob.files.file_info(1).locations.location, 'ks_out/session1');
verifyEqual(testCase, double(ob.files.file_info(1).locations.ingest), 0);
verifyEqual(testCase, ob.data_body.content_hash, 'd41d8cd98f00b204e9800998ecf8427e');
verifyEqual(testCase, ob.data_body.hash_algorithm, 'MD5');
verifyFalse(testCase, contains(ob.data_body.description, 'd41d8cd9'), ...
    'the MD5 is the checksum, not free text');
verifyEqual(testCase, ob.data_body.format.node, 'EMPTY:0000315');   % "directory of files"
% Decided by Jess Haley, 2026-10-21 [sorter keys]: kilosort carries NO keys --
% the output folder is the value as-is
verifyFalse(testCase, isfield(obs, 'statement') && isfield(obs.statement, 'keys') ...
    && ~isempty(obs.statement.keys));
% (keys became dimensions + covariates on `data`, data_body AMENDMENT 6)
verifyFalse(testCase, isfield(obs, 'data') && isfield(obs.data, 'dimensions') && ~isempty(obs.data.dimensions));
verifyFalse(testCase, isfield(ob, 'data') && isfield(ob.data, 'dimensions') && ~isempty(ob.data.dimensions));
end

function testKiasortClustersFoldsToCountObservationPlusOpaqueBody(testCase)
% Sibling of kilosort: kiasort_clusters decomposes identically (method 'kiasort',
% kiasort_directory).
body = struct();
body.document_class = struct('class_name', 'kiasort_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_ka'});
body.base = struct('id', 'ka_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.app.kiasort', 'version', '1.0');
body.kiasort_clusters = struct('kiasort_directory', 'ka_out/session1', ...
    'curated_output_MD5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');

out = did2.convert.migrators_j.kiasort_clusters(body);
% 3 -> 4: the app block now becomes a `software` entity instead of being
% dropped -- see the sibling kilosort test above for why this arity moved.
verifyEqual(testCase, numel(out), 5);   % #88: + the software version text_assertion
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    'the app block must become a software entity, not vanish');
obs = out{find(strcmp(names, 'calculation+label'), 1)};
verifyEqual(testCase, obs.base.id, 'ka_1');
verifyEqual(testCase, obs.interaction.method.term.name, 'kiasort');
ob = out{find(strcmp(names, 'opaque_body'), 1)};
verifyEqual(testCase, ob.data_body.filename, 'ka_out/session1');
% [sorter keys] (Jess Haley, 2026-10-21): no keys on kiasort either
verifyFalse(testCase, isfield(obs, 'statement') && isfield(obs.statement, 'keys') ...
    && ~isempty(obs.statement.keys));
% (keys became dimensions + covariates on `data`, data_body AMENDMENT 6)
verifyFalse(testCase, isfield(obs, 'data') && isfield(obs.data, 'dimensions') && ~isempty(obs.data.dimensions));
end

function body = sortingOutputsBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/sorting/
% SpikeInterfaceSortingOutputs.json). Note `depends_on: []` -- the class
% declares NO edges at all, so there is no subject to observe.
body = struct();
body.document_class = struct('class_name', 'spike_interface_sorting_outputs', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 'sis_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.spike_interface_sorting_outputs = struct('sorter_name', 'kilosort', ...
    'sample_rate', 30000, 'unit', 'ms');
body.files = struct('file_list', {{'sorting.sioutputs.zip'}});
end

function testSortingOutputsDefersToSecondPass(testCase)
% Both halves of the old fold were wrong: `num_units` does not exist (the unit
% count is inside sorting.sioutputs.zip, and single-document migrators do not
% read file bytes), and neither does `element_id` -- the class declares NO
% dependencies, so there is no subject to attach an observation to. Because
% num_units never matched, these documents were ALREADY carried through
% unconverted; the change is making the deferral explicit rather than accidental.
out = did2.convert.migrators_j.spike_interface_sorting_outputs(sortingOutputsBody());
verifyClass(testCase, out, 'cell');
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'spike_interface_sorting_outputs');
verifyEqual(testCase, out{1}.spike_interface_sorting_outputs.sorter_name, 'kilosort');
verifyEqual(testCase, out{1}.spike_interface_sorting_outputs.unit, 'ms');
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testSortingOutputsRejectsInventedShape(testCase)
body = sortingOutputsBody();
body.spike_interface_sorting_outputs = struct('sorter_name', 'kilosort', ...
    'num_units', 12, 'sample_rate', 30000);
verifyError(testCase, @() did2.convert.migrators_j.spike_interface_sorting_outputs(body), ...
    'did2:convert:sortingOutputsInventedShape');
end

function testProbeGeometryBecomesPerAxisLengthObservations(testCase)
% probe_geometry -> one length_observation PER POPULATED SPATIAL AXIS about the
% probe-subject, + anchor, + a probe-model term_assertion.
%
% Fixture built from the NDI TEMPLATE. The previous one used num_channels,
% channel_positions, position_units and probe_type -- NOT ONE of which exists on
% the real class, so channel_positions never matched, the isempty guard always
% fired, and every real document was carried through unconverted while this test
% passed.
%
% The real source is three already-named parallel per-site arrays, so each is
% kept as its own observation rather than concatenated into one anonymous array.
v1 = struct();
v1.document_class = struct('class_name', 'probe_geometry', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_5'});
v1.base = struct('id', 'pg_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_geometry = struct( ...
    'site_locations_leftright', [0 20], ...
    'site_locations_frontback', [0 0], ...
    'site_locations_depth', [], ...
    'ndim', 2, 'unit', 'um', ...
    'probe_model', 'linear');
% 2026-10-26: no `manufacturer` (it was 'acme'): a document that sets one is
% carried whole as v1 ([probe contact geometry carried];
% testProbeGeometryWithContactGeometryIsCarriedAsV1).

out = did2.convert.migrators_j.probe_geometry(v1);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
% two populated axes -> two observations; depth is empty so it is NOT emitted
verifyEqual(testCase, sum(strcmp(names, 'observation+length')), 2);
vars = {};
for k = 1:numel(out)
    if strcmp(names{k}, 'observation+length')
        vars{end+1} = out{k}.statement.variable.name; %#ok<AGROW>
    end
end
verifyTrue(testCase, any(strcmp(vars, 'site location (left-right)')));
verifyTrue(testCase, any(strcmp(vars, 'site location (front-back)')));
verifyFalse(testCase, any(strcmp(vars, 'site location (depth)')));

lr = out{find(strcmp(names, 'observation+length'), 1)};
verifyEqual(testCase, depValue(lr, 'entity_id'), 'probe_5');
verifyEqual(testCase, numel(lr.length.value), 2);
verifyEqual(testCase, lr.length.value(2).source_value, 20, 'AbsTol', 1e-9);
verifyEqual(testCase, lr.length.value(1).source_unit.name, 'micrometre');   % registry label for 'um'
verifyEqual(testCase, lr.length.value(2).meters, 2e-5, 'AbsTol', 1e-12);

% probe_model, not the invented probe_type
assertion = out{find(strcmp(names, 'assertion+term'), 1)};
verifyEqual(testCase, assertion.statement.variable.name, 'probe model');
verifyEqual(testCase, assertion.term.value.name, 'linear');
end

function testProbeGeometryWithContactGeometryIsCarriedAsV1(testCase)
% [probe contact geometry carried] (Jess Haley, 2026-10-26): `shank_id`, the
% contact shape and its width / height / radius, `manufacturer`,
% `has_planar_contour` and the contour have no V2 home until a contact-geometry
% model exists, so a document that sets any of them is carried whole as v1
% (they were dropped as "still deferred"). One field at a time.
% (has_planar_contour 2: neither writer default -- 0 and 1 count as not set,
% testProbeGeometryWritersContourFlagDoesNotCarry)
fields = {'shank_id', [1 1]; 'contact_shape', 'circle'; ...
    'contact_shape_width', 12; 'contact_shape_height', 12; ...
    'contact_shape_radius', 6; 'manufacturer', 'acme'; ...
    'has_planar_contour', 2; 'contour_x', [0 1 1 0]; 'contour_y', [0 0 1 1]};
for k = 1:size(fields, 1)
    v1 = struct();
    v1.document_class = struct('class_name', 'probe_geometry', 'class_version', '1.0.0', ...
        'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
    v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_5'});
    v1.base = struct('id', 'pg_3', 'session_id', 'sess_09', 'name', '', ...
        'datestamp', '2024-06-01T12:00:00.000Z');
    v1.probe_geometry = struct('site_locations_leftright', [0 20], ...
        'site_locations_frontback', [0 0], 'ndim', 2, 'unit', 'um', ...
        'probe_model', 'linear');
    v1.probe_geometry.(fields{k, 1}) = fields{k, 2};
    did2.convert.reportNote('reset');
    out = did2.convert.migrators_j.probe_geometry(v1);
    notes = did2.convert.reportNote('collect');
    did2.convert.reportNote('reset');
    verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), ...
        sprintf('%s set: not returned unchanged', fields{k, 1}));
    verifyTrue(testCase, isfield(notes, 'carried_as_v1'), fields{k, 1});
    if isfield(notes, 'carried_as_v1')
        verifyTrue(testCase, contains(notes.carried_as_v1.distinct_details{1}, ...
            ['probe_geometry.' fields{k, 1}]), notes.carried_as_v1.distinct_details{1});
    end
end
end

function testProbeGeometryWritersContourFlagDoesNotCarry(testCase)
% [writer default is not set] (Jess Haley, 2026-10-26): has_planar_contour
% equal to an NDI writer's fixed default -- 1 (template probe_geometry.json:33)
% or 0 (fromStruct.m:73) -- counts as not set, so it alone does not carry the
% document; the fold runs. A non-default value still carries it.
for v = {1, 0, true}
    v1 = struct();
    v1.document_class = struct('class_name', 'probe_geometry', 'class_version', '1.0.0', ...
        'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
    v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_5'});
    v1.base = struct('id', 'pg_4', 'session_id', 'sess_09', 'name', '', ...
        'datestamp', '2024-06-01T12:00:00.000Z');
    v1.probe_geometry = struct('site_locations_leftright', [0 20], ...
        'site_locations_frontback', [0 0], 'ndim', 2, 'unit', 'um', ...
        'probe_model', 'linear', 'has_planar_contour', v{1});
    out = did2.convert.migrators_j.probe_geometry(v1);
    verifyGreaterThan(testCase, numel(out), 1, ...
        sprintf('has_planar_contour %g alone carried the document', double(v{1})));
end
v1.probe_geometry.has_planar_contour = 3;
out = did2.convert.migrators_j.probe_geometry(v1);
verifyTrue(testCase, isscalar(out) && isequaln(out{1}, v1), 'a non-default value carries');
end

function testProbeGeometryRejectsInventedShape(testCase)
% channel_positions/position_units/probe_type are V_alpha inventions. Reading
% them again must be loud, not a silent carry-through.
v1 = struct();
v1.document_class = struct('class_name', 'probe_geometry', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_5'});
v1.base = struct('id', 'pg_2', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_geometry = struct('channel_positions', [0 0; 20 0], ...
    'position_units', 'um', 'probe_type', 'linear');
verifyError(testCase, @() did2.convert.migrators_j.probe_geometry(v1), ...
    'did2:convert:probeGeometryInventedShape');
end
function body = site2ChannelMapBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/probe/
% site2channelmap.json). ONE property field, `map`, and a second dependency the
% old fixture omitted -- probe_geometry_id, which is what makes `map` readable.
body = struct();
body.document_class = struct('class_name', 'site2channelmap', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'probe_id', 'value', 'probe_6'), ...
                    struct('name', 'probe_geometry_id', 'value', 'pg_2')];
body.base = struct('id', 's2c_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.site2channelmap = struct('map', [5; 6; 7; 8]);
end

function testSite2ChannelMapDefersToSecondPass(testCase)
% `num_sites` does not exist, so these documents were ALREADY carried through
% unconverted -- the right outcome reached by accident. `map` is not migratable
% from this document alone either: its i-th element is the channel wired to SITE
% i OF THE REFERENCED probe_geometry, so the numbers mean nothing without that
% document's site ordering. The join is the second pass's to make.
out = did2.convert.migrators_j.site2channelmap(site2ChannelMapBody());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'site2channelmap');
verifyEqual(testCase, out{1}.site2channelmap.map, [5; 6; 7; 8]);
% the edge that gives `map` its meaning is kept
verifyEqual(testCase, depValue(out{1}, 'probe_geometry_id'), 'pg_2');
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testSite2ChannelMapRejectsInventedShape(testCase)
body = site2ChannelMapBody();
body.site2channelmap = struct('num_sites', 32, ...
    'site_to_channel', struct('site', 1, 'channel', 5));
verifyError(testCase, @() did2.convert.migrators_j.site2channelmap(body), ...
    'did2:convert:site2ChannelMapInventedShape');
end

function body = positionMetadataBody()
% the JH writer's shape (+setup/+conv/+haley/doImport.m, Step 6), in the v1
% spelling the migrator reads since it reads raw v1 (did2.convert.rawV1Classes)
body = struct();
body.document_class = struct('class_name', 'position_metadata', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'element_id'}, 'value', {'pos_elem_7'});
body.base = struct('id', 'pm_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.position_metadata = struct('ontologyNode', 'EMPTY:0000200', ...
    'units', 'NCIT:C48367', 'dimensions', 'NCIT:C44477,NCIT:C44478');
end

function testPositionMetadataWithUnitsOrDimensionsIsCarriedWholeAsV1(testCase)
% INVERTS what testPositionMetadataBecomesTermObservation asserted for the
% writer's shape: the term observation dropped `units` and `dimensions`. Since
% [generic stage is lossless] / [partly placed is carried as v1] (Jess Haley,
% 2026-10-25) the document is carried whole as v1, each field on its own too.
v1 = positionMetadataBody();
out = runJ(v1);
verifyCarriedWholeAsV1(testCase, v1, out);
verifyEqual(testCase, out.migrated{1}.get('position_metadata.units'), 'NCIT:C48367');
for f = {'units', 'dimensions'}
    one = positionMetadataBody();
    other = setdiff({'units', 'dimensions'}, f);
    one.position_metadata.(other{1}) = '';
    outOne = runJ(one);
    verifyCarriedWholeAsV1(testCase, one, outOne);
    verifyEqual(testCase, outOne.summary.migration_notes.carried_as_v1.distinct_details{1}, ...
        ['[carry-053] unplaced: position_metadata.' f{1}]);
end
end

function testPositionMetadataBecomesTermObservation(testCase)
% position_metadata carries only DESCRIPTIVE ontology fields -- the numeric
% coordinates live in the separate element/timeseries doc that element_id points
% at, NOT here. So it folds to a term_observation of the element-subject naming
% the measurement term (value = the ontologyNode CURIE), plus a session anchor.
% 1 -> 2. No values are invented. UPDATED for [generic stage is lossless]
% (Jess Haley, 2026-10-25): the fold runs only when it places the document
% whole, i.e. when `units` and `dimensions` are empty (it has no place for
% them); the writer's shape, with both, is carried as v1
% (testPositionMetadataWithUnitsOrDimensionsIsCarriedWholeAsV1).
body = positionMetadataBody();
body.position_metadata.units = '';
body.position_metadata.dimensions = '';

bodies = did2.convert.migrators_j.position_metadata(body);
verifyEqual(testCase, numel(bodies), 2);              % obs + anchor
obs = bodies{1};
verifyEqual(testCase, did2.unittest.helpers.classKey(obs), 'observation+term');
verifyEqual(testCase, obs.term.value.node, 'EMPTY:0000200');
verifyEqual(testCase, obs.statement.variable.name, 'position');
verifyEqual(testCase, obs.statement.variable.node, 'PATO:0000140');
verifyEqual(testCase, depValue(obs, 'entity_id'), 'pos_elem_7');
anchor = bodies{2};
verifyEqual(testCase, did2.unittest.helpers.classKey(anchor), 'relative_time_reference');
verifyEqual(testCase, anchor.relative_time_reference.value.relation.name, 'intervalDuring');
verifyEqual(testCase, depValue(obs, 'time_reference_id'), anchor.base.id);
end

function testSpatialFrequencyTuningFoldsToCalculationLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% spatial_frequency_tuning -> spatial_frequency_tuning_calculation, id-preserved
% (#88). UPDATED for #88: app block added (an operating system is required);
% significance on tuning_curve_calculation, `fitless` on the leaf's
% interpolated_values, `fit_dog` one model_fit entry (its r2 -> goodness.r2, its
% pref -> metrics.preferred_value).
body = struct();
body.document_class = struct('class_name', 'spatial_frequency_tuning', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_2'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_2')];
body.base = struct('id', 'sf_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.spatial_frequency_tuning');
body.spatial_frequency_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('spatial_frequency', [0.05 0.1 0.2 0.5], 'mean', [2 8 5 1]), ...
    'significance', struct('visual_response_anova_p', 0.01, 'across_stimuli_anova_p', 0.03), ...
    'fitless', struct('pref', 0.12, 'l50', 0.06, 'h50', 0.28, 'bandwidth', 2.2, ...
        'low_pass_index', 0.3, 'high_pass_index', 0.7), ...
    'fit_dog', struct('r2', 0.95, 'pref', 0.13));

out = foldPlaceable(testCase, @did2.convert.migrators_j.spatial_frequency_tuning, body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'observation+score')));
verifyFalse(testCase, any(strcmp(names, 'observation+frequency')));
leaf = calcLeafJ(testCase, out, 'spatial_frequency_tuning_calculation', 'sf_1', 'neuron_2');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_2');
verifyEqual(testCase, char(leaf.interaction.method.term.node), 'OBI:0200072');   % [tuning fits use curve fitting now], Jess Haley 2026-10-27
mf = leaf.tuning_curve.value.model_fit;   % [one fit entry], Jess Haley 2026-10-22
verifyEqual(testCase, numel(mf), 1);
verifyEqual(testCase, lower(char(mf(1).model.name)), 'dog');
verifyEqual(testCase, mf(1).goodness.r2, 0.95, 'AbsTol', 1e-9);
verifyEqual(testCase, mf(1).metrics.preferred_value, 0.13, 'AbsTol', 1e-9);
verifyEqual(testCase, leaf.tuning_curve.value.significance.visual_response_anova_p, ...
    0.01, 'AbsTol', 1e-9);
iv = leaf.spatial_frequency_tuning_calculation.interpolated_values;
verifyEqual(testCase, iv.preferred_value, 0.12, 'AbsTol', 1e-9);
verifyEqual(testCase, iv.half_maximum_below, 0.06, 'AbsTol', 1e-9);
end


% ==== temporal_frequency_tuning: the fifth tuning family, built FROM THE WRITER ====

function body = temporalFrequencyTuningBody()
%TEMPORALFREQUENCYTUNINGBODY The did_v1 `temporal_frequency_tuning` body, taken from
%   the WRITER rather than from any DID-side schema. The class ships NO NDI-matlab
%   template -- it is one of the vhlab calculator classes -- measured rather than
%   assumed, and case-insensitively, because this project has twice reported an
%   absence that was a property of the query:
%
%     $ cd NDI-matlab && git ls-files | wc -l
%     1450
%     $ git grep -ril temporal_frequency_tuning   -- . | wc -l    ->  0
%     $ git grep -ril temporalfrequencytuning     -- . | wc -l    ->  0
%     $ git grep -ril tftuning                    -- . | wc -l    ->  0
%
%   So the writer is NDIcalc-vis-matlab, and it is the ONLY construction site of the
%   bare class name in that repository:
%
%     DENOMINATOR: 153 .m file(s) tracked in NDIcalc-vis-matlab (65718ed);
%                  1 construction site for class `temporal_frequency_tuning`
%     +ndi/+calc/+vis/temporal_frequency_tuning.m
%       :274-293  builds the block
%       :295-296  ndi.document('temporal_frequency_tuning', ...
%                     'temporal_frequency_tuning', temporal_frequency_tuning)
%       :297-300  set_dependency_value('element_id', ...) and
%                 set_dependency_value('stimulus_tuningcurve_id', tuning_doc.id())
%
%   THE FIELD NAMES BELOW ARE THE WRITER'S, VERBATIM, AND FOUR OF THEM DIFFER FROM
%   THE ONES THE SIBLING FIXTURE ABOVE GUESSED (testSpatialFrequencyTuningFoldsTo
%   CalculationLeaf builds `fitless.pref/.l50/.h50` and `fit_dog.r2`; the writer
%   emits `Pref`/`L50`/`H50`, and sets no `R2` on the DOG fit at all). The empirical
%   summary block spells its three frequency landmarks CAPITALISED, and the sibling
%   family's writer agrees -- +vis/+frequency/spatial_frequency_analysis.m:66 is the
%   same line for SF. Positive evidence, +vis/+frequency/temporal_frequency_analysis.m:58-68:
%
%     [tf_props.fitless.L50,tf_props.fitless.Pref,tf_props.fitless.H50] = ...
%     tf_props.fitless.bandwidth = vis.frequency.bandwidth(...)
%     tf_props.fitless.low_pass_index  = ...
%     tf_props.fitless.high_pass_index = ...
%
%   and universalRenames does NOT lower-case them: its snake_case sweep touches only
%   the IMMEDIATE field names of a property block ("nested struct values ... are left
%   alone for per-class migrators to handle", universalRenames.m:33-37), and `L50`
%   sits one level down inside `fitless`. So the migrator really does see `Pref`.
%
%   THERE ARE FIVE CO-EXISTING FITS, not one, and their coefficient blocks are NOT
%   the same shape as each other -- read off all 8 of the writer's own mock documents
%   (+ndi/+calc/+vis/mock/temporal_frequency_tuning/mock.[1-8].json):
%
%     DENOMINATOR: 8 mock document(s) read; every field below present in 8/8
%     fit_dog        parameters values fit L50 Pref H50 bandwidth        (no R2)
%     fit_movshon    parameters values fit L50 Pref H50 bandwidth R2
%     fit_movshon_c  parameters values fit L50 Pref H50 bandwidth R2
%     fit_spline                values fit L50 Pref H50 bandwidth        (no parameters)
%     fit_gausslog   parameters values fit L50 Pref H50 bandwidth        (no R2)
%
%   The TEMPLATE disagrees with the writer in at least two ways that matter here,
%   and per the ground-truth rule the WRITER WINS:
%   ndi_common/database_documents/vision/temporal_frequency_tuning.json declares a
%   `fit_sgauss` block the writer never emits, and gives `fit_dog` an `R2` the writer
%   never sets (it also omits `fit_gausslog`, which the writer always emits). The
%   fixture follows the writer; none of the template-only fields appear below.
%
%   `abs` (a complete second analysis of the rectified responses: fitless + the same
%   five fits, writer :288-293) IS included here because real documents carry it. So
%   are `properties.response_units` -- whose real value is EMPTY in 8/8 mocks -- and
%   the five control-response fields, which the writer puts INSIDE `tuning_curve`
%   (:260-264), not beside it. The current reshape carries none of those three; that
%   is reported as an open item and is deliberately NOT asserted here, so repairing
%   the reshape does not have to fight a test that pinned the gap.
body = struct();
body.document_class = struct('class_name', 'temporal_frequency_tuning', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'tf_elem_3'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_tf_9')];
body.base = struct('id', 'tft_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
% The `app` block every real calculator document carries (a Soph
% temporal_frequency_tuning_calc sample has exactly these keys). #88's calculation
% requires an operating system, read from app.os.
body.app = calcAppJ('ndi.calc.vis.temporal_frequency_tuning');

% properties: response_units is EMPTY in 8/8 of the writer's mock documents, so it is
% built by assignment rather than through struct(), which would be a lie about shape.
props = struct('response_type', 'mean');
props.response_units = [];

% tuning_curve, writer :254-264. The independent axis is named `temporal_frequency`;
% the control vectors live in here, not on the block.
tc = struct( ...
    'temporal_frequency', [1; 2; 4; 8], ...
    'mean',               [1; 5; 9; 3], ...
    'stddev',             [0.1; 0.2; 0.3; 0.4], ...
    'stderr',             [0.05; 0.1; 0.15; 0.2], ...
    'control_mean',       [0.5; 0.5; 0.5; 0.5], ...
    'control_stddev',     [0.02; 0.02; 0.02; 0.02], ...
    'control_stderr',     [0.01; 0.01; 0.01; 0.01], ...
    'control_mean_stddev', 0.02, ...
    'control_mean_stderr', 0.01);
tc.individual = [1.0 5.1 8.8 3.2; 1.1 4.9 9.2 2.8];   % vlt.data.cellarray2mat(resp.ind)

fitless = struct('L50', 1.4, 'Pref', 4.2, 'H50', 9.6, 'bandwidth', 2.78, ...
    'low_pass_index', 0.31, 'high_pass_index', 0.07);

fitDog = struct('parameters', [0; 1.1; 2.2; 3.3; 4.4], 'values', [1; 2; 4; 8], ...
    'fit', [1.2; 5.0; 8.9; 3.1], 'L50', 1.5, 'Pref', 4.1, 'H50', 9.4, ...
    'bandwidth', 2.65);
fitMovshon = struct('parameters', [1; 2; 3; 4], 'values', [1; 2; 4; 8], ...
    'fit', [1.1; 5.2; 8.7; 3.0], 'L50', 1.6, 'Pref', 4.0, 'H50', 9.1, ...
    'R2', 0.83, 'bandwidth', 2.51);
fitMovshonC = struct('parameters', [1; 2; 3; 4; 5], 'values', [1; 2; 4; 8], ...
    'fit', [1.0; 5.3; 8.6; 3.4], 'L50', 1.7, 'Pref', 3.9, 'H50', 9.0, ...
    'R2', 0.87, 'bandwidth', 2.40);
fitSpline = struct('values', [1; 2; 4; 8], 'fit', [1.0; 5.0; 9.0; 3.0], ...
    'L50', 1.3, 'Pref', 4.3, 'H50', 9.8, 'bandwidth', 2.91);
fitGausslog = struct('parameters', [1; 2; 3; 4], 'values', [1; 2; 4; 8], ...
    'fit', [1.3; 4.8; 9.1; 2.9], 'L50', 1.45, 'Pref', 4.15, 'H50', 9.5, ...
    'bandwidth', 2.71);

blk = struct();
blk.properties    = props;
blk.tuning_curve  = tc;
blk.significance  = struct('visual_response_anova_p', 0.002, ...
                           'across_stimuli_anova_p', 0.031);
blk.fitless       = fitless;
blk.fit_dog       = fitDog;
blk.fit_movshon   = fitMovshon;
blk.fit_movshon_c = fitMovshonC;
blk.fit_spline    = fitSpline;
blk.fit_gausslog  = fitGausslog;
% the rectified-response duplicate analysis, abridged to two of its six sub-blocks
blk.abs = struct('fitless', fitless, 'fit_dog', fitDog);

body.temporal_frequency_tuning = blk;
end

function testTemporalFrequencyTuningFoldsToCalculationLeaf(testCase)
% UPDATED 2026-10-25 ([generic stage is lossless]): the fixture states a
% field the fold has no home for, so the migrator carries it whole as v1;
% foldPlaceable asserts that, removes exactly the fields the carry names, and
% folds what is left -- the assertions below are about the placed fields.
% did_v1 temporal_frequency_tuning -> temporal_frequency_tuning_calculation
% (#88), from the WRITER-shaped fixture below. UPDATED for #88: the leaf is the
% concrete *_calculation class (under tuning_curve_calculation); the consumed
% curve -> input_id; the TF axis -> data.keys; the five co-existing fits ->
% tuning_curve_calculation.model_fit with {model, coefficients list, goodness,
% metrics, sampled_fit}; `fitless` -> the leaf's interpolated_values.
% UPDATED 2026-10-27 ([absolute-value fits are a second calculation], Jess
% Haley): the `abs` block no longer carries the document; it is a second
% calculation of the same class, whose method says the response was made
% absolute.
out = did2.convert.migrators_j.temporal_frequency_tuning(temporalFrequencyTuningBody());
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 9);
absCalcs = {};
for k = 1:numel(out)
    b = out{k};
    if isfield(b, 'temporal_frequency_tuning_calculation') && ~strcmp(char(b.base.id), 'tft_1')
        absCalcs{end+1} = b; %#ok<AGROW>
    end
end
assertEqual(testCase, numel(absCalcs), 1, 'one absolute-value calculation');
verifyEqual(testCase, paramTextJ(absCalcs{1}, 'response transform'), 'absolute value');
verifyEqual(testCase, numel(absCalcs{1}.tuning_curve.value.model_fit), 1, 'the abridged abs block: fit_dog');
verifyFalse(testCase, any(strcmp(names, 'observation+frequency')));
leaf = calcLeafJ(testCase, out, 'temporal_frequency_tuning_calculation', 'tft_1', 'tf_elem_3');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_tf_9');
verifyEqual(testCase, depValue(leaf, 'session_id'), 'sess_09');
superNames = {leaf.document_class.superclasses.class_name};
verifyTrue(testCase, any(strcmp(superNames, 'tuning_curve_calculation')));
verifyEqual(testCase, char(leaf.interaction.method.term.node), 'OBI:0200072');   % [tuning fits use curve fitting now], Jess Haley 2026-10-27
% [one calculation per named calculator output] (Jess Haley, 2026-10-28): the
% method holds no `function` list; the five fits name their own models
verifyEqual(testCase, nParamsJ(leaf), 0, ...
    'a bare temporal_frequency_tuning document carries no input_parameters, and its five models write no function list');
verifyEqual(testCase, paramTextJ(leaf, 'function'), '');

verifyEqual(testCase, leaf.data.covariates(1).quantity.value, [1 2 4 8]);
verifyEqual(testCase, lower(leaf.data.dimensions(1).term.name), 'temporal frequency');
v = leaf.tuning_curve.value;
verifyEqual(testCase, v.mean, [1; 5; 9; 3]);
verifyEqual(testCase, v.stddev, [0.1; 0.2; 0.3; 0.4]);
verifyEqual(testCase, v.stderr, [0.05; 0.1; 0.15; 0.2]);
verifyEqual(testCase, size(v.individual), [4 2]);   % #88 D3: stimuli x trials
verifyEqual(testCase, v.control.mean, [0.5; 0.5; 0.5; 0.5]);
verifyEqual(testCase, leaf.tuning_curve.value.significance.visual_response_anova_p, ...
    0.002, 'AbsTol', 1e-12);
verifyEqual(testCase, leaf.tuning_curve.value.significance.across_stimuli_anova_p, ...
    0.031, 'AbsTol', 1e-12);
iv = leaf.temporal_frequency_tuning_calculation.interpolated_values;
verifyEqual(testCase, iv.preferred_value, 4.2, 'AbsTol', 1e-12);

mf = leaf.tuning_curve.value.model_fit;   % [one fit entry], Jess Haley 2026-10-22
assertEqual(testCase, numel(mf), 5, ...
    ['the TF family carries five co-existing fits (dog, movshon, movshon_c, ' ...
     'spline, gausslog); a single model_fit means the array collapsed']);
gotModels = sort(arrayfun(@(e) lower(char(e.model.name)), mf, 'UniformOutput', false));
verifyEqual(testCase, gotModels, {'dog', 'gausslog', 'movshon', 'movshon c', 'spline'});
mv = mf(strcmp(arrayfun(@(e) lower(char(e.model.name)), mf, 'UniformOutput', false), 'movshon'));
assertEqual(testCase, numel(mv), 1, 'expected exactly one movshon entry');
verifyEqual(testCase, mv.goodness.r2, 0.83, 'AbsTol', 1e-12);
verifyEqual(testCase, mv.metrics.preferred_value, 4.0, 'AbsTol', 1e-12);
dg = mf(strcmp(arrayfun(@(e) lower(char(e.model.name)), mf, 'UniformOutput', false), 'dog'));
assertEqual(testCase, numel(dg), 1, 'expected exactly one dog entry');
verifyEqual(testCase, nCoeffJ(dg), 5);   % [0 a1 b1 a2 b2]
verifyEqual(testCase, dg.metrics.bandwidth, 2.65, 'AbsTol', 1e-12);
sp = mf(strcmp(arrayfun(@(e) lower(char(e.model.name)), mf, 'UniformOutput', false), 'spline'));
assertEqual(testCase, numel(sp), 1, 'expected exactly one spline entry');
verifyEqual(testCase, nCoeffJ(sp), 0, ...
    'the spline fit has no parameters block in the writer; coefficients here would be invented');
verifyFalse(testCase, any(strcmp(gotModels, 'abs')));
end

% ---- helpers for the #88 calculation tests ----


function testNeuronExtracellularMintsDerivedSubject(testCase)
% #9 grain-B pattern: a sorted unit is a DERIVED subject, not an observation of the
% recording. neuron_extracellular -> entity (cell) + derived_from relation (unit <-
% the recording element) + anchor + CALCULATIONS about the unit (#73 review item
% 48, 2026-10-21): cluster_index as a label, quality_number as a score. No app
% block here, so NO software (Decided by Jess Haley, 2026-10-22 [sorter
% software]; it was the invented 'spike sorter' fallback until then). 1 -> 5.
%
% WAS 4 UNTIL 2026-08-17. The fifth body is the `count_assertion` carrying
% `cluster_index`, which until then survived only as text inside
% `subject.local_identifier`. This fixture carries NO `mean_waveform`, so the
% sixth body (the voltage_observation) is correctly absent here -- that fold has
% its own file, testMigratorsJNeuronExtracellular.m.
body = struct();
body.document_class = struct('class_name', 'neuron_extracellular', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'rec_sub_1'});
body.base = struct('id', 'ne_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.neuron_extracellular = struct('cluster_index', 7, 'quality_number', 3, ...
    'number_of_channels', 1);   % no waveform: the writers' 1 (a 4 is carried as v1)

out = did2.convert.migrators_j.neuron_extracellular(body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
% INVERTED 2026-10-27 ([neuron uses the sorted unit's cell], Jess Haley): no
% unit entity and no derived_from are minted; the calculations are about the
% element's own entity (rec_sub_1). 1 -> 3: the anchor and two calculations.
verifyEqual(testCase, numel(out), 3, ...
    sprintf('expected 3 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyFalse(testCase, any(strcmp(names, 'cell')), 'no entity of its own');
verifyFalse(testCase, any(strcmp(names, 'directed_relation')), 'no derived_from of its own');
verifyTrue(testCase, any(strcmp(names, 'calculation+score')));
verifyTrue(testCase, any(strcmp(names, 'calculation+label')));
verifyFalse(testCase, any(strcmp(names, 'software')), 'no software is invented');
verifyFalse(testCase, any(strcmp(names, 'calculation+voltage')), ...
    'no mean_waveform in this fixture -- a calculation here would be a husk');
% the quality calculation is about the sorted unit's entity, the element
qobs = out{find(strcmp(names, 'calculation+score'), 1)};
verifyEqual(testCase, depValue(qobs, 'entity_id'), 'rec_sub_1');
verifyEqual(testCase, qobs.score.value.score, 3, 'AbsTol', 1e-9);
% [every v1 id survives]: the first calculation (the cluster index) keeps ne_1
lab = out{find(strcmp(names, 'calculation+label'), 1)};
verifyEqual(testCase, lab.base.id, 'ne_1');
end

function body = spikeClustersBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/apps/
% spikesorter/spike_clusters.json). Three property fields, none of which the old
% fixture had; four dependencies, of which the old fixture had two.
body = struct();
body.document_class = struct('class_name', 'spike_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'app'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
body.depends_on = [ struct('name', 'sorting_parameters_id', 'value', 'sp_1'), ...
                    struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'extraction_parameters_id', 'value', 'ep_1'), ...
                    struct('name', 'spikewaves_doc_id', 'value', 'sw_1')];
body.base = struct('id', 'sc_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
body.spike_clusters = struct('epoch_info', struct('epoch_number', 1), ...
    'clusterinfo', struct('number', {1, 2}, 'quality', {'good', 'mua'}), ...
    'waveform_sample_times', [0; 1; 2]);
body.files = struct('file_list', {{'spike_cluster.bin'}});
end

function testSpikeClustersDefersToSecondPass(testCase)
% The old fold declared a sampled_body of n = num_spikes. `num_spikes` does not
% exist, so it defaulted to 0 and every document claimed the sorter assigned NO
% spikes -- a fabricated measurement invisible to both Phase 1 counters (the
% value is numeric 0, not a blank, and output WAS produced). The count is
% recoverable only from spike_cluster.bin, which single-document migrators carry
% without reading.
out = did2.convert.migrators_j.spike_clusters(spikeClustersBody());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'spike_clusters');
verifyEqual(testCase, numel(out{1}.spike_clusters.clusterinfo), 2);
verifyEqual(testCase, out{1}.spike_clusters.waveform_sample_times, [0; 1; 2]);
verifyEqual(testCase, out{1}.files.file_list{1}, 'spike_cluster.bin');
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testSpikeClustersRejectsInventedShape(testCase)
body = spikeClustersBody();
body.spike_clusters = struct('num_clusters', 5, 'num_spikes', 400);
verifyError(testCase, @() did2.convert.migrators_j.spike_clusters(body), ...
    'did2:convert:spikeClustersInventedShape');
end

function testHartleyCalcWithoutAnNgridBlockIsRefused(testCase)
% INVERTED 2026-10-21 (was testHartleyCalcPassesThroughOn88). The passthrough
% existed because receptive_field.value was a REQUIRED structure declaring no
% sub-fields, so no receptive_field_calculation could validate (corpus run
% 39550766416 quarantined all 210 of 20211116's documents). did-schema
% data_body AMENDMENT 5 (rule value_inline_or_body) lifted that: the fold
% runs, and this fixture, which carries no `ngrid` block and so no response
% volume, is REFUSED rather than emitted as a receptive field whose value
% lives nowhere. testMigratorsJHartleyCalc owns the fold itself.
body = struct();
body.document_class = struct('class_name', 'hartley_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_h'});
body.base = struct('id', 'hc_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.hartley_calc = struct('input_parameters', struct());
verifyError(testCase, @() did2.convert.migrators_j.hartley_calc(body), ...
    'did2:convert:hartleyNgridBlockMissing');
end

function testFitcurveFoldsToResidualScore(testCase)
% did-schema #88 (#73 review item 68): a fit is a `model_fit_calculation`, its
% value a `model_fit` composite {model, equation, coefficients, goodness}, NOT
% a residual score_observation. A calculation REQUIRES an operating system, so
% the fold happens only for a source whose `app` block names one; this fixture
% (the NDI template's fields plus an element_id and an app block) folds, and
% the one below without an app block passes through.
body = fitcurveBody('fc_1', 'sub_9');
body.app = struct('name', 'ndi.fit', 'version', '1.0', 'os', 'GLNXA64', ...
    'os_version', '6.1', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
out = did2.convert.migrators_j.fitcurve(body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'calculation+model_fit')), strjoin(names, ', '));
calc = out{find(strcmp(names, 'calculation+model_fit'), 1)};
verifyEqual(testCase, calc.base.id, 'fc_1', 'id preserved');
verifyEqual(testCase, depValue(calc, 'entity_id'), 'sub_9');
verifyNotEmpty(testCase, depValue(calc, 'operating_system_id'));
verifyEqual(testCase, calc.model_fit.value.equation, 'gaussian');
verifyEqual(testCase, calc.model_fit.value.goodness.sse, 12.5, 'AbsTol', 1e-9);
end

function testFitcurveWithNoOperatingSystemFoldsWithoutTheEdge(testCase)
% INVERTED 2026-10-21 (was testFitcurveWithNoOperatingSystemPassesThrough).
% A calculation's operating_system_id is OPTIONAL (Jess Haley, 2026-10-21
% [calculation-os-optional], did-schema f8ab172): "required when the
% operating system is known, absent when the source never recorded it". So the
% same document with no `app` block now FOLDS, with the edge omitted --
% never invented.
out = did2.convert.migrators_j.fitcurve(fitcurveBody('fc_1', 'sub_9'));
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
assertTrue(testCase, any(strcmp(names, 'calculation+model_fit')), strjoin(names, ', '));
calc = out{find(strcmp(names, 'calculation+model_fit'), 1)};
verifyEqual(testCase, calc.base.id, 'fc_1', 'id preserved');
verifyEqual(testCase, depValue(calc, 'entity_id'), 'sub_9');
verifyEmpty(testCase, depValue(calc, 'operating_system_id'), ...
    'no operating system was recorded, so none is named');
verifyEqual(testCase, calc.model_fit.value.goodness.sse, 12.5, 'AbsTol', 1e-9);
end

function body = fitcurveBody(id, elementId)
% Built from the NDI TEMPLATE: fit_equation and fit_sse are what it carries.
body = struct();
body.document_class = struct('class_name', 'fitcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {elementId});
body.base = struct('id', id, 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.fitcurve = struct('fit_equation', 'gaussian', 'fit_sse', 12.5);
end

function testFitcurveWithNoSubjectPassesThroughInsteadOfObservingNobody(testCase)
% THE GUARD. This fixture is the NDI TEMPLATE EXACTLY: one dependency,
% `fit_example_data_id`, and no subject-bearing edge of any kind. That is what
% a real fitcurve document looks like -- `element_id` has never been in the
% template's history and NDI has no writer for the class at all.
%
% NOTE WHAT THIS MEANS ABOUT THE TEST ABOVE. testFitcurveFoldsToResidualScore
% hands the migrator an `element_id`, i.e. it asserts the migrator's own
% assumption back to it, so it could never have caught this. It stays, because
% documents MAY carry edges the template does not declare and that path has to
% keep working -- but it is not evidence that the path is ever taken.
%
% Before the guard this emitted a score_observation with an empty subject_id:
% a residual sum of squares about nobody, invisible to every gate because
% references.m skips empty edges.
body = struct();
body.document_class = struct('class_name', 'fitcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'fit_example_data_id'}, 'value', {''});
body.base = struct('id', 'fc_2', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.fitcurve = struct('fit_equation', 'gaussian', 'fit_sse', 12.5);

out = did2.convert.migrators_j.fitcurve(body);

verifyEqual(testCase, numel(out), 1, ...
    'a subject-less fitcurve must pass through as exactly one document');
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'observation+score')), ...
    'must NOT emit an observation with no subject');
verifyEqual(testCase, names{1}, 'fitcurve');
% id preserved and the payload intact, so the second pass still has both.
verifyEqual(testCase, out{1}.base.id, 'fc_2');
verifyEqual(testCase, out{1}.fitcurve.fit_sse, 12.5, 'AbsTol', 1e-9);
verifyEqual(testCase, out{1}.fitcurve.fit_equation, 'gaussian');
end

function testFitcurveWithAnEmptyElementIdIsAlsoGuarded(testCase)
% The edge being PRESENT but blank is the same defect as the edge being absent
% -- and it is the shape the invented-empty-edge pattern produces, so it is
% worth pinning separately rather than assuming the isempty covers it.
body = struct();
body.document_class = struct('class_name', 'fitcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {''});
body.base = struct('id', 'fc_3', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.fitcurve = struct('fit_equation', 'gaussian', 'fit_sse', 1.5);

out = did2.convert.migrators_j.fitcurve(body);

verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'fitcurve');
verifyEqual(testCase, out{1}.base.id, 'fc_3');
end

function testVmspikefitFoldsToResidualScore(testCase)
% did-schema #88: as fitcurve -- a calculation with the model_fit value kind.
% UPDATED 2026-10-21: operating_system_id is OPTIONAL (Jess Haley
% [calculation-os-optional]), so with no app block (the NDI template ships
% none) it FOLDS with no operating_system_id edge, instead of passing through.
body = struct();
body.document_class = struct('class_name', 'vmspikefit', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_a'});
body.base = struct('id', 'vf_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.vmspikefit = struct('fit_equation', 'exp2', 'fit_sse', 3.25);
out = did2.convert.migrators_j.vmspikefit(body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
assertTrue(testCase, any(strcmp(names, 'calculation+model_fit')), strjoin(names, ', '));
calc0 = out{find(strcmp(names, 'calculation+model_fit'), 1)};
verifyEqual(testCase, calc0.base.id, 'vf_1');
verifyEmpty(testCase, depValue(calc0, 'operating_system_id'));
body.app = struct('name', 'vm', 'version', '1', 'os', 'GLNXA64');
out = did2.convert.migrators_j.vmspikefit(body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
calc = out{find(strcmp(names, 'calculation+model_fit'), 1)};
verifyEqual(testCase, calc.model_fit.value.equation, 'exp2');
verifyEqual(testCase, calc.model_fit.value.goodness.sse, 3.25, 'AbsTol', 1e-9);
end

function body = simpleCalcDoc()
% Built from the NDI template + writer (+ndi/+calc/+example/simple.m), NOT from
% our schema: the block is {input_parameters, answer}, the only edge is
% document_id pointing at the INPUT document, and the parent is app -- not the
% result_value/result_units/element_id/calculator shape our V_alpha snapshot
% claimed.
body = struct();
body.document_class = struct('class_name', 'simple_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'app'}, 'class_version', {'1.0.0', '1.0.0'}));
body.depends_on = struct('name', {'document_id'}, 'value', {'input_doc_1'});
body.base = struct('id', 'sm_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.example.simple', 'version', '1.0');
body.simple_calc = struct('input_parameters', struct('answer', 5), 'answer', 5);
end

function testSimpleCalcDefersToSecondPass(testCase)
% simple_calc has no subject-bearing edge: the writer sets only document_id,
% pointing at the document the calculation ran ON. Reaching a subject means
% following that edge, which needs the migrated-id graph. So the document is
% carried through intact rather than turned into an observation about nobody.
out = did2.convert.migrators_j.simple_calc(simpleCalcDoc());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'simple_calc');
verifyEqual(testCase, out{1}.simple_calc.answer, 5);
% no husk observation, and no stray anchor left behind either
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testSimpleCalcRejectsInventedShape(testCase)
% result_value/result_units are DID-side inventions -- the class has no units
% field at all. Their presence means a fixture or caller was built against our
% schema instead of the real document, which is the mistake being corrected.
body = simpleCalcDoc();
body.simple_calc = struct('result_value', 12.5, 'result_units', 'Hz');
verifyError(testCase, @() did2.convert.migrators_j.simple_calc(body), ...
    'did2:convert:simpleCalcInventedShape');
end

function testTheNeedsHomeClassesAreCarriedWholeAsV1(testCase)
% [simple_calc carries as needs home] and [unbuilt spike classes carry as needs
% home] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): each is carried whole as v1 through the
% carry path, citing a needs-home register row (carry-101..104), read raw so
% the carry is
% the untouched v1 source.
fixtures = {simpleCalcDoc(), spikewavesBody(), spikeClustersBody(), binnedSpikeRateBody()};
for k = 1:numel(fixtures)
    v1 = jsondecode(jsonencode(fixtures{k}));
    cls = v1.document_class.class_name;
    verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), cls)), [cls ': read raw']);
    out = runJ(v1);
    verifyCarriedWholeAsV1(testCase, v1, out);
    emitted = out.migrated{1}.toStruct();
    verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1', cls);
    emitted.document_class = rmfield(emitted.document_class, 'schema_version');
    verifyTrue(testCase, isequaln(emitted, v1), [cls ': the carry is not the v1 source']);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    rowOf = struct('simple_calc', 'carry-104', 'spikewaves', 'carry-101', ...
        'spike_clusters', 'carry-102', 'binnedspikeratevm', 'carry-103');
    verifyTrue(testCase, startsWith(d, ['[' rowOf.(cls) '] ']), [cls ': ' d]);
    verifyTrue(testCase, contains(d, 'awaiting_home'), [cls ': ' d]);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried, cls);
    verifyTrue(testCase, r.ok, cls);
end
end

function body = vmResidualsBody()
% Fixture built from the NDI TEMPLATE (ndi_common/database_documents/apps/
% vhlab_voltage2firingrate/vmneuralresponseresiduals.json). element_id is the
% ONLY dependency -- the vmspikefit_id edge the old fixture carried does not
% exist -- and the fit-quality fields are goodness_of_fit / total_power /
% residual_power, not mean_residual.
body = struct();
body.document_class = struct('class_name', 'vmneuralresponseresiduals', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_c'});
body.base = struct('id', 'rr_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.vmneuralresponseresiduals = struct( ...
    'element_epochid', 't00001', ...
    'parameters', struct('number_traces', 1, 'samples_per_trace', 1000, 'units', 'V'), ...
    'column_labels', struct('first_column', 'Time (s)', ...
        'second_column', 'Raw signal', 'third_column', 'Raw signal with spikes', ...
        'fourth_column', 'Fit signal', 'fifth_column', 'Residual signal'), ...
    'goodness_of_fit', '', 'total_power', '', 'residual_power', '');
end

function testVmResidualsDefersToSecondPass(testCase)
% THE FRAGMENT FAILURE MODE, and the reason Phase 1 needed more than one
% counter. `mean_residual` never matched, so the isnumeric guard never passed
% and the old migrator fell out of its only branch having emitted nothing but a
% bare session anchor: payload dropped, stray time-reference left behind. That
% is not hollow (no blank required field) and not an unconverted document
% (output WAS produced), so NO counter saw it.
out = did2.convert.migrators_j.vmneuralresponseresiduals(vmResidualsBody());
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out{1}), 'vmneuralresponseresiduals');
verifyEqual(testCase, out{1}.vmneuralresponseresiduals.element_epochid, 't00001');
verifyEqual(testCase, out{1}.vmneuralresponseresiduals.column_labels.fifth_column, ...
    'Residual signal');
% no husk observation, and no stray anchor either
verifyFalse(testCase, isfield(out{1}, 'subject_statement'));
end

function testVmResidualsRejectsInventedShape(testCase)
body = vmResidualsBody();
body.vmneuralresponseresiduals = struct('mean_residual', 1.7);
verifyError(testCase, @() did2.convert.migrators_j.vmneuralresponseresiduals(body), ...
    'did2:convert:vmResidualsInventedShape');
end

function testAnUnplacedSyncruleMappingIsCarriedUntouched(testCase)
% INVERTS testSyncruleMappingEpochnodeToTimeReference, which pinned the #58
% reshape (epoch_clock / epoch_id nested under a time_reference, stamped
% did_v2). A mapping that cannot be placed between two per-system references is
% carried UNTOUCHED as v1 ([passthrough stays v1], [generic stage is lossless];
% [device clocks on one epoch] (3), Jess Haley, 2026-10-26).
body = struct();
body.document_class = struct('class_name', 'syncrule_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'syncgraph_id', 'value', 'sg_1'), ...
                    struct('name', 'syncrule_id',  'value', 'sr_1') ];
body.base = struct('id', 'sm_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
nodeA = struct('epoch_clock', 'dev_local_time', 'epoch_id', 't00001', ...
    'epoch_session_id', 'sess_09', 'epochprobemap', 'name\treference\n', ...
    'objectclass', 'ndi.daq.system.mfdaq', 'objectname', 'vhvis_spike2', ...
    't0_t1', [0 300]);
nodeB = struct('epoch_clock', 'utc', 'epoch_id', 't00002', ...
    'epoch_session_id', 'sess_09', 'epochprobemap', '', 'objectclass', '', ...
    'objectname', 'vhintan', 't0_t1', [5 305]);
body.syncrule_mapping = struct('cost', 1.0, 'mapping', [1 0; 0 1], ...
    'epochnode_a', nodeA, 'epochnode_b', nodeB);
bodies = did2.convert.migrators_j.syncrule_mapping(body);
verifyEqual(testCase, numel(bodies), 1);
verifyTrue(testCase, isequaln(bodies{1}, body), 'returned untouched');
out = runJ(body);
verifyEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};
verifyEqual(testCase, char(d.get('document_class.schema_version')), 'did_v1');
verifyEqual(testCase, d.get('syncrule_mapping.epochnode_a.epoch_clock'), 'dev_local_time');
verifyEqual(testCase, d.get('syncrule_mapping.epochnode_b.objectname'), 'vhintan');
verifyTrue(testCase, isfield(out.summary.migration_notes, 'carried_as_v1'));
end

% ===================== oneepoch: a class that had NO schema ===============
%
% `oneepoch` reached 2026-08-10 with no V_eta schema, no migrator and no row on
% any worklist, because coverage.py tagged it non-production -- which suppresses
% the coverage gap. It is production: ndi.element.oneepoch concatenates an
% element's N epochs into one, written at src/ndi/element.m:387 and read back at
% +ndi/+element/oneepoch.m:78-80. A real document quarantined on "No schema file
% for class oneepoch" (measured, scratch probe 8, run 31423494433).
%
% These drive the FULL pipeline via runJ, not the migrator directly. That matters:
% the whole reason this migrator exists is that a BASE superclass migrator has
% already rewritten the inherited block before the concrete migrator runs, and
% calling migrators_j.oneepoch on a raw v1 body would test a shape that never
% actually occurs.

function testOneEpochFoldsItsInheritedBlockAndKeepsItsClass(testCase)
% element_epoch is renamed to acquisition_epoch in V_eta, so no class of that
% name exists for oneepoch to inherit from -- and the validator's top-level check
% is strict. The inherited block must end up on the concrete one.
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_1'});
v1.base = struct('id', 'oe_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', 't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

out = runJ(v1);
verifyEmpty(testCase, out.quarantine, 'oneepoch must not quarantine');
verifyEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};

% the class is KEPT -- this is a fold, not a dissolution
verifyEqual(testCase, did2.unittest.helpers.classKey(d), 'oneepoch');
% the inherited block is GONE from the top level. Checked with isfield on the
% struct rather than by expecting d.get() to throw -- probe 7's lesson: an
% assertion about behaviour I have not observed is an assertion that can pass for
% the wrong reason.
sOut = d.toStruct();
verifyFalse(testCase, isfield(sOut, 'element_epoch'), ...
    'the element_epoch block must not survive -- no V_eta class hosts it');
verifyTrue(testCase, isfield(sOut, 'oneepoch'));
end

function testOneEpochCarriesTheClocksTheBaseMigratorBuilt(testCase)
% The multi-clock case is REAL here: oneepoch.m:124 writes strjoin(ecs,','), every
% clock the element had, where a plain element_epoch carries one. The base
% element_epoch migrator parses the 2-by-N t0_t1 convention; this migrator must
% MOVE that result without reshaping it.
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_1'});
v1.base = struct('id', 'oe_2', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', 't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

d = runJ(v1).migrated{1};
clocks = d.get('oneepoch.clocks');
verifyEqual(testCase, numel(clocks), 2, ...
    'both clocks in the comma-joined list must survive');
verifyEqual(testCase, clocks(1).name, 'utc');
verifyEqual(testCase, clocks(1).t0, 0);
verifyEqual(testCase, clocks(1).t1, 2);
verifyEqual(testCase, clocks(2).name, 'dev_local_time');
verifyEqual(testCase, clocks(2).t0, 1);
verifyEqual(testCase, clocks(2).t1, 3);
end

function testOneEpochKeepsTheSourceEpochIdsAndTheElementEdge(testCase)
% epoch_ids is the ONLY field the class declares itself and the whole reason it is
% distinct from element_epoch -- under fork A1 it becomes the derived_from_# edges.
% Losing it would leave a concatenation that cannot say what it concatenated.
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_1'});
v1.base = struct('id', 'oe_3', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0; 930.35]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

d = runJ(v1).migrated{1};
verifyEqual(testCase, d.get('oneepoch.epoch_ids'), 't00001,t00002,t00003');
% the SYNTHETIC epoch id survives too -- sourceCensus tracks exactly this string
% as a grouping hazard, citing oneepoch.m:42, so it must not be quietly dropped
verifyEqual(testCase, d.get('epochid.epochid'), 'whole_session_ref1');
% READ THE EDGE TOLERANTLY. A depends_on entry is spelled `value` on a body a
% migrator built and `document_id` once universalRenames has normalised it
% (universalRenames.m:372-380), and BOTH shapes are live -- this document is a
% passthrough, so its edge came through the rename and carries `document_id`
% (observed: scratch probe 9, run 31424544834, printed `fieldnames: name,
% document_id`).
%
% Reading one spelling is what broke this test twice: first via `depValue`, which
% read only `value`, and then via `depVal`, which reads only `value` too -- I
% swapped helpers on the INFERENCE that get() and toStruct() disagreed, without
% ever observing get(). That inference was the error, not the first helper.
%
% The tolerant read is the codebase's own convention, not an invention here:
% +did2/+validate/references.m:176-179 takes `document_id` when present and falls
% back to `value`, with exactly this precedence. depValue now does the same.
verifyEqual(testCase, depValue(d.toStruct(), 'element_id'), 'elem_1');
end

function testOneEpochValidatesAgainstItsNewTombstone(testCase)
% THE POINT OF THE WHOLE CHANGE, asserted with validation ON rather than inferred
% from the three tests above. Before the tombstone existed this quarantined with
% "No schema file for class oneepoch"; the fold and the schema have to agree, and
% only a validating run proves they do. runJ deliberately passes Validate=false,
% so this calls v1_to_v2 directly.
v1 = struct();
v1.document_class = struct('class_name', 'oneepoch', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'element_epoch', 'class_version', '1.0.0'), ...
                      struct('class_name', 'base',          'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid',       'class_version', '1.0.0')]);
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_1'});
v1.base = struct('id', 'oe_4', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', 't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('oneepoch quarantined under validation: %s', ...
        out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'oneepoch');
end

function v = depValue(b, name)
% Read an edge off a RAW BODY STRUCT (a direct migrator call, or toStruct()).
%
% ACCEPTS BOTH SPELLINGS, deliberately. universalRenames normalises v1's
% {name, value} to {name, document_id} (universalRenames.m:372-380), so which one
% a body carries depends on where it came from: a migrator that BUILT the edge
% still has `value`, while an edge that came through the rename -- as any
% passthrough's does -- has `document_id`. Observed, not inferred: scratch probe
% 9 (run 31424544834) printed `fieldnames: name, document_id` on a migrated
% oneepoch body, and reading only `value` threw MATLAB:nonExistentField.
%
% This precedence is copied from +did2/+validate/references.m:176-179, which
% takes document_id when present and falls back to value. That the orphan checker
% needs the same fallback is the evidence that both shapes are genuinely live.
%
% `depVal` above reads ONLY `value`, so it is not a drop-in for this. Which of
% the two is right depends on the body, and this one is safe for either.
v = '';
if ~isfield(b, 'depends_on'); return; end
for k = 1:numel(b.depends_on)
    if ~strcmp(b.depends_on(k).name, name); continue; end
    if isfield(b.depends_on(k), 'document_id') && ~isempty(b.depends_on(k).document_id)
        v = b.depends_on(k).document_id;
    elseif isfield(b.depends_on(k), 'value')
        v = b.depends_on(k).value;
    end
    return;
end
end

function testCalculationWithNoOperatingSystemFoldsWithoutTheEdge(testCase)
% INVERTED 2026-10-21 (was testCalculationWithNoOperatingSystemPassesThrough).
% did-schema #88's `calculation.operating_system_id` is OPTIONAL (Jess Haley,
% 2026-10-21 [calculation-os-optional]). A v1 calculator document with no
% `app.os` now FOLDS to its named calculation, id preserved, with the edge
% omitted -- an operating system is never invented.
body = struct();
body.document_class = struct('class_name', 'contrast_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'ct_1', 'session_id', 'sess_09', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.contrast_tuning = struct( ...
    'tuning_curve', struct('contrast', [0 0.25 0.5 1], 'mean', [2 5 9 12]));
out = did2.convert.migrators_j.contrast_tuning(body);
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
assertTrue(testCase, any(strcmp(names, 'contrast_tuning_calculation')), strjoin(names, ', '));
leaf = out{find(strcmp(names, 'contrast_tuning_calculation'), 1)};
verifyEqual(testCase, leaf.base.id, 'ct_1', 'id preserved');
verifyEmpty(testCase, depValue(leaf, 'operating_system_id'));
verifyNotEmpty(testCase, depValue(leaf, 'software_id'), ...
    'the calculator is still named, from its method name');
end


function a = calcAppJ(name)
% The v1 `app` block ndi.app.newdocument stamps on every app/calculator
% document; values from a real Soph temporal_frequency_tuning_calc document.
a = struct('name', name, 'version', '3c482d1', ...
    'url', 'https://github.com/VH-Lab/NDIcalc-vis-matlab', 'os', 'MACA64', ...
    'os_version', '15.4.1', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
end


function leaf = calcLeafJ(testCase, out, leafClass, id, entityId)
% The #88 calculation contract every calculator fold shares: the named leaf class,
% id preserved, the entity edge, a time reference that is one of the emitted
% documents, and the required software + operating-system edges.
names = cellfun(@(b) did2.unittest.helpers.classKey(b), out, 'UniformOutput', false);
at = find(strcmp(names, leafClass), 1);
assertNotEmpty(testCase, at, sprintf('no %s leaf; got: %s', leafClass, strjoin(names, ', ')));
leaf = out{at};
verifyEqual(testCase, leaf.base.id, id);
verifyEqual(testCase, depValue(leaf, 'entity_id'), entityId);
ids = cellfun(@(b) char(b.base.id), out, 'UniformOutput', false);
tr = depValue(leaf, 'time_reference_id');
verifyNotEmpty(testCase, tr);
verifyTrue(testCase, any(strcmp(ids, tr)), 'the time reference is not among the emitted documents');
verifyTrue(testCase, any(strcmp(ids, depValue(leaf, 'software_id'))));
verifyTrue(testCase, any(strcmp(ids, depValue(leaf, 'operating_system_id'))));
end


function e = entityByNameJ(out, name)
e = [];
for k = 1:numel(out)
    b = out{k};
    if strcmp(b.document_class.class_name, 'entity') && isfield(b.entity, 'name') ...
            && strcmp(char(b.entity.name), name)
        e = b; return;
    end
end
error('no entity named %s', name);
end


function e = paramEntryJ(leaf, varName)
e = [];
p = leaf.interaction.method;
if ~isfield(p, 'parameters'); return; end
p = p.parameters;
for k = 1:numel(p)
    if isstruct(p(k).variable) && strcmpi(char(p(k).variable.name), varName)
        e = p(k); return;
    end
end
end


function t = paramTextJ(leaf, varName)
e = paramEntryJ(leaf, varName);
t = '';
if ~isempty(e); t = char(e.text); end
end


function v = paramValueJ(leaf, varName)
e = paramEntryJ(leaf, varName);
v = [];
if ~isempty(e); v = e.quantity.value; end
end


function n = nParamsJ(leaf)
n = 0;
m = leaf.interaction.method;
if ~isfield(m, 'parameters') || ~isstruct(m.parameters); return; end
for k = 1:numel(m.parameters)
    v = m.parameters(k).variable;
    if isstruct(v) && isfield(v, 'name') && ~isempty(v.name); n = n + 1; end
end
end


function n = nCoeffJ(fit)
n = 0;
if ~isfield(fit, 'coefficients') || ~isstruct(fit.coefficients); return; end
c = fit.coefficients;
for k = 1:numel(c)
    if isfield(c(k), 'variable') && isstruct(c(k).variable) && isfield(c(k).variable, 'name') ...
            && ~isempty(c(k).variable.name) && ~isempty(c(k).value)
        n = n + 1;
    end
end
end

function n = nLeafJ(migrated, leaf)
% #88: summary.by_class counts raw class names (`observation`, `entity`); a test
% asking for a leaf (`term_observation`, `organism`) counts it here.
n = 0;
for k = 1:numel(migrated)
    if strcmp(did2.unittest.helpers.classKey(migrated{k}), leaf)
        n = n + 1;
    end
end
end


function [f, c] = doseChainJ(migrated, dose)
% #88 dose chain: the dose names its formulation (formulation_id); the
% formulation names its ingredient chemical (ingredient_id).
f = []; c = [];
fId = depVal(dose, 'formulation_id');
for k = 1:numel(migrated)
    if strcmp(migrated{k}.get('base.id'), fId); f = migrated{k}; end
end
if isempty(f); error('the formulation the dose names is not in the batch'); end
cId = depVal(f, 'ingredient_id');
for k = 1:numel(migrated)
    if strcmp(migrated{k}.get('base.id'), cId); c = migrated{k}; end
end
if isempty(c); error('the chemical the formulation names is not in the batch'); end
end

function a = assertionAboutJ(migrated, entityId, varName)
% #88: the first assertion about entityId whose variable is named varName.
a = [];
for k = 1:numel(migrated)
    d = migrated{k};
    if strcmp(d.get('document_class.class_name'), 'assertion') ...
            && strcmp(depVal(d, 'entity_id'), entityId)
        v = d.get('statement.variable');
        if isstruct(v) && strcmpi(char(v.name), varName)
            a = d; return;
        end
    end
end
end


function n = termNodeJ(t)
% A term's node; '' when the term carries none (the builder leaves an empty
% node out).
n = '';
if isstruct(t) && isfield(t, 'node') && ~isempty(t.node); n = char(t.node); end
end


function t = textAboutJ(migrated, entityId, varName)
% #88: the text value(s) of the text_assertion about entityId named varName,
% as a cell row ({} when there is none).
t = {};
a = assertionAboutJ(migrated, entityId, varName);
if isempty(a); return; end
v = a.get('text.value');
if iscell(v); v = [v{:}]; end
t = arrayfun(@(e) char(e.text), v, 'UniformOutput', false);
t = reshape(t, 1, []);
end


function g = globalIdsJ(e)
% #88: an entity's global identifiers as a cell row ({} when none).
g = {};
s = e.get('entity');
if isfield(s, 'global_identifier') && ~isempty(s.global_identifier)
    g = reshape(cellstr(s.global_identifier), 1, []);
end
end

function out = foldPlaceable(testCase, migrator, body)
%FOLDPLACEABLE [generic stage is lossless] / [partly placed is carried as v1]
%   (Jess Haley, 2026-10-25): a writer-shaped calculator fixture that states a
%   field the fold has no home for is CARRIED WHOLE as v1 (returned unchanged,
%   one `carried_as_v1` note naming the fields). Asserted here. Then exactly
%   those fields are removed and the rest is folded, so a fold test still
%   asserts the fold of everything that IS placed.
did2.convert.reportNote('reset');
first = migrator(body);
notes = did2.convert.reportNote('collect');
did2.convert.reportNote('reset');
assertTrue(testCase, isscalar(first) && isequaln(first{1}, body), ...
    'the writer-shaped document was not carried whole as v1');
assertTrue(testCase, isfield(notes, 'carried_as_v1'), 'the carry was not noted');
d = notes.carried_as_v1.distinct_details{1};
% each path follows its carry register row tag ('[carry-056] ', [carry register]),
% or the '[carry-100] malformed: ...' head of a field outside the NDI template
% ([tuning stray fields are malformed]): did2.unittest.helpers.carryPaths
paths = did2.unittest.helpers.carryPaths(d);
for k = 1:numel(paths)
    body = removePathJ(body, strsplit(paths{k}, '.'));
end
out = migrator(body);
verifyGreaterThan(testCase, numel(out), 1, ...
    sprintf('with %s removed the document still did not fold', d));
end

function s = removePathJ(s, parts)
%REMOVEPATHJ Remove the field PARTS (a path) from struct S, matching each part
%   case-insensitively (the fold lower-cases fit field names).
if ~isstruct(s) || ~isscalar(s) || isempty(parts); return; end
fn = fieldnames(s);
ix = find(strcmpi(fn, parts{1}), 1);
if isempty(ix); return; end
if isscalar(parts)
    s = rmfield(s, fn{ix});
else
    s.(fn{ix}) = removePathJ(s.(fn{ix}), parts(2:end));
end
end

function n = regNode(node)
%REGNODE NODE as the loaded term registry spells it when it holds it ([migrator
%   writes the registry spelling], Jess Haley, 2026-10-26), else as given.
t = did2.convert.registeredTerm(node, '');
n = node;
if ~isempty(t.name); n = t.node; end
end

function n = regName(name)
%REGNAME NAME as the loaded term registry labels it when it holds it, else as
%   given ([term labels stay as the ontology spells them]).
t = did2.convert.registeredTerm('', name);
n = t.name;
end
