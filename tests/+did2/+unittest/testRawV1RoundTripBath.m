function tests = testRawV1RoundTripBath
%TESTRAWV1ROUNDTRIPBATH stimulus_bath read as raw v1, and its round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [early migration pieces
%   fixed] (1) (one migrator per class: the old +migrators/stimulus_bath.m,
%   never reached, is deleted) and [migration reliability practices] (a) (a
%   round trip per class, did2.convert.roundtrip.check).
%
%   THE v1 DOCUMENTS ARE THE WRITER'S. +setup/+NDIMaker/stimulusDocMaker.m
%   createBathDocs (Dabrowska) and +setup/+conv/+marder/marderbath.m (Marder),
%   NDI-matlab locked `main` 3cb19a8: ndi.document('stimulus_bath',
%   'stimulus_bath', {location {ontologyNode, name}, mixture_table}, 'epochid',
%   epochid) + session.newdocument(), then stimulus_element_id. The
%   mixture_table is ndi.database.fun.writetablechar's text (a header row,
%   names with a comma double-quoted); the tables below are corpus Dab's own
%   (its 1,605 baths hold four shapes: one drug, two drugs, the ACSF, the ACSF
%   with a drug). The location's name is ndi.ontology.lookup's for the node
%   ('Baths, Water, Laboratory' for NCIm:C0179246, as corpus Dab holds it). The
%   templates are copied verbatim to tests/+did2/fixtures/ndi_templates
%   (stimulus_bath, epochid, base, element, subject). The stimulator is an
%   ndi.probe.timeseries.stimulator element of type `stimulator`, as corpus Dab
%   holds it.
%
%   WHAT HAPPENS TO THEM. Pass 1 defers every whole bath
%   (did2:convert:needsSessionContext, as before the switch); the coarse DID
%   pass did2.convert.resolveDeferredBaths assembles it from the quarantined
%   source: the manipulation (the v1 id; value kind formulation; entity the
%   stimulator's subject), its session anchor, the formulation and one chemical
%   per row, and a site observation for an anatomical location. The round trip
%   is of THAT output. Since [one bath shape] (Jess Haley, 2026-10-27) the
%   stimulator is the manipulation's instrument_id (depends_on(1).value comes
%   back), and the epoch is handed on to did2.convert.epochMint, which re-points
%   the anchor at the epoch entity (testTheEpochAnchoredBathRoundTrips: nothing
%   lost but the ACSF rows below). KNOWN FINDINGS of the bath pass's own output,
%   listed exactly:
%     epochid.epochid         the anchor is still on the session until epochMint
%                             re-points it
%     stimulus_bath.mixture_table, for a table with a pH or osm row (the ACSF):
%                             those rows go on the formulation's `ph` /
%                             `osmolarity`, which keep no ontology node
%                             (NCIm:C4048290, NCIm:C0439186) and not where the
%                             row stood
%   Nothing is invented or unplaced.
tests = functiontests(localfunctions);
end

% ===================== the writer's documents round trip ==================

function testWriterBathsRoundTrip(testCase)
% {label, the bath, carried?, known lost paths}
coarse = {'epochid.epochid'};   % until epochMint re-points the anchor
cases = { ...
    'Dab one drug', dabBath(oneDrug()), false, coarse; ...
    'Dab two drugs (a name with commas)', dabBath(twoDrugs()), false, coarse; ...
    'Dab ACSF (pH, carbogen, osm)', dabBath(acsf()), false, [coarse, {'stimulus_bath.mixture_table'}]; ...
    'Dab ACSF with a drug', dabBath(acsfWithDrug()), false, [coarse, {'stimulus_bath.mixture_table'}]; ...
    'Marder anatomical location', marderBath(), false, coarse; ...
    'a location field no resolver reads', withLocationExtra(), true, {}};
