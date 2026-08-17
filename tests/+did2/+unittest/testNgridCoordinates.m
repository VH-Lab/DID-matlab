function tests = testNgridCoordinates
%TESTNGRIDCOORDINATES `ngrid.coordinates` must survive the V_eta pipeline --
%   FOR THE CONSUMER THAT STILL PASSES THROUGH, which since 2026-08-17 is
%   `ontology_image` ALONE.
%
%   AMENDED 2026-08-17. The unqualified H1 was true when written and is not
%   now: `hartley_calc` no longer passes through, it DECOMPOSES (the signed
%   receptive_field fold), so for that class the requirement is the opposite --
%   no emitted document may still carry an `ngrid` block. Both claims live
%   below, one per consumer. The H1 is amended rather than left to be
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
%   TargetVersion 'V_eta' the V_delta `ngrid` superclass migrator ran, and its
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
%   V_delta migrator's output. A test written against them would be a test
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

% ===================== the V_eta superclass migrator =======================

function testVEtaSuperNgridCarriesAllFourV1Fields(testCase)
out = did2.convert.migrators_j.super.ngrid(v1NgridBody());
verifyEqual(testCase, out.ngrid.data_size, 8);
verifyEqual(testCase, out.ngrid.data_type, 'double');
verifyEqual(testCase, out.ngrid.data_dim, [4 4]);
verifyEqual(testCase, out.ngrid.coordinates, [1;2;3;4;1;2;3;4]);
% and it invents nothing -- the two V_delta names must not appear
verifyFalse(testCase, isfield(out.ngrid, 'dim_sizes'));
verifyFalse(testCase, isfield(out.ngrid, 'ndims'));
end

function testVEtaSuperNgridIsANoOpWhenTheBlockIsAbsent(testCase)
b = v1NgridBody();
b = rmfield(b, 'ngrid');
out = did2.convert.migrators_j.super.ngrid(b);
verifyFalse(testCase, isfield(out, 'ngrid'));
end

function testVEtaSuperNgridRejectsTheVDeltaOutputShape(testCase)
% THE GUARD, and it is the same guard ontology_image needed: a block carrying
% `dim_sizes`/`ndims` can only have come from the V_delta migrator or from a
% fixture built against a DID-side schema. Both are the mistake this family has
% already paid for twice, so it must be loud.
b = v1NgridBody();
b.ngrid = struct('dim_sizes', [4 4], 'ndims', 2, 'data_type', 'double');
verifyError(testCase, @() did2.convert.migrators_j.super.ngrid(b), ...
    'did2:convert:ngridVDeltaShape');
end

% ===================== the V_delta path is UNCHANGED =======================

function testVDeltaSuperclassMigratorStillReshapesAndDrops(testCase)
% The V_delta migrator is CORRECT for V_delta -- its schema declares ndims and
% dim_sizes and has nowhere to put coordinates. This test exists so that a
% future reader cannot mistake the V_eta override for a bug fix in the shared
% migrator, and so that "carry it" cannot quietly leak into the V_delta path.
out = did2.convert.migrators.ngrid(v1NgridBody());
verifyEqual(testCase, out.ngrid.ndims, 2);
verifyEqual(testCase, out.ngrid.dim_sizes, [4 4]);
verifyFalse(testCase, isfield(out.ngrid, 'coordinates'));
verifyFalse(testCase, isfield(out.ngrid, 'data_size'));
end

function testDispatcherUnderVDeltaStillUsesTheVDeltaMigrator(testCase)
% The override is selected by TargetVersion, so the default target must be
% completely untouched. `ndims` present == the V_delta migrator ran.
out = did2.convert.v1_to_v2(ontologyImageVintageB(), 'Validate', false);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('ngrid.ndims'), 2);
end

% ===================== end to end, through the dispatcher ==================

function testCoordinatesSurviveTheFullVEtaPipeline(testCase)
% THE REGRESSION TEST. Calling migrators_j.ontology_image directly already
% showed the coordinates surviving; the loss only appeared through the
% dispatcher, because the superclass pass runs before the concrete migrator.
% So this must go through v1_to_v2, or it tests nothing.
out = runJ(ontologyImageVintageB());
verifyEqual(testCase, out.summary.quarantine_count, 0);
verifyEqual(testCase, numel(out.migrated), 1);
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'ontology_image');
verifyEqual(testCase, doc.get('ngrid.coordinates'), [1;2;3;4;1;2;3;4]);
verifyEqual(testCase, doc.get('ngrid.data_dim'), [4 4]);
verifyEqual(testCase, doc.get('ngrid.data_size'), 8);
verifyEqual(testCase, doc.get('ngrid.data_type'), 'double');
end

function testTheCarriedBlockVALIDATESAgainstTheVEtaTombstone(testCase)
% The schema half and the migrator half are LOCKSTEP: the tombstone declares
% the four v1 names, so a body carrying them must pass the strict-fields check
% in +did2/+schema/cache.m. With Validate=false this test would pass even if
% the tombstone still declared ndims/dim_sizes -- which is precisely how a
% half-landed change would slip through.
out = did2.convert.v1_to_v2(ontologyImageVintageB(), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, out.summary.quarantine_count, 0, ...
    'the v1 ngrid block must validate against the restated V_eta tombstone');
verifyEqual(testCase, out.summary.migrated_count, 1);
end

function testHartleyCalcNoLongerCarriesNgridBecauseItDecomposes(testCase)
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
out = runJ(hartleyCalcV1());
verifyEqual(testCase, out.summary.quarantine_count, 0);

% `get` and `documentProperties`, NOT `document_properties`. The first draft
% of this test used the snake_case spelling and CI failed it -- which is
% exactly the defect CLAUDE.md records against `silentLoss`, where `asStruct`
% asked a `did2.document` for `document_properties`, got `[]` for every
% document, and reported `total_docs = 0` for two days while appearing to
% measure. The property is declared `documentProperties` at
% `+did2/document.m:41`; the tests above this one use the `get` dot-path
% accessor, so this one does too.
names = cellfun(@(d) d.get('document_class.class_name'), ...
    out.migrated, 'UniformOutput', false);
verifyEqual(testCase, sum(strcmp(names, 'receptive_field_calculation')), 1, ...
    sprintf(['the signed fold emits exactly one receptive_field_calculation; ' ...
             'got {%s}'], strjoin(names, ', ')));

% THE CLAIM THAT REPLACES THE OLD ONE: no emitted document still carries an
% `ngrid` block. Asserted over EVERY emitted document rather than over
% migrated{1}, because the fold turns one document into several and a
% first-only check would pass while a plane body carried the block.
for k = 1:numel(out.migrated)
    verifyFalse(testCase, ...
        isfield(out.migrated{k}.documentProperties, 'ngrid'), ...
        sprintf(['emitted %s still carries an `ngrid` block -- the fold is ' ...
                 'meant to CONSUME it, and a surviving block means the ' ...
                 'superclass carry and the decomposition are both running'], ...
                names{k}));
end
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
