function doc = test_did_file_document()
% TEST_DID_FILE_DOCUMENT - Test the functionality of the DID_DOCUMENT object file components
%
% [DOC,FILEPATH] = TEST_DID_FILE_DOCUMENT()
%
% Creates a demoFile-type did.document, and creates two 
% example files to be added to the database when it is
% added to the database with did.database.add_doc()
%

did.globals();
dirname = [did_globals.path.testpath filesep 'exampledb'];

example_session_id = '1234';

 % make example files, just fill them with 10 consecutive binary numbers

fname{1} = 'filename1.ext';
fname{2} = 'filename2.ext';

if ~isfolder(dirname),
	mkdir(dirname);
end;

doc = did.document('demoFile');

for i=1:numel(fname),
	fullfilename{i} = fullfile(dirname,fname{i});
	fid = fopen(fullfilename{i},'w','ieee-le');
	fwrite(fid,char((i-1)*10+[0:9]),'char');
	fclose(fid);

	doc = doc.add_file(fname{i},fullfilename{i});
end;

 % now add fake URLs

url_prefix = 'https://nosuchserver.com.notthere/';

for i=1:numel(fname),
	doc = doc.add_file(fname{i},[url_prefix fname{i}]);
end;


