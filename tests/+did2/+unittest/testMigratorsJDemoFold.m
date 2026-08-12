function tests = testMigratorsJDemoFold
%TESTMIGRATORSJDEMOFOLD The 3 -> 1 demo collapse, TargetVersion 'V_eta'.
%
%     did_v1 demoNDI      -> demo, is_mock FALSE
%     did_v1 demoNDIMock  -> demo, is_mock TRUE   (value inherited from demoNDI)
%     did_v1 mock         -> NO MIGRATOR: no document can carry it alone
%
%   Signed by the team 2026-08-06 and recorded at did-schema
%   `tools/build_v_eta.py:1817-1867`, which builds `stable/demo.json` and DELETES
%   `demo_ndi`, `demo_ndi_mock` and `mock` from the built set. The migrator half
%   did not exist until now, so a real document passed through to a class name
%   with no schema.
%
%   ---------------------------------------------------------------------
%   THE FIXTURES ARE did_v1 SHAPED, IN NDI's OWN camelCase
%   ---------------------------------------------------------------------
%   Deliberately: they are driven through the whole pipeline
%   (did2.convert.v1_to_v2), so universalRenames performs the class-name and
%   block-key rename before the migrator is dispatched. That rename is the part
%   this repository has already got wrong once -- `demo_ndi` was dispositioned
%   DELETE on 2026-08-06 on the evidence "absent from NDI origin/main; referenced
%   by NOTHING", from a grep for a string NDI has never contained -- so testing
%   the camelCase side of it is the point, not an incidental detail.
%
%   Every field name and value below is the WRITER's:
%
%     +ndi/+calc/+example/simple.m:105-113   demoNDIMock carrying a demoNDI block
%                                            with value 5, plus filename1.ext
%     +ndi/+calc/+example/simple.m:125-126   the same with value 10
%     +ndi/+test/+database/test_ndi_document.m:33-35   a plain demoNDI, value 5
%     ndi_common/database_documents/mock.json          mock: { ismock: 1 }
%     ndi_common/database_documents/demoNDI.json       demoNDI: { value: "" },
%                                                      files: [ filename1.ext ]
%
%   The three property blocks on the mock fixture are not invented either: NDI
%   materialises superclass blocks into the body
%   (`+ndi/document.m:1063-1100`, readblankdefinition step 3).
%
%   UNVERIFIED: there is no MATLAB in the authoring environment, so none of these
%   tests has been executed. They are written from the code as it stands and from
%   the writer evidence quoted above.
%
%   Run with:  results = runtests('did2.unittest.testMigratorsJDemoFold');

tests = functiontests(localfunctions);
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== harness =============================================

function out = runJ(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
end

function out = runJValidated(v1)
out = did2.convert.v1_to_v2(v1, 'Validate', true, 'TargetVersion', 'V_eta');
end

function msg = reasonsOf(out)
%REASONSOF The quarantine reasons, as a NON-EMPTY diagnostic.
if isempty(out.quarantine)
    msg = 'no quarantined documents';
    return;
end
msg = '';
for k = 1:numel(out.quarantine)
    msg = [msg sprintf('[%s] %s\n', out.quarantine(k).class_name, ...
        out.quarantine(k).reason)]; %#ok<AGROW>
end
end

function assumeVEtaSchemas(testCase)
%ASSUMEVETASCHEMAS Skip unless the schema cache can resolve `demo`.
%   installSchemaPath only checks that SOME folder of *.json exists, so a
%   V_delta-only checkout would satisfy it and then fail these tests for the
%   wrong reason. Probing the class the fold emits turns that into an honest skip.
did2.unittest.helpers.installSchemaPath(testCase, ...
    'skipping the V_eta demo-fold validation test');
try
    cache = did2.schema.cache.shared();
    cache.getClass('demo');
catch err
    assumeFail(testCase, ...
        ['DID_SCHEMA_PATH does not resolve the V_eta `demo` class (' ...
         err.message ').']);
end
end

% ===================== fixtures, built from the writer ======================

function v1 = demoNdiV1(value)
%DEMONDIV1 A did_v1 `demoNDI` as +ndi/+test/+database/test_ndi_document.m:33
%   writes one: one property block with `value`, no dependencies, and the
%   filename1.ext the template's file_list declares.
v1 = struct();
v1.document_class = struct('class_name', 'demoNDI', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}));
v1.base = struct('id', 'demo_1', 'session_id', 'sess_09', ...
    'name', 'doc_1', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.demoNDI = struct('value', value);
v1.files = struct('file_list', {{'filename1.ext'}});
end

function v1 = demoNdiMockV1(value, ismock)
%DEMONDIMOCKV1 A did_v1 `demoNDIMock` as ndi.calc.example.simple writes one.
%   THREE property blocks, because demoNDIMock subclasses BOTH mock and demoNDI
%   and NDI materialises superclass blocks into the body: its own (empty -- the
%   class declares no fields), `mock` (ismock) and `demoNDI` (value).
v1 = struct();
v1.document_class = struct('class_name', 'demoNDIMock', 'class_version', '1.0.0', ...
    'superclasses', [ struct('class_name', 'mock', 'class_version', '1.0.0'), ...
                      struct('class_name', 'demoNDI', 'class_version', '1.0.0') ]);
v1.base = struct('id', 'demo_mock_1', 'session_id', 'sess_09', ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
v1.demoNDIMock = struct();
v1.mock = struct('ismock', ismock);
v1.demoNDI = struct('value', value);
v1.files = struct('file_list', {{'filename1.ext'}});
end

% ===================== the two folds =======================================

function testDemoNdiFoldsToDemoWithIsMockFalse(testCase)
% 1 -> 1, id PRESERVED. Every fold in this project that changed a document id
% created dangling references, so base.id is asserted before anything else.
out = runJ(demoNdiV1(5));
% ASSERT, not verify: everything below reads out.migrated{1}, and a verify on
% the count would let an empty result set pass the rest vacuously.
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.migrated), 1, ...
    'the demoNDI fold emitted no document; every assertion below would be vacuous');
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'demo');
verifyEqual(testCase, doc.get('base.id'), 'demo_1');
verifyEqual(testCase, doc.get('base.session_id'), 'sess_09');
verifyEqual(testCase, doc.get('demo.value'), 5);
verifyTrue(testCase, isnumeric(doc.get('demo.value')), ...
    'demo.value is declared double; the did_v1 template declares char');
