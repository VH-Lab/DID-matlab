function tests = testRawV1RoundTripImage
%TESTRAWV1ROUNDTRIPIMAGE The imaging family read as raw v1, and its round trip:
%   imageStack, ontologyLabel and image (switched 2026-10-30).
%
%   Decided by Jess Haley, 2026-10-26 (did-schema
%   V_eta_go_forward_class_audit.md): [migrators read raw v1] (switched one
%   family at a time, did2.convert.rawV1Classes), [migration reliability
%   practices] (a) (a round trip per class, did2.convert.roundtrip.check),
%   [renames carry is temporary] (what universalRenames would discard is still
%   carried, carry-049), [image file details placed], [one-reading quick
%   answers] (Q3) and [dependents of a carried document carry]. The test of the
%   round trip is [lossless means round trip].
%
%   THE v1 DOCUMENTS are built from NDI's templates at the locked NDI-matlab
%   `main` (3cb19a8; tests/+did2/fixtures/ndi_templates, copied verbatim:
%   imageStack.json, imageStack_parameters.json, ontologyLabel.json,
%   base.json) in the shapes the two writers at that commit give them, and pass
%   through jsonencode/jsondecode as a corpus delivers them:
%     Haley behaviour  +setup/+conv/+haley/doImport.m, the plate loop: a video
%                      (YXT, uint8, EMPTY:0000129, NCIT:C190180), an arena mask
%                      and a bacteria mask (YX, logical, [0 1], EMPTY:0000130 /
%                      0000131, NCIT:C85437) and a closest-patch map (YX,
%                      uint8, EMPTY:0000132); `document_id` (the plate row) AND
%                      `subject_id` (the subject group) set
%     Haley E. coli    the image loop: an image (YX, its bit depth,
%                      EMPTY:0000133, NCIT:C70631), a mask and a map;
%                      `document_id` ONLY
%     Babu             +setup/+conv/+babu/import.m step 6: a video (YXT,
%                      'pixel,pixel,second', scale [1 1 FrameRate],
%                      EMPTY:0000257, NCIT:C190180) or an image (YX,
%                      EMPTY:0000258, NCIT:C70631); `subject_id` ONLY
%   The template merge sorts the edges (document_id, subject_id), as every JH
%   corpus document has them. The 7,007 JH imageStacks of the corpora are the
%   Haley shapes: 2,444 behaviour (carried, carry-052) and 4,563 E. coli
%   (passed through); no corpus holds a Babu stack (census of the corpus zips,
%   2026-10-27).
%     image            no writer at the locked main constructs one, and no corpus
%                      holds one: data/image.json (copied verbatim from NDI-matlab
%                      441530d0) merged with imageStack_parameters.json and
%                      base.json, the edges sorted and unique (document_id,
%                      imageCollection_id, subject_id), with a Babu-image-like
%                      parameters block. Its round trip is [image raw round
%                      trip and single-read keys] (Jess Haley, 2026-10-30).
%
%   WHAT V2 DOES NOT KEEP is listed per fixture as KNOWN FINDINGS: open
%   questions for the team, not rules made here. Each fixture's lost paths
%   must be EXACTLY its listed findings.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the known findings ===============================

function f = knownFindings()
% {fixture, path, why}. Open questions, reported to the team; nothing here is
% decided. EMPTY since 2026-10-27: the axis letters (`dimension_order`), the
% three findings listed here before, are derived from the labels through a
% fixed table ([axis letters derive from labels], Jess Haley; did2.convert.axisLetter).
f = cell(0, 3);
end

function paths = findingsFor(fixture)
f = knownFindings();
paths = reshape(sort(f(strcmp(f(:, 1), fixture), 2)), 1, []);
end

function testTheAxisLettersDeriveFromTheLabels(testCase)
% [axis letters derive from labels] (Decided by Jess Haley, 2026-10-27,
% did-schema V_eta_go_forward_class_audit.md): `dimension_order` is not
% stored; the round trip derives each letter from the dimension's label
% through a fixed table, and "a video or image whose labels do not map
% one-to-one onto its v1 letters is carried whole as v1" (carry-114)
for kind = {'video', 'image'}
    v1 = babuStack(['is_ax_' kind{1}], kind{1});
    r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
    verifyTrue(testCase, any(strcmp('imageStack_parameters.dimension_order', r.matched)), kind{1});
end
verifyEqual(testCase, did2.convert.axisLetter('height'), 'Y');
verifyEqual(testCase, did2.convert.axisLetter('Width'), 'X');
verifyEqual(testCase, did2.convert.axisLetter(struct('node', 'om:Time', 'name', 'time')), 'T');
verifyEqual(testCase, did2.convert.axisLetter('gene'), '');
bad = {'width,height', 'height,gene', 'height,width,time'};
for k = 1:numel(bad)
    v1 = babuStack(sprintf('is_axbad_%d', k), 'image');
    v1.imageStack_parameters.dimension_labels = bad{k};
    v1 = jsondecode(jsonencode(v1));
    out = runRaw(v1);
    verifyCarriedUntouched(testCase, v1, out, bad{k});
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-114] '), d);
end
end

function testAStackNameIsTheBodysFreeText(testCase)
% [image stack name goes to notes] (Decided by Jess Haley, 2026-10-27): a
% non-empty v1 base.name is written to the data body's free text, `notes`
% ([one free-text field: notes]), and the round trip reads it back
v1 = babuStack('is_named', 'image');
v1.base.name = 'plate 3, 10x';
v1 = jsondecode(jsonencode(v1));
out = runRaw(v1);
verifyEmpty(testCase, out.passthrough);
b = [];
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.className(), 'sampled_body')
        b = out.migrated{k}.toStruct();
    end
end
assertNotEmpty(testCase, b);
verifyEqual(testCase, did2.unittest.helpers.notesOf(b.data_body), 'plate 3, 10x');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyTrue(testCase, any(strcmp('base.name', r.matched)));
verifyRoundTrip(testCase, r, 'named stack', {});
end

function testEveryKnownFindingNamesAFixtureThatIsRun(testCase)
f = knownFindings();
names = {'Babu video', 'Babu image', 'DID brightfield, labels'};
for k = 1:size(f, 1)
    verifyTrue(testCase, any(strcmp(f{k, 1}, names)), f{k, 1});
end
end

% ===================== the switch ======================================

function testImageStackLabelAndImageAreSwitched(testCase)
% INVERTED 2026-10-30 (was testImageStackAndLabelAreSwitchedAndImageIsNot, which
% asserted `image` stays on the renamed path): [migrators read raw v1] (Decided
% by Jess Haley, 2026-10-26, did-schema V_eta_go_forward_class_audit.md)
% switches every class, and the `image` tombstone that kept it renamed was
% deleted on 2026-10-28 ([carried v1 validates against NDI templates])
names = did2.convert.rawV1Classes();
verifyTrue(testCase, any(strcmp(names, 'imageStack')));
verifyEqual(testCase, did2.convert.rawV1Classes('imageStack'), 'image_stack');
verifyTrue(testCase, any(strcmp(names, 'ontologyLabel')));
verifyEqual(testCase, did2.convert.rawV1Classes('ontologyLabel'), 'ontology_label');
verifyTrue(testCase, any(strcmp(names, 'image')));
verifyEqual(testCase, did2.convert.rawV1Classes('image'), 'image');
r = runRaw({babuStack('is_b1', 'video'), haleyLabel('lab_1', 'is_b1', 'EMPTY:0000257'), ...
    imageDoc('im_b1', 'tiff')});
