function [b,msg] = file_document()
% did.test.file_document - Test the functionality of the did.document and did.database object file components
%
% [B,MSG] = did.test.file_document()
%
% Creates a demoFile-type did.document, and creates two 
% example files to be added to the database when it is
% added to the database with did.database.add_docs()
% 
% The files are then read from the database and the contents
% checked.
%
% B is 1 if the test succeeds, and 0 otherwise.
% MSG has an error message if the test fails.

b = 1;
msg = '';

did.globals();
dirname = [did.common.PathConstants.testpath filesep 'exampledb'];

db_filename = fullfile(dirname,'filetestdb.sqlite');

if ~isfolder(dirname),
	mkdir(dirname);
end;

if isfile(db_filename),
	delete(db_filename);
end;

db = did.implementations.sqlitedb(db_filename);
db.add_branch('a');

 % make example files, just fill them with 10 consecutive binary numbers

fname{1} = 'filename1.ext';
fname{2} = 'filename2.ext';

if ~isfolder(dirname),
	mkdir(dirname);
end;

doc = did.document('demoFile','demoFile.value',1);

for i=1:numel(fname),
	fullfilename{i} = fullfile(dirname,fname{i});
	fid = fopen(fullfilename{i},'w','ieee-le');
	if fid<0,
		b = 0;
		msg = ['Could not open file ' fullfilename{i} ' for writing.'];
	end;
	fwrite(fid,char((i-1)*10+[0:9]),'char');
	fclose(fid);

	doc = doc.add_file(fname{i},fullfilename{i});
end;

 % now add fake URLs

url_prefix = 'https://nosuchserver.com.notthere/';

for i=1:numel(fname),
	doc = doc.add_file(fname{i},[url_prefix fname{i}]);
end;

db.add_docs(doc);

 % now delete the original files

for i=1:numel(fname),
	if isfile(fullfilename{i}),
		delete(fullfilename{i});
	end;
end;

g = db.search(did.query('','isa','demoFile',''));
doc_g = db.get_docs(g);

data = {};

for i=1:numel(fname),
	f = db.open_doc(g{1}, fname{i});
	fopen(f);
	if f.fid<0,
		b = 0;
		msg = ['Could not open document file ' fname{i} '.'];
		return;
	end;
	data{i} = fread(f,Inf,'char');
	fclose(f);
	if ~did.datastructures.eqlen(data{i},(i-1)*10+[0:9]'),
		b = 0;
		msg = ['Data for file ' fname{i} ' did not match.'];
		return;
	end;
end;

