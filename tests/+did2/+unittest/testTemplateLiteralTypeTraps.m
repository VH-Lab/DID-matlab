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
%                              (since 2026-10-29 carried whole as v1 instead,
%                              [binaryseries parameters carried], Jess Haley)
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
%   Both classes stay PASSTHROUGHS (a `stimulus_parameter` is carried whole as
%   v1 since 2026-10-29, [one folder, final classes only], so its placeholder is
%   kept as written). `stimulus_parameter` is held for the
%   stimulus model (#31) and `image_stack` / `image_stack_parameters` were taken
%   BACK OUT of _DELETE_PHASE8 precisely so a passthrough has a schema to
%   validate against. These tests gate the normalisation, not a fold. Since
%   2026-10-28 ([carried v1 validates against NDI templates]) a passthrough
%   whose class has no V2 schema is counted, not quarantined, so the
%   tombstones' existence is no longer pinned here.

tests = functiontests(localfunctions);
end

% ===================== harness =============================================

function out = runJ(v1)
%RUNJ The full pipeline at V_eta, validation OFF (transform assertions).
%   ALWAYS through v1_to_v2, never a direct migrator call: universalRenames
%   snake-cases `imageStack_parameters` -> `image_stack_parameters` before any
%   migrator runs (universalRenames.m:302-334), and a direct call would hand the
%   migrator a block key it never sees on the real pipeline.
%   ON THE RENAMED PATH ('RawV1Classes', {}): `imageStack` reads raw v1 since
%   2026-10-27 (did2.convert.rawV1Classes), where no superclass migrator runs
%   and a passthrough is the untouched v1 source; the v1 `image`, which shares
%   the block, reads raw too since 2026-10-30. The superclass migrator these
%   tests pin runs only on this renamed path; the raw path's refusals are
%   pinned by testRawV1RoundTripImage.
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta', ...
    'RawV1Classes', {});
end

function out = runJValidated(v1)
%RUNJVALIDATED The same, with the validator ARMED. This is the assertion that
%   actually matters: the placeholder is only worth dropping if dropping it is
%   what lets the document through. On the renamed path, as RUNJ.
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta', ...
    'RawV1Classes', {});
end

function d = onlyClass(testCase, out, className)
d = [];
n = 0;
for k = 1:numel(out.migrated)
    if strcmp(did2.unittest.helpers.classKey(out.migrated{k}), className)
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
v1.base = struct('id', 'is_1', 'session_id', 'sess_1', 'name', '', ...
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

function testStimulusParameterEmptyValuePlaceholderIsCarriedAsWritten(testCase)
% INVERTED 2026-10-29 from testStimulusParameterEmptyValuePlaceholderIsDropped.
% Decided by Jess Haley, 2026-10-29 [one folder, final classes only] (did-schema
% V_eta_go_forward_class_audit.md): a retire class's V2 file is deleted once no
% v1 document passes through under it, so a stimulus_parameter is now carried
% whole as v1 ([passthrough stays v1]). A carried document is not read against
% V2, so the template's `value: ""` (a char in a field NDI's schema types
% `double`, which validateTypeShape rejected) no longer has to be dropped to
% get through: it is kept as v1 wrote it, never coerced.
out = runJ(stimulusParameterBody(''));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'stimulus_parameter');
verifyEqual(testCase, char(d.get('document_class.schema_version')), 'did_v1');
b = d.get('stimulus_parameter');
verifyTrue(testCase, isfield(b, 'value'), 'the placeholder is kept, not dropped');
verifyEqual(testCase, b.value, '', 'and not coerced');
% the two string fields are untouched: `string` accepts '' (cache.m:1349-1371)
verifyEqual(testCase, b.ontology_name, 'NDIC:12');
verifyEqual(testCase, b.name, 'Command temperature constant');
end

function testStimulusParameterPlaceholderDocumentValidates(testCase)
% The assertion that matters: the document -- exactly what
% ndi.document('stimulus_parameter') produces -- gets through the validator
% instead of quarantining on typeMismatch. Since 2026-10-29 it is carried whole
% as v1 ([one folder, final classes only]), which is not validated against V2.
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

