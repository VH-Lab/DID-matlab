function tests = testNgridCoordinates
%TESTNGRIDCOORDINATES `ngrid.coordinates` must survive the V_eta pipeline --
%   FOR THE CONSUMER THAT STILL PASSES THROUGH, which since 2026-08-17 is
%   `ontology_image` ALONE.
%
%   AMENDED 2026-08-17. The unqualified H1 was true when written and is not
%   now: `hartley_calc` no longer passes through, it DECOMPOSES (the signed
%   receptive_field fold), so for that class the requirement is the opposite --
%   the block is CONSUMED, and a grid whose coordinates cannot be accounted
%   for is REFUSED rather than carried. Both claims live below, one per
%   consumer. The H1 is amended rather than left to be
%   discovered because a header that overstates a guarantee is how this project
%   has repeatedly read "we are further along / more protected than we are",
%   and a reader who stops at this line would take the carry as universal.
%
%   STATUS: NEVER RUN. There is no MATLAB in the environment these were written
%   in, so every assertion below is unexecuted. Treat a first green run as the
%   evidence, not this file.
%
%   ---------------------------------------------------------------------
%   WHAT THIS FILE IS FOR  (#46 / #47)
%   ---------------------------------------------------------------------
%   `did2.convert.v1_to_v2` runs SUPERCLASS migrators before the concrete one,
%   and that step was never bypassed by the migrators_j split. So under
%   TargetVersion 'V_eta' the base (+migrators) `ngrid` superclass migrator ran, and its
%   job is to `rmfield(block,'coordinates')` and `rmfield(block,'data_size')`.
%   Every ontologyImage document and every hartley_calc document (>=210 in the
%   20211116 corpus) lost both fields before any J migrator saw the body.
%
%   Nothing could see it. `coordinates` is not a required field, an absent
%   optional field is not a validation error, and the class it belonged to was
%   passing through -- so the quarantine gate, the orphan gate, silentLoss and
%   isFragment were all silent, exactly as they were for the ontology_image
%   husk. The only record of it was a COMMENT in testMigratorsJ:
%
%       "in the real pipeline the ngrid SUPERCLASS migrator runs first and
%        deletes it. That deletion is a known, separate data loss"
%
%   THIS FILE IS WRITTEN FROM THE WRITER, NOT FROM OUR SCHEMA. Every fixture
%   block below is the four-field shape that NDI actually produces:
%
%       git show origin/main:src/ndi/ndi_common/database_documents/data/ngrid.json
%           "ngrid": { "data_size":"", "data_type":"",
%                      "data_dim":"",  "coordinates":"" }
%       git show origin/main:src/ndi/ndi_common/schema_documents/data/ngrid_schema.json
%           data_size integer / data_type string / data_dim matrix /
%           coordinates matrix
%       +ndi/+fun/+data/mat2ngrid.m -- the ONLY writer, sets exactly those four
%       `git grep -c ndims -- src/ndi/ndi_common/*` -> nothing
%
%   `ndims` and `dim_sizes` therefore have NO did_v1 existence: they are the
%   base migrator's output. A test written against them would be a test
%   written from the same premise as the code.
%
%   ---------------------------------------------------------------------
%   WHAT IS DELIBERATELY *NOT* TESTED HERE
%   ---------------------------------------------------------------------
%   That `coordinates` lands anywhere. It does not: its decided destination is
%   `axes[k].values` (V_eta_image_model_plan.md, signed 2026-08-08), which is
%   part of the data_body tier (#45, blocked on #32). These tests assert only
%   that the data is CARRIED. Asserting a home would assert a build that has
%   not happened.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
% The migrators run inside did2.convert.v1_to_v2, which disarms the
% TermRegistry strict mode for the call (T19: the check is for imports; a
% migrator transcribes the source's own terms, which the registry need not
% hold yet). A test that calls a migrator directly runs it the same way.
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

% ===================== the V_eta superclass migrator =======================

function testVEtaSuperNgridCarriesAllFourV1Fields(testCase)
out = did2.convert.migrators_j.super.ngrid(v1NgridBody());
verifyEqual(testCase, out.ngrid.data_size, 8);
verifyEqual(testCase, out.ngrid.data_type, 'double');
verifyEqual(testCase, out.ngrid.data_dim, [4 4]);
verifyEqual(testCase, out.ngrid.coordinates, [1;2;3;4;1;2;3;4]);
% and it invents nothing -- the two base-migrator names must not appear
verifyFalse(testCase, isfield(out.ngrid, 'dim_sizes'));
verifyFalse(testCase, isfield(out.ngrid, 'ndims'));
end

function testVEtaSuperNgridIsANoOpWhenTheBlockIsAbsent(testCase)
b = v1NgridBody();
b = rmfield(b, 'ngrid');
out = did2.convert.migrators_j.super.ngrid(b);
verifyFalse(testCase, isfield(out, 'ngrid'));
end

function testVEtaSuperNgridRejectsTheBaseMigratorShape(testCase)
% THE GUARD, and it is the same guard ontology_image needed: a block carrying
% `dim_sizes`/`ndims` can only have come from the base (+migrators) migrator or from a
% fixture built against a DID-side schema. Both are the mistake this family has
% already paid for twice, so it must be loud.
b = v1NgridBody();
b.ngrid = struct('dim_sizes', [4 4], 'ndims', 2, 'data_type', 'double');
verifyError(testCase, @() did2.convert.migrators_j.super.ngrid(b), ...
    'did2:convert:ngridBaseMigratorShape');
end

% ===================== the base ngrid migrator: a carry ===================

% ===================== end to end, through the dispatcher ==================

function testCoordinatesSurviveTheFullVEtaPipeline(testCase)
% THE REGRESSION TEST. Calling migrators_j.ontology_image directly already
% showed the coordinates surviving; the loss only appeared through the
% dispatcher, because the superclass pass runs before the concrete migrator.
% So this must go through v1_to_v2, or it tests nothing.
%
% BOTH SPELLINGS (2026-10-30). The snake-spelled `ontology_image` fixture is
% the one that goes through the superclass pass (the renamed path), which is
% the regression this test was written for. Validate is false, so nothing is
% validated; did2.convert.ensureClassBlocks pads blocks from the
% `ontology_image` file when it exists and returns the body unchanged when it
% does not (its `catch; return;` around resolvePlacement), and neither touches
% the ngrid block, so this case holds with or without the file. NDI's own
% spelling, `ontologyImage`, is read raw
% (did2.convert.rawV1Classes) and is what a real dataset holds; it is driven
% too, so the coordinates are pinned on the path production takes.
cases = {ontologyImageVintageB(), 'ontology_image'; ...
         ontologyImageWriterNoRow(), 'ontologyImage'};
for c = 1:size(cases, 1)
    out = runJ(cases{c, 1});
    label = cases{c, 2};
    verifyEqual(testCase, out.summary.quarantine_count, 0, label);
    assertEqual(testCase, numel(out.migrated), 1, label);
    doc = out.migrated{1};
    verifyEqual(testCase, doc.get('document_class.class_name'), label);
    verifyEqual(testCase, doc.get('ngrid.coordinates'), [1;2;3;4;1;2;3;4], label);
    verifyEqual(testCase, doc.get('ngrid.data_dim'), [4 4], label);
    verifyEqual(testCase, doc.get('ngrid.data_size'), 8, label);
    verifyEqual(testCase, doc.get('ngrid.data_type'), 'double', label);
end
end

function testTheV1NgridBlockPassesThroughAsV1UnderValidation(testCase)
% INVERTED 2026-10-30 from testTheCarriedBlockVALIDATESAgainstTheVEtaTombstone,
% which validated a snake-spelled `ontology_image` fixture against the
% `ontology_image` + `ngrid` V_eta tombstones ("the schema half and the
% migrator half are LOCKSTEP"). [one folder, final classes only] (Jess Haley,
% 2026-10-29, did-schema V_eta_go_forward_class_audit.md) removes that premise:
% a retire class's JSON file is deleted once no v1 document passes through
% under it, and a document carried as v1 is checked against NDI's own v1
% template, not a V_eta tombstone. NDI never writes `ontology_image`; it writes
% `ontologyImage` (+ndi/+setup/+NDIMaker/imageDocMaker.m), which v1_to_v2 reads
% raw and passes through under that v1 class name. No V_eta schema of that name
% exists, with or without the `ontology_image` file, so the document is counted
% in passthrough_unvalidated_no_schema (v1_to_v2: `if passedThrough &&
% strcmp(vErr.identifier, 'did2:schema:missingClass')`) and never quarantined.
%
% What this still protects, with Validate ON: the writer's v1 ngrid block
% passes through without a quarantine, nothing reshaped, all four fields kept.
out = did2.convert.v1_to_v2(ontologyImageWriterNoRow(), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0, ...
    'the v1 ngrid block must pass through as v1, not quarantine');
verifyEqual(testCase, out.summary.migrated_count, 1);
assertEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'ontologyImage');
verifyEqual(testCase, doc.get('ngrid.coordinates'), [1;2;3;4;1;2;3;4]);
verifyEqual(testCase, doc.get('ngrid.data_dim'), [4 4]);
verifyFalse(testCase, isfield(doc.get('ngrid'), 'ndims'));
verifyFalse(testCase, isfield(doc.get('ngrid'), 'dim_sizes'));
verifyEqual(testCase, numel(out.passthrough), 1, 'recorded as a pass-1 passthrough');
verifyTrue(testCase, isfield(out.summary.passthrough_unvalidated_no_schema_by_class, ...
    'ontologyImage'), 'counted as a v1 passthrough with no V_eta schema');
end

function testHartleyCalcConsumesNgridAndRefusesAnUnaccountableGrid(testCase)
% RE-ARMED 2026-10-21: hartley_calc folds again once the loaded schema's
% `value` declares rule `value_inline_or_body` (did-schema data_body AMENDMENT
% 5): a receptive field is then `data_body: true` with an empty value. Before
% it, receptive_field.value was required with no sub-fields and the class
% passed through.
vc = did2.schema.cache.shared().getClass('value');
vr = {};
if isfield(vc, 'rules') && ~isempty(vc.rules)
    r = vc.rules;
    if iscell(r); vr = cellfun(@(x) char(x.name), r, 'UniformOutput', false);
    else; vr = {r.name}; end
end
assumeTrue(testCase, any(strcmp(vr, 'value_inline_or_body')), ...
    'the loaded schema predates data_body AMENDMENT 5; hartley_calc passes through');
% INVERTED 2026-08-17, NOT DELETED, AND THE INVERSION IS THE POINT.
%
% This test used to be `testHartleyCalcAlsoKeepsItsCoordinates` and asserted
% that a hartley_calc document reaches the far end of the pipeline still
% carrying `ngrid.data_dim` and `ngrid.coordinates` verbatim. That was correct
% for exactly as long as hartley_calc was a PASSTHROUGH, and its own header
% said so in its own words -- "the RF fold (#48) is not built, and the repo it
% came from is out of session scope".
%
% #48 IS NOW BUILT AND SIGNED (DID-schema V_eta_ngrid_family_findings.md,
% TEAM-SIGN-OFF [receptive field fold], 2026-08-17). hartley_calc decomposes
% into a `receptive_field_calculation` leaf plus two plane bodies, so there is
% no surviving `ngrid` block to carry and the old assertion asserts the
% pre-decision behaviour. This file's own governing rule is the one being
% followed here: a test written from the same premise as the code cannot catch
% the code, so a superseded assertion is INVERTED to state the new decided
% behaviour rather than patched away -- deleting it would leave the strongest
% claim about this class untested at precisely the moment it changed.
%
% WHAT THE CARRY NOW MEANS FOR #46. Retiring `ngrid` was gated on BOTH of its
% consumers. hartley_calc is now the one that no longer needs the carry at all
% -- it consumes the block and emits typed documents -- so the gate reduces to
% `ontology_image` alone, which the test above still covers. That is a
% NARROWING of #46, not a closure: the second consumer is unchanged.
%
% The payload shape stays recorded because it is what the fold had to model:
% NDIcalc-vis `+ndi/+calc/+vis/hartley.m` writes `ngridp.data_dim =
% [size(sta) 2]` and `fwrite(fid, cat(4, sta, p_val))` -- a [T x X x Y x 2]
% volume whose last plane is a p-value map, not a second image. Both planes now
% have somewhere to land; the shape assertions live in
% testMigratorsJHartleyCalc, which owns the fold.
% WHAT THIS FIXTURE CAN AND CANNOT ESTABLISH -- written down because two
% drafts of this test got it wrong in a row, and both times by asserting a
% shape rather than reading the fixture. `hartleyCalcV1` here is a STUB: it
% carries `coordinates [1;2;3]` against `data_dim [200 200 36 2]`, numbers
% chosen when this class was a PASSTHROUGH and nothing looked at them. The
% fold reads them, and no leading run of that data_dim sums to 3, so
% hartley_calc.m:466 refuses with `hartleyCoordinateCountUnaccounted` --
% v1_to_v2 routes a migrator error to QUARANTINE rather than rethrowing, so
% the observable outcome is a quarantined document and an EMPTY migrated set.
%
% So this file cannot assert the fold's emitted shape from this fixture, and
% it should not try: `testMigratorsJHartleyCalc` owns that, drives the fold
% with a coherent fixture, and asserts the leaf, both planes and the spike
% input. What IS assertable here, and is worth asserting, is the property this
% file has always been about -- whether the ngrid block survives -- now read
% the other way round: hartley_calc CONSUMES it, and when it cannot account
% for the coordinates it REFUSES rather than carrying them through.
%
% That refusal is the #46 narrowing in its observable form. Before the fold, a
% stub like this migrated clean and kept its ngrid block; the carry was the
% guarantee. Now an unaccountable grid stops, which is the "refuse rather than
% emit a husk" discipline the ontology_image husk cost us.
out = runJ(hartleyCalcV1());

