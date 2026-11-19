function tests = testRegionParts
%TESTREGIONPARTS Region parts with computed ids, the merge of their copies,
%   and a side another document gives (VH-Lab/DID-matlab #488).
%
%   Decided by Jess Haley (did-schema did_v2_go_forward_class_audit.md):
%   [site scaffolding not a loss] (2) (2026-10-26): pass 1 writes the final
%   shape directly, the part's id computed from the subject id, region term
%   and side; [duplicate parts merged in DID] and [part re-keyed when its side
%   arrives] (2026-11-17); [region part ids computed] (2026-11-19): (1) copies
%   take the earliest source document's values, a copy that still differs is
%   counted and the first kept; (2) a side given later attaches only when the
%   subject has exactly one no-side part, else it is not attached and counted;
%   (3) the part, its kind assertion, its laterality assertion and its
%   part_of relation take ids from did2.convert.mintId in a context keyed on
%   '<subject id>|<region node, lowercased>|side:<side node>'.
%
%   The fixtures are NDI's writer shape for treatment_drug
%   (+setup/+NDIMaker/treatmentMaker.m create_treatment_drug_doc), as
%   testMigratorsJ's treatmentDrugDoc.

tests = functiontests(localfunctions);
end

function setup(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the computed ids ================================

function testTheIdsAreAFunctionOfTheKeyAlone(testCase)
area = struct('node', 'UBERON:0002436', 'name', 'primary visual cortex');
a = did2.convert.regionPartIds('subj_007', area, []);
verifyEqual(testCase, a.key, 'subj_007|uberon:0002436', ...
    'with no side the key has no side part, as NDI''s partKey');
b = did2.convert.regionPartIds('subj_007', ...
    struct('node', 'uberon:0002436', 'name', 'V1'), []);
verifyEqual(testCase, b, setfield(a, 'local_identifier', b.local_identifier), ...
    'the node is case-folded and the label is not part of the ids'); %#ok<SFLD>
verifyEmpty(testCase, a.laterality, 'no side, no laterality assertion');
verifyTrue(testCase, all(cellfun(@did.ido.isvalid, {a.part, a.kind, a.relation})));
verifyEqual(testCase, numel(unique({a.part, a.kind, a.relation})), 3);
side = struct('node', 'UBERON:0002812', 'name', 'left cerebral hemisphere');
s = did2.convert.regionPartIds('subj_007', area, side);
verifyEqual(testCase, s.key, 'subj_007|uberon:0002436|side:uberon:0002812');
verifyNotEmpty(testCase, s.laterality);
verifyNotEqual(testCase, s.part, a.part, 'one part per side');
% the same inside any migration context: the ids depend on the key alone
d = did2.convert.mintId('-depth');
did2.convert.mintId('-push', 'some_source');
c = did2.convert.regionPartIds('subj_007', area, []);
did2.convert.mintId('-popto', d);
verifyEqual(testCase, c, a);
verifyEqual(testCase, did2.convert.mintId('-depth'), d, 'a context was left open');
other = did2.convert.regionPartIds('subj_008', area, []);
verifyNotEqual(testCase, other.part, a.part, 'another subject, another part');
end

function testTheBodiesAreTheFinalShape(testCase)
area = struct('node', 'UBERON:0002436', 'name', 'primary visual cortex');
side = struct('node', 'UBERON:0002812', 'name', 'left cerebral hemisphere');
[b, ids] = did2.convert.regionPart('subj_007', area, side, ...
    'SessionId', 'sess_09', 'CreationTimestamp', '2024-06-01T12:00:00.000Z');
verifyEqual(testCase, numel(b), 4);
verifyEqual(testCase, b{1}.document_class.class_name, 'entity');
verifyEqual(testCase, b{1}.base.id, ids.part);
verifyEqual(testCase, b{1}.entity.local_identifier, ids.local_identifier);
verifyEqual(testCase, b{2}.base.id, ids.kind);
verifyEqual(testCase, b{2}.statement.variable.node, 'UBERON:0000061');
verifyEqual(testCase, b{2}.term.value.node, 'UBERON:0002436');
verifyEqual(testCase, b{3}.base.id, ids.laterality);
verifyEqual(testCase, b{3}.statement.variable.node, 'NCIT:C25185');
verifyEqual(testCase, b{3}.term.value.node, 'UBERON:0002812');
verifyEqual(testCase, b{4}.base.id, ids.relation);
verifyEqual(testCase, b{4}.document_class.class_name, 'directed_relation');
[b2, ~] = did2.convert.regionPart('subj_007', area, [], 'SessionId', 'sess_09');
verifyEqual(testCase, numel(b2), 3, 'no side: entity, kind, part_of');
end

function testLateralityIsReadFromTheNode(testCase)
[lat, tf] = did2.convert.lateralityOf(struct('node', 'uberon:0002813', 'name', 'x'));
verifyTrue(testCase, tf);
verifyEqual(testCase, lat.side, 'right');
[~, tf] = did2.convert.lateralityOf(struct('node', 'UBERON:0002436', ...
    'name', 'left primary visual cortex'));
verifyFalse(testCase, tf, 'a label is not a side');
[~, tf] = did2.convert.lateralityOf(struct('node', '', 'name', 'left'));
verifyFalse(testCase, tf);
end

% ===================== pass 1 and the merge ============================

function testTwoDocumentsNamingOneRegionWriteOnePart(testCase)
a = drugAt('td_a', '2024-06-02T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
b = drugAt('td_b', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
out = did2.convert.v1_to_v2({a, b}, 'Validate', true, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine);
ids = did2.convert.regionPartIds('subj_007', ...
    struct('node', 'UBERON:0002436', 'name', ''), []);
verifyEqual(testCase, countId(out.migrated, ids.part), 2, 'pass 1 writes a copy per source');
out = did2.convert.resolveRegionParts(out, 'Validate', true, 'TargetVersion', 'did_v2');
r = out.region_part_resolution;
verifyTrue(testCase, r.ran);
verifyEqual(testCase, r.documents_inspected, r.migrated_before);
verifyEqual(testCase, r.parts_seen, 2);
verifyEqual(testCase, r.duplicate_ids, 3, 'the part, its kind assertion, its part_of');
verifyEqual(testCase, r.duplicate_copies_dropped, 3);
verifyEqual(testCase, r.duplicate_copies_differing, 0);
verifyEqual(testCase, r.migrated_after, r.migrated_before - 3);
for id = {ids.part, ids.kind, ids.relation}
    verifyEqual(testCase, countId(out.migrated, id{1}), 1, id{1});
end
% the kept copy is the earliest source's (td_b, a day earlier)
p = byId(out.migrated, ids.part);
verifyEqual(testCase, char(p.get('base.creation_timestamp')), '2024-06-01T12:00:00.000Z');
% both doses are about the one part
verifyEqual(testCase, depVal(byId(out.migrated, 'td_a'), 'entity_id'), ids.part);
verifyEqual(testCase, depVal(byId(out.migrated, 'td_b'), 'entity_id'), ids.part);
% no duplicate id is left anywhere in the batch
allIds = cellfun(@(d) char(d.get('base.id')), out.migrated, 'UniformOutput', false);
verifyEqual(testCase, numel(unique(allIds)), numel(allIds));
% and each source still round trips on the documents its ids name
for v1 = {a, b}
    r1 = roundTripOf(v1{1}, out);
    verifyTrue(testCase, r1.ok, sprintf('%s: lost %s; unplaced %s', v1{1}.base.id, ...
        strjoin({r1.lost.path}, ', '), strjoin(r1.unplaced, '; ')));
end
end

function testTheMergeDoesNotDependOnReadingOrder(testCase)
a = drugAt('td_a', '2024-06-02T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
b = drugAt('td_b', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
o1 = merged({a, b});
o2 = merged({b, a});
verifyEqual(testCase, sortedJson(o1.migrated), sortedJson(o2.migrated));
end

function testACopyThatStillDiffersIsCountedAndTheFirstKept(testCase)
% a node the term registry does not hold, so each label is kept as written
a = drugAt('td_a', '2024-06-01T12:00:00.000Z', 'UBERON:0002421', 'hippocampal formation');
b = drugAt('td_b', '2024-06-03T12:00:00.000Z', 'UBERON:0002421', 'hippocampus');
out = merged({b, a});
r = out.region_part_resolution;
verifyEqual(testCase, r.duplicate_ids, 3);
% the kind assertion's label differs, and so does the part's local identifier,
% which is made from it; the part_of relation does not
verifyEqual(testCase, r.duplicate_copies_differing, 2);
ids = did2.convert.regionPartIds('subj_007', ...
    struct('node', 'UBERON:0002421', 'name', ''), []);
verifyEqual(testCase, sort(r.duplicate_ids_differing), sort({ids.part, ids.kind}));
verifyEqual(testCase, countId(out.migrated, ids.part), 1);
k = byId(out.migrated, ids.kind);
verifyEqual(testCase, char(k.get('base.creation_timestamp')), '2024-06-01T12:00:00.000Z', ...
    'the earliest source''s copy is kept');
end

function testTwoRegionsAreTwoParts(testCase)
a = drugAt('td_a', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
b = drugAt('td_b', '2024-06-01T12:00:00.000Z', 'UBERON:0001880', 'bed nucleus of stria terminalis');
out = merged({a, b});
r = out.region_part_resolution;
verifyEqual(testCase, r.parts_seen, 2);
verifyEqual(testCase, r.duplicate_ids, 0);
verifyNotEqual(testCase, depVal(byId(out.migrated, 'td_a'), 'entity_id'), ...
    depVal(byId(out.migrated, 'td_b'), 'entity_id'));
end

% ===================== a side given later ==============================

function testASideGivenLaterReKeysTheSubjectsOnePart(testCase)
a = drugAt('td_a', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
s = drugAt('td_s', '2024-06-02T12:00:00.000Z', 'UBERON:0002812', 'left cerebral hemisphere');
out = did2.convert.v1_to_v2({a, s}, 'Validate', true, 'TargetVersion', 'did_v2');
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, nSideObservations(out.migrated), 1, ...
    'a side names no region: pass 1 leaves the site observation');
old = did2.convert.regionPartIds('subj_007', struct('node', 'UBERON:0002436', 'name', ''), []);
out = did2.convert.resolveRegionParts(out, 'Validate', true, 'TargetVersion', 'did_v2');
r = out.region_part_resolution;
verifyEqual(testCase, r.side_observations_seen, 1);
verifyEqual(testCase, r.sides_attached, 1);
verifyEqual(testCase, r.parts_rekeyed, 1);
verifyEqual(testCase, r.rekey_quarantined, 0);
% (the labels are the registry's; they make only the local identifier)
nid = did2.convert.regionPartIds('subj_007', ...
    struct('node', 'UBERON:0002436', 'name', 'primary visual cortex'), ...
    struct('node', 'UBERON:0002812', 'name', 'left cerebral hemisphere'));
% the part's id matches its content: (subject, region, side)
for id = {nid.part, nid.kind, nid.laterality, nid.relation}
    verifyEqual(testCase, countId(out.migrated, id{1}), 1, id{1});
end
for id = {old.part, old.kind, old.relation}
    verifyEqual(testCase, countId(out.migrated, id{1}), 0, id{1});
    verifyEqual(testCase, countEdgesNaming(out.migrated, id{1}), 0, ...
        ['an edge still names the old id ' id{1}]);
end
lat = byId(out.migrated, nid.laterality);
verifyEqual(testCase, lat.get('term.value').node, 'UBERON:0002812');
verifyEqual(testCase, depVal(lat, 'entity_id'), nid.part);
verifyEqual(testCase, char(byId(out.migrated, nid.part).get('entity.local_identifier')), ...
    nid.local_identifier);
% both documents' doses are about the sided part; the side observation is gone
verifyEqual(testCase, depVal(byId(out.migrated, 'td_a'), 'entity_id'), nid.part);
verifyEqual(testCase, depVal(byId(out.migrated, 'td_s'), 'entity_id'), nid.part);
verifyEqual(testCase, nSideObservations(out.migrated), 0);
end

function testASideIsNotAttachedWhenTheSubjectHasSeveralParts(testCase)
a = drugAt('td_a', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
b = drugAt('td_b', '2024-06-01T12:00:00.000Z', 'UBERON:0001880', 'bed nucleus of stria terminalis');
s = drugAt('td_s', '2024-06-02T12:00:00.000Z', 'UBERON:0002812', 'left cerebral hemisphere');
out = merged({a, b, s});
r = out.region_part_resolution;
verifyEqual(testCase, r.sides_attached, 0);
verifyEqual(testCase, r.sides_not_attached_several_parts, 1);
verifyEqual(testCase, r.parts_rekeyed, 0);
verifyEqual(testCase, nSideObservations(out.migrated), 1, 'the side observation stays');
verifyEqual(testCase, depVal(byId(out.migrated, 'td_s'), 'entity_id'), 'subj_007');
end

function testASideIsNotAttachedWhenTheSubjectHasNoPart(testCase)
s = drugAt('td_s', '2024-06-02T12:00:00.000Z', 'UBERON:0002812', 'left cerebral hemisphere');
out = merged({s});
r = out.region_part_resolution;
verifyEqual(testCase, r.sides_not_attached_no_part, 1);
verifyEqual(testCase, nSideObservations(out.migrated), 1);
end

function testTwoSidesForOnePartAttachNeither(testCase)
a = drugAt('td_a', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
l = drugAt('td_l', '2024-06-02T12:00:00.000Z', 'UBERON:0002812', 'left cerebral hemisphere');
g = drugAt('td_g', '2024-06-02T12:00:00.000Z', 'UBERON:0002813', 'right cerebral hemisphere');
out = merged({a, l, g});
r = out.region_part_resolution;
verifyEqual(testCase, r.sides_not_attached_several_sides, 2, '[one part per side]');
verifyEqual(testCase, r.parts_rekeyed, 0);
verifyEqual(testCase, nSideObservations(out.migrated), 2);
end

function testAProbesHemisphereIsNotASideDocument(testCase)
% a probe_location's hemisphere (vhlab-contrast-matlab
% sophie_add_treatment_info.m; corpus 20211116) is a site observation about
% the probe with no manipulation: no side of a subject's part, left for NDI's
% pathSPromotion 'located' mode, and counted apart
a = drugAt('td_a', '2024-06-01T12:00:00.000Z', 'UBERON:0002436', 'primary visual cortex');
pl = struct();
pl.document_class = struct('class_name', 'probe_location', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
pl.depends_on = struct('name', {'probe_id'}, 'value', {'probe_42'});
pl.base = struct('id', 'pl_01', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
pl.probe_location = struct('ontology_name', 'UBERON:0002812', 'name', 'left cerebral hemisphere');
out = merged({a, pl});
r = out.region_part_resolution;
verifyEqual(testCase, r.side_observations_seen, 0);
verifyEqual(testCase, r.side_observations_not_co_anchored, 1);
verifyEqual(testCase, r.sides_attached + r.sides_not_attached_no_part, 0);
verifyEqual(testCase, nSideObservations(out.migrated), 1, 'the probe''s location stays');
end

function testAnEmptyBatchReportsItsDenominator(testCase)
out = did2.convert.resolveRegionParts(struct('migrated', {{}}), ...
    'Validate', false, 'TargetVersion', 'did_v2');
verifyTrue(testCase, out.region_part_resolution.ran);
verifyEqual(testCase, out.region_part_resolution.documents_inspected, 0);
end

% ===================== helpers =========================================

function v1 = drugAt(id, datestamp, node, name)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', id, 'session_id', 'sess_09', 'name', '', 'datestamp', datestamp);
v1.treatment_drug = struct('mixture_table', ...
    sprintf('ontologyName,name,value,ontologyUnit,unitName\nNCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg'), ...
    'location_ontologyNode', node, 'location_name', name);
end

function out = merged(bodies)
out = did2.convert.v1_to_v2(bodies, 'Validate', false, 'TargetVersion', 'did_v2');
out = did2.convert.resolveRegionParts(out, 'Validate', false, 'TargetVersion', 'did_v2');
end

function n = countId(docs, id)
n = sum(cellfun(@(d) strcmp(char(d.get('base.id')), id), docs));
end

function d = byId(docs, id)
d = [];
for k = 1:numel(docs)
    if strcmp(char(docs{k}.get('base.id')), id)
        d = docs{k};
        return;
    end
end
end

function v = depVal(doc, name)
v = '';
if isempty(doc); return; end
s = doc.toStruct();
if ~isfield(s, 'depends_on'); return; end
deps = s.depends_on;
if iscell(deps); deps = [deps{:}]; end
for k = 1:numel(deps)
    if strcmp(char(deps(k).name), name)
        if isfield(deps, 'value'); v = char(deps(k).value);
        else; v = char(deps(k).document_id); end
        return;
    end
end
end

function n = countEdgesNaming(docs, id)
n = 0;
for k = 1:numel(docs)
    s = docs{k}.toStruct();
    if ~isfield(s, 'depends_on') || isempty(s.depends_on); continue; end
    deps = s.depends_on;
    if iscell(deps); deps = [deps{:}]; end
    f = 'value';
    if ~isfield(deps, 'value'); f = 'document_id'; end
    for j = 1:numel(deps)
        if strcmp(char(deps(j).(f)), id); n = n + 1; end
    end
end
end

function n = nSideObservations(docs)
n = 0;
for k = 1:numel(docs)
    if strcmp(did2.unittest.helpers.classKey(docs{k}), 'observation+term') ...
            && strcmpi(docs{k}.get('statement.variable').node, 'NCIT:C13717')
        n = n + 1;
    end
end
end

function t = sortedJson(docs)
t = sort(cellfun(@(d) jsonencode(d.toStruct()), docs, 'UniformOutput', false));
end

function r = roundTripOf(v1, out)
row = out.source_outputs(strcmp({out.source_outputs.id}, v1.base.id));
ids = row.output_ids;
mine = {};
for k = 1:numel(out.migrated)
    if any(strcmp(char(out.migrated{k}.get('base.id')), ids))
        mine{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
r = did2.convert.roundtrip.check(v1, mine);
end
