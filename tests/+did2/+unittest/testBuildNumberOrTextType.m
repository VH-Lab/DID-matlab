function tests = testBuildNumberOrTextType
%TESTBUILDNUMBERORTEXTTYPE The declared field type `number_or_text`.
%
%   Decided by Jess Haley, 2026-11-19, did-schema
%   docs/plans/did_v2_numeric_shape_plan.md [numeric step 3 leftovers] (1),
%   with her follow-up answer "A" ([source numeric is number or text]): a
%   condition's or method parameter's `source_numeric` is declared, optional,
%   and keeps what v1 wrote in v1's own type -- sometimes a number (0.03),
%   sometimes text ("0.030", whose trailing zero is the stated precision).
%   Every other declared type admits one MATLAB type, so did-schema could not
%   declare the field (did-schema 164d5d44 left it undeclared): a `char`
%   refuses the number, a `matrix` refuses the text. This type admits both.
%
%   Pinned here, for the builder (did2.build, private/fillField) and the
%   validator (did2.schema.cache.validateDocument):
%     * a number passes, text passes (char and a string scalar);
%     * a struct, a cell and true/false are refused (the control), and so is
%       more than one number where the field is scalar, and a char matrix;
%     * on a copy of the loaded schema that declares `source_numeric` with
%       this type on statement.conditions, interaction.method.parameters and
%       method.parameters (the declaration did-schema will make), a condition and a parameter
%       build with either form, the statement validates, and the value keeps
%       its type through did2's JSON writer and reader;
%     * on that copy the types beside it are unchanged: `text` (char) still
%       refuses a number and `numeric` (matrix) still refuses text.
%   The undeclared case (today's did-schema main) is testBuildNumericShape's.
%
%   UNVERIFIED locally: written without MATLAB; test-builder.yml and
%   test-code.yml run it.
%
%   Run with:  results = runtests('did2.unittest.testBuildNumberOrTextType');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.sid = did.ido.unique_id();
end

% ===================== the validator ========================================

function testTheValidatorAcceptsANumberOrText(testCase)
cache = minimalSchemaDeclaring(testCase);
for v = {0.03, '0.030', "0.030", int32(4), '', -2.5e-7}
    doc = demoDocument(cache, v{1});
    cache.validateDocument(doc);   % errors on a refusal
end
end

function testTheValidatorRefusesEverythingElse(testCase)
cache = minimalSchemaDeclaring(testCase);
bad = {struct('value', 0.03), {0.03}, {'0.030'}, true, false, 1i};
for k = 1:numel(bad)
    doc = demoDocument(cache, bad{k});
    verifyError(testCase, @() cache.validateDocument(doc), ...
        'did2:validation:typeMismatch', sprintf('case %d (%s)', k, class(bad{k})));
end
% scalar: one number, or one row of text
verifyError(testCase, @() cache.validateDocument(demoDocument(cache, [0.03 0.04])), ...
    'did2:validation:notScalar');
verifyError(testCase, @() cache.validateDocument(demoDocument(cache, ['ab'; 'cd'])), ...
    'did2:validation:typeMismatch');
end

function testTheValidatorsCharFieldIsUnchanged(testCase)
% control: the same field declared `char`, as the fixture has it, still
% refuses a number
cache = minimalSchemaDeclaring(testCase, 'char');
cache.validateDocument(demoDocument(cache, '0.030'));
verifyError(testCase, @() cache.validateDocument(demoDocument(cache, 0.03)), ...
    'did2:validation:typeMismatch');
end

% ===================== the builder ==========================================

function testAConditionAndAParameterBuildEitherForm(testCase)
useDeclaringSchema(testCase);
cases = {0.03, '0.030'};
for k = 1:numel(cases)
    src = cases{k};
    c = did2.build.condition('threshold', 'Value', 0.03, 'SourceValue', src, ...
        'Unit', 'volt', 'Shape', 'new');
    p = did2.build.parameter('threshold', 'Value', 0.03, 'SourceValue', src, ...
        'Unit', 'volt', 'Shape', 'new');
    verifyEqual(testCase, c.source_numeric, src, class(src));
    verifyEqual(testCase, p.source_numeric, src, class(src));
    doc = statementWith(testCase, c, p);
    verifyEqual(testCase, doc.statement.conditions.source_numeric, src);
    verifyEqual(testCase, doc.interaction.method.parameters.source_numeric, src);
    did2.schema.cache.shared().validateDocument(doc);
    % through did2's JSON writer and reader: a number stays a number, text text
    cache = did2.schema.cache.shared();
    back = did2.document.fromJSON(did2.document(doc).toJSON('SchemaCache', cache), ...
        'SchemaCache', cache);
    verifyEqual(testCase, back.get('statement.conditions').source_numeric, src, class(src));
    verifyEqual(testCase, back.get('interaction.method.parameters').source_numeric, src, class(src));
    verifyWarningFree(testCase, @() back.validate('SchemaCache', cache));
end
% a string scalar is text
c = did2.build.condition('threshold', 'Value', 0.03, 'SourceValue', "0.030", 'Shape', 'new');
verifyEqual(testCase, c.source_numeric, '0.030');
end

function testTheBuilderRefusesEverythingElse(testCase)
useDeclaringSchema(testCase);
bad = {struct('value', 0.03), {0.03}, true, 1i};
for k = 1:numel(bad)
    e = struct('variable', 'threshold', 'numeric', 0.03);
    e.source_numeric = bad{k};
    verifyError(testCase, @() did2.build.composite('statement', 'conditions', e), ...
        'did2:build:typeMismatch', sprintf('case %d (%s)', k, class(bad{k})));
    verifyError(testCase, @() did2.build.composite('method', 'parameters', e), ...
        'did2:build:typeMismatch', sprintf('parameter case %d (%s)', k, class(bad{k})));
end
e = struct('variable', 'threshold', 'numeric', 0.03, 'source_numeric', [0.03 0.04]);
verifyError(testCase, @() did2.build.composite('statement', 'conditions', e), ...
    'did2:build:notScalar');
e.source_numeric = ['ab'; 'cd'];
verifyError(testCase, @() did2.build.composite('statement', 'conditions', e), ...
    'did2:build:typeMismatch');
end

function testTheTypesBesideItAreUnchanged(testCase)
% on the declaring copy, `text` (char) still refuses a number, `numeric`
% (matrix) still refuses text, and `count` (integer) still refuses text
useDeclaringSchema(testCase);
e = struct('variable', 'threshold', 'text', 0.03);
verifyError(testCase, @() did2.build.composite('statement', 'conditions', e), ...
    'did2:build:typeMismatch');
e = struct('variable', 'threshold', 'numeric', '0.03');
verifyError(testCase, @() did2.build.composite('statement', 'conditions', e), ...
    'did2:build:typeMismatch');
e = struct('variable', 'threshold', 'count', 'three');
verifyError(testCase, @() did2.build.composite('statement', 'conditions', e), ...
    'did2:build:typeMismatch');
% and the declared field is the schema's own: numericShapeFields adds no
% second one, and still adds `tolerance` beside it
defs = conditionDefs();
names = cellfun(@(d) char(d.name), defs, 'UniformOutput', false);
verifyEqual(testCase, nnz(strcmp(names, 'source_numeric')), 1);
sn = defs{strcmp(names, 'source_numeric')};
verifyEqual(testCase, char(sn.type), 'number_or_text');
verifyFalse(testCase, isfield(sn, 'alt_leaf'));
verifyFalse(testCase, isfield(sn, 'numeric_shape') && logical(sn.numeric_shape), ...
    'the schema declares it; numericShapeFields did not add it');
verifyTrue(testCase, any(strcmp(names, 'tolerance')));
end

% ===================== helpers ==============================================

function cache = minimalSchemaDeclaring(testCase, type)
% a copy of tests/+did2/fixtures/schema_minimal whose demoA.value is TYPE
% (default number_or_text), and a cache on it
if nargin < 2
    type = 'number_or_text';
end
thisDir = fileparts(mfilename('fullpath'));
src = fullfile(fileparts(thisDir), 'fixtures', 'schema_minimal');
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
copyfile(fullfile(src, '*.json'), tmp);
file = fullfile(tmp, 'demoA.json');
t = fileread(file);
old = '"name": "value",';
at = strfind(t, old);
assertNotEmpty(testCase, at, 'demoA.json declares no `value`');
typeAt = at(1) + regexp(t(at(1):end), '"type": "char"', 'once') - 1;
assertNotEmpty(testCase, typeAt, 'demoA.value is not declared char');
t = [t(1:typeAt-1) '"type": "' type '"' t(typeAt + numel('"type": "char"'):end)];
writeText(file, t);
did2.schema.cache.setSchemaPath(tmp);
testCase.addTeardown(@() did2.schema.cache.resetSingleton());
cache = did2.schema.cache.shared();
end

function doc = demoDocument(cache, value)
doc = cache.buildBlankDocument('demoA');
doc.base.session_id = did.ido.unique_id();
doc.demoA.value = value;
end

function useDeclaringSchema(testCase)
% a copy of the loaded did-schema set that declares `source_numeric` as
% number_or_text on statement.conditions, interaction.method.parameters and
% method.parameters, as did-schema will (the PR's fragment)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping number_or_text tests');
testCase.addTeardown(@() did2.unittest.helpers.restoreSchemaPath(testCase));
prevTermRegistry = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prevTermRegistry));
prevShape = did2.build.numericShape('');
testCase.addTeardown(@() did2.build.numericShape(prevShape));
src = did2.schema.cache.shared().schemaPath;
if ~did2.schema.cache.shared().hasClass('statement') ...
        || ~did2.schema.cache.shared().hasClass('interaction') ...
        || ~did2.schema.cache.shared().hasClass('method')
    assumeFail(testCase, sprintf('the loaded schema (%s) has no statement, interaction or method class.', src));
