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
%     [element name and reference stored apart] (2026-10-29)  the v1 name,
%                                       exactly, is entity.name; the
%                                       reference is what follows it in the
%                                       local_identifier
%                                       (did2.convert.elementHandle /
%                                       elementNameReferenceApart), so a name
%                                       that reads as a pair converts
%                                       (no longer carried as unpackable); an entity
%                                       with no `name` (migrated before it)
%                                       still reads by the old parse
%     [element types have no default], [element types batch 1] ..
%     [element types batch 4] (2026-10-30)
%                                       a device only on an ndi.probe.* class,
%                                       for the 23 types with a device kind;
%                                       the electrode spellings, event,
%                                       neuron, cell and anything else
%                                       carried (carry-063)
%     [stimulator is SNOMED CT Stimulator] (2026-10-30)
%                                       stimulator is a device of kind
%                                       SNOMEDCT:36645008 (replaces batch 4
%                                       item (4), which carried it)
%     [sorted units are cells or groups], [unlabelled units need a map]
%                                       spikes: single -> cell, multi -> Group,
%                                       no label carried (carry-062)
%     [migrator writes the registry spelling]  entity type `Group`, as the
%                                       registry names it
%     [element type is a device kind term], [n-trode is a multielectrode
%     array], [element types batch 1] .. [element types batch 4]
%                                       a device kind as an Equipment Type
%                                       assertion; the `element type`
%                                       assertion only where the kind alone
%                                       does not rebuild the v1 word
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
% unit whose probe is NOT in the batch was converted with this one finding (its
% subject_id unread) until [unit with no probe in the batch carried] (Jess
% Haley, 2026-10-29): it is carried now (carry-151,
% testCarriedElementsCiteTheirRows), so no converted fixture has a finding.
f = cell(0, 3);
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

% ===================== converted writer shapes ==========================

function testConvertedElementsRoundTrip(testCase)
units = {neuronDoc('ne_1', 'el_unit_s', 'single'), neuronDoc('ne_2', 'el_unit_m', 'multi'), ...
    unitProbe()};