L = r.summary.legacy_ndi_document;
verifyEqual(testCase, L.bodies_read_raw_v1, 3, 'the stack, the label and the image are read raw');
verifyEqual(testCase, L.bodies_reaching_universal_renames, 0);
verifyEqual(testCase, L.bodies_unreached, 0);
end

% ===================== image: converted, read raw ========================

function testAnImageConvertsAndRoundTrips(testCase)
% [image raw round trip and single-read keys] (Decided by Jess Haley,
% 2026-10-30, did-schema V_eta_go_forward_class_audit.md, G42): "a raw-v1
% round trip is built for `image` when `image` moves to the raw-v1 path,
% carrying the label back and rebuilding `format` 'tiff' from
% EDAM:format_3591"
v1 = imageDoc('im_conv', 'tiff');
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEmpty(testCase, out.passthrough, 'converted, not carried');
verifyEqual(testCase, numel(out.migrated), 3, 'observation, sampled_body, anchor');
obs = [];
body = [];
for k = 1:numel(out.migrated)
    switch out.migrated{k}.className()
        case 'observation', obs = out.migrated{k}.toStruct();
        case 'sampled_body', body = out.migrated{k}.toStruct();
    end
end
assertNotEmpty(testCase, obs);
assertNotEmpty(testCase, body);
verifyEqual(testCase, char(obs.statement.notes), v1.image.label, 'the label is the notes');
verifyEqual(testCase, char(body.data_body.format.node), 'EDAM:format_3591');
% either shape: the char, or the {term, parameters} block ([compression block
% and empty levels] (1))
verifyEqual(testCase, did2.build.compressionCodec(body.data_body.compression), 'lzw');
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
verifyRoundTrip(testCase, r, 'image', {});
accounted = [r.matched, r.not_set, r.restated, r.equivalent];
P = 'imageStack_parameters.';
for p = {'base.id', 'base.session_id', 'base.datestamp', 'document_class.class_name', ...
        'depends_on(1).value', 'depends_on(2).value', 'depends_on(3).value', ...
        'image.label', 'image.format', 'image.compression', ...
        [P 'dimension_labels'], [P 'dimension_size'], [P 'dimension_scale'], ...
        [P 'dimension_scale_units'], [P 'data_type'], [P 'data_limits'], ...
        [P 'timestamp'], [P 'clocktype'], 'files.file_list'}
    verifyTrue(testCase, any(strcmp(p{1}, accounted)), sprintf('image: %s is not accounted for', p{1}));
end
verifyTrue(testCase, any(strcmp('image.format', r.matched)), ...
    'the format tiff is rebuilt from EDAM:format_3591');
verifyTrue(testCase, any(strcmp('image.label', r.matched)), 'the label comes back');
end

function testAnImageFormatGivenAsItsNodeRoundTrips(testCase)
% the format stated as the CURIE, or as the registry label in another case: the
% body holds the node, and the round trip compares the v1 text with the node
% or the registry label, ignoring case
fmts = {'EDAM:format_3591', 'TIFF'};
for k = 1:numel(fmts)
    v1 = imageDoc(sprintf('im_fmt_%d', k), fmts{k});
    r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
    verifyRoundTrip(testCase, r, ['format ' fmts{k}], {});
    verifyTrue(testCase, any(strcmp('image.format', [r.matched, r.equivalent])), fmts{k});
end
end

function testAChangedImageFieldIsReportedLost(testCase)
% the round trip can fail: a changed label or compression is named
v1 = imageDoc('im_lost', 'tiff');
out = runRaw(v1);
for f = {'label', 'compression'}
    v1b = v1;
    v1b.image.(f{1}) = 'something else';
    r = did2.convert.roundtrip.check(v1b, out.migrated);
    verifyFalse(testCase, r.ok, f{1});
    verifyTrue(testCase, any(strcmp(['image.' f{1}], {r.lost.path})), f{1});
end
end

function testASubjectlessImagePassesThroughAndRoundTrips(testCase)
% the template's empty subject_id: no subject, so the untouched raw source
% passes through (no `image` tombstone since 2026-10-28: counted, not
% validated), and the passthrough inverse reads it back
v1 = jsondecode(jsonencode(setEdge(imageDoc('im_nosub', 'tiff'), 'subject_id', '')));
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
verifyEqual(testCase, numel(out.passthrough), 1, 'a pass-1 passthrough');
emitted = out.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.class_name, 'image');
verifyEqual(testCase, emitted.imageStack_parameters, v1.imageStack_parameters, ...
    'the passthrough is the raw v1 source');
verifyEqual(testCase, emitted.image, v1.image);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyFalse(testCase, r.carried);
verifyRoundTrip(testCase, r, 'subject-less image', {});
end

function testAnImageCarriesOnTheRawShapeAsTheRenamedOneDid(testCase)
% a collection edge (carry-153), a parameters block beside a different
% snake_case twin (what universalRenames would discard: carry-049)
coll = setEdge(imageDoc('im_coll', 'tiff'), 'imageCollection_id', 'coll_1');
twin = imageDoc('im_twin', 'tiff');
twin.image_stack_parameters = twin.imageStack_parameters;
twin.image_stack_parameters.clocktype = 'dev_local_time';
cases = {'collection', coll, '[carry-153] malformed: '; 'parameters twin', twin, '[carry-100] '};
for k = 1:size(cases, 1)
    [label, v1, row] = cases{k, :};
    v1 = jsondecode(jsonencode(v1));
    out = runRaw(v1);
    verifyCarriedUntouched(testCase, v1, out, label);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, row), [label ': ' d]);
    old = runRenamed(v1);
    verifyEqual(testCase, old.migrated{1}.get('document_class.schema_version'), 'did_v1', ...
        [label ': the renamed path carried it too']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
end
end

function testATimestampTheSuperclassMigratorRefusesStillQuarantinesAnImage(testCase)
% the superclass migrator's refusals run on a raw image's parameters block too
v1 = imageDoc('im_ts', 'tiff');
v1.imageStack_parameters.timestamp = [739038.5; 739039.5];
raw = runRaw(v1);
verifyEqual(testCase, numel(raw.quarantine), 1);
verifyEqual(testCase, raw.quarantine(1).identifier, ...
    'did2:convert:imageStackParametersNonScalarTimestamp');
verifyEqual(testCase, numel(runRenamed(v1).quarantine), 1, 'renamed: refused too');
end

function testTheImageSwitchChangesNoOutcome(testCase)
% converted: the same documents on both paths (ids are deterministic); a
% passthrough on both, the raw one the untouched v1 source with the same edges
% and identity
nosub = jsondecode(jsonencode(setEdge(imageDoc('im_s_ns', 'tiff'), 'subject_id', '')));
fixtures = {imageDoc('im_s_conv', 'tiff'), nosub};
for k = 1:numel(fixtures)
    v1 = fixtures{k};
    raw = runRaw(v1);
    old = runRenamed(v1);
    label = sprintf('image fixture %d (%s)', k, v1.base.id);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEmpty(testCase, old.quarantine, label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), label);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    if ~isempty(raw.passthrough)
        a = raw.migrated{1}.toStruct();
        b = old.migrated{1}.toStruct();
        verifyEqual(testCase, edgeMap(a), edgeMap(b), [label ': the edges differ']);
        verifyEqual(testCase, a.base, b.base, [label ': the identity differs']);
        continue;
    end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        a = raw.migrated{j}.toStruct();
        b = old.migrated{j}.toStruct();
        verifyTrue(testCase, isequaln(a, b), sprintf('%s, document %d: raw %s; renamed %s', ...
            label, j, jsonencode(a), jsonencode(b)));
    end
