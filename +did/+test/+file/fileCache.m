function b = fileCache()
% FILECACHE - test the fileCache object
%
% B = FILECACHE()
%
% Test the fileCache object
%

b = 0; 

did.globals;
dirname = [did_globals.path.temppath filesep 'file-cache-test'];

if ~isfolder(dirname),
	mkdir(dirname);
end;

obj = did.file.fileCache(dirname);

p = obj.getProperties(),

b = 1;