for k = 1:size(cases, 1)
    [label, v1, carried, known] = cases{k, :};
    [mine, out] = bathOutputs(v1);
    verifyEmpty(testCase, quarantinedBaths(out), [label ': left quarantined']);
    r = did2.convert.roundtrip.check(v1, mine);
    verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
    verifyEqual(testCase, r.carried, carried, [label ': carried?']);
    verifyEqual(testCase, sort(lostPaths(r)), sort(known), ...
        sprintf('%s: lost %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end
end

function testTheEpochAnchoredBathRoundTrips(testCase)
% [one bath shape] (Jess Haley, 2026-10-27): once did2.convert.epochMint holds
% the bath's epoch, the anchor names it and the bath round trips with its
% stimulator AND its epoch
for c = {{'Dab one drug', dabBath(oneDrug()), {}}, ...
        {'Dab ACSF', dabBath(acsf()), {'stimulus_bath.mixture_table'}}, ...
        {'Marder anatomical location', marderBath(), {}}}
    [label, v1, known] = c{1}{:};
    [mine, out] = bathOutputs(v1);
    ids = cellfun(@(d) char(d.get('base.id')), mine, 'UniformOutput', false);
    e = epochEntity(v1);
    out.migrated{end+1} = did2.document(e);
    out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'V_eta');
    verifyEqual(testCase, out.epoch_mint.bath_anchors_repointed, 1, label);
    docs = {};
    for k = 1:numel(out.migrated)
        if any(strcmp(char(out.migrated{k}.get('base.id')), [ids, {e.base.id}]))
            docs{end+1} = out.migrated{k}; %#ok<AGROW>
        end
    end
    r = did2.convert.roundtrip.check(v1, docs);
    verifyFalse(testCase, r.carried, label);
    verifyEqual(testCase, sort(lostPaths(r)), sort(known), ...
        sprintf('%s: lost %s', label, describeLost(r)));
    verifyTrue(testCase, any(strcmp(r.matched, 'epochid.epochid')), [label ': the epoch']);
    verifyTrue(testCase, any(strcmp(r.matched, 'depends_on(1).value')), [label ': the stimulator']);
    verifyEmpty(testCase, r.invented, label);
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end
end

function e = epochEntity(v1)
% the epoch epochMint holds for (session, the bath's epoch string)
epochType = did2.convert.registeredTerm( ...
    did2.build.vocabulary('entity_type', 'epoch'), 'recording epoch');
e = did2.build.document('entity', ...
    struct('type', epochType, 'local_identifier', v1.epochid.epochid), ...
    'Id', 'aabb1122ccdd3344_e000000000000ba1', 'SessionId', v1.base.session_id, ...
    'CreationTimestamp', v1.base.datestamp, 'Validate', false);
end

function testEveryWriterFieldIsAccountedFor(testCase)
% the denominator is the writer's document: every leaf is matched, restated,
% equivalent, not set, exempt or one of the known findings, and the ones the
% bath is built from by name
v1 = dabBath(oneDrug());
r = did2.convert.roundtrip.check(v1, bathOutputs(v1));
accounted = [r.matched, r.restated, r.equivalent, r.not_set, r.exempt, lostPaths(r)];
verifyEqual(testCase, numel(accounted), r.fields_inspected);
for p = {'base.id', 'base.session_id', 'base.datestamp', 'depends_on(1).name', ...
        'stimulus_bath.mixture_table', 'document_class.class_name'}
    verifyTrue(testCase, any(strcmp(p{1}, [r.matched, r.equivalent])), ...
        sprintf('%s is not accounted for', p{1}));
end
for p = {'stimulus_bath.location.ontologyNode', 'stimulus_bath.location.name'}
    verifyTrue(testCase, any(strcmp(p{1}, r.restated)), ...
        sprintf('%s is not restated as the generic bath', p{1}));
end
v1 = marderBath();
r = did2.convert.roundtrip.check(v1, bathOutputs(v1));
for p = {'stimulus_bath.location.ontologyNode', 'stimulus_bath.location.name'}
    verifyTrue(testCase, any(strcmp(p{1}, [r.matched, r.equivalent])), ...
        sprintf('%s is not read from the site observation', p{1}));
end
end

% ===================== the switch ======================================

function testTheSwitchListsTheBath(testCase)
names = did2.convert.rawV1Classes();
verifyTrue(testCase, any(strcmp(names, 'stimulus_bath')));
verifyEqual(testCase, did2.convert.rawV1Classes('stimulus_bath'), 'stimulus_bath');
verifyEmpty(testCase, which('did2.convert.migrators.stimulus_bath'), ...
    '+migrators/stimulus_bath.m is back');
end

function testAWholeBathStillDefers(testCase)
% pass 1 alone: the raw bath is quarantined with the deferral, as before, and
% its quarantined source is the untouched v1 document both resolvers read
v1 = dabBath(oneDrug());
out = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).class_name, 'stimulus_bath');
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:needsSessionContext');
verifyTrue(testCase, isequaln(jsondecode(out.quarantine(1).original_body), v1));
end

