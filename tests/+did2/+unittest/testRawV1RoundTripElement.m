function tests = testRawV1RoundTripElement
%TESTRAWV1ROUNDTRIPELEMENT The v1 `element` read as raw v1, and its round trip.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a); and for what an element becomes:
%     [element local identifier is name and reference]  '<name> | <reference>'
%                                       (did2.convert.elementLocalIdentifier,
%                                       the mirror of NDI-matlab's
%                                       ndi.vintage.elementLocalIdentifier on
%                                       claude/phase3 471cd5c66)
%     [element types have no default], [electrode spellings and imaging types
%     are devices], [event lines and environment probes are devices]
%                                       a device only on an ndi.probe.* class;
%                                       anything else carried (carry-063)
%     [sorted units are cells or groups], [unlabelled units need a map]
%                                       single -> cell, multi -> Group, no label
%                                       carried (carry-062)
%     [migrator writes the registry spelling]  entity type `Group`, as the
%                                       registry names it
%     [element type is a device kind term], [n-trode is a multielectrode
%     array], [five probe kinds from NCIT], [ecg and eeg are recorders],
%     [imaging probes are microscopes or carried]
%                                       a device kind as an Equipment Type
%                                       assertion; wide-field / brightfield
%                                       imaging carried (carry-121)
%     [unit direct and subject rebuild from the probe]
%                                       a unit on its probe writes neither;
%                                       rebuilt from the probe, or carried
%                                       (carry-120) when they differ
%
%   THE v1 DOCUMENTS are built from NDI's element.json template at the locked
%   NDI-matlab `main` (3cb19a8; tests/+did2/fixtures/ndi_templates) as
%   ndi.element/newdocument writes them (every template field set; `reference`
%   a number; `direct` a logical; underlying_element_id then subject_id, and
%   any other dependency after them), shaped on the corpus census in did-schema
%   docs/v2_working/ELEMENT_TYPES_DRAFT.md (Soph / Dab probes and units, JH
%   position tracks), and pass through jsonencode/jsondecode. A sorted unit's
%   label comes from a neuron_extracellular document in the same batch.
%
%   WHAT V2 DOES NOT KEEP is listed per fixture as KNOWN FINDINGS (open
%   questions, no rule made here); each fixture's lost paths must be exactly
%   its listed findings.
tests = functiontests(localfunctions);
end

% ===================== the known findings ===============================

function f = knownFindings()
% [unit direct and subject rebuild from the probe] (Jess Haley, 2026-10-27):
% a unit whose probe is in the batch rebuilds both, so it has no finding. A
% unit whose probe is NOT in the batch is converted as before (no decision
% says otherwise; reported in the PR): its `direct` is still checked (0) and
% rebuilt, but its subject_id cannot be read from a probe the batch lacks.
f = { ...
    'unit, probe not in the batch', 'depends_on(2).value', ['its subject_id is ' ...
        'its probe''s, and the probe is not in the batch to read it from']};
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

% ===================== converted writer shapes ==========================

function testConvertedElementsRoundTrip(testCase)
units = {neuronDoc('ne_1', 'el_unit_s', 'single'), neuronDoc('ne_2', 'el_unit_m', 'multi'), ...
    neuronDoc('ne_5', 'el_unit_x', 'single'), unitProbe()};
