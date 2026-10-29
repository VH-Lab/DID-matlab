function tests = testRawV1RoundTripTreatment
%TESTRAWV1ROUNDTRIPTREATMENT The treatment family read as raw v1, and its
%   round trip: treatment, treatment_drug, treatment_transfer, virus_injection.
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes) and [migration reliability
%   practices] (a) (a round trip per class, did2.convert.roundtrip.check). The
%   test of the round trip is [lossless means round trip]; equivalent spellings
%   are [spelling is notation].
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim) in
%   the shapes NDI's WRITERS give them (the writer wins over the template), and
%   pass through jsonencode/jsondecode as a corpus delivers them:
%
%     treatment           +NDIMaker/treatmentMaker create_treatment_doc
%                         (+vhlab/treatmentTable.m's grating hours; a ChEBI
%                         substance at an UBERON site), table2treatment (the
%                         `manipulation_id` group link), +haley/doImport (food
%                         restriction onset), +dabrowska/doImport (target
%                         location)
%     treatment_drug      treatmentMaker create_treatment_drug_doc with
%                         +birren/TreatmentCreator.m's chronic CNO row (writes
%                         `location_ontologyName`, the offset and duration)
%     virus_injection     treatmentMaker create_virus_injection_doc with
%                         +birren/TreatmentCreator.m's neuronal DREADD row, and
%                         a body-site row
%     treatment_transfer  treatmentMaker create_treatment_transfer_doc with
%                         +babu/TreatmentCreator.m's pick row (a timestamp, and
%                         NaN where no transfer time was recorded): ALWAYS
%                         carried whole as v1 ([treatment transfer stays v1],
%                         Jess Haley, 2026-10-27)
%
%   Also built here, Decided by Jess Haley, 2026-10-27: [treatment groups are a
%   dataset decision] (a treatment with a `manipulation_id` link is carried,
%   needs_mapping) and [treatment location name is the node] (the writer's
%   `location_ontologyName` and the template's `location_ontologyNode` are one
%   field; both, differing, carry the document as malformed).
%
%   Every writer shape below converts or carries exactly as before the switch
%   (testTheSwitchChangesNoConvertedTreatment), and its round trip reports
%   nothing invented or unplaced. WHAT V2 DOES NOT KEEP is listed, per fixture,
%   as KNOWN FINDINGS (knownFindings): open questions for the team, not rules
%   made here. Each fixture's lost paths must be EXACTLY its listed findings,
%   so a new loss fails, and so does a finding that stops being one.
tests = functiontests(localfunctions);
end

% ===================== the known findings ===============================

function f = knownFindings()
% One row per v1 field a writer-shaped document loses today. Open questions,
% reported to the team; nothing here is decided. {fixture, path, why}
%
% INVERTED 2026-10-29: the four rows "no migrator reads the offset time" / "no
% migrator reads the duration" of 'Birren CNO in the bath' and 'treatmentMaker
% drug at an UBERON site' are gone. [drug end and duration on the anchor]
% (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md) writes them to the anchor's `value.end` and
% `value.duration`, so both fixtures now round trip them
% (testADrugsOffsetAndDurationAreItsAnchorsEndAndDuration).
f = { ...
    'Birren DREADD virus in the bath', 'virus_injection.virus_AdministrationPND', ...
        'no migrator reads the postnatal day'; ...
    'virus at V1', 'virus_injection.virusLocation_name', ...
        ['the site term is written with the registry label (T19, ' ...
        'did2.convert.registeredTerm: "primary visual cortex"); the writer''s ' ...
        'label "V1" is kept nowhere']; ...
    'virus at V1', 'virus_injection.virus_AdministrationPND', ...
        'no migrator reads the postnatal day'};
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

% ===================== the writer shapes round trip ======================

function testTreatmentWriterShapesRoundTrip(testCase)
roundTripCases(testCase, { ...
    'vhlab grating hours', vhlabHours(), false; ...
    'ChEBI substance at an UBERON site', muscimolAtV1(), false; ...
    'table2treatment group link', groupLinked(), true; ...
    'Haley food restriction onset', haleyOnset(), true; ...
    'Dabrowska target location', dabTarget(), true});
end

function testTreatmentDrugWriterShapesRoundTrip(testCase)
roundTripCases(testCase, { ...
    'Birren CNO in the bath', birrenCno(), false; ...
    'treatmentMaker drug at an UBERON site', drugAtSite(), false});