verifyFalse(testCase, doc.get('demo.is_mock'));
% the file the did_v1 template declares and V_eta re-declares survives
verifyEqual(testCase, doc.get('files.file_list'), {'filename1.ext'});
% the consumed did_v1 block is GONE -- a populated leftover trips the strict
% top-level check (did2:validation:undeclaredBlock)
s = doc.toStruct();
verifyFalse(testCase, isfield(s, 'demo_ndi'));
verifyFalse(testCase, isfield(s, 'demoNDI'));
end

function testDemoNdiMockFoldsToDemoWithTheInheritedValue(testCase)
% The value lives on the INHERITED demoNDI block, because demoNDIMock declares
% no fields of its own -- ndi.calc.example.simple.m:105-107 passes a demoNDI
% block into a demoNDIMock document for exactly that reason.
out = runJ(demoNdiMockV1(10, 1));
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.migrated), 1, ...
    'the demoNDIMock fold emitted no document; every assertion below would be vacuous');
doc = out.migrated{1};
verifyEqual(testCase, doc.get('document_class.class_name'), 'demo');
verifyEqual(testCase, doc.get('base.id'), 'demo_mock_1');
verifyEqual(testCase, doc.get('demo.value'), 10);
verifyTrue(testCase, doc.get('demo.is_mock'), ...
    'is_mock is the only marker separating self-test artefacts from real data');
% ALL THREE did_v1 blocks are consumed, named one at a time so a failure says
% which one survived
s = doc.toStruct();
verifyFalse(testCase, isfield(s, 'demo_ndi'));
verifyFalse(testCase, isfield(s, 'demo_ndi_mock'));
verifyFalse(testCase, isfield(s, 'mock'));
end

function testDemoMockReadsAStoredIsMockRatherThanAssumingIt(testCase)
% The flag is READ from the did_v1 `mock` block, not asserted from the class
% name. Nothing in NDI ever writes `ismock` (0 hits for the token across 1002 .m
% files on origin/main), so the template's own 1 is the only value that occurs in
% practice -- which is exactly why the read path needs a test of its own: it is
% otherwise indistinguishable from hard-coding true.
out = runJ(demoNdiMockV1(3, 0));
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.migrated), 1, ...
    'the demoNDIMock fold emitted no document; the assertion below would be vacuous');
verifyFalse(testCase, out.migrated{1}.get('demo.is_mock'));
end

% ===================== the value guard =====================================

function testDemoUnsetValueIsOmittedNeverInvented(testCase)
% The did_v1 template declares `"value": ""`. A document that never set one
% carries that empty char, which V_eta's `double` field cannot hold. The field is
% OMITTED -- `mustBeNonEmpty` is false, so an absent field is valid, and it says
% exactly what the source said. Writing the schema's blank_value 0.0 instead
% would invent a measurement that reads as real in every later query.
out = runJ(demoNdiV1(''));
verifyEmpty(testCase, out.quarantine);
assertEqual(testCase, numel(out.migrated), 1, ...
    'the demoNDI fold emitted no document; every assertion below would be vacuous');
s = out.migrated{1}.toStruct();
assertTrue(testCase, isfield(s, 'demo'), 'no demo block was produced');
verifyFalse(testCase, isfield(s.demo, 'value'), ...
    'an unset did_v1 value became a present field; 0 would read as a real measurement');
% the rest of the fold still happened
verifyEqual(testCase, s.document_class.class_name, 'demo');
verifyFalse(testCase, s.demo.is_mock);
end

