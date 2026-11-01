function tests = testRawV1RoundTripOpenminds
%TESTRAWV1ROUNDTRIPOPENMINDS The openMINDS family read as raw v1, and its round
%   trip: openminds, openminds_subject, openminds_element, openminds_stimulus.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (441530d; tests/+did2/fixtures/ndi_templates, copied verbatim) in
%   the shape ndi.database.fun.openMINDSobj2ndi_document writes:
%     openminds   metadata/openminds.json + base.json: the `openminds` block,
%                 an `openminds_<n>` edge per `ndi://` child in `fields`, or
%                 one empty `openminds` edge for a childless object (JH's
%                 OP50 strain and its species, +haley/doImport.m)
%     openminds_subject   metadata/openminds_subject.json + openminds.json +
%                 base.json, dependency type 'subject': the template's
%                 `subject_id` edge, then the `openminds` edge (JH's sex and
%                 species controlled terms, testWholeBatchRoundTrip's shapes)
%     openminds_element   metadata/openminds_element.json + openminds.json +
%                 base.json, dependency type 'element': the template's
%                 `element_id` edge, then the `openminds` edge (Dab's cell
%                 type, without and with its openMINDS id)
%     openminds_stimulus  metadata/openminds_stimulus.json + epochid.json +
%                 openminds.json + base.json, dependency type 'stimulus'
%                 (+setup/+NDIMaker/stimulusDocMaker.m: a StimulationApproach
%                 term, the epoch, the `stimulus_element_id` edge, then the
%                 `openminds` edge)
%
%   A bare `openminds` document passes through pass 1 unchanged for the batch
%   passes that read it (did2.convert.resolveOpenmindsCitations, NDI's
%   strainAssembly); both read either edge key. It round trips as itself.
%   openminds_subject converts to one term assertion, as before; its
%   `openminds_<n>` edges are read by NDI's subjectStrainAssembly from the v1
%   input, so they do not carry it. openminds_element converts to one term
%   assertion, or is carried with an id or a description (carry-128), as
%   before. openminds_stimulus is carried whole as v1 for NDI's second pass
%   (carry-165, since 2026-11-01). No known findings for the fixtures (a
%   species' definition and synonym are accepted differences, [species text is
%   the openMINDS equivalent]).
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== openminds =======================================

function testOpenmindsIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'openminds')));
out = runRaw(strainPair());
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 2);
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

function testBareOpenmindsPassesThroughAndRoundTrips(testCase)
batch = strainPair();
out = runRaw(batch);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.passthrough), 2, 'both pass through');
for k = 1:numel(batch)
    v1 = batch{k};
    doc = docWithId(out, v1.base.id);
    verifyEqual(testCase, char(doc.document_class.schema_version), 'did_v2', ...
        'a passthrough, not a carry');
    verifyEqual(testCase, doc.openminds, v1.openminds, 'the block, untouched');
    r = did2.convert.roundtrip.check(v1, {doc});
    verifyFalse(testCase, r.carried);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, v1.base.id, {});
end
end

function testTheCitationPassReadsTheRawEdges(testCase)
% referencedIds reads `value` (raw) as it read `document_id` (renamed): the
% strain's child is found through its openminds_1 edge on both paths
batch = strainPair();
raw = runRaw(batch);
old = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta', ...
    'RawV1Classes', {});
[~, repRaw] = did2.convert.resolveOpenmindsCitations(raw, 'Validate', false, 'TargetVersion', 'V_eta');
[~, repOld] = did2.convert.resolveOpenmindsCitations(old, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, repRaw.openminds_documents_seen, repOld.openminds_documents_seen);
verifyEqual(testCase, repRaw.openminds_components_seen, repOld.openminds_components_seen);
end

function testAFieldOutsideTheOpenmindsTemplateCarriesIt(testCase)
b = strainPair();
v1 = b{1};
v1.openminds.schema_iri = 'https://openminds.om-i.org/types/Species';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: openminds.schema_iri');
v1 = did2.unittest.helpers.setDependency(b{1}, 'subject_id', 'subj_1');
verifyCarried(testCase, v1, 'depends_on(subject_id)');
end

% ===================== openminds_subject ===============================

function testOpenmindsSubjectIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'openminds_subject')));
out = runRaw(subjectTerm('41268b6f5c6a3d4e_0e00000000000011', 'BiologicalSex', ...
    'hermaphrodite', 'PATO:0001340', '', ''));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

