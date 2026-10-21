function tests = testMigratorsJ
%TESTMIGRATORSJ Brainstorm-J split/fold migrator tests (TargetVersion 'V_eta').
%
%   Exercises the did_v1 -> V_eta migrators routed by did2.convert.v1_to_v2
%   when TargetVersion == 'V_eta'. Covers:
%     - subject_group      -> bare `subject` (v3.0.0; no is_group/is_biological)
%     - treatment_transfer -> term_manipulation + provenance directed_relation
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

function tf = schemaSaysAbstract(classSchema)
%SCHEMASAYSABSTRACT True when a schema struct's header carries `abstract: true`.
%
%   A LOCAL COPY, ON PURPOSE. did2.schema.cache has this exact predicate --
%   `classIsAbstract` -- and it is PRIVATE (+did2/+schema/cache.m:1434,
%   `methods (Access = private)`), so a test calling it errors with
%   MATLAB:class:MethodRestricted rather than failing a verification. The header
%   is public data on the struct `getClass` hands back, so read that.
%
%   ABSENCE IS CONCRETE, and that is the whole subtlety: build_v_eta.py emits
%   the key only on abstract classes, so a concrete one has no `abstract` field
%   at all -- `image_stack` does not carry it. Both the logical and numeric
%   spellings are accepted for the same reason the private method accepts both:
%   jsondecode's output shape for a JSON `true` is not something a test should
%   assume.
tf = false;
if ~isstruct(classSchema) || ~isfield(classSchema, 'document_class')
    return;
end
dc = classSchema.document_class;
if ~isstruct(dc) || ~isfield(dc, 'abstract')
    return;
end
v = dc.abstract;
tf = (islogical(v) && any(v)) || (isnumeric(v) && any(v == 1));
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
verifyEqual(testCase, did2.unittest.helpers.leafName(doc), 'group');
verifyEqual(testCase, doc.get('document_class.schema_version'), 'V_eta');
verifyEqual(testCase, doc.get('entity.local_identifier'), 'cohortA');
% bare identity: is_group / is_biological must NOT be present in V_eta
sub = doc.get('entity');
verifyFalse(testCase, isfield(sub, 'is_group'));
verifyFalse(testCase, isfield(sub, 'is_biological'));
end

function testSubjectGroupEmptyNameFallsBackToId(testCase)
% local_identifier is REQUIRED on a V_eta subject; a subject_group with no
% group_name must still be nameable -- it falls back to the document id.
v1 = struct();
v1.document_class = struct('class_name', 'subject_group', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'grp_noname', 'session_id', 'aa_99', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject_group = struct('group_name', '', 'description', '');
out = runJ(v1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('entity.local_identifier'), 'grp_noname');
end

function testSubjectCarryForwardFillsLocalId(testCase)
% A plain v1 subject with an empty/missing local_identifier is filled from the
% document id (the required-handle carry-forward path).
v1 = struct();
v1.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'document_id', {});
v1.base = struct('id', 'sub_bare', 'session_id', 'sess_09', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.subject = struct('local_identifier', '', 'description', '');
out = runJ(v1);
doc = out.migrated{1};
% did-schema #88: a subject is an `entity` of type organism
verifyEqual(testCase, did2.unittest.helpers.leafName(doc), 'organism');
verifyEqual(testCase, doc.get('entity.local_identifier'), 'sub_bare');
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
        verifyEqual(testCase, d.get('directed_relation.relation').name, 'member_of');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(a), 'term_assertion');
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
out = runJ(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1'));
sub = firstOfClassJ(out.migrated, 'cell');   % #88: a spikes element is an entity of type cell
verifyEqual(testCase, sub.get('base.id'), 'el_1');                 % id preserved
verifyEqual(testCase, sub.get('entity.local_identifier'), 'unit3 (ref 1)');
% type + ndi_element_class preserved as term_assertions (no silent drop)
verifyEqual(testCase, nLeafJ(out.migrated, 'term_assertion'), 2);
% lineage: derived_from the underlying element (safe computational lineage)
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'derived_from');
verifyEqual(testCase, depVal(rel, 'child_id'), 'el_1');
verifyEqual(testCase, depVal(rel, 'parent_id'), 'probe_1');
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
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'observes');
verifyEqual(testCase, depVal(rel, 'child_id'), 'el_1');
verifyEqual(testCase, depVal(rel, 'parent_id'), 'subj_007');

verifyEmpty(testCase, firstOfClassJ(out.migrated, 'voltage_observation'), ...
    'pass 1 emitted a recording observation; it is per epoch, minted by the batch pass');

% The element itself is still promoted to a subject with its id PRESERVED --
% ~50 documents reference `element_id`, and moving it is the 11,448-orphan
% shape.
subj = firstOfClassJ(out.migrated, 'device');   % #88: an entity of type device
verifyNotEmpty(testCase, subj, 'the element must still become a subject');
verifyEqual(testCase, subj.get('base.id'), 'el_1');
end

% ============ treatment_transfer -> term_manipulation + relation =======

function testTreatmentTransferBecomesTermManipulationPlusProvenance(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = [ ...
    struct('name', 'recipient_id', 'document_id', 'rec_001'), ...
    struct('name', 'donor_id',     'document_id', 'don_002')];
v1.base = struct('id', 'tt_01', 'session_id', 'sess_09', ...
    'name', 'graft', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_transfer = struct( ...
    'entity_ontologyNode', 'uberon:0000922', 'entity_name', 'embryonic tissue', ...
    'method_name', 'transplantation');
out = runJ(v1);

% 1 -> 3: the act, the provenance relation, the anchor.
verifyEqual(testCase, numel(out.migrated), 3);
verifyEqual(testCase, nLeafJ(out.migrated, 'term_manipulation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'directed_relation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 1);

act = out.migrated{1};
% recipient is the patient; the material term is the value AND the variable
verifyEqual(testCase, depVal(act, 'entity_id'), 'rec_001');
verifyEqual(testCase, act.get('statement.variable').name, 'embryonic tissue');
verifyEqual(testCase, act.get('term.value').name, 'embryonic tissue');
verifyEqual(testCase, act.get('interaction.method').term.name, 'transplantation');

rel = out.migrated{2};
verifyEqual(testCase, depVal(rel, 'child_id'), 'rec_001');
verifyEqual(testCase, depVal(rel, 'parent_id'), 'don_002');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'derived_from');

anchor = out.migrated{3};
verifyEqual(testCase, anchor.get('relative_time_reference.value').relation.name, 'intervalDuring');
end

% ============ ontology_table_row -> assertions/observations (1 -> N) ====

function otr = tableRow()
otr = struct();
otr.document_class = struct('class_name', 'ontology_table_row', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
otr.depends_on = struct('name', {'subject_id'}, 'value', {'subj_001'});
otr.base = struct('id', 'otr_01', 'session_id', 'sess_09', ...
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct( ...
    'variable_names', 'BodyWeight,StartleAmplitude,TrialType,SubjectLocalIdentifier', ...
    'names', 'body weight,acoustic startle maximum amplitude,trial type,subject local identifier', ...
    'ontology_nodes', 'EMPTY:1,EMPTY:2,EMPTY:3,EMPTY:4', ...
    'data', struct('BodyWeight', 24.3, 'StartleAmplitude', 38, ...
        'TrialType', 'Startle 95 dB', 'SubjectLocalIdentifier', 'rat_1'));
end

function testOntologyTableRowSplitsByShape(testCase)
out = runJ(tableRow());
% 3 kept columns (identity skipped) + 1 shared anchor
verifyEqual(testCase, numel(out.migrated), 4);
verifyEqual(testCase, nLeafJ(out.migrated, 'mass_observation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'intensity_observation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'term_observation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 1);
% identity column is skipped, not an observation
verifyFalse(testCase, isfield(out.summary.by_class, 'local_identifier'));
end

function testOntologyTableRowPreservesSourceIdOnFirstBody(testCase)
% The row dissolves 1 -> N. Exactly ONE emitted body must keep the source id,
% otherwise anything pointing at the row (an ontologyImage names it via
% ontologyTableRow_id and follows it to reach its subject) is left pointing at
% an id that no longer exists. There is no old-id -> new-id map in the
% converter, so preservation is the only thing that can make such an edge
% resolve. Same lesson as the calculator fold (T10).
out = runJ(tableRow());
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_01')), 1, ...
    'exactly one emitted body must carry the source id');
verifyEqual(testCase, out.migrated{1}.get('base.id'), 'otr_01', ...
    'the first emitted body is the one that carries it');
% and the siblings must NOT collide with it or each other
verifyEqual(testCase, numel(unique(ids)), numel(ids), 'emitted ids must be unique');
end

function testEncounterMapPreservesSourceId(testCase)
% Same requirement on the per-table map path, which previously minted a fresh
% id for every body it emitted.
out = runJ(encounterRow());
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_enc')), 1);
verifyEqual(testCase, numel(unique(ids)), numel(ids));
end

function testPatchGeometryMapDoesNotDoubleStampSourceId(testCase)
% makePatchSubject ALREADY preserves the id deliberately (the encounter
% relation names that document as its parent). Stamping again would mint two
% documents sharing one id, so the preservation step must detect it and leave
% it alone.
out = runJ(patchGeometryRow());
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_patch')), 1, ...
    'the id must be carried exactly once, not stamped twice');
verifyEqual(testCase, numel(unique(ids)), numel(ids));
end

function testOntologyTableRowNumericColumn(testCase)
out = runJ(tableRow());
mass = out.migrated{1};   % BodyWeight -> mass_observation
verifyEqual(testCase, did2.unittest.helpers.leafName(mass), 'mass_observation');
% identity is on the statement variable, value on the mass block
verifyEqual(testCase, mass.get('statement.variable').name, 'body weight');
verifyEqual(testCase, mass.get('mass.value').source_value, 24.3);
% the spine: subject_id carried, shared time anchor wired on
verifyEqual(testCase, depVal(mass, 'entity_id'), 'subj_001');
verifyEqual(testCase, depVal(mass, 'time_reference_id'), out.migrated{4}.get('base.id'));
end

function testOntologyTableRowStringColumnIsTermObservation(testCase)
out = runJ(tableRow());
term = out.migrated{3};   % TrialType -> term_observation (string value)
verifyEqual(testCase, did2.unittest.helpers.leafName(term), 'term_observation');
verifyEqual(testCase, term.get('term.value').name, 'Startle 95 dB');
end

function testOntologyTableRowAmplitudeIsIntensity(testCase)
out = runJ(tableRow());
amp = out.migrated{2};   % a.u. amplitude -> intensity_observation (J §7)
verifyEqual(testCase, did2.unittest.helpers.leafName(amp), 'intensity_observation');
verifyEqual(testCase, amp.get('intensity.value').source_value, 38);
end

% ===================== treatment -> manipulation leaves ================

function v1 = treatmentDoc(node, name, numeric, stringValue)
v1 = struct();
v1.document_class = struct('class_name', 'treatment', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'tr_01', 'session_id', 'sess_09', ...
    'name', 'trt', 'datestamp', '2024-06-01T12:00:00.000Z');
t = struct('ontology_name', node, 'name', name);
if ~isempty(numeric); t.numeric_value = numeric; end
if nargin >= 4 && ~isempty(stringValue); t.string_value = stringValue; end
v1.treatment = t;
end

function testTreatmentTemperatureIsTemperatureManipulation(testCase)
out = runJ(treatmentDoc('', 'cold exposure', 4.0, ''));
verifyEqual(testCase, numel(out.migrated), 2);   % manip + anchor
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(m), 'temperature_manipulation');
verifyEqual(testCase, m.get('temperature.value').source_value, 4.0);
verifyEqual(testCase, m.get('statement.variable').name, 'cold exposure');
verifyEqual(testCase, depVal(m, 'entity_id'), 'subj_007');
% shared session anchor wired on as the time_reference
verifyEqual(testCase, depVal(m, 'time_reference_id'), out.migrated{2}.get('base.id'));
end

function testTreatmentSubstanceIsDoseManipulation(testCase)
out = runJ(treatmentDoc('chebi:28001', 'haloperidol', 2.5, ''));
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(m), 'dose_manipulation');
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
verifyEqual(testCase, m.get('statement.variable').node, 'chebi:28001');
% A generic treatment with no location: "stays a dose with NaN and is listed
% in the migration report as route unknown" (Jess Haley, 2026-10-21). The
% unitless numeric_value is no amount of the dose; it stays on the ingredient.
verifyTrue(testCase, isnan(m.get('dose.value').volume.liters), ...
    'an unrecorded amount is NaN in the dose''s volume');
if ~isempty(f)
    verifyEqual(testCase, f.get('formulation.value').ingredients(1).concentration.source_value, 2.5);
end
verifyEqual(testCase, routeUnknownCount(out, 'treatment'), 1);
verifyEqual(testCase, out.summary.migration_notes.route_unknown.ids, {'tr_01'});
end

function testTreatmentProcedureIsTermManipulation(testCase)
out = runJ(treatmentDoc('', 'craniotomy', [], ''));
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(m), 'term_manipulation');
verifyEqual(testCase, m.get('term.value').name, 'craniotomy');
end

function testTreatmentTargetLocationEmitsSiteObservation(testCase)
% Dab "Target Location" idiom: the site rides in string_value; strict J has no
% target_structure, so a located site becomes a term_observation (D3).
out = runJ(treatmentDoc('chebi:28001', 'muscimol Target Location', [], 'uberon:0002436'));
% #88: dose manip + its chemical + formulation + anchor + site obs
verifyEqual(testCase, numel(out.migrated), 5);
verifyEqual(testCase, nLeafJ(out.migrated, 'dose_manipulation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'term_observation'), 1);
% " Target Location" stripped from the manipulation's spine variable
verifyEqual(testCase, out.migrated{1}.get('statement.variable').name, 'muscimol');
site = firstOfClassJ(out.migrated, 'term_observation');
verifyEqual(testCase, did2.unittest.helpers.leafName(site), 'term_observation');
verifyEqual(testCase, site.get('term.value').node, 'uberon:0002436');
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
    'name', 'td', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_drug = struct('mixture_table', 'chebi:28001,haloperidol,5', ...
    'location_ontologyNode', 'uberon:0002436', 'location_name', 'primary visual cortex');
out = runJ(v1);
% #88: dose + chemical + formulation + site obs + anchor
verifyEqual(testCase, numel(out.migrated), 5);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(d), 'dose_manipulation');
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
site = firstOfClassJ(out.migrated, 'term_observation');
verifyEqual(testCase, did2.unittest.helpers.leafName(site), 'term_observation');
verifyEqual(testCase, site.get('term.value').node, 'uberon:0002436');
end

function testVirusInjectionBecomesDoseManipulation(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'vi_01', 'session_id', 'sess_09', ...
    'name', 'vi', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'AAV-ChR2', 'dilution', 1000, ...
    'virusLocation_OntologyName', 'uberon:0002436', 'virusLocation_name', 'V1');
out = runJ(v1);
% #88: dose + chemical + formulation + site obs + anchor
verifyEqual(testCase, numel(out.migrated), 5);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(d), 'dose_manipulation');
[f, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, c.get('chemical.value').substance.name, 'AAV-ChR2');
conc = f.get('formulation.value').ingredients(1).concentration;
verifyEqual(testCase, conc.source_value, 1000);
verifyEqual(testCase, conc.source_unit.name, 'dilution');
verifyEqual(testCase, d.get('statement.variable').node, 'addgene:26973');
% "virus_injection is always a dose (an injection), its volume NaN when
% unrecorded, its dilution staying on the formulation" (Jess Haley, 2026-10-21)
verifyTrue(testCase, isnan(d.get('dose.value').volume.liters));
verifyEqual(testCase, routeUnknownCount(out, 'virus_injection'), 0);
% site node survives snake-casing (virusLocation_OntologyName -> virus_location_ontology_name)
site = firstOfClassJ(out.migrated, 'term_observation');
verifyEqual(testCase, site.get('term.value').node, 'uberon:0002436');
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
verifyEqual(testCase, nLeafJ(out.migrated, 'formulation_manipulation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'dose_manipulation'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'term_observation'), 0);
m = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(m), 'formulation_manipulation');
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

function testTreatmentDrugIntraperitonealTakesTheSourcesAmount(testCase)
% Hunsberger writes alprazolam as a treatment_drug at Intraperitoneal
% (SNOMED:783351009) with a mixture row `0.25 mg/kg` (SNOMED:396163008)
% (+hunsberger/TreatmentCreator.m). A body site -> a dose "with the source's
% amount when it has one": the mg/kg row is the dose's amount per body mass,
% taken off the ingredient entry (it is not a concentration).
v1 = treatmentDrugDoc('td_ip', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'SNOMED:783351009', 'Intraperitoneal');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
% dose + chemical + formulation + site obs + anchor
verifyEqual(testCase, numel(out.migrated), 5);
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(d), 'dose_manipulation');
a = d.get('dose.value').amount_per_body_mass;
verifyEqual(testCase, a.source_value, 0.25);
verifyEqual(testCase, a.grams_per_gram, 0.25e-6, 'AbsTol', 1e-15);
verifyEqual(testCase, a.source_unit.node, 'SNOMED:396163008');
[f, c] = doseChainJ(out.migrated, d);
verifyEqual(testCase, c.get('chemical.value').substance.name, 'alprazolam');
% the per-body-mass amount is the dose's, not the ingredient's concentration:
% the ingredient's own amount is unrecorded, NaN (a blank entry would leave the
% formulation's value empty, which value_inline_or_body refuses)
e = f.get('formulation.value').ingredients(1);
verifyTrue(testCase, isnan(e.concentration.source_value));
site = firstOfClassJ(out.migrated, 'term_observation');
verifyEqual(testCase, site.get('term.value').node, 'SNOMED:783351009');
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 0);
end

