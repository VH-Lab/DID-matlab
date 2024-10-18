% Class that defines some global constants for the DID package
%
% The following variables are defined:
% 
% Name:                          | Description
% -------------------------------------------------------------------------
%   path                         | The path of the DID distribution on this machine.
%   definitions                  | A containers.Map where the keys are placeholder 
%                                |   names for paths and the value 
%                                |   is the actual path location or url for the 
%                                |   corresponding placeholder name. The placeholder
%                                |   names are present in document definitions and 
%                                |   schemas and will be substituted with
%                                |   the actual paths 
%   documentschemapath. ...      | The path of the NDI document validation schema
%   preferences                  | A path to a directory of preferences files
%   filecachepath                | A path where files may be cached (not deleted every time)
%   temppath                     | The path to a directory that may be used for
%                                |   temporary files (Initialized by did_Init.m)
%   testpath                     | A path to a safe place to run test code

classdef PathConstants

    properties (Constant)
        % path - The path of the DID distribution on this machine.
        path = did.toolboxdir()
        defpath = fullfile(did.common.PathConstants.path, 'example_schema', 'demo_schema1')

        definitions = containers.Map(...
            {'$DIDDOCUMENT_EX1',  ...
            '$DIDSCHEMA_EX1', ...
            '$DIDCONTROLLEDVOCAB_EX1'}, ...
            {fullfile(did.common.PathConstants.defpath, 'database_documents'), ...
            fullfile(did.common.PathConstants.defpath, 'database_schema'), ...
            fullfile(did.common.PathConstants.defpath, 'controlled_vocabulary')},...
            'UniformValues',false);

        % temppath - The path to a directory that may be used for temporary files
        temppath {mustBeWritable} = fullfile(tempdir, 'didtemp')
        
        % filecachepath - A path where files may be cached (not deleted every time)
        filecachepath {mustBeWritable} = fullfile(userpath, 'Documents', 'DID', 'fileCache')
        
        % preferences - A path to a directory of preferences files
        preferences {mustBeWritable} = fullfile(userpath, 'Documents', 'DID', 'Preferences') % Todo: Use prefdir
    end
end

function mustBeWritable(folderPath)
    if ~isfolder(folderPath)
        try
            mkdir(folderPath)
        catch
            % See issue #29, R2022a)
            folderPath = strrep(folderPath, userpath, tempdir);
            mkdir(folderPath)
        end
    end

	didido = did.ido();
	fname = fullfile( folderPath, ['testfile_' didido.id() '.txt'] );
	fid = fopen(fname,'wt');
    if fid < 0
        throwWriteAccessDeniedError(folderPath)
    end
	fclose(fid);
	delete(fname);
end

function throwWriteAccessDeniedError(folderPath)
    [~, name] = fileparts(folderPath);
    error('DID:FolderNotWritable', ...
          'We do not have write access to the "%s" at %s', name, folderPath)
end