end
end

function testTheLabelClassHelperAcceptsBothSpellings(testCase)
f = @did2.convert.isOntologyLabelClass;
verifyTrue(testCase, f('ontologyLabel'));
verifyTrue(testCase, f('ontology_label'));
verifyTrue(testCase, f("ontologyLabel"));
verifyFalse(testCase, f('ontologylabel'));
verifyFalse(testCase, f('imageStack'));
verifyFalse(testCase, f(''));
verifyFalse(testCase, f([]));
verifyFalse(testCase, f({'ontologyLabel'}));
end

% ===================== Haley behaviour: carried, carry-052 ===============

function testHaleyBehaviourStacksAreCarriedAndRoundTrip(testCase)
for kind = {'video', 'arena mask', 'bacteria mask', 'closest patch'}
    v1 = haleyBehaviourStack(['is_' strrep(kind{1}, ' ', '_')], kind{1});
    out = runRaw(v1);
    label = ['Haley behaviour ' kind{1}];
    verifyCarriedUntouched(testCase, v1, out, label);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    % [image stack link needs mapping] (Jess Haley, 2026-10-27, did-schema
    % V_eta_go_forward_class_audit.md): the edge is carried needs_mapping
    verifyTrue(testCase, startsWith(d, '[carry-052] needs_mapping: '), [label ': ' d]);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
end
end

% ===================== Haley E. coli: passed through =====================

function testHaleyEColiStacksPassThroughAndRoundTrip(testCase)
for kind = {'image', 'mask', 'closest patch'}
    v1 = haleyEColiStack(['is_e_' strrep(kind{1}, ' ', '_')], kind{1});
    out = runRaw(v1);
    label = ['Haley E. coli ' kind{1}];
    verifyEmpty(testCase, out.quarantine, label);
    verifyEqual(testCase, numel(out.migrated), 1, label);
    verifyEqual(testCase, numel(out.passthrough), 1, [label ': a pass-1 passthrough']);
    verifyFalse(testCase, isfield(out.summary.migration_notes, 'carried_as_v1') ...
        && out.summary.migration_notes.carried_as_v1.count > 0, ...
        [label ': no carry note (today''s behaviour: a stack with no subject passes through)']);
    emitted = out.migrated{1}.toStruct();
    verifyEqual(testCase, emitted.document_class.class_name, 'imageStack', label);
    verifyEqual(testCase, emitted.imageStack_parameters, v1.imageStack_parameters, ...
        [label ': the passthrough is the raw v1 source']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, {});
end
end

function testAnEColiStackWithNoTimestampIsTheUntouchedSource(testCase)
% the template's own [] placeholder: the renamed path's superclass migrator
% stripped it so the passthrough validated under the `image_stack` tombstone;
% the raw passthrough is the v1 source, kept as v1 wrote it
v1 = haleyEColiStack('is_e_nots', 'image');
v1.imageStack_parameters.timestamp = [];
out = runRaw(v1);
verifyEmpty(testCase, out.quarantine);
emitted = out.migrated{1}.toStruct();
verifyTrue(testCase, isfield(emitted.imageStack_parameters, 'timestamp'));
verifyRoundTrip(testCase, did2.convert.roundtrip.check(v1, out.migrated), ...
    'E. coli, empty timestamp', {});
end

% ===================== Babu: converted ===================================

function testBabuStacksConvertAndRoundTrip(testCase)
cases = {'Babu video', babuStack('is_b_v', 'video'); ...
    'Babu image', babuStack('is_b_i', 'image')};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, not carried']);
    verifyEqual(testCase, numel(out.migrated), 3, [label ': observation, sampled_body, anchor']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyFalse(testCase, r.carried, label);
    verifyRoundTrip(testCase, r, label, findingsFor(label));
    accounted = [r.matched, r.not_set, r.restated, r.equivalent];
    P = 'imageStack_parameters.';
    for p = {'base.id', 'base.session_id', 'base.datestamp', 'document_class.class_name', ...
            'depends_on(2).value', 'imageStack.label', 'imageStack.formatOntology', ...
            [P 'dimension_labels'], [P 'dimension_size'], [P 'dimension_scale'], ...
            [P 'dimension_scale_units'], [P 'data_type'], [P 'data_limits'], ...
            [P 'timestamp'], [P 'clocktype'], 'files.file_list'}
        verifyTrue(testCase, any(strcmp(p{1}, accounted)), ...
            sprintf('%s: %s is not accounted for', label, p{1}));
    end
    verifyTrue(testCase, any(strcmp([P 'data_limits'], r.restated)), ...
        [label ': the type''s range is left unwritten and restated']);
end
end

function testAConvertedStackOnCoordinateAxesKeepsItsOrder(testCase)
% no dimension_labels: each axis is named by its letter's term (X, Y: the
% coordinate nodes did2.convert.axisTerm writes), so the order IS recoverable
v1 = didBrightfield('is_d_xy', '');
out = runRaw(v1);
verifyEmpty(testCase, out.passthrough);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r, 'DID brightfield, letters', {});
v1 = didBrightfield('is_d_lab', 'height,width');
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyRoundTrip(testCase, r, 'DID brightfield, labels', findingsFor('DID brightfield, labels'));
end

function testAValueRangeOtherThanTheTypesRoundTrips(testCase)
v1 = didBrightfield('is_d_rng', '');
v1.imageStack_parameters.data_limits = [10; 200];
out = runRaw(v1);
verifyEmpty(testCase, out.passthrough);
r = did2.convert.roundtrip.check(v1, out.migrated);
verifyRoundTrip(testCase, r, 'value range', {});
% kept as the pair: matched (same shape) or equivalent (another shape)
verifyTrue(testCase, any(strcmp('imageStack_parameters.data_limits', [r.matched, r.equivalent])));
end