function testWriterSubjectTermsConvertAndRoundTrip(testCase)
f = subjectFixtures();
for k = 1:size(f, 1)
    [label, v1] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, not carried']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testAChildEdgeDoesNotCarryASubjectTerm(testCase)
% a Strain's children are `openminds_<n>` edges, which NDI's
% subjectStrainAssembly reads from the v1 input: accounted for, not carry-100
v1 = subjectTerm('41268b6f5c6a3d4e_0e00000000000013', 'Strain', 'Escherichia coli OP50', ...
    'NCBITaxon:637912', '', '');
v1.depends_on(2).name = 'openminds_1';
v1.depends_on(2).value = '41268b6f5c6a3d4e_0e00000000000014';
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyFalse(testCase, carried, notes);
verifyFalse(testCase, contains(notes, '[carry-100]'), notes);
end

function testALabMadeStrainWithAnIdConvertsAndRoundTrips(testCase)
% [openMINDS subject leftovers] (Jess Haley, 2026-10-27): "a lab-made strain's
% `openminds_id` goes on the strain entity's `global_identifier` as
% `openminds:<id>`". NDI's second pass writes it there (NDI-matlab a24ee16a,
% #1107), so pass 1 converts the document (it is not carried) and the round trip
% accounts for the id
v1 = labStrain('41268b6f5c6a3d4e_0e00000000000015', 'AVP-Cre', ...
    'https://openminds.om-i.org/instances/strain/5b9a95df');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'a lab-made strain converts, not carried');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_subject, lab-made strain', {});
end

function testAFieldOutsideTheSubjectTemplateCarriesIt(testCase)
f = subjectFixtures();
v1 = f{1, 2};
v1.openminds_subject = struct('note', 'kept');
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: openminds_subject.note');
v1 = did2.unittest.helpers.setDependency(f{1, 2}, 'element_id', 'el_1');
verifyCarried(testCase, v1, 'depends_on(element_id)');
v1 = f{1, 2};
v1.openminds.version = '3.0';
verifyCarried(testCase, v1, 'openminds.version');
end

% ===================== openminds_element ===============================

function testOpenmindsElementIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'openminds_element')));
out = runRaw(elementTerm('41268b6f5c6a3d4e_0e00000000000021', ''));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

function testAWriterElementTermConvertsAndRoundTrips(testCase)
v1 = elementTerm('41268b6f5c6a3d4e_0e00000000000021', '');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted, not carried');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_element', {});
end

function testAnElementTermWithAnIdIsCarriedUntouched(testCase)
v1 = elementTerm('41268b6f5c6a3d4e_0e00000000000022', ...
    'CellType/dc2f5dd6-5cea-477c-a035-ca2dd3e6649d');
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, contains(notes, '[carry-128] '), notes);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'openminds_element (id)', {});
end

function testAFieldOutsideTheElementTemplateCarriesIt(testCase)
v1 = elementTerm('41268b6f5c6a3d4e_0e00000000000023', '');
v1.openminds_element = struct('note', 'kept');
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: openminds_element.note');
v1 = elementTerm('41268b6f5c6a3d4e_0e00000000000023', '');
v1.depends_on(2).name = 'openminds_1';
v1.depends_on(2).value = '41268b6f5c6a3d4e_0e00000000000024';
verifyCarried(testCase, v1, 'depends_on(openminds_1)');
end

% ===================== openminds_stimulus ==============================

function testOpenmindsStimulusIsSwitched(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'openminds_stimulus')));
out = runRaw(approachLabel('41268b6f5c6a3d4e_0e00000000000031'));
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

function testAnApproachLabelIsCarriedForTheSecondPass(testCase)
% INVERTED 2026-11-01. This asserted the document passed through stamped
% did_v2 ("a passthrough, not a carry"), validated against the V_eta
% `openminds_stimulus` tombstone. It is now CARRIED whole as v1 with a note
% (carry-165, [v1 passthroughs accepted]): stamped did_v1, never read against
% V_eta, so the tombstone can be deleted. The epoch must still survive for
% NDI's second pass.
v1 = approachLabel('41268b6f5c6a3d4e_0e00000000000031');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
doc = docWithId(out, v1.base.id);
verifyEqual(testCase, char(doc.document_class.schema_version), 'did_v1', ...
    'carried whole as v1, not a did_v2 passthrough');
