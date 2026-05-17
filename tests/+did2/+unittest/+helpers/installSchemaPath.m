function installSchemaPath(testCase, skipMessageContext)
%INSTALLSCHEMAPATH Probe a V_delta schema dir, set DID_SCHEMA_PATH, reset cache.
%
%   did2.unittest.helpers.installSchemaPath(TESTCASE, SKIPMESSAGECONTEXT) probes
%   DID_SCHEMA_PATH then the sibling-checkout default. If neither
%   resolves to a folder of V_delta `*.json` files, the test is
%   filtered via assumeFail with a clear message. Otherwise the env
%   var is set and the schema-cache singleton is reset.
%
%   Seeds testCase.TestData.previousSchemaPath /
%   .didOverrideSchemaPath so did2.unittest.helpers.restoreSchemaPath can run
%   safely in teardownOnce even when this helper aborted via
%   assumeFail.

arguments
    testCase
    skipMessageContext (1,:) char = 'skipping corpus test'
end

if ~isfield(testCase.TestData, 'previousSchemaPath')
    testCase.TestData.previousSchemaPath = getenv('DID_SCHEMA_PATH');
end
if ~isfield(testCase.TestData, 'didOverrideSchemaPath')
    testCase.TestData.didOverrideSchemaPath = false;
end

schemaPath = resolveSchemaPath();
if isempty(schemaPath)
    assumeFail(testCase, ...
        ['V_delta schemas not found. Set DID_SCHEMA_PATH or check out ', ...
         'did-schema as a sibling of DID-matlab; ' skipMessageContext '.']);
end
setenv('DID_SCHEMA_PATH', schemaPath);
testCase.TestData.didOverrideSchemaPath = true;
did2.schema.cache.resetSingleton();
end

function p = resolveSchemaPath()
candidates = {};
envPath = getenv('DID_SCHEMA_PATH');
if ~isempty(envPath)
    candidates{end+1} = envPath; %#ok<AGROW>
end
toolboxDir = did.toolboxdir();
candidates{end+1} = fullfile(toolboxDir, '..', '..', '..', ...
    'did-schema', 'schemas', 'V_delta', 'stable'); %#ok<AGROW>

p = '';
for k = 1:numel(candidates)
    candidate = candidates{k};
    if isfolder(candidate) && ~isempty(dir(fullfile(candidate, '*.json')))
        p = candidate;
        return;
    end
end
end