verifyEqual(testCase, out.summary.quarantine_count, 1, ...
    ['the stub coordinates cannot be accounted for against the data_dim, ' ...
     'so the fold must refuse -- a 0 here means hartley_calc is passing ' ...
     'the ngrid block through again']);
verifyEmpty(testCase, out.migrated, ...
    'a refused document must emit nothing, not a partial decomposition');
verifyEqual(testCase, out.quarantine(1).class_name, 'hartley_calc');
verifyTrue(testCase, ...
    contains(out.quarantine(1).reason, 'coordinates'), ...
    sprintf(['the refusal must name the coordinate accounting, so a future ' ...
             'unrelated failure here is not mistaken for this one; got: %s'], ...
            out.quarantine(1).reason));
end

% ===================== fixtures (from the WRITER) ==========================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function b = v1NgridBody()
%V1NGRIDBODY A minimal carrier of the four real did_v1 ngrid fields.
b = struct();
b.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base', 'ngrid'}, ...
                           'class_version', {'1.0.0', '1.0.0'}));
b.depends_on = struct('name', {'ontology_table_row_id'}, 'value', {''});
b.base = struct('id', 'oi_ng', 'session_id', 'sess_09', 'name', 'oi', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
b.ontology_image = struct('ontology_nodes', 'uberon:0000955');
b.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', [1;2;3;4;1;2;3;4]);
end

function b = ontologyImageVintageB()
%ONTOLOGYIMAGEVINTAGEB The CURRENT (and only) NDI production shape.
%
%   From imageDocMaker.m:121-127 -- `mat2ngrid(image)` with ONE argument, so
%   `coordinates` is the default index vector [1..d1; 1..d2], and
%   `struct('ontologyNodes', ...)`, a comma-joined sorted CURIE list. The edge
%   is left EMPTY on purpose: empty edges are skipped by the orphan check, so
%   the fixture stays self-contained.
%
%   The `ontology_table_row_id` SPELLING here follows the V_eta tombstone. NDI
%   names it `ontologyTableRow_id` and universalRenames does not rename
%   depends_on entry names -- that mismatch is a real open question raised in
%   migrators_j/ontology_image.m, not something these tests settle.
b = v1NgridBody();
b.base.id = 'oi_02';
b.ontology_image = struct('ontology_nodes', 'uberon:0000955,uberon:0002436');
end

function b = ontologyImageWriterNoRow()
%ONTOLOGYIMAGEWRITERNOROW The same document in NDI's OWN spelling.
%
%   Built from NDI's template (tests/+did2/fixtures/ndi_templates/
%   ontologyImage.json, via did2.unittest.helpers.ndiDocument) in the shape
%   imageDocMaker.m createOntologyImageDoc writes when it is given no table
%   row: `ontologyImage.ontologyNodes`, the four-field ngrid, the
%   `ontologyTableRow_id` edge left empty. With no non-empty edge it is not the
%   document [ngrid with no statement carried] names, so +migrators_j/
%   ontology_image.m hands it back unchanged (a passthrough, no carry note;
%   testRawV1RoundTripOntologyImage/testAWriterDocumentWithNoTableRowStillPassesThrough).
%   Not jsondecode-round-tripped, so data_dim stays the 1x2 row the
%   assertions use.
b = did2.unittest.helpers.ndiDocument('ontologyImage', 'Id', '41268b6f5c6a3d4e_af0000000000000c');
b.ontologyImage = struct('ontologyNodes', 'UBERON:0000955,UBERON:0002436');
b.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [4 4], 'coordinates', [1;2;3;4;1;2;3;4]);
b = did2.unittest.helpers.setDependency(b, 'ontologyTableRow_id', '');
end