cases = { ...
    'n-trode probe', probeDoc('el_probe', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'patch-I probe', probeDoc('el_patch', 'patch1', 1, 'patch-I', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'patch probe', probeDoc('el_patch0', 'patch0', 1, 'patch', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'patch-attached probe', probeDoc('el_patcha', 'patcha', 1, 'patch-attached', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'sharp-Vm probe', probeDoc('el_sharp', 'sharp1', 1, 'sharp-Vm', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'electrode-$ probe', probeDoc('el_edollar', 'el', 1, 'electrode-$', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'lick spout probe', probeDoc('el_lick', 'lick', 1, 'lick-spout', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'reward well probe', probeDoc('el_rw', 'rw', 1, 'reward-well', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'intraoral cannula probe', probeDoc('el_ioc', 'ioc', 1, 'intraoral-cannula', 'ndi.probe.timeseries.stimulator'), 'device'; ...
    'optogenetic fiber probe', probeDoc('el_opto', 'opto', 1, 'optogenetic-fiber', 'ndi.probe.timeseries.stimulator'), 'device'; ...
    'stimulator probe', probeDoc('el_stim', 'vhvis_spike2', 1, 'stimulator', 'ndi.probe.timeseries.stimulator'), 'device'; ...
    'thermometer probe', probeDoc('el_therm', 'therm', 1, 'thermometer', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'ppg probe', probeDoc('el_ppg', 'ppg', 1, 'ppg', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'single unit', unitDoc('el_unit_s', 'leftcortex_17', 1), 'cell'; ...
    'multi unit', unitDoc('el_unit_m', 'leftcortex_18', 1), 'group'; ...
    'accelerometer probe', probeDoc('el_acc', 'acc', 1, 'accelerometer', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'ecg probe', probeDoc('el_ecg', 'ecg', 1, 'ecg', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'eeg probe', probeDoc('el_eeg', 'eeg', 1, 'eeg', 'ndi.probe.timeseries.mfdaq'), 'device'; ...
    'two-photon probe', probeDoc('el_2p', 'tp', 1, 'two-photon-imaging', 'ndi.probe.image'), 'device'; ...
    'one-photon probe', probeDoc('el_1p', 'op', 1, 'one-photon-imaging', 'ndi.probe.image'), 'device'; ...
    'wide-field imaging probe', probeDoc('el_wf', 'cam', 1, 'wide-field-imaging', 'ndi.probe.image'), 'device'; ...
    'brightfield imaging probe', probeDoc('el_bf', 'cam', 1, 'brightfield-imaging', 'ndi.probe.image'), 'device'};
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
verifyEqual(testCase, char(ent.get('entity.name')), 'leftcortex');
[n, r] = did2.convert.elementNameReference('leftcortex | 2');
verifyEqual(testCase, n, 'leftcortex');
verifyEqual(testCase, r, 2);
% a name holding ' | ' itself still reads back: the split is at the LAST one
v1 = probeDoc('el_probe2', 'a | b', 3, 'n-trode', 'ndi.probe.timeseries.mfdaq');
r2 = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyEmpty(testCase, r2.lost, describeLost(r2));
end

function testNameAndReferenceStoredApartRoundTrip(testCase)
% [element name and reference stored apart] (Jess Haley, 2026-10-29): the v1
% name, exactly, is entity.name, and local_identifier keeps
% '<name> | <reference>'; the reference is read back as what follows the
% known name. INVERTED from the unpackable-pair carry rows of
% testCarriedElementsCiteTheirRows ('name reads as a pair', 'non-integer
% reference'), which carried these elements whole: each now converts and
% rebuilds exactly.
cases = { ...
    'name holding (ref 3)', 'el_ref3', 'leftcortex (ref 3)', 2, 'leftcortex (ref 3) | 2'; ...
    'name that is an old (ref X) pair, no reference', 'el_ref3n', 'leftcortex (ref 3)', [], 'leftcortex (ref 3)'; ...
    'name reads as a pair, no reference', 'el_pair', 'leftcortex | 2', [], 'leftcortex | 2'; ...
    'name reads as a pair, with a reference', 'el_pair2', 'leftcortex | 2', 5, 'leftcortex | 2 | 5'; ...
    'non-integer reference', 'el_frac', 'leftcortex', 1.5, 'leftcortex | 1.5'; ...
    'text reference', 'el_text', 'leftcortex', 'tip', 'leftcortex | tip'; ...
    'empty name with a reference', 'el_noname', '', 2, ' | 2'};
for k = 1:size(cases, 1)
    [label, id, name, reference, localId] = cases{k, :};
    v1 = probeDoc(id, name, reference, 'n-trode', 'ndi.probe.timeseries.mfdaq');
    out = runRaw(v1);
    verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, id))), 0, ...
        sprintf('%s: carried (%s)', label, carryNoteFor(out, id)));
    docs = elementOutputs(out, id);
    if isempty(docs); continue; end
    ent = docs{1};
    verifyEqual(testCase, char(ent.entity.local_identifier), localId, label);
    if isempty(name)
        verifyFalse(testCase, isfield(ent.entity, 'name'), [label ': an empty name wrote entity.name']);
    else
        verifyEqual(testCase, char(ent.entity.name), name, [label ': entity.name']);
    end
    r = did2.convert.roundtrip.check(v1, docs);
    verifyFalse(testCase, r.carried, label);
    verifyEmpty(testCase, r.lost, sprintf('%s: %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyTrue(testCase, any(strcmp('element.name', [r.matched, r.not_set])), ...
        [label ': element.name not rebuilt']);
    verifyTrue(testCase, any(strcmp('element.reference', [r.matched, r.not_set])), ...
        [label ': element.reference not rebuilt']);
end
end

function testAnEntityWithoutNameReadsByTheOldParse(testCase)
% an element entity migrated before [element name and reference stored apart]
% has no `name` (its v1 base.name was '') and holds the pair in
% local_identifier alone: '<name> | <reference>' (2026-10-26), or the older
% '<name> (ref <X>)'. Its round trip falls back to that parse
% (did2.convert.elementNameReference) and still rebuilds the v1 element.
v1 = probeDoc('el_old', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq');
docs = elementOutputs(runRaw(v1), 'el_old');
for form = {'leftcortex | 2', 'leftcortex (ref 2)'}
    old = docs;
    old{1}.entity = rmfield(old{1}.entity, 'name');
    old{1}.entity.local_identifier = form{1};
    r = did2.convert.roundtrip.check(v1, old);
    verifyEmpty(testCase, r.lost, sprintf('%s: %s', form{1}, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', form{1}, strjoin(r.invented, ', ')));
end
% and one whose `name` is its v1 base.name ([v1 name is the entity name],
% 2026-10-27), not leading its local_identifier: base.name is rebuilt from
% `name`, element.name and element.reference from local_identifier
v1n = v1;
v1n.base.name = 'left cortex probe';
old = docs;
old{1}.entity.name = 'left cortex probe';
r = did2.convert.roundtrip.check(v1n, old);
verifyEmpty(testCase, r.lost, describeLost(r));
verifyEmpty(testCase, r.invented, strjoin(r.invented, ', '));
end

function testANonEmptyBaseNameIsCarried(testCase)
% [element name and reference stored apart] (2026-10-29) gives the entity's
% one `name` to element.name. A non-empty v1 base.name, which [v1 name is the
% entity name] (2026-10-27) wrote there, then has no field: writing either
% name loses the other. ndi.element/newdocument writes base.name '' (NDI-matlab
% main 441530d0, +ndi/element.m newdocument), so Decided by Jess Haley,
% 2026-10-30 [element name kept apart, base.name carried]: the element is
% carried whole as v1, malformed, under carry-149. REPLACES
% testABaseNameIsTheEntityName's element case, which wrote base.name to
% entity.name.
v1 = probeDoc('el_named', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq');
v1.base.name = 'left cortex probe';
out = runRaw(v1);
verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, 'el_named'))), 1, ...
    'a non-empty base.name was not carried');
d = carryNoteFor(out, 'el_named');
verifyTrue(testCase, startsWith(d, '[carry-149] malformed: base.name "left cortex probe"'), d);
docs = elementOutputs(out, 'el_named');
r = did2.convert.roundtrip.check(v1, docs);
verifyTrue(testCase, r.carried);
verifyTrue(testCase, r.ok, describeLost(r));
% base.name '' (the writer's) converts, and the entity's name is element.name
v0 = probeDoc('el_unnamed', 'leftcortex', 2, 'n-trode', 'ndi.probe.timeseries.mfdaq');
e0 = runRaw(v0).migrated{1}.toStruct();
verifyEqual(testCase, char(e0.entity.name), 'leftcortex');
r0 = did2.convert.roundtrip.check(v0, elementOutputs(runRaw(v0), 'el_unnamed'));
verifyEmpty(testCase, r0.lost, describeLost(r0));
verifyTrue(testCase, any(strcmp('base.name', [r0.matched, r0.not_set])), 'base.name '''' not rebuilt');
% and the named device validates
outV = did2.convert.v1_to_v2(v0, 'Validate', true, 'TargetVersion', 'did_v2');
reasons = '';
for k = 1:numel(outV.quarantine)
    reasons = [reasons sprintf('%s: %s; ', outV.quarantine(k).class_name, ...
        outV.quarantine(k).reason)]; %#ok<AGROW>
end
verifyEmpty(testCase, outV.quarantine, reasons);
end

function testEveryDeviceHasItsDecidedKind(testCase)
% [element type is a device kind term] (Jess Haley, 2026-10-27) and
% [element types batch 1] .. [element types batch 4] (2026-10-30): every
% device gets one Equipment Type (NCIT:C178920) assertion with its decided
% kind. INVERTS testADecidedDeviceKindIsAnEquipmentTypeAssertion, which
% pinned patch-Vm, sharp-Im, lick-spout and reward-well to no kind, and
% stimulator, event and electrode-4 to devices with none (event and
% electrode-4 are now carried: testCarriedElementsCiteTheirRows; stimulator
% is a device of kind SNOMEDCT:36645008 "Stimulator", [stimulator is SNOMED
% CT Stimulator], Jess Haley, 2026-10-30).
cases = { ...
    'n-trode', 'ndi.probe.timeseries.mfdaq', 'wikidata:Q1952355'; ...
    'patch', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000411'; ...
    'patch-Vm', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000411'; ...
    'patch-I', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000411'; ...
    'patch-attached', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000411'; ...
    'sharp', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000412'; ...
    'sharp-Vm', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000412'; ...
    'sharp-Im', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000412'; ...
    'wide-field-imaging', 'ndi.probe.image', 'OBI:0400169'; ...
    'two-photon-imaging', 'ndi.probe.image', 'OBI:0400169'; ...
    'one-photon-imaging', 'ndi.probe.image', 'OBI:0400169'; ...
    'brightfield-imaging', 'ndi.probe.image', 'OBI:0400169'; ...
    'lick-spout', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000414'; ...
    'reward-well', 'ndi.probe.timeseries.mfdaq', 'EMPTY:0000415'; ...
    'intraoral-cannula', 'ndi.probe.timeseries.stimulator', 'NCIT:C50343'; ...
    'optogenetic-fiber', 'ndi.probe.timeseries.stimulator', 'NCIT:C50358'; ...
    'ecg', 'ndi.probe.timeseries.mfdaq', 'OBI:0003806'; ...
    'eeg', 'ndi.probe.timeseries.mfdaq', 'wikidata:Q4531135'; ...
    'accelerometer', 'ndi.probe.timeseries.mfdaq', 'NCIT:C88166'; ...
    'thermometer', 'ndi.probe.timeseries.mfdaq', 'NCIT:C50059'; ...
    'ppg', 'ndi.probe.timeseries.mfdaq', 'NCIT:C224112'; ...
    'electrode-$', 'ndi.probe.timeseries.mfdaq', 'NCIT:C49936'; ...
    'stimulator', 'ndi.probe.timeseries.stimulator', 'SNOMEDCT:36645008'};
[~, ~, kindTable] = did2.convert.elementDeviceKind('');
verifyEqual(testCase, sort(kindTable(:, 1)), sort(cases(:, 1)), ...
    'the device-kind table is not the decided list');
for k = 1:size(cases, 1)
    [ty, cls, node] = cases{k, :};
    id = sprintf('el_kind_%d', k);
    out = runRaw(probeDoc(id, 'p', 1, ty, cls));
    verifyEqual(testCase, numel(out.passthrough), 0, [ty ': carried']);
    kinds = assertionsAbout(out, id, 'Equipment Type');
    verifyNumElements(testCase, kinds, 1, ty);
    if numel(kinds) == 1
        verifyEqual(testCase, char(kinds{1}.statement.variable.node), 'NCIT:C178920', ty);
        verifyEqual(testCase, char(kinds{1}.term.value.node), node, ty);
    end
end
end

function testTheElementTypeAssertionIsKeptOnlyWhereTheKindDoesNotRebuildIt(testCase)
% [element type is a device kind term] (Jess Haley, 2026-10-27): the
% `element type` assertion is replaced by the device kind, and "until a type
% has its term, the migrator keeps writing the current statement". A kind
% one v1 type has rebuilds the word alone, so the assertion is not written;
% a kind several types share (patch electrode, sharp electrode, microscope)
% needs the recording or imaging mode, which goes on the recording
% observation the batch pass mints and is not decided for every mode yet
% ([element types batch 1], [element types batch 2]), so the word is kept.
% A sorted unit (no device kind) does NOT keep it: [cell spellings are one
% meaning], [cell spellings amended] (Jess Haley, 2026-10-27). INVERTED
% 2026-11-10: the `ndi element class` assertion was asserted present for
% every element; [ndi element class not kept] (Jess Haley, 2026-10-27), built
% on NDI-matlab's side by #1214 ([element recognised by its links]), stops it
% wherever the class rebuilds (testTheClassIsRebuiltFromWhatTheElementIs).
dropped = {'n-trode', 'electrode-$', 'lick-spout', 'reward-well', 'intraoral-cannula', ...
    'optogenetic-fiber', 'ecg', 'eeg', 'accelerometer', 'thermometer', 'ppg', 'stimulator'};
kept = {'patch', 'patch-Vm', 'patch-I', 'patch-attached', 'sharp', 'sharp-Vm', ...
    'sharp-Im', 'wide-field-imaging', 'two-photon-imaging', 'one-photon-imaging', ...
    'brightfield-imaging'};
types = [dropped, kept];
for k = 1:numel(types)
    ty = types{k};
    id = sprintf('el_word_%d', k);
    % its probetype2object.json class, so the class rebuilds
    out = runRaw(probeDoc(id, 'p', 1, ty, did2.convert.elementClassOfKind('probe', ty)));
    vars = cellfun(@(b) char(b.statement.variable.name), assertionsAbout(out, id, ''), ...
        'UniformOutput', false);
    verifyEqual(testCase, any(strcmp(vars, 'element type')), any(strcmp(ty, kept)), ...
        [ty ': element type assertion written or dropped wrongly']);
    verifyFalse(testCase, any(strcmp(vars, 'ndi element class')), [ty ': ndi element class assertion written']);
    kind = did2.convert.elementDeviceKind(ty);
    expected = '';
    if any(strcmp(ty, dropped)); expected = ty; end
    verifyEqual(testCase, did2.convert.elementTypeOfKind(kind.node), expected, ...
        [ty ': elementTypeOfKind reads the kind back wrongly']);
end
% a sorted unit keeps no word: its entity type (cell or Group) is the type
for label = {'single', 'multi'}
    id = ['el_unit_w_' label{1}];
    out = runRaw({unitDoc(id, 'leftcortex_25', 1), neuronDoc(['ne_w_' label{1}], id, label{1}), unitProbe()});
    vars = cellfun(@(b) char(b.statement.variable.name), assertionsAbout(out, id, ''), ...
        'UniformOutput', false);
    verifyFalse(testCase, any(strcmp(vars, 'element type')), ['spikes (' label{1} '): element type assertion written']);
    verifyFalse(testCase, any(strcmp(vars, 'ndi element class')), ['spikes (' label{1} '): ndi element class assertion written']);
end
end

function testTheClassIsRebuiltFromWhatTheElementIs(testCase)
% [ndi element class not kept] (Decided by Jess Haley, 2026-10-27): "the
% 'ndi element class' assertion is not written; the round trip rebuilds
% `element.ndi_element_class` from the entity type and device kind (for a
% probe type, NDI's `probetype2object.json`)"; [element recognised by its
% links], [ensemble has members] (2026-11-10). A device takes its type's
% probetype2object.json class; a cell or a multi-unit Group 'ndi.neuron'.
units = {neuronDoc('ne_c1', 'el_c_s', 'single'), neuronDoc('ne_c2', 'el_c_m', 'multi'), unitProbe()};
cases = { ...
    'n-trode', probeDoc('el_c_nt', 'p', 1, 'n-trode', 'ndi.probe.timeseries.mfdaq'), 'ndi.probe.timeseries.mfdaq'; ...
    'stimulator', probeDoc('el_c_st', 'p', 1, 'stimulator', 'ndi.probe.timeseries.stimulator'), 'ndi.probe.timeseries.stimulator'; ...
    'two-photon', probeDoc('el_c_2p', 'p', 1, 'two-photon-imaging', 'ndi.probe.image'), 'ndi.probe.image'; ...
    'single unit', unitDoc('el_c_s', 'u', 1), 'ndi.neuron'; ...
    'multi unit', unitDoc('el_c_m', 'u', 2), 'ndi.neuron'};
testCase.log(sprintf('DENOMINATOR: %d element(s)', size(cases, 1)));
for k = 1:size(cases, 1)
    [label, v1, want] = cases{k, :};
    out = runRaw([{v1}, units]);
    verifyEmpty(testCase, assertionsAbout(out, v1.base.id, 'ndi element class'), ...
        [label ': ndi element class assertion written']);
    docs = elementOutputs(out, v1.base.id);
    rebuilt = did2.convert.roundtrip.element(docs);
    verifyEqual(testCase, rebuilt.element.ndi_element_class, want, label);
    r = did2.convert.roundtrip.check(v1, docs);
    verifyTrue(testCase, any(strcmp(r.matched, 'element.ndi_element_class')), ...
        sprintf('%s: class not matched: %s', label, describeLost(r)));
end
verifyEqual(testCase, did2.convert.elementClassOfKind('probe', 'patch-Vm'), 'ndi.probe.timeseries.mfdaq');
verifyEqual(testCase, did2.convert.elementClassOfKind('probe', 'sharp-I'), '');
verifyEqual(testCase, did2.convert.elementClassOfKind('unit', 'spikes'), 'ndi.neuron');
verifyEqual(testCase, did2.convert.elementClassOfKind('ensemble', 'ensemble'), 'ndi.element.ensemble');
verifyEqual(testCase, did2.convert.elementClassOfKind('', 'n-trode'), '');
end

function testAClassThatDoesNotRebuildKeepsItsAssertion(testCase)
% [ndi element class not kept]: "an element whose class cannot be rebuilt
% that way is brought to the team". Until then nothing is lost: it keeps the
% assertion, which wins while written ([assertion wins while written] (1),
% Jess Haley, 2026-11-10), and is noted `element_class_not_rebuilt`.
v1 = probeDoc('el_c_odd', 'p', 1, 'n-trode', 'ndi.probe.timeseries');
out = runRaw(v1);
verifyEqual(testCase, numel(out.passthrough), 0, 'carried');
cls = assertionsAbout(out, 'el_c_odd', 'ndi element class');
verifyNumElements(testCase, cls, 1);
verifyTrue(testCase, isfield(out.summary.migration_notes, 'element_class_not_rebuilt'), 'not noted');
if isfield(out.summary.migration_notes, 'element_class_not_rebuilt')
    verifyTrue(testCase, any(strcmp(out.summary.migration_notes.element_class_not_rebuilt.ids, 'el_c_odd')));
end
r = did2.convert.roundtrip.check(v1, elementOutputs(out, 'el_c_odd'));
verifyEmpty(testCase, r.lost, describeLost(r));
verifyEmpty(testCase, r.unplaced, strjoin(r.unplaced, '; '));
end

function testAnEnsembleIsCheckedAfterNdisSecondPass(testCase)
% [ensemble has members] (Decided by Jess Haley, 2026-11-10): a Group that
% `member_of` relations point into is an ensemble; one with none is a
% multi-unit. [assertion wins while written] (1): "when DID-matlab stops
% writing the assertion, ensembles are checked after NDI-matlab's second
% pass writes their `member_of` relations" (this round trip runs before it).
% So with no members its class and type read as one multi-unit, and the v1
% ensemble's are reported `equivalent` under that decision, not lost; with
% a member_of relation in the batch index they rebuild exactly.
v1 = ndiElement('el_ens', 'ens', 1, 'ensemble', 'ndi.element.ensemble', false, ...
    'el_uprobe', 'subj_1', {});
out = runRaw({v1, unitProbe()});
verifyEqual(testCase, numel(out.passthrough(strcmp({out.passthrough.id}, 'el_ens'))), 0, 'carried');
verifyEmpty(testCase, assertionsAbout(out, 'el_ens', 'ndi element class'), 'class assertion written');
docs = elementOutputs(out, 'el_ens');
verifyEqual(testCase, did2.unittest.helpers.classKey(docs{1}), 'group');
[rebuilt, spec] = did2.convert.roundtrip.element(docs);
verifyEqual(testCase, rebuilt.element.ndi_element_class, 'ndi.neuron', 'no members: a multi-unit');
verifyEqual(testCase, rebuilt.element.type, 'spikes', 'no members: a multi-unit');
verifyTrue(testCase, any(contains({spec.same.why}, '[assertion wins while written]')), ...
    'the deferral is not stated');
r = did2.convert.roundtrip.check(v1, docs);
lost = {r.lost.path};
verifyFalse(testCase, any(strcmp(lost, 'element.type')), describeLost(r));
verifyFalse(testCase, any(strcmp(lost, 'element.ndi_element_class')), describeLost(r));
verifyTrue(testCase, any(strcmp(r.equivalent, 'element.ndi_element_class')), 'class not reported equivalent');
verifyTrue(testCase, any(strcmp(r.equivalent, 'element.type')), 'type not reported equivalent');
% a multi-unit that is NOT an ensemble is not taken as one
multi = v1;
multi.element.type = 'spikes';
multi.element.ndi_element_class = 'ndi.neuron';
r = did2.convert.roundtrip.check(multi, docs);
verifyFalse(testCase, any(strcmp(r.equivalent, 'element.ndi_element_class')));
% with its members (NDI's second pass): rebuilt exactly
rel = struct('document_class', struct('class_name', 'directed_relation'), ...
    'base', struct('id', 'rel_member_1'), ...
    'directed_relation', struct('relation', struct('node', 'RO:0002350', 'name', 'member of')), ...
    'depends_on', struct('name', {'child_id', 'parent_id'}, 'value', {'el_unit_a', 'el_ens'}));
ctx = struct('docs', {{rel}}, ...
    'byId', containers.Map({'rel_member_1'}, {1}), ...
    'referrers', containers.Map({'el_unit_a', 'el_ens'}, {1, 1}));
rebuilt = did2.convert.roundtrip.element(docs, ctx);
verifyEqual(testCase, rebuilt.element.ndi_element_class, 'ndi.element.ensemble');
verifyEqual(testCase, rebuilt.element.type, 'ensemble');
end

function testAProbeThatNeverRecordedRebuildsItsGeneralType(testCase)
% [clamp mode of unrecorded probe dropped] (Jess Haley, 2026-11-03): a patch,
% sharp or imaging probe that never recorded keeps its device kind and no
% `element type` statement (resolveEpochProbemap drops it). Decided by Jess
% Haley, 2026-11-06 ("Read back patch"): its type rebuilds as the general
% registered v1 type of its kind, 'patch' or 'sharp'; a microscope has none
% and rebuilds ''. Its kind is placed either way.
rows = {
    'patch-I',            'patch'
    'patch-Vm',           'patch'
    'patch-attached',     'patch'
    'patch',              'patch'
    'sharp-Vm',           'sharp'
    'sharp-Im',           'sharp'
    'sharp',              'sharp'
    'two-photon-imaging', ''
    'wide-field-imaging', ''};
testCase.log(sprintf('DENOMINATOR: %d v1 type(s) of a shared device kind', size(rows, 1)));
for k = 1:size(rows, 1)
    [ty, want] = rows{k, :};
    id = sprintf('el_nrec_%d', k);
    ndiClass = 'ndi.probe.timeseries.mfdaq';
    if endsWith(ty, 'imaging'); ndiClass = 'ndi.probe.image'; end
    v1 = probeDoc(id, 'p', 1, ty, ndiClass);
    docs = elementOutputs(runRaw(v1), id);
    isType = cellfun(@(b) strcmp(char(b.document_class.class_name), 'assertion') ...
        && strcmpi(char(b.statement.variable.name), 'element type'), docs);
    assertEqual(testCase, nnz(isType), 1, [ty ': premise, one element type assertion']);
    docs = docs(~isType);   % what resolveEpochProbemap leaves of a probe that never recorded
    [rebuilt, spec] = did2.convert.roundtrip.element(docs);
    verifyEqual(testCase, rebuilt.element.type, want, ty);
    verifyEmpty(testCase, spec.unplaced, [ty ': unplaced: ' strjoin(spec.unplaced, '; ')]);
    r = did2.convert.roundtrip.check(v1, docs);
    verifyEmpty(testCase, r.unplaced, ty);
    lostType = any(strcmp({r.lost.path}, 'element.type'));
    verifyEqual(testCase, lostType, ~strcmp(ty, want), ...
        sprintf('%s: element.type lost (only the mode is): %s', ty, describeLost(r)));
end
end

function testTheGeneralTypeOfEachKind(testCase)
% did2.convert.elementGeneralTypeOfKind, from the elementDeviceKind table
[~, ~, types] = did2.convert.elementDeviceKind('');
nodes = unique(types(:, 2));
testCase.log(sprintf('DENOMINATOR: %d kind node(s)', numel(nodes)));
assertNotEmpty(testCase, nodes);
general = struct('EMPTY_0000411', 'patch', 'EMPTY_0000412', 'sharp');
for k = 1:numel(nodes)
    key = strrep(nodes{k}, ':', '_');
    want = '';
    if isfield(general, key); want = general.(key); end
    verifyEqual(testCase, did2.convert.elementGeneralTypeOfKind(nodes{k}), want, nodes{k});
end
verifyEqual(testCase, did2.convert.elementGeneralTypeOfKind('empty:0000411'), 'patch');
verifyEqual(testCase, did2.convert.elementGeneralTypeOfKind(''), '');
verifyEqual(testCase, did2.convert.elementGeneralTypeOfKind('NCIT:C0000000'), '');
end

function testTheThreeUnitSpellingsRoundTripAsOne(testCase)
% [cell spellings are one meaning], [cell spellings amended] (Decided by Jess
% Haley, 2026-10-27, did-schema did_v2_go_forward_class_audit.md): "the round
% trip counts the three as equivalent spellings". A unit's entity type
% rebuilds 'spikes'; a v1 type `neuron` or `cell` compares as the same
% meaning (reported `equivalent`, not lost), and any other word is lost.
units = {neuronDoc('ne_sp', 'el_unit_sp', 'single'), unitProbe()};
v1 = unitDoc('el_unit_sp', 'leftcortex_26', 1);
out = runRaw([{v1}, units]);
docs = elementOutputs(out, 'el_unit_sp');
r = did2.convert.roundtrip.check(v1, docs);
verifyTrue(testCase, any(strcmp(r.matched, 'element.type')), 'spikes rebuilds as spikes');
for spelling = {'neuron', 'cell'}
    other = v1;
    other.element.type = spelling{1};
    r = did2.convert.roundtrip.check(other, docs);
    verifyFalse(testCase, any(strcmp({r.lost.path}, 'element.type')), ...
        [spelling{1} ': element.type reported lost']);
    verifyTrue(testCase, any(strcmp(r.equivalent, 'element.type')), ...
        [spelling{1} ': element.type not reported equivalent']);
end
other = v1;
other.element.type = 'ensemble';
r = did2.convert.roundtrip.check(other, docs);
verifyTrue(testCase, any(strcmp({r.lost.path}, 'element.type')), ...
    'a word that is not one of the three spellings is lost');
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
    'patch type on no probe class', probeDoc('el_npp', 'x', 1, 'patch-Vm', 'ndi.element.timeseries'), {}, '[carry-063] '; ...
    'unlisted type', probeDoc('el_ul', 'x', 1, 'sharp-I', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-063] '; ...
    'event line probe', probeDoc('el_ev', 'vhtaste_sync', 1, 'event', 'ndi.probe.timeseries.stimulator'), {}, '[carry-063] '; ...
    'electrode spelling', probeDoc('el_e4', 'tet', 1, 'electrode-4', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-063] '; ...
    'prefixed electrode spelling', probeDoc('el_xe4', 'tet', 1, 'extracellular_electrode-4', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-063] '; ...
    'neuron, labelled', namedUnit('el_neu', 'neuron'), {neuronDoc('ne_neu', 'el_neu', 'single'), unitProbe()}, '[carry-063] '; ...
    'cell, labelled', namedUnit('el_cel', 'cell'), {neuronDoc('ne_cel', 'el_cel', 'multi'), unitProbe()}, '[carry-063] '; ...
    'lfp', probeDoc('el_lfp', 'lfp', 1, 'lfp', 'ndi.element.timeseries'), {}, '[carry-063] '; ...
    'reference not one number', probeDoc('el_arr', 'leftcortex', [1 2], 'n-trode', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-120] '; ...
    'no name, no reference', probeDoc('el_none', '', [], 'n-trode', 'ndi.probe.timeseries.mfdaq'), {}, '[carry-048] '; ...
    'unit, probe not in the batch', unitDoc('el_unit_x', 'leftcortex_22', 1, 'el_absent'), ...
        {neuronDoc('ne_5', 'el_unit_x', 'single')}, '[carry-151] needs_mapping: '};
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

function testAUnitWithNoProbeInTheBatchIsCarried(testCase)
% INVERTED 2026-10-30: the 'unit, probe not in the batch' fixture was converted
% with its subject_id unchecked (one known finding, note
% unit_probe_not_in_batch). [unit with no probe in the batch carried] (Decided
% by Jess Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "a
% sorted unit whose probe is not in the migration batch ... is carried whole
% as v1 under a register row instead of converting with its subject
% unchecked" -- carry-151, needs_mapping. The same unit WITH its probe in the
% batch converts.
v1 = unitDoc('el_unit_x', 'leftcortex_22', 1, 'el_absent');
out = runRaw({v1, neuronDoc('ne_5', 'el_unit_x', 'single')});
docs = elementOutputs(out, v1.base.id);
verifyEqual(testCase, numel(docs), 1, 'one document, the v1 source');
d = carryNoteFor(out, v1.base.id);
verifyTrue(testCase, startsWith(d, '[carry-151] needs_mapping: '), d);
verifyTrue(testCase, contains(d, 'el_absent'), d);
verifyFalse(testCase, isfield(out.summary.migration_notes, 'unit_probe_not_in_batch'), ...
    'the old converted-and-counted note is gone');
r = did2.convert.roundtrip.check(v1, docs);
verifyTrue(testCase, r.carried);
verifyTrue(testCase, r.ok, describeLost(r));
probe = probeDoc('el_absent', 'leftcortex', 1, 'n-trode', 'ndi.probe.timeseries.mfdaq');
out2 = runRaw({v1, neuronDoc('ne_5', 'el_unit_x', 'single'), probe});
verifyEqual(testCase, numel(out2.passthrough(strcmp({out2.passthrough.id}, v1.base.id))), 0, ...
    'with its probe in the batch the unit converts');
end

function testABatchLabelCanBeGivenByTheCaller(testCase)
% 'UnitQualityLabels': a unit whose neuron_extracellular is not in the batch.
% Its probe is in the batch: without it the unit is carried (carry-151,
% [unit with no probe in the batch carried], 2026-10-29).
v1 = unitDoc('el_unit_g', 'leftcortex_21', 1);
out = did2.convert.v1_to_v2({v1, unitProbe()}, 'Validate', false, 'TargetVersion', 'did_v2', ...
    'UnitQualityLabels', {'el_unit_g', 'multi'});
docs = elementOutputs(out, 'el_unit_g');
verifyEqual(testCase, did2.unittest.helpers.classKey(docs{1}), 'group');
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
    % the probe is in the batch (carry-151 otherwise)
    out = runRaw({v1, neuronDoc(sprintf('ne_ks_%d', k), id, cases{k, 1}), unitProbe()});
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

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
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
% no carried_as_v1 field at all when nothing in the run was carried
if ~isfield(out.summary.migration_notes, 'carried_as_v1')
    return;
end
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

function v1 = namedUnit(id, type)
% a sorted unit NDI wrote with type `neuron` or `cell` rather than `spikes`
% ([element types batch 4] (9): carried, whatever its label)
v1 = ndiElement(id, [id '_u'], 1, type, 'ndi.neuron', false, 'el_uprobe', 'subj_1', {});
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