end

function testVirusInjectionWriterShapesRoundTrip(testCase)
roundTripCases(testCase, { ...
    'Birren DREADD virus in the bath', birrenVirus(), false; ...
    'virus at V1', virusAtV1(), false});
end

function testTreatmentTransferWriterShapesRoundTrip(testCase)
roundTripCases(testCase, { ...
    'Babu pick transfer', babuTransfer(-72000), true; ...
    'Babu transfer, no time', babuTransfer(NaN), true});
end

function testEveryKnownFindingNamesAFixtureThatIsRun(testCase)
% a finding whose fixture is not round-tripped would never fail
f = knownFindings();
names = {'Birren CNO in the bath', 'treatmentMaker drug at an UBERON site', ...
    'Birren DREADD virus in the bath', 'virus at V1'};
for k = 1:size(f, 1)
    verifyTrue(testCase, any(strcmp(f{k, 1}, names)), f{k, 1});
end
end

% ===================== what the round trip accounts for ==================

function testEveryTemplateFieldOfAConvertedDrugIsAccountedFor(testCase)
% the Birren row: each field the writer sets is matched, restated,
% equivalent, not set, exempt, or a listed finding
v1 = birrenCno();
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
accounted = [r.matched, r.restated, r.equivalent, r.not_set, {r.lost.path}];
for p = {'base.id', 'base.session_id', 'base.name', 'base.datestamp', ...
        'depends_on(1).name', 'depends_on(1).value', ...
        'treatment_drug.location_ontologyName', 'treatment_drug.location_name', ...
        'treatment_drug.mixture_table', 'treatment_drug.administration_onset_time', ...
        'treatment_drug.administration_offset_time', ...
        'treatment_drug.administration_duration', 'document_class.class_name'}
    verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
        sprintf('%s is not accounted for', p{1}));
end
verifyTrue(testCase, any(strcmp('treatment_drug.mixture_table', [r.matched, r.equivalent])), ...
    'the mixture table is rebuilt: as written, or row by row');
verifyTrue(testCase, any(strcmp('treatment_drug.location_name', r.restated)), ...
    'an immersion''s location is the bath');
end

function testADrugsOffsetAndDurationAreItsAnchorsEndAndDuration(testCase)
% INVERTED 2026-10-29 from the knownFindings rows "no migrator reads the
% offset time" / "no migrator reads the duration". [drug end and duration on
% the anchor] (Decided by Jess Haley, 2026-10-27, did-schema
% V_eta_go_forward_class_audit.md): "`administration_offset_time` ->
% `absolute_time_reference.value.end`; `administration_duration` ->
% `absolute_time_reference.value.duration`". The Birren row writes local times
% (no Z) and the duration in days (NDI-matlab main +birren/TreatmentCreator.m
% "newRow{12} = 2; % duration in days").
out = runRaw(birrenCno());
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted, not carried');
v = anchorValue(testCase, out);
verifyEqual(testCase, char(v.start.source_value), '2024-05-30T00:00:00');
verifyEqual(testCase, char(v.end.source_value), '2024-06-01T00:00:00');
verifyFalse(testCase, isfield(v.end, 'utc'), 'a local time is not normalised');
verifyEqual(testCase, double(v.duration.source_value), 2);
verifyEqual(testCase, double(v.duration.seconds), 2 * 86400);
verifyEqual(testCase, char(v.duration.source_unit.name), 'day');
verifyEmpty(testCase, char(v.duration.source_unit.node), ...
    'no registered term holds the day (V_eta_source_unit_plan.md item 4)');
r = did2.convert.roundtrip.check(birrenCno(), out.migrated);
verifyTrue(testCase, any(strcmp('treatment_drug.administration_offset_time', r.matched)));
verifyTrue(testCase, any(strcmp('treatment_drug.administration_duration', r.matched)));
end