verifyEqual(testCase, doc.epochid.epochid, 't00001', 'the epoch survives for the second pass');
verifyCarried(testCase, v1, '[carry-165]');
end

function testTheInventedStimulusEdgeStillQuarantines(testCase)
v1 = approachLabel('41268b6f5c6a3d4e_0e00000000000032');
v1.depends_on(1).name = 'stimulus_id';
out = runRaw(v1);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:openmindsStimulusInventedEdge');
end

function testAFieldOutsideTheStimulusTemplateCarriesIt(testCase)
v1 = approachLabel('41268b6f5c6a3d4e_0e00000000000033');
v1.openminds_stimulus = struct('note', 'kept');
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: openminds_stimulus.note');
v1 = did2.unittest.helpers.setDependency(approachLabel('41268b6f5c6a3d4e_0e00000000000033'), ...
    'element_id', 'el_1');
verifyCarried(testCase, v1, 'depends_on(element_id)');
end

% ===================== the family ======================================

function testTheSwitchChangesNoOutcome(testCase)
f = fixtures();
for k = 1:size(f, 1)
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(f{k, 2});
    verifyEmpty(testCase, problems, sprintf('%s: %s', f{k, 1}, strjoin(problems, '; ')));
end
end

function testValidationIsAsBefore(testCase)
% a raw passthrough validates exactly where the renamed one did
f = fixtures();
for k = 1:size(f, 1)
    raw = did2.convert.v1_to_v2(f{k, 2}, 'Validate', true, 'TargetVersion', 'V_eta');
    old = did2.convert.v1_to_v2(f{k, 2}, 'Validate', true, 'TargetVersion', 'V_eta', ...
        'RawV1Classes', {});
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), f{k, 1});
end
end

% ===================== fixtures, from the TEMPLATES and WRITER ============

function f = fixtures()
% {label, batch}
s = [subjectFixtures(); elementFixtures(); ...
    {'openminds_stimulus, approach label', approachLabel('41268b6f5c6a3d4e_0e00000000000031')}];
f = cell(1 + size(s, 1), 2);
f(1, :) = {'openminds, strain and species', strainPair()};
for k = 1:size(s, 1)
    f(1 + k, :) = {s{k, 1}, s(k, 2)};
end
end

function f = elementFixtures()
f = {'openminds_element, cell type', elementTerm('41268b6f5c6a3d4e_0e00000000000021', ''); ...
    'openminds_element, cell type with an id', elementTerm('41268b6f5c6a3d4e_0e00000000000022', ...
        'CellType/dc2f5dd6-5cea-477c-a035-ca2dd3e6649d')};
end

function f = subjectFixtures()
f = {'openminds_subject, sex', subjectTerm('41268b6f5c6a3d4e_0e00000000000011', ...
        'BiologicalSex', 'hermaphrodite', 'PATO:0001340', '', ''); ...
    'openminds_subject, species', subjectTerm('41268b6f5c6a3d4e_0e00000000000012', ...
        'Species', 'Caenorhabditis elegans', 'NCBITaxon:6239', ...
        'Caenorhabditis elegans is a species of nematode.', 'C. elegans')};
end

function v1 = subjectTerm(id, type, name, node, definition, synonym)
% openMINDSobj2ndi_document(term, sessionId, 'subject', subjectId): the
% template's subject_id edge, then the empty `openminds` edge of a childless term
v1 = termDocument('openminds_subject', id, type, name, node, definition, synonym);
v1 = did2.unittest.helpers.setDependency(v1, 'subject_id', '41268b6f5c6a3d4e_0e000000000000a1');
v1.depends_on(2) = struct('name', 'openminds', 'value', '');
v1 = jsondecode(jsonencode(v1));
end

function v1 = labStrain(id, name, openmindsId)
% openMINDSobj2ndi_document(strain, sessionId, 'subject', subjectId) for a
% Strain with no ontology node (lab-made), its fields in the Strain shape
v1 = did2.unittest.helpers.ndiDocument('openminds_subject', 'Id', id);
flds = struct('alternateIdentifier', '', 'backgroundStrain', [], 'breedingType', [], ...
    'description', '', 'digitalIdentifier', [], 'diseaseModel', [], ...
    'geneticStrainType', [], 'laboratoryCode', '', 'name', name, ...
    'ontologyIdentifier', '', 'phenotype', '', 'species', [], ...
    'stockNumber', [], 'synonym', '');
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Strain', ...
    'matlab_type', 'openminds.core.research.Strain', 'openminds_id', openmindsId, ...
    'fields', flds);
