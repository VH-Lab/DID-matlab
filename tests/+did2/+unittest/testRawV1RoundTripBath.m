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
%   lost). KNOWN FINDINGS of the bath pass's own output, listed exactly:
%     epochid.epochid         the anchor is still on the session until epochMint
%                             re-points it
%   A table with a pH row is no longer a finding: it goes on the formulation's
%   `ph`, which keeps no ontology node (NCIm:C4048290) and not where the row
%   stood, and the round trip counts it equal (Decided by Jess Haley,
%   2026-10-27 [bath ph and osmolarity are formulation fields]). Dabrowska's
%   ACSF, whose carbogen row is in "saturation" and osm row in "osm", is
%   carried whole as v1 (carry-155; Decided by Jess Haley, 2026-11-03 [Dab
%   bath units are Dabrowska's]).
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
    'Dab ACSF (pH, carbogen, osm): carried, carry-155', dabBath(acsf()), true, {}; ...
    'Dab ACSF with a drug: carried, carry-155', dabBath(acsfWithDrug()), true, {}; ...
    'an ACSF in read units (pH)', dabBath(acsfReadUnits()), false, coarse; ...
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
        {'an ACSF in read units', dabBath(acsfReadUnits()), {}}, ...
        {'Marder anatomical location', marderBath(), {}}}
    [label, v1, known] = c{1}{:};
    [mine, out] = bathOutputs(v1);
    ids = cellfun(@(d) char(d.get('base.id')), mine, 'UniformOutput', false);
    e = epochEntity(v1);
    out.migrated{end+1} = did2.document(e);
    out = did2.convert.epochMint(out, 'Validate', false, 'TargetVersion', 'did_v2');
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

function testAPhOrOsmolarityRowIsComparedByWhatItStates(testCase)
% [bath ph and osmolarity are formulation fields] (Decided by Jess Haley,
% 2026-10-27): the row's term id and its position are not kept and count
% equal; its number is kept and is compared
% (the ACSF without its carbogen and osm rows, which [Dab bath units are
% Dabrowska's] carries: testAnUnreadUnitCarriesTheBath)
v1 = dabBath(acsfReadUnits());
mine = bathOutputs(v1);
r = did2.convert.roundtrip.check(v1, mine);
verifyFalse(testCase, r.carried);
verifyTrue(testCase, any(strcmp('stimulus_bath.mixture_table', [r.matched, r.equivalent])));
% another pH: lost
v2 = v1;
v2.stimulus_bath.mixture_table = strrep(v1.stimulus_bath.mixture_table, '"pH",7.4', '"pH",7.2');
r = did2.convert.roundtrip.check(v2, mine);
verifyTrue(testCase, any(strcmp(lostPaths(r), 'stimulus_bath.mixture_table')));
% the same pH under another term id and at the end of the table: equal
pHrow = sprintf('NCIm:C4048290,"pH",7.4,OM:Acidity,pH\n');
moved = [strrep(v1.stimulus_bath.mixture_table, pHrow, '') ...
    sprintf('NCIT:C45997,"pH",7.4,OM:Acidity,pH\n')];
v3 = v1;
v3.stimulus_bath.mixture_table = moved;
verifyNotEqual(testCase, moved, v1.stimulus_bath.mixture_table, 'the fixture moved the row');
r = did2.convert.roundtrip.check(v3, mine);
verifyFalse(testCase, any(strcmp(lostPaths(r), 'stimulus_bath.mixture_table')), ...
    'a moved pH row with another term id counts equal');
end

function testAnUnreadUnitCarriesTheBath(testCase)
% Decided by Jess Haley, 2026-11-03 [Dab bath units are Dabrowska's] (did-schema
% did_v2_go_forward_class_audit.md): a mixture row stated in "osm" (an amount;
% per litre or per kg is not stated) or "saturation" (not a unit) is not read
% by the generic stage: the bath is carried whole as v1 under carry-155
% ([canonical absent only as needs info]); the Dabrowska map states their
% meaning. INVERTED: Dabrowska's ACSF used to convert, its osm row on the
% formulation's osmolarity and its carbogen row an ingredient.
for c = {{'ACSF (both)', acsf(), 2}, ...
        {'saturation only', strrep(acsf(), sprintf('NCIm:C0439186,"osm",0.29,NCIm:C0439186,osm\n'), ''), 1}, ...
        {'osm only', strrep(acsf(), sprintf('NCIm:CL1445492,"carbogen",1,NCIm:C0522534,saturation\n'), ''), 1}}
    [label, table, nRows] = c{1}{:};
    if nRows == 1
        verifyNotEqual(testCase, table, acsf(), [label ': the fixture removed a row']);
    end
    v1 = dabBath(table);
    [mine, out] = bathOutputs(v1);
    verifyEmpty(testCase, quarantinedBaths(out), [label ': left quarantined']);
    verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_unread_unit, 1, label);
    verifyEqual(testCase, out.deferred_bath_resolution.baths_resolved, 0, label);
    assertEqual(testCase, numel(mine), 1, [label ': not one document, the carry']);
    verifyEqual(testCase, char(mine{1}.get('document_class.schema_version')), 'did_v1', label);
    r = did2.convert.roundtrip.check(v1, mine);
    verifyTrue(testCase, r.carried, label);
    verifyEmpty(testCase, lostPaths(r), describeLost(r));
    n = out.summary.migration_notes.carried_as_v1;
    verifyTrue(testCase, any(strcmp(n.register_rows, 'carry-155')), [label ': no carry-155 note']);
end
end

% ============ [bath concentration prefixes convert to molar] ===============
% Decided by Jess Haley, 2026-11-12 (did-schema did_v2_go_forward_class_audit.md)
% [bath concentration prefixes convert to molar]: an ingredient's concentration
% in a molar unit with a known SI prefix gets its canonical `molar` (arithmetic
% only); a unit that cannot be read so carries the bath for mapping
% (carry-155); an osmolarity in osmoles per litre with a known prefix gets its
% `osmolar`, any other osmolarity unit is a gap in the run's migration report.

function testAPrefixedMolarUnitGetsItsMolar(testCase)
% {unitName, number, molar}
rows = { ...
    'Molar',      0.002,  0.002; ...
    'M',          0.002,  0.002; ...
    'mM',         125,    0.125; ...
    'millimolar', 2.5,    0.0025; ...
    'uM',         10,     1e-5; ...
    [char(181) 'M'], 10,  1e-5; ...
    'micromolar', 3,      3e-6; ...
    'nM',         200,    2e-7; ...
    'pM',         5,      5e-12; ...
    'mmol/L',     1,      1e-3};
v1 = dabBath(tableOf(rows));
did2.convert.migrationReport('begin');
testCase.addTeardown(@() did2.convert.migrationReport('end'));
[mine, out] = bathOutputs(v1);
verifyEmpty(testCase, quarantinedBaths(out), 'left quarantined');
verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_unread_unit, 0, 'carried');
f = formulationOf(mine);
ing = ingredientsOf(f);
assertEqual(testCase, numel(ing), size(rows, 1), 'one ingredient per row');
for k = 1:size(rows, 1)
    c = ing{k}.concentration;
    label = sprintf('row %d (%s)', k, rows{k, 1});
    verifyEqual(testCase, c.source_value, rows{k, 2}, [label ': the number as written']);
    verifyEqual(testCase, c.source_unit.name, rows{k, 1}, [label ': the unit as written']);
    assertTrue(testCase, isfield(c, 'molar') && ~isempty(c.molar), [label ': no molar']);
    verifyEqual(testCase, c.molar, rows{k, 3}, 'RelTol', 1e-12, label);
end
verifyEmpty(testCase, did2.convert.migrationReport('gaps', f.base.id), 'no gap');
r = did2.convert.roundtrip.check(v1, mine);
verifyFalse(testCase, r.carried);
verifyFalse(testCase, any(strcmp(lostPaths(r), 'stimulus_bath.mixture_table')), describeLost(r));
end

function testAnUnreadableConcentrationUnitCarriesTheBath(testCase)
% a unit that is not molar with a known prefix (a mass per volume, a case
% that makes another unit: MM, a prefix not known: xM) is carried, carry-155
for u = {'mg/mL', 'MM', 'xM', 'percent'}
    label = u{1};
    v1 = dabBath(tableOf({'Molar', 0.1, 0.1; u{1}, 2, []}));
    [mine, out] = bathOutputs(v1);
    verifyEmpty(testCase, quarantinedBaths(out), [label ': left quarantined']);
    verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_unread_unit, 1, label);
    verifyEqual(testCase, out.deferred_bath_resolution.baths_resolved, 0, label);
    assertEqual(testCase, numel(mine), 1, [label ': not one document, the carry']);
    verifyEqual(testCase, char(mine{1}.get('document_class.schema_version')), 'did_v1', label);
    n = out.summary.migration_notes.carried_as_v1;
    verifyTrue(testCase, any(strcmp(n.register_rows, 'carry-155')), [label ': no carry-155 note']);
    ix = find(strcmp(n.ids, v1.base.id), 1);
    assertNotEmpty(testCase, ix, [label ': no note for the bath']);
    verifyTrue(testCase, contains(n.details{ix}, u{1}), [label ': the note does not name the unit']);