cases = { ...
    'n-trode probe', probeDoc('el_probe', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'stimulator probe', probeDoc('el_stim', 'vhvis_spike2', 1, 'stimulator', 'ndi.probe.timeseries.stimulator'), 'device'; ...
    'patch-I probe', probeDoc('el_patch', 'patch1', 1, 'patch-I', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'spelled electrode probe', probeDoc('el_e4', 'tet', 1, 'extracellular_electrode-4', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'event line probe', probeDoc('el_ev', 'vhtaste_sync', 1, 'event', 'ndi.probe.timeseries.stimulator'), 'device'; ...
    'single unit', unitDoc('el_unit_s', 'leftcortex_17', 1), 'cell'; ...
    'multi unit', unitDoc('el_unit_m', 'leftcortex_18', 1), 'group'; ...
    'unit, probe not in the batch', unitDoc('el_unit_x', 'leftcortex_22', 1, 'el_absent'), 'cell'; ...
    'accelerometer probe', probeDoc('el_acc', 'acc', 1, 'accelerometer', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'ecg probe', probeDoc('el_ecg', 'ecg', 1, 'ecg', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'eeg probe', probeDoc('el_eeg', 'eeg', 1, 'eeg', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'two-photon probe', probeDoc('el_2p', 'tp', 1, 'two-photon-imaging', 'ndi.probe.image'), 'device'};
for k = 1:size(cases, 1)
    [label, v1, entityType] = cases{k, :};
    out = runRaw([{v1}, units]);
    docs = elementOutputs(out, v1.base.id);
    verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, v1.base.id))), 0, ...
        [label ': carried']);
    ent = docs{1};
    verifyEqual(testCase, did2.unittest.helpers.classKey(ent), entityType, label);
    r = did2.convert.roundtrip.check(v1, docs);
    verifyFalse(testCase, r.carried, label);
    verifyGreaterThan(testCase, r.fields_inspected, 0);
    verifyEqual(testCase, reshape(sort({r.lost.path}), 1, []), findingsFor(label), ...
        sprintf('%s: lost paths are not the listed findings; lost: %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end
end

function testTheLocalIdentifierIsNameBarReference(testCase)
v1 = probeDoc('el_probe', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq');
out = runRaw(v1);
ent = out.migrated{1};
verifyEqual(testCase, ent.get('entity.local_identifier'), 'leftcortex | 2');
[n, r] = did2.convert.elementNameReference('leftcortex | 2');
verifyEqual(testCase, n, 'leftcortex');
verifyEqual(testCase, r, 2);
% a name holding ' | ' itself still reads back: the split is at the LAST one
v1 = probeDoc('el_probe2', 'a | b', 3, 'n-trode', 'ndi.probe.timeseries.mfdaq');
r2 = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyEmpty(testCase, r2.lost, describeLost(r2));
end

function testABaseNameIsTheEntityName(testCase)
% [v1 name is the entity name] (Jess Haley, 2026-10-27): a non-empty v1
% base.name is entity.name, and is rebuilt from it; '' (what
% ndi.element/newdocument writes) writes nothing
v1 = probeDoc('el_named', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq');
v1.base.name = 'left cortex probe';
out = runRaw(v1);
docs = elementOutputs(out, v1.base.id);
verifyEqual(testCase, char(out.migrated{1}.get('entity.name')), 'left cortex probe');
r = did2.convert.roundtrip.check(v1, docs);
verifyEmpty(testCase, r.lost, describeLost(r));
verifyEmpty(testCase, r.invented, strjoin(r.invented, ', '));
verifyTrue(testCase, any(strcmp('base.name', r.matched)));
v0 = probeDoc('el_unnamed', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq');
e0 = runRaw(v0).migrated{1}.toStruct();
verifyFalse(testCase, isfield(e0.entity, 'name'), 'an empty base.name wrote entity.name');
% and the named device validates
outV = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
reasons = '';
for k = 1:numel(outV.quarantine)
    reasons = [reasons sprintf('%s: %s; ', outV.quarantine(k).class_name, ...
        outV.quarantine(k).reason)]; %#ok<AGROW>
end
verifyEmpty(testCase, outV.quarantine, reasons);
end

function testADecidedDeviceKindIsAnEquipmentTypeAssertion(testCase)
% [element type is a device kind term] and the decisions naming each kind
% (Jess Haley, 2026-10-27): one Equipment Type (NCIT:C178920) assertion with
% the decided term; a type with no registered kind writes none ((iii): it
% keeps today's assertion only). The `element type` and `ndi element class`
% assertions are still written (NDI-matlab reads them; PR body).
cases = { ...
    'n-trode', 'ndi.probe.timeseries.mfdaq', 'wikidata:Q1952355'; ...
    'accelerometer', 'ndi.probe.timeseries.mfdaq', 'NCIT:C88166'; ...
    'thermometer', 'ndi.probe.timeseries.mfdaq', 'NCIT:C50059'; ...
    'ppg', 'ndi.probe.timeseries.mfdaq', 'NCIT:C224112'; ...
    'optogenetic-fiber', 'ndi.probe.timeseries.stimulator', 'NCIT:C50358'; ...
    'intraoral-cannula', 'ndi.probe.timeseries.stimulator', 'NCIT:C50343'; ...
    'ecg', 'ndi.probe.timeseries.mfdaq', 'OBI:0003806'; ...
    'eeg', 'ndi.probe.timeseries.mfdaq', 'wikidata:Q4531135'; ...
    'one-photon-imaging', 'ndi.probe.image', 'OBI:0400169'; ...
    'two-photon-imaging', 'ndi.probe.image', 'OBI:0400169'; ...
    'patch-Vm', 'ndi.probe.timeseries.mfdaq', ''; ...
    'sharp-Im', 'ndi.probe.timeseries.mfdaq', ''; ...
    'stimulator', 'ndi.probe.timeseries.stimulator', ''; ...
    'lick-spout', 'ndi.probe.timeseries.mfdaq', ''; ...
    'reward-well', 'ndi.probe.timeseries.mfdaq', ''; ...
    'event', 'ndi.probe.timeseries.stimulator', ''; ...
    'electrode-4', 'ndi.probe.timeseries.mfdaq', ''};
for k = 1:size(cases, 1)
    [ty, cls, node] = cases{k, :};
    id = sprintf('el_kind_%d', k);
    out = runRaw(probeDoc(id, 'p', 1, ty, cls));
    kinds = assertionsAbout(out, id, 'Equipment Type');
    vars = cellfun(@(b) char(b.statement.variable.name), assertionsAbout(out, id, ''), ...
        'UniformOutput', false);
    verifyTrue(testCase, any(strcmp(vars, 'element type')), [ty ': element type assertion']);
    verifyTrue(testCase, any(strcmp(vars, 'ndi element class')), [ty ': ndi element class assertion']);
    if isempty(node)
        verifyEmpty(testCase, kinds, [ty ': a kind with no registered term was written']);
    else
        verifyNumElements(testCase, kinds, 1, ty);
        verifyEqual(testCase, char(kinds{1}.statement.variable.node), 'NCIT:C178920', ty);
        verifyEqual(testCase, char(kinds{1}.term.value.node), node, ty);
    end
end
end

function testGroupIsWrittenAsTheRegistryNamesIt(testCase)
% [migrator writes the registry spelling] (Jess Haley, 2026-10-26): `Group`,
% NCIT:C43359, not `group`
out = runRaw({unitDoc('el_unit_m', 'leftcortex_18', 1), neuronDoc('ne_2', 'el_unit_m', 'multi'), unitProbe()});
ent = elementOutputs(out, 'el_unit_m');
verifyEqual(testCase, char(ent{1}.entity.type.name), 'Group');
verifyEqual(testCase, char(ent{1}.entity.type.node), 'NCIT:C43359');
end

function testAUnitThatDisagreesWithItsProbeIsCarried(testCase)
% [unit direct and subject rebuild from the probe] (Jess Haley, 2026-10-27):
% a unit whose `direct` is not 0, or whose subject is not its probe's, is
% carried whole as v1, malformed (carry-120)
bad = unitDoc('el_unit_d', 'leftcortex_23', 1);
bad.element.direct = true;
other = unitDoc('el_unit_o', 'leftcortex_24', 1);
other.depends_on(strcmp({other.depends_on.name}, 'subject_id')).value = 'subj_2';
cases = {'direct 1', bad; 'another subject', other};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw({v1, neuronDoc(['ne_' v1.base.id], v1.base.id, 'single'), unitProbe()});
    verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, v1.base.id))), 1, ...
        [label ': not carried']);
    d = carryNoteFor(out, v1.base.id);
    verifyTrue(testCase, startsWith(d, '[carry-120] malformed: '), sprintf('%s: %s', label, d));
    r = did2.convert.roundtrip.check(v1, elementOutputs(out, v1.base.id));
    verifyTrue(testCase, r.carried, label);
    verifyTrue(testCase, r.ok, sprintf('%s: %s', label, describeLost(r)));
end
end

% ===================== carried writer shapes ============================

function testCarriedElementsCiteTheirRows(testCase)
cases = { ...
    'unlabelled unit', unitDoc('el_unit_u', 'leftcortex_19', 1), {}, '[carry-062] '; ...
    'conflicting labels', unitDoc('el_unit_c', 'leftcortex_20', 1), ...
        {neuronDoc('ne_3', 'el_unit_c', 'single'), neuronDoc('ne_4', 'el_unit_c', 'multi')}, '[carry-062] '; ...
    'JH position track', jhTrack('el_pos', 'worm1_head_position', 'position'), {}, '[carry-063] '; ...
    'JH distance track', jhTrack('el_dist', 'worm1_head_distance', 'distance'), {}, '[carry-063] '; ...
    'downsampled copy of a probe', derivedCopy('el_ds'), {}, '[carry-063] '; ...
    'probe type on no probe class', probeDoc('el_np', 'x', 1, 'n-trode', 'ndi.element.timeseries'), {}, '[carry-063] '; ...
    'unlisted type', probeDoc('el_ul', 'x', 1, 'sharp-I', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-063] '; ...
    'wide-field imaging probe', probeDoc('el_wf', 'cam', 1, 'wide-field-imaging', 'ndi.probe.image'), {}, '[carry-121] '; ...
    'brightfield imaging probe', probeDoc('el_bf', 'cam', 1, 'brightfield-imaging', 'ndi.probe.image'), {}, '[carry-121] '; ...
    'name reads as a pair', probeDoc('el_pair', 'leftcortex | 2', [], 'n-trode', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-055] '; ...
    'non-integer reference', probeDoc('el_frac', 'leftcortex', 1.5, 'n-trode', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-055] '; ...
    'no name, no reference', probeDoc('el_none', '', [], 'n-trode', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-048] '};
for k = 1:size(cases, 1)
    [label, v1, others, row] = cases{k, :};
    out = runRaw([{v1}, others]);
    docs = elementOutputs(out, v1.base.id);
    verifyEqual(testCase, numel(docs), 1, [label ': one document, the v1 source']);
    verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, v1.base.id))), 1, ...
        [label ': not recorded as carried']);
    d = carryNoteFor(out, v1.base.id);
    verifyTrue(testCase, startsWith(d, row), sprintf('%s: %s', label, d));
    r = did2.convert.roundtrip.check(v1, docs);
    verifyTrue(testCase, r.carried, label);
    verifyTrue(testCase, r.ok, sprintf('%s: %s', label, describeLost(r)));
end
end

function testABatchLabelCanBeGivenByTheCaller(testCase)
% 'UnitQualityLabels': a unit whose neuron_extracellular is not in the batch
v1 = unitDoc('el_unit_g', 'leftcortex_21', 1);
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', ...
    'UnitQualityLabels', {'el_unit_g', 'multi'});
