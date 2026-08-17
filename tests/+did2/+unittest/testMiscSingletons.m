function tests = testMiscSingletons
%TESTMISCSINGLETONS The "misc singletons" family (TargetVersion 'V_eta'):
%   `binaryseries_parameters`, `projectvar`, `interaction_purpose`.
%
%   STATUS: NEVER EXECUTED. There is no MATLAB in the environment this file was
%   written in, so every assertion below is UNVERIFIED. Read it as a
%   specification of intended behaviour, not as a passing suite. Run
%       results = runtests('did2.unittest.testMiscSingletons');
%   and treat any red as a defect in the code or in these tests, not as a
%   surprise.
%
%   Do NOT merge these into testMigratorsJ -- that file is being edited
%   concurrently.
%
%   ---------------------------------------------------------------------
%   THE SIGNED DISPOSITIONS
%   ---------------------------------------------------------------------
%   TEAM-SIGN-OFF [misc singletons], jess 2026-08-09
%   (did-schema/schemas/V_eta_go_forward_class_audit.md):
%
%     binaryseries_parameters  retires INTO THE data_body MODEL -- time_type ->
%                              the time axis's datum_type, data_type -> the
%                              statement's, data_dim -> the axis count,
%                              samples_regular_intervals -> the axis `regular`
%                              flag.
%                              THIS ENTRY USED TO END "NONE of those slots is
%                              built: that is #45, blocked on #32". STALE --
%                              #45 was SIGNED 2026-08-14 and THREE OF THE FOUR
%                              slots are now built (see
%                              testBinaryseriesFoldBlockersAreStillInTheSchema,
%                              which measures it rather than asserting it). It
%                              still PASSES THROUGH, for the OTHER blocker: the
%                              class carries no edge, and `subject_statement`
%                              is abstract. These tests gate the passthrough,
%                              not the fold.
%     projectvar               stays a deprecated passthrough until real
%                              documents exist to model its untyped `data`
%                              field against.
%     interaction_purpose      is a TARGET, not a source. Its emitter is the NDI
%                              SECOND PASS (#75/#31): pass 1 emits nothing and
%                              carries openminds_stimulus through, which
%                              testMigratorsJ + testFixtureCorpus already cover.
%                              What is NOT covered anywhere is the target
%                              itself, so that is what the tests here take.
%
%   ---------------------------------------------------------------------
%   THE FIXTURES, AND WHERE EACH ONE COMES FROM
%   ---------------------------------------------------------------------
%   Ground-truth rule: NDI origin/main templates are did_v1 truth, and where
%   TEMPLATE and WRITER disagree the WRITER wins. Fixtures are never built from
%   a DID-side schema.
%
%     projectvar               FROM THE WRITER. +ndi/+database/+fun/
%                              projectvardef.m sets base.name, projectvar.type,
%                              .description and .data -- and NOTHING else, so
%                              project/user/lab and the element_id edge are
%                              empty on every real document. NOTE the NDI SCHEMA
%                              declares a field `date` that the template and the
%                              writer do not have, while both have `data`; the
%                              writer wins and the fixture carries `data`.
%     binaryseries_parameters  FROM THE TEMPLATE, because THERE IS NO WRITER.
%                              Denominator: 1467 files tracked on NDI
%                              origin/main, 1002 of them .m; `git grep -i
%                              binaryseries origin/main` matches 3 files and NOT
%                              ONE is a .m -- the template, its schema, and
%                              ndiDocumentAttributes.json. Said plainly because
%                              a template-built fixture is normally the mistake
%                              this track exists to remove; here it is the only
%                              ground truth that exists.
%
%   ---------------------------------------------------------------------
%   TESTS THAT MUST BE INVERTED, NOT PATCHED
%   ---------------------------------------------------------------------
%   Three tests below assert CURRENT, KNOWN-INCOMPLETE behaviour on purpose, so
%   that nobody discovers the change by accident on a corpus run:
%
%     testProjectvarNumericPayloadQuarantinesToday
%         `projectvar.data` is an ARBITRARY caller-supplied value typed `string`
%         in V_eta, so a non-empty NUMERIC payload quarantines. The meta-schema
%         has no union and no `any`, so this cannot be fixed in the tombstone --
%         it is an open modelling question. INVERT when it is answered.
%
%     testInteractionPurposeMissingEdgeFamilyIsReportOnly
%         `interaction_id_#` declares min_count 1 and NOTHING ENFORCES IT
%         (#63): cache.requiredDependencies excludes numbered families by
%         design, so a purpose with no interaction validates clean and is only
%         COUNTED, by silentLoss. INVERT when the family gate is armed.
%
%     testBinaryseriesFoldIsNotBuiltAndNeedsMoreThanAxes
%         The signed fold (-> subject_statement + sampled_body) is not built,
%         and this pins BOTH reasons so that #45 landing is not mistaken for
%         the all-clear. #45 HAS NOW LANDED and this test is unchanged, which
%         is the whole point of having written it that way. INVERT only after
%         the team has answered WHICH statement these parameters attach to --
%         see the migrator header.
%
%   And ONE test that is deliberately NOT an invert-when, because it measures
%   the schema instead of asserting a conclusion about it:
%
%     testBinaryseriesFoldBlockersAreStillInTheSchema
%         Reads the LIVE V_eta schemas for what the signature's four mappings
%         need, and goes red the day any of it changes -- in either direction.
%         It is the answer to a specific failure this repo has already paid
%         for: the migrator header carried a hand-typed census ("`datum_type`:
%         0 declarations") that went stale in the PESSIMISTIC direction when
%         #45 landed, so the record claimed less built than existed. A census
%         typed into a comment cannot notice that; this one can.

tests = functiontests(localfunctions);
end

% ===================== harness =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function d = onlyClass(testCase, out, className)
%ONLYCLASS The single migrated document of CLASSNAME (fails if not exactly one).
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

function s = blockOf(doc, blockName)
s = doc.get(blockName);
end

function v = depValue(doc, name)
% Read the edge tolerantly: a depends_on entry is spelled `value` on a body a
% migrator built and `document_id` once universalRenames has normalised it
% (universalRenames.m:369-422). Both shapes are live on this path.
v = '';
s = doc;
if isa(doc, 'did2.document'); s = doc.toStruct(); end
if ~isfield(s, 'depends_on') || isempty(s.depends_on); return; end
for k = 1:numel(s.depends_on)
    d = s.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(char(d.name), name); continue; end
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    end
    return;
end
end

% ===================== fixtures ============================================

function v1 = binaryseriesTemplateBody(id, sessionId)
% THE TEMPLATE, LITERAL FOR LITERAL:
%   origin/main:src/ndi/ndi_common/database_documents/data/binaryseries_parameters.json
%       time_size "", time_type "", data_size "", data_type "",
%       data_dim "", samples_regular_intervals 0
% This is what ndi.document('binaryseries_parameters') produces for a caller
% who sets nothing (+ndi/document.m:54-56 readblankdefinition, then only the
% name/value pairs the caller passed are assigned).
v1 = struct();
v1.document_class = struct('class_name', 'binaryseries_parameters', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', id, 'session_id', sessionId, 'name', 'bsp', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
v1.binaryseries_parameters = struct( ...
    'time_size', '', 'time_type', '', 'data_size', '', 'data_type', '', ...
    'data_dim', '', 'samples_regular_intervals', 0);
end

function v1 = binaryseriesPopulatedBody(id, sessionId)
% The same class with the values NDI's SCHEMA gives as defaults -- i.e. what a
% caller who filled the document in would store. Types from
%   origin/main:src/ndi/ndi_common/schema_documents/data/binaryseries_parameters_schema.json
%       time_size integer (default 32), time_type string (default float32),
%       data_size integer (32), data_type string (float32),
%       data_dim integer (1), samples_regular_intervals integer (0)
v1 = binaryseriesTemplateBody(id, sessionId);
v1.binaryseries_parameters = struct( ...
    'time_size', 32, 'time_type', 'float32', ...
    'data_size', 32, 'data_type', 'float32', ...
    'data_dim', 1, 'samples_regular_intervals', 1);
end

function v1 = projectvarWriterBody(id, sessionId, data)
% THE WRITER: +ndi/+database/+fun/projectvardef.m sets exactly
%   base.name, projectvar.type, projectvar.description, projectvar.data
% and nothing else, so project/user/lab keep the template's '' and the
% element_id edge is empty -- despite the NDI schema marking it
% "mustbenotempty", which is enforced nowhere.
v1 = struct();
v1.document_class = struct('class_name', 'projectvar', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.depends_on = struct('name', {'element_id'}, 'value', {''});
v1.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'trial_notes', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.projectvar = struct( ...
    'project', '', 'type', 'annotation', 'user', '', 'lab', '', ...
    'description', 'free-text note attached to the project', 'data', data);
end

function body = interactionPurposeBody(id, sessionId, edgeNames)
% A V_eta TARGET document -- what the NDI second pass will write for each of the
% 635 StimulationApproach documents. NOT a did_v1 shape: this class has no v1
% source (0 of 1467 files on NDI origin/main mention it in any casing).
body = struct();
body.document_class = struct('class_name', 'interaction_purpose', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
body.depends_on = struct('name', {}, 'document_id', {});
for k = 1:numel(edgeNames)
    body.depends_on(end+1) = struct('name', edgeNames{k}, ...
        'document_id', sprintf('interaction_%d', k)); %#ok<AGROW>
end
% `creation_timestamp`, not `datestamp` (did-schema 72fa57f). This helper
% builds a V_eta body DIRECTLY and hands it to the validator, so it never
% passes through did2.convert.v1_to_v2 and never gets the outbound rename --
% which is exactly why it failed loudly rather than silently.
body.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'creation_timestamp', '2024-06-01T12:00:00.000Z');
body.interaction_purpose = struct( ...
    'purpose', struct('node', 'NDIC:00000012', ...
                      'name', 'Assessing spatial frequency tuning'), ...
    'comment', '');
end

% ===================== binaryseries_parameters =============================

function testBinaryseriesTemplatePlaceholdersAreDropped(testCase)
% THE REPAIR. NDI's template supplies the CHAR '' for three fields its own
% schema types `integer`, and V_eta takes its types from that schema. Against
% +did2/+schema/cache.m there is NO empty representation that validates:
% validateTypeShape runs unconditionally on a present field (cache.m:1169) and
% `integer` demands isnumeric (cache.m:1318), so '' is a typeMismatch; [] is
% numeric but fails mustBeScalar (cache.m:1200). Absence is the only spelling
% of "unset" that passes -- an absent optional field returns early at
% cache.m:1157-1163 -- so the placeholder is dropped, not coerced.
out = runJ(binaryseriesTemplateBody('bsp_1', 'sess_1'));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'binaryseries_parameters');
b = blockOf(d, 'binaryseries_parameters');
verifyFalse(testCase, isfield(b, 'time_size'), 'placeholder time_size must be dropped');
verifyFalse(testCase, isfield(b, 'data_size'), 'placeholder data_size must be dropped');
verifyFalse(testCase, isfield(b, 'data_dim'),  'placeholder data_dim must be dropped');
% the three that are NOT integer-typed are untouched: `string` accepts '' and
% `samples_regular_intervals` is a real 0 in the template
verifyEqual(testCase, b.time_type, '');
verifyEqual(testCase, b.data_type, '');
verifyEqual(testCase, b.samples_regular_intervals, 0);
% and the id is preserved -- a passthrough must never renumber a document
verifyEqual(testCase, d.get('base.id'), 'bsp_1');
end

function testBinaryseriesPopulatedBodyPassesThroughVerbatim(testCase)
% A filled-in document is carried WHOLE. The migrator's only job is the
% placeholder; it must not touch a real value, and it must not fold -- the fold
% into the data_body model is #45, and `axes[]` / `datum_type` / `regular` do
% not exist yet.
out = runJ(binaryseriesPopulatedBody('bsp_2', 'sess_1'));
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'binaryseries_parameters');
b = blockOf(d, 'binaryseries_parameters');
verifyEqual(testCase, b.time_size, 32);
verifyEqual(testCase, b.time_type, 'float32');
verifyEqual(testCase, b.data_size, 32);
verifyEqual(testCase, b.data_type, 'float32');
verifyEqual(testCase, b.data_dim, 1);
verifyEqual(testCase, b.samples_regular_intervals, 1);
verifyEqual(testCase, d.get('base.id'), 'bsp_2');
end

function testBinaryseriesDataTypeFieldSurvivesUniversalRenames(testCase)
% `binaryseries_parameters.data_type` COLLIDES BY NAME with V_eta's `data_type`
% CATEGORY. The tombstone's own documentation asserts the field "survives
% universalRenames unchanged"; that claim had no test, and a rename here would
% silently destroy the very field the #45 fold maps to
% subject_statement.datum_type.
out = runJ(binaryseriesPopulatedBody('bsp_3', 'sess_1'));
d = onlyClass(testCase, out, 'binaryseries_parameters');
b = blockOf(d, 'binaryseries_parameters');
verifyTrue(testCase, isfield(b, 'data_type'), ...
    'universalRenames must not rename binaryseries_parameters.data_type');
verifyEqual(testCase, b.data_type, 'float32');
end

function testBinaryseriesRejectsInventedFields(testCase)
% THE GUARD. `num_channels` and `sample_rate` are what the PRE-Phase-2b V_eta
% tombstone REQUIRED; neither appears in any NDI template or schema. A body
% carrying one was built from the V_alpha/V_zeta snapshot, not from a real
% document, and must fail loudly rather than migrate to something plausible.
for f = {'num_channels', 'sample_rate'}
    v1 = binaryseriesPopulatedBody('bsp_4', 'sess_1');
    v1.binaryseries_parameters.(f{1}) = 4;
    verifyError(testCase, @() did2.convert.migrators_j.binaryseries_parameters(v1), ...
        'did2:convert:binaryseriesParametersInventedField', ...
        sprintf('a body carrying `%s` must be rejected by name', f{1}));
end
end

function testBinaryseriesRejectsNonEmptyCharInAnIntegerField(testCase)
% A non-empty char in an integer field is NOT parsed. There is no writer for
% this class anywhere in NDI, so nothing can say what encoding '32' was meant
% to carry, and inventing the parse is the failure mode this whole repair track
% exists to remove. Quarantine with a legible reason, not a bare typeMismatch.
v1 = binaryseriesTemplateBody('bsp_5', 'sess_1');
v1.binaryseries_parameters.time_size = '32';
verifyError(testCase, @() did2.convert.migrators_j.binaryseries_parameters(v1), ...
    'did2:convert:binaryseriesParametersCharInteger');
end

function testBinaryseriesValidatesAgainstItsSchema(testCase)
% VALIDATION ON -- the point the tests above can only infer. Both shapes are
% driven at once: the template-placeholder document (which quarantined before
% this migrator existed) and the populated one.
%
% runJ deliberately passes Validate=false, so this calls v1_to_v2 directly.
% Requires the V_eta schema set on DID_SCHEMA_PATH (the quick gate assembles it
% from schemas/V_eta/{stable,draft,deprecated}).
v1 = { binaryseriesTemplateBody('bsp_v1', 'sess_V'), ...
       binaryseriesPopulatedBody('bsp_v2', 'sess_V') };
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('%s quarantined under validation: %s', ...
        out.quarantine(1).class_name, out.quarantine(1).reason));
end
verifyEqual(testCase, numel(out.migrated), 2);
% no empty required edge was manufactured on the way -- an empty edge VALIDATES
% CLEAN (+did2/+validate/references.m:90 skips it), so only the census sees one
verifyTrue(testCase, isfield(out.silent_loss, 'empty_dependency_count'), ...
    'silent-loss audit did not run');
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0);
end

function testBinaryseriesCarriesNoEdgeSoNoSubjectIsReachable(testCase)
% A DURABLE FACT, not a snapshot of unfinished work -- this one never needs
% inverting, because it is a property of the did_v1 class itself.
%
% All three declarations of this class agree that it has NO dependencies, and
% there is no writer anywhere in NDI to overrule them (git grep -i binaryseries
% on origin/main matches 3 files, none of them a .m, out of 1002 .m files):
%
%   NDI database_documents/data/binaryseries_parameters.json  no depends_on key
%   NDI schema_documents/data/binaryseries_parameters_schema.json  "depends_on": []
%   did-schema schemas/V_eta/stable/binaryseries_parameters.json   "depends_on": []
%
% That is what makes the signed fold unreachable rather than merely deferred:
% `subject_statement.subject_id` is mustBeNonEmpty, and there is no key here to
% resolve a subject FROM -- not in this migrator and not in a batch post-pass,
% which is the usual rescue for a missing subject. If a future source shape ever
% does carry an edge, this test goes red and the migrator header's "OPEN TEAM
% QUESTION" section is the thing to read before changing it.
out = runJ({ binaryseriesTemplateBody('bsp_e1', 'sess_V'), ...
             binaryseriesPopulatedBody('bsp_e2', 'sess_V') });
verifyEmpty(testCase, out.quarantine);
% ASSERT, not verify: everything below loops over out.migrated, and a verify on
% the count would let an empty result set pass every assertion vacuously.
assertEqual(testCase, numel(out.migrated), 2);
for k = 1:numel(out.migrated)
    s = out.migrated{k}.toStruct();
    % The GENERAL claim first -- no edge of ANY name, which is the fact that
    % makes a subject unreachable however a future fold tries to reach one.
    verifyTrue(testCase, ~isfield(s, 'depends_on') || isempty(s.depends_on), ...
        'binaryseries_parameters acquired a depends_on edge; see the migrator header');
    % Then the two names a fold would actually reach for, stated separately so a
    % failure says WHICH edge appeared rather than only that the count moved.
    verifyEmpty(testCase, depValue(s, 'element_id'));
    verifyEmpty(testCase, depValue(s, 'subject_id'));
end
end

function testBinaryseriesFoldIsNotBuiltAndNeedsMoreThanAxes(testCase)
% INVERT-WHEN, and NOT when #45 lands. See the header list above.
%
% did-schema's coverage ledger records `decided_targets: [subject_statement,
% sampled_body]` for this class and grades it stage 2, blocked at rung 3 with
% state `no`. That red rung is THIS MIGRATOR BEHAVING AS DESIGNED, and this
% test exists so that reading the rung as an instruction to build produces a
% failing test with a pointer, rather than a husk on a corpus run.
%
% TWO independent blockers, and #45 lifts only the first. THE FIRST HAS NOW
% BEEN LIFTED (#45 signed 2026-08-14) AND THIS TEST IS UNCHANGED:
%   (1) WAS "`datum_type` is declared in 0 of the 247 json files under
%       schemas/V_eta/, and the single collapsed axis `regular` flag does not
%       exist either". STALE. `subject_statement.datum_type` and the boolean
%       axis `regular` both exist now, and `axes[]` mounts on BOTH
%       subject_statement and sampled_body. What is STILL missing is the ONE
%       slot the 2026-08-09 addendum added for this very class: the AXIS's own
%       `datum_type`, the destination for `time_type`. Measured, not asserted,
%       by testBinaryseriesFoldBlockersAreStillInTheSchema below.
%   (2) no subject and no `variable`, per the test above -- which #45 does not
%       touch, and which is a TEAM question, not a build. Plus a third fact
%       nothing had recorded: `subject_statement` is ABSTRACT, so the target
%       the ledger names cannot be instantiated at all.
out = runJ({ binaryseriesTemplateBody('bsp_f1', 'sess_V'), ...
             binaryseriesPopulatedBody('bsp_f2', 'sess_V') });
verifyEmpty(testCase, out.quarantine);
% ASSERT before the all()/any() below. `all(strcmp({}, ...))` is TRUE on an
% empty set, so a verify here would let a run that migrated NOTHING report a
% clean pass -- the denominator defect this repo has already paid for once.
assertEqual(testCase, numel(out.migrated), 2);
names = cell(1, numel(out.migrated));
for k = 1:numel(out.migrated)
    names{k} = out.migrated{k}.get('document_class.class_name');
end
% The passthrough, and ONLY the passthrough: 2 in, 2 out, class unchanged.
verifyTrue(testCase, all(strcmp(names, 'binaryseries_parameters')));
verifyFalse(testCase, any(strcmp(names, 'subject_statement')), ...
    ['a subject_statement was minted from binaryseries_parameters. It carries ' ...
     'no subject and no measured quantity -- read the OPEN TEAM QUESTION ' ...
     'section of +migrators_j/binaryseries_parameters.m before inverting this.']);
verifyFalse(testCase, any(strcmp(names, 'sampled_body')), ...
    ['a sampled_body was minted from binaryseries_parameters. The source ' ...
     'declares "file": [], so the body would carry no payload.']);
end

function testBinaryseriesFoldBlockersAreStillInTheSchema(testCase)
% WHAT THE SIGNED FOLD NEEDS, MEASURED AGAINST THE LIVE SCHEMAS -- not against
% a census typed into a comment. This test is the repair for a specific defect:
% the migrator header carried "leaf field `datum_type`: 0 declarations" for
% five days after #45 built one, so the record understated what existed and a
% reader would have reported the whole data_body tier as unlanded. Prose about
% a built tree cannot notice that it has gone stale; this can.
%
% It is NOT an invert-when. It asserts the CURRENT state of four slots in both
% directions -- three present, one absent -- so it goes red on any movement and
% the failure message names which slot moved and which way. Whoever sees it red
% reads the migrator header, they do not "fix" the test.
%
% TEAM-SIGN-OFF [misc singletons], jess 2026-08-09, quoted for the four
% mappings this checks:
%   time_type -> the time axis's datum_type    data_type -> the statement's
%   data_dim  -> the axis count      samples_regular_intervals -> axis `regular`
cache = did2.schema.cache.shared();

% DENOMINATOR FIRST. All three classes must RESOLVE or every assertion below is
% vacuous -- "the slot is absent" and "the schema set is not on the path" would
% otherwise read identically, which is the silentLoss defect in miniature.
try
    statement = cache.getClass('subject_statement');
    body      = cache.getClass('sampled_body');
    tombstone = cache.getClass('binaryseries_parameters');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve the V_eta data_body classes (' ...
         err.message ') -- this test measured NOTHING.']);
    return;
end
verifyTrue(testCase, isstruct(tombstone), ...
    'the binaryseries_parameters source tombstone must exist to pass through to');

% ---- (1) THE THREE SLOTS #45 BUILT. Absence here means the tier REGRESSED.
verifyTrue(testCase, ~isempty(fieldDecl(statement, 'datum_type')), ...
    ['subject_statement.datum_type has gone -- it is the destination the ' ...
     'signature names for binaryseries_parameters.data_type.']);
stmtAxes = fieldDecl(statement, 'axes');
bodyAxes = fieldDecl(body, 'axes');
verifyNotEmpty(testCase, stmtAxes, 'subject_statement.axes[] has gone (#45 regressed)');
verifyNotEmpty(testCase, bodyAxes, 'sampled_body.axes[] has gone (#45 regressed)');
% `data_dim -> the axis count` needs no field: it is numel(axes). `regular` does.
for m = {{'subject_statement', stmtAxes}, {'sampled_body', bodyAxes}}
    verifyTrue(testCase, ~isempty(subDecl(m{1}{2}, 'regular')), ...
        sprintf(['%s.axes[].regular has gone -- it is the destination for ' ...
                 'samples_regular_intervals.'], m{1}{1}));
end

% ---- (2) THE ONE SLOT THAT DID NOT LAND, and the reason `time_type` is still
% homeless. V_eta_data_body_model_plan.md's ADDENDUM of 2026-08-09 ("the axis
% carries its own `datum_type`") was written FROM this class -- the plan says so
% -- and the built axis entry does not carry it, on either mount. If this goes
% red the addendum has landed and `time_type` finally has a destination; that is
% a genuine change in the fold's status and the migrator header says what to do.
for m = {{'subject_statement', stmtAxes}, {'sampled_body', bodyAxes}}
    verifyEmpty(testCase, subDecl(m{1}{2}, 'datum_type'), ...
        sprintf(['%s.axes[] now declares `datum_type`. The 2026-08-09 addendum ' ...
                 'has landed, so binaryseries_parameters.time_type has a ' ...
                 'destination for the first time -- read the migrator header ' ...
                 'before changing anything. It does NOT lift the edge blocker.'], ...
                m{1}{1}));
end

% ---- (3) THE BLOCKER #45 NEVER TOUCHED, in the schema rather than in prose.
% subject_statement is ABSTRACT (+did2/+schema/cache.m raises
% did2:validation:abstractInstantiation for any document naming such a class),
% so the target the coverage ledger records BY NAME cannot be minted even given
% a subject. sampled_body must stay CONCRETE -- that half also proves this
% predicate can return false, so the assertion above is not vacuous.
verifyTrue(testCase, schemaSaysAbstract(statement), ...
    ['V_eta subject_statement is no longer abstract. The signed target is now ' ...
     'directly instantiable -- which does NOT make the fold buildable (the ' ...
     'source still carries no edge and no `variable`), but it does change the ' ...
     'reason. Read the migrator header.']);
verifyFalse(testCase, schemaSaysAbstract(body), ...
    'V_eta sampled_body must stay concrete; it is the other signed target');

% ---- (4) and the required-ness that makes minting one a quarantine, not a
% husk. Read off the schema so that a relaxation is noticed here rather than on
% a corpus run.
verifyTrue(testCase, depIsRequired(statement, 'subject_id'), ...
    'subject_statement.subject_id stopped being mustBeNonEmpty');
verifyTrue(testCase, ~isempty(fieldDecl(statement, 'variable')), ...
    'subject_statement.variable has gone');
end

% ---- helpers for the schema read -----------------------------------------

function d = fieldDecl(classSchema, name)
%FIELDDECL The top-level field declaration NAME, or [] when absent.
d = [];
if ~isstruct(classSchema) || ~isfield(classSchema, 'fields'); return; end
d = declNamed(classSchema.fields, name);
end

function d = subDecl(parentDecl, name)
%SUBDECL The nested field declaration NAME under PARENTDECL, or [] when absent.
d = [];
if isempty(parentDecl) || ~isstruct(parentDecl); return; end
if ~isfield(parentDecl, 'fields'); return; end
d = declNamed(parentDecl.fields, name);
end

function d = declNamed(fieldList, name)
%DECLNAMED The entry of FIELDLIST whose `name` is NAME, or [] when absent.
%   jsondecode hands back a STRUCT ARRAY when every entry carries the same keys
%   and a CELL of structs when they do not. Both shapes are live in this tree
%   (subject_statement's field list mixes leaf and nested declarations), so
%   handle both rather than assume -- the same tolerance testMigratorsJAppFold
%   applies to depends_on.
%
%   NOTE the list is passed whole rather than re-wrapped with
%   struct('fields', list): struct() given a non-scalar value builds a STRUCT
%   ARRAY of that size instead of one struct holding the array, which would
%   silently make every lookup here miss.
d = [];
if isempty(fieldList); return; end
fs = fieldList;
if ~iscell(fs); fs = num2cell(fs); end
for k = 1:numel(fs)
    f = fs{k};
    if isstruct(f) && isfield(f, 'name') && strcmp(char(f.name), name)
        d = f;
        return;
    end
end
end

function tf = depIsRequired(classSchema, name)
%DEPISREQUIRED True when CLASSSCHEMA declares depends_on NAME as mustBeNonEmpty.
tf = false;
if ~isstruct(classSchema) || ~isfield(classSchema, 'depends_on'); return; end
deps = classSchema.depends_on;
if isempty(deps); return; end
if ~iscell(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name); continue; end
    tf = isfield(d, 'mustBeNonEmpty') && ...
        (islogical(d.mustBeNonEmpty) || isnumeric(d.mustBeNonEmpty)) && ...
        logical(d.mustBeNonEmpty);
    return;
end
end

function tf = schemaSaysAbstract(classSchema)
%SCHEMASAYSABSTRACT True when a schema struct's header carries `abstract: true`.
%
%   A LOCAL COPY, ON PURPOSE, exactly as testMigratorsJ carries one:
%   did2.schema.cache.classIsAbstract is PRIVATE, so a test calling it errors
%   with MATLAB:class:MethodRestricted rather than failing a verification. The
%   header is public data on the struct getClass returns.
%
%   ABSENCE IS CONCRETE: build_v_eta.py emits the key only on abstract classes,
%   so a concrete one carries no `abstract` field at all. Both the logical and
%   the numeric spelling are accepted because jsondecode's shape for a JSON
%   `true` is not something a test should assume.
tf = false;
if ~isstruct(classSchema) || ~isfield(classSchema, 'document_class'); return; end
dc = classSchema.document_class;
if ~isstruct(dc) || ~isfield(dc, 'abstract'); return; end
v = dc.abstract;
if islogical(v) || isnumeric(v)
    tf = ~isempty(v) && logical(v(1));
end
end

% ===================== projectvar ==========================================

function testProjectvarWriterShapePassesThroughAndValidates(testCase)
% The signed disposition: PASS THROUGH, unmodelled, until real documents exist
% to type `data` against. There is no migrator, so this exercises the identity
% fallback (v1_to_v2.m:372-378) plus the DEPRECATED-tier tombstone -- and the
% tombstone only reaches the validator because all six DID-matlab workflows
% copy schemas/V_eta/deprecated/ into DID_SCHEMA_PATH. A passthrough the
% validator cannot see quarantines, which is the opposite of preserving it.
out = did2.convert.v1_to_v2(projectvarWriterBody('pv_1', 'sess_V', 'x=3; y=4'), ...
    'Validate', true, 'TargetVersion', 'V_eta');
if ~isempty(out.quarantine)
    verifyFail(testCase, sprintf('projectvar quarantined under validation: %s', ...
        out.quarantine(1).reason));
end
d = onlyClass(testCase, out, 'projectvar');
% id preserved, class unchanged, payload untouched
verifyEqual(testCase, d.get('base.id'), 'pv_1');
verifyEqual(testCase, d.get('projectvar.data'), 'x=3; y=4');
verifyEqual(testCase, d.get('projectvar.type'), 'annotation');
verifyEqual(testCase, d.get('projectvar.description'), ...
    'free-text note attached to the project');
% the three fields the writer never sets stay empty rather than being invented
verifyEqual(testCase, d.get('projectvar.project'), '');
verifyEqual(testCase, d.get('projectvar.user'), '');
verifyEqual(testCase, d.get('projectvar.lab'), '');
end

function testProjectvarEmptyElementEdgeIsNotInvented(testCase)
% The writer never populates element_id, so every real document has it empty.
% V_eta declares it OPTIONAL for exactly that reason -- declaring it required
% would put projectvar in the invented-empty-edge table (7,233 documents across
% two classes at the last census) where it does not belong.
out = did2.convert.v1_to_v2(projectvarWriterBody('pv_2', 'sess_V', 'note'), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEmpty(testCase, out.quarantine);
d = onlyClass(testCase, out, 'projectvar');
verifyEqual(testCase, depValue(d, 'element_id'), '');
verifyEqual(testCase, out.silent_loss.empty_dependency_count, 0, ...
    'an OPTIONAL empty edge must not be counted as a required empty edge');
end

function testProjectvarNumericPayloadQuarantinesToday(testCase)
% THIS TEST ASSERTS A DEFECT, DELIBERATELY. INVERT IT, DO NOT PATCH IT.
%
% `projectvardef(NAME, TYPE, DESCRIPTION, DATA)` takes an ARBITRARY payload; the
% template's literal is '' so V_eta types the field `string`, and
% +did2/+schema/cache.m:1290-1310 accepts char, string, cell-of-char and an
% EMPTY numeric -- but not a non-empty numeric. So a projectvar holding a
% number quarantines with did2:validation:typeMismatch.
%
% This cannot be repaired in the tombstone: the meta-schema has no union and no
% `any` type, so widening to `matrix` would break the char payloads instead.
% It is an OPEN MODELLING QUESTION, and it is the reason the class is filed as
% "needs real documents" rather than modelled. Pinned here so that nobody meets
% it for the first time on a corpus run.
out = did2.convert.v1_to_v2(projectvarWriterBody('pv_3', 'sess_V', [1 2 3]), ...
    'Validate', true, 'TargetVersion', 'V_eta');
verifyEqual(testCase, numel(out.quarantine), 1, ...
    'a numeric projectvar payload is expected to quarantine TODAY');
verifyEqual(testCase, out.quarantine(1).class_name, 'projectvar');
end

% ===================== interaction_purpose =================================

function testInteractionPurposeTargetValidates(testCase)
% interaction_purpose is a TARGET with no v1 source: 0 of 1467 files on NDI
% origin/main mention it in any casing, and no migrator emits it -- its emitter
% is the NDI SECOND PASS over the 635 StimulationApproach documents (#75).
%
% Pass 1's side is already covered (testMigratorsJ's
% testOpenmindsStimulusPassesThroughForSecondPass and testFixtureCorpus's
% fx_openminds_stimulus), so what is asserted here is the thing NOTHING covers:
% that the target the second pass will write into actually accepts the document
% it is going to be handed.
cache = did2.schema.cache.shared();
body = interactionPurposeBody('ip_1', 'sess_V', {'interaction_id_1'});
cache.validateDocument(body);   % raises on any non-conformance
% and a purpose covering SEVERAL interactions -- the repeatable-annotation shape
% the class was kept for -- is equally acceptable
multi = interactionPurposeBody('ip_2', 'sess_V', ...
    {'interaction_id_1', 'interaction_id_2', 'interaction_id_3'});
cache.validateDocument(multi);
end

function testInteractionPurposeMissingEdgeFamilyIsReportOnly(testCase)
% THIS TEST ASSERTS A GAP, DELIBERATELY. INVERT IT, DO NOT PATCH IT.
%
% `interaction_id_#` declares min_count 1. Nothing enforces it: cache.m:193-246
% (requiredDependencies) EXCLUDES numbered families by design -- "a MISSING
% instance is not a blank one" -- so a purpose covering no interaction at all
% validates clean. The only instrument that sees it is the report-only census
% (#63), which counts it as a family_count_violation.
%
% That is exactly the shape of the invented-empty-edge pattern one level up, and
% it is why `interaction_id_#` is listed among the three numbered families
% declared REQUIRED and verified by nothing.
cache = did2.schema.cache.shared();
body = interactionPurposeBody('ip_3', 'sess_V', {});
cache.validateDocument(body);   % clean -- the gap
rep = did2.validate.silentLoss({did2.document(body)}, 'SchemaCache', cache);
% denominator first: an audit that read nothing must not read as a clean one
verifyEqual(testCase, rep.total_docs, 1);
verifyEqual(testCase, rep.skipped_docs, 0);
verifyEqual(testCase, rep.family_violation_count, 1, ...
    'the census is the only thing that sees a missing required edge family');
verifyEqual(testCase, rep.family_count_violation(1).class_name, 'interaction_purpose');
verifyEqual(testCase, rep.family_count_violation(1).edge_name, 'interaction_id_#');
end

function testInteractionPurposeIsNotEmittedByPassOne(testCase)
% The conditional keep, made checkable. `interaction_purpose` was persisted on
% the condition that an emitter be scheduled -- the same condition that
% `openminds_import` was persisted on and that nobody ever met. Pass 1 emits
% NOTHING of this class BY DESIGN (the resolution needs the migrated graph), so
% this pins the current state: if a pass-1 emitter ever appears, that is a
% decision, and it should announce itself here rather than in a corpus report.
v1 = { binaryseriesTemplateBody('bsp_n', 'sess_V'), ...
       projectvarWriterBody('pv_n', 'sess_V', 'note') };
out = runJ(v1);
for k = 1:numel(out.migrated)
    verifyNotEqual(testCase, ...
        out.migrated{k}.get('document_class.class_name'), 'interaction_purpose');
end
end