v1 = did2.unittest.helpers.setDependency(v1, 'subject_id', '41268b6f5c6a3d4e_0e000000000000a1');
v1.depends_on(2) = struct('name', 'openminds', 'value', '');
v1 = jsondecode(jsonencode(v1));
end

function v1 = elementTerm(id, openmindsId)
% Dab's cell type (openMINDSobj2ndi_document(term, sessionId, 'element',
% elementId)): the template's element_id edge, then the empty `openminds` edge
v1 = termDocument('openminds_element', id, 'CellType', 'type III BNST neuron', ...
    'EMPTY:0000073', '', '');
v1.openminds.openminds_id = openmindsId;
v1 = did2.unittest.helpers.setDependency(v1, 'element_id', '41268b6f5c6a3d4e_0e000000000000b1');
v1.depends_on(2) = struct('name', 'openminds', 'value', '');
v1 = jsondecode(jsonencode(v1));
end

function v1 = approachLabel(id)
% stimulusDocMaker.m: openMINDSobj2ndi_document(approach, sessionId,
% 'stimulus', stimulatorId, 'epochid.epochid', epochId)
v1 = did2.unittest.helpers.ndiDocument('openminds_stimulus', 'Id', id);
v1.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/StimulationApproach', ...
    'matlab_type', 'openminds.controlledterms.StimulationApproach', 'openminds_id', '', ...
    'fields', struct('definition', '', 'description', 'Assessing spatial frequency tuning', ...
    'interlexIdentifier', '', 'knowledgeSpaceLink', '', ...
    'name', 'Purpose: Assessing spatial frequency tuning', ...
    'preferredOntologyIdentifier', 'NDIC:00000012', 'synonym', ''));
v1.epochid.epochid = 't00001';
v1 = did2.unittest.helpers.setDependency(v1, 'stimulus_element_id', '41268b6f5c6a3d4e_0e000000000000c1');
v1.depends_on(2) = struct('name', 'openminds', 'value', '');
v1 = jsondecode(jsonencode(v1));
end

function v1 = termDocument(cls, id, type, name, node, definition, synonym)
v1 = did2.unittest.helpers.ndiDocument(cls, 'Id', id);
v1.openminds = struct('openminds_type', ['https://openminds.om-i.org/types/' type], ...
    'matlab_type', ['openminds.controlledterms.' type], 'openminds_id', '', ...
    'fields', struct('definition', definition, 'description', '', ...
    'interlexIdentifier', '', 'knowledgeSpaceLink', '', 'name', name, ...
    'preferredOntologyIdentifier', node, 'synonym', synonym));
end

function batch = strainPair()
% +haley/doImport.m: an OP50 Strain whose `species` is a Species child, written
% by openMINDSobj2ndi_document with no dependency type
sp = did2.unittest.helpers.ndiDocument('openminds', 'Id', '41268b6f5c6a3d4e_0e00000000000001');
sp.depends_on = struct('name', 'openminds', 'value', '');
sp.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Species', ...
    'matlab_type', 'openminds.controlledterms.Species', 'openminds_id', '', ...
    'fields', struct('name', 'Escherichia coli', 'preferredOntologyIdentifier', 'NCBITaxon:562', ...
    'definition', '', 'description', '', 'interlexIdentifier', '', ...
    'knowledgeSpaceLink', '', 'synonym', ''));
st = did2.unittest.helpers.ndiDocument('openminds', 'Id', '41268b6f5c6a3d4e_0e00000000000002');
st.depends_on = struct('name', 'openminds_1', 'value', sp.base.id);
f = struct('name', 'Escherichia coli OP50', 'ontologyIdentifier', 'NCBITaxon:637912', ...
    'description', 'OP50 is a strain of E. coli.', 'laboratoryCode', '', 'synonym', '');
f.species = {['ndi://' sp.base.id]};
st.openminds = struct('openminds_type', 'https://openminds.om-i.org/types/Strain', ...
    'matlab_type', 'openminds.core.research.Strain', 'openminds_id', '', 'fields', f);
batch = {jsondecode(jsonencode(sp)), jsondecode(jsonencode(st))};
end

% ===================== helpers =========================================

function out = runRaw(batch)
if ~iscell(batch); batch = {batch}; end
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
end

function s = docWithId(out, id)
s = [];
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(char(b.base.id), id)
        s = b;
        return;
    end
end
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end
