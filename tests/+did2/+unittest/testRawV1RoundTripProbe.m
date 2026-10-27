function tests = testRawV1RoundTripProbe
%TESTRAWV1ROUNDTRIPPROBE The probe family read as raw v1, and its round trip:
%   probe_geometry, site2channelmap, electrode_offset_voltage.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [migration reliability
%   practices] (a) (a round trip per class, did2.convert.roundtrip.check) and
%   [renames carry is temporary]; 2026-10-27 [fields outside the template are
%   malformed] (a field the migrator does not read carries the document,
%   under the generic "malformed" register row; marked `none` until that row
%   reaches did-schema `main`).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   probe_geometry.json, site2channelmap.json, electrode_offset_voltage.json,
%   base.json) in the shapes their WRITERS give them, and pass through
%   jsonencode/jsondecode as a corpus delivers them:
%     probe_geometry     +ndi/+fun/+probe/+geometry/fromStruct.m: every field
%                        set, columns, frontback zeros and shank_id ones when
%                        the caller gives none, ndim 2, unit 'um',
%                        has_planar_contour 0, the empty matrices 0x1
%     site2channelmap    the same writer, given a map: `map` a column, edges
%                        probe_id and probe_geometry_id
%     electrode_offset_voltage  +ndi/+setup/+conv/+marder/makeVoltageOffsets.m:
%                        one document per CSV row, offset and temperature
%                        (NaN when the row has none), probe_id
%   No corpus of the four zips holds any of the three classes, so these are
%   the only shapes.
%
%   WHAT THE WRITERS' DOCUMENTS DO TODAY.
%     probe_geometry    carried, carry-001: fromStruct always writes shank_id
%                       ([probe contact geometry carried]). The same document
%                       with no shank_id (the "converted shape", DID-side)
%                       converts and loses nothing.
%     site2channelmap   a pass-1 passthrough (the NDI second pass joins it to
%                       its geometry); it round trips as itself.
%     electrode_offset_voltage  converts; with a temperature and with the
%                       writer's NaN. Nothing lost.
%   No writer-shaped document loses a field: there are no known findings for
%   this family.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the switch ======================================

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for c = {'probe_geometry', 'site2channelmap', 'electrode_offset_voltage'}
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
    verifyEqual(testCase, did2.convert.rawV1Classes(c{1}), c{1}, ...
        [c{1} ': the migrator is the v1 name']);
end
f = writerFixtures();
r = runRaw(f(:, 2)');
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_read_raw_v1, size(f, 1));
verifyEqual(testCase, r.summary.legacy_ndi_document.bodies_reaching_universal_renames, 0);
end

% ===================== every writer shape round trips =====================

function testWriterShapesRoundTrip(testCase)
f = writerFixtures();
for k = 1:size(f, 1)
    [label, v1, outcome] = f{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    switch outcome
        case 'converted'
            verifyEmpty(testCase, out.passthrough, [label ': converted, not passed through']);
            verifyGreaterThan(testCase, numel(out.migrated), 1, [label ': the document and its parts']);
            verifyFalse(testCase, r.carried, label);
        case 'passthrough'
            verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
            verifyEqual(testCase, char(out.migrated{1}.get('document_class.schema_version')), ...
                'did_v2', [label ': a passthrough is not a carry']);
            verifyFalse(testCase, r.carried, label);
        case 'carried'
            verifyTrue(testCase, r.carried, [label ': carried']);
    end
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
end

function testEveryTemplateFieldIsAccountedFor(testCase)
% by name, on the converted writer shapes: each field NDI's template declares
cases = { ...
    'probe_geometry, converted shape', {'probe_geometry.site_locations_leftright', ...
        'probe_geometry.site_locations_frontback', 'probe_geometry.site_locations_depth', ...
        'probe_geometry.probe_model', 'probe_geometry.ndim', 'probe_geometry.unit', ...
        'probe_geometry.has_planar_contour', 'depends_on(1).value', 'base.id', ...
        'base.session_id', 'base.datestamp'}; ...
    'electrode_offset_voltage, with a temperature', {'electrode_offset_voltage.offset', ...
        'electrode_offset_voltage.temperature', 'depends_on(1).value', 'base.id', ...
        'base.session_id', 'base.datestamp'}; ...
    'site2channelmap', {'site2channelmap.map', 'depends_on(1).value', ...
        'depends_on(2).value', 'base.id', 'base.session_id', 'base.datestamp'}};
f = writerFixtures();
for k = 1:size(cases, 1)
    v1 = f{strcmp(f(:, 1), cases{k, 1}), 2};
    r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
    accounted = [r.matched, r.restated, r.equivalent];
    for p = cases{k, 2}
        verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
            sprintf('%s: %s is not accounted for', cases{k, 1}, p{1}));
    end