function testTheAcquisitionTimeRoundTripsOnEveryClock(testCase)
% [acquisition time on its clock] (Decided by Jess Haley, 2026-10-30, did-schema
% V_eta_go_forward_class_audit.md): a UTC clock's datenum is the observation's
% time reference on clock utc, in seconds; any other clock keeps the datenum as
% the AFO:AFR_0001158 "acquisition time" condition's source_value, its
% canonical listed as a gap in the migration report. Every clock reads back as v1 wrote it.
clocks = {'utc', 'approx_utc', 'exp_global_time', 'approx_exp_global_time', ...
    'dev_local_time', 'no_time', ''};
for k = 1:numel(clocks)
    v1 = babuStack(sprintf('is_b_clk%d', k), 'image');
    v1.imageStack_parameters.clocktype = clocks{k};
    out = runRaw(v1);
    label = sprintf('clock "%s"', clocks{k});
    verifyEmpty(testCase, out.quarantine, label);
    verifyEmpty(testCase, out.passthrough, [label ': converted, not carried']);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyRoundTrip(testCase, r, label, {});
    P = 'imageStack_parameters.';
    accounted = [r.matched, r.not_set, r.restated, r.equivalent];
    verifyTrue(testCase, any(strcmp([P 'timestamp'], accounted)), [label ': timestamp']);
    verifyTrue(testCase, any(strcmp([P 'clocktype'], accounted)), [label ': clocktype']);
end
end

function testAUtcAcquisitionTimeIsAnAbsoluteInstant(testCase)
% [UTC acquisition time is absolute] (Decided by Jess Haley, 2026-10-31,
% did-schema did_v2_go_forward_class_audit.md; docs/V2_PLAN.md G65: "That
% should be an absolute time reference"): on a UTC clock the acquisition time
% is the observation's absolute_time_reference holding the UTC instant, the
% datenum kept as start.source_value -- not a relative_time_reference to the
% session. approx_utc adds a 5 s clock_tolerance. Any other clock keeps the
% session anchor.
cases = {'utc', []; 'approx_utc', 5};
for k = 1:size(cases, 1)
    v1 = babuStack(sprintf('is_b_abs%d', k), 'image');
    v1.imageStack_parameters.clocktype = cases{k, 1};
    v1.imageStack_parameters.timestamp = 739321.4166666666;
    out = runRaw(v1);
    label = sprintf('clock "%s"', cases{k, 1});
    verifyEmpty(testCase, out.quarantine, label);
    names = cellfun(@(d) d.className(), out.migrated, 'UniformOutput', false);
    verifyFalse(testCase, any(strcmp(names, 'relative_time_reference')), ...
        [label ': no relative reference to the session']);
    i = find(strcmp(names, 'absolute_time_reference'));
    assertNumElements(testCase, i, 1, label);
    a = out.migrated{i}.toStruct();
    obs = out.migrated{strcmp(names, 'observation')}.toStruct();
    ids = {};
    for e = 1:numel(obs.depends_on)
        dep = obs.depends_on(e);
        if ~strcmp(dep.name, 'time_reference_id'); continue; end
        if isfield(dep, 'document_id') && ~isempty(dep.document_id)
            ids{end+1} = char(dep.document_id); %#ok<AGROW>
        elseif isfield(dep, 'value')
            ids{end+1} = char(dep.value); %#ok<AGROW>
        end
    end
    verifyTrue(testCase, any(strcmp(ids, a.base.id)), ...
        [label ': the observation''s time reference']);
    verifyEqual(testCase, char(a.absolute_time_reference.value.start.utc), ...
        '2024-03-10T10:00:00.000Z', label);
    verifyEqual(testCase, str2double(a.absolute_time_reference.value.start.source_value), ...
        739321.4166666666, [label ': the datenum as v1 wrote it']);
    if isempty(cases{k, 2})
        verifyFalse(testCase, isfield(a, 'time_reference') && isfield(a.time_reference, 'clock_tolerance') ...
            && ~isempty(a.time_reference.clock_tolerance), label);
    else
        verifyEqual(testCase, a.time_reference.clock_tolerance.seconds, cases{k, 2}, label);
    end
    did2.schema.cache.shared().validateDocument(a);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyRoundTrip(testCase, r, label, {});
end
end

% ===================== the other carries, on the raw shape ===============

function testTheRawShapeCarriesAsTheRenamedOneDid(testCase)
% a mask with a subject and no plate row (carry-154 since [Haley mask words
% leave the generic stage], 2026-10-30; carry-025 before), a collection edge
% (carry-153 since [image collection carried until a writer], 2026-10-30;
% an awaiting_home row before), a data_limits that is not a pair (carry-012)
mask = haleyBehaviourStack('is_m', 'arena mask');
mask.depends_on(1).value = '';
coll = babuStack('is_c', 'image');
coll.depends_on(end+1) = struct('name', 'imageCollection_id', 'value', 'coll_1');
lim = babuStack('is_l', 'image');
lim.imageStack_parameters.data_limits = 'not a pair';
cases = {'mask', mask, '[carry-154] '; 'collection', coll, '[carry-153] malformed: '; ...
    'limits', lim, '[carry-012] '};
for k = 1:size(cases, 1)
    [label, v1, row] = cases{k, :};
    v1 = jsondecode(jsonencode(v1));
    out = runRaw(v1);
    verifyCarriedUntouched(testCase, v1, out, label);
    d = out.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, contains(d, row), [label ': ' d]);
    old = runRenamed(v1);
    verifyEqual(testCase, old.migrated{1}.get('document_class.schema_version'), 'did_v1', ...
        [label ': the renamed path carried it too']);
    verifyRoundTrip(testCase, did2.convert.roundtrip.check(v1, out.migrated), label, {});
end
end

function testATimestampTheSuperclassMigratorRefusesStillQuarantines(testCase)
% the superclass migrator's refusals (+super/image_stack_parameters), called by
% the leaf on the raw block: the same documents quarantine, with its identifiers
cases = {[739038.5; 739039.5], 'did2:convert:imageStackParametersNonScalarTimestamp'; ...
    '2024-06-01', 'did2:convert:imageStackParametersCharTimestamp'};
for k = 1:size(cases, 1)
    v1 = haleyEColiStack(sprintf('is_t%d', k), 'image');
    v1.imageStack_parameters.timestamp = cases{k, 1};
    raw = runRaw(v1);
    old = runRenamed(v1);
    verifyEqual(testCase, numel(raw.quarantine), 1, cases{k, 2});
    verifyEmpty(testCase, raw.migrated, cases{k, 2});
    verifyEqual(testCase, raw.quarantine(1).identifier, cases{k, 2});
    verifyEqual(testCase, numel(old.quarantine), 1, ['renamed: ' cases{k, 2}]);
end
end

% ===================== what universalRenames would discard ===============

function testWhatTheRenamesWouldDiscardIsCarriedOnBothPaths(testCase)
ver = babuStack('is_v', 'video');
deps = num2cell(ver.depends_on);
for k = 1:numel(deps)
    deps{k}.version = '';
