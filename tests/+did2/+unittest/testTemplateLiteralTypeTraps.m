function tests = testTemplateLiteralTypeTraps
%TESTTEMPLATELITERALTYPETRAPS The two LIVE template-literal type mismatches.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment this file was
%   written in, so every assertion below is UNVERIFIED. Read it as a
%   specification of intended behaviour, not as a passing suite.
%   Run with:  results = runtests('did2.unittest.testTemplateLiteralTypeTraps');
%
%   Do NOT merge these into testMigratorsJ.m -- that file is being edited
%   concurrently.
%
%   ---------------------------------------------------------------------
%   THE DEFECT, IN ONE PARAGRAPH
%   ---------------------------------------------------------------------
%   NDI's database_documents templates carry '' or [] placeholders for fields
%   NDI's OWN schema_documents type `integer` / `double` / `timestamp`. V_eta
%   takes its types from the schema, and +did2/+schema/cache.m admits NO empty
%   representation of a numeric field:
%
%     cache.m:1229   validateTypeShape runs UNCONDITIONALLY on a field that is
%                    PRESENT -- there is no is-empty short circuit ahead of it
%     cache.m:1383   case {'double','matrix'}: ~isnumeric -> typeMismatch
%                    ==> the char '' FAILS
%     cache.m:1258   mustBeScalar && ~isScalarValue -> notScalar
%                    ==> the empty double [] FAILS
%     cache.m:1212-1225  an ABSENT field that is not mustBeNonEmpty returns
%                    early, before any type check       ==> ABSENCE VALIDATES
%
%   So the repair is to DROP the placeholder, never to coerce it. A non-empty
%   value that cannot be interpreted ERRORS instead of being guessed at --
%   the precedent is migrators_j/binaryseries_parameters.m, and the reason is
%   that this whole repair track exists to remove guesses.
%
%   ---------------------------------------------------------------------
%   WHY THESE TWO, AND NOT THE OTHER 31 ROWS
%   ---------------------------------------------------------------------
%   The sweep of all 91 NDI templates against the V_eta classes they map to
%   found 33 such fields across 20 classes. 17 of those classes have a migrator
%   that overwrites the placeholder with a real value, so they are LATENT.
%   THREE are exposed on a passthrough path, where nothing overwrites anything:
%
%     binaryseries_parameters  time_size / data_size / data_dim   ALREADY FIXED
%     stimulus_parameter       value                              <- here
%     imageStack_parameters    timestamp                          <- here
%
%   ---------------------------------------------------------------------
%   BOTH IN-TREE WRITERS SET BOTH FIELDS. THAT IS NOT A REASON TO SKIP.
%   ---------------------------------------------------------------------
%   Said plainly, because the opposite reading is the recurring epistemic error
%   this project keeps writing down:
%
%     stimulus_parameter.value      DENOMINATOR 5 .m files on NDI origin/main
%       mention the class; ONE constructs it, at three sites, and all three set
%       `value` numerically
%       (+setup/+conv/+marder/temptable2stimulusparameters.m:44-46, :56-58, :63-65).
%     imageStack_parameters.timestamp  DENOMINATOR 2 production converters,
%       7 ndi.document('imageStack') sites; every one builds a parameters struct
%       carrying `timestamp` (+setup/+conv/+babu/import.m:463,
%       +setup/+conv/+haley/doImport.m:414 and :788).
%
%   THE CORPORA ARE A SAMPLE OF DATASETS, NOT THE UNIVERSE, and
%   `ndi.document(<class>)` fills every unset field from the TEMPLATE. A caller
%   who does not pass the block gets the placeholder, and neither class has a
%   migrator downstream that would overwrite it. So the exposure is real and
%   the fixtures below are built from the TEMPLATE deliberately -- which is
%   normally the mistake this track removes, and is here the exact shape under
%   test.
%
%   ---------------------------------------------------------------------
%   NOTHING HERE ASSERTS A DISPOSITION
%   ---------------------------------------------------------------------
%   Both classes stay PASSTHROUGHS. `stimulus_parameter` is held for the
%   stimulus model (#31) and `image_stack` / `image_stack_parameters` were taken
%   BACK OUT of _DELETE_PHASE8 precisely so a passthrough has a schema to
%   validate against. These tests gate the normalisation, not a fold, and
%   testImageStackParametersTombstoneStillExists below pins the second half of
%   that so a future re-deletion fails here rather than in a corpus run.

tests = functiontests(localfunctions);
end

% ===================== harness =============================================

function out = runJ(v1)
%RUNJ The full pipeline at V_eta, validation OFF (transform assertions).
%   ALWAYS through v1_to_v2, never a direct migrator call: universalRenames
%   snake-cases `imageStack_parameters` -> `image_stack_parameters` before any
%   migrator runs (universalRenames.m:302-334), and a direct call would hand the
%   migrator a block key it never sees on the real pipeline.
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runJValidated(v1)
%RUNJVALIDATED The same, with the validator ARMED. This is the assertion that
%   actually matters: the placeholder is only worth dropping if dropping it is
%   what lets the document through.
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
end

function d = onlyClass(testCase, out, className)
d = [];
n = 0;
for k = 1:numel(out.migrated)
    if strcmp(out.migrated{k}.get('document_class.class_name'), className)
        d = out.migrated{k};
        n = n + 1;
    end
end
assertEqual(testCase, n, 1, sprintf('expected exactly one %s document', className));
end

% ===================== fixtures ============================================

function v1 = stimulusParameterBody(value, withValueField)
%STIMULUSPARAMETERBODY A did_v1 stimulus_parameter.
%   THE TEMPLATE, LITERAL FOR LITERAL:
%     origin/main:src/ndi/ndi_common/database_documents/stimulus/stimulus_parameter.json
%       superclasses [ base, epochid ]
%       depends_on   [ stimulus_element_id ]
%       stimulus_parameter { ontology_name "", name "", value "" }
%   The epoch id and the element edge are set because the WRITER sets both
%   (temptable2stimulusparameters.m:41-47) and `epochid.epochid` is
%   mustBeNonEmpty in V_eta.
if nargin < 2; withValueField = true; end
v1 = struct();
v1.document_class = struct('class_name', 'stimulus_parameter', ...
    'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'epochid', 'class_version', '1.0.0') ]);
v1.depends_on = struct('name', {'stimulus_element_id'}, 'value', {'stim_elem_1'});
v1.base = struct('id', 'sp_1', 'session_id', 'sess_1', 'name', '', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.epochid = struct('epochid', 't00023');
blk = struct('ontology_name', 'NDIC:12', 'name', 'Command temperature constant');
if withValueField
    blk.value = value;
end
v1.stimulus_parameter = blk;
end

function v1 = imageStackBody(timestamp, withTimestampField)
%IMAGESTACKBODY A did_v1 imageStack carrying its imageStack_parameters block.
%   Template: origin/main:src/ndi/ndi_common/database_documents/data/imageStack.json
%       superclasses [ base, data/imageStack_parameters ]
%       depends_on   [ subject_id, document_id ]
%   NOTE `subject_id` IS LEFT EMPTY ON PURPOSE. That is the shape NDI's own
%   writer produces at doImport.m:789/811/827 (only document_id is set), and it
%   is the branch that makes this trap live: migrators_j/image_stack.m's
%   subject-less guard PASSES THE DOCUMENT THROUGH, so the template literal
%   reaches the validator untouched.
%   Block keys are spelled as NDI spells them (camelCase); universalRenames
%   snake-cases them, which is why these fixtures must run through v1_to_v2.
if nargin < 2; withTimestampField = true; end
v1 = struct();
v1.document_class = struct('class_name', 'imageStack', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'base', 'class_version', '1.0.0'), ...
                      struct('class_name', 'imageStack_parameters', ...
                             'class_version', '1.0.0') ]);
v1.depends_on = [ struct('name', 'subject_id', 'value', ''), ...
                  struct('name', 'document_id', 'value', 'plate_row_1') ];
v1.base = struct('id', 'is_1', 'session_id', 'sess_1', 'name', 'img', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.imageStack = struct('label', 'A brightfield image of a plate.', ...
    'formatOntology', 'NCIT:C70631');
blk = struct('dimension_order', 'YX', 'dimension_labels', 'height,width', ...
    'dimension_size', [1024 1024], 'dimension_scale', [2 2], ...
    'dimension_scale_units', 'micrometer,micrometer', ...
    'data_type', 'uint16', 'data_limits', [0 65535], ...
    'clocktype', 'exp_global_time');
if withTimestampField
    blk.timestamp = timestamp;
end
v1.imageStack_parameters = blk;
end

% ===================== stimulus_parameter.value ============================

function testStimulusParameterEmptyValuePlaceholderIsDropped(testCase)
% THE REPAIR. The template's `value: ""` is a char in a field NDI's own schema
% types `double`, so validateTypeShape (cache.m:1229 -> :1383) rejects it. There
% is no numeric substitute that invents nothing -- 0 is a recorded measurement,
% NaN is a value the field may reject -- and absence is what "unset" means and
% the only spelling that passes (cache.m:1212-1225).
out = runJ(stimulusParameterBody(''));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'stimulus_parameter');
b = d.get('stimulus_parameter');
verifyFalse(testCase, isfield(b, 'value'), ...
    'the empty char placeholder must be DROPPED, not coerced');
% the two string fields are untouched: `string` accepts '' (cache.m:1349-1371)
verifyEqual(testCase, b.ontology_name, 'NDIC:12');
verifyEqual(testCase, b.name, 'Command temperature constant');
end

function testStimulusParameterPlaceholderDocumentValidates(testCase)
% The assertion that matters: with the placeholder dropped the document -- which
% is otherwise exactly what ndi.document('stimulus_parameter') produces -- gets
% through the validator instead of quarantining on typeMismatch.
out = runJValidated(stimulusParameterBody(''));
verifyEmpty(testCase, out.quarantine);
verifyEqual(testCase, numel(out.migrated), 1);
end

function testStimulusParameterRealValueIsUntouched(testCase)
% The writer's own shape (temptable2stimulusparameters.m:44 assigns
% last_match.temp{1}). A real number passes through byte for byte, and the
% id is preserved because this is a passthrough.
out = runJValidated(stimulusParameterBody(21.5));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'stimulus_parameter');
verifyEqual(testCase, d.get('stimulus_parameter.value'), 21.5, 'AbsTol', 1e-12);
verifyEqual(testCase, d.get('base.id'), 'sp_1');
end

