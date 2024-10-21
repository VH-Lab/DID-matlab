function doc_ids = test_did_sqlitedb(dirname)
% TEST_DID_SQLITEDB - Test the functionality of DID_DATABASE SQLite database
%
%  DOC_IDS = TEST_DID_SQLITEDB(DIRNAME)
%
%  This test function tries to create a DID_DOCUMENT object and store it in a
%  DID_DATABASE of type SQLite in the specified DIRNAME folder. 
%
%  If DIRNAME is not provided, [did.common.PathConstants.testpath] is used. 
%  If the resulting DIRNAME is invalid, DIRNAME is set to the %TEMPDIR% folder.
%
%  Upon completion, the test function removes the database file from DIRNAME and
%  returns the doc_ids created during the test.
%

    if nargin < 1
        try dirname = did.common.PathConstants.testpath; catch, dirname = tempdir; end
    end
    if ~isfolder(dirname), dirname = tempdir; end
    db_filename = fullfile(dirname, 'test.sqlite');

    disp(['Creating a new temp database file: ' db_filename]);
    remove_old = 1;
    oldWarn = warning;
    h = onCleanup(@() warning(oldWarn));
    mksqlite('close');  % ensure that the database file can be deleted
    if remove_old
        % remove any old versions
        %{
        doc = db.search(did.query('base.name','exact_string','mytestdocument',''));
        if ~isempty(doc)
            for i=1:numel(doc)
                db.remove(doc{i}.id());
            end
        end
        %}
        warning('off','MATLAB:DELETE:FileNotFound');
        warning('off','MATLAB:DELETE:Permission');
        delete(db_filename)
    end
    db = did.implementations.sqlitedb(db_filename)
    %try winopen(db_filename); catch, end  % for debugging

    disp('Creating a few new documents of type did_document_app')
    d1 = did.document('did_document_app', 'data.str','abc123', 'data.num',-pi);
    d2 = did.document('did_document_app', 'data.str','xyz123', 'data.num',+pi);
    d3 = did.document('did_document_app', 'data.str','abcxyz', 'data.num',0);

    disp('Adding the documents to the database');
    db.add(d1);  id1 = d1.document_properties.base.id;
    db.add(d2);  id2 = d2.document_properties.base.id;
    db.add(d3);  id3 = d3.document_properties.base.id;

    % now do some searching
    disp('Now searching for documents')

    q1 = did.query('data.str','exact_string','abc123');
    q2 = did.query('data.str','contains_string','123');
    q3 = did.query('data.str','regexp','abc');
    q4 = did.query('data.num','greaterThanEq',0);
    r1  =db.search(q1),    assert(isequal(r1,{id1}),           'Bad results for db query #1');
    r2  =db.search(q2),    assert(isequal(r2,{id1;id2}),       'Bad results for db query #2');
    r3  =db.search(q3),    assert(isequal(r3,{id1;id3}),       'Bad results for db query #3');
    r4  =db.search(q4),    assert(isequal(r4,{id2;id3}),       'Bad results for db query #4');
    rOr =db.search(q3|q4), assert(isequal(rOr,{id1;id2;id3}),  'Bad results for db query #3 | 4');
    rAnd=db.search(q3&q4), assert(isequal(rAnd,{id3}),         'Bad results for db query #3 & 4');
    rAll=db.search(q1|(q3&q4)), assert(isequal(rAll,{id1;id3}),'Bad results for db query #1|(3&4)');

    % remove docs from the DB
    doc_ids = db.search(did.query({'base.name',''}));
    assert(isequal(doc_ids,{id1;id2;id3}),'Bad results for db query to fetch all doc IDs');
    if ~isempty(doc_ids)
        for i = 1 : numel(doc_ids)
            db.remove(doc_ids{i});
        end
    end
    doc_ids2 = db.search(did.query({'base.name',''}));
    assert(isempty(doc_ids2),'Unsuccessful removal of all docs from the database');

    % all done - delete the temporary DB
    delete(db_filename)

    disp('All seams to be ok!')

    if ~nargout, clear doc_ids, end
