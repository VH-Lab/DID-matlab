classdef TestDocumentEquality < matlab.unittest.TestCase
    % did.document/eq - comparing documents by identifier.
    %
    % eq() read document_properties.did_document.id, a field no document has:
    % the constructor writes the identifier to base.id and id() reads it from
    % there. Nothing exercised eq(), so every comparison would have thrown
    % "Reference to non-existent field 'did_document'". These tests are what
    % was missing.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)

        function testDocumentEqualsItself(testCase)
            doc = did.document('demoA');
            testCase.verifyTrue(eq(doc, doc));
        end

        function testOperatorDispatchesToEq(testCase)
            % The point of defining eq is that == works.
            doc = did.document('demoA');
            testCase.verifyTrue(doc == doc);
        end

        function testDistinctDocumentsAreNotEqual(testCase)
            % Two documents of the same class get different ids.
            docA = did.document('demoA');
            docB = did.document('demoA');
            testCase.assertNotEqual(docA.id(), docB.id(), ...
                'two new documents were given the same id');
            testCase.verifyFalse(docA == docB);
        end

        function testEqualityFollowsTheIdNotTheContents(testCase)
            % Same id, different contents: still equal. This is what makes eq
            % usable for "is this the document I already have?".
            docA = did.document('demoA');
            props = docA.document_properties;
            props.demoA.value = 12345;
            docB = did.document(props);
            testCase.assertEqual(docB.id(), docA.id());
            testCase.verifyTrue(docA == docB);
        end

        function testDifferentClassesWithDifferentIdsAreNotEqual(testCase)
            docA = did.document('demoA');
            docB = did.document('demoB');
            testCase.verifyFalse(docA == docB);
        end

        function testEqualitySurvivesAStructRoundTrip(testCase)
            % Reading a document back out of storage rebuilds it from its
            % properties struct; the rebuilt one must compare equal to the
            % original, which is how callers recognize it.
            doc = did.document('demoA');
            rebuilt = did.document(doc.document_properties);
            testCase.verifyTrue(doc == rebuilt);
        end

    end
end