function testTheSwitchChangesNoBath(testCase)
% "keep behaviour identical": the raw and the universalRenames path defer the
% same bath and the coarse pass assembles the same documents from it
for v1 = {dabBath(oneDrug()), dabBath(acsfWithDrug()), marderBath()}
    batch = [fixtureBatch(), v1];
    raw = resolved(did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta'));
    old = resolved(did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta', ...
        'RawV1Classes', {}));
    label = v1{1}.base.id;
    verifyEqual(testCase, raw.deferred_bath_resolution.baths_resolved, 1, label);
    verifyEqual(testCase, old.deferred_bath_resolution.baths_resolved, 1, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        verifyTrue(testCase, isequaln(raw.migrated{j}.toStruct(), old.migrated{j}.toStruct()), ...
            sprintf('%s, document %d differs between the raw and the renamed path', label, j));
    end
end
end

% ===================== every field accounted for =========================

function testAFieldNoResolverReadsCarriesTheBath(testCase)
v1 = withLocationExtra();
verifyCarriedFor(testCase, v1, 'unplaced: stimulus_bath.location.side');
v1 = dabBath(oneDrug());
v1.stimulus_bath.temperature = 32;
verifyCarriedFor(testCase, v1, 'unplaced: stimulus_bath.temperature');
v1 = dabBath(oneDrug());
v1.epochid.epoch_clock = 'dev_local_time';
verifyCarriedFor(testCase, v1, 'unplaced: epochid.epoch_clock');
v1 = dabBath(oneDrug());
v1.depends_on(end + 1) = struct('name', 'subject_id', 'value', 'subj_1');
verifyCarriedFor(testCase, v1, 'unplaced: depends_on(subject_id)');
v1 = dabBath(oneDrug());
v1.stimulus_bath.mixture_table = struct('ontologyName', 'NCIm:C1098706', 'value', 2e-7);
verifyCarriedFor(testCase, v1, 'unplaced: stimulus_bath.mixture_table (not text)');
v1 = dabBath(oneDrug());
v1.ndi_document = struct('id', 'x', 'type', 'stimulus_bath');
verifyCarriedFor(testCase, v1, '[carry-049] universalRenames would discard: ndi_document');
end

% ===================== a check that cannot fail proves nothing ===========

function testABrokenAssemblyIsReportedLost(testCase)
% a concentration changed
v1 = dabBath(oneDrug());
docs = structs(bathOutputs(v1));
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'formulation')
        ing = docs{k}.formulation.value.ingredients;
        if iscell(ing)
            ing{1}.concentration.source_value = 1e-6;
        else
            ing(1).concentration.source_value = 1e-6;
        end
        docs{k}.formulation.value.ingredients = ing;
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp(lostPaths(r), 'stimulus_bath.mixture_table')));

% a chemical dropped: the formulation names a document that was not emitted
v1 = dabBath(twoDrugs());
docs = structs(bathOutputs(v1));
keep = true(1, numel(docs));
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'chemical')
        keep(k) = false;
        break;
    end
end
r = did2.convert.roundtrip.check(v1, docs(keep));
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);

% the site observation dropped: the anatomical location is reported lost
v1 = marderBath();
docs = structs(bathOutputs(v1));
keep = ~cellfun(@(d) strcmp(d.document_class.class_name, 'observation'), docs);
r = did2.convert.roundtrip.check(v1, docs(keep));
verifyTrue(testCase, any(strcmp(lostPaths(r), 'stimulus_bath.location.ontologyNode')));
end

