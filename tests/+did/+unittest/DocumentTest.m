classdef DocumentTest < matlab.unittest.TestCase
    % Test the document adding functions of the did.database class

    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
    end

    properties
        db            % Holds the database object
        dG            % Holds the digraph object
        node_names    % Holds the node names
        root_indexes  % Holds the indexes of root nodes
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)

            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            testCase.applyFixture(did.test.fixture.PathConstantFixture)

            % Step 1: Create an empty database with a starting branch
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');
        end
    end

    methods (Test)
        function testAddDocuments(testCase)
            % Generate a set of documents with node names and a graph of the dependencies
            [G,node_names,docs] = did.test.helper.documents.make_doc_tree([10 10 10]);

            figure;
            testCase.dG = digraph(G,node_names);
            plot(testCase.dG,'layout','circle');
            title('The dependency relationships among the randomly generated documents.');

            testCase.db.add_docs(docs);

            % Step 3: check the database results
            [b, msg] = did.test.helper.documents.verify_db_document_structure(testCase.db, G, docs);

            b = logical(b);
            testCase.verifyTrue(b, msg);
        end

        function testRemoveDocuments(testCase)
            % Step 2: generate a set of documents with node names and a graph of the dependencies
            [G{1},node_names{1},docs{1}] = did.test.helper.documents.make_doc_tree([30 30 30]);

            figure;
            dG = digraph(G{1},node_names{1});
            plot(dG,'layout','circle');
            title('The dependency relationships among the randomly generated documents.');

            testCase.db.add_docs(docs{1});
            %for i=1:numel(docs{1})
            %    db.add_doc(docs{1}{i});
            %end

            % Step 3: check the database results
            [b, msg] = did.test.helper.documents.verify_db_document_structure(testCase.db, G{1}, docs{1});
            b = logical(b);
            testCase.verifyTrue(b, msg);

            for i=[2:2:10]

                disp('will now delete some documents/nodes and check.');

                [docs_to_delete,docs_to_delete_seed,G{i},node_names{i},docs{i}] = ...
                    did.test.helper.documents.rm_doc_tree(2, G{i-1},node_names{i-1},docs{i-1});

                if ~isempty(docs_to_delete_seed)
                    testCase.db.remove_docs(docs_to_delete_seed);
                end

                [b,msg] = did.test.helper.documents.verify_db_document_structure(testCase.db, G{i}, docs{i});
                b = logical(b);
                testCase.verifyTrue(b, msg);

                disp('will now add some documents/nodes and check.');

                N = numel(docs{i});
                [G{i+1},node_names{i+1},docs{i+1}] = did.test.helper.documents.add_doc_tree([5 5 5],...
                    G{i},node_names{i},docs{i});
                testCase.db.add_docs(docs{i+1}(N+1:numel(docs{i+1})));

                [b,msg] = did.test.helper.documents.verify_db_document_structure(testCase.db, G{i+1}, docs{i+1});

                b = logical(b);
                testCase.verifyTrue(b, msg);
            end
        end

        function testRemoveDocsHonorsOnMissing(testCase)
            % Regression: remove_docs wrapped do_remove_doc in a bare try/catch
            % with an empty handler, so every failure - including the documented
            % OnMissing='error' -> DID:SQLITEDB:NO_SUCH_DOC - was swallowed and
            % removal always reported success. Errors must now propagate.
            missingId = '0123456789abcdef_fedcba9876543210';  % valid shape, not in db

            % OnMissing='error' must surface NO_SUCH_DOC
            testCase.verifyError(...
                @() testCase.db.remove_docs(missingId,'a','OnMissing','error'), ...
                'DID:SQLITEDB:NO_SUCH_DOC');

            % OnMissing='ignore' must remain a quiet no-op
            testCase.verifyWarningFree(...
                @() testCase.db.remove_docs(missingId,'a','OnMissing','ignore'));
        end

        function testOnDuplicateIgnoreAndWarn(testCase)
            % Regression: OnDuplicate 'ignore'/'warn' previously detected the
            % duplicate but still fell through to the branch_docs INSERT, which
            % violated PRIMARY KEY(branch_id,doc_idx) and threw. They must now
            % be no-ops that leave exactly one copy in the branch.
            doc = did.document('demoA','demoA.value',1);
            testCase.db.add_docs(doc);

            % 'ignore' - no error, no warning, still one copy
            testCase.verifyWarningFree(...
                @() testCase.db.add_docs(doc,'a','OnDuplicate','ignore'));
            ids = testCase.db.search(did.query('base.id','exact_string',doc.id));
            testCase.verifyNumElements(ids,1, ...
                'branch must hold exactly one copy after OnDuplicate=ignore');

            % 'warn' - warns with the documented id, does not error, still one copy
            testCase.verifyWarning(...
                @() testCase.db.add_docs(doc,'a','OnDuplicate','warn'), ...
                'DID:SQLITEDB:DUPLICATE_DOC');
            ids2 = testCase.db.search(did.query('base.id','exact_string',doc.id));
            testCase.verifyNumElements(ids2,1, ...
                'branch must still hold exactly one copy after OnDuplicate=warn');
        end

        function testJournalModeRestoredAfterThrow(testCase)
            % Regression: add_docs('Validate',false) sets pragma journal_mode=OFF
            % and previously restored it only on the normal exit path, so a throw
            % in the document loop left journalling OFF for the connection's life.
            % The restore now happens via onCleanup on ANY exit.
            doc = did.document('demoA','demoA.value',1);
            testCase.db.add_docs(doc);

            % Hold the connection open across the failing call so a leaked
            % journal_mode=OFF would persist on it (the leak scenario).
            hKeepOpen = testCase.db.open(); %#ok<NASGU>

            % Re-add with Validate=false (journal set OFF) and OnDuplicate=error
            % so the loop throws after journalling was disabled.
            testCase.verifyError(...
                @() testCase.db.add_docs(doc,'a','Validate',false,'OnDuplicate','error'), ...
                'DID:SQLITEDB:DUPLICATE_DOC');

            res = testCase.db.run_sql_query('pragma journal_mode');
            flat = [res{:}];
            mode = lower(char(flat{1}));
            testCase.verifyEqual(mode, 'delete', ...
                'journal_mode must be restored after a throw in the add_docs loop');
        end
    end
end