verifyEqual(testCase, did2.unittest.helpers.classKey(out.migrated{1}), 'group');
end

function testKilosortAndPhyLabelsMap(testCase)
% [sorter labels map] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): a sorted unit whose only label is a
% Kilosort/phy label maps -- `good` to a single unit (cell), `mua` to a
% multi-unit (group); a `noise` unit is carried whole as v1, needs_mapping.
% NDI-matlab main +kilosort/probe.m writes the label as the curator typed it
% (matched case-insensitively), so 'Good' and 'MUA' map too.
cases = {'good', 'cell'; 'Good', 'cell'; 'mua', 'group'; 'MUA', 'group'};
for k = 1:size(cases, 1)
    id = sprintf('el_ks_%d', k);
    v1 = unitDoc(id, sprintf('leftcortex_%d', 30 + k), 1);
    out = runRaw({v1, neuronDoc(sprintf('ne_ks_%d', k), id, cases{k, 1})});
    docs = elementOutputs(out, id);
    verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, id))), 0, ...
        [cases{k, 1} ': carried']);
    verifyEqual(testCase, did2.unittest.helpers.classKey(docs{1}), cases{k, 2}, cases{k, 1});
end
v1 = unitDoc('el_ks_noise', 'leftcortex_39', 1);
out = runRaw({v1, neuronDoc('ne_ks_noise', 'el_ks_noise', 'noise')});
docs = elementOutputs(out, 'el_ks_noise');
verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, 'el_ks_noise'))), 1, ...
    'a noise unit is carried');
