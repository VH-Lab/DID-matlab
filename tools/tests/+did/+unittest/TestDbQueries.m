classdef TestDbQueries < matlab.unittest.TestCase
    % TestDbQueries
    % Test case for verifying database queries using did.test.db_queries



    properties (Constant)
        db_filename = 'test_db_docs.sqlite' % Holds the path to the SQLite database
    end

    properties (TestParameter)
        doc_value_ind_for_and = {1, 2}
        sub_string = {'', 'bc', '_c'}
        fieldname = {'demoA', 'demoA.value'}
    end

    properties
        db             % Database object
        G              % Database graph object
        docs           % Document object
        node_names     % Full file paths for test files
        fname          % Filenames
    end

    methods (TestClassSetup)
        function setupClass(testCase)
            % Create a temporary working directory to run tests in
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            % Step 1: make an empty database with a starting branch
            testCase.db = did.implementations.sqlitedb(testCase.db_filename);
            testCase.db.add_branch('a');

            % Step 2: generate a set of documents with node names and a graph of the dependencies
            [testCase.G, testCase.node_names, testCase.docs] = ...
                did.test.helper.documents.make_doc_tree([10 10 10]);

            for i=1:numel(testCase.docs)
                testCase.db.add_doc(testCase.docs{i});
            end

            % Step 3: check the database results
            [b, msg] = did.test.helper.documents.verify_db_document_structure(...
                testCase.db, testCase.G, testCase.docs);
        end
    end

    methods
        function testQuery(testCase, query)

            % Do a fast search using the database and returns ids
            ids_actual = testCase.db.search(query);
            testCase.assertClass(ids_actual, 'cell', ...
                'Expected query to produce a cell array of document ids')

            % Do manual search to get expected value of fast search
            [ids_expected, ~] = did.test.helper.utility.apply_didquery(testCase.docs, query);

            if isempty(ids_actual)
                testCase.assertEmpty(ids_expected)
            else
                % Ids_expected will always be a column vector
                if isrow(ids_actual); ids_actual = ids_actual'; end

                testCase.assertEqual(ids_actual, ids_expected, ...
                    'Query result is not equal to manual result')
            end
        end

        function documentId = getRandomDocumentId(testCase)
            % Choose an id to set as a variable
            numDocs = numel(testCase.docs);
            documentIdx = randi(numDocs);
            documentId = testCase.docs{documentIdx}.id;
        end
    end

    methods (Test)

        function testPlotDocumentDependencyRelationships(testCase)
            figure;
            dG = digraph(testCase.G, testCase.node_names);
            plot(dG,'layout','circle');
            title('The dependency relationships among the randomly generated documents.');
        end

        function testExactString(testCase)

            % Choose an id to set as a variable
            id_chosen = testCase.getRandomDocumentId();

            % Do a fast search using the database and return document ids
            q = did.query('base.id', 'exact_string', id_chosen);

            testCase.testQuery(q)
        end

        function testNotExactString(testCase)

            % Choose an id to set as a variable
            id_chosen = testCase.getRandomDocumentId();

            % Do a fast search using the database and return document ids
            q = did.query('base.id', '~exact_string', id_chosen);

            testCase.testQuery(q)
        end

        function testAnd(testCase, doc_value_ind_for_and)

            doc_id_ind_for_and = 1;
            id_chosen = testCase.docs{doc_id_ind_for_and}.id;

            value_chosen = doc_value_ind_for_and; %doc values are equivalent to their index
            demoType = did.test.helper.utility.get_demoType(testCase.docs{doc_value_ind_for_and}); %find the demo type that this doc contains
            exact_number_field_name = [demoType,'.value']; %the value field can only be accessed by going through the demoType field, which may be named differently for each document

            q = did.query('base.id','exact_string',id_chosen) & did.query(exact_number_field_name,'exact_number',value_chosen); %find docs that have the chosen id AND the chosen value (numerical field located in demoType)
            testCase.testQuery(q)
        end

        function testOr(testCase)
            id_chosen = testCase.getRandomDocumentId();
            doc_value_for_or = [10 11];

            demoType1 = did.test.helper.utility.get_demoType(testCase.docs{doc_value_for_or(1)}); %check how to access the 'value' field for the document we should find with an exact number query
            exact_number_field_name1 = [demoType1,'.value']; %create a fieldname string that will help access the 'value' field for the first exact number query
            demoType2 = did.test.helper.utility.get_demoType(testCase.docs{doc_value_for_or(2)});
            exact_number_field_name2 = [demoType2,'.value']; %create a fieldname string that will help access the 'value' field for the second exact number query
            q = or(did.query('base.id','exact_string',id_chosen),or(did.query(exact_number_field_name1,'exact_number',doc_value_for_or(1)),did.query(exact_number_field_name2,'exact_number',doc_value_for_or(2))));

            testCase.testQuery(q)
        end

        function testDoNotBluh(testCase)
            id_chosen = testCase.getRandomDocumentId();
            q = did.query('base.id','~bluh',id_chosen); %using ~ for NOT

            testCase.assertError(@(query) testCase.db.search(q), 'DID:Database:SQL')

            % Doing this to check whether the apply_didquery function throws an exception or has a real output
            try
                [~, ~] = did.test.helper.utility.apply_didquery(testCase.docs, q);
            catch ME
                testCase.assertSubstring(ME.message, 'Unknown search operation bluh')
            end
        end

        function testContainsString(testCase, sub_string)
            if isempty(sub_string)
                id_chosen = testCase.getRandomDocumentId();
                % Get substring of randomly chosen id.
                sub_string = cell2mat(extractBetween(id_chosen, 11, 12));
            end

            q = did.query('base.id', 'contains_string', sub_string);
            testCase.testQuery(q)
        end

        function testDoNotContainsString(testCase)
            id_chosen = testCase.getRandomDocumentId();
            id_substring_chosen = cell2mat(extractBetween(id_chosen,11,12)); %base the chosen id_substring off of the previously chosen full id, (max 33 characters)
            q = did.query('base.id', '~contains_string', id_substring_chosen);

            testCase.testQuery(q)
        end

        function testLessThan(testCase)

            number_chosen = randi(100);
            %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
            % but may not return the amount of documents expected if a document's
            % value is stored in the demoB or demoC field (would occur if the
            % document does not have a demoA field

            queryA = did.query('demoA.value','lessthan',number_chosen);
            queryB = did.query('demoB.value','lessthan',number_chosen);
            queryC = did.query('demoC.value','lessthan',number_chosen);

            q = or(queryA, or(queryB, queryC));
            testCase.testQuery(q)
        end

        function testLessThanEqual(testCase)
            number_chosen = 48;
            %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
            % but may not return the amount of documents expected if a document's
            % value is stored in the demoB or demoC field (would occur if the
            % document does not have a demoA field)

            queryA = did.query('demoA.value','lessthaneq',number_chosen);
            queryB = did.query('demoB.value','lessthaneq',number_chosen);
            queryC = did.query('demoC.value','lessthaneq',number_chosen);

            q = or(queryA, or(queryB, queryC));
            testCase.testQuery(q)
        end

        function testDoGreaterThan(testCase)
            number_chosen = 1;
            %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
            % but may not return the amount of documents expected if a document's
            % value is stored in the demoB or demoC field (would occur if the
            % document does not have a demoA field)

            queryA = did.query('demoA.value','greaterthan',number_chosen);
            queryB = did.query('demoB.value','greaterthan',number_chosen);
            queryC = did.query('demoC.value','greaterthan',number_chosen);

            q = or(queryA, or(queryB, queryC));
            testCase.testQuery(q)
        end

        function testDoGreaterThanEqual(testCase)
            number_chosen = 1;
            %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
            % but may not return the amount of documents expected if a document's
            % value is stored in the demoB or demoC field (would occur if the
            % document does not have a demoA field)

            queryA = did.query('demoA.value','greaterthaneq',number_chosen);
            queryB = did.query('demoB.value','greaterthaneq',number_chosen);
            queryC = did.query('demoC.value','greaterthaneq',number_chosen);

            q = or(queryA, or(queryB, queryC));
            testCase.testQuery(q)
        end

        function testHasField(testCase, fieldname)
            q = did.query(fieldname, 'hasfield');
            testCase.testQuery(q)
        end

        function testHasMember(testCase)
            fieldname = 'demoA.value'; %#ok<PROP>
            param1 = 1;
            q = did.query(fieldname, 'hasmember', param1);
            testCase.testQuery(q)
        end

        function testDependsOn(testCase)
            param1_depends_on = 'item1';

            doc_ind = numel(testCase.docs); %choose last document to ensure we use the demoC build, which contains the depends_on field
            if numel(testCase.docs{doc_ind}.document_properties.depends_on)>0 %so we don't try to access indices of an array that don't exist
                %dependency_name = docs{doc_ind}.document_properties.depends_on(1).name;
                dependency_name = param1_depends_on;
                dependency_value = testCase.docs{doc_ind}.document_properties.depends_on(2).value;
            else %maybe do a try catch to check if you get an expected error
                dependency_name = '';
                dependency_value = '';
            end
            q = did.query('','depends_on',dependency_name,dependency_value);
            testCase.testQuery(q)
        end

        function testDoIsA(testCase)
            q = did.query('','isa','demoB');
            testCase.testQuery(q)
        end

        function testDoRegExp(testCase)
            regexp_chosen = '\d{4}-\d{2}-\d{2}\w\d{2}:\d{2}:\d{2}.\d{2}0\w'; %last digit arbitrarily chosen to be a 0
            q = did.query('base.datestamp','regexp',regexp_chosen);
            testCase.testQuery(q)
        end
    end
end
