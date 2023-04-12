function [b,msg] = db_queries(varargin)
% [B,MSG] = TEST_DID_DB_QUERIES(VARARGIN)
% 
% Tests the functionality of queries using the db.query class, and using the
% did.implementations.sqlitedb class.
%  
% This function first tries to delete a file 'test_db_docs.sqlite', and then
% makes a new database with the same filename.
%
% This function takes name/value pairs that alter its behavior:
% -----------------------------------------------------------------------------------------------------
% | Parameter (default)                        | Description                                          |
% |--------------------------------------------|------------------------------------------------------|
% | Do_EXACT_STRING_test(0)                    | 0/1 Should we test 'exact_string'?                   |
% | Do_NOT_EXACT_STRING_test(0)                | 0/1 Should we test '~exact_string'?                  |
% | Do_AND_test (0)                            | 0/1 Should we test the AND method?                   |
% | doc_id_ind_for_and (1)                     | doc id index used in AND test                        |         
% | doc_value_ind_for_and (2)                  | doc value index used in AND test                     |
% | Do_OR_test (0)                             | 0/1 Should we test the OR method?                    |
% | Do_NOT_BLUH_test (0)                       | 0/1 Should we test '~bluh'?                          |
% | ***Do_CONTAINS_STRING_test(0)                 | 0/1 Should we test 'contains_string'?                |
% | param1_contains_string ('id_substring_chosen')| what should we use as param1 for a 'contains_string' query?|
% | Do_NOT_CONTAINS_STRING_test(0)             | 0/1 Should we test '~contains_string'?               |
% | Do_LESSTHAN_test (0)                       | 0/1 Should we test 'lessthan'?                       |
% | Do_LESSTHANEQ_test (0)                     | 0/1 Should we test 'lessthaneq'?                     |
% | Do_GREATERTHAN_test (0)                    | 0/1 Should we test 'greaterthan'?                    |
% | Do_GREATERTHANEQ_test (0)                  | 0/1 Should we test 'greaterthaneq'?                  |
% | ***Do_HASFIELD_test (0)                       | 0/1 Should we test 'hasfield'?                       |
% | fieldname ('demoA')                        | the name of the field used to test HASFIELD            |           
% | ***Do_HASMEMBER_test (0)                      | 0/1 Should we test 'hasmember'?                       |
% | param1_hasmember (1)                       | the value to put in param1 in a query using 'hasmember'|
% | ***Do_HASANYSUBFIELD_CONTAINS_STRING_test (0) | 0/1 Should we test 'hasanysubfield_contains_string'? |
% | Do_DEPENDS_ON_test (0)                     | 0/1 Should we test'depends_on'?                      |
% | param1_depends_on ('item1')                | the dependency name chosen
% | Do_ISA_test (0)                            | 0/1 Should we test 'isa'?                            |
% | Do_REGEXP_test (0)                         | 0/1 Should we test'regexp'?                          |
% | *Do_HASSIZE_test (0)                        | 0/1 Should we test 'hassize'?                        |
%   *not implemented in this function
%   ***not implemented in DID / test doesn't pass
% |--------------------------------------------|------------------------------------------------------|


 % setup: assign default parameter values
 
Do_EXACT_STRING_test = 0; 
Do_NOT_EXACT_STRING_test = 0; 
Do_AND_test = 0; 
doc_id_ind_for_and = 1;
doc_value_ind_for_and = 2;
Do_OR_test = 0; 
Do_NOT_BLUH_test = 0; 
Do_CONTAINS_STRING_test = 0; 
param1_contains_string = 'id_substring_chosen';
Do_NOT_CONTAINS_STRING_test = 0;
Do_LESSTHAN_test = 0; 
Do_LESSTHANEQ_test = 0; 
Do_GREATERTHAN_test = 0; 
Do_GREATERTHANEQ_test = 0; 
Do_HASFIELD_test = 0; 
fieldname = 'demoA';
Do_HASMEMBER_test = 0;
param1_hasmember = 1;
Do_HASANYSUBFIELD_CONTAINS_STRING_test = 0; 
Do_DEPENDS_ON_test = 0; 
param1_depends_on = 'item1';
Do_ISA_test = 0; 
Do_REGEXP_test = 0; 
did.datastructures.assign(varargin{:});

doc_id_ind = 1;
doc_value_ind = 1;
doc_value_for_or = [10 11];

% ***need to make sure the assigned values are within bounds: 
% for tests, should be 0 or 1
% for inds, should be between 1 and the number of documents produced 
% (this check is more important, since we're not specifying beforehand how many documents
% there are)