function testTreatmentDrugWithNoLocationIsRouteUnknown(testCase)
% No location recorded: the route cannot be read, so a dose with a NaN amount
% and a `route_unknown` note in the migration report; no site observation.
v1 = treatmentDrugDoc('td_none', 'chebi:28001,haloperidol,5', '', '');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 4);   % dose + chemical + formulation + anchor
d = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(d), 'dose_manipulation');
verifyTrue(testCase, isnan(d.get('dose.value').volume.liters));
verifyEqual(testCase, nLeafJ(out.migrated, 'term_observation'), 0);
verifyEqual(testCase, routeUnknownCount(out, 'treatment_drug'), 1);
verifyEqual(testCase, out.summary.migration_notes.route_unknown.ids, {'td_none'});
% the notes are per batch: a second run does not carry the first one's note
out2 = runJ(treatmentDrugDoc('td_v1', 'chebi:28001,haloperidol,5', ...
    'uberon:0002436', 'primary visual cortex'));
verifyEqual(testCase, routeUnknownCount(out2, 'treatment_drug'), 0);
end

function testVirusInjectionAtTheBathIsStillADose(testCase)
% Birren records AAV DREADDs as virus_injection located in the bath
% (+birren/TreatmentCreator.m). "virus_injection is always a dose": the
% location does not make it an immersion.
v1 = struct();
v1.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', 'vi_bath', 'session_id', 'sess_09', ...
    'name', 'vi', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.virus_injection = struct('virus_OntologyName', 'addgene:50474', ...
    'virus_name', 'AAV9-hSyn-hM3D(Gq)-mCherry', 'dilution', 0, ...
    'virusLocation_OntologyName', 'NCIm:C0179246', 'virusLocation_name', 'bath', ...
    'diluent_OntologyName', 'NCIm:C0043047', 'diluent_name', 'Water');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, nLeafJ(out.migrated, 'dose_manipulation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'formulation_manipulation'), 0);
d = out.migrated{1};
verifyTrue(testCase, isnan(d.get('dose.value').volume.liters));
verifyEqual(testCase, routeUnknownCount(out, 'virus_injection'), 0);
end

function v1 = treatmentDrugDoc(id, mixtureTable, locNode, locName)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', id, 'session_id', 'sess_09', ...
    'name', 'td', 'datestamp', '2024-06-01T12:00:00.000Z');
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
    'name', 'pl', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_location = struct('ontology_name', 'uberon:0002436', 'name', 'primary visual cortex');
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 2);   % obs + anchor
o = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(o), 'term_observation');
verifyEqual(testCase, o.get('term.value').node, 'uberon:0002436');
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
    'name', 'ol', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'ontology_label');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(doc), 'ontology_label');
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
% V_delta conversion doc (since corrected). None exists on the real class.
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
v1.depends_on = [ struct('name', 'subject_id', 'value', 'subj_007'), ...
                  struct('name', 'imageCollection_id', 'value', 'coll_1')];
v1.base = struct('id', 'img_01', 'session_id', 'sess_09', ...
    'name', 'img', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', 'a histology section', 'format', 'tiff', ...
    'compression', 'lzw');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXC', 'dimension_size', [1024 1024 3], ...
    'dimension_scale', [0.25 0.25 1], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 3);   % observation + sampled_body + anchor
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(obs), 'intensity_observation');
verifyEqual(testCase, obs.get('base.id'), 'img_01');     % id PRESERVED
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subj_007');
verifyTrue(testCase, logical(obs.get('value.data_body')));
% dtype comes from the parameters block, never guessed from the pixels
verifyEqual(testCase, obs.get('value.data_type'), 'uint8');
names = cellfun(@(d) did2.unittest.helpers.leafName(d), out.migrated, ...
    'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'image')));
end


function testDidV1ImageDoesNotMintADanglingCollectionEdge(testCase)
% imageCollection has NO V_eta class and NO migrator, so carrying
% imageCollection_id would reference a document that does not exist after
% migration -- a GATING orphan, not a cosmetic gap. (Dissolving referenced
% documents without preserving ids once cost 11,448 orphans.) The grouping is
% real and wants the second pass, once imageCollection has a home.
v1 = struct();
v1.document_class = struct('class_name', 'image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'image_stack_parameters'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
v1.depends_on = [ struct('name', 'subject_id', 'value', 'subj_007'), ...
                  struct('name', 'imageCollection_id', 'value', 'coll_1')];
v1.base = struct('id', 'img_02', 'session_id', 'sess_09', ...
    'name', 'img', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', '', 'format', 'tiff', 'compression', '');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXC', 'dimension_size', [8 8 3], ...
    'dimension_scale', [1 1 1], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
% DENOMINATOR FIRST. The loop below is vacuously true over an empty batch, so
% a migrator that emitted NOTHING would have passed this test unchanged -- the
% "all-zero reads as clean" defect in a two-line sweep. Assert the fold ran.
verifyEqual(testCase, numel(out.migrated), 3, ...
    'the 1 -> 3 fold must have run, or the sweep below checked nothing');
for k = 1:numel(out.migrated)
    verifyEqual(testCase, depVal(out.migrated{k}, 'imageCollection_id'), '');
    verifyEqual(testCase, depVal(out.migrated{k}, 'image_collection_id'), '');
end
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
    'name', 'img', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(doc), 'image');
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
    'name', 'img', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image = struct('label', '', 'format', 'tiff', 'compression', 'lzw');
v1.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YX', 'dimension_size', [64 64], ...
    'dimension_scale', [1 1], 'clocktype', 'no_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, out.summary.total, 1);
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out.migrated{1}), 'image');
end


function testTheVEtaImageNameIsAbstractSoAPassthroughIsNotAnOption(testCase)
% INVERTED for did-schema #88, and kept as THE INSTRUMENT for the two tests
% above: their passthrough is legal only because `image` now resolves to a
% CONCRETE did_v1 tombstone (deprecated/, #73 item 51). If `image` ever becomes
% abstract again, or the tombstone leaves the validation set, this goes red and
% the passthrough has to be re-examined. `image_stack` is checked beside it so
% "concrete" is not read off a reader that answers false for everything.
cache = did2.schema.cache.shared();
try
    imgSchema   = cache.getClass('image');
    stackSchema = cache.getClass('image_stack');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve the V_eta image classes (' ...
         err.message ') -- this test measured nothing.']);
    return;
