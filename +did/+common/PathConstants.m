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
            fullfile(did.common.PathConstants.defpath, 'controlled_vocabulary')} )

        % temppath - The path to a directory that may be used for temporary files
        temppath {mustBeWritable} = fullfile(tempdir, 'didtemp')
        
        % testpath - A path to a safe place to run test code
        testpath {mustBeWritable} = fullfile(userpath, 'Documents', 'DID', 'Testcode') % Todo: Use fixtures and test classes
        
        % filecachepath - A path where files may be cached (not deleted every time)
        filecachepath {mustBeWritable} = fullfile(userpath, 'Documents', 'DID', 'fileCache')
        
        % preferences - A path to a directory of preferences files
        preferences {mustBeWritable} = fullfile(userpath, 'Documents', 'DID', 'Preferences') % Todo: Use prefdir
    
        javapath = fullfile(did.common.PathConstants.path, 'java')    
    end
end

function mustBeWritable(folderPath)
    if ~isfolder(folderPath)
        mkdir(folderPath)
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