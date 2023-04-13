function doc = test_did_document(dirname)
% TEST_DID_DOCUMENT - Test the functionality of the DID_DOCUMENT object and the DID_DATABASE database
%
%  DOC = TEST_DID_DOCUMENT([DIRNAME])
%
%  Given a directory, this function tries to create a
%  DID_DOCUMENT object and stores it in a DID_DATABASE. The test function
%  removes them on completion.
%
%  If DIRNAME is not provided, the default directory
%  [did_globals.path.testpath] is used.
%
%  See also: did.globals

did.globals;

remove_old = 1;
write_binary_file = 0;

if nargin<1,
	dirname = [did_globals.path.testpath filesep 'exampledb'];
end;

example_session_id = '1234';

disp(['Creating a new database in directory ' dirname '.']);
db = did.implementations.matlabdumbjsondb('new',[dirname filesep 'did.dumbjsondb.json']);

if remove_old,
  % remove any old versions
	doc = db.search(did.query('base.name','exact_string','mytestdocument',''));
	if ~isempty(doc),
		for i=1:numel(doc),
			db.remove(doc{i}.id());
		end;
	end;
end;

disp(['Creating a new document of type did_document_app'])

doc = did.document('did_document_app','app.name','mytestname','base.name','mytestdocument');

disp(['These are the doc.document_properties:'])
doc.document_properties,

disp(['Adding the document to the database']);

db.add(doc);

if write_binary_file,
	  % store some data in the binary portion of the file
	binarydoc = E.database_openbinarydoc(doc);
	disp(['Storing ' mat2str(0:9) '...'])
	binarydoc.fwrite(char([0:9]),'char');
	binarydoc = E.database_closebinarydoc(binarydoc);
end;

 % now do some searching

disp(['Now searching for the document'])
doc = db.search(did.query({'base.name','mytestdocument'}))
if numel(doc)~=1,
	error(['Found <1 or >1 document with base.name ''mytestdocument''; this means there is a database problem.']);
end;
doc = doc{1}, % should be only one match

disp(['Now searching for the document'])
doc = db.search(did.query('','isa','did_document_app.json',''));
if numel(doc)~=1,
	error(['Found <1 or >1 document with base.name ''mytestdocument''; this means there is a database problem.']);
end;
doc = doc{1}, % should be only one match

if write_binary_file,
	 % read the binary data
	binarydoc = E.database_openbinarydoc(doc);
	disp('About to read stored data: ');
	data = double(binarydoc.fread(10,'char'))',
	binarydoc = E.database_closebinarydoc(binarydoc);
end;

% remove the document

doc = db.search(did.query({'base.name','mytestdocument'}));
if ~isempty(doc),
	for i=1:numel(doc),
		db.remove(doc{i}.id());
	end;
end;

 % return the first document structure

doc = doc{1}; 
