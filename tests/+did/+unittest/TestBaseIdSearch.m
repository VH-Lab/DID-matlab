classdef TestBaseIdSearch < matlab.unittest.TestCase
    % Test that looking documents up by base.id is fast in did.implementations.sqlitedb
    %
    % NDI looks documents up by id constantly, as
    %     did.query('base.id','exact_string',ID) & did.query('base.session_id','exact_string',SESSION_ID)
    % The terms of an AND used to be searched separately and their results
    % intersected in MATLAB, so the session term returned every document of
    % the session: about 1 s per lookup in a database of 100,000 documents.
    % Now the base.id term is searched first and the session term is checked
    % against the document it found only, through the doc_data
    % (doc_idx,field_idx) index - see did.database/search_doc_ids.
    %
    % Besides the results, these tests check the number of rows each SQL
    % query returned (did.test.helper.QueryLogSqlitedb records them): an id
    % lookup that returns a row per document of the session is the slow path
    % however quickly it happens to run on a small test database.

    properties (Constant)
        db_filename = 'test_db_base_id.sqlite'
        numSessionDocs = 1500  % documents in the main session
        numOtherDocs = 100     % documents in a second session
    end

    properties
        db            % did.test.helper.QueryLogSqlitedb
        sessionId     % base.session_id of the main session
        otherSession  % base.session_id of the second session
        ids           % base.id of every main-session document, in order added
        otherIds      % base.id of every second-session document
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.test.helper.QueryLogSqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');

            testCase.sessionId = did.ido.unique_id();
            testCase.otherSession = did.ido.unique_id();
            docs = cell(1, testCase.numSessionDocs);
            for i = 1:testCase.numSessionDocs
                docs{i} = did.document('demoA', 'base.session_id', testCase.sessionId, ...
                    'demoA.value', i);
            end
            otherDocs = cell(1, testCase.numOtherDocs);
            for i = 1:testCase.numOtherDocs
                otherDocs{i} = did.document('demoB', 'base.session_id', testCase.otherSession, ...
                    'demoA.value', i, 'demoB.value', i);
            end
            testCase.db.add_docs([docs otherDocs], 'a', 'Validate', false);
            testCase.ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.otherIds = cellfun(@(d) d.id(), otherDocs, 'UniformOutput', false);
        end
    end

    methods (TestMethodTeardown)
        function restoreCandidateSearch(testCase)
            testCase.db.noCandidateSearch = false;
        end
    end

    methods
        function q = idQuery(~, id)
            q = did.query('base.id', 'exact_string', id);
        end

        function q = sessionQuery(~, session_id)
            q = did.query('base.session_id', 'exact_string', session_id);
        end

        function q = orOfIds(testCase, ids)
            % A balanced OR of base.id queries (shallow, whatever the count)
            if numel(ids) == 1
                q = testCase.idQuery(ids{1});
            else
                half = floor(numel(ids)/2);
                q = testCase.orOfIds(ids(1:half)) | testCase.orOfIds(ids(half+1:end));
            end
        end

        function [found, maxRows, numQueries] = searchLogged(testCase, q)
            % Search, and report the most rows any document query of the
            % search returned, and how many document queries it ran (the
            % branch-id check that search also makes is left out)
            testCase.db.clearQueryLog();
            found = testCase.db.search(q);
            entries = testCase.db.queryLog;
            entries = entries(startsWith({entries.query}, 'SELECT DISTINCT docs.doc_id'));
            numQueries = numel(entries);
            if isempty(entries)
                maxRows = 0;
            else
                maxRows = max([entries.rows]);
            end
        end

        function verifySameIds(testCase, actual, expected, msg)
            testCase.verifyEqual(sort(actual(:)), sort(expected(:)), msg);
        end
    end

    methods (Test)
        function testNewDatabaseHasSearchIndex(testCase)
            rows = testCase.db.run_sql_query(['SELECT name FROM sqlite_master ' ...
                'WHERE type=''index'' AND name=''doc_data_doc_idx_field_idx'''], true);
            testCase.verifyNotEmpty(rows, ...
                'a new database must be created with the doc_data_doc_idx_field_idx index');
            testCase.verifyTrue(testCase.db.hasSearchIndexFlag());
        end

        function testIndexAddedWhenOlderDatabaseOpened(testCase)
            % A database written before the index existed (by DID-matlab or
            % DID-python) gets it when it is opened, and keeps working
            filename = 'test_db_older.sqlite';
            older = did.implementations.sqlitedb(filename);
            older.add_branch('a');
            doc = did.document('demoA', 'demoA.value', 1);
            older.add_docs(doc);
            older.run_sql_query('DROP INDEX "doc_data_doc_idx_field_idx"');
            indexQuery = ['SELECT name FROM sqlite_master ' ...
                'WHERE type=''index'' AND name=''doc_data_doc_idx_field_idx'''];
            testCase.assertEmpty(older.run_sql_query(indexQuery, true), ...
                'setup: the index should be gone');
            older.close();
            delete(older);

            reopened = did.test.helper.QueryLogSqlitedb(filename);
            testCase.verifyNotEmpty(reopened.run_sql_query(indexQuery, true), ...
                'opening an older database must add the doc_data_doc_idx_field_idx index');
            testCase.verifyTrue(reopened.hasSearchIndexFlag());
            reopened.set_branch('a');
            q = testCase.idQuery(doc.id()) & did.query('demoA.value', 'exact_number', 1);
            testCase.verifyEqual(reopened.search(q), {doc.id()});
            reopened.close();
        end

        function testIdLookupAlone(testCase)
            id = testCase.ids{777};
            [found, maxRows] = testCase.searchLogged(testCase.idQuery(id));
            testCase.verifyEqual(found, {id});
            testCase.verifyLessThanOrEqual(maxRows, 1, ...
                'an id lookup must not return a row per document');
        end

        function testIdAndSessionLookupIsFast(testCase)
            % The NDI lookup: base.id AND base.session_id
            pick = [1 2 500 1000 testCase.numSessionDocs];
            elapsed = zeros(size(pick));
            for k = 1:numel(pick)
                id = testCase.ids{pick(k)};
                q = testCase.idQuery(id) & testCase.sessionQuery(testCase.sessionId);
                tic;
                [found, maxRows] = testCase.searchLogged(q);
                elapsed(k) = toc;
                testCase.verifyEqual(found, {id}, ...
                    'the id lookup must return exactly the document with that id');
                testCase.verifyLessThanOrEqual(maxRows, 1, ...
                    ['the session term must be checked against the one document ' ...
                     'found by id, not return every document of the session']);
            end

            % The order of the terms must not matter
            id = testCase.ids{42};
            q = testCase.sessionQuery(testCase.sessionId) & testCase.idQuery(id);
            [found, maxRows] = testCase.searchLogged(q);
            testCase.verifyEqual(found, {id});
            testCase.verifyLessThanOrEqual(maxRows, 1);

            % A generous bound: it was ~1 s per lookup at 100,000 documents,
            % and it no longer grows with the number of documents
            testCase.verifyLessThan(median(elapsed), 0.25, ...
                sprintf('id lookups took a median of %.3f s', median(elapsed)));
        end

        function testIdLookupInWrongSessionFindsNothing(testCase)
            q = testCase.idQuery(testCase.ids{3}) & testCase.sessionQuery(testCase.otherSession);
            [found, maxRows] = testCase.searchLogged(q);
            testCase.verifyEmpty(found);
            testCase.verifyLessThanOrEqual(maxRows, 1);

            q = testCase.idQuery(testCase.otherIds{3}) & testCase.sessionQuery(testCase.otherSession);
            testCase.verifyEqual(testCase.db.search(q), testCase.otherIds(3));
        end

        function testUnknownIdFindsNothing(testCase)
            q = testCase.idQuery('no_such_id_0123456789') & testCase.sessionQuery(testCase.sessionId);
            [found, maxRows] = testCase.searchLogged(q);
            testCase.verifyEmpty(found);
            testCase.verifyEqual(maxRows, 0, ...
                'once the id matches nothing, the session term need not be searched at all');
        end

        function testOrOfIdsReturnsAllMatches(testCase)
            wanted = testCase.ids([5 50 500 1234]);
            wanted{end+1} = testCase.otherIds{7};

            % Nested left to right, as q = q | ... in a loop builds it
            q = testCase.idQuery(wanted{1});
            for k = 2:numel(wanted)
                q = q | testCase.idQuery(wanted{k});
            end
            [found, maxRows, numQueries] = testCase.searchLogged(q);
            testCase.verifySameIds(found, wanted, 'an OR of ids must return every match');
            testCase.verifyLessThanOrEqual(maxRows, numel(wanted));
            testCase.verifyEqual(numQueries, 1, ...
                'ORed ids must be looked up in one query');

            % ...an unknown id among them changes nothing
            q2 = q | testCase.idQuery('no_such_id_0123456789');
            testCase.verifySameIds(testCase.db.search(q2), wanted, ...
                'an unknown id in an OR must simply match nothing');

            % ...and ANDed with a session, only that session's documents remain
            q3 = q & testCase.sessionQuery(testCase.sessionId);
            [found, maxRows] = testCase.searchLogged(q3);
            testCase.verifySameIds(found, wanted(1:end-1), ...
                'an OR of ids ANDed with a session must keep only that session''s documents');
            testCase.verifyLessThanOrEqual(maxRows, numel(wanted));
        end

        function testOrOfManyIds(testCase)
            % More ids than one SQL query lists (maxSearchCandidates, 1000)
            wanted = [testCase.ids(1:1200) testCase.otherIds(1:10)];
            q = testCase.orOfIds(wanted);
            testCase.verifySameIds(testCase.db.search(q), wanted, ...
                'an OR of 1210 ids must return every match');

            q = q & testCase.sessionQuery(testCase.sessionId);
            testCase.verifySameIds(testCase.db.search(q), testCase.ids(1:1200), ...
                'an OR of 1210 ids ANDed with a session must keep that session''s documents');
        end

        function testRestrictedSearchMatchesFullSearch(testCase)
            % Every kind of term, checked against candidate documents, must
            % give what it gives when searched over the whole branch
            id = testCase.ids{10};
            otherId = testCase.otherIds{10};
            idOr = testCase.idQuery(id) | testCase.idQuery(otherId);
            terms = {
                testCase.sessionQuery(testCase.sessionId)
                did.query('base.session_id', '~exact_string', testCase.sessionId)
                did.query('', 'isa', 'demoB')
                did.query('', 'isa', 'demoA')
                did.query('demoB', 'hasfield')
                did.query('demoA.value', 'exact_number', 10)
                did.query('demoA.value', 'greaterthan', 5)
                did.query('base.id', 'contains_string', id(1:8))
                did.query('base.datestamp', 'regexp', '^[0-9]')
                did.query('demoA.value', 'exact_number', 10) | did.query('', 'isa', 'demoB')
                };
            for k = 1:numel(terms)
                for lookup = {testCase.idQuery(id), idOr}
                    q = lookup{1} & terms{k};
                    testCase.db.noCandidateSearch = false;
                    fast = testCase.db.search(q);
                    testCase.db.noCandidateSearch = true;
                    full = testCase.db.search(q);
                    testCase.verifySameIds(fast, full, ...
                        sprintf('term %d: the restricted search must match the full search', k));
                end
            end
            testCase.db.noCandidateSearch = false;
        end

        function testSearchesWithoutIdStillWork(testCase)
            % ANDs without an id lookup take the same path as before
            q = testCase.sessionQuery(testCase.otherSession) & did.query('', 'isa', 'demoB');
            testCase.verifySameIds(testCase.db.search(q), testCase.otherIds, ...
                'a session AND isa search must return the session''s documents');
            q = testCase.sessionQuery(testCase.sessionId) & did.query('demoA.value', 'lessthaneq', 3);
            testCase.verifyNumElements(testCase.db.search(q), 3);
        end
    end
end