function testStimulusParameterVectorValueSurvives(testCase)
% `value` is NOT scalar-constrained in V_eta ("the constant branch assigns a
% whole cell"), so a multi-element numeric value must NOT be touched. This pins
% the difference from imageStack_parameters.timestamp, which IS scalar.
out = runJ(stimulusParameterBody([18 21 24]));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'stimulus_parameter');
verifyEqual(testCase, d.get('stimulus_parameter.value'), [18 21 24]);
end

function testStimulusParameterAbsentValueIsNotManufactured(testCase)
% ensureClassBlocks pads missing BLOCKS, never missing FIELDS
% (v1_to_v2.m:473-478), so a document that never had `value` must not acquire a
% 0. If this ever goes red the padding has changed and the repair is moot.
out = runJ(stimulusParameterBody([], false));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'stimulus_parameter');
verifyFalse(testCase, isfield(d.get('stimulus_parameter'), 'value'));
end

function testStimulusParameterNonEmptyCharValueErrorsRatherThanGuessing(testCase)
% '32' -> 32 would be a GUESS. NDI's schema types the field `double` and its
% writer assigns out of a table cell, so a char here means the source is not
% what we think it is. A loud quarantine with a legible reason beats a silent
% typeMismatch -- the same call binaryseries_parameters makes.
out = runJ(stimulusParameterBody('32'));
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, numel(out.migrated), 0);
end