end
verifyFalse(testCase, schemaSaysAbstract(imgSchema), ...
    'V_eta `image` must be the CONCRETE did_v1 tombstone the passthrough validates against');
verifyEqual(testCase, imgSchema.document_class.maturity_level, 'deprecated');
verifyFalse(testCase, schemaSaysAbstract(stackSchema));
end


function testImageStackWithNoSubjectPassesThroughInsteadOfObservingNobody(testCase)
% THE 4,563. NDI's own writer leaves subject_id empty on three of its seven
% imageStack sites (+setup/+conv/+haley/doImport.m:789,811,827 -- the image /
% mask / closest-patch loop set only document_id), so this fixture carries
% `document_id` and NO subject, which is what a real JH document of that kind
% looks like. Before the guard this emitted an image_observation with an empty
% required subject_id: an observation about nobody, invisible to every gate
% because references.m skips empty edges.
%
% Note the fixture also pins WHY the passthrough is safe: image_stack came back
% out of _DELETE_PHASE8 so the document has a schema to validate against.
v1 = struct();
v1.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'document_id'}, 'value', {'otr_42'});
v1.base = struct('id', 'is_02', 'session_id', 'sess_09', ...
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C70631', 'label', 'an image');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YX', 'dimension_size', [512 512], ...
    'dimension_scale', [0.5 0.5], 'clocktype', 'exp_global_time', 'timestamp', 0);

out = runJ(v1);

verifyEqual(testCase, numel(out.migrated), 1, ...
    'a subject-less image_stack must pass through as exactly one document');
verifyEqual(testCase, nLeafJ(out.migrated, 'intensity_observation'), 0, ...
    'must NOT emit an observation with no subject');
% NOTE THE ACCESSOR. v1_to_v2 returns did2.document OBJECTS, read with
% .get('dotted.path') -- NOT structs. The first draft of these two tests used
% struct field access, carried over from the fitcurve tests, which call the
% migrator DIRECTLY and so really do get structs back. Two green CI jobs went
% red on that alone.
doc = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(doc), 'image_stack');
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
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C70631', 'label', 'an image');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YX', 'dimension_size', [512 512], ...
    'dimension_scale', [0.5 0.5], 'clocktype', 'exp_global_time', 'timestamp', 0);

out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out.migrated{1}), 'image_stack');
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
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'edam:3382', ...
    'label', 'a two-photon stack', 'format', 'tiff');
v1.image_stack_parameters = struct('data_type', 'uint16', ...
    'dimension_order', 'YXCZT', 'dimension_size', [512 512 1 1 10], ...
    'dimension_scale', [0.5 0.5 1 1 1], 'clocktype', 'dev_local_time', 'timestamp', 0);
out = runJ(v1);
verifyEqual(testCase, numel(out.migrated), 3);
verifyEqual(testCase, nLeafJ(out.migrated, 'intensity_observation'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'sampled_body'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 1);
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(obs), 'intensity_observation');
verifyEqual(testCase, obs.get('statement.variable').name, 'image intensity');
verifyEqual(testCase, obs.get('statement.notes'), 'a two-photon stack');
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subj_007');
verifyEqual(testCase, obs.get('value.data_type'), 'uint16');
verifyTrue(testCase, logical(obs.get('value.data_body')));
sb = out.migrated{2};
verifyEqual(testCase, did2.unittest.helpers.leafName(sb), 'sampled_body');
verifyEqual(testCase, depVal(sb, 'owner_id'), obs.get('base.id'));
verifyEqual(testCase, sb.get('data.datum_order'), 'F');
keys = sb.get('data.keys');
verifyEqual(testCase, numel(keys), 5);               % YXCZT
verifyEqual(testCase, keys(1).variable.name, 'y');
verifyEqual(testCase, keys(1).n, 512);
verifyTrue(testCase, logical(keys(1).regular));
verifyEqual(testCase, keys(1).spacing.value, 0.5);
verifyEqual(testCase, keys(1).origin.value, 0);
% C/Z/T carry a recorded scale of 1, so they are calibrated, not index axes
verifyEqual(testCase, keys(3).spacing.value, 1);
verifyEqual(testCase, keys(3).origin.value, 0);
verifyEqual(testCase, keys(5).variable.name, 't');
verifyEqual(testCase, keys(5).n, 10);
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
out = runJ(behaviourImageStack());
sb = firstOfClassJ(out.migrated, 'sampled_body');
keys = sb.get('data.keys');
verifyEqual(testCase, numel(keys), 3, 'dimension_order YXT is three keys');
verifyEqual(testCase, keys(1).variable.name, 'y');
verifyEqual(testCase, keys(3).variable.name, 't');
verifyEqual(testCase, keys(1).source_unit.name, 'micrometre');
verifyEqual(testCase, keys(2).source_unit.name, 'micrometre');
verifyEqual(testCase, keys(3).source_unit.name, 'second');
verifyEqual(testCase, keys(1).spacing.value, 1.5);
verifyEqual(testCase, keys(3).spacing.value, 0.2);
end


function testImageStackAxisWithNoRecordedScaleIsAnIndexAxis(testCase)
% A dimension with no recorded scale is an index key: regular, origin 1,
% spacing 1, no unit. UPDATED for #88: read off the sampled_body's data.keys.
v1 = behaviourImageStack();
v1.image_stack_parameters.dimension_scale = [];        % nothing recorded
v1.image_stack_parameters.dimension_scale_units = '';
out = runJ(v1);
keys = firstOfClassJ(out.migrated, 'sampled_body').get('data.keys');
verifyEqual(testCase, numel(keys), 3);
for k = 1:3
    verifyTrue(testCase, logical(keys(k).regular));
    verifyEqual(testCase, keys(k).spacing.value, 1);
    verifyEqual(testCase, keys(k).origin.value, 1, 'an index axis starts at 1, not at 0');
    verifyTrue(testCase, ~isfield(keys(k), 'source_unit') || isempty(keys(k).source_unit) ...
        || (isstruct(keys(k).source_unit) && isempty(keys(k).source_unit.name)), ...
        'an index axis carries no unit');
end
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
    'name', 'stack', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.image_stack = struct('format_ontology', 'NCIT:C190180', ...
    'label', 'A video recording capturing the behavior of C. elegans');
v1.image_stack_parameters = struct('data_type', 'uint8', ...
    'dimension_order', 'YXT', 'dimension_size', [1024 1024 30], ...
    'dimension_scale', [1.5 1.5 0.2], ...
    'dimension_scale_units', 'micrometer,micrometer,second', ...
    'clocktype', 'exp_global_time', 'timestamp', 739000);
v1.files = struct('file_list', {{'imageStack'}});
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
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function testImageStackFoldCarriesDocumentIdIntoTheOntologyTableRowSlot(testCase)
% INVERTED for did-schema #88, which removed image_observation's
% `ontology_table_row_id` slot (#73 item 42) and gives an observation no edge
% for the ontologyTableRow an image belongs to. The fold therefore does NOT
% carry the v1 `document_id`; resolving the image to its plate row is an NDI
% second-pass need (listed in the port report). The whole edge set is still
% asserted, so a dropped, invented or renamed edge fails here.
out = runJ(behaviourImageStack());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3, ...
    'the fold arm is 1 -> intensity_observation + sampled_body + anchor');
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(obs), 'intensity_observation');
verifyEqual(testCase, sort(did2.unittest.helpers.dropSessionEdge(depNamesOf(obs))), ...
    {'entity_id', 'time_reference_id'});
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subjgrp_7');
for k = 1:numel(out.migrated)
    verifyFalse(testCase, any(strcmp(depNamesOf(out.migrated{k}), 'document_id')), ...
        'the did_v1 edge name must not survive onto a V_eta document');
end
verifyEqual(testCase, obs.get('base.id'), 'is_beh_01');
verifyEqual(testCase, did2.unittest.helpers.leafName(out.migrated{2}), 'sampled_body');
sbStruct = out.migrated{2}.toStruct();
verifyTrue(testCase, isfield(sbStruct, 'files'), 'the carried bytes must land on the sampled_body');
verifyEqual(testCase, sbStruct.files.file_list{1}, 'imageStack', ...
    'and under NDI''s own spelling -- universalRenames skips file keys');
obsStruct = obs.toStruct();
verifyFalse(testCase, isfield(obsStruct, 'files'), ...
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
verifyEqual(testCase, numel(out.migrated), 5);   % image 1->3, row 1->1, group 1->1
ids = cellfun(@(d) d.get('base.id'), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(ids, 'otr_plate_1')), 1);
classes = cellfun(@(d) did2.unittest.helpers.leafName(d), out.migrated, ...
    'UniformOutput', false);
verifyTrue(testCase, any(strcmp(classes, 'ontology_table_row')));
rep = did2.validate.references(out.migrated, ...
    'KnownIds', did2.unittest.helpers.sessionKnownIds(out.migrated));
verifyGreaterThan(testCase, rep.edges_examined, 0);
verifyEqual(testCase, rep.orphan_count, 0);

outNoRow = runJ({behaviourImageStack(), group});
repMissing = did2.validate.references(outNoRow.migrated, ...
    'KnownIds', did2.unittest.helpers.sessionKnownIds(outNoRow.migrated));
verifyGreaterThan(testCase, repMissing.edges_examined, 0);
verifyEqual(testCase, repMissing.orphan_count, 0, ...
    'no emitted edge names the plate row on #88, so its absence orphans nothing');
end


function testImageStackBabuShapeOmitsTheSlotRatherThanEmittingItBlank(testCase)
% A babu imageStack (subject, no document_id) folds like any other. UPDATED for
% #88: leaf intensity_observation; edges exactly entity_id + time_reference_id.
out = runJ(babuImageStack());
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 3);
obs = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(obs), 'intensity_observation');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(obs), 'intensity_observation');
verifyEqual(testCase, depVal(obs, 'entity_id'), 'subjgrp_babu_3');
verifyEqual(testCase, sort(did2.unittest.helpers.dropSessionEdge(depNamesOf(obs))), ...
    {'entity_id', 'time_reference_id'});
end

% ============ ontology_table_row per-table map: C. elegans encounter ====

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
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function d = firstOfClassJ(migrated, className)
d = [];
for k = 1:numel(migrated)
    % #88: a class name OR a leaf name (`term_observation`, `organism`, ...)
    if strcmp(migrated{k}.get('document_class.class_name'), className) ...
            || strcmp(did2.unittest.helpers.leafName(migrated{k}), className)
        d = migrated{k}; return;
    end
end
end

function testEncounterTableMap(testCase)
out = runJ(encounterRow());
% 8 worm observations + 1 relation + 1 shared time_reference
verifyEqual(testCase, numel(out.migrated), 10);
m = out.migrated;   % #88: by_class counts raw classes; count leaves
verifyEqual(testCase, nLeafJ(m, 'velocity_observation'), 3);
verifyEqual(testCase, nLeafJ(m, 'acceleration_observation'), 1);
verifyEqual(testCase, nLeafJ(m, 'score_observation'), 2);
verifyEqual(testCase, nLeafJ(m, 'concentration_observation'), 2);
verifyEqual(testCase, nLeafJ(m, 'directed_relation'), 1);
verifyEqual(testCase, nLeafJ(m, 'relative_time_reference'), 1);   % #88: the bounded session reference
% onset/offset are the window (not observations); encounter # is derived (dropped)
verifyEqual(testCase, nLeafJ(m, 'time_observation'), 0);
verifyEqual(testCase, nLeafJ(m, 'count_observation'), 0);
% a measurement is about the worm and shares the encounter window
tref = firstOfClassJ(out.migrated, 'relative_time_reference');
vel = firstOfClassJ(out.migrated, 'velocity_observation');
verifyEqual(testCase, depVal(vel, 'entity_id'), 'worm_1');
verifyEqual(testCase, depVal(vel, 'time_reference_id'), tref.get('base.id'));
% the relation is the encounter record: worm --encountered--> patch, same window
rel = firstOfClassJ(out.migrated, 'directed_relation');
verifyEqual(testCase, depVal(rel, 'child_id'), 'worm_1');
verifyEqual(testCase, depVal(rel, 'parent_id'), 'patch_1');
verifyEqual(testCase, rel.get('directed_relation.relation').name, 'encountered');
verifyEqual(testCase, depVal(rel, 'time_reference_id'), tref.get('base.id'));
% the window carries onset/offset
verifyEqual(testCase, tref.get('relative_time_reference.value').start.seconds, 1249.72);
end