end
deps{2}.version = 2;
ver.depends_on = [deps{:}];
fmt = babuStack('is_f', 'video');
fmt.imageStack.format_ontology = 'NCIT:C70631';
blk = babuStack('is_k', 'video');
blk.image_stack_parameters = blk.imageStack_parameters;
blk.image_stack_parameters.clocktype = 'dev_local_time';
cases = {'depends_on version', ver; 'formatOntology twin', fmt; 'parameters block twin', blk};
for k = 1:size(cases, 1)
    [label, v1] = cases{k, :};
    v1 = jsondecode(jsonencode(v1));
    raw = runRaw(v1);
    old = runRenamed(v1);
    verifyCarriedUntouched(testCase, v1, raw, label);
    d = raw.summary.migration_notes.carried_as_v1.distinct_details{1};
    verifyTrue(testCase, startsWith(d, '[carry-100] '), [label ': ' d]);
    verifyEqual(testCase, numel(old.passthrough), 1, [label ': renamed path carried it']);
    verifyEqual(testCase, old.migrated{1}.get('document_class.schema_version'), 'did_v1', label);
end
end

% ===================== the switch changes no outcome ======================

function testTheSwitchChangesNoOutcome(testCase)
% a converted document is the one the renamed path converted (ids are
% deterministic, practice (b)); a carry is carried on both paths; a passthrough
% passes through on both, the raw one the untouched v1 source with the same
% edges and identity
fixtures = {babuStack('is_b_v', 'video'), babuStack('is_b_i', 'image'), ...
    didBrightfield('is_d_xy', ''), didBrightfield('is_d_lab', 'height,width'), ...
    haleyBehaviourStack('is_h_v', 'video'), haleyBehaviourStack('is_h_c', 'closest patch'), ...
    haleyEColiStack('is_e_i', 'image'), haleyEColiStack('is_e_m', 'mask')};
for k = 1:numel(fixtures)
    v1 = fixtures{k};
    raw = runRaw(v1);
    old = runRenamed(v1);
    label = sprintf('fixture %d (%s)', k, v1.base.id);
    verifyEmpty(testCase, raw.quarantine, label);
    verifyEmpty(testCase, old.quarantine, label);
    verifyEqual(testCase, numel(raw.passthrough), numel(old.passthrough), [label ': passed through on one path only']);
    verifyEqual(testCase, numel(raw.migrated), numel(old.migrated), label);
    if ~isempty(raw.passthrough)
        a = raw.migrated{1}.toStruct();
        b = old.migrated{1}.toStruct();
        verifyEqual(testCase, a.document_class.schema_version, b.document_class.schema_version, label);
        verifyEqual(testCase, edgeMap(a), edgeMap(b), [label ': the edges differ']);
        verifyEqual(testCase, a.base, b.base, [label ': the identity differs']);
        continue;
    end
    for j = 1:min(numel(raw.migrated), numel(old.migrated))
        a = raw.migrated{j}.toStruct();
        b = old.migrated{j}.toStruct();
        verifyTrue(testCase, isequaln(a, b), sprintf('%s, document %d: raw %s; renamed %s', ...
            label, j, jsonencode(a), jsonencode(b)));
    end
end
end

% ===================== the round trip can fail ===========================

function testAChangedScaleIsReportedLost(testCase)
v1 = babuStack('is_b_x', 'video');
out = runRaw(v1);
v1b = v1;
v1b.imageStack_parameters.dimension_scale(3) = 99;
r = did2.convert.roundtrip.check(v1b, out.migrated);
verifyFalse(testCase, r.ok);
verifyEqual(testCase, sort({r.lost.path}), ...
    sort([{'imageStack_parameters.dimension_scale'}, findingsFor('Babu video')]));
end

function testAFieldOutsideTheTemplateIsReportedLost(testCase)
% OPEN (a team question): the fold reads the template's fields only, and the
% register has no imageStack row for a field it has no home for (as carry-056
% is for a calculator), so one more field is dropped on both paths, as before
% the switch; the round trip names it
v1 = babuStack('is_b_extra', 'image');
v1.imageStack.magnification = 40;
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyFalse(testCase, r.ok);
verifyTrue(testCase, any(strcmp('imageStack.magnification', {r.lost.path})));
end

function testANonEmptyBaseNameIsKept(testCase)
% INVERTS testANonEmptyBaseNameIsReportedLost: [image stack name goes to
% notes] (Decided by Jess Haley, 2026-10-27) answers the open question -- the
% name is the data body's free text, so the round trip keeps it
v1 = babuStack('is_b_name', 'image');
v1.base.name = 'worm plate 3';
r = did2.convert.roundtrip.check(v1, runRaw(v1).migrated);
verifyFalse(testCase, any(strcmp('base.name', {r.lost.path})));
verifyTrue(testCase, any(strcmp('base.name', r.matched)));
end

function testADroppedBodyIsUnplaced(testCase)
v1 = babuStack('is_b_drop', 'video');
out = runRaw(v1);
kept = {};
for k = 1:numel(out.migrated)
    if ~strcmp(out.migrated{k}.className(), 'sampled_body')
        kept{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
r = did2.convert.roundtrip.check(v1, kept);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

function testAnExtraDocumentIsUnplaced(testCase)
v1 = babuStack('is_b_one', 'video');
out = runRaw(v1);
other = runRaw(babuStack('is_b_two', 'image')).migrated;
r = did2.convert.roundtrip.check(v1, [out.migrated, other(1)]);
verifyFalse(testCase, r.ok);
verifyNotEmpty(testCase, r.unplaced);
end

% ===================== ontologyLabel: switched ===========================

function testLabelsFollowTheirStack(testCase)
% the default path: a label on a carried stack is carried (carry-064); a label
% on a stack that passes through is handed to NDI's second pass as v1 wrote it
% (NDI finds it under either name, ndi.migrate.internal.isOntologyLabelClass)
beh = haleyBehaviourStack('is_h1', 'video');
eco = haleyEColiStack('is_e1', 'image');
labH = haleyLabel('lab_h1', 'is_h1', 'EMPTY:0000129');
labE = haleyLabel('lab_e1', 'is_e1', 'EMPTY:0000133');
out = runRaw({beh, labH, eco, labE});
verifyEmpty(testCase, out.quarantine);
lh = docWithId(out, 'lab_h1');
le = docWithId(out, 'lab_e1');
verifyEqual(testCase, lh.document_class.schema_version, 'did_v1', 'a label on a carried stack is carried');
verifyEqual(testCase, le.document_class.class_name, 'ontologyLabel', ...
    'the label is switched: it keeps its v1 class name');
verifyEqual(testCase, le.ontologyLabel, labE.ontologyLabel, 'the v1 block is untouched');
verifyEqual(testCase, edgeMap(le).document_id, 'is_e1', 'the label''s only join');
d = out.summary.migration_notes.carried_as_v1.distinct_details;
verifyTrue(testCase, any(startsWith(d, '[carry-064] ')), strjoin(d, ' | '));
verifyOneRecordPerSource(testCase, out, 'default path');
end

function testACarriedLabelHasOnePassthroughRecord(testCase)
% THE DUPLICATE-RECORD CONCERN. A label is a pass-1 passthrough (its migrator
% hands it back with no carry note), so the loop records it; a label on a
% carried stack is then carried by carryDependents (carry-064), which recorded
% it again, and NDI's carryUnchangedAsV1 counted the one document twice. One
% record per source, on both paths, and the record is the carried v1 body.
beh = haleyBehaviourStack('is_h3', 'video');
lab = haleyLabel('lab_h3', 'is_h3', 'EMPTY:0000129');
paths = {{}, {'RawV1Classes', {}}};
pathName = {'raw', 'renamed'};
for p = 1:numel(paths)
    out = did2.convert.v1_to_v2({beh, lab}, 'Validate', false, ...
        'TargetVersion', 'did_v2', paths{p}{:});
    verifyEmpty(testCase, out.quarantine, pathName{p});
    verifyEqual(testCase, numel(out.migrated), 2, pathName{p});
    ids = {out.passthrough.id};
    verifyEqual(testCase, sum(strcmp(ids, 'lab_h3')), 1, ...
        [pathName{p} ': the carried label has more than one passthrough record']);
    verifyEqual(testCase, numel(out.passthrough), 2, pathName{p});
    rec = out.passthrough(strcmp(ids, 'lab_h3'));
    verifyEqual(testCase, rec.body.document_class.schema_version, 'did_v1', ...
        [pathName{p} ': the record is not the carried body']);
    verifyEqual(testCase, rec.input_index, 2, pathName{p});
    verifyEqual(testCase, out.summary.passthrough_count, 2, pathName{p});
end
end

function testTheRenamedPathStillRenamesTheLabel(testCase)
% 'RawV1Classes', {} runs the label as before the switch
eco = haleyEColiStack('is_e2', 'image');
out = runRenamed({eco, haleyLabel('lab_e2', 'is_e2', 'EMPTY:0000133')});
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, docWithId(out, 'lab_e2').document_class.class_name, 'ontology_label');
end