d = carryNoteFor(out, 'el_ks_noise');
verifyTrue(testCase, startsWith(d, '[carry-062] needs_mapping: '), d);
verifyTrue(testCase, contains(d, 'noise'), d);
r = did2.convert.roundtrip.check(v1, docs);
verifyTrue(testCase, r.carried);
verifyTrue(testCase, r.ok, describeLost(r));
end

% ===================== the switch changes nothing else ==================

function testBothPathsConvertAnElementAlike(testCase)
% the migrator is the same on the raw and the universalRenames path; the
% inputs differ only in spelling it reads both ways
fixtures = {probeDoc('el_probe', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq'), ...
    unitDoc('el_unit_s', 'leftcortex_17', 1), jhTrack('el_pos', 'worm1_head_position', 'position')};
for k = 1:numel(fixtures)
    v1 = fixtures{k};
    raw = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', ...
        'UnitQualityLabels', {'el_unit_s', 'single'});
    old = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', ...
        'UnitQualityLabels', {'el_unit_s', 'single'}, 'RawV1Classes', {});
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), v1.base.id);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), v1.base.id);
    if ~isempty(raw.passthrough); continue; end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        a = raw.migrated{j}.toStruct();
        b = old.migrated{j}.toStruct();
        verifyTrue(testCase, isequaln(a, b), sprintf('%s document %d: raw %s; renamed %s', ...
            v1.base.id, j, jsonencode(a), jsonencode(b)));
    end