function testADrugsUtcEndIsNormalisedWithItsStart(testCase)
% [drug end and duration on the anchor]: with UTC times (the template's
% "YYYY-MM-DDThh:mm:ssZ"), the end is normalised like the start, and the three
% agree (rule end_consistent: end = start + duration)
v1 = drugAtSite();
v1.treatment_drug.administration_onset_time = '2024-06-01T09:15:00Z';
v1.treatment_drug.administration_offset_time = '2024-06-01T09:16:00Z';
v1.treatment_drug.administration_duration = 1/1440;
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
v = anchorValue(testCase, out);
verifyEqual(testCase, char(v.start.utc), '2024-06-01T09:15:00Z');
verifyEqual(testCase, char(v.end.utc), '2024-06-01T09:16:00Z');
verifyEqual(testCase, char(v.end.source_value), '2024-06-01T09:16:00Z');
verifyEqual(testCase, double(v.duration.seconds), 60, 'AbsTol', 1e-6);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEmpty(testCase, r.lost, describeLost(r));
verifyEmpty(testCase, r.invented, strjoin(r.invented, ', '));
end

function testADrugsDisagreeingUtcTimesWriteNoEndOrDuration(testCase)
% NOT DECIDED (reported to the team): UTC onset, offset and duration that the
% rule end_consistent rejects. The anchor never holds an end and a duration
% that contradict its start (the document would not validate); neither is
% written, as before [drug end and duration on the anchor], and the round trip
% reports both lost
v1 = drugAtSite();
v1.treatment_drug.administration_onset_time = '2024-06-01T09:15:00Z';
v1.treatment_drug.administration_offset_time = '2024-06-01T09:16:00Z';
v1.treatment_drug.administration_duration = 1;
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
v = anchorValue(testCase, out);
verifyFalse(testCase, isfield(v, 'end'));
verifyFalse(testCase, isfield(v, 'duration'));
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEqual(testCase, reshape(sort({r.lost.path}), 1, []), ...
    {'treatment_drug.administration_duration', 'treatment_drug.administration_offset_time'});
end

function testADilutionOfZeroIsRestatedAndAnyOtherIsNot(testCase)
% [virus-location]: "A dilution of 0 is treated as not recorded (NaN)"
v1 = birrenVirus();
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyTrue(testCase, any(strcmp('virus_injection.dilution', r.restated)));
end

% ===================== the round trip can fail ===========================

function testAChangedMixtureRowIsReportedLost(testCase)
% the row-by-row comparison is not a pass-through: a different amount fails
v1 = birrenCno();
out = runRaw(v1);
v1b = v1;
v1b.treatment_drug.mixture_table = strrep(v1.treatment_drug.mixture_table, '1e-05', '2e-05');
r = did2.convert.roundtrip.check(v1b, out.migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp('treatment_drug.mixture_table', {r.lost.path})));
end

function testADroppedChemicalIsReported(testCase)
v1 = birrenCno();
out = runRaw(v1);
kept = out.migrated;
for k = numel(kept):-1:1
    if strcmp(kept{k}.className(), 'chemical')
        kept(k) = [];
        break;
    end
end
r = did2.convert.roundtrip.check(v1, kept);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

function testABathNodeThatIsNotTheBathIsReportedLost(testCase)
% the restatement is the bath only: a virus "in the bath" by its name whose
% node names something else loses that node
v1 = birrenVirus();
v1.virus_injection.virusLocation_OntologyName = 'NCIm:C9999999';
out = runRaw(v1);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp('virus_injection.virusLocation_OntologyName', {r.lost.path})));
end

% ===================== the switch changes nothing converted ==============

function testTheSwitchChangesNoConvertedTreatment(testCase)
% "keep behaviour identical": every document the raw path CONVERTS is the one
% the universalRenames path converted (ids are deterministic, practice (b));
% a carry is carried on both paths, the raw one the untouched v1 source
fixtures = [writerFixtures(), didSideFixtures()];
for k = 1:numel(fixtures)
    v1 = jsondecode(jsonencode(fixtures{k}));   % the shape a corpus delivers
    raw = runRaw(v1);
    old = did2.convert.v1_to_v2(v1, 'Validate', false, ...
        'TargetVersion', 'V_eta', 'RawV1Classes', {});
    label = sprintf('fixture %d (%s %s)', k, v1.document_class.class_name, v1.base.id);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEqual(testCase, numel(raw.quarantine), numel(old.quarantine), label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), [label ': carried on one path only']);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    if ~isempty(raw.passthrough)
        emitted = raw.migrated{1}.toStruct();
        emitted.document_class = rmfield(emitted.document_class, 'schema_version');
        verifyTrue(testCase, isequaln(emitted, v1), [label ': the carry is not the v1 source']);
        continue;
    end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        verifyTrue(testCase, isequaln(raw.migrated{j}.toStruct(), old.migrated{j}.toStruct()), ...
            sprintf('%s, document %d differs between the raw and the renamed path', label, j));
    end
