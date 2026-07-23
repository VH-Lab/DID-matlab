function restoreSchemaPath(testCase)
%RESTORESCHEMAPATH Restore DID_SCHEMA_PATH captured by installSchemaPath.
%
%   Safe to call from teardownOnce even when installSchemaPath
%   filtered the suite before the override happened: the absence of
%   the .didOverrideSchemaPath flag (or its `false` value) makes
%   this a no-op.

if isfield(testCase.TestData, 'didOverrideSchemaPath') ...
        && testCase.TestData.didOverrideSchemaPath
    setenv('DID_SCHEMA_PATH', testCase.TestData.previousSchemaPath);
    did2.schema.cache.resetSingleton();
end
end
