%function did_Init
% DID_INIT - initalize a global variable did_globals with default file paths

mydidpath = fileparts(which('did_Init'));

% remove any paths that have the string 'DID-matlab' so we don't have stale paths confusing anyone
pathsnow = path;
pathsnow_cell = split(pathsnow,pathsep);
matches = contains(pathsnow_cell, 'DID-matlab');
pathstoremove = char(strjoin(pathsnow_cell(matches),pathsep));
rmpath(pathstoremove);

% add everyelement except '.git' directories
pathstoadd = genpath(mydidpath);
pathstoadd_cell = split(pathstoadd,pathsep);
matches = (~contains(pathstoadd_cell,'.git'))&(~contains(pathstoadd_cell,'.did_globals'));
pathstoadd = char(strjoin(pathstoadd_cell(matches),pathsep));
addpath(pathstoadd);

did.globals;

% prepare paths
did_globals.path = [];

% Test writability of the user folder (issue #29, R2022a)
userFolder = fullfile(userpath,'Documents', 'DID');
testFilename = fullfile(userFolder,'test.txt');
fid = fopen(testFilename,'wt');
if fid < 0
    % userFolder is not writable - use temp folder instead
    userFolder = fullfile(tempdir,'DID');
else  % userFolder is writable
    fclose(fid);
    delete(testFilename);
end

did_globals.path.path = mydidpath;
did_globals.path.definition_names = {'$DIDDOCUMENT_EX1' '$DIDSCHEMA_EX1', '$DIDCONTROLLEDVOCAB_EX1'};
defsFolder = fullfile(did_globals.path.path,'example_schema','demo_schema1');
did_globals.path.definition_locations = {...
    fullfile(defsFolder,'database_documents') ...
    fullfile(defsFolder,'database_schema')...
    fullfile(defsFolder,'controlled_vocabulary')};
did_globals.path.temppath = fullfile(tempdir,'Temp');     %(tempdir,'didtemp');
did_globals.path.testpath = fullfile(userFolder,'Testcode'); %(tempdir,'didtestcode');
did_globals.path.filecachepath = fullfile(userFolder,'fileCache'); %DID file cache
did_globals.path.preferences   = fullfile(userFolder,'Preferences');
did_globals.path.javapath = fullfile(mydidpath,'java');

if ~exist(did_globals.path.temppath,'dir')
    mkdir(did_globals.path.temppath);
end

if ~exist(did_globals.path.testpath,'dir')
    mkdir(did_globals.path.testpath);
end

if ~exist(did_globals.path.filecachepath,'dir')
    mkdir(did_globals.path.filecachepath);
end

if ~exist(did_globals.path.preferences,'dir')
    mkdir(did_globals.path.preferences);
end

did_globals.fileCache = did.file.fileCache(did_globals.path.filecachepath,33);

did_globals.debug.verbose = 1;

% test write access to preferences, testpath, filecache, temppath
paths = {did_globals.path.testpath, did_globals.path.temppath, did_globals.path.filecachepath, did_globals.path.preferences};
pathnames = {'DID test path', 'DID temporary path', 'DID filecache path', 'DID preferences path'};

for i=1:numel(paths)
    fname = [paths{i},'testfile_' did.ido.unique_id() '.txt'];
    fid = fopen(fname,'wt');
    if fid < 0
        error(['We do not have write access to the ' pathnames{i} ' at '  paths{i} '.']);
    end
    fclose(fid);
    delete(fname);
end