end
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
declare(testCase, fullfile(tmp, 'statement.json'), 'conditions');
declare(testCase, fullfile(tmp, 'interaction.json'), 'parameters');
declare(testCase, fullfile(tmp, 'method.json'), 'parameters');   % did2.build.parameter's
did2.schema.cache.setSchemaPath(tmp);
% (added after the rmdir, so it runs before it)
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
end

function declare(testCase, file, listName)
% insert the source_numeric declaration into LISTNAME's entry, before its
% `count` (declared in the old numeric shape and the new one); a file
% already declaring it there is left as it is
assertTrue(testCase, isfile(file), [file ' is not in the schema in use']);
t = fileread(file);
at = strfind(t, ['"name": "' listName '"']);
assertNotEmpty(testCase, at, sprintf('%s declares no %s', file, listName));
rest = t(at(1):end);
q = strfind(rest, '"name": "count"');
assertNotEmpty(testCase, q, sprintf('%s.%s declares no count', file, listName));
q = at(1) + q(1) - 1;
already = strfind(t(at(1):q), '"name": "source_numeric"');
if ~isempty(already)
    return;
end
open = find(t(1:q) == '{', 1, 'last');
t = [t(1:open-1) sourceNumericDeclaration() ', ' t(open:end)];
writeText(file, t);
end