function testDemoRefusesAValueItCannotHold(testCase)
% GUARD, NOT GUESS -- and NOT a passthrough. A guarded passthrough is the usual
% fallback in this package, and it is unavailable here: did-schema deletes
% demo_ndi / demo_ndi_mock / mock from the built set, so a passed-through
% document has no schema and quarantines with missingClass anyway. Failing by
% name at least puts the field and the shape in the quarantine reason.
out = runJ(demoNdiV1('a string nobody declared'));
verifyEmpty(testCase, out.migrated);
assertEqual(testCase, numel(out.quarantine), 1, ...
    'the unmappable value did not quarantine; the assertions below would be vacuous');
verifyEqual(testCase, out.quarantine(1).identifier, ...
    'did2:convert:demoUnmappableValue');
verifyEqual(testCase, out.quarantine(1).class_name, 'demo_ndi');
verifyTrue(testCase, contains(out.quarantine(1).reason, 'char'), ...
    'the reason must name the shape that could not be held');
end

function testDemoRefusesAFieldItHasNoDestinationFor(testCase)
% V_eta `demo` declares exactly `value` and `is_mock`. A did_v1 field outside
% those two would be silently DROPPED by this fold, so it is named and refused.
% If NDI ever adds a field to demoNDI, this test is the thing that says so --
% loudly, on the first document, instead of at a corpus census months later.
v1 = demoNdiV1(5);
v1.demoNDI.somethingNew = 'x';
out = runJ(v1);
verifyEmpty(testCase, out.migrated);
assertEqual(testCase, numel(out.quarantine), 1, ...
    'the unknown field did not quarantine; the assertions below would be vacuous');
verifyEqual(testCase, out.quarantine(1).identifier, 'did2:convert:demoUnknownField');
% universalRenames snake_cases field names inside a block, so the reason names
% the V_eta spelling of the offending field
verifyTrue(testCase, contains(out.quarantine(1).reason, 'something_new'), ...
    'the reason must name the field that had no destination');
end

% ===================== under the real V_eta validator ======================

function testDemoFoldValidatesUnderVEta(testCase)
% THE CHECK THAT MATTERS MOST, and the one the unvalidated tests above cannot
% make: does the body this fold produces actually satisfy `stable/demo.json`?
% Both arms are run, because they produce different blocks (the mock arm consumes
% three did_v1 blocks, the plain arm one) and a leftover from either would trip
% the strict top-level check rather than anything asserted above.
assumeVEtaSchemas(testCase);

out = runJValidated(demoNdiV1(5));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
assertEqual(testCase, numel(out.migrated), 1, ...
    'the demoNDI fold produced no validated document');
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'demo');
verifyFalse(testCase, out.migrated{1}.get('demo.is_mock'));

out = runJValidated(demoNdiMockV1(10, 1));
verifyEqual(testCase, out.summary.quarantine_count, 0, reasonsOf(out));
assertEqual(testCase, numel(out.migrated), 1, ...
    'the demoNDIMock fold produced no validated document');
verifyEqual(testCase, out.migrated{1}.get('document_class.class_name'), 'demo');
verifyEqual(testCase, out.migrated{1}.get('demo.value'), 10);
verifyTrue(testCase, out.migrated{1}.get('demo.is_mock'));
end

% ===================== `mock` needs no migrator ============================

function testBareMockHasNoMigratorBecauseNoDocumentCanCarryIt(testCase)
% A DURABLE FACT, and the reason a file is ABSENT -- which nothing else in this
% repository can record, because an absence leaves no code to read.
%
% `mock` is a superclass. It is deleted from the built V_eta set alongside the
% other two, so a bare `mock` document would pass through and quarantine. None
% can exist: across 1002 .m files on NDI origin/main, `ndi.document('mock'`,
% `newdocument('mock'` and `'isa','mock'` return 0 hits between them, and the
% token `ismock` returns 0 in any case, while the quoted literal 'mock' returns
% 13 -- a subject-identifier substring, an email prefix, a path segment,
% epochfile names and openMINDS object names, none of them a document class. The
% zero is a measurement, not a property of the query.
%
% The two sibling lookups are asserted PRESENT in the same test, so this cannot
% degrade into a broken-lookup tautology that passes while checking nothing.
assertFalse(testCase, isempty(which('did2.convert.migrators_j.demo_ndi')), ...
    'the demo_ndi migrator does not resolve; the mock assertion below is meaningless');
assertFalse(testCase, isempty(which('did2.convert.migrators_j.demo_ndi_mock')), ...
    'the demo_ndi_mock migrator does not resolve; the mock assertion below is meaningless');
verifyTrue(testCase, isempty(which('did2.convert.migrators_j.mock')), ...
    ['a migrator was added for the bare `mock` class -- read demo_ndi_mock.m''s ' ...
     'header first: it is written for a class no NDI writer constructs']);
end
