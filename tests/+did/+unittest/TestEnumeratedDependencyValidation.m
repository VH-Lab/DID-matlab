classdef TestEnumeratedDependencyValidation < matlab.unittest.TestCase
    % TestEnumeratedDependencyValidation
    % A dependency whose name is enumerated -- 'item1_1', 'syncrule_id_2' --
    % must have its VALUE validated, not just its presence.
    %
    % did.database.validate_doc_vs_schema strips the enumeration suffix into
    % docNames_alt and uses that for the presence check, but the loop that
    % reads each value back used to match on the un-stripped docNames. The
    % schema declares 'item1' while the document holds 'item1_1', so the two
    % never matched: value stayed empty, and both the mustbenotempty check and
    % the dependent-ID resolution check were skipped. An enumerated dependency
    % could point at a document that exists nowhere and still validate.
    %
    % See VH-Lab/DID-python#41 (shared issue; the same shape existed on both
    % sides and the fix landed here first).

    properties (Constant)
        db_filename = 'test_enumerated_dependency.sqlite'
        dangling_id = '0000000000000000_0000000000000000'
    end

    properties
        db
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
        end
    end

    methods
        function doc = demoCWithDependencies(~, dependsOn)
            % A demoC document carrying exactly the given depends_on struct
            % array. demoC's three dependencies (item1/item2/item3) are all
            % declared mustbenotempty:0, so presence is never the thing under
            % test here -- the value is. demoC.value must be a valid integer.
            doc = did.document('demoC', 'demoC.value', 1);
            warnstate = warning('off');
            d_struct = struct(doc);
            warning(warnstate);
            d_struct.document_properties.depends_on = dependsOn;
            doc = did.document(d_struct.document_properties);
        end
    end

    methods (Test)
        function testEnumeratedDependencyWithDanglingValueIsRejected(testCase)
            % The headline bug: 'item1_1' pointing at a document that is in no
            % database and in no batch used to validate cleanly.
            doc = testCase.demoCWithDependencies( ...
                struct('name', 'item1_1', 'value', testCase.dangling_id));

            testCase.verifyError(@() testCase.db.add_docs({doc}), ...
                'DID:Database:ValidationDependency');
        end

        function testEveryEnumeratedEntryIsChecked(testCase)
            % An enumerated dependency may legitimately have several entries.
            % The old lookup took the first match only; a bad value in any
            % later one has to be caught too.
            good = did.document('demoA', 'demoA.value', 1);
            testCase.db.add_docs({good});

            doc = testCase.demoCWithDependencies([ ...
                struct('name', 'item1_1', 'value', good.id()), ...
                struct('name', 'item1_2', 'value', testCase.dangling_id)]);

            testCase.verifyError(@() testCase.db.add_docs({doc}), ...
                'DID:Database:ValidationDependency');
        end

        function testEnumeratedDependencyResolvingInTheDatabaseIsAccepted(testCase)
            % The fix must not reject a legitimate enumerated dependency.
            good = did.document('demoA', 'demoA.value', 1);
            testCase.db.add_docs({good});

            doc = testCase.demoCWithDependencies( ...
                struct('name', 'item1_1', 'value', good.id()));

            testCase.db.add_docs({doc});
            testCase.verifyNotEmpty(testCase.db.get_docs(doc.id()), ...
                'A dependency resolving to a stored document must be accepted');
        end

        function testEnumeratedDependencyResolvingWithinTheBatchIsAccepted(testCase)
            % all_ids covers the documents being added alongside this one, not
            % only what is already stored.
            good = did.document('demoA', 'demoA.value', 1);
            doc = testCase.demoCWithDependencies( ...
                struct('name', 'item1_1', 'value', good.id()));

            testCase.db.add_docs({good, doc});
            testCase.verifyNotEmpty(testCase.db.get_docs(doc.id()), ...
                'A dependency resolving within the same batch must be accepted');
        end

        function testUnenumeratedDependencyStillValidates(testCase)
            % The un-enumerated path was already correct; keep it that way.
            doc = testCase.demoCWithDependencies( ...
                struct('name', 'item1', 'value', testCase.dangling_id));

            testCase.verifyError(@() testCase.db.add_docs({doc}), ...
                'DID:Database:ValidationDependency');
        end

        function testEmptyEnumeratedDependencyIsStillAllowedWhenOptional(testCase)
            % demoC's dependencies are all optional, so an empty value is not
            % an error -- the id check simply has nothing to resolve.
            doc = testCase.demoCWithDependencies( ...
                struct('name', 'item1_1', 'value', ''));

            testCase.db.add_docs({doc});
            testCase.verifyNotEmpty(testCase.db.get_docs(doc.id()), ...
                'An empty optional dependency must remain acceptable');
        end
    end
end
