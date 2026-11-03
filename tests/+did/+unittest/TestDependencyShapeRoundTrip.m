classdef TestDependencyShapeRoundTrip < matlab.unittest.TestCase
    % did.document writes a dependency in the shape it was read in
    %
    % DID-matlab #204 (Steve Van Hooser): "read V1 -> write V1; read V_zeta
    % -> write V_zeta. Migration becomes an explicit action." did-schema
    % did_v2_go_forward_class_audit.md [v2 line reads and writes both]
    % (Jess Haley, 2026-11-03): did.document writes a dependency in the
    % shape it was read; nothing migrates implicitly.
    %
    % The constructor used to rename every depends_on entry's key to the v2
    % `document_id` (i_normalizeDependsOn), and set_dependency_value wrote
    % only `document_id`, so a v1 document read and saved came back
    % v2-shaped. These tests hold both directions:
    %   - a v1 document (entries keyed `value`, or the older `id`) stays v1:
    %     its dependency block encodes to the same bytes after construction,
    %     after a database round trip, and after the setters run;
    %   - a v2 document (entries keyed `document_id`) stays v2.

    properties (Constant)
        % A v1 dependency block as NDI's v1 templates and DID's demo
        % definitions write it.
        v1Block = ['[{"name":"item1","value":"aaaa1111"},' ...
            '{"name":"item2","value":""},' ...
            '{"name":"item3","value":"cccc3333"}]']
        v2Block = ['[{"name":"item1","document_id":"aaaa1111"},' ...
            '{"name":"item2","document_id":""},' ...
            '{"name":"item3","document_id":"cccc3333"}]']
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)

        % ---- v1 -> v1 -----------------------------------------------

        function testV1BlockIsUnchangedByConstruction(testCase)
            props = demoCWith(testCase.v1Block);
            doc = did.document(props);
            testCase.verifyEqual(jsonencode(doc.document_properties.depends_on), ...
                testCase.v1Block, 'a v1 dependency block is kept byte for byte');
        end

        function testV1DefinitionStaysV1(testCase)
            % A blank document from a v1 definition (demoC.json keys its
            % entries `value`) is a v1 document.
            doc = did.document('demoC', 'demoC.value', 1);
            testCase.verifyEqual(entryKeys(doc), {'name','value'});
        end

        function testV1BlockSurvivesADatabaseRoundTrip(testCase)
            doc = did.document(demoCWith(testCase.v1Block));
            db = did.implementations.sqlitedb('test_db_dependency_shape_v1.sqlite');
            db.add_branch('v1');
            db.add_docs({doc}, 'v1', 'Validate', false);
            back = db.get_docs(doc.id(), 'OnMissing', 'error');
            if iscell(back), back = back{1}; end
            testCase.verifyEqual(jsonencode(back.document_properties.depends_on), ...
                testCase.v1Block, 'read v1 -> write v1: the stored block is the v1 block');
        end

        function testV1SettersWriteTheV1Key(testCase)
            doc = did.document(demoCWith(testCase.v1Block));
            doc = doc.set_dependency_value('item2', 'bbbb2222');
            doc = doc.set_dependency_value('item4', 'dddd4444', 'ErrorIfNotFound', 0);
            doc = doc.add_dependency_value_n('extra', 'eeee5555');
            testCase.verifyEqual(entryKeys(doc), {'name','value'}, ...
                'no document_id key is introduced on a v1 document');
            expected = ['[{"name":"item1","value":"aaaa1111"},' ...
                '{"name":"item2","value":"bbbb2222"},' ...
                '{"name":"item3","value":"cccc3333"},' ...
                '{"name":"item4","value":"dddd4444"},' ...
                '{"name":"extra_1","value":"eeee5555"}]'];
            testCase.verifyEqual(jsonencode(doc.document_properties.depends_on), expected);
            testCase.verifyEqual(doc.dependency_value('item2'), 'bbbb2222');
            testCase.verifyEqual(doc.dependency_value_n('extra'), {'eeee5555'});
        end

        function testSettingTheSameValuesIsByteIdentical(testCase)
            doc = did.document(demoCWith(testCase.v1Block));
            doc = doc.set_dependency_value('item1', 'aaaa1111');
            doc = doc.set_dependency_value('item3', 'cccc3333');
            testCase.verifyEqual(jsonencode(doc.document_properties.depends_on), testCase.v1Block);
        end

        function testOlderV1IdKeyStaysId(testCase)
            block = '[{"name":"item1","id":"aaaa1111"},{"name":"item2","id":""}]';
            doc = did.document(demoCWith(block));
            testCase.verifyEqual(jsonencode(doc.document_properties.depends_on), block);
            doc = doc.set_dependency_value('item2', 'bbbb2222');
            testCase.verifyEqual(entryKeys(doc), {'id','name'});
            testCase.verifyEqual(doc.dependency_value('item2'), 'bbbb2222');
        end

        function testUnstampedDocumentWithNoDependenciesWritesV1(testCase)
            props = did.document('demoC', 'demoC.value', 1).document_properties;
            props = rmfield(props, 'depends_on');
            doc = did.document(props);
            doc = doc.set_dependency_value('item1', 'aaaa1111', 'ErrorIfNotFound', 0);
            testCase.verifyEqual(entryKeys(doc), {'name','value'});
        end

        % ---- v2 -> v2 -----------------------------------------------

        function testV2BlockIsUnchangedByConstruction(testCase)
            doc = did.document(demoCWith(testCase.v2Block, 'did_v2'));
            testCase.verifyEqual(jsonencode(doc.document_properties.depends_on), testCase.v2Block);
        end

        function testV2BlockSurvivesADatabaseRoundTrip(testCase)
            doc = did.document(demoCWith(testCase.v2Block, 'did_v2'));
            db = did.implementations.sqlitedb('test_db_dependency_shape_v2.sqlite');
            db.add_branch('v2');
            db.add_docs({doc}, 'v2', 'Validate', false);
            back = db.get_docs(doc.id(), 'OnMissing', 'error');
            if iscell(back), back = back{1}; end
            testCase.verifyEqual(jsonencode(back.document_properties.depends_on), ...
                testCase.v2Block, 'read v2 -> write v2');
        end

        function testV2SettersWriteTheV2Key(testCase)
            doc = did.document(demoCWith(testCase.v2Block, 'did_v2'));
            doc = doc.set_dependency_value('item2', 'bbbb2222');
            doc = doc.set_dependency_value('item4', 'dddd4444', 'ErrorIfNotFound', 0);
            doc = doc.add_dependency_value_n('extra', 'eeee5555');
            testCase.verifyEqual(entryKeys(doc), {'document_id','name'}, ...
                'no value key is introduced on a v2 document');
            expected = ['[{"name":"item1","document_id":"aaaa1111"},' ...
                '{"name":"item2","document_id":"bbbb2222"},' ...
                '{"name":"item3","document_id":"cccc3333"},' ...
                '{"name":"item4","document_id":"dddd4444"},' ...
                '{"name":"extra_1","document_id":"eeee5555"}]'];
            testCase.verifyEqual(jsonencode(doc.document_properties.depends_on), expected);
        end

        function testV2StampedDocumentWithNoDependenciesWritesV2(testCase)
            props = did.document('demoC', 'demoC.value', 1).document_properties;
            props = rmfield(props, 'depends_on');
            props.document_class.schema_version = 'did_v2';
            doc = did.document(props);
            doc = doc.set_dependency_value('item1', 'aaaa1111', 'ErrorIfNotFound', 0);
            testCase.verifyEqual(entryKeys(doc), {'document_id','name'});
        end

        % ---- explicit conversion and merging ------------------------

        function testConversionIsOnlyExplicit(testCase)
            props = demoCWith(testCase.v1Block);
            converted = did.document.i_normalizeDependsOn(props);
            testCase.verifyEqual(jsonencode(converted.depends_on), testCase.v2Block, ...
                'i_normalizeDependsOn still converts when a caller asks for it');
        end

        function testPlusKeepsTheShapeOfTheFirstDocument(testCase)
            a = did.document(demoCWith(testCase.v1Block));
            bProps = demoCWith( ...
                '[{"name":"item3","document_id":"ffff6666"},{"name":"item9","document_id":"9999"}]', 'did_v2');
            b = did.document(bProps);
            merged = a + b;
            testCase.verifyEqual(entryKeys(merged), {'name','value'});
            testCase.verifyEqual(merged.dependency_value('item3'), 'ffff6666', 'B wins a name collision');
            testCase.verifyEqual(merged.dependency_value('item9'), '9999');
            testCase.verifyEqual(merged.dependency_value('item1'), 'aaaa1111');
        end
    end
end

function props = demoCWith(block, stamp)
    % A demoC body carrying the dependency block BLOCK (JSON text), stamped
    % STAMP (document_class.schema_version) unless empty.
    props = did.document('demoC', 'demoC.value', 1).document_properties;
    props.depends_on = jsondecode(block);
    if nargin > 1 && ~isempty(stamp)
        props.document_class.schema_version = stamp;
    end
end

function keys = entryKeys(doc)
    keys = sort(fieldnames(doc.document_properties.depends_on))';
end
