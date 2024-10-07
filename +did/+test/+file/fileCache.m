function b = fileCache()
% FILECACHE - test the fileCache object
%
% B = FILECACHE()
%
% Test the fileCache object
%

b = 0; 

did.globals;
dirname = [did.common.PathConstants.temppath filesep 'file-cache-test'];

if ~isfolder(dirname),
	mkdir(dirname);
end;

obj = did.file.fileCache(dirname,33,1000,800); % tiny cache for testing

obj.clear();

p = obj.getProperties();


tempdir =  [did.common.PathConstants.temppath filesep 'file-cache-test-base'];

if ~isfolder(tempdir),
	mkdir(tempdir);
end;

 % make fake files

files = {};

for i=1:100,
	fname = ['f' sprintf('%0.3d',i) '0' repmat('_',1,32-4)];
	files{i} = fname;
	fullfiles{i} = fullfile(tempdir,files{i});
	fid = fopen(fullfiles{i},'w','ieee-le');
	fwrite(fid,[i*100+[0:99]],'uint16');
	fclose(fid);
end;

 % now insert the files

for i=1:6,
	obj.addFile(fullfiles{i},'copy',true);
end;

[fn,sz,la] = obj.fileList(false);
p = obj.getProperties()

disp(['Total size from files is ' int2str(sum(sz)) '.']); 

disp('Manifest:');

fn'

 % now touch file 3, and add 3 more files

obj.touch(files{3});
for i=27:30,
	obj.addFile(fullfiles{i},'copy',true);
	obj.touch(files{3});
end;

 % reprint manifest

[fn,sz,la] = obj.fileList(false);
p = obj.getProperties()

disp(['Total size from files is ' int2str(sum(sz)) '.']); 

disp('Manifest:');

fn'

 % now delete file 3

obj.removeFile(files{30})

 % reprint manifest

[fn,sz,la] = obj.fileList(false);
p = obj.getProperties()

disp(['Total size from files is ' int2str(sum(sz)) '.']); 

disp('Manifest:');

fn'

disp(['Is f0100 a file?']);
obj.isFile(files{10}),
disp(['Is nonsense a file?']);
obj.isFile('adslkjfksldjfkljsdf'),


 % now, add a file at the head
disp('Adding file earlier in alphabet')

obj.touch(files{3});
obj.addFile(fullfiles{1},'copy',true);
obj.touch(files{3});

 % reprint manifest

[fn,sz,la] = obj.fileList(false);
p = obj.getProperties()

disp(['Total size from files is ' int2str(sum(sz)) '.']); 

disp('Manifest:');

fn'

disp('Adding file in middle of in alphabet')

obj.addFile(fullfiles{4},'copy',true);

 % reprint manifest

[fn,sz,la] = obj.fileList(false);
p = obj.getProperties()

disp(['Total size from files is ' int2str(sum(sz)) '.']); 

disp('Manifest:');

fn'



b = 1;