function b = hartleyCalcV1()
%HARTLEYCALCV1 The RF document, as NDIcalc-vis writes it.
%
%   `+ndi/+calc/+vis/hartley.m:448` builds ONE document carrying the
%   hartley_calc, hartley_reverse_correlation, reverse_correlation and ngrid
%   blocks, and sets `element_id` + `stimulus_presentation_id` explicitly.
%   `reverse_correlation` and `hartley_reverse_correlation` are superclass-only
%   -- no standalone documents of either exist.
%
%   PROVENANCE CAVEAT, stated because it is the rule in this repo: this shape
%   comes from V_eta_ngrid_family_findings.md, which read it from a shallow
%   clone of VH-Lab/NDIcalc-vis-matlab @ 65718ed. That repo is NOT in session
%   scope now and this fixture is NOT re-verified against it. It is used only
%   to exercise the ngrid CARRY through a deeper superclass chain; nothing here
%   asserts anything about the RF fold (#48), which is unbuilt for exactly this
%   reason.
b = struct();
b.document_class = struct('class_name', 'hartley_calc', 'class_version', '1.0.0', ...
    'superclasses', struct( ...
        'class_name', {'base', 'hartley_reverse_correlation', 'ngrid'}, ...
        'class_version', {'1.0.0', '1.0.0', '1.0.0'}));
b.depends_on = struct('name', {'element_id', 'stimulus_presentation_id'}, ...
    'value', {'elem_9', 'stimpres_1'});
b.base = struct('id', 'hc_01', 'session_id', 'sess_09', 'name', 'hc', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
b.hartley_calc = struct('input_parameters', []);
b.ngrid = struct('data_size', 8, 'data_type', 'double', ...
    'data_dim', [200 200 36 2], 'coordinates', [1;2;3]);
end