% ==== ontology_table_row per-table map: C. elegans bacterial patch ======

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
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
otr.ontology_table_row = struct('variable_names', strjoin(keys, ','), ...
    'names', strjoin(keys, ','), 'ontology_nodes', nodes, 'data', data);
end

function testPatchGeometryTableMap(testCase)
out = runJ(patchGeometryRow());
% 1 subject + 6 geometry observations + the BacterialPlateIdentifier column
% (no longer dropped -- see testPatchGeometryCarriesUnenumeratedColumns)
% + 1 shared session anchor
verifyEqual(testCase, numel(out.migrated), 9);
m = out.migrated;   % #88: the patch is an entity of type culture; leaves counted
% the patch is declared as a bare subject
verifyEqual(testCase, nLeafJ(m, 'culture'), 1);
% geometry -> observations (OD600, volume, radius + centre X/Y, circularity)
verifyEqual(testCase, nLeafJ(m, 'concentration_observation'), 1);
verifyEqual(testCase, nLeafJ(m, 'volume_observation'), 1);
verifyEqual(testCase, nLeafJ(m, 'length_observation'), 3);   % radius + centre X + centre Y
verifyEqual(testCase, nLeafJ(m, 'score_observation'), 1);
verifyEqual(testCase, nLeafJ(m, 'relative_time_reference'), 1);
% the patch's OWN identifier is its identity, not a measurement
verifyEqual(testCase, nLeafJ(m, 'count_observation'), 0);
% the minted subject PRESERVES the source document id (the encounter table's
% directed_relation parent points at it) and names the patch
sub = firstOfClassJ(out.migrated, 'culture');
verifyEqual(testCase, sub.get('base.id'), 'otr_patch');
% THIS ASSERTION WAS INVERTED 2026-08-11, not updated. It read '0017' -- the
% bare `patchID` -- which is precisely what the team directive of that day
% forbids ("None should be labeled just patch #"). A test written from the same
% premise as the code cannot catch the code, and this one had been pinning the
% collision rather than the fix: `patchID` is 1:numPatch WITHIN a plate
% (doImport.m:275), so '0001' recurs on every plate in one session.
verifyEqual(testCase, sub.get('entity.local_identifier'), ...
    'plate/0061/patch/0017', ...
    ['the patch handle must carry its plate; the experiment number is not a ' ...
     'column of this table and is added by did2.convert.resolveLawnPlateSubjects']);
% every geometry observation is about that patch and shares the anchor
anchor = firstOfClassJ(out.migrated, 'relative_time_reference');
od = firstOfClassJ(out.migrated, 'concentration_observation');
verifyEqual(testCase, depVal(od, 'entity_id'), 'otr_patch');
verifyEqual(testCase, depVal(od, 'time_reference_id'), anchor.get('base.id'));
end

function testAPatchSubjectIsNeverLabelledJustThePatchNumber(testCase)
%TESTAPATCHSUBJECTISNEVERLABELLEDJUSTTHEPATCHNUMBER The team directive of
%   2026-08-11, verbatim: *"each experiment #, plate #, and patch # combo should
%   be unique and should dictate the local identifier for all patches. None
%   should be labeled just patch #"*.
%
%   SEPARATE FROM THE MAP TEST ABOVE ON PURPOSE. That one pins the exact handle
%   this table produces today; this one pins the PROHIBITION, so it stays red
%   for any future handle that regresses to a bare number -- including through
%   the `jEnsureLocalId` fallback, which returns its candidate unchanged and
%   would happily emit '0001' if the plate component were dropped again.
%
%   The second half drives the exact regression path: with the plate column
%   gone, the OLD code returned the bare `patchID`. The handle must fall back to
%   the document id instead -- unique by construction -- and never to the number.
out = runJ(patchGeometryRow());
sub = firstOfClassJ(out.migrated, 'culture');   % #88: entity of type culture
handle = sub.get('entity.local_identifier');
verifyNotEmpty(testCase, handle, 'local_identifier is REQUIRED on a subject');
verifyEmpty(testCase, regexp(handle, '^\d+$', 'once'), ...
    sprintf('the patch is labelled with the bare number %s', handle));
verifyEqual(testCase, handle, 'plate/0061/patch/0017');

noPlate = dropColumnJ(patchGeometryRow(), 'BacterialPlateIdentifier');
out2 = runJ(noPlate);
sub2 = firstOfClassJ(out2.migrated, 'culture');
handle2 = sub2.get('entity.local_identifier');
% DENOMINATOR FIRST: the map must still have dispatched, or this asserts nothing
% about the handle at all -- a row that fell through to the passthrough would
% mint no subject and firstOfClassJ would have failed instead.
verifyEqual(testCase, sub2.get('base.id'), 'otr_patch');
verifyEmpty(testCase, regexp(handle2, '^\d+$', 'once'), ...
    sprintf(['with no plate column the handle fell back to the bare patch ' ...
             'number %s -- the directive forbids exactly this'], handle2));
verifyEqual(testCase, handle2, 'otr_patch', ...
    'the fallback is the document id, which is unique by construction');
end

function otr = dropColumnJ(otr, key)
%DROPCOLUMNJ Remove one column from an ontology_table_row fixture, keys, names,
%   nodes and data together -- a fixture with a data key its variable_names does
%   not list is not a shape NDI can produce.
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

function testPatchGeometryCarriesUnenumeratedColumns(testCase)
%TESTPATCHGEOMETRYCARRIESUNENUMERATEDCOLUMNS A column the 6-measure enumeration
%   does not name must still be carried, not dropped.
%
%   WHY THIS IS A REAL PROPERTY AND NOT A HYPOTHETICAL. The geometry table
%   already ships a 7th column the enumeration never named --
%   `BacterialPlateIdentifier` (doImport.m:291, `plateID`) -- and it was being
%   dropped on every JH document this map touched. (The map's own commit,
%   72ece64, reports 6,306; that figure is NOT quoted as the geometry-row count,
%   because it was taken while the cultivation-plate table was ALSO dispatching
%   here and nothing has re-measured the split since.) A dropped column
%   is the one loss NO instrument sees: it leaves no empty edge for silentLoss,
%   no scaffolding for isFragment and no vacuous field, so the corpus reads
%   green while the data is gone. The table's width is set by NDI, not by us,
%   so a fixed enumeration is the wrong shape.
otr = patchGeometryRow();
% a column that exists in no enumeration -- stands in for the next one NDI adds
otr.ontology_table_row.variable_names = [ ...
    otr.ontology_table_row.variable_names ',BacterialPatchThickness'];
otr.ontology_table_row.names = [ ...
    otr.ontology_table_row.names ',BacterialPatchThickness'];
otr.ontology_table_row.ontology_nodes = [ ...
    otr.ontology_table_row.ontology_nodes ',EMPTY:0'];
otr.ontology_table_row.data.BacterialPatchThickness = 12.5;

out = runJ(otr);
% dimensionless numeric with no recognised dimension -> intensity (J §7, D8);
% the point of the assertion is that it EXISTS, not which leaf it picked
verifyEqual(testCase, nLeafJ(out.migrated, 'intensity_observation'), 1, ...
    'an unenumerated column was dropped by the patch geometry map');
% and it is about the patch, on the same anchor as the enumerated measures
anchor = firstOfClassJ(out.migrated, 'relative_time_reference');
extra = firstOfClassJ(out.migrated, 'intensity_observation');
verifyEqual(testCase, depVal(extra, 'entity_id'), 'otr_patch');
verifyEqual(testCase, depVal(extra, 'time_reference_id'), anchor.get('base.id'));
% the already-shipped 7th column is carried too, as a term (its value is a label)
plate = firstOfClassJ(out.migrated, 'term_observation');
assertNotEmpty(testCase, plate, ...
    'BacterialPlateIdentifier was dropped');
verifyEqual(testCase, plate.get('term.value').name, '0061');
verifyEqual(testCase, depVal(plate, 'entity_id'), 'otr_patch');
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
    'name', 'row', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(d), 'ontology_table_row');
verifyEqual(testCase, d.get('base.id'), 'otr_cultivation');
bc = out.summary.by_class;
% NOT a patch: no minted subject, and none of the geometry-map outputs
% #88: by_class counts raw classes, so the leaves are counted directly
verifyEqual(testCase, nLeafJ(out.migrated, 'culture'), 0, ...
    'a cultivation plate was minted as a bacterial-patch subject');
verifyEqual(testCase, nLeafJ(out.migrated, 'concentration_observation'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'volume_observation'), 0);
verifyEqual(testCase, nLeafJ(out.migrated, 'relative_time_reference'), 0);
verifyFalse(testCase, isfield(bc, 'entity'));
% and nothing was quarantined to achieve that
verifyEmpty(testCase, out.quarantine);
end

function testPatchGeometryStillDispatchesOnGeometryEvidence(testCase)
%TESTPATCHGEOMETRYSTILLDISPATCHESONGEOMETRYEVIDENCE The tightening's fail-safe.
%
%   The added clause is ANY-of-four (radius / circularity / centre X / centre Y)
%   rather than all-of, on purpose: the shortName strings cannot be evaluated in
%   the repo (ndi.ontology.lookup is not here), so no SINGLE mis-spelling may be
%   allowed to un-dispatch the geometry table -- that would strand the 20,411
%   encounter relations whose parent is the patch document this map preserves.
%   Each column is removed in turn and the map must still fire.
geom = {'BacterialPatchRadius', 'BacterialPatchCircularity', ...
    'BacterialPatchCenter_XCoordinate', 'BacterialPatchCenter_YCoordinate'};
for k = 1:numel(geom)
    otr = patchGeometryRow();
    otr.ontology_table_row.data = rmfield(otr.ontology_table_row.data, geom{k});
    kept = setdiff(strsplit(otr.ontology_table_row.variable_names, ','), ...
        geom(k), 'stable');
    otr.ontology_table_row.variable_names = strjoin(kept, ',');
    otr.ontology_table_row.names = strjoin(kept, ',');
    otr.ontology_table_row.ontology_nodes = strjoin( ...
        repmat({'EMPTY:0'}, 1, numel(kept)), ',');
    out = runJ(otr);
    verifyEqual(testCase, nLeafJ(out.migrated, 'culture'), 1, ...
        sprintf(['the patch geometry map stopped firing when %s was absent; ' ...
                 'one missing geometry column must not un-dispatch it'], geom{k}));
    sub = firstOfClassJ(out.migrated, 'culture');
    verifyEqual(testCase, sub.get('base.id'), 'otr_patch');
end
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
elem.element = struct('ndi_element_class', 'ndi.element', 'name', 'stim', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);

bath = struct();
bath.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0')]);
bath.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
bath.base = struct('id', 'aabb1122ccdd3344_5500000000000004', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'bath', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, nLeafJ(out.migrated, 'formulation_manipulation'), 1, ...
    'no formulation-valued manipulation produced');
verifyEqual(testCase, nLeafJ(out.migrated, 'dose_manipulation'), 0, ...
    'a bath is not a dose (a dose always has an amount)');
verifyFalse(testCase, isfield(out.summary.by_class, 'bath'), ...
    'retired `bath` class must not be emitted at V_eta');
for k = 1:numel(out.quarantine)
    verifyEmpty(testCase, regexp(out.quarantine(k).reason, ...
        'needsSessionContext|NDI layer|class "bath"', 'once'), ...
        sprintf('bath left unresolved: %s', out.quarantine(k).reason));
end

m = firstOfClassJ(out.migrated, 'formulation_manipulation');
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
locObs = firstOfClassJ(out.migrated, 'term_observation');
verifyNotEmpty(testCase, locObs);
verifyEqual(testCase, locObs.get('term.value').name, 'CNS');
verifyEqual(testCase, depVal(locObs, 'entity_id'), subjId);
end

