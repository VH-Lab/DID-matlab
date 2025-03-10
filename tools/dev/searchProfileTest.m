function db = searchProfileTest(db, test_number)
% SEARCHPROFILETEST - perform a profiling test of querying DID databases
%
% DB = SEARCHPROFILETEST(DB, TEST_NUMBER)
%
% Create an example database and test query speed.
%
% TEST_NUMBER == 1:
%    Search and retrieve all documents of one type
% TEST_NUMBER == 2:
%    Search and retrieve all documents of one type
%    Perform a more complicated query
% TEST_NUMBER == 3:
%    Search and retrieve all documents of one type
%    Perform a more complicated query
%    Perform a second more complicated query
% 
% 
% Example 1:
%    db = searchProfileTest();
%    profile on;
%    searchProfileTest(db,1);
%    profile off;
%    profile viewer;
%
% Example 2:
%    profile on;
%    searchProfileTest(db,2);
%    profile off;
%    profile viewer;
%
% Example 3:
%    profile on;
%    searchProfileTest(db,3);
%    profile off;
%    profile viewer;
%

if nargin<1
    % need to create database
    size = 1e4;
    [G,node_names,docs] = did.test.helper.documents.make_doc_tree(size*[1,1,1]);
    db_filename = [tempname '.sqlite'];
    db = did.implementations.sqlitedb(db_filename);
    db.add_branch('a');
    db.add_docs(docs, 'validate',false);
    return;
end

q1 = did.query('','isa','demoB');

hCleanup = db.open(); %#ok<NASGU>
demoBdocID = db.search(q1);
demoBdocs = db.get_docs(demoBdocID);

if test_number == 1
    return;
end

q2 = did.query('demoB.value','exact_number',demoBdocs(5).document_properties.demoB.value);

match_ids = db.search(q1&q2);
match_docs = db.get_docs(match_ids);

if test_number == 2
    return;
end

qC = did.query('','isa','demoC');
demoCdocID = db.search(qC);
demoCdocs = db.get_docs(demoCdocID);

q3 = did.query('','depends_on','*',demoBdocs(5).document_properties.base.id);

match_ids2 = db.search(q3);
match_docs2 = db.get_docs(match_ids2);