% ===================== imageStack_parameters.timestamp =====================

function testImageStackTimestampEmptyPlaceholderIsDropped(testCase)
% THE REPAIR, and note it fails DIFFERENTLY from the one above: [] is numeric,
% so it PASSES validateTypeShape and dies one line later on mustBeScalar
% (cache.m:1258). Same disposition, different error -- which is why the sweep
% had to look at the type AND the shape, not just the type.
out = runJ(imageStackBody([]));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'image_stack');
p = d.get('image_stack_parameters');
verifyFalse(testCase, isfield(p, 'timestamp'), ...
    'the empty [] placeholder must be DROPPED, not coerced to 0');
% every other field of the block is left exactly as it was
verifyEqual(testCase, p.dimension_order, 'YX');
verifyEqual(testCase, p.dimension_size, [1024 1024]);
verifyEqual(testCase, p.data_limits, [0 65535]);
verifyEqual(testCase, p.clocktype, 'exp_global_time');
end

function testImageStackPlaceholderDocumentValidatesOnThePassthrough(testCase)
% The whole point. This document has NO subject (NDI's writer leaves the edge
% empty at doImport.m:789/811/827), so migrators_j/image_stack.m's guard passes
% it through -- and a passthrough is exactly where an unnormalised template
% literal reaches the validator. With the placeholder dropped it validates.
out = runJValidated(imageStackBody([]));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'image_stack');
verifyEqual(testCase, d.get('base.id'), 'is_1');   % passthrough: id preserved
end