% ============ metadata_editor -> dataset + entities + relations =========

function ds = allOfClassJ(migrated, className)
ds = {};
for k = 1:numel(migrated)
    if strcmp(migrated{k}.get('document_class.class_name'), className) ...
            || strcmp(did2.unittest.helpers.leafName(migrated{k}), className)
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
ms.ExperimentalApproach = {'electrophysiology', 'behavior'};  % bucket 2 projection -> not stored
% two authors, both affiliated to the SAME organization (dedup to one org)
a1 = struct('givenName', 'Ada', 'familyName', 'Lovelace', ...
    'digitalIdentifier', struct('identifier', '0000-0001-2345-6789'), ...
    'contactInformation', struct('email', 'ada@example.org'), ...
    'affiliation', struct('memberOf', struct('fullName', 'Analytical Society')), ...
    'authorRole', 'Custodian');
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
% bucket 2 (projections off subject statements) -> dropped
ms.TechniquesEmployed = 'patch clamp';
ms.Subjects = struct('SubjectName', 'worm_1', 'BiologicalSexList', 'male');
v1.metadata_editor = struct('metadata_structure', ms);
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
% 8 entities + 11 assertions + 8 relations
verifyEqual(testCase, numel(m), 27);
verifyEqual(testCase, nLeafJ(m, 'dataset'), 1);
verifyEqual(testCase, nLeafJ(m, 'person'), 2);
verifyEqual(testCase, nLeafJ(m, 'organization'), 2);   % Analytical Society (deduped) + NIH
verifyEqual(testCase, nLeafJ(m, 'funding'), 1);
verifyEqual(testCase, nLeafJ(m, 'publication'), 1);
verifyEqual(testCase, nLeafJ(m, 'protocol'), 1);
verifyEqual(testCase, nLeafJ(m, 'directed_relation'), 8);
verifyEqual(testCase, out.summary.by_class.assertion, 11);
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
verifyEqual(testCase, lic.get('term.value').name, 'CC-BY-4.0');
rd = assertionAboutJ(out.migrated, id, 'release date');
verifyEqual(testCase, rd.get('date.value').instant, '2024-01-15');
kw = textAboutJ(out.migrated, id, 'Keyword');
verifyEqual(testCase, sort(kw), {'calcium imaging', 'worm'});
% bucket-2 projections are not stored
verifyEmpty(testCase, assertionAboutJ(out.migrated, id, 'experimental approach'));
end


function testMetadataEditorAuthorsAndOrcid(testCase)
% UPDATED for #88: a person is an entity named 'given family', its ORCID a
% `ORCID:` global identifier; given name, family name and e-mail are assertions
% about it; authorship is has_author (dataset -> person) with a sequence.
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
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(d.get('directed_relation.relation').name, 'has_author')
        verifyEqual(testCase, depVal(d, 'child_id'), ds.get('base.id'));
        seqs(end+1) = d.get('directed_relation.sequence'); %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(seqs), [1 2]);
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
            && strcmp(d.get('directed_relation.relation').name, 'affiliated_with')
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
% census is defeated by the `(unnamed dataset)` fallback). A struct fixture
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
%   EmptyStructureStillYields...           1 ->  1             no, by design
%   StructureInsideACellIsStillRead        1 -> 16             YES
%
% The two insensitive ones are PINS, not proofs: the baseline pins that the
% round trip alone changes nothing, and the empty-structure one pins that the
% `(unnamed dataset)` fallback still fires for the NDI template's own default.

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
            && strcmp(d.get('directed_relation.relation').name, relName)
        n = n + 1;
    end
end
end

function testMetadataEditorSurvivesTheJsonRoundTrip(testCase)
% The decomposition is unchanged by a jsonencode/jsondecode round trip.
% UPDATED for #88 (entity types, assertions; 27 documents).
out = runJRoundTrip(metadataEditorDoc());
m = out.migrated;
verifyEqual(testCase, numel(m), 27);
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
    'authorRole',         'Custodian');
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
verifyEqual(testCase, numel(m), 27);
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
verifyEqual(testCase, numel(m), 33);   % 11 entities + 11 assertions + 11 relations
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


function testMetadataEditorEmptyStructureStillYieldsTheUnnamedDataset(testCase)
% An editor with no structure still yields the dataset entity, named
% '(unnamed dataset)'. UPDATED for #88: the name is entity.name.
v1 = metadataEditorDoc();
v1.metadata_editor = struct('metadata_structure', []);
out = runJRoundTrip(v1);
verifyEqual(testCase, numel(out.migrated), 1);
ds = out.migrated{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(ds), 'dataset');
verifyEqual(testCase, ds.get('base.id'), 'sess_09');
verifyEqual(testCase, ds.get('entity.name'), '(unnamed dataset)');
end


function testMetadataEditorStructureInsideACellIsStillRead(testCase)
% A structure wrapped in a cell beside other keys is still read. UPDATED for #88.
v1 = metadataEditorDoc();
ms = v1.metadata_editor.metadata_structure;
other = struct('SomeOtherKey', 'ignored');
v1.metadata_editor.metadata_structure = {ms, other};
out = runJRoundTrip(v1);
verifyEqual(testCase, numel(out.migrated), 27);
ds = firstOfClassJ(out.migrated, 'dataset');
verifyEqual(testCase, ds.get('entity.name'), 'The Big Worm Dataset');
end


function r = relByName(migrated, relName)
r = [];
for k = 1:numel(migrated)
    d = migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation') ...
            && strcmp(d.get('directed_relation.relation').name, relName)
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
verifyEqual(testCase, org.get('entity.name'), 'ndicloud-lab');
verifyEqual(testCase, depVal(hosted, 'parent_id'), org.get('base.id'));
end


function v1 = sessionInADatasetDoc(memberSession)
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
verifyEqual(testCase, rel.get('directed_relation.relation').name, relName);
verifyEqual(testCase, rel.get('directed_relation.relation').node, relNode);
verifyEqual(testCase, depVal(rel, 'child_id'), 'member_sess_9');   % the member session
verifyEqual(testCase, depVal(rel, 'parent_id'), 'dsid_1');          % the dataset
end


function testDatasetSessionInfoAggregate(testCase)
% One membership relation per listed session. UPDATED for #88 (dataset entity).
v1 = struct();
v1.document_class = struct('class_name', 'dataset_session_info', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'dsi_01', 'session_id', 'dsid_1', ...
    'name', 'dsi', 'datestamp', '2024-06-01T12:00:00.000Z');
e1 = struct('session_id', 'member_a', 'is_linked', 0);
e2 = struct('session_id', 'member_b', 'is_linked', 1);
v1.dataset_session_info = struct('dataset_session_info', [e1 e2]);
out = runJ(v1);
verifyEqual(testCase, nLeafJ(out.migrated, 'dataset'), 1);
verifyEqual(testCase, nLeafJ(out.migrated, 'directed_relation'), 2);   % two members
children = {};
relName = membershipRelation();
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if strcmp(d.get('document_class.class_name'), 'directed_relation')
        verifyEqual(testCase, d.get('directed_relation.relation').name, relName);
        verifyEqual(testCase, depVal(d, 'parent_id'), 'dsid_1');
        children{end+1} = depVal(d, 'child_id'); %#ok<AGROW>
    end
end
verifyEqual(testCase, sort(children), {'member_a', 'member_b'});
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
            && strcmp(d.get('directed_relation.relation').name, relName)
        verifyNotEqual(testCase, depVal(d, 'child_id'), 'absent_sess');
    end
end
end


% ============ regression: relations carry no stale subject_relation block =====

function testDirectedRelationsHaveNoSubjectRelationBlock(testCase)
% subject_relation was renamed to `relation` (abstract, no fields) -> migrators
% must NOT emit a subject_relation property block, or the doc fails validation
% with "undeclared top-level block subject_relation" and quarantines (the JH
% 163k-orphan regression). Check the element + subject_group relation emitters.
outs = {runJ(elementDoc('unit3', 'spikes', 'ndi.neuron', 0, 'subj_007', 'probe_1')), ...
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
% DID-schema's build_v_eta.py, each a few lines from something contradicting it.
% directly (the quick CI's V_zeta schema still has daqreader_ndr; under the V_eta
% corpus run daqreader_ndr is gone and the folded daqreader validates).
body = struct();
body.document_class = struct('class_name', 'daqreader_ndr', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base',      'class_version', '1.0.0'), ...
                      struct('class_name', 'daqreader', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', 'ndr_1', 'session_id', 'sess_09', ...
    'name', 'reader', 'datestamp', '2024-06-01T12:00:00.000Z');
body.daqreader = struct('ndi_daqreader_class', 'ndi.daq.reader.mfdaq.ndr');
body.daqreader_ndr = struct('ndi_daqreader_ndr_class', 'ndi.daq.reader.mfdaq.ndr', ...
    'ndr_reader_string', 'intan', 'file_extension', '.rhd');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(reader), 'acquisition_reader');
verifyEqual(testCase, reader.base.id, 'ndr_1', ...
    'base.id must be preserved on the reader or reader_id edges dangle');
verifyEqual(testCase, reader.acquisition_reader.reader_string, 'intan');
% The implementation class became a `software` entity with its OWN id -- which
% is what lets the deferred dedup pass merge rigs sharing one class (#25).
verifyEqual(testCase, did2.unittest.helpers.leafName(software), 'software');
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
% it survived. The fixture above still SETS it, deliberately: that is what
% makes this an assertion about the migrator rather than about the fixture.
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
    'name', 'ingested', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.daqreader_epochdata_ingested = struct('epochtable', ...
    struct('epochclock', {{'dev_local_time'}}, 't0_t1', [0, 10]));
body.daqreader_mfdaq_epochdata_ingested = struct('parameters', ...
    struct('sample_analog_segment', 1000000, 'sample_digital_segment', 1000000));
out = did2.convert.migrators_j.daqreader_mfdaq_epochdata_ingested(body);
verifyEqual(testCase, did2.unittest.helpers.leafName(out), 'daqreader_epochdata_ingested');
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
    'name', 't00001', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', 't00001');
body.element_epoch = struct('epoch_clock', 'dev_local_time', 't0_t1', [0; 930.35]);
out = did2.convert.migrators_j.element_epoch(body);
verifyEqual(testCase, did2.unittest.helpers.leafName(out), 'acquisition_epoch');
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
    'name', 'dm', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(doc), 'distance_metadata');

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
names = cellfun(@(d) did2.unittest.helpers.leafName(d), out.migrated, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'length_observation')));
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
    'name', 'pyr', 'datestamp', '2024-06-01T12:00:00.000Z');
body.pyraview = struct('label', 'lfp', 'native_rate', 1000, ...
    'native_start_time', 0, 'channels', 4, 'data_type', 'int16', ...
    'decimation_sampling_rates', [1000 500]);
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
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'voltage_observation')));
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));
% ONE sampled_body per stored level (2 here) -> 1 obs + 2 bodies + 1 anchor
sbods = out(strcmp(names, 'sampled_body'));
verifyEqual(testCase, numel(sbods), 2);

obs = out{find(strcmp(names, 'voltage_observation'), 1)};
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
    ax = sbods{j}.data.keys;   % #88: `axes` became `data.keys`
    verifyEqual(testCase, numel(ax), 2, ...
        'both dimensions or neither -- a positional list has no partial mode');
    verifyEqual(testCase, ax(1).variable.name, 'time');
    verifyEqual(testCase, ax(2).variable.name, 'channel');
    verifyEqual(testCase, ax(2).n, 4);          % the `channels` field
    verifyTrue(testCase, ax(1).regular);
end
% Levels are told apart by the TIME axis spacing now, not by sample_time.dt --
% that block is no longer written here (step 5 of the signed build order), and
% writing the cadence into both would store one fact twice.
dts = sort(arrayfun(@(k) sbods{k}.data.keys(1).spacing.source_value, ...
    1:numel(sbods)));