end
end

function testANumberWithNoUnitIsAGap(testCase)
v1 = dabBath(tableOf({'Molar', 0.1, 0.1; '', 3, []}));
did2.convert.migrationReport('begin');
testCase.addTeardown(@() did2.convert.migrationReport('end'));
[mine, out] = bathOutputs(v1);
verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_unread_unit, 0, 'carried');
f = formulationOf(mine);
ing = ingredientsOf(f);
verifyEqual(testCase, ing{2}.concentration.source_value, 3);
verifyFalse(testCase, isfield(ing{2}.concentration, 'molar') ...
    && ~isempty(ing{2}.concentration.molar), 'a molar for a number with no unit');
g = did2.convert.migrationReport('gaps', f.base.id);
verifyEqual(testCase, {g.field}, {'formulation.value.ingredients(2).concentration.canonical'});
end

function testAnOsmolarityInOsmolesPerLitreGetsItsOsmolar(testCase)
for c = {{'mOsm/L', 290, 0.29}, {'Osm/L', 0.3, 0.3}, {'mOsM', 300, 0.3}, ...
        {'milliosmolar', 280, 0.28}}
    [u, value, expected] = c{1}{:};
    v1 = dabBath([tableOf({'Molar', 0.1, 0.1}) ...
        sprintf('NCIm:C0439186,"osmolarity",%s,,%s\n', num2str(value, 17), u)]);
    did2.convert.migrationReport('begin');
    [mine, out] = bathOutputs(v1);
    verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_unread_unit, 0, [u ': carried']);
    f = formulationOf(mine);
    o = f.formulation.value.osmolarity;
    verifyEqual(testCase, o.source_value, value, u);
    assertTrue(testCase, isfield(o, 'osmolar') && ~isempty(o.osmolar), [u ': no osmolar']);
    verifyEqual(testCase, o.osmolar, expected, 'RelTol', 1e-12, u);
    verifyEmpty(testCase, did2.convert.migrationReport('gaps', f.base.id), [u ': a gap']);
    did2.convert.migrationReport('end');