function testASubjectlessImageStackPassesThroughUntouchedAndCounted(testCase)
% INVERTED 2026-10-29 from testImageStackPlaceholderDocumentValidatesOnThePassthrough,
% which ran the RENAMED path ('RawV1Classes', {}) and asserted that dropping
% the empty `timestamp` placeholder let the passthrough validate against the
% did-schema `image_stack` tombstone. That tombstone is deleted (Jess Haley,
% 2026-10-27 [carried v1 validates against NDI templates]; 2026-10-29
% [base.name kept until retire classes leave], did-schema
% V_eta_go_forward_class_audit.md). On the path real data takes, `imageStack`
% reads raw v1 (did2.convert.rawV1Classes): a subject-less stack (NDI's writer
% leaves the edge empty at doImport.m:789/811/827) is returned UNTOUCHED, so it
% is a v1 document, counted (passthrough_unvalidated_no_schema), not
% quarantined, with its id and its placeholder as v1 wrote them.
v1 = imageStackBody([]);
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.migrated), 1);
d = out.migrated{1};
verifyEqual(testCase, d.get('base.id'), 'is_1');   % passthrough: id preserved
verifyEqual(testCase, out.summary.passthrough_unvalidated_no_schema_count, 1);
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

% RETIRED 2026-10-28 with did-schema's deprecated/ tombstones (Decided by Jess
% Haley, 2026-10-27 [carried v1 validates against NDI templates], did-schema
% V_eta_go_forward_class_audit.md): a carried or passed-through v1 document is
% checked against NDI's v1 templates (did2.validate.v1Document), not a
% did-schema tombstone, and one whose class has no V2 schema is counted
% (summary.passthrough_unvalidated_no_schema_count), never quarantined
% (v1_to_v2.m). This test asserted the `image_stack` / `image_stack_parameters` schema EXISTS, which
% that decision removes; the passthrough tests beside it, which assert no
% quarantine, are the guard now.

function testTheBuiltPathStillReadsARealTimestamp(testCase)
% A real v1 timestamp survives the built path. INVERTED 2026-10-30 for
% [acquisition time on its clock] (Decided by Jess Haley, did-schema
% V_eta_go_forward_class_audit.md): the fixture's clock (exp_global_time) is
% not UTC, so the datenum is the AFO:AFR_0001158 "acquisition time"
% condition's source_value, its canonical left out and listed as a gap in the
% run's migration report ([migration record], 2026-11-01),
% and the clock is on the observation's session anchor -- no longer the
% "acquisition timestamp (<clock>)" label with the datenum as its value.
[obs, anchor] = builtStack(testCase, 739038.5, 'exp_global_time');
c = obs.get('statement.conditions');
verifyEqual(testCase, char(c.variable.node), 'AFO:AFR_0001158');
verifyEqual(testCase, str2double(c.quantity.source_value), 739038.5);
verifyFalse(testCase, isfield(c.quantity, 'value'), ...
    'a datenum on a clock that is not UTC has no canonical');
verifyEqual(testCase, char(c.source_unit.name), 'day');
s = obs.toStruct();
verifyFalse(testCase, isfield(s.base, 'needs_info'));
g = did2.convert.migrationReport('gaps', char(s.base.id));
verifyEqual(testCase, numel(g), 1);
if isempty(g); return; end
verifyEqual(testCase, g(1).field, 'statement.conditions(1).quantity.value');
verifyTrue(testCase, contains(g(1).reason, '''exp_global_time'''));
did2.unittest.helpers.verifyClock(testCase, anchor.get('relative_time_reference.value.clock'), ...
    'exp_global_time');   % by node [clock terms get nodes]
verifyEqual(testCase, char(anchor.get('relative_time_reference.value.relation').node), ...
    'time:intervalDuring');
end

