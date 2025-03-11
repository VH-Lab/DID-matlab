classdef sqlitedb < did.database %#ok<*TNOW1>
    % did.implementations.sqlitedb - An implementation of an SQLite database for DID
    %
    % See also: did.database, did.implementations.dumbjasondb, did.implementations.postgresdb

    properties
        FileDir % full path to directory where files are stored
    end

    properties (Access=protected)
        fields_cache = cell(0,2)
    end

    methods % constructor
        function sqlitedb_obj = sqlitedb(filename)
            % sqlitedb create a new did.implementations.sqlitedb object
            %
            % sqlitedb_obj = sqlitedb(filename)
            %
            % Creates a new sqlitedb object with optional FILENAME.
            % If FILENAME parameter is specified, the specified file is opened;
            % otherwise the user is prompted to select a *.sqlite file.
            % In FILENAME exists, the database validity as a DID DB is checked.
            % If FILENAME does not exist, it is created as empty DID SQLite DB.

            % Ensure that mksqlite package is installed
            if isempty(which('mksqlite'))
                url = 'https://github.com/a-ma72/mksqlite';
                if ~isdeployed, url = ['<a href="' url '">' url '</a>']; end
                msg = ['The mksqlite package is not detected on the Matlab path - '   newline ...
                    'please install it before using did.implementations.sqlitedb.' newline ...
                    'Download mksqlite from ' url ' and then run buildit.m'];
                error('DID:SQLITEDB:NO_MKSQLITE',msg);
            end

            % If filename was not specified, request it from the user
            if nargin < 1
                [filename, folder] = uiputfile({'*.sqlite','SQLite DB files (*.sqlite)'}, 'Select data file');
                drawnow; pause(0.01);  % avoid Matlab hang
                if isempty(filename) || ~ischar(folder) %user bail-out
                    error('DID:SQLITEDB:NO_FILE','No file selected')
                end
                filename = fullfile(folder,filename);
            end

            % Set the filename in the object's connection property
            sqlitedb_obj.connection = filename;

            % Open/create the database (croaks in case of error)
            sqlitedb_obj.open_db();

            % Update the database version
            sqlitedb_obj.version = [];
            try sqlitedb_obj.version.mksqlite = mksqlite('version mex'); catch, end
            try sqlitedb_obj.version.sqlite   = mksqlite('version sql'); catch, end

            % Set some default database preferences
            cacheDir_parent = fileparts(filename);
            cacheDir = fullfile(cacheDir_parent, 'files');
            if ~isfolder(cacheDir)
                mkdir(cacheDir);
            end
            %sqlitedb_obj.set_preference('remote_folder',  fileparts(which(filename)));
            sqlitedb_obj.set_preference('cache_folder',    cacheDir);
            sqlitedb_obj.set_preference('cache_duration',  1.0); %[days]
            sqlitedb_obj.set_preference('cache_max_files', inf);
            sqlitedb_obj.FileDir = cacheDir;
        end % sqlitedb()
    end

    methods % destructor
        function delete(this_obj)
            % DELETE - destructor function. Closes the database connection/file.
            this_obj.close_db();
        end  % delete()
    end

    % Implementations of abstract methods defined in did.database
    methods (Access=protected)
        function data = do_run_sql_query(this_obj, query_str, varargin)
            % do_run_sql_query - run a single SQL query on the database
            %
            % data = do_run_sql_query(this_obj, query_str)
            %
            % Inputs:
            %    this_obj  - this class object
            %    query_str - the SQL query string. For example:
            %                'SELECT docs.doc_id FROM docs, doc_data, fields
            %                 WHERE docs.doc_idx = doc_data.doc_idx
            %                   AND fields.field_idx = doc_data.field_idx
            %                   AND fields.field_idx = doc_data.field_idx
            %                   AND ((fields.field_name = "meta.class" AND
            %                         doc_data.value = "ndi_documentx") OR
            %                        (fields.field_name = "meta.superclass" AND
            %                         doc_data.value like "%ndi_documentx%"))'

            % Open the database for query
            if isempty(this_obj.dbid)
                hCleanup = this_obj.open_db(); %#ok<NASGU>
            end

            % Run the SQL query in the database
            data = this_obj.run_sql_noOpen(query_str);

            % Close the DB file - this happens automatically when hCleanup is
            % disposed when this method returns, using the onCleanup mechanism
        end % do_run_sql_query()

        function branch_ids = do_get_branch_ids(this_obj)
            % do_get_branch_ids - return all unique branch ids in the database
            %
            % branch_ids = do_get_branch_ids(this_obj)
            %
            % Return all unique branch ids as a cell array of strings.
            % If no branches are defined, an empty cell array is returned.

            % Run the SQL query in the database
            data = this_obj.run_sql_query('SELECT DISTINCT branch_id FROM branches');

            % Parse the results
            if isempty(data)
                branch_ids = {};
            else
                branch_ids = data{1};
                if ~iscell(branch_ids)
                    branch_ids = {branch_ids};
                end
            end
        end % do_get_branch_ids()

        function do_add_branch(this_obj, branch_id, parent_branch_id, varargin)
            % do_add_branch - Adds a new database branch based on specified parent branch
            %
            % do_add_branch(this_obj, branch_id, parent_branch_id)
            %
            % Adds a new branch with the specified BRANCH_ID to the database,
            % based on (duplicating) the specified PARENT_BRANCH_ID.
            %
            % An error is generated if PARENT_BRANCH_ID does not exist in the
            % database, or if BRANCH_ID already exists in the database, or if
            % the specified BRANCH_ID is empty or not a string.

            % Add the new branch to the branches table (no docs yet)
            tnow = now;
            hCleanup = this_obj.open_db(); %#ok<NASGU>
            this_obj.insert_into_table('branches', 'branch_id,parent_id,timestamp', branch_id, parent_branch_id, tnow);

            % Duplicate the docs from parent branch to the newly-created branch
            sqlStr = ['SELECT doc_idx FROM branch_docs WHERE branch_id="' parent_branch_id '"'];
            data = this_obj.run_sql_noOpen(sqlStr);
            if ~isempty(data)
                doc_idx = [data.doc_idx];
                for i = 1 : numel(doc_idx)
                    this_obj.insert_into_table('branch_docs','branch_id,doc_idx,timestamp',branch_id,doc_idx(i),tnow);
                end
            end
        end % do_add_branch()

        function do_delete_branch(this_obj, branch_id, varargin)
            % do_delete_branch - Deletes the specified parent branch from the DB
            %
            % do_delete_branch(this_obj, branch_id
            %
            % Deletes the branch with the specified BRANCH_ID from the database.
            % An error is generated if BRANCH_ID is not a valid branch ID.

            % First remove all documents from the branch
            doc_ids = this_obj.do_get_doc_ids(branch_id); %this croaks if branch_id is invalid - good!
            if ~isempty(doc_ids)
                % Remove all documents from the branch_docs table
                % TODO: also delete records of unreferenced docs ???
                this_obj.run_sql_query(['DELETE FROM branch_docs WHERE branch_id="' branch_id '"']);
            end

            % Now delete the branch record
            this_obj.run_sql_query(['DELETE FROM branches WHERE branch_id="' branch_id '"']);
        end % do_delete_branch()

        function parent_branch_id = do_get_branch_parent(this_obj, branch_id, varargin)
            % do_get_branch_parent - Return the id of the specified branch's parent branch
            %
            % parent_branch_id = do_get_branch_parent(this_obj, branch_id)
            %
            % Returns the ID of the parent branch for the specified BRANCH_ID.

            sqlStr = ['SELECT parent_id FROM branches WHERE branch_id="' branch_id '"'];
            data = this_obj.run_sql_query(sqlStr);
            if isempty(data)
                parent_branch_id = '';
            else
                parent_branch_id = data{1};
                if iscell(parent_branch_id)
                    if isempty(parent_branch_id)
                        parent_branch_id = '';
                    elseif numel(parent_branch_id) == 1
                        parent_branch_id = char(parent_branch_id{1}); % [] => ''
                    else
                        % multiple values - leave as cell array (maybe error?)
                        warning('DID:SQLITEDB:Multiple_Parents','Multiple branch parents found for the %s branch',branch_id);
                    end
                elseif ~ischar(parent_branch_id)
                    parent_branch_id = char(parent_branch_id); % [] => ''
                end
            end
        end % do_get_branch_parent()

        function branch_ids = do_get_sub_branches(this_obj, branch_id, varargin)
            % do_get_sub_branches - Return the ids of the specified branch's child branches (if any)
            %
            % branch_ids = do_get_sub_branches(this_obj, branch_id)
            %
            % Returns a cell array of IDs of sub-branches of the specified BRANCH_ID.
            % If BRANCH_ID has no sub-branches, an empty cell array is returned.

            sqlStr = ['SELECT branch_id FROM branches WHERE parent_id="' branch_id '"'];
            data = this_obj.run_sql_query(sqlStr);
            if isempty(data)
                branch_ids = {};
            else
                branch_ids = data{1};
            end
        end % do_get_sub_branches()

        function doc_ids = do_get_doc_ids(this_obj, branch_id, varargin)
            % do_get_doc_ids - Return the ids of the specified branch's child branches (if any)
            %
            % doc_ids = do_get_doc_ids(this_obj, branch_id)
            %
            % Returns a cell array of document IDs contained in the specified BRANCH_ID.
            % If BRANCH_ID has no documents, an empty cell array is returned.
            % If BRANCH_ID  is empty or not specified, all IDs in all branches are
            % returned.

            if nargin > 1 && ~isempty(branch_id)
                sqlStr = ['SELECT docs.doc_id FROM docs,branch_docs' ...
                    ' WHERE docs.doc_idx = branch_docs.doc_idx' ...
                    '   AND branch_id="' branch_id '"'];
            else
                sqlStr = 'SELECT docs.doc_id FROM docs';
            end
            data = this_obj.run_sql_query(sqlStr);
            if isempty(data)
                doc_ids = {};
            else
                doc_ids = data{1};
            end
        end % do_get_doc_ids()

        function do_add_doc(this_obj, document_obj, branch_id, varargin)
            % do_add_doc - Add a DID document to a specified branch in the DB
            %
            % do_add_doc(this_obj, document_obj, branch_id, [params])
            %
            % Adds the specified DID.DOCUMENT object to the specified BRANCH_ID.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnDuplicate' - followed by 'ignore', 'warn', or 'error' (default)

            % Open the database for update
            hCleanup = this_obj.open_db(); %#ok<NASGU>

            % Get the document id
            meta_data = did.implementations.doc2sql(document_obj);
            meta_data_struct = cell2struct({meta_data.columns}',{meta_data.name}');
            doc_id = meta_data_struct.meta(1).value;

            % If the document was not already defined (for any branch)
            doc_props = document_obj.document_properties;
            data = this_obj.run_sql_noOpen('SELECT doc_idx FROM docs WHERE doc_id=?', doc_id);
            if isempty(data)
                % Get the JSON code that parses all the document's properties
                json_code = did.datastructures.jsonencodenan(doc_props);

                % Add the new document to docs table
                this_obj.insert_into_table('docs', 'doc_id,json_code,timestamp', doc_id, json_code, now); %, document_obj);

                % Re-fetch the new document record's idx
                data = this_obj.run_sql_noOpen('SELECT doc_idx FROM docs WHERE doc_id=?', doc_id);
                doc_idx = data(1).doc_idx;

                % Add the document fields to doc_data table (possibly also fields entries)
                %this_obj.insert_doc_data_field(doc_idx,'app','name',filename);
                field_groups = fieldnames(meta_data_struct);
                doc_data_vals = {};
                num_rows = 0;
                for groupIdx = 1 : numel(field_groups)
                    group_name = field_groups{groupIdx};
                    group_data = meta_data_struct.(group_name);
                    for fieldIdx = 1 : numel(group_data)
                        field_data = group_data(fieldIdx);
                        field_name  = field_data.name;
                        if strcmpi(field_name,'doc_id'), continue, end
                        field_value = field_data.value;
                        %this_obj.insert_doc_data_field(doc_idx, group_name, field_name, field_value);
                        field_idx = this_obj.get_field_idx(group_name, field_name);
                        doc_data_vals(end+1:end+3) = {doc_idx, field_idx, field_value};
                        num_rows = num_rows + 1;
                    end
                end
                % Insert multiple new row records to the doc_data table, en-bulk
                if num_rows > 0
                    this_obj.insert_into_table('doc_data', 'doc_idx,field_idx,value', doc_data_vals{:});
                end
            else
                doc_idx = data(1).doc_idx;
            end

            % Handle case of the branch already containing this document
            data = this_obj.run_sql_noOpen(['SELECT doc_idx FROM branch_docs ' ...
                                            ' WHERE doc_idx=? AND branch_id=?'], ...
                                            doc_idx, branch_id);
            if ~isempty(data)
                errMsg = sprintf('Document %s already exists in the %s branch', doc_id, branch_id);
                %assert(isempty(data),'DID:SQLITEDB:DUPLICATE_DOC','%s',errMsg)
                params = this_obj.parseOptionalParams(varargin{:});
                try doOnDuplicate = params.OnDuplicate; catch, doOnDuplicate = 'error'; end
                doOnDuplicate = lower(doOnDuplicate(doOnDuplicate~=' '));
                switch doOnDuplicate
                    case 'ignore'
                        % do nothing
                    case 'warn'
                        warning('DID:SQLITEDB:DUPLICATE_DOC','%s',errMsg);
                    otherwise %case 'error'
                        error('DID:SQLITEDB:DUPLICATE_DOC','%s',errMsg);
                end
            end

            % Add the document reference to the branch_docs table
            this_obj.insert_into_table('branch_docs', 'branch_id,doc_idx,timestamp', branch_id, doc_idx, now);

            % Check if the doc refers to any local files that should be cached
            numCachedFiles = 0;
            try files = doc_props.files.file_info; catch, files = []; end
            for idx = 1 : numel(files)
                try
                    % Loop over all files defined within the doc
                    filename = sprintf('#%d',idx); %used in catch, if the line below fails
                    filename = char(files(idx).name);
                    locations = files(idx).locations;
                    for locIdx = 1 : numel(locations)
                        % Cache this file locally, if specified
                        thisLocation = locations(locIdx);
                        sourcePath = thisLocation.location;
                        if thisLocation.ingest
                            % destDir = this_obj.get_preference('cache_folder');
                            destDir = this_obj.FileDir;
                            destPath = fullfile(destDir, thisLocation.uid);
                            try
                                file_type = lower(strtrim(thisLocation.location_type));
                                if strcmpi(file_type, 'file')
                                    [status,errMsg] = copyfile(sourcePath, destPath, 'f');
                                else  % url
                                    websave(destPath, sourcePath);
                                    status = isfile(destPath);
                                end
                            catch err
                                status = false;
                                errMsg = err.message;
                            end
                            if ~status
                                warning('DID:SQLiteDB:add_doc','Failed to cache "%s" %s referenced in document object: %s',filename,file_type,errMsg);
                                destPath = '';
                            else
                                if thisLocation.delete_original
                                    delete(sourcePath);
                                end
                                %this_obj.insert_doc_data_field(doc_idx, 'files', 'cached_file_path', destPath);
                                numCachedFiles = numCachedFiles + 1;
                            end
                        else
                            destPath = '';
                        end

                        % Store file information in the database (files tables)
                        fieldNames = 'doc_idx, filename, uid, orig_location, cached_location, type, parameters';
                        this_obj.insert_into_table('files',fieldNames, ...
                            doc_idx, filename, thisLocation.uid, ...
                            sourcePath, destPath, ...
                            thisLocation.location_type, ...
                            thisLocation.parameters);
                        if 0, disp(['Inserted ' filename ' with absolute location ' destPath ' and ID ' thisLocation.uid]); end %#ok<UNRCH> % debugging
                    end
                catch
                    warning('DID:SQLiteDB:add_doc','Bad definition of referenced file %s in document object',filename);
                end
            end
            %{
            if numCachedFiles > 1
                warning('DID:SQLiteDB:add_doc','Multiple files specified for caching in document object');
            end
            %}
        end % do_add_doc()

        function document_obj = do_get_doc(this_obj, document_id, varargin)
            % do_get_doc - Return a DID.DOCUMENT for the specified document ID
            %
            % document_obj = do_get_doc(this_obj, document_id, [params])
            %
            % Returns the DID.DOCUMENT object with the specified by DOCUMENT_ID.
            % DOCUMENT_ID must be a scalar ID string, not an array of IDs.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnMissing' - followed by 'ignore', 'warn', or 'error' (default)
            %
            % Inputs:
            %    this_obj - this class object
            %    document_id - unique document ID for the requested document
            %    params - optional parameters: 'OnMissing','ignore'/'warn'/'error'
            %
            % Outputs:
            %    document_obj - a did.document object (possibly empty)

            %[doc, version] = this_obj.db.read(document_id);
            %document_obj = did.document(doc);

            % Run the SQL query in the database
            query_str = ['SELECT json_code FROM docs WHERE doc_id="' document_id '"'];
            data = this_obj.run_sql_query(query_str);

            % Process missing document results
            if isempty(data)
                % Handle case of missing document
                params = this_obj.parseOptionalParams(varargin{:});
                try doOnMissing = params.OnMissing; catch, doOnMissing = 'error'; end
                errMsg = sprintf('Document id "%s" was not found in the database',document_id);
                %assert(~isempty(data),'DID:SQLITEDB:NO_SUCH_DOC','%s',errMsg)
                doOnMissing = lower(doOnMissing(doOnMissing~=' '));
                switch doOnMissing
                    case 'ignore'
                        document_obj = did.document.empty; %return empty document
                        return
                    case 'warn'
                        warning('DID:SQLITEDB:NO_SUCH_DOC','%s',errMsg);
                        return
                    otherwise %case 'error'
                        error('DID:SQLITEDB:DOC_ID','%s',errMsg);
                end
            end

            % Document found: return a did.document object of the decoded JSON code
            json_code = data{1};
            if iscell(json_code), json_code = json_code{1}; end
            doc_struct = jsondecode(json_code);
            document_obj = did.document(doc_struct);
        end % do_get_doc()

        function do_remove_doc(this_obj, document_id, branch_id, varargin)
            % do_remove_doc - Remove specified DID document from the specified branch
            %
            % do_remove_doc(this_obj, document_id, branch_id, [params])
            %
            % Returns the DID.DOCUMENT object with the specified by DOCUMENT_ID.
            % DOCUMENT_ID must be a scalar ID string, not an array of IDs.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnMissing' - followed by 'ignore', 'warn', or 'error' (default)
            %
            % Inputs:
            %    this_obj - this class object
            %    document_id - unique document ID for the requested document
            %    params - optional parameters: 'OnMissing','ignore'/'warn'/'error'
            %
            % Outputs:
            %    document_obj - a did.document object (possibly empty)

            % Open the database for update
            hCleanup = this_obj.open_db(); %#ok<NASGU>

            % Get the document id (ensure that we have a string if doc object was specified)
            if ~ischar(document_id)
                meta_data = did.implementations.doc2sql(document_id);
                meta_data_struct = cell2struct({meta_data.columns}',{meta_data.name}');
                document_id = meta_data_struct.meta(1).value;
            end
            doc_id = document_id;

            % Handle case of missing document
            sqlStr = ['SELECT docs.doc_idx FROM docs,branch_docs ' ...
                ' WHERE docs.doc_idx = branch_docs.doc_idx ' ...
                '   AND branch_id="' branch_id '"' ...
                '   AND doc_id="' doc_id '"'];
            %doc_id = [doc_id '/' branch_id];
            data = this_obj.run_sql_noOpen(sqlStr);
            if isempty(data)
                errMsg = sprintf('Cannot remove document %s - document not found in the %s branch', doc_id, branch_id);
                %assert(~isempty(data),'DID:SQLITEDB:NO_SUCH_DOC','%s',errMsg)
                params = this_obj.parseOptionalParams(varargin{:});
                try doOnMissing = params.OnMissing; catch, doOnMissing = 'error'; end
                doOnMissing = lower(doOnMissing(doOnMissing~=' '));
                switch doOnMissing
                    case 'ignore'
                        return
                    case 'warn'
                        warning('DID:SQLITEDB:NO_SUCH_DOC','%s',errMsg);
                        return
                    otherwise %case 'error'
                        error('DID:SQLITEDB:NO_SUCH_DOC','%s',errMsg);
                end
            end
            doc_idx = data(1).doc_idx;

            % Remove the document from the branch_docs table
            this_obj.run_sql_noOpen(['DELETE FROM branch_docs WHERE branch_id="' branch_id '" AND doc_idx=?'], doc_idx);

            % TODO - remove all document records if no branch references remain?
            %{
            % If no more branches reference this document
            remaining_ids = this_obj.run_sql_noOpen('SELECT branch_id FROM branch_docs WHERE doc_idx=?', doc_idx));
            if isempty(remaining_ids)
                % Remove all document records from docs, doc_data tables
                this_obj.run_sql_noOpen('DELETE FROM docs     WHERE doc_idx=?', doc_idx)
                this_obj.run_sql_noOpen('DELETE FROM doc_data WHERE doc_idx=?', doc_idx)
            end
            %}
        end % do_remove_doc()

        function file_obj = do_open_doc(this_obj, document_id, filename, varargin)
            % do_open_doc - Return a did.file.readonly_fileobj for the specified document ID
            %
            % file_obj = do_open_doc(this_obj, document_id, [filename], [params])
            %
            % Return a DID.FILE.READONLY_FILEOBJ object for a data file within
            % the specified DOCUMENT_ID. The requested filename must be
            % specified using the (mandatory) FILENAME parameter.
            %
            % DOCUMENT_ID must be a scalar ID string, not an array of IDs.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value, as accepted by the DID.FILE.FILEOBJ
            % constructor method.
            %
            % Only the first matching file that is found is returned.
            %
            % Inputs:
            %    this_obj - this class object
            %    document_id - unique document ID for the requested document
            %    filename - name of requested data file referenced in the document
            %    params - optional parameters to DID.FILE.FILEOBJ constructor
            %
            % Outputs:
            %    file_obj - a did.file.readonly_fileobj object (possibly empty)

            % Get the cached filepath to the specified document

            query_str = ['SELECT cached_location,orig_location,uid,type ' ...
                         '  FROM docs,files ' ...
                         ' WHERE docs.doc_id="' document_id '" ' ...
                         '   AND files.doc_idx=docs.doc_idx'];
            if nargin > 2 && ~isempty(filename)
                query_str = [query_str ' AND files.filename="' filename '"'];
            else
                error('DID:SQLITEDB:open','The requested filename must be specified in open_doc()');
                %filename = '';  % used in catch block below
            end
            data = this_obj.run_sql_query(query_str, true);  %structArray=true
            if isempty(data)
                if isempty(filename)
                    error('DID:SQLITEDB:open','Document id "%s" does not include any readable file',document_id);
                else
                    error('DID:SQLITEDB:open','Document id "%s" does not include a file named "%s"',document_id,filename);
                end
            end

            % First try to access the global cached file, if defined and if exists
            file_paths = {};
            for uids=1:numel(data)
                file_paths{end+1} = [did.common.PathConstants.filecachepath filesep data(uids).uid ]; %#ok<AGROW>
                file_paths{end+1} = [this_obj.FileDir filesep data(uids).uid]; %#ok<AGROW>
            end

            didCache = did.common.getCache();

            file_paths = file_paths(~cellfun('isempty',file_paths));
            for idx = 1 : numel(file_paths)
                this_file = file_paths{idx};
                if isfile(this_file)
                    % Return a did.file.readonly_fileobj wrapper obj for the cached file
                    parent = fileparts(this_file);
                    if strcmp(parent,did.common.PathConstants.filecachepath) % fileCache,
                        didCache.touch(this_file); % we used it so indicate that we did
                    end
                    file_obj = did.file.readonly_fileobj('fullpathfilename',this_file,varargin{:});
                    return
                end
            end

            % No stored file exists, try to access original location(s) and put in file cache
            for idx = 1 : numel(data)  %data is a struct array
                this_file_struct = data(idx);
                sourcePath = this_file_struct.orig_location;
                destDir =  did.common.PathConstants.temppath;
                %destDir = this_obj.FileDir;  % SDV this should be changed to file cache
                %destDir = this_obj.get_preference('cache_folder');
                destPath = fullfile(destDir, this_file_struct.uid);
                try
                    file_type = lower(strtrim(this_file_struct.type));
                    if strcmpi(file_type,'file')
                        [status,errMsg] = copyfile(sourcePath, destPath, 'f');
                        if ~status, error(errMsg); end
                    elseif strcmpi(file_type,'url')
                        % call fileCache object to add the file
                        websave(destPath, sourcePath);
                        if ~isfile(destPath), error(' '); end
                    end
                    % now we have the temporary file for the file cache
                    didCache.addFile(destPath, this_file_struct.uid);
                    cacheFile = fullfile(didCache.directoryName,this_file_struct.uid);
                    % Return a did.file.readonly_fileobj wrapper obj for the cached file
                    file_obj = did.file.readonly_fileobj('fullpathfilename',cacheFile,varargin{:});
                    return
                catch err
                    errMsg = strtrim(err.message); if ~isempty(errMsg), errMsg=[': ' errMsg]; end %#ok<AGROW>
                    warning('DID:SQLITEDB:open','Cannot access the %s "%s" in document "%s"%s',file_type,sourcePath,document_id,errMsg);
                end
            end

            % No cached file was found or is accessible - return an error
            if isempty(filename)
                error('DID:SQLITEDB:open','No file in document "%s" can be accessed',document_id);
            else
                error('DID:SQLITEDB:open','The file "%s" in document "%s" cannot be accessed',filename,document_id);
            end
        end

        function [tf, file_path] = check_exist_doc(this_obj, document_id, filename, varargin)
            % check_exist_doc - Check if file exists for the specified document ID
            %
            % [tf, file_path] = check_exist_doc(this_obj, document_id, filename, [params])
            %
            % Return a boolean flag indicating whether a specified file
            % exists for the specified DOCUMENT_ID. The requested filename
            % must be specified using the (mandatory) FILENAME parameter.
            %
            % DOCUMENT_ID must be a scalar ID string, not an array of IDs.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value, as accepted by the DID.FILE.FILEOBJ
            % constructor method.
            %
            % Only the first matching file that is found is returned.
            %
            % Inputs:
            %    this_obj - this class object
            %    document_id - unique document ID for the requested document
            %    filename - name of requested data file referenced in the document
            %    params - optional parameters to DID.FILE.FILEOBJ constructor
            %
            % Outputs:
            %    tf - a boolean flag indicating if the file exists
            %    file_path (optional) - The absolute file path of the file.
            %       This is an empty character vector if the file does not
            %       exist

            file_path = '';

            % Get the cached filepath to the specified document
            query_str = ['SELECT cached_location,orig_location,uid,type ' ...
                '  FROM docs,files ' ...
                ' WHERE docs.doc_id="' document_id '" ' ...
                '   AND files.doc_idx=docs.doc_idx'];
            if nargin > 2 && ~isempty(filename)
                query_str = [query_str ' AND files.filename="' filename '"'];
            else
                error('DID:SQLITEDB:open','The requested filename must be specified in check_exist_doc()');
            end
            data = this_obj.run_sql_query(query_str, true);  %structArray=true
            if isempty(data)
                tf = false; % File does not exist
            elseif numel(data) == 1
                tf = true;
                file_path = [this_obj.FileDir, filesep, data.uid];
            else
                file_path = fullfile( this_obj.FileDir, {data.uid} );
                tf = false( size( file_path) );
                for i = numel(file_path)
                    tf = ~isempty(file_path{i}) && isfile(file_path{i});
                end
                tf = any(tf);
                file_path = file_path(tf);
                if numel(file_path) > 1
                    warning('Expected to find exactly one file matching filename.')
                end
                file_path = file_path{1};
            end
            if nargout < 2
                clear file_path
            end
        end
    end

    % Internal methods used by this class
    methods (Access=protected)
        function [hCleanup, filename] = open_db(this_obj)
            % open_db - Open/create a DID SQLite database file
            %
            % [hCleanup, filename] = open_db(this_obj)
            %
            % Inputs:
            %    this_obj - this class object
            %
            % Outputs:
            %    hCleanup - object used by onCleanup to close the DB connection/file
            %               when the calling function concludes (returns/errors)
            %    filename - name of the database file (used in error messages)

            % Initialize
            hCleanup = [];
            if nargout > 1
                filename = this_obj.connection;
            else
                filename = '';
            end

            % Bail out without validation if the DB is already open (performance)
            if ~isempty(this_obj.dbid) % && ~isNew
                return
            end

            % Open the specified filename. Use 0 to get the next free dbid
            filename = this_obj.connection;
            isNew = ~isfile(filename);
            this_obj.dbid = mksqlite(0, 'open', filename);

            % Create a cleanup object to close the DB file once usage is done (if requested)
            if nargout
                hCleanup = onCleanup(@()this_obj.close_db());
            end

            % Disable OS file synchronization (performance)
            % https://www.sqlite.org/pragma.html#pragma_synchronous
            % https://stackoverflow.com/questions/1711631/improve-insert-per-second-performance-of-sqlite
            mksqlite(this_obj.dbid,'pragma synchronous=OFF'); %default=DELETE

            % Set the max memory cache size to 1M pages = 4GB (performance)
            % https://www.sqlite.org/pragma.html#pragma_cache_size
            mksqlite(this_obj.dbid,'pragma cache_size=1000000'); %default=-2000=2MB

            % Use exclusive database connection locking mode (performance, DANGEROUS?)
            % https://www.sqlite.org/pragma.html#pragma_locking_mode
            %mksqlite(this_obj.dbid,'pragma locking_mode=EXCLUSIVE'); %default=NORMAL

            % If this is an existing file
            if ~isNew

                % Ensure that the file is a valid DID SQLite database
                try
                    tables = this_obj.run_sql_noOpen('show tables');
                    tablenames = {tables.tablename};
                    mandatory_tables = {'branches','docs','branch_docs','fields','doc_data'};
                    for i = 1 : numel(mandatory_tables)
                        table_name = mandatory_tables{i};
                        errMsg = ['"' table_name '" table not found in database'];
                        assert(any(strcmp(tablenames,table_name)), errMsg);
                    end
                catch err
                    error('DID:SQLITEDB:OPEN','Error opening %s as a DID SQLite database: %s',filename,err.message);
                end

            else % new database

                % Use Types BLOBs to store data values of any type/size
                % http://mksqlite.sourceforge.net/d2/dd2/example_6.html
                mksqlite('typedBLOBs', 2);

                % Create empty default tables in the newly-created database
                this_obj.create_db_tables();

                % Close the database - Actually NOT: keep it open!
                %this_obj.close_db();

                % No cleanup object in this case
            end
        end

        function data = run_sql_noOpen(this_obj, query_str, varargin)
            % Run the SQL query in an open database
            try
                %query_str  %debug
                data = mksqlite(this_obj.dbid, query_str, varargin{:});
                return
            catch err
            end
            if strcmpi(strtrim(err.message),'database not open')
                try
                    warning('Database is in an inconsistent state - reopening');
                    dbstack
                    this_obj.open_db(); %hCleanup = 
                    data = mksqlite(this_obj.dbid, query_str, varargin{:});
                    return
                catch err
                end
            end
            query_str = regexprep(query_str, {' +',' = '}, {' ','='});
            fprintf(2,'Error running the following SQL query in SQLite DB:\n%s\nError cause: %s\n',query_str,err.message)
            rethrow(err)
        end

        function close_db(this_obj)
            % Close the database file (ignore any errors)
            
            try 
                dbid = this_obj.dbid; 
            catch
                % bail out if object is no longer valid
                return
            end
            
            try
                if ~isempty(dbid)
                    mksqlite(dbid, 'close');
                    this_obj.dbid = [];
                end
            catch ME
                warning(ME.message)
            end
        end

        function create_db_tables(this_obj)
            try
                %% Create "branches" table
                this_obj.create_table('branches', ...
                    {'branch_id TEXT NOT NULL UNIQUE', ...
                    'parent_id TEXT', ...
                    'timestamp NUMERIC', ...
                    'FOREIGN KEY(parent_id) REFERENCES branches(branch_id)', ...
                    'PRIMARY KEY(branch_id)'});

                %% Create "docs" table
                this_obj.create_table('docs', ...
                    {'doc_id    TEXT    NOT NULL UNIQUE', ...
                    'doc_idx   INTEGER NOT NULL UNIQUE', ...
                    'json_code TEXT', ...
                    'timestamp NUMERIC', ...
                    ... 'object', ... %BLOB
                    'PRIMARY KEY(doc_idx AUTOINCREMENT)'});

                %% Create "branch_docs" table
                this_obj.create_table('branch_docs', ...
                    {'branch_id TEXT    NOT NULL', ...
                    'doc_idx   INTEGER NOT NULL', ...
                    'timestamp NUMERIC', ...
                    'FOREIGN KEY(branch_id) REFERENCES branches(branch_id)', ...
                    'FOREIGN KEY(doc_idx)   REFERENCES docs(doc_idx)', ...
                    'PRIMARY KEY(branch_id,doc_idx)'});

                %% Create "fields" table
                this_obj.create_table('fields', ...
                    {'class      TEXT NOT NULL', ...
                    'field_name TEXT NOT NULL UNIQUE', ...
                    'json_name  TEXT NOT NULL', ...
                    'field_idx  INTEGER NOT NULL UNIQUE DEFAULT 1', ...
                    'PRIMARY KEY(field_idx AUTOINCREMENT)'});

                %% Create "doc_data" table
                this_obj.create_table('doc_data', ...
                    {'doc_idx   INTEGER NOT NULL', ...
                    'field_idx INTEGER NOT NULL', ...
                    'value', ... %BLOB - any data type
                    'FOREIGN KEY(doc_idx)   REFERENCES docs(doc_idx)', ...
                    'FOREIGN KEY(field_idx) REFERENCES fields(field_idx)'});

                %% Create "files" table
                this_obj.create_table('files', ...
                    {'doc_idx         INTEGER NOT NULL', ...
                    'filename        TEXT NOT NULL', ...
                    'uid             TEXT NOT NULL UNIQUE', ...
                    'orig_location   TEXT NOT NULL', ...
                    'cached_location TEXT',          ... % empty if not cached
                    'type            TEXT NOT NULL', ...
                    'parameters      TEXT',          ... % normally empty
                    'FOREIGN KEY(doc_idx) REFERENCES docs(doc_idx)', ...
                    'PRIMARY KEY(doc_idx,filename,uid)'});

                %% Add indexes (performance)
                this_obj.run_sql_noOpen('CREATE INDEX "docs_doc_id"       ON "docs"     ("doc_id")');
                this_obj.run_sql_noOpen('CREATE INDEX "doc_data_value"    ON "doc_data" ("value")');
                this_obj.run_sql_noOpen('CREATE INDEX "fields_field_name" ON "fields"   ("field_name")');
            catch err
                this_obj.close_db();
                try delete(filename); catch, end
                error('DID:SQLITEDB:CREATE','Error creating %s as a new DID SQLite database: %s',filename,err.message);
            end
        end

        function create_table(this_obj, table_name, columns, extra)
            % create_table - Create a new table with specified columns in the database
            sql_str = ['CREATE TABLE "' table_name '" ('];
            if nargin < 3 || isempty(columns), columns = {'id TEXT'}; end
            if ~iscell(columns), columns = {columns}; end
            for i = 1 : numel(columns)
                if i > 1, sql_str = [sql_str ', ']; end %#ok<AGROW>
                sql_str = [sql_str columns{i}]; %#ok<AGROW>
            end
            sql_str(end+1) = ')';
            if nargin >3 && ~isempty(extra), sql_str = [sql_str ' ' extra]; end
            this_obj.run_sql_noOpen(sql_str);
        end

        function insert_into_table(this_obj, table_name, field_names, varargin)
            num_values = numel(varargin);
            num_fields = sum(field_names==',') + 1;
            queryStrs = regexprep(field_names,'[^,]+','?');
            if num_values > num_fields
                num_rows = round(num_values/num_fields);  % should be an integer
                queryStrs = repmat([queryStrs '),('],1,num_rows);
                queryStrs(end-2:end) = '';  % remove the trailing '),('
            end
            sqlStr = ['INSERT INTO ' table_name ' (' field_names ') VALUES (' queryStrs ')'];
            this_obj.run_sql_noOpen(sqlStr, varargin{:});
        end

        function field_idx = get_field_idx(this_obj, group_name, field_name)
            % Fetch the field_idx (auto-incremented) for the specified field_name
            field_name = strrep(strtrim(field_name),'___','.');  % ___ => .
            field_name = strrep(field_name,[group_name '.'],''); % strip group_name
            field_name = [group_name '.' field_name];            % add group_name

            % Try to reuse the field_idx, if known
            cached_field_names = this_obj.fields_cache(:,1);
            row = find(strcmp(cached_field_names, field_name),1);
            if isempty(row)
                % field_name's field_idx is unknown - get it from DB, or add new
                results = this_obj.run_sql_noOpen('SELECT field_idx FROM fields WHERE field_name=?', field_name);
                if isempty(results)
                    % Insert a new field key and rerun the query
                    json_name = regexprep(field_name,{'\.','\s+'},{'___','_'});  % . => ___
                    this_obj.insert_into_table('fields','class,field_name,json_name', group_name, field_name, json_name);
                    field_idx = this_obj.get_field_idx(group_name, field_name);
                else
                    % Add a new field with the specified field_id to the doc_data table
                    field_idx = results(1).field_idx;

                    % Cache the field_idxx for later reuse
                    this_obj.fields_cache(end+1,:) = {field_name, field_idx};
                end
            else  % cached field_idx found for this field_name
                field_idx = this_obj.fields_cache{row,2};
            end
        end

        function insert_doc_data_field(this_obj, doc_idx, group_name, field_name, value)
            % Insert a new row record to the doc_data table

            % Fetch the field_idx (auto-incremented) for the specified field_name
            field_idx = this_obj.get_field_idx(group_name, field_name);

            % Insert a new row record to the doc_data table
            this_obj.insert_into_table('doc_data', 'doc_idx,field_idx,value', doc_idx, field_idx, value);
        end
    end

end % sqlitedb classdef
