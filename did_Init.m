function did_Init
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
matches=(~contains(pathstoadd_cell,'.git'))&(~contains(pathstoadd_cell,'.did_globals'));
pathstoadd = char(strjoin(pathstoadd_cell(matches),pathsep));
addpath(pathstoadd);

did.globals;

 % paths

did_globals.path = [];

did_globals.path.path = mydidpath;
did_globals.path.definition_names = {'$DIDDOCUMENT_EX1' '$DIDSCHEMA_EX1', '$DIDCONTROLLEDVOCAB_EX1'};
did_globals.path.definition_locations = ...
	{  [did_globals.path.path filesep 'example_schema' filesep 'demo_schema1' filesep 'database_documents'] ...
	   [did_globals.path.path filesep 'example_schema' filesep 'demo_schema1' filesep 'database_schema']...
       [did_globals.path.path filesep 'example_schema' filesep 'demo_schema1' filesep 'controlled_vocabulary']};
did_globals.path.temppath = [tempdir filesep 'didtemp'];
did_globals.path.testpath = [tempdir filesep 'didtestcode'];
did_globals.path.filecachepath = [userpath filesep 'Documents' filesep 'DID' filesep 'DID-filecache'];
did_globals.path.preferences = [userpath filesep 'Preferences' filesep' 'DID'];
did_globals.path.javapath = [mydidpath filesep 'java']

if ~exist(did_globals.path.temppath,'dir'),
        mkdir(did_globals.path.temppath);
end;

if ~exist(did_globals.path.testpath,'dir'),
        mkdir(did_globals.path.testpath);
end;

if ~exist(did_globals.path.filecachepath,'dir'),
        mkdir(did_globals.path.filecachepath);
end;

if ~exist(did_globals.path.preferences,'dir'),
        mkdir(did_globals.path.preferences);
end;


did_globals.debug.verbose = 1;

 % test write access to preferences, testpath, filecache, temppath
paths = {did_globals.path.testpath, did_globals.path.temppath, did_globals.path.filecachepath, did_globals.path.preferences};
pathnames = {'DID test path', 'DID temporary path', 'DID filecache path', 'DID preferences path'};

for i=1:numel(paths),
        fname = [paths{i} filesep 'testfile_' did.ido.unique_id() '.txt'];
        fid = fopen(fname,'wt');
        if fid<0,
                error(['We do not have write access to the ' pathnames{i} ' at '  paths{i} '.']);
        end;
        fclose(fid);
        delete(fname);
end;