end
end

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function docs = elementOutputs(out, elementId)
% the documents migrators_j.element emitted for ELEMENTID: its entity (or its
% carry), the assertions about it it writes, and the relations from it
docs = {};
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    cn = char(b.document_class.class_name);
    if strcmp(char(b.base.id), elementId)
        docs = [{b}, docs]; %#ok<AGROW>
    elseif strcmp(cn, 'assertion') && strcmp(edgeOf(b, 'entity_id'), elementId)
        v = b.statement.variable;
        if isstruct(v) && any(strcmpi(char(v.name), {'element type', 'ndi element class', ...
                'modality unresolved', 'Equipment Type'}))
            docs{end+1} = b; %#ok<AGROW>
        end
    elseif strcmp(cn, 'directed_relation') && strcmp(edgeOf(b, 'child_id'), elementId)
        docs{end+1} = b; %#ok<AGROW>
    end
end
end

function docs = assertionsAbout(out, elementId, variableName)
% the assertions about ELEMENTID, all of them or those of VARIABLENAME
docs = {};
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(char(b.document_class.class_name), 'assertion') && strcmp(edgeOf(b, 'entity_id'), elementId) ...
            && (isempty(variableName) || strcmp(char(b.statement.variable.name), variableName))
        docs{end+1} = b; %#ok<AGROW>
    end