function testImageStackRealTimestampIsUntouched(testCase)
% The writers' own shape: a scalar datenum
% (babu/import.m:463 / haley/doImport.m:414,:788 `convertTo(...,'datenum')`).
out = runJValidated(imageStackBody(739038.5));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'image_stack');
verifyEqual(testCase, d.get('image_stack_parameters.timestamp'), 739038.5, ...
    'AbsTol', 1e-9);
end

function testImageStackTimestampZeroIsAValueNotAPlaceholder(testCase)
% A recorded 0 is a measurement, not a blank -- the same rule cache.m's
% isVacuousValue states ("a real numeric 0 or a logical false IS a value").
% Dropping it would delete a datum; this pins that it is kept.
out = runJ(imageStackBody(0));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'image_stack');
verifyEqual(testCase, d.get('image_stack_parameters.timestamp'), 0);
end

function testImageStackNonScalarTimestampErrorsRatherThanTruncating(testCase)
% NDI's schema says this is the acquisition time of the FIRST image -- one
% number. Two numbers means the source is not what we think it is, and nothing
% establishes which element is meant, so it is not truncated.
out = runJ(imageStackBody([739038.5 739039.5]));
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, numel(out.migrated), 0);
end

function testImageStackCharTimestampErrorsRatherThanParsing(testCase)
% A date STRING has no established encoding here: the clock is named separately
% by `clocktype`, so parsing would be a guess about both format and epoch.
out = runJ(imageStackBody('2024-06-01'));
verifyEqual(testCase, numel(out.quarantine), 1);
verifyEqual(testCase, numel(out.migrated), 0);
end

function testImageStackAbsentTimestampIsNotManufactured(testCase)
% A block that never carried the field must not acquire one.
out = runJ(imageStackBody([], false));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'image_stack');
verifyFalse(testCase, isfield(d.get('image_stack_parameters'), 'timestamp'));
end

function testImageStackParametersTombstoneStillExists(testCase)
% A GUARD ON THE SCHEMA, NOT ON THE MIGRATOR. `image_stack` and
% `image_stack_parameters` were taken BACK OUT of _DELETE_PHASE8 so that the
% subject-less passthrough has something to validate against. Re-deleting them
% would strand 4,563 JH documents in quarantine (the epochfiles_ingested
% regression, exactly) -- and this normalisation would become dead code without
% anything saying so. Fail here instead.
cache = did2.schema.cache.shared();
chain = cache.superclasses('image_stack');
verifyTrue(testCase, any(strcmp(chain, 'image_stack_parameters')), ...
    ['image_stack no longer inherits image_stack_parameters -- if the ' ...
     'tombstone was re-deleted, the subject-less passthrough has no schema.']);
end

function testTheBuiltPathStillReadsARealTimestamp(testCase)
% The superclass migrator runs BEFORE the concrete one (v1_to_v2.m:156 then
% :165), so it must not disturb the FOLD either. With a subject present,
% image_stack builds its observation triple and clockFromParams reads the
% timestamp into the body's t0. A real value must still get there.
v1 = imageStackBody(739038.5);
v1.depends_on(1).value = 'sub_1';          % give it a subject -> the built path
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
verifyTrue(testCase, any(strcmp(names, 'image_observation')));
body = out.migrated{find(strcmp(names, 'sampled_body'), 1)};
verifyEqual(testCase, body.get('sampled_body.sample_time.t0.source_value'), ...
    739038.5, 'AbsTol', 1e-9);
end

function testTheBuiltPathSurvivesTheDroppedPlaceholder(testCase)
% And with the placeholder dropped, the fold must still work -- image_stack.m
% reads the timestamp through a guarded getField, so an ABSENT field yields the
% same t0 = 0 it used to get from []. If this goes red the two repairs are
% fighting.
v1 = imageStackBody([]);
v1.depends_on(1).value = 'sub_1';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
body = out.migrated{find(strcmp(names, 'sampled_body'), 1)};
verifyEqual(testCase, body.get('sampled_body.sample_time.t0.source_value'), 0, ...
    'AbsTol', 1e-12);
end
