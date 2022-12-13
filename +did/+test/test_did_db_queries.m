function [b,msg] = test_did_db_queries(varargin)
% TEST_DID_BRANCHES - test the branching functionality of a DID database
%
% [B,MSG] = TEST_DID_DB_DOCUMENTS()
% 
% Tests the document adding functions of the did.database class, using the
% did.implementations.sqlitedb class.
%  
% This function first tries to delete a file 'test_db_docs.sqlite', and then
% makes a new database with the same filename.
%
% This function takes name/value pairs that alter its behavior:
% -------------------------------------------------------------------------------
% | Parameter (default)   | Description                                         |
% |-----------------------|-----------------------------------------------------|
% | Do_EXACTSTRING_test(1)| 0/1 Should we test exact_string                     |
% | Do_AND_test (1)       | 0/1 Should we do the AND test?                      |
% | Do_OR_test (1)        | 0/1 Should we do the OR test?                       |
% | doc_id_ind (1)        | [1,n) Index of document whose id we're accessing    | 
% | doc_value_ind (1)     | [1,n) Index of document whose value we're accessing | 
% |-----------------------|-----------------------------------------------------|


 % setup: assign default parameter values
 
Do_EXACTSTRING_test = 1;
Do_AND_test = 1;
Do_OR_test = 1;
doc_id_ind = 1;
doc_value_ind = 1;
did.datastructures.assign(varargin{:});
% ***need to make sure the assigned values are within bounds: 
% for tests, should be 0 or 1
% for inds, should be between 1 and the number of documents produced 
% (this check is more important, since we're not specifying beforehand how many documents
% there are)

% test parameters check:
% 1) EXACTSTRING check
if Do_EXACTSTRING_test~=0 && Do_EXACTSTRING_test~=1
    b = 0;
    msg = ['invalid input - Do_EXACTSTRING_test must be 0 or 1, but was ',num2str(Do_EXACTSTRING_test),'.'];
    return
end
% 2) AND check
if Do_AND_test~=0 && Do_AND_test~=1
    b = 0;
    msg = ['invalid input - Do_AND_test must be 0 or 1, but was ',num2str(Do_AND_test),'.'];
    return
end
% 3) OR check
if Do_OR_test~=0 && Do_OR_test~=1
    b = 0;
    msg = ['invalid input - Do_OR_test must be 0 or 1, but was ',num2str(Do_OR_test),'.'];
    return
end

% Step 1: make an empty database with a starting branch
% delete test_db_docs.sqlite
% db = did.implementations.sqlitedb('test_db_docs.sqlite');
db_filename = [pwd filesep 'test_db_docs.sqlite'];
if isfile(db_filename)
	delete(db_filename); 
end
db = did.implementations.sqlitedb(db_filename);
db.add_branch('a');

% Step 2: generate a set of documents with node names and a graph of the dependencies
[G,node_names,docs] = did.test.documents.make_doc_tree([30 30 30]);

%index parameters check:
if doc_id_ind < 1
    b = 0;
    msg = ['invalid input - doc_id_ind must be 1 or more, but was ',num2str(doc_id_ind),'.'];
    return
end
if doc_value_ind < 1
    b = 0;
    msg = ['invalid input - doc_value_ind must be 1 or more, but was ',num2str(doc_value_ind),'.'];
    return
end
%key step: check that the index parameters are not greater than number of documents generated
if doc_id_ind > numel(docs)
    b = 0;
    msg = ['invalid input - doc_id_ind was ',num2str(doc_id_ind),...
        ', which exceeds the number of documents generated (',num2str(numel(docs)),').'];
    return
end
if doc_value_ind > numel(docs)
    b = 0;
    msg = ['invalid input - doc_value_ind was ',num2str(doc_value_ind),...
        ', which exceeds the number of documents generated (',num2str(numel(docs)),').'];
    return
end

figure;
dG = digraph(G,node_names);
plot(dG,'layout','circle');
title('The dependency relationships among the randomly generated documents.');

for i=1:numel(docs)
	db.add_doc(docs{i});
end

% Step 3: check the database results
[b,msg] = did.test.documents.verify_db_document_structure(db, G, docs);

if ~b,
    return;
end;


% Step 4: test the query capabilities
% for each subtest, test against the same fields
if (numel(docs)>1) %tests only work if there's 2 or more docs
    id_expected = docs{doc_id_ind}.id; %choose an id to set as a variable
    demoType = did.test.fun.get_demoType(docs{doc_value_ind}); %find the demo type that this doc contains
    value_expected = eval(['docs{',num2str(doc_value_ind),'}.document_properties.',demoType,'.value']); %use the demo type to get the value (could also get the value by getting the index of the docs array)
