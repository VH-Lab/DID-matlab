classdef TestOptionalDependencyWarning < matlab.unittest.TestCase
    % TestOptionalDependencyWarning
    % Test that a missing optional dependency (mustbenotempty:0) triggers the
    % DID:Database:MissingOptionalDependency warning when, and only when, the
    % DID_FORCE_VALIDATION_WARNINGS environment variable is enabled. The
    % warning is opt-in so it stays out of normal releases (see
    % did.database.validate_doc_vs_schema).

    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
        warn_id     = 'DID:Database:MissingOptionalDependency'
        env_var     = 'DID_FORCE_VALIDATION_WARNINGS'
    end

    properties
        db
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Create a temporary working directory and an empty database
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
        end
    end

    methods
        function doc = demoCWithMissingOptionalDependency(~)
            % Build a demoC document and drop its first (optional) dependency,
            % 'item1', so that schema validation finds it missing. All three
            % demoC dependencies (item1/item2/item3) are declared with
            % mustbenotempty:0, so a missing one is allowed (no error) but is
            % reported via the opt-in warning. demoC.value must be a valid
            % integer (the schema enforces the type), so set it explicitly.
            doc = did.document('demoC', 'demoC.value', 1);
            warnstate = warning('off');
            d_struct = struct(doc);
            warning(warnstate);
            d_struct.document_properties.depends_on = ...
                d_struct.document_properties.depends_on([2 3]); % remove item1
            doc = did.document(d_struct.document_properties);
        end

        function restoreEnv = enableForcedWarnings(testCase, value)
            % Set the opt-in environment variable for the duration of a test,
            % returning an onCleanup object that restores the prior value.
            originalEnv = getenv(testCase.env_var);
            setenv(testCase.env_var, value);
            restoreEnv = onCleanup(@() setenv(testCase.env_var, originalEnv));
        end
    end

    methods (Test)
        function testWarningIssuedWhenEnabled(testCase)
            % With the override enabled, adding a document that is missing an
            % optional dependency must issue the warning, and the document must
            % still be added (a missing optional dependency is not an error).
            doc = testCase.demoCWithMissingOptionalDependency();
            restoreEnv = testCase.enableForcedWarnings('1'); %#ok<NASGU>

            testCase.verifyWarning(@() testCase.db.add_docs({doc}), testCase.warn_id);

            found = testCase.db.get_docs(doc.id());
            testCase.verifyNotEmpty(found, ...
                'Document with a missing optional dependency should still be added');
        end

        function testNoWarningWhenDisabled(testCase)
            % With the override disabled, the same missing optional dependency
            % must not raise the warning (the default, release-safe behavior).
            doc = testCase.demoCWithMissingOptionalDependency();
            restoreEnv = testCase.enableForcedWarnings('0'); %#ok<NASGU>

            lastwarn('', '');
            testCase.db.add_docs({doc});
            [~, lastId] = lastwarn();

            testCase.verifyNotEqual(lastId, testCase.warn_id, ...
                'Missing optional dependency must not warn when the override is disabled');
        end
    end
end