function testADifferentSourceIsReportedLost(testCase)
v1 = dabBath(oneDrug());
mine = bathOutputs(v1);
v1.base.datestamp = '2025-01-01T00:00:00.000Z';
v1.stimulus_bath.location.name = 'water bath';
r = did2.convert.roundtrip.check(v1, mine);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, sort(lostPaths(r)), sort({'base.datestamp', ...
    'epochid.epochid', 'stimulus_bath.location.name'}));
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = dabBath(oneDrug());
mine = bathOutputs(v1);
other = bathOutputs(marderBath());
isForm = cellfun(@(d) strcmp(char(d.get('document_class.class_name')), 'formulation'), other);
r = did2.convert.roundtrip.check(v1, [mine, other(find(isForm, 1))]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== helpers =========================================

function [mine, out] = bathOutputs(v1)
% pass 1 on the stimulator, its subject and the bath, then the coarse pass;
% the bath's documents are the ones that pass appended, or its carry
batch = [fixtureBatch(), {v1}];
first = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
out = resolved(first);
n = numel(first.migrated);
mine = out.migrated(n + 1:end);
if isempty(mine)
    for k = 1:numel(out.migrated)
        if strcmp(char(out.migrated{k}.get('base.id')), v1.base.id)
            mine = out.migrated(k);
        end
    end
end
end

function out = resolved(out)
out = did2.convert.resolveDeferredBaths(out, 'Validate', false, 'TargetVersion', 'V_eta');
end

function q = quarantinedBaths(out)
q = {};
for k = 1:numel(out.quarantine)
    if strcmp(out.quarantine(k).class_name, 'stimulus_bath')
        q{end+1} = out.quarantine(k).reason; %#ok<AGROW>
    end
end
end

function verifyCarriedFor(testCase, v1, part)
out = did2.convert.v1_to_v2([fixtureBatch(), {v1}], 'Validate', false, 'TargetVersion', 'V_eta');
label = sprintf('stimulus_bath (%s)', part);
verifyEmpty(testCase, quarantinedBaths(out), [label ': deferred, not carried']);
hit = [];
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), v1.base.id)
        hit = out.migrated{k}.toStruct();
    end
end
assertNotEmpty(testCase, hit, [label ': not emitted']);
verifyEqual(testCase, hit.document_class.schema_version, 'did_v1', label);
hit.document_class = rmfield(hit.document_class, 'schema_version');
verifyTrue(testCase, isequaln(hit, v1), [label ': not the untouched v1 source']);
n = out.summary.migration_notes.carried_as_v1;
ix = find(strcmp(n.ids, v1.base.id), 1);
assertNotEmpty(testCase, ix, [label ': no carried_as_v1 note']);
verifyTrue(testCase, contains(n.details{ix}, part), ...
    sprintf('%s: the note does not name it: %s', label, n.details{ix}));
end

function p = lostPaths(r)
p = {};
if ~isempty(r.lost)
    p = {r.lost.path};
end
end

function s = describeLost(r)
s = strjoin(lostPaths(r), '; ');
end

function c = structs(docs)
c = cellfun(@(d) d.toStruct(), docs, 'UniformOutput', false);
end

function b = fixtureBatch()
% the stimulator element (as corpus Dab holds it: an ndi.probe on its
% subject, no underlying element) and its subject
b = {subjectDoc(), stimulatorDoc()};
end

function v1 = subjectDoc()
tpl = loadTemplate('subject');
v1 = withBase(tpl, 'subj_1', '');
v1.subject = tpl.subject;
v1.subject.local_identifier = 'rat_17@dabrowska.lab';
v1 = jsondecode(jsonencode(v1));
end

