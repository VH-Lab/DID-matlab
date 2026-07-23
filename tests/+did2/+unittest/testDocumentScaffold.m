function tests = testDocumentScaffold
% testDocumentScaffold - smoke tests for the did2.document scaffold.
%
%   Run with:
%       results = runtests('did2.unittest.testDocumentScaffold');
%
%   These tests exercise the surface API of did2.document that does not
%   depend on the schema cache being fully implemented yet:
%   construction from a struct or JSON, dot-path get/set, iterate(),
%   and toJSON()/toStruct() round-trips. Tests that depend on the
%   schema cache live in did2.unittest.testSchemaCache.

tests = functiontests(localfunctions);
end

function testConstructFromStruct(testCase)
s = struct('id', 'abc', 'session_id', 'sess', 'name', 'unit-test');
doc = did2.document(s);
verifyEqual(testCase, doc.get('id'), 'abc');
verifyEqual(testCase, doc.get('name'), 'unit-test');
end

function testConstructFromJSON(testCase)
jsonText = '{"id":"abc","sample_rate":{"hertz":30000,"approximate":false}}';
doc = did2.document(jsonText);
verifyEqual(testCase, doc.get('id'), 'abc');
verifyEqual(testCase, doc.get('sample_rate.hertz'), 30000);
verifyFalse(testCase, doc.get('sample_rate.approximate'));
end

function testSetCreatesNestedPath(testCase)
doc = did2.document();
doc.set('app.app_name', 'ndi_app_spikeextractor');
verifyEqual(testCase, doc.get('app.app_name'), 'ndi_app_spikeextractor');
end

function testToJSONRoundTrip(testCase)
s = struct('id', 'abc', 'datestamp', '2026-05-11T00:00:00.000Z');
doc = did2.document(s);
jsonText = doc.toJSON();
doc2 = did2.document(jsonText);
verifyEqual(testCase, doc2.toStruct(), s);
end

function testIterateReturnsStructArray(testCase)
s = struct('axes', struct('name', {'x','y','z'}, 'unit', {'um','um','um'}));
doc = did2.document(s);
elements = doc.iterate('axes');
verifyEqual(testCase, numel(elements), 3);
verifyEqual(testCase, elements(2).name, 'y');
end

function testGetMissingFieldErrors(testCase)
doc = did2.document(struct('id', 'abc'));
verifyError(testCase, @() doc.get('nope.missing'), 'did2:document:missingField');
end

function testGetRejectsArrayPath(testCase)
doc = did2.document(struct('axes', struct('name', {'x'})));
verifyError(testCase, @() doc.get('axes[*].name'), 'did2:document:arrayPathHere');
end

function testBadConstructorInput(testCase)
verifyError(testCase, @() did2.document(42), 'did2:document:badInput');
end