end
end

function testAnOsmolarityInAnotherUnitIsAGap(testCase)
% a bare mOsm says neither per litre nor per kg ([Dab bath units are
% Dabrowska's] says so of "osm", which unreadUnitRows carries); mOsm/kg is an
% osmolality; no unit at all: each is a gap naming the canonical `osmolar`
for u = {'mOsm', 'mOsm/kg', ''}
    v1 = dabBath([tableOf({'Molar', 0.1, 0.1}) ...
        sprintf('NCIm:C0439186,"osmolarity",290,,%s\n', u{1})]);
    did2.convert.migrationReport('begin');
    [mine, out] = bathOutputs(v1);
    label = ['"' u{1} '"'];
    verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_unread_unit, 0, [label ': carried']);
    f = formulationOf(mine);
    o = f.formulation.value.osmolarity;
    verifyEqual(testCase, o.source_value, 290, label);
    verifyFalse(testCase, isfield(o, 'osmolar') && ~isempty(o.osmolar), [label ': an osmolar']);
    g = did2.convert.migrationReport('gaps', f.base.id);
    verifyEqual(testCase, {g.field}, {'formulation.value.osmolarity.osmolar'}, label);
    did2.convert.migrationReport('end');
end
end

function t = tableOf(rows)
% a mixture_table of one chemical per row {unitName, number, ~}
t = sprintf('ontologyName,name,value,ontologyUnit,unitName\n');
for k = 1:size(rows, 1)
    node = 'OM:MolarVolumeUnit';
    if isempty(rows{k, 1}); node = ''; end
    t = [t sprintf('NCIm:C00%05d,"chemical %d",%s,%s,%s\n', k, k, ...
        num2str(rows{k, 2}, 17), node, rows{k, 1})]; %#ok<AGROW>
end
end

function f = formulationOf(docs)
f = [];
for k = 1:numel(docs)
    if strcmp(docs{k}.className(), 'formulation')
        f = docs{k}.toStruct();
    end
end
if isempty(f)
    error('testRawV1RoundTripBath:noFormulation', 'No formulation among the bath''s documents.');
end
end

function c = ingredientsOf(f)
c = f.formulation.value.ingredients;
if isstruct(c)
    c = num2cell(c);
end
c = reshape(c, 1, []);
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
out = did2.convert.v1_to_v2({v1}, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, out.summary.legacy_ndi_document.bodies_read_raw_v1, 1);
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, out.quarantine(1).class_name, 'stimulus_bath');
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:needsSessionContext');
verifyTrue(testCase, isequaln(jsondecode(out.quarantine(1).original_body), v1));
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
% INVERTED 2026-10-29 from 'unplaced: stimulus_bath.mixture_table (not text)'
% (no register row): [values no writer produces are malformed] (Jess Haley,
% 2026-10-27, did-schema V_eta_go_forward_class_audit.md) -- the item cites
% carry-120
verifyCarriedFor(testCase, v1, 'unplaced: [carry-120] stimulus_bath.mixture_table (not text)');
v1 = dabBath(oneDrug());
v1.ndi_document = struct('id', 'x', 'type', 'stimulus_bath');
verifyCarriedFor(testCase, v1, '[carry-100] malformed: outside the NDI template, unplaced: ndi_document.');   % [ndi_document read as base]: its id and type are not base's
end