function testTheGenericFileFoldReadsARawLabel(testCase)
% did2.convert.foldGenericFiles finds the sibling label under either class name
% (did2.convert.isOntologyLabelClass) and reads its node from either block
% spelling: the raw v1 label folds the file exactly as the renamed one did
node = 'EDAM:data_1286';
raw = haleyLabel('gf_lbl', 'gf_1', node);
renamed = raw;
renamed.document_class.class_name = 'ontology_label';
renamed = rmfield(renamed, 'ontologyLabel');
renamed.ontology_label = struct('ontology_node', node);
for c = {{'raw', raw}, {'renamed', renamed}}
    label = c{1}{1};
    result = struct('migrated', {{did2.document(foldSubject('gf_subj')), ...
        did2.document(foldGenericFile('gf_1', 'gf_subj')), did2.document(c{1}{2})}}, ...
        'quarantine', struct('original_body', {}, 'class_name', {}, ...
        'identifier', {}, 'reason', {}, 'failed_at', {}));
    [result, rep] = did2.convert.foldGenericFiles(result, 'Validate', false, ...
        'TargetVersion', 'did_v2');
    verifyEqual(testCase, rep.ontology_labels_seen, 1, label);
    verifyEqual(testCase, rep.labels_pointing_at_a_file, 1, label);
    verifyEqual(testCase, rep.files_folded, 1, label);
    verifyEqual(testCase, rep.refused_label_node_empty, 0, label);
    verifyEqual(testCase, rep.labels_modified, 0, label);
    verifyEqual(testCase, rep.labels_deleted, 0, label);
    verifyEqual(testCase, docWithId(result, 'gf_lbl'), ...
        did2.document(c{1}{2}).toStruct(), [label ': the label was touched']);
    folded = docWithId(result, 'gf_1');
    verifyNotEqual(testCase, folded.document_class.class_name, 'generic_file', label);
    verifyTrue(testCase, contains(jsonencode(folded), node), ...
        [label ': the folded statement does not carry the label''s node']);
end
end

function testAWriterShapedLabelReadRawRoundTrips(testCase)
% the default path (the label is switched): handed back untouched, round trip
% exact
for node = {'EMPTY:0000129', 'EMPTY:0000131', 'EMPTY:0000257'}
    v1 = haleyLabel(['lab_' node{1}(end-2:end)], 'is_x', node{1});
    out = runRaw(v1);
    verifyEmpty(testCase, out.quarantine, node{1});
    verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
    verifyEqual(testCase, numel(out.passthrough), 1, node{1});
    verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'ontologyLabel');
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyRoundTrip(testCase, r, ['label ' node{1}], {});
end
% and on a carried stack, carried down the chain as the raw source
beh = haleyBehaviourStack('is_h2', 'video');
lab = haleyLabel('lab_h2', 'is_h2', 'EMPTY:0000129');
out = runRaw({beh, lab});
l = docWithId(out, 'lab_h2');
verifyEqual(testCase, l.document_class.schema_version, 'did_v1');
l.document_class = rmfield(l.document_class, 'schema_version');
verifyTrue(testCase, isequaln(l, lab), 'the carried label is not the raw v1 source');
end

function testALabelOutsideItsTemplateIsCarriedAsMalformed(testCase)
% Decided by Jess Haley, 2026-10-27 [ontologyLabel row split] (did-schema
% V_eta_go_forward_class_audit.md): "a field outside NDI's `ontologyLabel`
% template, or an edge other than `document_id`, is carried under carry-100
% (malformed)". The template (ontologyLabel.json + base.json at the locked
% NDI-matlab `main`) has one field, `ontologyNode`, and one edge, `document_id`.
stray = haleyLabel('lab_sf', 'is_x', 'EMPTY:0000129');
stray.ontologyLabel.ontologyName = 'arena mask';
stray = jsondecode(jsonencode(stray));
edge = haleyLabel('lab_se', 'is_x', 'EMPTY:0000129');
edge.depends_on(end+1) = struct('name', 'subject_id', 'value', 'sg_1');
edge = jsondecode(jsonencode(edge));
cases = {stray, 'ontologyLabel.ontologyName'; edge, 'depends_on(subject_id)'};
for c = 1:size(cases, 1)
    v1 = cases{c, 1};
    id = v1.base.id;
    [carried, notes, out] = did2.unittest.helpers.carryNote({v1});
    verifyEmpty(testCase, out.quarantine, id);
    verifyTrue(testCase, carried, [id ': not carried as its v1 source']);
    verifyTrue(testCase, startsWith(notes, '[carry-100] '), notes);
    verifyTrue(testCase, contains(notes, cases{c, 2}), notes);
    r = did2.convert.roundtrip.check(v1, out.migrated);
    verifyTrue(testCase, r.carried, id);
    verifyTrue(testCase, r.ok, id);
end
% the writer's shape is not carried: handed back untouched for NDI's second pass
[~, notes, out] = did2.unittest.helpers.carryNote({haleyLabel('lab_ok', 'is_x', 'EMPTY:0000129')});
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, notes, '', 'a writer-shaped label is carried');
verifyEqual(testCase, docWithId(out, 'lab_ok').document_class.class_name, 'ontologyLabel');
end