end
end

function id = edgeOf(b, name)
deps = did2.convert.v1read.readDependsOn(b, 'Name', ['^' name '$']);
id = '';
if ~isempty(deps); id = deps(1).document_id; end
end

function d = carryNoteFor(out, id)
d = '';
n = out.summary.migration_notes.carried_as_v1;
ix = find(strcmp(n.ids, id), 1);
if ~isempty(ix)
    d = n.details{ix};
end
end

function s = describeLost(r)
parts = cell(1, numel(r.lost));
for k = 1:numel(r.lost)
    parts{k} = sprintf('%s (v1 %s, rebuilt %s)', r.lost(k).path, ...
        show(r.lost(k).v1), show(r.lost(k).rebuilt));
end
s = strjoin(parts, '; ');
if isempty(s); s = '(none)'; end
end

function s = show(v)
try
    s = jsonencode(v);
catch
    s = class(v);
end
end

function v1 = probeDoc(id, name, reference, type, ndiClass)
% ndi.probe (ndi.element with direct 1 and no underlying element)
v1 = ndiElement(id, name, reference, type, ndiClass, true, [], 'subj_1', {});
end

function v1 = unitDoc(id, name, reference, probeId)
% ndi.neuron from a spike sorter: type spikes, direct false, on its probe
% (unitProbe, el_uprobe, unless PROBEID names another), the probe's subject,
% and the JRCLUST run it came from
if nargin < 4
    probeId = 'el_uprobe';
end
v1 = ndiElement(id, name, reference, 'spikes', 'ndi.neuron', false, probeId, ...
    'subj_1', {'jrclust_clusters_id', 'jrc_run_1'});
end

function v1 = unitProbe()
% the n-trode the units are sorted from, on the same subject
v1 = probeDoc('el_uprobe', 'leftcortex', 1, 'n-trode', 'ndi.probe.timeseries.mfdaq');
end

function v1 = jhTrack(id, name, type)
% +haley/doImport.m: ndi.element.timeseries(session, name, 1, type, [], 0, subject)
v1 = ndiElement(id, name, 1, type, 'ndi.element.timeseries', false, [], 'worm_1', {});
end

function v1 = derivedCopy(id)
% +element/downsample.m: an ndi.element.timeseries with its probe's type
v1 = ndiElement(id, 'leftcortex_ds', 2, 'n-trode', 'ndi.element.timeseries', false, ...
    'el_probe', 'subj_1', {});
end

function v1 = ndiElement(id, name, reference, type, ndiClass, direct, underlying, subject, extra)
tpl = loadTemplate('element');
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = tpl.depends_on;
v1.depends_on(strcmp({v1.depends_on.name}, 'underlying_element_id')).value = underlying;
v1.depends_on(strcmp({v1.depends_on.name}, 'subject_id')).value = subject;
for k = 1:2:numel(extra)
    v1.depends_on(end+1) = struct('name', extra{k}, 'value', extra{k + 1});
end
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.element = tpl.element;
v1.element.ndi_element_class = ndiClass;
v1.element.name = name;
v1.element.reference = reference;
v1.element.type = type;
v1.element.direct = direct;
v1 = jsondecode(jsonencode(v1));
end

function v1 = neuronDoc(id, elementId, label)
% a neuron_extracellular from its template: the element it is, and the
% sorting run's single/multi label (no waveform: the counts left blank)
tpl = loadTemplate('neuron_extracellular');
baseTpl = loadTemplate('base');
appTpl = loadTemplate('app');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = tpl.depends_on;
v1.depends_on(strcmp({v1.depends_on.name}, 'element_id')).value = elementId;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.app = appTpl.app;
v1.neuron_extracellular = tpl.neuron_extracellular;
v1.neuron_extracellular.quality_label = label;
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
