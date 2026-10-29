function tests = testRawV1RoundTripPosition
%TESTRAWV1ROUNDTRIPPOSITION position_metadata and distance_metadata read as
%   raw v1, and their round trips.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [early migration pieces
%   fixed] (1) (one migrator per class: the old +migrators/position_metadata.m
%   and distance_metadata.m are deleted; the second was reached only through
%   +migrators_j/distance_metadata.m, which now reshapes the v1 spelling itself)
%   and [migration reliability practices] (a) (a round trip per class,
%   did2.convert.roundtrip.check).
%
%   THE v1 DOCUMENTS ARE THE WRITER'S. +setup/+conv/+haley/doImport.m (NDI-matlab
%   locked `main` 3cb19a8), per worm and body part:
%     position_metadata  ontologyNode the body part (EMPTY:0000136/7/8, head /
%                        midpoint / tail), units 'NCIT:C48367' (pixels),
%                        dimensions 'NCIT:C44477,NCIT:C44478' (X, Y)
%     distance_metadata  ontologyNode_A EMPTY:0000096 (subject document
%                        identifier), integerIDs_A 1, ontologyStringValues_A the
%                        subject document's id; ontologyNode_B EMPTY:0000134
%                        (bacterial patch document identifier), integerIDs_B
%                        the patch numbers, ontologyStringValues_B the patch
%                        rows' document ids joined with ','; numeric values []
%                        and units 'NCIT:C48367'
%   each on the `position` / `distance` ndi.element.timeseries it describes,
%   passed through jsonencode/jsondecode, the shape a corpus delivers (corpus JH
%   holds 2,078 of each, in exactly these shapes). The templates are copied
%   verbatim to tests/+did2/fixtures/ndi_templates (position_metadata,
%   distance_metadata, element, base).
%
%   WHAT THE WRITER'S DOCUMENTS DO TODAY.
%     position_metadata  carried (carry-053): V2 has no place for its units and
%                        dimensions. The same document without them (the
%                        "converted shape") is carried too: it converted to a
%                        term observation until [position and its metadata
%                        are one statement] (Jess Haley, 2026-10-27, did-schema
%                        V_eta_go_forward_class_audit.md): "no term observation
%                        is written"; the metadata and its element's values
%                        become one position calculation, and until position
%                        elements are mapped (carry-063) both stay carried.
%     distance_metadata  converts to the V2 distance_metadata (a class whose
%                        disposition is `retire`; a question in the phase
%                        report) and loses nothing.
%     both, beside their element   the element's type (`position`,
%                        `distance`, on ndi.element.timeseries) is not on the
%                        element type list, so it is carried (carry-063) and
%                        they are carried for it (carry-064).
%   Nothing is lost, invented or unplaced.
tests = functiontests(localfunctions);
end

% ===================== the writer's documents round trip ==================

function testWriterDocumentsRoundTrip(testCase)
% {label, batch (first: the document), carried?}
cases = { ...
    'position writer output', {position('pm_1', 'EMPTY:0000137')}, true; ...
    'position, converted shape', {positionConvertedShape()}, true; ...  % carried since [position and its metadata are one statement]
    'position beside its carried element', {position('pm_1', 'EMPTY:0000137'), track('el_pos', 'position')}, true; ...
    'distance writer output (19 patches)', {distance('dm_1', 1:19)}, false; ...
    'distance writer output (one patch)', {distance('dm_2', 4)}, false; ...
    'distance beside its carried element', {distance('dm_1', 1:19), track('el_dist', 'distance')}, true};