function testAnInventedLabelShapeIsStillRefusedInEitherSpelling(testCase)
v1 = haleyLabel('lab_bad', 'is_x', 'EMPTY:0000129');
v1.ontologyLabel.label_id = 12;
raw = runRaw(v1);
old = runRenamed(v1);
verifyEqual(testCase, numel(raw.quarantine), 1);
verifyEqual(testCase, numel(old.quarantine), 1);
verifyEqual(testCase, raw.quarantine(1).identifier, 'did2:convert:ontologyLabelInventedShape');
end

% ===================== helpers =========================================

function out = runRaw(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
end

function out = runRenamed(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2', ...
    'RawV1Classes', {});
end

function verifyCarriedUntouched(testCase, v1, out, label)
verifyEmpty(testCase, out.quarantine, label);
verifyEqual(testCase, numel(out.migrated), 1, label);
verifyEqual(testCase, numel(out.passthrough), 1, [label ': carried']);
emitted = out.migrated{1}.toStruct();
verifyEqual(testCase, emitted.document_class.schema_version, 'did_v1', label);
emitted.document_class = rmfield(emitted.document_class, 'schema_version');
verifyTrue(testCase, isequaln(emitted, v1), [label ': the carry is not the v1 source']);
end

function verifyOneRecordPerSource(testCase, out, label)
idx = [out.passthrough.input_index];
verifyEqual(testCase, numel(unique(idx)), numel(idx), ...
    [label ': a source has more than one passthrough record']);
end

function s = foldSubject(id)
% any document of the id: the fold only needs the file's referent in the batch
s = struct();
s.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
s.depends_on = struct('name', {}, 'value', {});
s.base = struct('id', id, 'session_id', '41269430c597c3e6_c0c9895d35d19b54', ...
    'name', 'subject', 'datestamp', '2024-06-01T12:00:00.000Z');
s.subject = struct('local_identifier', 'plasmidHostStrain', 'description', '');
end

function g = foldGenericFile(id, subjectId)
% a generic_file as pass 1 hands it to the fold (testFixtureCorpus om_gf_03:
% no dates, so it folds)
g = struct();
g.document_class = struct('class_name', 'generic_file', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
g.depends_on = struct('name', {'document_id'}, 'document_id', {subjectId});
g.base = struct('id', id, 'session_id', '41269430c597c3e6_c0c9895d35d19b54', ...
    'name', 'plasmid', 'datestamp', '2024-06-01T12:00:00.000Z');
g.generic_file = struct('filename', 'plasmids/pXY-12.gb', ...
    'format_ontology', 'EMPTY:0000253', ...
    'checksum', 'd41d8cd98f00b204e9800998ecf8427e');
g.files = struct('file_list', {{'generic_file.ext'}});
end

function b = docWithId(out, id)
b = struct();
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), id)
        b = out.migrated{k}.toStruct();
        return;
    end
end
end

function m = edgeMap(b)
% name -> id, whichever key holds it
m = struct();
if ~isfield(b, 'depends_on'); return; end
d = b.depends_on;
if isstruct(d); d = num2cell(d); end
for k = 1:numel(d)
    e = d{k};
    v = '';
    for key = {'document_id', 'value', 'id'}
        if isfield(e, key{1}) && ~isempty(e.(key{1}))
            v = char(e.(key{1}));
            break;
        end
    end
    m.(matlab.lang.makeValidName(char(e.name))) = v;
end
end

function verifyRoundTrip(testCase, r, label, expectedLost)
verifyGreaterThan(testCase, r.fields_inspected, 0, [label ': inspected nothing']);
lost = reshape(sort({r.lost.path}), 1, []);
verifyEqual(testCase, lost, reshape(sort(expectedLost), 1, []), ...
    sprintf('%s: lost paths are not the listed findings; lost: %s', label, describeLost(r)));
verifyEmpty(testCase, r.invented, sprintf('%s: invented: %s', label, strjoin(r.invented, ', ')));
verifyEmpty(testCase, r.unplaced, sprintf('%s: unplaced: %s', label, strjoin(r.unplaced, '; ')));
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

% ---- the writers' shapes ------------------------------------------------

function v1 = stackShell(id, sessionId, datestamp)
% ndi.document('imageStack', ...) + session.newdocument: the template merge
% (imageStack.json, its superclasses base.json and imageStack_parameters.json),
% the edges sorted and unique (document_id, subject_id)
tpl = loadTemplate('imageStack');
ptpl = loadTemplate('imageStack_parameters');
btpl = loadTemplate('base');
v1 = struct();
v1.base = btpl.base;
v1.base.id = id;
v1.base.session_id = sessionId;
v1.base.datestamp = datestamp;
deps = [reshape(tpl.depends_on, [], 1); reshape(ptpl.depends_on, [], 1)];
[~, ix] = unique({deps.name});
v1.depends_on = reshape(deps(ix), 1, []);
v1.document_class = tpl.document_class;
v1.files = struct('file_list', {{'imageStack'}}, 'file_info', struct( ...
    'name', 'imageStack', 'locations', struct('delete_original', 0, ...
    'uid', [id '_f'], 'location', ['ndic://682e7772cdf3f24938176fac/' id '_f'], ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0)));
v1.imageStack = tpl.imageStack;
v1.imageStack_parameters = ptpl.imageStack_parameters;
end

function v1 = setEdge(v1, name, value)
v1.depends_on(strcmp({v1.depends_on.name}, name)).value = value;
end

function v1 = haleyBehaviourStack(id, kind)
% +haley/doImport.m, the behaviour plate loop
v1 = stackShell(id, '41269430c597c3e6_c0c9895d35d19b54', '2025-09-04T16:17:17.990Z');
v1 = setEdge(v1, 'document_id', '41269430c5a381ab_40d18c40b982f557');
v1 = setEdge(v1, 'subject_id', '41269430c60a3940_40df6475b28be4df');
p = struct('dimension_order', 'YX', 'dimension_labels', 'height,width', ...
    'dimension_size', [1024 1024], 'dimension_scale', [32.930891045367005 32.930891045367005], ...
    'dimension_scale_units', 'micrometer,micrometer', 'data_type', 'logical', ...
    'data_limits', [0 1], 'timestamp', 738637.4600694445, 'clocktype', 'exp_global_time');
switch kind
    case 'video'
        p.dimension_order = 'YXT';
        p.dimension_labels = 'height,width,time';
        p.dimension_size = [1024 1024 10797];
        p.dimension_scale = [32.930891045367005 32.930891045367005 0.33342891628933624];
        p.dimension_scale_units = 'micrometer,micrometer,second';
        p.data_type = 'uint8';
        p.data_limits = [0 255];
        s = struct('label', ['A video recording capturing the behavior of C. ' ...
            'elegans during an experimental assay.'], 'formatOntology', 'NCIT:C190180');
    case 'arena mask'
        s = struct('label', ['A binary image mask (logical matrix) that defines ' ...
            'the boundaries of the experimental arena.'], 'formatOntology', 'NCIT:C85437');
    case 'bacteria mask'
        s = struct('label', ['A binary image mask (logical matrix) representing ' ...
            'the union of all individually detected bacterial patch areas on an ' ...
            'assay plate. This mask defines all food-containing regions.'], ...
            'formatOntology', 'NCIT:C85437');
    case 'closest patch'
        p.data_type = 'uint8';
        p.data_limits = [0 255];
        s = struct('label', ['An image or map where each pixel''s value is the ' ...
            'identifier of the bacterial patch closest to that pixel''s location.'], ...
            'formatOntology', 'NCIT:C85437');