function j = sourceNumericDeclaration()
% the declaration did-schema makes (the PR body's fragment)
j = ['{"name": "source_numeric", "type": "number_or_text", ' ...
    '"blank_value": "", "default_value": "", "mustBeNonEmpty": false, ' ...
    '"mustBeScalar": true, "mustNotHaveNaN": false, "queryable": true, ' ...
    '"ontology": null, "documentation": "What the source wrote for the number, ' ...
    'in the source''s own type.", "constraints": {}}'];
end

function defs = conditionDefs()
cache = did2.schema.cache.shared();
own = cache.ownFields('statement');
defs = {};
for k = 1:numel(own)
    if strcmp(char(own{k}.name), 'conditions')
        sub = own{k}.fields;
        if isstruct(sub); sub = num2cell(reshape(sub, 1, [])); end
        defs = did2.schema.numericShapeFields(sub, 'conditions');
        return;
    end
end
end

function doc = statementWith(testCase, c, p)
doc = did2.build.statement('observation', did.ido.unique_id(), 'voltage', ...
    did2.build.valueCell('voltage', 0.01, 'Shape', 'new'), 'Conditions', c, ...
    'MethodParameters', p, 'TimeReferenceIds', {did.ido.unique_id()}, ...
    'SessionId', testCase.TestData.sid, 'ValueKind', 'voltage');
end

function writeText(file, t)
fid = fopen(file, 'w', 'n', 'UTF-8');
fwrite(fid, t, 'char');
fclose(fid);
end