for k = 1:size(cases, 1)
    [label, batch, carried] = cases{k, :};
    out = runRaw(batch);
    verifyEmpty(testCase, out.quarantine, [label ': quarantined']);
    mine = own(out.migrated, batch);
    r = did2.convert.roundtrip.check(batch{1}, mine);
    verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
    verifyEqual(testCase, r.carried, carried, [label ': carried?']);
    verifyEmpty(testCase, r.lost, sprintf('%s: lost %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
end
end

function testEveryWriterFieldOfADistanceIsAccountedFor(testCase)
v1 = distance('dm_1', 1:19);
r = did2.convert.roundtrip.check(v1, runRaw({v1}).migrated);
accounted = [r.matched, r.restated, r.equivalent, r.not_set, r.exempt];
verifyEqual(testCase, numel(accounted), r.fields_inspected);
for p = {'distance_metadata.ontologyNode_A', 'distance_metadata.integerIDs_A', ...
        'distance_metadata.ontologyStringValues_A', 'distance_metadata.ontologyNode_B', ...
        'distance_metadata.integerIDs_B', 'distance_metadata.ontologyStringValues_B', ...
        'distance_metadata.units', 'depends_on(1).value', 'base.id', 'document_class.class_name'}
    verifyTrue(testCase, any(strcmp(p{1}, r.matched)), sprintf('%s is not matched', p{1}));
end
end

function testCarriesCiteTheirRows(testCase)
verifyCarriedFor(testCase, {position('pm_1', 'EMPTY:0000137')}, ...
    '[carry-053] unplaced: position_metadata.units, position_metadata.dimensions');
verifyCarriedFor(testCase, {position('pm_1', 'EMPTY:0000137'), track('el_pos', 'position')}, ...
    '[carry-053]');
verifyCarriedFor(testCase, {distance('dm_1', 1:19), track('el_dist', 'distance')}, ...
    '[carry-064] needs_mapping: its element_id edge names el_dist');
end

% ===================== the switch ======================================

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for cls = {'position_metadata', 'distance_metadata'}
    verifyTrue(testCase, any(strcmp(names, cls{1})), cls{1});
    verifyEqual(testCase, did2.convert.rawV1Classes(cls{1}), cls{1});
    verifyEmpty(testCase, which(['did2.convert.migrators.' cls{1}]), ...
        sprintf('+migrators/%s.m is back', cls{1}));
    verifyNotEmpty(testCase, which(['did2.convert.migrators_j.' cls{1}]));
end
end

function testTheSwitchChangesNoConvertedDocument(testCase)
% "keep behaviour identical": every document the raw path CONVERTS is the one
% the universalRenames path converted; a carry is carried on both paths, the
% raw one the untouched v1 source
batches = {{position('pm_1', 'EMPTY:0000137')}, {positionConvertedShape()}, ...
    {distance('dm_1', 1:19)}, {distance('dm_2', 4)}, ...
    {distance('dm_1', 1:19), track('el_dist', 'distance')}};
for k = 1:numel(batches)
    b = batches{k};
    raw = runRaw(b);
    old = did2.convert.v1_to_v2(b, 'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
    label = sprintf('batch %d (%s)', k, b{1}.document_class.class_name);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), ...
        [label ': carried on one path only']);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    if isCarried(raw, b{1})
        verifyTrue(testCase, isCarried(old, []), [label ': carried on the raw path only']);
        continue;
    end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        verifyTrue(testCase, isequaln(raw.migrated{j}.toStruct(), old.migrated{j}.toStruct()), ...
            sprintf('%s, document %d differs between the raw and the renamed path', label, j));
    end
end
end

function testAPositionNamingNoMeasurementIsCarried(testCase)
% the one change of the switch: before it, such a document passed through as a
% V2 position_metadata (a class to retire), which NDI's last step stamps v1
% again ([passthrough stays v1: how]); it is now carried as v1 at once, on
% either path (no NDI writer at the locked main writes one)
v1 = position('pm_9', '');
verifyCarriedFor(testCase, {v1}, 'no ontologyNode');
old = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
verifyTrue(testCase, isCarried(old, []), 'not carried on the renamed path');
end

function testTheConvertedDocumentsValidate(testCase)
% positionConvertedShape() is no longer a converted document ([position and
% its metadata are one statement], Jess Haley, 2026-10-27): it is carried, and
% its carry is checked by testAPositionWithOnlyABodyPartIsCarried
for b = {{distance('dm_1', 1:19)}, {distance('dm_2', 4)}}
    out = did2.convert.v1_to_v2(b{1}, 'Validate', true, 'TargetVersion', 'V_eta');
    label = b{1}{1}.document_class.class_name;
    verifyEmpty(testCase, out.quarantine, sprintf('%s: %s', label, quarantineText(out)));
    verifyNotEmpty(testCase, out.migrated, label);
end
end

% ===================== every field accounted for =========================

function testAFieldTheMigratorDoesNotReadCarriesTheDocument(testCase)
v1 = positionConvertedShape();
v1.position_metadata.frame = 'image';
verifyCarriedFor(testCase, {v1}, 'unplaced: position_metadata.frame');
v1 = positionConvertedShape();
v1.position_metadata.ontology_node = 'EMPTY:0000136';
verifyCarriedFor(testCase, {v1}, 'unplaced: position_metadata.ontology_node');
v1 = distance('dm_1', 1:19);
v1.distance_metadata.integerIDs_C = 3;
verifyCarriedFor(testCase, {v1}, 'unplaced: distance_metadata.integerIDs_C');
v1 = distance('dm_1', 1:19);
v1.depends_on(end + 1) = struct('name', 'subject_id', 'value', 'worm_1');
verifyCarriedFor(testCase, {v1}, 'unplaced: depends_on(subject_id)');
v1 = distance('dm_1', 1:19);
v1.distance_metadata.ontology_node_a = 'EMPTY:0000097';
verifyCarriedFor(testCase, {v1}, 'unplaced: distance_metadata.ontology_node_a');
v1 = distance('dm_1', 1:19);
v1.ndi_document = struct('id', 'x', 'type', 'distance_metadata');
verifyCarriedFor(testCase, {v1}, '[carry-049] universalRenames would discard: ndi_document');
end

% ===================== a check that cannot fail proves nothing ===========

function testABrokenEmissionIsReportedLost(testCase)
% distance: a patch number and an id changed
v1 = distance('dm_1', 1:19);
docs = structs(runRaw({v1}).migrated);
ep = docs{1}.distance_metadata.endpoints;
if iscell(ep)
    ep{2}.integer_ids(3) = 99;
    ep{1}.measurement.node = 'EMPTY:0000097';
else
    ep(2).integer_ids(3) = 99;
    ep(1).measurement.node = 'EMPTY:0000097';
end
docs{1}.distance_metadata.endpoints = ep;
r = did2.convert.roundtrip.check(v1, docs);
verifyEqual(testCase, sort(lostPaths(r)), ...
    sort({'distance_metadata.integerIDs_B', 'distance_metadata.ontologyNode_A'}));
end

function testAPositionWithOnlyABodyPartIsCarried(testCase)
% INVERTED 2026-10-29 from the position half of testABrokenEmissionIsReportedLost,
% which broke the term observation and the anchor made from
% positionConvertedShape() and expected the round trip to report them. Since
% [position and its metadata are one statement] (Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md) "no term observation is
% written": the document is carried whole as v1, so there is no emission to
% break; the round trip reads the carry, and a changed carried body is lost.
v1 = positionConvertedShape();
verifyCarriedFor(testCase, {v1}, 'its metadata are one statement');
verifyCarriedFor(testCase, {v1}, '[carry-053] awaiting_home: position_metadata.ontologyNode');
out = runRaw({v1});
verifyEqual(testCase, numel(out.migrated), 1, 'the v1 source only');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
verifyTrue(testCase, r.ok, describeLost(r));
docs = structs(out.migrated);
docs{1}.position_metadata.ontologyNode = 'EMPTY:0000138';
r = did2.convert.roundtrip.check(v1, docs);
verifyEqual(testCase, lostPaths(r), {'position_metadata.ontologyNode'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = distance('dm_1', 1:19);
out = runRaw({v1});
extra = runRaw({positionConvertedShape()}).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== helpers =========================================

function out = runRaw(batch)
out = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'V_eta');
end

function docs = own(migrated, batch)
% the documents emitted for the first source: every one but those of the
% element beside it (its carry)
others = cellfun(@(b) char(b.base.id), batch(2:end), 'UniformOutput', false);
keep = cellfun(@(d) ~any(strcmp(char(d.get('base.id')), others)), migrated);
docs = migrated(keep);
end

function tf = isCarried(out, v1)
tf = false;
for k = 1:numel(out.migrated)
    d = out.migrated{k};
    if ~strcmp(char(d.get('document_class.schema_version')), 'did_v1')
        continue;
    end
    s = d.toStruct();
    if isempty(v1)
        tf = true;
        return;
    end
    if strcmp(char(s.base.id), v1.base.id)
        s.document_class = rmfield(s.document_class, 'schema_version');
        tf = isequaln(s, v1);
        return;
    end
end
end

function verifyCarriedFor(testCase, batch, part)
out = runRaw(batch);
v1 = batch{1};
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, isCarried(out, v1), [label ': not carried as the untouched v1 source']);
notes = out.summary.migration_notes;
assertTrue(testCase, isfield(notes, 'carried_as_v1'), [label ': no carried_as_v1 note']);
ix = find(strcmp(notes.carried_as_v1.ids, v1.base.id));
assertNotEmpty(testCase, ix, [label ': no note for the document']);
d = strjoin(notes.carried_as_v1.details(ix), ' || ');
verifyTrue(testCase, contains(d, part), sprintf('%s: the note does not name it: %s', label, d));
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

function s = quarantineText(out)
s = strjoin(arrayfun(@(q) sprintf('%s|%s|%s', q.class_name, q.identifier, q.reason), ...
    out.quarantine, 'UniformOutput', false), '; ');
end

function v1 = position(id, bodyPart)
% doImport.m Step 6 A: ndi.document('position_metadata', 'position_metadata',
% position_metadata) + session.newdocument(), then element_id
tpl = loadTemplate('position_metadata');
v1 = withBase(tpl, id);
v1.depends_on = tpl.depends_on;
v1.depends_on(1).value = 'el_pos';
v1.position_metadata = struct('ontologyNode', bodyPart, 'units', 'NCIT:C48367', ...
    'dimensions', 'NCIT:C44477,NCIT:C44478');
v1 = jsondecode(jsonencode(v1));
end

function v1 = positionConvertedShape()
% the writer's document without units and dimensions (no writer at the locked
% main omits them): the shape the migrator converts
v1 = position('pm_2', 'EMPTY:0000136');
v1.position_metadata.units = '';
v1.position_metadata.dimensions = '';
end