end
end

function testALegacyIdentityBlockConvertsAsBefore(testCase)
% a pre-2023 treatment whose identity is only in `ndi_document` (the 2020
% vintage: id and session_id spelled as `base` spells them): universalRenames
% moved the block into `base`; the raw migrator reads it through readBase
v1 = vhlabHours();
legacy = struct('id', v1.base.id, 'session_id', v1.base.session_id, ...
    'name', '', 'type', '', 'datestamp', v1.base.datestamp, 'database_version', 1);
v1 = rmfield(v1, 'base');
v1.ndi_document = legacy;
raw = runRaw(v1);
old = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', 'RawV1Classes', {});
verifyEmpty(testCase, raw.quarantine);
verifyEqual(testCase, numel(raw.migrated), numel(old.migrated));
% the minted ids agree too: did2.convert.mintKey keys a base-less document on
% its legacy id (practice (b); it minted random ids before)
for j = 1:min(numel(raw.migrated), numel(old.migrated))
    a = raw.migrated{j}.toStruct();
    b = old.migrated{j}.toStruct();
    verifyTrue(testCase, isequaln(a, b), ...
        sprintf('document %d differs: raw %s; renamed %s', j, jsonencode(a), jsonencode(b)));
end
verifyEqual(testCase, raw.migrated{1}.get('base.id'), legacy.id);
end

function testAWriterShapedDrugAtABodySiteIsADoseAtThatSite(testCase)
% INVERTS testAWriterShapedDrugAtABodySiteCarriesForItsNodeSpelling.
% [treatment location name is the node] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): treatmentMaker writes the node as
% `location_ontologyName` (NDI-matlab main +setup/+NDIMaker/treatmentMaker.m
% line 163), the template as `location_ontologyNode`; they are one field, so the
% writer's UBERON site is read and the drug is a dose at that site (it was
% carried, carry-028, because only the template spelling was read)
out = runRaw(drugAtSite());
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted, not carried');
sites = {};
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(b.document_class.class_name, 'observation') && isfield(b, 'term')
        sites{end+1} = char(b.term.value.node); %#ok<AGROW>
    end
end
verifyEqual(testCase, numel(sites), 1, 'one site observation');
verifyTrue(testCase, any(strcmpi(sites, 'UBERON:0001179')), strjoin(sites, ', '));
end

function testBothLocationSpellingsDifferingCarryTheDrugAsMalformed(testCase)
% [treatment location name is the node]: "a document holding both with
% different values is carried whole as v1, kind `malformed`" (carry-110)
v1 = drugAtSite();
v1.treatment_drug.location_ontologyNode = 'UBERON:0002436';
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.passthrough), 1, 'carried');
emitted = out.migrated{1}.toStruct();
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-110] malformed: '), d);
% the same node under both spellings (prefix case aside) is one statement
v1.treatment_drug.location_ontologyNode = 'uberon:0001179';
out = runRaw(v1);
verifyEmpty(testCase, out.passthrough, 'equal nodes: converted');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyEmpty(testCase, r.invented, strjoin(r.invented, ', '));
verifyFalse(testCase, any(strcmp({r.lost.path}, 'treatment_drug.location_ontologyNode')));
verifyFalse(testCase, any(strcmp({r.lost.path}, 'treatment_drug.location_ontologyName')));
end

function testAGroupLinkedTreatmentIsCarriedForItsDataset(testCase)
% [treatment groups are a dataset decision] (Decided by Jess Haley,
% 2026-10-27): a treatment with a `manipulation_id` link (table2treatment's
% group) is carried whole as v1, needs_mapping; without the link it converts
v1 = jsondecode(jsonencode(groupLinked()));
out = runRaw(v1);
assertEqual(testCase, numel(out.passthrough), 1, 'carried');
d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
verifyTrue(testCase, startsWith(d, '[carry-108] needs_mapping: '), d);
verifyTrue(testCase, contains(d, '41268b6f5c6a3d4e_7a00000000000001'), d);
out = runRaw(jsondecode(jsonencode(vhlabHours())));
verifyEmpty(testCase, out.passthrough, 'no link: converted');
end