% test parameters check:
% 1) EXACTSTRING check
if Do_EXACT_STRING_test~=0 && Do_EXACT_STRING_test~=1
    b = 0;
    msg = ['invalid input - Do_EXACTSTRING_test must be 0 or 1, but was ',num2str(Do_EXACT_STRING_test),'.'];
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
    id_chosen = docs{doc_id_ind}.id; %choose an id to set as a variable
    demoType = did.test.fun.get_demoType(docs{doc_value_ind}); %find the demo type that this doc contains
    value_chosen = eval(['docs{',num2str(doc_value_ind),'}.document_properties.',demoType,'.value']); %use the demo type to get the value (could also get the value by getting the index of the docs array)
else
    b = 0;
    msg = ['Not enough docs were generated to perform the tests - try again.'];
    return
end

 % 4a: test did.query operation 'exact_string'
    % 1) perform fast did query
    % 2) check that the outcome is a cell array
    % 3) check that the outcome matches the expected outcome 
if Do_EXACT_STRING_test
    q = did.query('base.id','exact_string',id_chosen);
    d1 = db.search(q); %this does a fast search using the database and returns ids
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); %manual search to check outcome of fast search against
    
    disp('Results of EXACT_STRING test:')    
    if ~iscell(d1) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['EXACT_STRING operation query did not produce a cell array of documents - instead it produced an array of type ' class(d1) ' and length ' int2str(numel(d1)) '. Expected a cell array with ' int2str(numel(ids_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d1,
        disp(['We expected:'])
        ids_expected,
        return
    elseif ~did.datastructures.eqlen(d1,ids_expected) %checks that the length and contents of each object are the same
        b = 0;
        msg = ['EXACT_STRING operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d1,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['We got:']);
        d1,
        disp(['We expected:'])
        ids_expected,
    end
end % Do_EXACT_STRING_test

if Do_NOT_EXACT_STRING_test
    q = did.query('base.id','~exact_string',id_chosen);
    d1 = db.search(q); %this does a fast search using the database and returns ids
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); %manual search to check outcome of fast search against
    
    disp('Results of NOT_EXACT_STRING test:')    
    if ~iscell(d1) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['NOT_EXACT_STRING operation query did not produce a cell array of documents - instead it produced an array of type ' class(d1) ' and length ' int2str(numel(d1)) '. Expected a cell array with ' int2str(numel(ids_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d1,
        disp(['We expected:'])
        ids_expected,
        return
    elseif ~did.datastructures.eqlen(d1,ids_expected) %checks that the length and contents of each object are the same
        b = 0;
        msg = ['NOT_EXACT_STRING operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d1,
        disp(['We expected:'])
        ids_expected,
        disp(['We were looking for NOT ' id_chosen])
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d1,
        disp(['We expected:'])
        ids_expected,
    end
end % Do_NOT_EXACT_STRING_test




%  4b: test did.query operations 'and' with 'exact_string' and
%  'exact_number'

if Do_AND_test, 
    id_chosen = docs{doc_id_ind_for_and}.id;
    value_chosen = doc_value_ind_for_and; %doc values are equivalent to their index
    demoType = did.test.fun.get_demoType(docs{doc_value_ind_for_and}); %find the demo type that this doc contains
    exact_number_field_name = [demoType,'.value']; %the value field can only be accessed by going through the demoType field, which may be named differently for each document 
    q = did.query('base.id','exact_string',id_chosen)&did.query(exact_number_field_name,'exact_number',value_chosen); %find docs that have the chosen id AND the chosen value (numerical field located in demoType)
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); %returns a cell array of doc ids and docs themselves that we expect the query to return
    d2 = db.search(q); %manual search to check outcome of fast search against
    
    disp('Results of AND test:')
    if ~iscell(d2) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['AND operation query did not produce a cell array of documents - instead it produced an array of type ' class(d2) ' and length ' int2str(numel(d2)) '. Expected a cell array with ' int2str(numel(ids_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d2,
        disp(['We expected:'])
        ids_expected,
        return
    elseif ~did.datastructures.eqlen(d2,ids_expected) && ... %checks that the length and contents of each object are the same
        ~( isempty(d2) && isempty(ids_expected)) %length of arrays doesn't matter if both are empty
        b = 0;
        msg = ['AND operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d2,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['We got:']);
        d2,
        disp(['We expected:'])
        ids_expected,
    end;

end; % Do_AND_test
    
%4c: test 'or'
if Do_OR_test
    demoType1 = did.test.fun.get_demoType(docs{doc_value_for_or(1)}); %check how to access the 'value' field for the document we should find with an exact number query
    exact_number_field_name1 = [demoType1,'.value']; %create a fieldname string that will help access the 'value' field for the first exact number query
    demoType2 = did.test.fun.get_demoType(docs{doc_value_for_or(2)});
    exact_number_field_name2 = [demoType2,'.value']; %create a fieldname string that will help access the 'value' field for the second exact number query
    q = or(did.query('base.id','exact_string',id_chosen),or(did.query(exact_number_field_name1,'exact_number',doc_value_for_or(1)),did.query(exact_number_field_name2,'exact_number',doc_value_for_or(2))));
    d3 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); %returns a cell array of doc ids and docs that we expect the query to return
    
    disp('Results of OR test:')
    if ~iscell(d3) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['OR operation query did not produce a cell array of documents - instead it produced an array of type ' class(d3) ' and length ' int2str(numel(d3)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg);
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d3,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d3(:),ids_expected(:)) && ~( isempty(d2) && isempty(ids_expected))
        b = 0;
        msg = ['OR operation query did not produce expected output.'];
        disp(msg);
        disp(['We got:']);
        d3,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['We got:']);
        d3,
        disp(['We expected:'])
        ids_expected,
    end;
    
end % Do_OR_test

% 4d: test 'not'
% supposed to run into an exception since we are using an incorrect
% operator 'bluh'
if Do_NOT_BLUH_test %run a test of the NOT operator in a query 
    q = did.query('base.id','~bluh',id_chosen); %using ~ for NOT
    try 
        d4 = db.search(q); 
    catch exception
        d4 = exception;
    end
    try
        [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    catch exception_expected
        ids_expected = exception_expected; %doing this to check whether the apply_didquery function throws an exception or has a real output
    end
    
    disp('Results of NOT_BLUH test:') 
    if ~iscell(d4) && ~isa(d4,'MException') %can't do any of the below if the result of the search is not a cell with document ids or an exception
        b = 0;
        msg = ['NOT_BLUH operation query did not produce a cell array of documents - instead it produced an array of type ' class(d4) ' and length ' int2str(numel(d4)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d4,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif isa(d4,'MException') %won't produce exact same exception, but as long as it passes an exception in both cases, it should pass the test
        if ~isa(ids_expected,'MException')
            b = 0;
            msg = ['NOT_BLUH operation query did not produce expected output.'];
            disp(msg)
            disp(['We got:']);
            d4,
            disp(['We expected:'])
            exception_expected,
            return
        else
            disp(['We got:']);
            d4,
            disp(['We expected:'])
            exception_expected,
        end
    elseif ~did.datastructures.eqlen(d4(:),ids_expected(:))
        b = 0;
        msg = ['NOT_BLUH operation query did not produce expected output.'];
        disp(msg)
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d4,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d4,
        disp(['We expected:'])
        ids_expected,
    end;
end % Do_NOT_BLUH_test

%test 'contains_string'
if Do_CONTAINS_STRING_test
    if strcmp(param1_contains_string,'id_substring_chosen')
        param1 = cell2mat(extractBetween(id_chosen,11,12)); %base the chosen id_substring off of the previously chosen full id, (max 33 characters)
    else
        param1 = param1_contains_string;
    end
    q = did.query('base.id','contains_string',param1); 
    d = db.search(q); 
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    disp('Results of CONTAINS_STRING test:');
    if ~iscell(d) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['CONTAINS_STRING operation query did not produce a cell array of documents - instead it produced an array of type ' class(d) ' and length ' int2str(numel(d)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['The string was ' param1])
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d(:),ids_expected(:))
        b = 0;
        msg = ['CONTAINS_STRING operation query did not produce expected output.'];
        disp(msg)
        disp(['The string was ' param1])
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['The string was ' param1])
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
    end;
end

%test '~contains_string'
    % ^using NOT with CONTAINS_STRING is a more flexible way to test NOT
if Do_NOT_CONTAINS_STRING_test
    id_substring_chosen = cell2mat(extractBetween(id_chosen,11,12)); %base the chosen id_substring off of the previously chosen full id, (max 33 characters)
    q = did.query('base.id','~contains_string',id_substring_chosen); 
    d = db.search(q); 
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    disp('Results of NOT_CONTAINS_STRING test:');
    if ~iscell(d) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['NOT_CONTAINS_STRING operation query did not produce a cell array of documents - instead it produced an array of type ' class(d) ' and length ' int2str(numel(d)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d(:),ids_expected(:))
        b = 0;
        msg = ['NOT_CONTAINS_STRING operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['The string was ' id_substring_chosen])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
    end;
end % Do_NOT_CONTAINS_STRING_test

%test 'lessthan'
if Do_LESSTHAN_test
    number_chosen = randi(100);
    %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
    % but may not return the amount of documents expected if a document's
    % value is stored in the demoB or demoC field (would occur if the
    % document does not have a demoA field)
    q = or(did.query('demoA.value','lessthan',number_chosen),or(did.query('demoB.value','lessthan',number_chosen),did.query('demoC.value','lessthan',number_chosen)));
    d6 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    
    disp(['Results of LESSTHAN test:'])
    if ~iscell(d6) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['LESSTHAN operation query did not produce a cell array of documents - instead it produced an array of type ' class(d6) ' and length ' int2str(numel(d6)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d6,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d6(:),ids_expected(:))
        b = 0;
        msg = ['LESSTHAN operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d6,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['We got:']);
        d6,
        disp(['We expected:'])
        ids_expected,
    end;
end

%4g: test 'lessthaneq'
if Do_LESSTHANEQ_test
    number_chosen = 48;
    %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
    % but may not return the amount of documents expected if a document's
    % value is stored in the demoB or demoC field (would occur if the
    % document does not have a demoA field)
    q = or(did.query('demoA.value','lessthaneq',number_chosen),or(did.query('demoB.value','lessthaneq',number_chosen),did.query('demoC.value','lessthaneq',number_chosen)));
    d7 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    disp(['Results of LESSTHANEQ test:'])
    if ~iscell(d7) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['LESSTHANEQ operation query did not produce a cell array of documents - instead it produced an array of type ' class(d7) ' and length ' int2str(numel(d7)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d7,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d7(:),ids_expected(:))
        b = 0;
        msg = ['LESSTHANEQ operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d7,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['We got:']);
        d7,
        disp(['We expected:'])
        ids_expected,
    end;
end

%4h: test 'greaterthan'
if Do_GREATERTHAN_test
    number_chosen = 1;
    %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
    % but may not return the amount of documents expected if a document's
    % value is stored in the demoB or demoC field (would occur if the
    % document does not have a demoA field)
    q = or(did.query('demoA.value','greaterthan',number_chosen),or(did.query('demoB.value','greaterthan',number_chosen),did.query('demoC.value','greaterthan',number_chosen)));
    d8 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    disp(['Results of GREATERTHAN test:'])
    if ~iscell(d8) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['GREATERTHAN operation query did not produce a cell array of documents - instead it produced an array of type ' class(d8) ' and length ' int2str(numel(d8)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d8,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d8(:),ids_expected(:))
        b = 0;
        msg = ['GREATERTHAN operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d8,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d8,
        disp(['We expected:'])
        ids_expected,
    end;
end

%4i: test 'greaterthaneq'
if Do_GREATERTHANEQ_test
    number_chosen = 1;
    %q = did.query('demoA.value','lessthan',number_chosen); %easy option,
    % but may not return the amount of documents expected if a document's
    % value is stored in the demoB or demoC field (would occur if the
    % document does not have a demoA field)
    q = or(did.query('demoA.value','greaterthaneq',number_chosen),or(did.query('demoB.value','greaterthaneq',number_chosen),did.query('demoC.value','greaterthaneq',number_chosen)));
    d9 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q); 
    disp(['Results of GREATERTHANEQ test:'])
    if ~iscell(d9) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['GREATERTHANEQ operation query did not produce a cell array of documents - instead it produced an array of type ' class(d9) ' and length ' int2str(numel(d9)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d9,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d9(:),ids_expected(:))
        b = 0;
        msg = ['GREATERTHANEQ operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d9,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d9,
        disp(['We expected:'])
        ids_expected,
    end;
end % Do_GREATERTHANEQ_test

%4j: test 'hasfield'
if Do_HASFIELD_test
    q = did.query(fieldname,'hasfield');
    d = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q);
    disp(['Results of HASFIELD test:'])
    if ~iscell(d) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['HASFIELD operation query did not produce a cell array of documents - instead it produced an array of type ' class(d) ' and length ' int2str(numel(d)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d(:),ids_expected(:))
        b = 0;
        msg = ['HASFIELD operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
    end;
end % Do_HASFIELD_test

%test 'hasmember'
if Do_HASMEMBER_test
    param1 = param1_hasmember;
    q = did.query(fieldname,'hasmember',param1);
    d = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q);
    disp(['Results of HASMEMBER test:'])
    if ~iscell(d) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['HASMEMBER operation query did not produce a cell array of documents - instead it produced an array of type ' class(d) ' and length ' int2str(numel(d)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d(:),ids_expected(:))
        b = 0;
        msg = ['HASMEMBER operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d,
        disp(['We expected:'])
        ids_expected,
    end;
end % 'Do_HASMEMBER_test'

%test 'hasanysubfield_contains_string'
if Do_HASANYSUBFIELD_CONTAINS_STRING_test
    doc_id_ind = randi(numel(docs));
    doc_id = docs{doc_id_ind}.id;
    q = did.query('base','hasanysubfield_contains_string','id',doc_id);
    d11 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q);
    disp(['Results of HASANYSUBFIELD_CONTAINS_STRING test:'])
    if ~iscell(d11) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['HASANYSUBFIELD_CONTAINS_STRING operation query did not produce a cell array of documents - instead it produced an array of type ' class(d11) ' and length ' int2str(numel(d11)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d11(:),ids_expected(:))
        b = 0;
        msg = ['HASANYSUBFIELD_CONTAINS_STRING operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
    end;
    
end %Do_HASANYSUBFIELD_CONTAINS_STRING_test

%4l: test 'depends_on' 
if Do_DEPENDS_ON_test
    doc_ind = numel(docs); %choose last document to ensure we use the demoC build, which contains the depends_on field
    if numel(docs{doc_ind}.document_properties.depends_on)>0 %so we don't try to access indices of an array that don't exist
        %dependency_name = docs{doc_ind}.document_properties.depends_on(1).name;
        dependency_name = param1_depends_on;
        dependency_value = docs{doc_ind}.document_properties.depends_on(2).value;
    else %maybe do a try catch to check if you get an expected error
        dependency_name = '';
        dependency_value = '';
    end
    q = did.query('','depends_on',dependency_name,dependency_value);
    d11 = db.search(q);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q);
    disp(['Results of DEPENDS_ON test:'])
    if ~iscell(d11) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['DEPENDS_ON operation query did not produce a cell array of documents - instead it produced an array of type ' class(d11) ' and length ' int2str(numel(d11)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d11(:),ids_expected(:))
        b = 0;
        msg = ['DEPENDS_ON operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
    end;
    
end %Do_DEPENDS_ON_test

%4m: test 'isa'
% ISA is a combination of the subqueries CONTAINS_STRING and
% HASANYSUBFIELD_CONTAINS_STRING
if Do_ISA_test
    q = did.query('','isa','demoB');
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q);
    d11 = db.search(q); 
    disp(['Results of ISA test:'])
    if ~iscell(d11) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['ISA operation query did not produce a cell array of documents - instead it produced an array of type ' class(d11) ' and length ' int2str(numel(d11)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d11(:),ids_expected(:))
        b = 0;
        msg = ['ISA operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
    end;
end %Do_ISA_test

%4n: test 'regexp'
% use the datestamp field in base, which has a defined structure, and
% choose one digit arbitrarily (preferably one that is relatively evenly distributed between the 10 digits among different documents)
if Do_REGEXP_test
    regexp_chosen = '\d{4}-\d{2}-\d{2}\w\d{2}:\d{2}:\d{2}.\d{2}0\w'; %last digit arbitrarily chosen to be a 0
    q = did.query('base.datestamp','regexp',regexp_chosen);
    [ids_expected,docs_expected] = did.test.fun.apply_didquery(docs,q);
    d11 = db.search(q);
    disp(['Results of REGEXP test:'])
    if ~iscell(d11) %can't do any of the below if the result of the search is not a cell with document ids
        b = 0;
        msg = ['REGEXP operation query did not produce a cell array of documents - instead it produced an array of type ' class(d11) ' and length ' int2str(numel(d11)) '. Expected a cell array with ' int2str(numel(docs_expected)) ' document(s).'];
        disp(msg)
        disp(['This is the error; expected a cell array of documents.'])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return;
    elseif ~did.datastructures.eqlen(d11(:),ids_expected(:))
        b = 0;
        msg = ['REGEXP operation query did not produce expected output.'];
        disp(msg)
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
        return
    else
        disp(['Number of total docs: ' num2str(numel(docs))])
        disp(['We got:']);
        d11,
        disp(['We expected:'])
        ids_expected,
    end;
end %Do_REGEXP_test