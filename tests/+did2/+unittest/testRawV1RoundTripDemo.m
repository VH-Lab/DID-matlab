function tests = testRawV1RoundTripDemo
%TESTRAWV1ROUNDTRIPDEMO The demo classes and binaryseries_parameters read as
%   raw v1, and their round trip: demoNDI, demoNDIMock (migrators demo_ndi,
%   demo_ndi_mock, joined by did2.convert.rawV1Classes' table),
%   binaryseries_parameters.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [migration
%   reliability practices] (a), [renames carry is temporary]; 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim):
%   demoNDIMock as +ndi/+calc/+example/simple.m writes it (demoNDI.value 5, +
%   the session's newdocument(), add_file('filename1.ext', ...)); demoNDI (no
%   writer makes one alone) and binaryseries_parameters (no writer) as their
%   templates state them. No corpus of the four zips holds any of them.
%
%   The demo documents fold to one `demo` each and lose nothing;
%   binaryseries_parameters is carried whole as v1, needs_mapping (Decided by
%   Jess Haley, 2026-10-29 [binaryseries parameters carried]; until then it was
%   kept with its template's empty-text placeholders for integer fields
%   removed). No known findings.
tests = functiontests(localfunctions);
end

function testTheSwitchListsTheFamily(testCase)
names = did2.convert.rawV1Classes();
for c = {'demoNDI', 'demoNDIMock', 'binaryseries_parameters'}
    verifyTrue(testCase, any(strcmp(names, c{1})), c{1});
end
verifyEqual(testCase, did2.convert.rawV1Classes('demoNDI'), 'demo_ndi');
verifyEqual(testCase, did2.convert.rawV1Classes('demoNDIMock'), 'demo_ndi_mock');
end

function testFixturesRoundTrip(testCase)
% the demo documents convert (binaryseries_parameters is carried: the test below)
f = fixtures();
n = 0;
for k = 1:size(f, 1)
    [label, v1] = f{k, :};
    if strcmp(v1.document_class.class_name, 'binaryseries_parameters')
        continue;
    end
    n = n + 1;
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    did2.unittest.helpers.verifyRoundTrip(testCase, r, label, {});
end
verifyEqual(testCase, n, 2, 'DENOMINATOR: the two demo fixtures');
end

function testBinaryseriesParametersIsCarriedAndRoundTrips(testCase)
% INVERTED 2026-10-29 from the binaryseries_parameters row of
% testFixturesRoundTrip (which asserted it was NOT carried). [binaryseries
% parameters carried] (Jess Haley, 2026-10-29, did-schema
% V_eta_go_forward_class_audit.md): "a v1 `binaryseries_parameters` ... is
% carried whole as v1 `needs_mapping`: each dataset says which data body it
% describes". The template's own document (no writer exists) is carried as
% its untouched v1 source, noted needs_mapping, and round-trips with nothing
% lost.
v1 = series();
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, startsWith(notes, '[carry-122] needs_mapping: '), notes);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'binaryseries_parameters, template', {});
end

function testTheDemoDocumentsValidate(testCase)
for v1 = {demoMock(), demo()}
    out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
    verifyEmpty(testCase, out.quarantine, v1{1}.document_class.class_name);
end
end

function testAFieldOutsideTheTemplateCarriesTheDocument(testCase)
% the fold refused these with an error (a quarantine) before the switch
v1 = demoMock();
v1.demoNDI.units = 'a.u.';
verifyCarried(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: demoNDI.units');
v1 = demo();
v1.mock = struct('ismock', 1);
verifyCarried(testCase, v1, 'unplaced: mock');
v1 = series();
v1.binaryseries_parameters.channel_count = 4;
verifyCarried(testCase, v1, 'binaryseries_parameters.channel_count');
end

function testADifferentSourceIsReportedLost(testCase)
v1 = demoMock();
out = runRaw(v1);
v1.demoNDI.value = 6;
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, {r.lost.path}, {'demoNDI.value'});
end

% ===================== fixtures =========================================

function f = fixtures()
f = { ...
    'demoNDIMock, ndi.calc.example.simple', demoMock(); ...
    'demoNDI, template', demo(); ...
    'binaryseries_parameters, template', series()};
end

function d = demoMock()
d = did2.unittest.helpers.ndiDocument('demoNDIMock', 'Id', '41268b6f5c6a3d4e_8e0000000000000a');
d.demoNDI = struct('value', 5);
d.files = struct('file_list', {{'filename1.ext'}}, 'file_info', struct('name', 'filename1.ext', ...
    'locations', struct('delete_original', 1, 'uid', '41268b6f5c6a3d4e_8e000000000000f1', ...
    'location', '/tmp/test1_dummy.txt', 'parameters', '', 'location_type', 'file', 'ingest', 1)));
d = jsondecode(jsonencode(d));
end

function d = demo()
d = did2.unittest.helpers.ndiDocument('demoNDI', 'Id', '41268b6f5c6a3d4e_8e0000000000000b');
d.demoNDI = struct('value', 7);
d = jsondecode(jsonencode(d));
end

function d = series()
d = did2.unittest.helpers.ndiDocument('binaryseries_parameters', 'Id', '41268b6f5c6a3d4e_8e0000000000000c');
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