function testAUtcTimestampIsTheObservationsTimeReference(testCase)
% [acquisition time on its clock] as amended by [UTC acquisition time is
% absolute] (Decided by Jess Haley, 2026-10-31, did-schema
% did_v2_go_forward_class_audit.md; docs/V2_PLAN.md G65: "That should be an
% absolute time reference"): on clock utc the datenum IS the observation's time
% reference, an absolute_time_reference holding the UTC instant (the datenum as
% its source_value), not a relative_time_reference to the session; no
% condition and no gap. INVERTED: it pinned the relative shape
% (start = datenum x 86400 s on clock utc) until then.
[obs, anchor] = builtStack(testCase, 739038.5, 'utc');
s = obs.toStruct();
verifyFalse(testCase, isfield(s.statement, 'conditions') && ~isempty(s.statement.conditions));
verifyEmpty(testCase, did2.convert.migrationReport('gaps', char(s.base.id)));
verifyEqual(testCase, anchor.get('document_class.class_name'), 'absolute_time_reference');
st = anchor.get('absolute_time_reference.value.start');
verifyEqual(testCase, char(st.utc), '2023-06-01T12:00:00.000Z');
verifyEqual(testCase, str2double(st.source_value), 739038.5);
a = anchor.toStruct();
verifyFalse(testCase, isfield(a, 'time_reference') && isfield(a.time_reference, 'clock_tolerance') ...
    && ~isempty(a.time_reference.clock_tolerance));
end

function testAnApproxUtcTimestampKeepsItsFiveSeconds(testCase)
% approx_utc is clock utc within 5 s (NDI +ndi/+time/clocktype.m): the same
% absolute instant with a 5 s clock_tolerance ([UTC acquisition time is
% absolute], Jess Haley, 2026-10-31)
[~, anchor] = builtStack(testCase, 739038.5, 'approx_utc');
verifyEqual(testCase, anchor.get('document_class.class_name'), 'absolute_time_reference');
verifyEqual(testCase, anchor.get('time_reference.clock_tolerance.seconds'), 5);
verifyEqual(testCase, char(anchor.get('absolute_time_reference.value.start').utc), ...
    '2023-06-01T12:00:00.000Z');
end

function [obs, anchor] = builtStack(testCase, ts, clk)
% the built path (a subject, no plate row) for a stack with TS on clock CLK
v1 = imageStackBody(ts);
v1.imageStack_parameters.clocktype = clk;
v1.depends_on(1).value = 'sub_1';          % give it a subject -> the built path
% and no plate row: since [generic stage is lossless] (Jess Haley, 2026-10-25) a
% stack that names one is carried whole as v1 (no edge for it on the observation)
v1.depends_on(2).value = '';
% its own migration run: the gaps of this stack only (the stacks of these
% tests share their ids)
did2.convert.migrationReport('begin');
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = cellfun(@(d) char(did2.unittest.helpers.classKey(d)), out.migrated, ...
    'UniformOutput', false);
verifyTrue(testCase, any(strcmp(names, 'observation+intensity')));
obs = out.migrated{find(strcmp(names, 'observation+intensity'), 1)};
% the observation's time reference: absolute on a UTC clock, else relative
k = find(strcmp(names, 'absolute_time_reference'), 1);
if isempty(k)
    k = find(strcmp(names, 'relative_time_reference'), 1);
end
anchor = out.migrated{k};
end


function testTheBuiltPathSurvivesTheDroppedPlaceholder(testCase)
% An empty timestamp placeholder is dropped, not turned into a zero. UPDATED for
% #88: with no timestamp the statement carries no condition at all.
v1 = imageStackBody([]);
v1.depends_on(1).value = 'sub_1';
% and no plate row: since [generic stage is lossless] (Jess Haley, 2026-10-25) a
% stack that names one is carried whole as v1 (no edge for it on the observation)
v1.depends_on(2).value = '';
out = runJ(v1);
verifyEmpty(testCase, out.quarantine);
names = cellfun(@(d) char(did2.unittest.helpers.classKey(d)), out.migrated, ...
    'UniformOutput', false);
obs = out.migrated{find(strcmp(names, 'observation+intensity'), 1)};
s = obs.toStruct();
verifyFalse(testCase, isfield(s.statement, 'conditions') && ~isempty(s.statement.conditions), ...
    'an absent timestamp must not become a condition (a 0 would read as a real datenum)');
verifyTrue(testCase, any(strcmp(names, 'sampled_body')));
end