function testEveryTreatmentTransferIsCarriedWholeAsV1(testCase)
% [treatment transfer stays v1] (Decided by Jess Haley, 2026-10-27): the
% generic stage converts no treatment_transfer; each is carried whole as v1
% with a needs-mapping register row (carry-107), for the Babu
% reimport
fixtures = [{babuTransfer(-72000), babuTransfer(NaN)}, didSideFixtures()];
n = 0;
for k = 1:numel(fixtures)
    v1 = jsondecode(jsonencode(fixtures{k}));
    if ~strcmp(v1.document_class.class_name, 'treatment_transfer')
        continue;
    end
    n = n + 1;
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine);
    assertEqual(testCase, numel(out.migrated), 1);
    emitted = out.migrated{1}.toStruct();
    emitted.document_class = rmfield(emitted.document_class, 'schema_version');
    verifyTrue(testCase, isequaln(emitted, v1), 'the carry is not the v1 source');
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-107] needs_mapping: '), d);
end
verifyEqual(testCase, n, 3, 'the transfer fixtures were found');
end

% ===================== helpers =========================================

function roundTripCases(testCase, cases)
for k = 1:size(cases, 1)
    [label, v1, carried] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, [label ': quarantined']);
    if ~isempty(out.quarantine)
        continue;
    end
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
    verifyEqual(testCase, r.carried, carried, [label ': carried?']);
    lost = reshape(sort({r.lost.path}), 1, []);
    verifyEqual(testCase, lost, findingsFor(label), ...
        sprintf('%s: lost paths are not the listed findings; lost: %s', label, describeLost(r)));
    verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
    verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
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

function v = anchorValue(testCase, out)
% the `value` of the one absolute_time_reference the migration emitted
v = [];
n = 0;
for k = 1:numel(out.migrated)
    b = out.migrated{k}.toStruct();
    if strcmp(b.document_class.class_name, 'absolute_time_reference')
        v = b.absolute_time_reference.value;
        n = n + 1;
    end
end
assertEqual(testCase, n, 1, 'one absolute anchor');
end

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function fx = writerFixtures()
fx = {vhlabHours(), muscimolAtV1(), groupLinked(), haleyOnset(), dabTarget(), ...
    birrenCno(), drugAtSite(), birrenVirus(), virusAtV1(), ...
    babuTransfer(-72000), babuTransfer(NaN)};
end