verifyEqual(testCase, dts, [1e-3 2e-3], 'AbsTol', 1e-9);
% and by extent: 10 s at 1000 Hz and at 500 Hz. `n` was hardcoded 0 on every
% body until this change, on bodies with real bytes attached.
ns = sort(arrayfun(@(k) sbods{k}.data.keys(1).n, 1:numel(sbods)));
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
    'name', 'sw', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'spikewaves');
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
    'name', 'br', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'binnedspikeratevm');
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
    'name', 'vs', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'vmspikesummary');
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
% contrast_tuning -> the contrast_tuning_calculation leaf, id-preserved (did-schema
% #88). UPDATED for #88: a calculation REQUIRES operating_system_id, read from the
% v1 `app.os`, so the fixture now carries the `app` block every real calculator
% document has (ndi.app.newdocument stamps it; all Soph *_calc samples carry it).
% Without it the document passes through -- see
% testCalculationWithNoOperatingSystemPassesThrough. Out: leaf + session anchor +
% three software entities (app, os, interpreter), each with a version assertion.
body = struct();
body.document_class = struct('class_name', 'contrast_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'ct_1', 'session_id', 'sess_09', 'name', 'ct', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.contrast');
body.contrast_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s', 'response_type', 'mean'), ...
    'tuning_curve', struct('contrast', [0 0.25 0.5 1], 'mean', [2 5 9 12]));

out = did2.convert.migrators_j.contrast_tuning(body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'contrast_tuning_calculation', 'ct_1', 'sub_8');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_1');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.vis.contrast');
verifyEqual(testCase, leaf.tuning_curve.value.mean, [2 5 9 12]);
verifyEqual(testCase, leaf.data.keys(1).quantity.value, [0 0.25 0.5 1]);
verifyEqual(testCase, lower(leaf.data.keys(1).variable.name), 'contrast');
end


function testOrientationDirectionTuningFoldsToCalculationLeaf(testCase)
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
body.base = struct('id', 'odt_1', 'session_id', 'sess_09', 'name', 'odt', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.oridir');
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5, 'circular_variance', 0.3), ...
    'significance', struct('visual_response_anova_p', 0.002), ...
    'fit', struct('hwhh', 22.0));

out = did2.convert.migrators_j.orientation_direction_tuning(body);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));   % not decomposed
verifyFalse(testCase, any(strcmp(names, 'angle_observation')));
leaf = calcLeafJ(testCase, out, 'orientation_direction_tuning_calculation', 'odt_1', 'neuron_1');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_1');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.vis.oridir');
verifyEqual(testCase, leaf.data.keys(1).quantity.value, [0 90 180 270]);
verifyEqual(testCase, leaf.tuning_curve.value.mean, [10 2 9 3]);
verifyEqual(testCase, leaf.tuning_curve_calculation.significance.visual_response_anova_p, ...
    0.002, 'AbsTol', 1e-9);
cs = leaf.orientation_direction_tuning_calculation.circular_statistics;
verifyEqual(testCase, cs.orientation_preference, 47.5, 'AbsTol', 1e-9);
verifyEqual(testCase, cs.circular_variance, 0.3, 'AbsTol', 1e-9);
mf = leaf.tuning_curve_calculation.model_fit;
verifyEqual(testCase, numel(mf), 1);
verifyEqual(testCase, mf(1).metrics.half_width_at_half_maximum, 22.0, 'AbsTol', 1e-9);
end


function testOridirtuningCalcUndefersToLeaf(testCase)
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
body.base = struct('id', 'oc_1', 'session_id', 'sess_09', 'name', 'oc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.calc.vis.oridir', 'version', '1.2', ...
    'url', 'https://github.com/VH-Lab/NDI-matlab', 'os', 'Linux', ...
    'os_version', '22.04', 'interpreter', 'MATLAB', 'interpreter_version', '24.2');
body.oridirtuning_calc = struct('input_parameters', ...
    struct('independent_variable', 'direction'));
body.orientation_direction_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('direction', [0 90 180 270], 'mean', [10 2 9 3]), ...
    'vector', struct('orientation_preference', 47.5));

out = did2.convert.migrators_j.oridirtuning_calc(body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'orientation_direction_tuning_calculation', 'oc_1', 'neuron_9');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_9');
verifyEqual(testCase, paramTextJ(leaf, 'independent variable'), 'direction');
sw = entityByNameJ(out, 'ndi.calc.vis.oridir');
verifyEqual(testCase, sw.entity.local_identifier, 'ndi.calc.vis.oridir@1.2');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
os = entityByNameJ(out, 'Linux');
verifyEqual(testCase, depValue(leaf, 'operating_system_id'), os.base.id);
it = entityByNameJ(out, 'MATLAB');
verifyEqual(testCase, depValue(leaf, 'interpreter_id'), it.base.id);
verifyEqual(testCase, leaf.data.keys(1).quantity.value, [0 90 180 270]);
end


function testContrastSensitivityCalcUndefersToLeaf(testCase)
% The aggregate ndi.calc.vis.contrast_sensitivity output folds 1 -> 1,
% id-preserved, into contrast_sensitivity_calculation. UPDATED for #88: the
% spatial frequencies are the statement's key (data.keys), each RB/RBN/RBNS
% Naka-Rushton variant is one value.model_fit entry whose coefficients are a
% {variable, value} list, input_parameters -> method.parameters, the consumed
% responses -> input_id, and `is_modulated_response` has no #88 field (dropped,
% reported by the migrator).
body = struct();
body.document_class = struct('class_name', 'contrast_sensitivity_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'calculator'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'neuron_cs'), ...
                    struct('name', 'stimulus_response_scalar_id', 'value', 'resp_cs')];
body.base = struct('id', 'cs_1', 'session_id', 'sess_09', 'name', 'cs', ...
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
verifyEqual(testCase, depValue(leaf, 'input_id'), 'resp_cs');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.vis.contrast_sensitivity');
verifyEqual(testCase, paramValueJ(leaf, 'threshold'), 1);
verifyEqual(testCase, leaf.data.keys(1).quantity.value, [0.5 1 2 4]);
csv = leaf.contrast_sensitivity.value;
verifyEqual(testCase, numel(csv.model_fit), 2);            % rb and rbns, not rbn
models = arrayfun(@(e) lower(char(e.model.name)), csv.model_fit, 'UniformOutput', false);
rbAt = find(endsWith(models, ' rb'), 1);
verifyNotEmpty(testCase, find(endsWith(models, ' rbns'), 1));
verifyEmpty(testCase, find(endsWith(models, ' rbn'), 1));
assertNotEmpty(testCase, rbAt);
rb = csv.model_fit(rbAt);
verifyEqual(testCase, rb.sensitivity, [10 20 15 5]);       % metric rides INSIDE its fit
verifyEqual(testCase, rb.empirical_c50, [0.2 0.3 0.4 0.5]);
verifyEqual(testCase, [rb.coefficients.value], [12 0.25 2]);
verifyEqual(testCase, csv.interpolated_values.c50, [0.21 0.31 0.41 0.51]);
verifyEqual(testCase, csv.significance.visual_response_p_bonferroni, [0.01 0.02 0.03 0.04]);
verifyEqual(testCase, lower(csv.response_type.name), 'mean');
sw = entityByNameJ(out, 'ndi.calc.vis.contrast_sensitivity');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
end


function testTuningcurveCalcUndefersToLeaf(testCase)
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
body.base = struct('id', 'tcc_1', 'session_id', 'sess_11', 'name', 'tc', ...
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

out = did2.convert.migrators_j.tuningcurve_calc(body);
verifyEqual(testCase, numel(out), 8);
leaf = calcLeafJ(testCase, out, 'tuning_curve_calculation', 'tcc_1', 'neuron_tc');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'resp_tc');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.stimulus.tuningcurve');
verifyEqual(testCase, paramTextJ(leaf, 'best algorithm'), 'empirical_maximum');
verifyEqual(testCase, leaf.tuning_curve.value.mean, [1 4 8 11]);
verifyEqual(testCase, leaf.data.keys(1).quantity.value, [0 0.25 0.5 1]);
sw = entityByNameJ(out, 'ndi.calc.stimulus.tuningcurve');
verifyEqual(testCase, depValue(leaf, 'software_id'), sw.base.id);
os = entityByNameJ(out, 'Linux');
verifyEqual(testCase, depValue(leaf, 'operating_system_id'), os.base.id);
end


function testStimulusTuningcurveRawFoldsToCalculationLeaf(testCase)
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
body.base = struct('id', 'stc_1', 'session_id', 'sess_11', 'name', 'rawtc', ...
    'datestamp', '2024-07-01T12:00:00.000Z');
body.app = calcAppJ('ndi.app.stimulus.tuning_response');
body.stimulus_tuningcurve = struct( ...
    'independent_variable_label', 'direction', ...
    'independent_variable_value', [0 90 180 270], ...
    'response_mean', [10 2 9 3], 'response_units', 'Spikes/s');

out = did2.convert.migrators_j.stimulus_tuningcurve(body);
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
% speed_tuning -> speed_tuning_calculation, id-preserved (#88). UPDATED for #88:
% app block added (an operating system is required); the two stimulus axes
% (SF, TF) become ONE key whose positions are labelled by both values.
body = struct();
body.document_class = struct('class_name', 'speed_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_s'});
body.base = struct('id', 'sp_1', 'session_id', 'sess_09', 'name', 'sp', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.speed');
body.speed_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('spatial_frequency', [0.5 0.5 1], ...
        'temporal_frequency', [2 4 4], 'mean', [5 8 6]));

out = did2.convert.migrators_j.speed_tuning(body);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));
leaf = calcLeafJ(testCase, out, 'speed_tuning_calculation', 'sp_1', 'sub_s');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.vis.speed');
verifyEqual(testCase, leaf.tuning_curve.value.mean, [5 8 6]);
verifyEqual(testCase, leaf.data.keys(1).n, 3);
end


function v1 = ontologyImageVintageA()
% VINTAGE A (legacy, DID-schema V_alpha/V_beta ancestry): the region is two
% coordinated chars and `element_id` supplies the subject. Shape taken from
% schemas/V_alpha/ontologyImage.json, NOT from our own V_eta schema.
v1 = struct();
v1.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'element_id'}, 'value', {'elem_9'});
v1.base = struct('id', 'oi_1', 'session_id', 'sess_09', 'name', 'oi', ...
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
v1.base = struct('id', 'oi_2', 'session_id', 'sess_09', 'name', 'oi', ...
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
v1.base = struct('id', 's2c_1', 'session_id', 'sess_09', 'name', 's2c', ...
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
verifyEqual(testCase, did2.unittest.helpers.leafName(o), 'term_observation');
verifyEqual(testCase, o.statement.variable.name, 'imaged region');
verifyEqual(testCase, o.term.value.node, 'uberon:0002436');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(o), 'ontology_image');
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

function testOntologyImageRejectsVDeltaRegionShape(testCase)
% THE GUARD. `region` is the V_delta migrator's OUTPUT, not a did_v1 field.
% The previous implementation read it, so it matched only a fixture built to
% our own schema and silently emitted an empty observation about nobody.
% Reading it again must be loud, not silent.
v1 = ontologyImageVintageA();
v1.ontology_image = struct('region', ...
    struct('node', 'uberon:0002436', 'name', 'primary visual cortex'));
verifyError(testCase, @() did2.convert.migrators_j.ontology_image(v1), ...
    'did2:convert:ontologyImageVDeltaShape');
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
v1.base = struct('id', 'eo_1', 'session_id', 'sess_09', 'name', 'eo', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.electrode_offset_voltage = struct('offset', 0.5, 'temperature', 11);

out = did2.convert.migrators_j.electrode_offset_voltage(v1);
verifyEqual(testCase, numel(out), 2);
o = out{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(o), 'voltage_observation');
verifyEqual(testCase, depValue(o, 'entity_id'), 'probe_7');
% a single reading, expressed as a length-1 array
vals = o.voltage.value;
verifyEqual(testCase, numel(vals), 1);
verifyEqual(testCase, vals(1).source_value, 0.5, 'AbsTol', 1e-9);
verifyEqual(testCase, vals(1).source_unit.name, 'V');   % #88: a bound term
verifyEqual(testCase, vals(1).volts, 0.5, 'AbsTol', 1e-9);
% temperature qualifies the SAME statement rather than becoming its own doc
c = o.statement.conditions;   % #88: conditions live on `statement`
verifyEqual(testCase, c.variable.name, 'temperature');
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
v1.base = struct('id', 'eo_2', 'session_id', 'sess_09', 'name', 'eo', ...
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
v1.base = struct('id', 'eo_3', 'session_id', 'sess_09', 'name', 'eo', ...
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
verifyEqual(testCase, did2.unittest.helpers.leafName(a), 'term_assertion');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'openminds_stimulus');
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
    'name', 'jc', 'datestamp', '2024-06-01T12:00:00.000Z');
body.jrclust_clusters = struct('res_mat_md5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');
body.files = struct('file_list', {{'clusters.mat'}});

out = did2.convert.migrators_j.jrclust_clusters(body);
verifyEqual(testCase, numel(out), 3);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
% #88: the .mat is an OPAQUE body (format EDAM:format_2333), not a sampled one
verifyTrue(testCase, any(strcmp(names, 'opaque_body')));
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));

obs = out{find(strcmp(names, 'count_observation'), 1)};
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
    'name', 'ks', 'datestamp', '2024-06-01T12:00:00.000Z');
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
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'count_observation')));
verifyTrue(testCase, any(strcmp(names, 'opaque_body')));
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    'the app block must become a software entity, not vanish');
verifyTrue(testCase, any(strcmp(names, 'relative_time_reference')));