end
v1.imageStack = s;
v1.imageStack_parameters = p;
v1 = jsondecode(jsonencode(v1));
end

function v1 = haleyEColiStack(id, kind)
% +haley/doImport.m, the E. coli image loop: document_id only
v1 = stackShell(id, '41269430c5983d0e_40902179ad27b308', '2025-09-05T02:42:39.891Z');
v1 = setEdge(v1, 'document_id', '41269431a441f675_c0c69cac575a6e6b');
p = struct('dimension_order', 'YX', 'dimension_labels', 'height,width', ...
    'dimension_size', [2208 2752], 'dimension_scale', [96.4409082312986 96.4409082312986], ...
    'dimension_scale_units', 'micrometer,micrometer', 'data_type', 'uint16', ...
    'data_limits', [0 65535], 'timestamp', 739254.536875, 'clocktype', 'exp_global_time');
switch kind
    case 'image'
        s = struct('label', 'A brightfield image of an E. coli patch on an assay plate.', ...
            'formatOntology', 'NCIT:C70631');
    case 'mask'
        p.data_type = 'logical';
        p.data_limits = [0 1];
        s = struct('label', ['A binary image mask (logical matrix) representing ' ...
            'the union of all individually detected bacterial patch areas on an ' ...
            'assay plate. This mask defines all food-containing regions.'], ...
            'formatOntology', 'NCIT:C85437');
    case 'closest patch'
        p.data_type = 'uint8';
        p.data_limits = [0 255];
        s = struct('label', ['An image or map where each pixel''s value is the ' ...
            'identifier of the bacterial patch closest to that pixel''s location.'], ...
            'formatOntology', 'NCIT:C85437');
end
v1.imageStack = s;
v1.imageStack_parameters = p;
v1 = jsondecode(jsonencode(v1));
end

function v1 = babuStack(id, kind)
% +babu/import.m step 6: subject_id only (the subject group), no document_id
v1 = stackShell(id, '4126aa00c0000000_0000000000000b01', '2025-03-11T09:30:00.000Z');
v1 = setEdge(v1, 'subject_id', '4126aa00c0000000_00000000000005a1');
switch kind
    case 'video'
        p = struct('dimension_order', 'YXT', 'dimension_labels', 'height,width,time', ...
            'dimension_size', [480 640 1800], 'dimension_scale', [1 1 30], ...
            'dimension_scale_units', 'pixel,pixel,second');
        s = struct('label', ['A video recording capturing the behavior of C. ' ...
            'elegans during a chemotaxis assay.'], 'formatOntology', 'NCIT:C190180');
    case 'image'
        p = struct('dimension_order', 'YX', 'dimension_labels', 'height,width', ...
            'dimension_size', [1024 1344], 'dimension_scale', [1 1], ...
            'dimension_scale_units', 'pixel,pixel');
        s = struct('label', 'An image or video acquired using fluorescence microscopy.', ...
            'formatOntology', 'NCIT:C70631');
end
p.data_type = 'uint8';
p.data_limits = [0 255];
p.timestamp = 739321.4166666666;
p.clocktype = 'exp_global_time';
v1.imageStack = s;
v1.imageStack_parameters = p;
v1 = jsondecode(jsonencode(v1));
end

function v1 = didBrightfield(id, labels)
% a DID-side shape: a subject, no plate row, an intensity image; LABELS ''
% names the axes by their letters
v1 = babuStack(id, 'image');
v1.imageStack.label = 'A brightfield image of a plate.';
v1.imageStack_parameters.dimension_labels = labels;
v1.imageStack_parameters.dimension_scale = [2; 2];
v1 = jsondecode(jsonencode(v1));
end

function v1 = imageDoc(id, format)
% ndi.document('image', ...) + session.newdocument: the template merge
% (image.json, its superclasses base.json and imageStack_parameters.json), the
% edges sorted and unique (document_id, imageCollection_id, subject_id). No
% writer at the locked main constructs one; the parameters are a Babu image's.
tpl = loadTemplate('image');
ptpl = loadTemplate('imageStack_parameters');
btpl = loadTemplate('base');
v1 = struct();
v1.base = btpl.base;
v1.base.id = id;
v1.base.session_id = '4126aa00c0000000_0000000000000b01';
v1.base.datestamp = '2025-03-11T09:30:00.000Z';
deps = [reshape(tpl.depends_on, [], 1); reshape(ptpl.depends_on, [], 1)];
[~, ix] = unique({deps.name});
v1.depends_on = reshape(deps(ix), 1, []);
v1.document_class = tpl.document_class;
v1.files = struct('file_list', {{'imageFile'}}, 'file_info', struct( ...
    'name', 'imageFile', 'locations', struct('delete_original', 0, ...
    'uid', [id '_f'], 'location', ['ndic://682e7772cdf3f24938176fac/' id '_f'], ...
    'parameters', '', 'location_type', 'ndicloud', 'ingest', 0)));
v1.image = struct('label', 'A brightfield image of a plate.', 'format', format, ...
    'compression', 'lzw');
v1.imageStack_parameters = struct('dimension_order', 'YX', ...
    'dimension_labels', 'height,width', 'dimension_size', [1024 1344], ...
    'dimension_scale', [1 1], 'dimension_scale_units', 'pixel,pixel', ...
    'data_type', 'uint8', 'data_limits', [0 255], 'timestamp', 739321.4166666666, ...
    'clocktype', 'exp_global_time');
v1 = setEdge(v1, 'subject_id', '4126aa00c0000000_00000000000005a1');
v1 = jsondecode(jsonencode(v1));
end

function v1 = haleyLabel(id, stackId, node)
% ndi.document('ontologyLabel', 'ontologyLabel', struct('ontologyNode', ...))
% + session.newdocument, then set_dependency_value('document_id', ...)
tpl = loadTemplate('ontologyLabel');
btpl = loadTemplate('base');
v1 = struct();
v1.base = btpl.base;
v1.base.id = id;
v1.base.session_id = '41269430c597c3e6_c0c9895d35d19b54';
v1.base.datestamp = '2025-09-04T16:17:18.000Z';
v1.depends_on = tpl.depends_on;
v1.depends_on.value = stackId;
v1.document_class = tpl.document_class;
v1.ontologyLabel = struct('ontologyNode', node);
v1 = jsondecode(jsonencode(v1));
end

function tpl = loadTemplate(name)
thisDir = fileparts(mfilename('fullpath'));
f = fullfile(fileparts(thisDir), 'fixtures', 'ndi_templates', [name '.json']);
tpl = jsondecode(fileread(f));
end
