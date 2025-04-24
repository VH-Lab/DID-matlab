% DID_INIT - Update DID-MATLAB on search path

mydidpath = fileparts(which('did_Init'));

% remove any paths that have the string 'DID-matlab' so we don't have stale paths confusing anyone
pathsnow = path;
pathsnow_cell = split(pathsnow,pathsep);
matches = contains(pathsnow_cell, 'DID-matlab');
pathstoremove = char(strjoin(pathsnow_cell(matches),pathsep));
rmpath(pathstoremove);

% Add the code subdirectory to MATLAB's search path
pathstoadd = addpath(genpath(fullfile(mydidpath, 'code')));