function v1 = stimulatorDoc()
tpl = loadTemplate('element');
v1 = withBase(tpl, 'stim_1', '');
v1.depends_on = tpl.depends_on;
v1.depends_on(strcmp({v1.depends_on.name}, 'underlying_element_id')).value = [];
v1.depends_on(strcmp({v1.depends_on.name}, 'subject_id')).value = 'subj_1';
v1.element = tpl.element;
v1.element.ndi_element_class = 'ndi.probe.timeseries.stimulator';
v1.element.name = 'bath_230831_BNSTIII_b';
v1.element.reference = 1;
v1.element.type = 'stimulator';
v1.element.direct = true;
v1 = jsondecode(jsonencode(v1));
end

function v1 = bathDoc(id, location, mixtureTable)
% stimulusDocMaker.createBathDocs / marderbath: the template's block filled,
% the epochid block, session.newdocument()'s base, stimulus_element_id
tpl = loadTemplate('stimulus_bath');
v1 = withBase(tpl, id, '');
v1.depends_on = tpl.depends_on;
v1.depends_on(1).value = 'stim_1';
v1.epochid = struct('epochid', 'epoch_4126945aee4e93b1_40d01af895f1e3f6');
v1.stimulus_bath = struct('location', location, 'mixture_table', mixtureTable);
v1 = jsondecode(jsonencode(v1));
end

function v1 = dabBath(mixtureTable)
v1 = bathDoc('bath_dab_1', struct('ontologyNode', 'NCIm:C0179246', ...
    'name', 'Baths, Water, Laboratory'), mixtureTable);
end

function v1 = marderBath()
% marderbath: an anatomical bath target ("lower", UBERON:8910010) named by
% ndi.database.fun.uberon_ontology_lookup (the label here stands for it), and
% a marder_mixtures.json saline
v1 = bathDoc('bath_marder_1', struct('ontologyNode', 'UBERON:8910010', ...
    'name', 'lower bath compartment'), ...
    ['ontologyName,name,value,ontologyUnit,unitName' newline ...
     'NCIm:C0037494,"sodium chloride",0.44,OM:MolarVolumeUnit,Molar' newline ...
     'NCIm:C0032825,"potassium chloride",0.011,OM:MolarVolumeUnit,Molar' newline]);
end

function v1 = withLocationExtra()
v1 = dabBath(oneDrug());
v1.stimulus_bath.location.side = 'left';
end

function t = oneDrug()
t = ['ontologyName,name,value,ontologyUnit,unitName' newline ...
    'NCIm:C1098706,arginine-vasopressin,2e-07,OM:MolarVolumeUnit,Molar' newline];
end

function t = twoDrugs()
t = ['ontologyName,name,value,ontologyUnit,unitName' newline ...
    'NCIm:C0078080,"d(CH2)5(1),Tyr(Me)(2),Arg(8)]-vasopressin",1e-06,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C1098706,"arginine-vasopressin",2e-07,OM:MolarVolumeUnit,Molar' newline];
end

function t = acsf()
t = ['ontologyName,name,value,ontologyUnit,unitName' newline ...
    'NCIm:C0037494,"sodium chloride",0.1225,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C0032825,"potassium chloride",0.0035,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C0074722,"sodium bicarbonate",0.025,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C1165377,"sodium phosphate, monobasic, anhydrous",0.001,OM:MolarVolumeUnit,Molar' newline ...
    'CHEBI:86158,"calcium chloride dihydrate",0.0025,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C0017725,"D-glucose",0.02,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C0724622,"magnesium chloride hexahydrate",0.001,OM:MolarVolumeUnit,Molar' newline ...
    'NCIm:C4048290,"pH",7.4,OM:Acidity,pH' newline ...
    'NCIm:CL1445492,"carbogen",1,NCIm:C0522534,saturation' newline ...
    'NCIm:C0439186,"osm",0.29,NCIm:C0439186,osm' newline];
end

function t = acsfWithDrug()
t = [acsf() 'NCIm:,"d(CH2)5(1), D-Tyr(2), Thr(4), Orn(8), des-Gly-NH2(9)]-Vasotocin trifluoroacetate salt",4e-07,OM:MolarVolumeUnit,Molar' newline];
end

function v1 = withBase(tpl, id, name)
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '4126945ae90c6c73_40de7029ad63f253';
v1.base.name = name;
v1.base.datestamp = '2025-09-25T18:22:09.689Z';
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
