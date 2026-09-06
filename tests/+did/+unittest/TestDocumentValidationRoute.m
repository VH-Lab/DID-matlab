classdef TestDocumentValidationRoute < matlab.unittest.TestCase
    % Where schema validation actually happens.
    %
    % did.document used to declare validate(), which delegated to did.validate.
    % No such function exists in DID-matlab, and none ever did -- there is no
    % validate.m anywhere under +did/ and no commit in the history that added or
    % removed one. So the method could not run at all: called with one argument
    % it threw "You must pass in an instance of did.database", which is the
    % catch block firing on an undefined-function error and pointing at the
    % wrong problem, and called with two it threw the undefined-function error
    % outright. Nothing in src/ ever called it. The only callers of did.validate
    % are in tests/+did/+test/_old/, which is not a package directory and so is
    % never collected into a suite.
    %
    % A document cannot validate itself: the schema check needs the database.
    % Documents are validated on the way in, by did.database/add, which calls
    % validate_docs -> validate_doc_vs_schema. These tests pin both halves so
    % the dead route cannot come back and the live one is not mistaken for an
    % implementation detail.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
        end
    end

    methods (Test)

        function testDocumentHasNoValidateMethod(testCase)
            testCase.verifyFalse(any(strcmp(methods('did.document'), 'validate')), ...
                ['did.document declares validate() again. Schema validation ' ...
                 'belongs to did.database/add, which has the database the ' ...
                 'check needs; a document on its own does not.']);
        end

        function testCallingValidateOnADocumentErrors(testCase)
            % The point of the removal. Asking for the route fails immediately
            % instead of returning a reassuring answer that means nothing.
            doc = did.document('demoA');
            testCase.verifyError(@() doc.validate(), ?MException);
        end

        function testDatabaseDeclaresTheValidationEntryPoint(testCase)
            % The live route. If this name changes, the comment above and the
            % first test's error message are stale and should be updated with it.
            testCase.verifyTrue(any(strcmp(methods('did.database'), 'validate_docs')), ...
                'did.database no longer declares validate_docs');
        end

    end
end
