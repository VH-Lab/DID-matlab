function tests = testRawV1RoundTripOntologyImage
%TESTRAWV1ROUNDTRIPONTOLOGYIMAGE ontologyImage read as raw v1, and its round
%   trip (migrator ontology_image, joined by did2.convert.rawV1Classes' table).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1], [early migration
%   pieces fixed] (1), [migration reliability practices] (a); 2026-10-27
%   [fields outside the template are malformed] (carry-100).
%
%   THE v1 DOCUMENT is built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   ontologyImage.json, ngrid.json, base.json) in the shape
%   +ndi/+setup/+NDIMaker/imageDocMaker.m createOntologyImageDoc writes it:
%   ontologyImage.ontologyNodes (the writer's spelling; the template says
%   ontologyNode), ngrid from ndi.fun.data.mat2ngrid of a 4-by-3 uint8 image,
%   + the session's newdocument(), ontologyTableRow_id, the .ngrid file. No
%   corpus of the four zips holds one.
%
%   It is carried whole as v1, needs_mapping, since 2026-10-29 ([ngrid with no
%   statement carried], Jess Haley: its only edge is its table row); it passed
%   through unchanged before, and the body is the same either way (v1's class
%   name kept). One with no table row passes through as before. The legacy vintage (ontologyName / ontologyRegion; no writer at
%   that `main`, a DID-side shape) still converts, the same on both paths.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testTheSwitchListsTheClass(testCase)
verifyTrue(testCase, any(strcmp(did2.convert.rawV1Classes(), 'ontologyImage')));
verifyEqual(testCase, did2.convert.rawV1Classes('ontologyImage'), 'ontology_image');
end

function testTheWriterDocumentIsCarriedAndRoundTrips(testCase)
% INVERTED 2026-10-29 from testTheWriterDocumentRoundTripsAsAPassthrough (which
% asserted r.carried false). [ngrid with no statement carried] (Decided by Jess
% Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "an
% ontologyImage `ngrid` whose only edge is its table row ... [is] carried whole
% as v1 `needs_mapping`". The writer's document names a table row and nothing
% else, so it is carried: the untouched v1 source, noted, nothing lost.
v1 = writerImage();
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.passthrough), 1);
verifyEqual(testCase, char(out.migrated{1}.get('document_class.class_name')), 'ontologyImage');
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, startsWith(notes, '[carry-124] needs_mapping: ngrid'), notes);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'ontologyImage, imageDocMaker', {});
raw = did2.convert.v1_to_v2({v1}, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, raw.quarantine);
verifyEqual(testCase, numel(raw.passthrough), 1, 'carried with the validator armed');
end

function testAWriterDocumentWithNoEdgeIsCarried(testCase)
% INVERTED 2026-10-30 from testAWriterDocumentWithNoTableRowStillPassesThrough
% (which asserted no carry note). [vintage-B ontologyImage cases] (a) (Decided
% by Jess Haley, 2026-10-29, did-schema V_eta_go_forward_class_audit.md): "a v1
% `ontologyImage` with no non-empty edge at all (NDI `imageDocMaker.m` makes one
% when given no row) is carried whole as v1 like the row-only case
% (carry-124)". imageDocMaker leaves the edge empty when given no row.
v1 = writerImage();
v1 = did2.unittest.helpers.setDependency(v1, 'ontologyTableRow_id', '');
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyTrue(testCase, carried, 'carried as the untouched v1 source');
verifyTrue(testCase, startsWith(notes, '[carry-124] needs_mapping: ngrid (no non-empty edge'), notes);
verifyEqual(testCase, numel(out.passthrough), 1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, r.carried);
did2.unittest.helpers.verifyRoundTrip(testCase, r, 'ontologyImage, no table row', {});
end