else
    b = 0;
    msg = ['Not enough docs were generated to perform the tests - try again.'];
    return
end

 % 4a: test did.query operation 'exact_string'
    % 1) get id from doc through query
    % 2) string compare to expected doc id
if Do_EXACTSTRING_test
    d1 = db.search(did.query('base.id','exact_string',id_expected));
    d1_docs = db.get_docs(d1); %get_docs converts a cell array containing documents in each cell to a document array
    if ~strcmp(d1_docs(1).id(),id_expected) %should just be 1 doc, but using indexing just in case
        b = 0;
        msg = ['Exact string operation failed - expected doc id did not match.'];
        return
    end
end % Do_EXACTSTRING_test

%  4b: test did.query operations 'and' with 'exact_string' and
%  'exact_number'

if Do_AND_test, 
    %d2 = db.search(did.query('base.id','exact_string',id_expected)&did.query('base.document_version','exact_number',value_expected));
    % ^ this was used when querying for document version using
    % 'exact_number'
    docs_expected = did.test.fun.get_docs_expected(docs,id_expected,value_expected,'and'); %returns a cell array of docs that we expect the query to return
    numDocs_expected = numel(docs_expected); %what is the expected number of documents?
    exact_number_field_name = [demoType,'.value']; %set the first input of the query that uses the exact number operation
    d2 = db.search(did.query('base.id','exact_string',id_expected)&did.query(exact_number_field_name,'exact_number',value_expected));
    if ~iscell(d2) %can't do any of the below if the result of the search is not a cell with documents
        b = 0;
        msg = ['AND operation query did not produce a cell array of documents - instead it produced an array of type ' class(d2) ' and length ' num2str(numel(d2)) '. Expected a cell array with ' num2str(numDocs_expected) ' document(s).'];
        disp(['This is the error; expected a cell array of documents.'])
%         disp(['Setting d2 to be a cell array so we can continue']);
%         d2 = {d2};
%       not sure if ^ is the move, since there's no guarantee attaching
%       curly brackets allows d2 to get through the next set of code
        return
    end;
    d2_docs = db.get_docs(d2);
    numDocs_actual = numel(d2_docs);
    
    cond_numDocs = (numDocs_actual==numDocs_expected);
    %check that there's the same number of documents from query as expected
    if ~cond_numDocs
        b = 0;
        msg = ['Number of AND operation query documents does not equal the expected number: number of docs after query was ' numDocs_actual ' and number of docs expected was ' numDocs_expected '.'];
        return
    end
    %check that the id is the same (assuming 1 document returned from query)
    %***need to check that the size of d2_docs is 1 before accessing 1st index
    if (numDocs_actual==1)
        id_actual = d2_docs(1).id; 
        cond_id = strcmp(id_actual,id_expected);
        if ~cond_id
            b = 0;
            msg = ['AND operation query documents did not match the expected documents: id_actual was ' id_actual ' and id_expected was ' id_expected '.'];
            return
        end
    end


end; % Do_AND_test
    
%4c: test 'or'
if Do_OR_test
    %check if number of documents the same
    exact_number_field_name = [demoType,'.value']; %set the first input of the query that uses the exact number operation
    d3 = db.search(or(did.query('base.id','exact_string',id_expected),did.query(exact_number_field_name,'exact_number',value_expected)));
    d3_docs = db.get_docs(d3);
    numDocs_actual = numel(d3_docs);
    docs_expected = did.test.fun.get_docs_expected(docs,id_expected,value_expected,'or'); 
    numDocs_expected = numel(docs_expected);
    if numDocs_actual~=numDocs_expected
        b = 0;
        msg = ['Number of or operation query documents did not match the expected number of documents: number of docs after query was ' num2str(numDocs_actual) ' and number of docs expected was ' num2str(numDocs_expected) '.'];
        return
    end
    % check for each expected id, there is a matching actual id

    for expected_ind = 1:numDocs_expected
        id_expected = docs_expected{expected_ind}.id;
        b_pre = 0; %for each id, assume b_pre is false unless a match is found
        for pred_ind = 1:numDocs_actual
            id_actual = d3_docs(pred_ind).id;
            if strcmp(id_expected,id_actual)
                b_pre = 1;
            end
        end
        if b_pre==0 %if no match is found for any of the expected ids
            b = 0;
            msg = ['Query failed to produce document with id: ' id_expected,'.'];
        end
    end
    
end % Do_OR_test