end
end

% ===================== the switch changes no outcome ======================

function testTheSwitchChangesNoOutcome(testCase)
f = writerFixtures();
for k = 1:size(f, 1)
    [~, ~, problems] = did2.unittest.helpers.rawAndRenamed(f(k, 2));
    verifyEmpty(testCase, problems, sprintf('%s: %s', f{k, 1}, strjoin(problems, '; ')));
end
end

function testTheConvertedDocumentsValidate(testCase)
f = writerFixtures();
for k = 1:size(f, 1)
    out = did2.convert.v1_to_v2(f(k, 2), 'Validate', true, 'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine, sprintf('%s: %s', f{k, 1}, quarantineText(out)));
end
end

% ===================== what the migrator does not read is carried =========

function testAFieldTheMigratorDoesNotReadCarriesTheDocument(testCase)
% before the switch these were dropped without a word (or, on the
% passthrough, met the V_eta class as undeclared fields)
v1 = writerOffset(0.012, 21.5);
v1.electrode_offset_voltage.units = 'mV';
verifyCarried(testCase, v1, 'unplaced: electrode_offset_voltage.units');
v1 = writerOffset(0.012, 21.5);
v1.electrode_offset_voltage.temperature = 'room';
verifyCarried(testCase, v1, 'electrode_offset_voltage.temperature (not one finite number)');
v1 = did2.unittest.helpers.setDependency(writerOffset(0.012, 21.5), 'element_epoch_id', 'ee_1');
verifyCarried(testCase, v1, 'depends_on(element_epoch_id)');
v1 = convertedGeometry();
v1.probe_geometry.ndim = 3;
verifyCarried(testCase, v1, 'probe_geometry.ndim');
v1 = convertedGeometry();
v1.probe_geometry.unit = 'furlong';
verifyCarried(testCase, v1, 'probe_geometry.unit');
v1 = convertedGeometry();
v1.probe_geometry.channel_order = [2; 1; 3; 4];
verifyCarried(testCase, v1, 'probe_geometry.channel_order');
v1 = writerSiteMap();
v1.site2channelmap.headstage = 'A';
verifyCarried(testCase, v1, 'site2channelmap.headstage');
end

function testTheWriterGeometryCarriesItsShanks(testCase)
[carried, notes] = did2.unittest.helpers.carryNote({writerGeometry()});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-001] unplaced: probe_geometry.shank_id'), notes);
end

function testTheInventedShapesStillFail(testCase)
% the V_alpha guards run before the raw read: such a body quarantines, as before
v1 = convertedGeometry();
v1.probe_geometry.channel_positions = [1 2];
verifyNotEmpty(testCase, runRaw(v1).quarantine);
v1 = writerOffset(0.01, 20);
v1.electrode_offset_voltage.offset_voltages = [1 2];
verifyNotEmpty(testCase, runRaw(v1).quarantine);
end

% ===================== a check that cannot fail proves nothing ===========

function testABrokenEmissionIsReportedLost(testCase)
v1 = writerOffset(0.012, 21.5);
docs = structs(runRaw(v1).migrated);
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'observation')
        val = docs{k}.voltage.value;
        if iscell(val)
            val{1}.source_value = 0.5;
        else
            val(1).source_value = 0.5;
        end
        docs{k}.voltage.value = val;
    end
end
r = did2.convert.roundtrip.check(v1, docs);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'electrode_offset_voltage.offset'});

v1 = convertedGeometry();
docs = structs(runRaw(v1).migrated);
keep = true(1, numel(docs));
for k = 1:numel(docs)
    if strcmp(docs{k}.document_class.class_name, 'observation') && ...
            strcmp(char(docs{k}.statement.variable.name), 'site location (depth)')
        keep(k) = false;
    end
end
r = did2.convert.roundtrip.check(v1, docs(keep));
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp({r.lost.path}, 'probe_geometry.site_locations_depth')));
end

function testADifferentSourceIsReportedLost(testCase)
v1 = writerSiteMap();
out = runRaw(v1);
v1.site2channelmap.map(2) = 99;
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, {r.lost.path}, {'site2channelmap.map'});
end

