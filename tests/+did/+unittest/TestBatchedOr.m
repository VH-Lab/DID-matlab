classdef TestBatchedOr < matlab.unittest.TestCase
    % Test that ORs are searched in batches of SQL terms, with the same results
    %
    % did.database/search_or_operands searches the operands of an OR that
    % are single SQL terms up to orBatchTerms at a time in one SQL query
    % (UNIONed SELECTs over a whole branch; one WHERE with the conditions
    % ORed together when restricted to candidate documents), instead of one
    % query per operand. These tests compare every search with the same
    % search made one query per operand (QueryLogSqlitedb.orBatchSize = 1,
    % the path used before batching), for every operation the SQL builder
    % supports, negated ones included; and check that the batched search
    % runs fewer queries. See issue #233.

    properties (Constant)
        db_filename = 'test_db_batched_or.sqlite'
        numA = 60  % demoA documents
        numB = 40  % demoB documents (also demoA)
        numC = 30  % demoC documents, depending on demoA and demoB documents
    end

    properties
        db      % did.test.helper.QueryLogSqlitedb
        idsA    % base.id of the demoA documents, in order added
        idsB    % base.id of the demoB documents
        idsC    % base.id of the demoC documents
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);

            testCase.db = did.test.helper.QueryLogSqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');

            docs = {};
            for i = 1:testCase.numA
                docs{end+1} = did.document('demoA', 'base.name', sprintf('n%d', i), ...
                    'demoA.value', i); %#ok<AGROW>
            end
            for i = 1:testCase.numB
                docs{end+1} = did.document('demoB', 'base.name', sprintf('b%d', i), ...
                    'demoA.value', i, 'demoB.value', 100 + i); %#ok<AGROW>
            end
            ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.idsA = ids(1:testCase.numA);
            testCase.idsB = ids(testCase.numA+1:end);
            for i = 1:testCase.numC
                d = did.document('demoC', 'base.name', sprintf('c%d', i), 'demoC.value', 200 + i);
                d = d.set_dependency_value('item1', testCase.idsA{i});
                d = d.set_dependency_value('item2', testCase.idsB{mod(i-1, testCase.numB) + 1});
                docs{end+1} = d; %#ok<AGROW>
            end
            testCase.db.add_docs(docs, 'a', 'Validate', false);
            ids = cellfun(@(d) d.id(), docs, 'UniformOutput', false);
            testCase.idsC = ids(testCase.numA+testCase.numB+1:end);
        end
    end

    methods (TestMethodTeardown)
        function restoreDefaults(testCase)
            testCase.db.orBatchSize = [];
            testCase.db.noSearchIndexes = false;
        end
    end

    methods
        function terms = allTerms(testCase)
            % One search term for every operation query_struct_to_sql_str
            % supports, and its negation (hasfield ignores negation in SQL,
            % and is kept for completeness)
            terms = {
                did.query('base.name', 'exact_string', 'n7')
                did.query('base.name', 'exact_string_anycase', 'N8')
                did.query('base.name', 'contains_string', 'b1')
                did.query('demoA.value', 'exact_number', 12)
                did.query('demoA.value', 'lessthan', 3)
                did.query('demoA.value', 'lessthaneq', 3)
                did.query('demoB.value', 'greaterthan', 138)
                did.query('demoB.value', 'greaterthaneq', 138)
                did.query('demoB', 'hasfield')
                did.query('', 'depends_on', 'item1', testCase.idsA{4})
                did.query('base.name', 'regexp', '^c2')
                did.query('', 'isa', 'demoB')
                did.query('', 'isa', 'demoC')
                };
            negatable = terms([1:8 10:13]);
            for k = 1:numel(negatable)
                s = negatable{k}.searchstructure;
                s.operation = ['~' s.operation];
                terms{end+1, 1} = s; %#ok<AGROW>
            end
            terms{end+1, 1} = struct('field', 'demoB', 'operation', '~hasfield', ...
                'param1', '', 'param2', '');
        end

        function s = toStruct(~, q)
            if isa(q, 'did.query')
                s = q.searchstructure;
            else
                s = q;
            end
        end

        function s = orOf(testCase, terms)
            % Left-nested OR of search structures, as q = q | ... builds it
            s = testCase.toStruct(terms{1});
            for k = 2:numel(terms)
                s = struct('field', '', 'operation', 'or', ...
                    'param1', s, 'param2', testCase.toStruct(terms{k}));
            end
        end

        function [found, numQueries] = searchWith(testCase, q, batchSize)
            % Search with at most BATCHSIZE OR operands per SQL query ([] =
            % the default), and count the document queries run
            testCase.db.orBatchSize = batchSize;
            testCase.db.clearQueryLog();
            found = testCase.db.search(q);
            entries = testCase.db.queryLog;
            numQueries = nnz(startsWith({entries.query}, 'SELECT DISTINCT docs.doc_id'));
            testCase.db.orBatchSize = [];
        end

        function verifyBatchedMatchesPerOperand(testCase, q, msg)
            % The batched search (default batch size, and batches of 3)
            % must return exactly what one query per operand returns
            perOperand = testCase.searchWith(q, 1);
            batched = testCase.searchWith(q, []);
            testCase.verifyEqual(batched, perOperand, [msg ': batched search']);
            smallBatches = testCase.searchWith(q, 3);
            testCase.verifyEqual(smallBatches, perOperand, [msg ': batches of 3']);
        end
    end

    methods (Test)
        function testEveryOperationInAnOr(testCase)
            terms = testCase.allTerms();
            for k = 1:numel(terms)
                s = testCase.toStruct(terms{k});
                q = testCase.orOf({terms{k}, did.query('base.name', 'exact_string', 'n3'), ...
                    did.query('', 'isa', 'demoC')});
                testCase.verifyBatchedMatchesPerOperand(q, ...
                    sprintf('%s %s OR ...', s.operation, s.field));
            end
        end

        function testAllOperationsInOneOr(testCase)
            q = testCase.orOf(testCase.allTerms());
            testCase.verifyBatchedMatchesPerOperand(q, 'an OR of every operation');
            [~, numQueries] = testCase.searchWith(q, []);
            testCase.verifyEqual(numQueries, 1, ...
                'an OR of single SQL terms must be searched in one query');
        end

        function testEveryOperationInAnOrInsideAnAnd(testCase)
            % 'isa demoB' leaves 40 candidates, so the OR is searched
            % restricted to them, with the conditions ORed in one query
            terms = testCase.allTerms();
            for k = 1:numel(terms)
                s = testCase.toStruct(terms{k});
                orPart = testCase.orOf({terms{k}, did.query('base.name', 'exact_string', 'b3'), ...
                    did.query('demoA.value', 'lessthan', 5)});
                q = [testCase.toStruct(did.query('', 'isa', 'demoB')), orPart];
                testCase.verifyBatchedMatchesPerOperand(q, ...
                    sprintf('isa demoB AND (%s %s OR ...)', s.operation, s.field));

                % ...and it must match the search over the whole branch
                batched = testCase.searchWith(q, []);
                testCase.db.noSearchIndexes = true;
                full = testCase.searchWith(q, 1);
                testCase.db.noSearchIndexes = false;
                testCase.verifyEqual(sort(batched(:)), sort(full(:)), ...
                    sprintf('isa demoB AND (%s %s OR ...): restricted vs. whole branch', ...
                    s.operation, s.field));
            end

            q = [testCase.toStruct(did.query('', 'isa', 'demoB')), testCase.orOf(terms)];
            testCase.verifyBatchedMatchesPerOperand(q, 'isa demoB AND an OR of every operation');
            [~, numQueries] = testCase.searchWith(q, []);
            testCase.verifyEqual(numQueries, 2, ...
                'the isa term and the restricted OR must take one query each');
        end

        function testMixedOr(testCase)
            % base.id lookups, ANDs and a negated OR among the operands:
            % the ids are searched together, the ANDs and the negated OR on
            % their own, and the rest in one batch
            nameIs = @(n) did.query('base.name', 'exact_string', n);
            andTerm = did.query('', 'isa', 'demoB') & did.query('demoA.value', 'lessthan', 4);
            notOr = struct('field', '', 'operation', '~or', ...
                'param1', nameIs('n1').searchstructure, 'param2', nameIs('n2').searchstructure);
            terms = {did.query('base.id', 'exact_string', testCase.idsA{20}), ...
                nameIs('n5'), andTerm, did.query('', 'isa', 'demoC'), ...
                did.query('base.id', 'exact_string', testCase.idsB{20}), notOr, ...
                did.query('base.id', 'exact_string', 'no_such_id'), ...
                did.query('demoA.value', '~greaterthan', 2)};
            q = testCase.orOf(terms);
            testCase.verifyBatchedMatchesPerOperand(q, 'a mixed OR');

            [found, numQueries] = testCase.searchWith(q, []);
            testCase.verifyTrue(all(ismember([testCase.idsA(20) testCase.idsB(20)], found)), ...
                'the ids looked up must be found');
            testCase.verifyTrue(all(ismember(testCase.idsC, found)), ...
                'every demoC document must be found');
            [~, perOperandQueries] = testCase.searchWith(q, 1);
            testCase.verifyLessThan(numQueries, perOperandQueries);

            % ...and the same inside an AND
            q2 = [testCase.toStruct(did.query('base.name', 'regexp', '^[nbc][0-9]$')), q];
            testCase.verifyBatchedMatchesPerOperand(q2, 'a mixed OR inside an AND');
        end

        function testLongOrIsSearchedInBatches(testCase)
            % 450 names: 3 queries of at most 200 terms, not 450
            names = [arrayfun(@(i) sprintf('n%d', i), 1:testCase.numA, 'UniformOutput', false), ...
                arrayfun(@(i) sprintf('missing%d', i), 1:390, 'UniformOutput', false)];
            terms = cellfun(@(n) did.query('base.name', 'exact_string', n), names, ...
                'UniformOutput', false);
            q = testCase.orOf(terms);

            [batched, numQueries] = testCase.searchWith(q, []);
            [perOperand, perOperandQueries] = testCase.searchWith(q, 1);
            testCase.verifyEqual(batched, perOperand);
            testCase.verifyEqual(sort(batched(:)), sort(testCase.idsA(:)), ...
                'every demoA document is named in the OR');
            testCase.verifyEqual(numQueries, 3, 'an OR of 450 terms takes 3 batches of 200');
            testCase.verifyEqual(perOperandQueries, 450);

            % ...restricted to candidates: the isa query, then 3 batches
            q2 = [testCase.toStruct(did.query('', 'isa', 'demoA')), q];
            [found, numQueries] = testCase.searchWith(q2, []);
            testCase.verifyEqual(sort(found(:)), sort(testCase.idsA(:)));
            testCase.verifyEqual(numQueries, 4);
            testCase.verifyEqual(found, testCase.searchWith(q2, 1));
        end

        function testBruteForceDependsOnInAnOr(testCase)
            % A depends_on that SQL cannot match exactly (an empty name; see
            % did.database/isBruteForceDependsOn) has no SQL form, so it is
            % searched by brute_force_search on its own, not in a batch
            value = testCase.idsA{4};
            emptyName = did.query('', 'depends_on', '', value);
            notEmptyName = did.query('', 'depends_on', '', value).searchstructure;
            notEmptyName.operation = '~depends_on';
            for term = {emptyName, notEmptyName}
                s = testCase.toStruct(term{1});
                q = testCase.orOf({term{1}, did.query('base.name', 'exact_string', 'n3'), ...
                    did.query('', 'isa', 'demoC'), did.query('', 'depends_on', 'item1', value)});
                testCase.verifyBatchedMatchesPerOperand(q, [s.operation ' with an empty name, in an OR']);
                q2 = [testCase.toStruct(did.query('', 'isa', 'demoC')), q];
                testCase.verifyBatchedMatchesPerOperand(q2, ...
                    [s.operation ' with an empty name, in an OR inside an AND']);
            end
        end

        function testBruteForceHasMemberInAnOr(testCase)
            % hasmember is always searched by brute_force_search (see
            % did.database/isBruteForceTerm), on its own, not in a batch
            member = did.query('demoC.value', 'hasmember', 205);
            notMember = member.searchstructure;
            notMember.operation = '~hasmember';
            for term = {member, notMember}
                s = testCase.toStruct(term{1});
                q = testCase.orOf({term{1}, did.query('base.name', 'exact_string', 'n3'), ...
                    did.query('', 'isa', 'demoB')});
                testCase.verifyBatchedMatchesPerOperand(q, [s.operation ' in an OR']);
                q2 = [testCase.toStruct(did.query('', 'isa', 'demoC')), q];
                testCase.verifyBatchedMatchesPerOperand(q2, [s.operation ' in an OR inside an AND']);
            end
        end

        function testWithoutSearchIndexes(testCase)
            % Without the indexes there are no candidates and no batched
            % id lookups; the batch is a UNION over the whole branch
            testCase.db.noSearchIndexes = true;
            q = testCase.orOf([testCase.allTerms(); ...
                {did.query('base.id', 'exact_string', testCase.idsB{2})}]);
            testCase.verifyBatchedMatchesPerOperand(q, 'an OR without the search indexes');
            q2 = [testCase.toStruct(did.query('', 'isa', 'demoB')), q];
            testCase.verifyBatchedMatchesPerOperand(q2, 'an OR in an AND without the search indexes');
        end
    end
end