function fx = didSideFixtures()
% the shapes testMigratorsJ / testFixtureCorpus use (snake `ontology_name`,
% the template's `location_ontologyNode`, `document_id` edges)
t1 = didTreatment('tr_d1', 'EMPTY:0000199', ...
    'treatment: grating direction-of-motion visual stimulation', 6.5, '');
t2 = didTreatment('tr_d2', 'CHEBI:5613', 'haloperidol', 2.5, 'uberon:0002436');
t3 = didTreatment('tr_d3', 'CHEBI:7035', 'muscimol', [], 'uberon:0002436');
t4 = didTreatment('tr_d4', '', 'cold exposure', 4.0, '');
d1 = didDrug('td_d1', 'CHEBI:5613,haloperidol,5', 'uberon:0002436', 'primary visual cortex');
d2 = didDrug('td_d2', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg']), 'UBERON:0001179', 'peritoneal cavity');
d2.treatment_drug.administration_onset_time = '2024-06-01T09:15:00Z';
d3 = didDrug('td_d3', sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIm:C0212364,clozapine N-oxide,1e-05,OM:MolarVolumeUnit,Molar']), 'NCIm:C0179246', 'bath');
v = struct();
v.document_class = struct('class_name', 'virus_injection', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v.base = struct('id', 'vi_d1', 'session_id', 'sess_09', ...
    'name', 'vi', 'datestamp', '2024-06-01T12:00:00.000Z');
v.virus_injection = struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'pAAV-hSyn-hChR2(H134R)-EYFP', 'dilution', 1000, ...
    'virusLocation_OntologyName', 'uberon:0002436', 'virusLocation_name', 'V1');
x = struct();
x.document_class = struct('class_name', 'treatment_transfer', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
x.depends_on = [ ...
    struct('name', 'recipient_id', 'document_id', 'rec_001'), ...
    struct('name', 'donor_id',     'document_id', 'don_002')];
x.base = struct('id', 'tt_d1', 'session_id', 'sess_09', ...
    'name', 'graft', 'datestamp', '2024-06-01T12:00:00.000Z');
x.treatment_transfer = struct('entity_ontologyNode', 'UBERON:0005291', ...
    'entity_name', 'embryonic tissue', 'method_name', 'transplantation');
fx = {t1, t2, t3, t4, d1, d2, d3, v, x};
end

function v1 = didTreatment(id, node, name, numeric, stringValue)
v1 = struct();
v1.document_class = struct('class_name', 'treatment', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', id, 'session_id', 'sess_09', ...
    'name', 'trt', 'datestamp', '2024-06-01T12:00:00.000Z');
t = struct('ontology_name', node, 'name', name);
if ~isempty(numeric); t.numeric_value = numeric; end
if ~isempty(stringValue); t.string_value = stringValue; end
v1.treatment = t;
end

function v1 = didDrug(id, mixture, locNode, locName)
v1 = struct();
v1.document_class = struct('class_name', 'treatment_drug', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
v1.depends_on = struct('name', {'subject_id'}, 'value', {'subj_007'});
v1.base = struct('id', id, 'session_id', 'sess_09', ...
    'name', 'td', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.treatment_drug = struct('mixture_table', mixture, ...
    'location_ontologyNode', locNode, 'location_name', locName);
end

% ----- writer shapes ---------------------------------------------------

function v1 = vhlabHours()
% treatmentMaker.create_treatment_doc, +vhlab/treatmentTable.m row 1: the
% looked-up node and label, numeric_value the hours, string_value ""
v1 = ndiDoc('treatment', '41268b6f5c6a3d4e_7a00000000000001', ...
    struct('ontologyName', 'EMPTY:0000199', ...
    'name', 'treatment: grating direction-of-motion visual stimulation', ...
    'string_value', '', 'numeric_value', 6.5), {'subject_id', 'subj_1'});
end

function v1 = muscimolAtV1()
% treatmentMaker.create_treatment_doc with a ChEBI substance whose
% string_value is the site CURIE (the Dab "Target Location" idiom)
v1 = ndiDoc('treatment', '41268b6f5c6a3d4e_7a00000000000002', ...
    struct('ontologyName', 'CHEBI:7035', 'name', 'muscimol', ...
    'string_value', 'UBERON:0002436', 'numeric_value', 2.5), {'subject_id', 'subj_1'});
end

function v1 = groupLinked()
% table2treatment: the second treatment of a group links the first by
% `manipulation_id`
v1 = ndiDoc('treatment', '41268b6f5c6a3d4e_7a00000000000003', ...
    struct('ontologyName', 'EMPTY:0000199', ...
    'name', 'treatment: grating direction-of-motion visual stimulation', ...
    'numeric_value', 3, 'string_value', ''), ...
    {'subject_id', 'subj_1', 'manipulation_id', '41268b6f5c6a3d4e_7a00000000000001'});
end

function v1 = haleyOnset()
% +haley/doImport: food restriction onset, numeric_value [], the time as text
v1 = ndiDoc('treatment', '41268b6f5c6a3d4e_7a00000000000004', ...
    struct('ontologyName', 'EMPTY:0000202', ...
    'name', 'treatment: food restriction onset time', ...
    'numeric_value', [], 'string_value', '2024-05-01T08:00:00'), {'subject_id', 'worm_1'});
end

function v1 = dabTarget()
% +dabrowska/doImport: the optogenetic target location
v1 = ndiDoc('treatment', '41268b6f5c6a3d4e_7a00000000000005', ...
    struct('ontologyName', 'EMPTY:0000074', ...
    'name', 'Optogenetic Tetanus Stimulation Target Location', ...
    'numeric_value', [], 'string_value', 'UBERON:0001880'), {'subject_id', 'rat_1'});
end

function v1 = birrenCno()
% treatmentMaker.create_treatment_drug_doc, +birren/TreatmentCreator.m
% Chronic_48h_Dreads: the bath, a writetablechar mixture, onset/offset as
% 'yyyy-MM-ddTHH:mm:ss', duration in days
mix = sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIm:C0212364,clozapine N-oxide,1e-05,OM:MolarVolumeUnit,Molar\n']);
v1 = ndiDoc('treatment_drug', '41268b6f5c6a3d4e_7b00000000000001', ...
    struct('location_ontologyName', 'NCIm:C0179246', 'location_name', 'bath', ...
    'mixture_table', mix, 'administration_onset_time', '2024-05-30T00:00:00', ...
    'administration_offset_time', '2024-06-01T00:00:00', 'administration_duration', 2), ...
    {'subject_id', 'culture_1'});
end

function v1 = drugAtSite()
% treatmentMaker.create_treatment_drug_doc at an UBERON site
mix = sprintf(['ontologyName,name,value,ontologyUnit,unitName\n' ...
    'NCIT:C227,alprazolam,0.25,SNOMED:396163008,mg/kg\n']);
v1 = ndiDoc('treatment_drug', '41268b6f5c6a3d4e_7b00000000000002', ...
    struct('location_ontologyName', 'UBERON:0001179', 'location_name', 'peritoneal cavity', ...
    'mixture_table', mix, 'administration_onset_time', '2024-06-01T09:15:00', ...
    'administration_offset_time', '2024-06-01T09:16:00', 'administration_duration', 1/1440), ...
    {'subject_id', 'rat_1'});
end

function v1 = birrenVirus()
% treatmentMaker.create_virus_injection_doc, +birren/TreatmentCreator.m
% neuronal_dreadds: the bath, no date, PND "3" (double() of the string),
% dilution 0, water as the diluent
v1 = ndiDoc('virus_injection', '41268b6f5c6a3d4e_7c00000000000001', ...
    struct('virus_OntologyName', 'AddGene:AAV9-hSyn-hM3D(Gq)-mCherry', ...
    'virus_name', 'AAV9-hSyn-hM3D(Gq)-mCherry', ...
    'virusLocation_OntologyName', 'NCIm:C0179246', 'virusLocation_name', 'bath', ...
    'virus_AdministrationDate', '', 'virus_AdministrationPND', 3, 'dilution', 0, ...
    'diluent_OntologyName', 'NCIm:C0043047', 'diluent_name', 'Water'), ...
    {'subject_id', 'culture_1'});
end

function v1 = virusAtV1()
% treatmentMaker.create_virus_injection_doc at a brain site, a dilution, a date
v1 = ndiDoc('virus_injection', '41268b6f5c6a3d4e_7c00000000000002', ...
    struct('virus_OntologyName', 'addgene:26973', ...
    'virus_name', 'pAAV-hSyn-hChR2(H134R)-EYFP', ...
    'virusLocation_OntologyName', 'UBERON:0002436', 'virusLocation_name', 'V1', ...
    'virus_AdministrationDate', '2024-05-02', 'virus_AdministrationPND', 21, ...
    'dilution', 1000, 'diluent_OntologyName', '', 'diluent_name', ''), ...
    {'subject_id', 'mouse_1'});
end

function v1 = babuTransfer(timestamp)
% treatmentMaker.create_treatment_transfer_doc from +babu/TreatmentCreator.m:
% timestamp seconds(hours(-TransferTime)) (NaN where none was recorded) on
% dev_local_time; the agar plate entity; the pick method; donor_id set
v1 = ndiDoc('treatment_transfer', sprintf('41268b6f5c6a3d4e_7d0000000000000%d', 1 + isnan(timestamp)), ...
    struct('timestamp', timestamp, 'clocktype', 'dev_local_time', ...
    'entity_name', 'agar plate medium', 'entity_ontologyNode', 'MICRO:0000480', ...
    'method_name', 'C. elegans transfer method: titanium pick', ...
    'method_ontologyNode', 'EMPTY:0000256'), ...
    {'recipient_id', 'worm_1', 'donor_id', 'plate_1'});
end

function v1 = ndiDoc(className, id, block, deps)
% ndi.document(className) from its template (+ base.json), as
% S.newdocument(className, className, block) writes it: base.session_id set,
% base.name left '', the class block REPLACED by the writer's struct, the
% template's depends_on entries kept and DEPS ({name, value, ...}) set in place
% (set_dependency_value); then the JSON round a corpus file goes through
tpl = loadTemplate(className);
baseTpl = loadTemplate('base');
v1 = struct();
v1.document_class = tpl.document_class;
v1.depends_on = tpl.depends_on;
for k = 1:2:numel(deps)
    hit = find(strcmp({v1.depends_on.name}, deps{k}), 1);
    v1.depends_on(hit).value = deps{k + 1};
end
if isfield(tpl, 'files')
    v1.files = tpl.files;
end
v1.base = baseTpl.base;
v1.base.id = id;
v1.base.session_id = '41268b6f5c6a3d4e_00000000000000a1';
v1.base.datestamp = '2024-06-01T12:00:00.000Z';
v1.(className) = block;
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