obs = out{find(strcmp(names, 'count_observation'), 1)};
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
verifyTrue(testCase, contains(ob.data_body.description, 'd41d8cd9'));% MD5 noted
end

function testKiasortClustersFoldsToCountObservationPlusOpaqueBody(testCase)
% Sibling of kilosort: kiasort_clusters decomposes identically (method 'kiasort',
% kiasort_directory).
body = struct();
body.document_class = struct('class_name', 'kiasort_clusters', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'; 'app'}, 'class_version', {'1.0.0'; '1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_ka'});
body.base = struct('id', 'ka_1', 'session_id', 'sess_09', ...
    'name', 'ka', 'datestamp', '2024-06-01T12:00:00.000Z');
body.app = struct('name', 'ndi.app.kiasort', 'version', '1.0');
body.kiasort_clusters = struct('kiasort_directory', 'ka_out/session1', ...
    'curated_output_MD5_checksum', 'd41d8cd98f00b204e9800998ecf8427e');

out = did2.convert.migrators_j.kiasort_clusters(body);
% 3 -> 4: the app block now becomes a `software` entity instead of being
% dropped -- see the sibling kilosort test above for why this arity moved.
verifyEqual(testCase, numel(out), 5);   % #88: + the software version text_assertion
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'software')), ...
    'the app block must become a software entity, not vanish');
obs = out{find(strcmp(names, 'count_observation'), 1)};
verifyEqual(testCase, obs.base.id, 'ka_1');
verifyEqual(testCase, obs.interaction.method.term.name, 'kiasort');
ob = out{find(strcmp(names, 'opaque_body'), 1)};
verifyEqual(testCase, ob.data_body.filename, 'ka_out/session1');
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
    'name', 'sis', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'spike_interface_sorting_outputs');
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
v1.base = struct('id', 'pg_1', 'session_id', 'sess_09', 'name', 'pg', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.probe_geometry = struct( ...
    'site_locations_leftright', [0 20], ...
    'site_locations_frontback', [0 0], ...
    'site_locations_depth', [], ...
    'ndim', 2, 'unit', 'um', ...
    'probe_model', 'linear', 'manufacturer', 'acme');

out = did2.convert.migrators_j.probe_geometry(v1);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
% two populated axes -> two observations; depth is empty so it is NOT emitted
verifyEqual(testCase, sum(strcmp(names, 'length_observation')), 2);
vars = {};
for k = 1:numel(out)
    if strcmp(names{k}, 'length_observation')
        vars{end+1} = out{k}.statement.variable.name; %#ok<AGROW>
    end
end
verifyTrue(testCase, any(strcmp(vars, 'site location (left-right)')));
verifyTrue(testCase, any(strcmp(vars, 'site location (front-back)')));
verifyFalse(testCase, any(strcmp(vars, 'site location (depth)')));

lr = out{find(strcmp(names, 'length_observation'), 1)};
verifyEqual(testCase, depValue(lr, 'entity_id'), 'probe_5');
verifyEqual(testCase, numel(lr.length.value), 2);
verifyEqual(testCase, lr.length.value(2).source_value, 20, 'AbsTol', 1e-9);
verifyEqual(testCase, lr.length.value(1).source_unit.name, 'micrometre');   % registry label for 'um'
verifyEqual(testCase, lr.length.value(2).meters, 2e-5, 'AbsTol', 1e-12);

% probe_model, not the invented probe_type
assertion = out{find(strcmp(names, 'term_assertion'), 1)};
verifyEqual(testCase, assertion.statement.variable.name, 'probe model');
verifyEqual(testCase, assertion.term.value.name, 'linear');
end

function testProbeGeometryRejectsInventedShape(testCase)
% channel_positions/position_units/probe_type are V_alpha inventions. Reading
% them again must be loud, not a silent carry-through.
v1 = struct();
v1.document_class = struct('class_name', 'probe_geometry', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'probe_id'}, 'value', {'probe_5'});
v1.base = struct('id', 'pg_2', 'session_id', 'sess_09', 'name', 'pg', ...
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
    'name', 's2c', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'site2channelmap');
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

function testPositionMetadataBecomesTermObservation(testCase)
% position_metadata carries only DESCRIPTIVE ontology fields -- the numeric
% coordinates live in the separate element/timeseries doc that element_id points
% at, NOT here. So it folds to a term_observation of the element-subject naming
% the measurement term (value = the ontologyNode CURIE), plus a session anchor.
% 1 -> 2. No values are invented.
body = struct();
body.document_class = struct('class_name', 'position_metadata', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'element_id'}, 'value', {'pos_elem_7'});
body.base = struct('id', 'pm_01', 'session_id', 'sess_09', ...
    'name', 'pm', 'datestamp', '2024-06-01T12:00:00.000Z');
body.position_metadata = struct('ontology_node', 'EMPTY:0000200', ...
    'units', 'NCIT:C48367', 'dimensions', 'NCIT:C44477,NCIT:C44478');

bodies = did2.convert.migrators_j.position_metadata(body);
verifyEqual(testCase, numel(bodies), 2);              % obs + anchor
obs = bodies{1};
verifyEqual(testCase, did2.unittest.helpers.leafName(obs), 'term_observation');
verifyEqual(testCase, obs.term.value.node, 'EMPTY:0000200');
verifyEqual(testCase, obs.statement.variable.name, 'position');
verifyEqual(testCase, obs.statement.variable.node, 'PATO:0000140');
verifyEqual(testCase, depValue(obs, 'entity_id'), 'pos_elem_7');
anchor = bodies{2};
verifyEqual(testCase, did2.unittest.helpers.leafName(anchor), 'relative_time_reference');
verifyEqual(testCase, anchor.relative_time_reference.value.relation.name, 'intervalDuring');
verifyEqual(testCase, depValue(obs, 'time_reference_id'), anchor.base.id);
end

function testSpatialFrequencyTuningFoldsToCalculationLeaf(testCase)
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
body.base = struct('id', 'sf_1', 'session_id', 'sess_09', 'name', 'sf', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.app = calcAppJ('ndi.calc.vis.spatial_frequency_tuning');
body.spatial_frequency_tuning = struct( ...
    'properties', struct('response_units', 'spikes/s'), ...
    'tuning_curve', struct('spatial_frequency', [0.05 0.1 0.2 0.5], 'mean', [2 8 5 1]), ...
    'significance', struct('visual_response_anova_p', 0.01, 'across_stimuli_anova_p', 0.03), ...
    'fitless', struct('pref', 0.12, 'l50', 0.06, 'h50', 0.28, 'bandwidth', 2.2, ...
        'low_pass_index', 0.3, 'high_pass_index', 0.7), ...
    'fit_dog', struct('r2', 0.95, 'pref', 0.13));

out = did2.convert.migrators_j.spatial_frequency_tuning(body);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'score_observation')));
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));
leaf = calcLeafJ(testCase, out, 'spatial_frequency_tuning_calculation', 'sf_1', 'neuron_2');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_2');
verifyEqual(testCase, lower(leaf.interaction.method.term.name), 'ndi.calc.vis.spatial_frequency_tuning');
mf = leaf.tuning_curve_calculation.model_fit;
verifyEqual(testCase, numel(mf), 1);
verifyEqual(testCase, lower(char(mf(1).model.name)), 'dog');
verifyEqual(testCase, mf(1).goodness.r2, 0.95, 'AbsTol', 1e-9);
verifyEqual(testCase, mf(1).metrics.preferred_value, 0.13, 'AbsTol', 1e-9);
verifyEqual(testCase, leaf.tuning_curve_calculation.significance.visual_response_anova_p, ...
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
body.base = struct('id', 'tft_1', 'session_id', 'sess_09', 'name', 'tft', ...
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
% did_v1 temporal_frequency_tuning -> temporal_frequency_tuning_calculation
% (#88), from the WRITER-shaped fixture below. UPDATED for #88: the leaf is the
% concrete *_calculation class (under tuning_curve_calculation); the consumed
% curve -> input_id; the TF axis -> data.keys; the five co-existing fits ->
% tuning_curve_calculation.model_fit with {model, coefficients list, goodness,
% metrics, sampled_fit}; `fitless` -> the leaf's interpolated_values.
out = did2.convert.migrators_j.temporal_frequency_tuning(temporalFrequencyTuningBody());
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 8);
verifyFalse(testCase, any(strcmp(names, 'frequency_observation')));
leaf = calcLeafJ(testCase, out, 'temporal_frequency_tuning_calculation', 'tft_1', 'tf_elem_3');
verifyEqual(testCase, depValue(leaf, 'input_id'), 'tc_tf_9');
verifyEqual(testCase, depValue(leaf, 'session_id'), 'sess_09');
superNames = {leaf.document_class.superclasses.class_name};
verifyTrue(testCase, any(strcmp(superNames, 'tuning_curve_calculation')));
verifyEqual(testCase, lower(leaf.interaction.method.term.name), ...
    'ndi.calc.vis.temporal_frequency_tuning');
verifyEqual(testCase, nParamsJ(leaf), 0, ...
    'a bare temporal_frequency_tuning document carries no input_parameters to carry');

verifyEqual(testCase, leaf.data.keys(1).quantity.value, [1 2 4 8]);
verifyEqual(testCase, lower(leaf.data.keys(1).variable.name), 'temporal frequency');
v = leaf.tuning_curve.value;
verifyEqual(testCase, v.mean, [1; 5; 9; 3]);
verifyEqual(testCase, v.stddev, [0.1; 0.2; 0.3; 0.4]);
verifyEqual(testCase, v.stderr, [0.05; 0.1; 0.15; 0.2]);
verifyEqual(testCase, size(v.individual), [4 2]);   % #88 D3: stimuli x trials
verifyEqual(testCase, v.control.mean, [0.5; 0.5; 0.5; 0.5]);
verifyEqual(testCase, leaf.tuning_curve_calculation.significance.visual_response_anova_p, ...
    0.002, 'AbsTol', 1e-12);
verifyEqual(testCase, leaf.tuning_curve_calculation.significance.across_stimuli_anova_p, ...
    0.031, 'AbsTol', 1e-12);
iv = leaf.temporal_frequency_tuning_calculation.interpolated_values;
verifyEqual(testCase, iv.preferred_value, 4.2, 'AbsTol', 1e-12);

mf = leaf.tuning_curve_calculation.model_fit;
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
% recording. neuron_extracellular -> subject + derived_from relation (unit <- the
% recording subject) + a count_assertion of the sorter's cluster_index + a
% score_observation of the unit + anchor. 1 -> 5.
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
    'name', 'ne', 'datestamp', '2024-06-01T12:00:00.000Z');
body.neuron_extracellular = struct('cluster_index', 7, 'quality_number', 3, ...
    'number_of_channels', 4);

out = did2.convert.migrators_j.neuron_extracellular(body);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyEqual(testCase, numel(out), 5, ...
    sprintf('expected 5 bodies, got %d: %s', numel(out), strjoin(names, ', ')));
verifyTrue(testCase, any(strcmp(names, 'cell')));   % #88: the unit is an entity of type cell
verifyTrue(testCase, any(strcmp(names, 'directed_relation')));
verifyTrue(testCase, any(strcmp(names, 'score_observation')));
verifyTrue(testCase, any(strcmp(names, 'count_assertion')));
verifyFalse(testCase, any(strcmp(names, 'voltage_observation')), ...
    'no mean_waveform in this fixture -- an observation here would be a husk');

neuron = out{find(strcmp(names, 'cell'), 1)};
verifyEqual(testCase, neuron.entity.local_identifier, 'unit_7');
rel = out{find(strcmp(names, 'directed_relation'), 1)};
% derived_from: unit (child) <- recording subject (parent)
verifyEqual(testCase, depValue(rel, 'child_id'), neuron.base.id);
verifyEqual(testCase, depValue(rel, 'parent_id'), 'rec_sub_1');
verifyEqual(testCase, rel.directed_relation.relation.name, 'derived_from');
% the quality observation is about the minted unit
qobs = out{find(strcmp(names, 'score_observation'), 1)};
verifyEqual(testCase, depValue(qobs, 'entity_id'), neuron.base.id);
verifyEqual(testCase, qobs.score.value.score, 3, 'AbsTol', 1e-9);
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
    'name', 'sc', 'datestamp', '2024-06-01T12:00:00.000Z');
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'spike_clusters');
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