function testAnUnplacedDocumentFailsTheRoundTrip(testCase)
v1 = writerOffset(0.012, 21.5);
out = runRaw(v1);
extra = runRaw(convertedGeometry()).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, extra(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
r = did2.convert.roundtrip.check(v1, out.migrated(1));
verifyFalse(testCase, r.ok, 'the session anchor is missing');
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== fixtures, from the WRITERS =========================

function f = writerFixtures()
% {label, v1, 'converted' | 'passthrough' | 'carried'}
nanTemp = writerOffset(-0.0031, NaN);
nanTemp.electrode_offset_voltage.temperature = NaN;   % jsonencodenan keeps NaN
f = { ...
    'probe_geometry, fromStruct', writerGeometry(), 'carried'; ...
    'probe_geometry, converted shape', convertedGeometry(), 'converted'; ...
    'site2channelmap', writerSiteMap(), 'passthrough'; ...
    'electrode_offset_voltage, with a temperature', writerOffset(0.012, 21.5), 'converted'; ...
    'electrode_offset_voltage, temperature not recorded (null)', writerOffset(-0.0031, NaN), 'converted'; ...
    'electrode_offset_voltage, temperature not recorded (NaN)', nanTemp, 'converted'};
end

function d = writerGeometry()
% fromStruct(S, probe, geom) with geom = leftright, depth, probe_model: the
% recognised fields overlay the defaults; frontback zeros and shank_id ones;
% every empty matrix 0x1; then ndi.document('probe_geometry', ..., 'base.session_id',
% S.id()) and set_dependency_value('probe_id', ...)
d = did2.unittest.helpers.ndiDocument('probe_geometry', 'Id', '41268b6f5c6a3d4e_9e0000000000000a');
pg = struct();
pg.site_locations_leftright = [0; 0; 0; 0];
pg.site_locations_frontback = zeros(4, 1);
pg.site_locations_depth = [0; 25; 50; 75];
pg.shank_id = ones(4, 1);
pg.contact_shape = '';
pg.contact_shape_width = zeros(0, 1);
pg.contact_shape_height = zeros(0, 1);
pg.contact_shape_radius = zeros(0, 1);
pg.probe_model = 'A1x4-tet';
pg.manufacturer = '';
pg.ndim = 2;
pg.unit = 'um';
pg.has_planar_contour = 0;
pg.contour_x = zeros(0, 1);
pg.contour_y = zeros(0, 1);
d.probe_geometry = pg;
d = did2.unittest.helpers.setDependency(d, 'probe_id', '41268b6f5c6a3d4e_9e00000000000001');
d = jsondecode(jsonencode(d));
end

function d = convertedGeometry()
% the writer's document with no shank_id (DID-side: what converts)
d = writerGeometry();
d.probe_geometry.shank_id = [];
end

function d = writerSiteMap()
% fromStruct(..., 'map', map): ndi.document('site2channelmap', ...) and the
% two edges
d = did2.unittest.helpers.ndiDocument('site2channelmap', 'Id', '41268b6f5c6a3d4e_9e0000000000000b');
d.site2channelmap = struct('map', [3; 1; 4; 2]);
d = did2.unittest.helpers.setDependency(d, 'probe_id', '41268b6f5c6a3d4e_9e00000000000001');
d = did2.unittest.helpers.setDependency(d, 'probe_geometry_id', '41268b6f5c6a3d4e_9e0000000000000a');
d = jsondecode(jsonencode(d));
end

function d = writerOffset(offset, temperature)
% makeVoltageOffsets: electrode_offset_voltage.offset = offsetV,
% .temperature = T, + S.newdocument(), then probe_id
d = did2.unittest.helpers.ndiDocument('electrode_offset_voltage', ...
    'Id', '41268b6f5c6a3d4e_9e0000000000000c');
d.electrode_offset_voltage = struct('offset', offset, 'temperature', temperature);
d = did2.unittest.helpers.setDependency(d, 'probe_id', '41268b6f5c6a3d4e_9e00000000000001');
d = jsondecode(jsonencode(d));
end

% ===================== helpers =========================================

function out = runRaw(v1)
if ~iscell(v1); v1 = {v1}; end
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function verifyCarried(testCase, v1, part)
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
label = sprintf('%s (%s)', v1.document_class.class_name, part);
verifyEmpty(testCase, out.quarantine, label);
verifyTrue(testCase, carried, [label ': not carried as the untouched v1 source']);
verifyTrue(testCase, contains(notes, part), sprintf('%s: the note does not name it: %s', label, notes));
end

function c = structs(docs)
c = cellfun(@(d) d.toStruct(), docs, 'UniformOutput', false);
end

function s = quarantineText(out)
s = strjoin(arrayfun(@(q) sprintf('%s|%s|%s', q.class_name, q.identifier, q.reason), ...
    out.quarantine, 'UniformOutput', false), '; ');
end