function v1 = distance(id, patches)
% doImport.m Step 6 B: the subject document and the plate's patch rows
tpl = loadTemplate('distance_metadata');
v1 = withBase(tpl, id);
v1.depends_on = tpl.depends_on;
v1.depends_on(1).value = 'el_dist';
patchIds = arrayfun(@(p) sprintf('41269430c5a8%04x_40c21c6cafc6a2f4', p), patches, ...
    'UniformOutput', false);
v1.distance_metadata = struct( ...
    'ontologyNode_A', 'EMPTY:0000096', ...
    'integerIDs_A', 1, ...
    'ontologyNumericValues_A', [], ...
    'ontologyStringValues_A', '41269430c5d0f467_40b3ce7c80fe06c8', ...
    'ontologyNode_B', 'EMPTY:0000134', ...
    'integerIDs_B', patches, ...
    'ontologyNumericValues_B', [], ...
    'ontologyStringValues_B', strjoin(patchIds, ','), ...
    'units', 'NCIT:C48367');
v1 = jsondecode(jsonencode(v1));
end

function v1 = track(id, type)
% doImport.m: ndi.element.timeseries(session, name, 1, type, [], 0, subject_id)
tpl = loadTemplate('element');
v1 = withBase(tpl, id);
v1.depends_on = tpl.depends_on;
v1.depends_on(strcmp({v1.depends_on.name}, 'underlying_element_id')).value = [];
v1.depends_on(strcmp({v1.depends_on.name}, 'subject_id')).value = 'worm_1';
v1.element = tpl.element;
v1.element.ndi_element_class = 'ndi.element.timeseries';
v1.element.name = ['worm1_head_' type];
v1.element.reference = 1;
v1.element.type = type;
v1.element.direct = false;
v1 = jsondecode(jsonencode(v1));
end

function v1 = withBase(tpl, id)
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41269430c597c3e6_c0c9895d35d19b54';
v1.base.datestamp = '2025-09-04T16:23:20.158Z';
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