function testHartleyCalcPassesThroughOn88(testCase)
% did-schema #88: receptive_field.value is a REQUIRED structure declaring no
% sub-fields, so no receptive_field_calculation can validate; corpus run
% 39550766416 quarantined all 210 of 20211116's hartley_calc documents before
% this passthrough. The document stays on its v1 tombstone, id and body intact.
body = struct();
body.document_class = struct('class_name', 'hartley_calc', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_h'});
body.base = struct('id', 'hc_1', 'session_id', 'sess_09', 'name', 'hc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.hartley_calc = struct('input_parameters', struct());
out = did2.convert.migrators_j.hartley_calc(body);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'hartley_calc');
verifyEqual(testCase, out{1}.base.id, 'hc_1');
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
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'model_fit_calculation')), strjoin(names, ', '));
calc = out{find(strcmp(names, 'model_fit_calculation'), 1)};
verifyEqual(testCase, calc.base.id, 'fc_1', 'id preserved');
verifyEqual(testCase, depValue(calc, 'entity_id'), 'sub_9');
verifyNotEmpty(testCase, depValue(calc, 'operating_system_id'));
verifyEqual(testCase, calc.model_fit.value.equation, 'gaussian');
verifyEqual(testCase, calc.model_fit.value.goodness.sse, 12.5, 'AbsTol', 1e-9);
end

function testFitcurveWithNoOperatingSystemPassesThrough(testCase)
% The same document with no `app` block: #88 cannot state a calculation that
% names no operating system, and one is never invented, so the v1 document
% passes through unchanged (Jess Haley, 2026-10-21).
out = did2.convert.migrators_j.fitcurve(fitcurveBody('fc_1', 'sub_9'));
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'fitcurve');
verifyEqual(testCase, out{1}.fitcurve.fit_sse, 12.5, 'AbsTol', 1e-9);
end

function body = fitcurveBody(id, elementId)
% Built from the NDI TEMPLATE: fit_equation and fit_sse are what it carries.
body = struct();
body.document_class = struct('class_name', 'fitcurve', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {elementId});
body.base = struct('id', id, 'session_id', 'sess_09', 'name', 'fc', ...
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
body.base = struct('id', 'fc_2', 'session_id', 'sess_09', 'name', 'fc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.fitcurve = struct('fit_equation', 'gaussian', 'fit_sse', 12.5);

out = did2.convert.migrators_j.fitcurve(body);

verifyEqual(testCase, numel(out), 1, ...
    'a subject-less fitcurve must pass through as exactly one document');
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
verifyFalse(testCase, any(strcmp(names, 'score_observation')), ...
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
body.base = struct('id', 'fc_3', 'session_id', 'sess_09', 'name', 'fc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.fitcurve = struct('fit_equation', 'gaussian', 'fit_sse', 1.5);

out = did2.convert.migrators_j.fitcurve(body);

verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'fitcurve');
verifyEqual(testCase, out{1}.base.id, 'fc_3');
end

function testVmspikefitFoldsToResidualScore(testCase)
% did-schema #88: as fitcurve -- a model_fit_calculation when the source names
% an operating system, a passthrough when it does not (the NDI template ships
% no app block, so the passthrough is the expected case).
body = struct();
body.document_class = struct('class_name', 'vmspikefit', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = struct('name', {'element_id'}, 'value', {'sub_a'});
body.base = struct('id', 'vf_1', 'session_id', 'sess_09', 'name', 'vf', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.vmspikefit = struct('fit_equation', 'exp2', 'fit_sse', 3.25);
out = did2.convert.migrators_j.vmspikefit(body);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'vmspikefit');
body.app = struct('name', 'vm', 'version', '1', 'os', 'GLNXA64');
out = did2.convert.migrators_j.vmspikefit(body);
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
calc = out{find(strcmp(names, 'model_fit_calculation'), 1)};
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
body.base = struct('id', 'sm_1', 'session_id', 'sess_09', 'name', 'sm', ...
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'simple_calc');
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
body.base = struct('id', 'rr_1', 'session_id', 'sess_09', 'name', 'rr', ...
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
verifyEqual(testCase, did2.unittest.helpers.leafName(out{1}), 'vmneuralresponseresiduals');
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

function testSyncruleMappingEpochnodeToTimeReference(testCase)
% gov part 3: each epochnode_*'s bare epoch_clock + epoch_id are nested under a
% time_reference sub-structure (epoch_bounded_reference shape). 1 -> 1; cost,
% mapping, node metadata and the deps carry through.
%
% #58, and the FIXTURE IS INVERTED WITH THE CODE. It used to declare a
% `syncrule_id` + `epochid` dependency pair and epoch nodes with no `objectname`
% and no `t0_t1` -- our own invented shape, so the test could not see that the
% reshape was dropping the field a live NDI query reads. NDI's template and schema
% both declare `syncgraph_id` + `syncrule_id`, and the real node carries seven
% sub-fields.
body = struct();
body.document_class = struct('class_name', 'syncrule_mapping', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'syncgraph_id', 'value', 'sg_1'), ...
                    struct('name', 'syncrule_id',  'value', 'sr_1') ];
body.base = struct('id', 'sm_1', 'session_id', 'sess_09', 'name', 'sm', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
nodeA = struct('epoch_clock', 'dev_local_time', 'epoch_id', 't00001', ...
    'epoch_session_id', 'sess_09', 'epochprobemap', struct('a', 1), ...
    'objectclass', 'ndi.daq.system.mfdaq', 'objectname', 'vhvis_spike2', ...
    't0_t1', [0 300]);
nodeB = struct('epoch_clock', 'utc', 'epoch_id', 't00002', ...
    'epoch_session_id', 'sess_09', 'epochprobemap', struct(), 'objectclass', '', ...
    'objectname', 'vhintan', 't0_t1', [5 305]);
body.syncrule_mapping = struct('cost', 1.0, 'mapping', [1 0; 0 1], ...
    'epochnode_a', nodeA, 'epochnode_b', nodeB);

% The migrator now returns a CELL of bodies, not a bare struct: the clock
% alignment build gave it a second branch (the clock_alignment +
% relative_reference fold), so its contract is 1 -> N. This branch is still the
% #58 passthrough and still 1 -> 1 -- the fold is GATED on an `epoch` document
% that no migrator mints yet, so every did_v1 document lands here. Only the
% container changed; every assertion below is unchanged, which is the point.
bodies = did2.convert.migrators_j.syncrule_mapping(body);
verifyEqual(testCase, numel(bodies), 1, ...
    'the gated fold must not fire: no epoch_id_# edges on a did_v1 document');
out = bodies{1};
verifyEqual(testCase, out.document_class.schema_version, 'V_eta');
% epoch_clock / epoch_id are no longer bare on the node -- they moved under
% time_reference (epoch_bounded_reference shape)
na = out.syncrule_mapping.epochnode_a;
verifyFalse(testCase, isfield(na, 'epoch_clock'));
verifyFalse(testCase, isfield(na, 'epoch_id'));
verifyEqual(testCase, na.time_reference.kind, 'epoch_bounded_reference');
verifyEqual(testCase, na.time_reference.epoch_clock, 'dev_local_time');
verifyEqual(testCase, na.time_reference.epoch_id, 't00001');
% node metadata retained
verifyEqual(testCase, na.epoch_session_id, 'sess_09');
verifyEqual(testCase, na.objectclass, 'ndi.daq.system.mfdaq');
verifyEqual(testCase, out.syncrule_mapping.epochnode_b.time_reference.epoch_clock, 'utc');
% #58: objectname is READ BY A LIVE NDI QUERY (syncgraph.m:406-407) and t0_t1 went
% out with it in the same reshape. Both must survive.
verifyEqual(testCase, na.objectname, 'vhvis_spike2');
verifyEqual(testCase, na.t0_t1, [0 300]);
verifyEqual(testCase, out.syncrule_mapping.epochnode_b.objectname, 'vhintan');
verifyEqual(testCase, out.syncrule_mapping.epochnode_b.t0_t1, [5 305]);
% cost / mapping / deps preserved -- including the syncgraph_id the query filters on
verifyEqual(testCase, out.syncrule_mapping.cost, 1.0);
verifyEqual(testCase, depValue(out, 'syncrule_id'), 'sr_1');
verifyEqual(testCase, depValue(out, 'syncgraph_id'), 'sg_1');
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
    'name', 'whole_session_ref1', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', 't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

out = runJ(v1);
verifyEmpty(testCase, out.quarantine, 'oneepoch must not quarantine');
verifyEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};

% the class is KEPT -- this is a fold, not a dissolution
verifyEqual(testCase, did2.unittest.helpers.leafName(d), 'oneepoch');
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
    'name', 'whole_session_ref1', 'datestamp', '2024-06-01T12:00:00.000Z');
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
    'name', 'whole_session_ref1', 'datestamp', '2024-06-01T12:00:00.000Z');
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
    'name', 'whole_session_ref1', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 'whole_session_ref1');
v1.element_epoch = struct('epoch_clock', 'utc,dev_local_time', 't0_t1', [0 1; 2 3]);
v1.oneepoch = struct('epoch_ids', 't00001,t00002,t00003');

out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('oneepoch quarantined under validation: %s', ...
        out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, did2.unittest.helpers.leafName(out.migrated{1}), 'oneepoch');
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

function testCalculationWithNoOperatingSystemPassesThrough(testCase)
% did-schema #88's `calculation` requires operating_system_id. A v1 calculator
% document with no `app.os` cannot supply one, and inventing an operating system
% is not allowed, so jCalculation passes the document through UNCHANGED (Jess's
% rule: pass through and list, never invent). This pins that branch.
body = struct();
body.document_class = struct('class_name', 'contrast_tuning', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
body.depends_on = [ struct('name', 'element_id', 'value', 'sub_8'), ...
                    struct('name', 'stimulus_tuningcurve_id', 'value', 'tc_1')];
body.base = struct('id', 'ct_1', 'session_id', 'sess_09', 'name', 'ct', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
body.contrast_tuning = struct( ...
    'tuning_curve', struct('contrast', [0 0.25 0.5 1], 'mean', [2 5 9 12]));
out = did2.convert.migrators_j.contrast_tuning(body);
verifyEqual(testCase, numel(out), 1);
verifyEqual(testCase, out{1}, body);
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
names = cellfun(@(b) did2.unittest.helpers.leafName(b), out, 'UniformOutput', false);
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
    if strcmp(did2.unittest.helpers.leafName(migrated{k}), leaf)
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