% ===================== a check that cannot fail proves nothing ===========

function testABathWithNoClockRecordIsCarried(testCase)
% Decided by Jess Haley, 2026-10-26 [one-reading quick answers] Q2 (did-schema
% V_eta_go_forward_class_audit.md): a bath epoch with no clock record is
% carried as v1 instead of defaulting to dev_local_time (carry-157). The
% stimulator has no element_epoch for the bath's epoch here, so the coarse
% pass carries the bath: its round trip is the carry, nothing lost.
v1 = dabBath(oneDrug());
first = did2.convert.v1_to_v2({subjectDoc(), stimulatorDoc(), v1}, ...
    'Validate', false, 'TargetVersion', 'did_v2');
out = resolved(first);
verifyEmpty(testCase, quarantinedBaths(out), 'left quarantined');
verifyEqual(testCase, out.deferred_bath_resolution.baths_carried_no_clock, 1);
mine = {};
for k = 1:numel(out.migrated)
    if strcmp(char(out.migrated{k}.get('base.id')), v1.base.id)
        mine{end+1} = out.migrated{k}; %#ok<AGROW>
    end
end
assertEqual(testCase, numel(mine), 1, 'not one document: the carry');
r = did2.convert.roundtrip.check(v1, mine);
verifyTrue(testCase, r.carried, 'not carried');
verifyEmpty(testCase, lostPaths(r), describeLost(r));
n = out.summary.migration_notes.carried_as_v1;
verifyTrue(testCase, any(strcmp(n.register_rows, 'carry-157')), 'no carry-157 note');
end

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
first = did2.convert.v1_to_v2(batch, 'Validate', false, 'TargetVersion', 'did_v2');
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
out = did2.convert.resolveDeferredBaths(out, 'Validate', false, 'TargetVersion', 'did_v2');
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
out = did2.convert.v1_to_v2([fixtureBatch(), {v1}], 'Validate', false, 'TargetVersion', 'did_v2');
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
% subject, no underlying element), its subject, and its element_epoch for
% the baths' epoch: the clock record the bath is anchored on. Without it the
% bath is carried, carry-157 ([one-reading quick answers] Q2, Jess Haley,
% 2026-10-26: testABathWithNoClockRecordIsCarried)
b = {subjectDoc(), stimulatorDoc(), stimulatorEpochDoc()};
end

function v1 = stimulatorEpochDoc()
% ndi.element's element_epoch of the stimulator for the baths' epoch
% (element_epoch.json + epochid.json + base.json, the writer's clock and
% t0_t1 for one clock)
tpl = loadTemplate('element_epoch');
v1 = withBase(tpl, 'stim_1_epoch', '');
v1.depends_on = tpl.depends_on;
v1.depends_on(1).value = 'stim_1';
v1.files = tpl.files;
v1.epochid = struct('epochid', BATH_EPOCH());
v1.element_epoch = tpl.element_epoch;
v1.element_epoch.epoch_clock = 'dev_local_time';
v1.element_epoch.t0_t1 = [0; 100];
v1 = jsondecode(jsonencode(v1));
end

function e = BATH_EPOCH()
e = 'epoch_4126945aee4e93b1_40d01af895f1e3f6';
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
v1.epochid = struct('epochid', BATH_EPOCH());
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

function t = acsfReadUnits()
% the ACSF without its carbogen ("saturation") and osm ("osm") rows, which the
% generic stage does not read ([Dab bath units are Dabrowska's])
t = strrep(strrep(acsf(), ...
    sprintf('NCIm:CL1445492,"carbogen",1,NCIm:C0522534,saturation\n'), ''), ...
    sprintf('NCIm:C0439186,"osm",0.29,NCIm:C0439186,osm\n'), '');
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