function testASubjectEdgeBesideTheTableRowIsCarriedMalformed(testCase)
% [vintage-B ontologyImage cases] (b) (Decided by Jess Haley, 2026-10-29): "one
% with a subject or element edge beside its row (no NDI writer makes one) is
% carried as `malformed`" -- register row carry-150. Both edge names.
for nm = {'subject_id', 'element_id'}
    v1 = did2.unittest.helpers.setDependency(writerImage(), nm{1}, ...
        '41268b6f5c6a3d4e_af00000000000002');
    [carried, notes, out] = did2.unittest.helpers.carryNote({v1});
    verifyEmpty(testCase, out.quarantine);
    verifyTrue(testCase, carried, nm{1});
    verifyTrue(testCase, startsWith(notes, '[carry-150] malformed: '), notes);
    verifyFalse(testCase, contains(notes, 'carry-124'), notes);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried);
end
end

function testASubjectEdgeWithNoTableRowStillPassesThrough(testCase)
% Neither line of [vintage-B ontologyImage cases] names a vintage-B document
% with a subject edge and an EMPTY table row: it passes through as before,
% with no carry note.
v1 = did2.unittest.helpers.setDependency(writerImage(), 'ontologyTableRow_id', '');
v1 = did2.unittest.helpers.setDependency(v1, 'subject_id', '41268b6f5c6a3d4e_af00000000000002');
[carried, notes, out] = did2.unittest.helpers.carryNote({v1});
verifyEmpty(testCase, out.quarantine);
verifyFalse(testCase, carried);
verifyEqual(testCase, notes, '');
verifyEqual(testCase, numel(out.passthrough), 1);
end

function testTheLegacyVintageConverts(testCase)
raw = did2.convert.v1_to_v2({legacyImage()}, 'Validate', false, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, raw.quarantine);
verifyGreaterThan(testCase, numel(raw.migrated), 1);
end

function testCarries(testCase)
v1 = writerImage();
v1.ontologyImage.channel_names = 'gray';
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, '[carry-100] malformed: outside the NDI template, unplaced: ontologyImage.channel_names'), notes);
v1 = did2.unittest.helpers.setDependency(legacyImage(), 'ontologyTableRow_id', 'otr_1');
[carried, notes] = did2.unittest.helpers.carryNote({v1});
verifyTrue(testCase, carried);
verifyTrue(testCase, contains(notes, 'depends_on(ontologyTableRow_id)'), notes);
end

function testTheNgridGuardStillRuns(testCase)
v1 = writerImage();
v1.ngrid.dim_sizes = [4 3];
verifyNotEmpty(testCase, runRaw(v1).quarantine);
end

% ===================== fixtures =========================================

function d = writerImage()
d = did2.unittest.helpers.ndiDocument('ontologyImage', 'Id', '41268b6f5c6a3d4e_af0000000000000a');
d.ontologyImage = struct('ontologyNodes', 'UBERON:0002436,UBERON:0001950');
% mat2ngrid(uint8 4x3): bytes per element, class, size, the 1:n coordinates
d.ngrid = struct('data_size', 1, 'data_type', 'uint8', 'data_dim', [4 3], ...
    'coordinates', [1; 2; 3; 4; 1; 2; 3]);
d = did2.unittest.helpers.setDependency(d, 'ontologyTableRow_id', '41268b6f5c6a3d4e_af00000000000001');
d.files = struct('file_list', {{'ontologyImage.ngrid'}}, 'file_info', struct('name', ...
    'ontologyImage.ngrid', 'locations', struct('delete_original', 1, ...
    'uid', '41268b6f5c6a3d4e_af000000000000f1', 'location', '/tmp/ngrid.bin', ...
    'parameters', '', 'location_type', 'file', 'ingest', 1)));
d = jsondecode(jsonencode(d));
end

function d = legacyImage()
% the legacy vintage the migrator folds (DID-side: no writer at the locked
% main): a region term, a subject, no raster
d = did2.unittest.helpers.ndiDocument('ontologyImage', 'Id', '41268b6f5c6a3d4e_af0000000000000b');
d.ontologyImage = struct('ontologyName', 'UBERON:0002436', 'ontologyRegion', 'primary visual cortex');
d = rmfield(d, 'ngrid');
if isfield(d, 'files'); d = rmfield(d, 'files'); end
d.depends_on = struct('name', 'subject_id', 'value', '41268b6f5c6a3d4e_af00000000000002');
d = jsondecode(jsonencode(d));
end

function out = runRaw(v1)
out = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'V_eta');
end
