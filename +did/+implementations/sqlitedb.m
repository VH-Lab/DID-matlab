classdef sqlitedb < did.database %#ok<*TNOW1>
% did.implementations.sqlitedb - An implementation of an SQLite database for DID
%
% See also: did.database, did.implementations.dumbjasondb, did.implementations.postgresdb

    properties
	    % insert needed properties here
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
            [hCleanup, filename] = this_obj.open_db(); %#ok<ASGLU>

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
            sqlStr = 'INSERT INTO branches (branch_id,parent_id,timestamp) VALUES (?,?,?)';
            this_obj.run_sql_noOpen(sqlStr, branch_id, parent_branch_id, tnow);

            % Duplicate the docs from parent branch to the newly-created branch
            sqlStr = ['SELECT doc_idx FROM branch_docs WHERE branch_id="' parent_branch_id '"'];
            data = this_obj.run_sql_noOpen(sqlStr);
            if ~isempty(data)
                doc_idx = data(1).doc_idx;
                for i = 1 : numel(doc_idx)
                    sqlStr = 'INSERT INTO branch_docs (branch_id,doc_idx,timestamp) VALUES (?,?,?)';
                    this_obj.run_sql_noOpen(sqlStr,branch_id,doc_idx(i),tnow);
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

            sqlStr = ['SELECT docs.doc_id FROM docs,branch_docs' ...
                      ' WHERE docs.doc_idx = branch_docs.doc_idx' ...
                      '   AND branch_id="' branch_id '"'];
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
            data = this_obj.run_sql_noOpen('SELECT doc_idx FROM docs WHERE doc_id=?', doc_id);
            if isempty(data)
                % Get the JSON code that parses all the document's properties
                json_code = jsonencode(document_obj.document_properties);

                % Add the new document to docs table
                sqlStr = 'INSERT INTO docs (doc_id,json_code,timestamp) VALUES (?,?,?)';
                this_obj.run_sql_noOpen(sqlStr, doc_id, json_code, now); %, document_obj);

                % Re-fetch the new document record's idx
                data = this_obj.run_sql_noOpen('SELECT doc_idx FROM docs WHERE doc_id=?', doc_id);
                doc_idx = data(1).doc_idx;

                % Add the document fields to doc_data table (possibly also fields entries)
                %this_obj.insert_doc_data_field(doc_idx,'app','name',filename);
                field_groups = fieldnames(meta_data_struct);
                for groupIdx = 1 : numel(field_groups)
                    group_name = field_groups{groupIdx};
                    group_data = meta_data_struct.(group_name);
                    for fieldIdx = 1 : numel(group_data)
                        field_data = group_data(fieldIdx);
                        field_name  = field_data.name;
                        if strcmpi(field_name,'doc_id'), continue, end
                        field_value = field_data.value;
                        this_obj.insert_doc_data_field(doc_idx, group_name, field_name, field_value);
                    end
                end
            else
                doc_idx = data(1).doc_idx;
            end

            % Handle case of the branch already containing this document
            data = this_obj.run_sql_noOpen('SELECT doc_idx FROM branch_docs WHERE doc_idx=?', doc_idx);
            if ~isempty(data)
                errMsg = sprintf('Document %s already exists in branch %s', doc_id, branch_id);
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
            sqlStr = 'INSERT INTO branch_docs (branch_id,doc_idx,timestamp) VALUES (?,?,?)';
            this_obj.run_sql_noOpen(sqlStr, branch_id, doc_idx, now);
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
            document_obj = did.document(jsondecode(json_code));
	    end % do_get_doc()

        function do_remove_doc(this_obj, document_id, branch_id, varargin)
            % do_remove - Remove specified DID document from the specified branch
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
            [hCleanup, filename] = this_obj.open_db(); %#ok<ASGLU>

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
                errMsg = sprintf('Cannot remove document %s - document not found in branch %s', doc_id, branch_id);
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

            % Is this a new or existing file?
            filename = this_obj.connection;
            isNew = ~exist(filename,'file');

            % Open the specified filename
            this_obj.dbid = mksqlite('open',filename);

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

                % Create a cleanup object to close the DB file once usage is done
                hCleanup = onCleanup(@()this_obj.close_db());

            else % new database

                % Create empty default tables in the newly-created database
                try
                    % Use Types BLOBs to store data values of any type/size
                    % http://mksqlite.sourceforge.net/d2/dd2/example_6.html
                    mksqlite('typedBLOBs', 2);

                    %{
                    % Create "app" table
                    this_obj.create_table('app', {'field TEXT NOT NULL', 'value'});
                    this_obj.run_sql_noOpen('INSERT INTO app VALUES ("name",?)',    filename);
                    this_obj.run_sql_noOpen('INSERT INTO app VALUES ("creation",?)',this_obj.getUnixTime());
                    %}

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
                                              'doc_idx   INTEGER NOT NULL', ...
                                              'json_code TEXT', ...
                                              'timestamp NUMERIC', ...
                                              ... 'object', ... %BLOB
                                              'PRIMARY KEY(doc_idx AUTOINCREMENT)'});

                    %% Create "branch_docs" table
                    this_obj.create_table('branch_docs', ...
                                             {'branch_id TEXT    NOT NULL UNIQUE', ...
                                              'doc_idx   INTEGER NOT NULL', ...
                                              'timestamp NUMERIC', ...
                                              'FOREIGN KEY(branch_id) REFERENCES branches(branch_id)', ...
                                              'FOREIGN KEY(doc_idx)   REFERENCES docs(doc_idx)', ...
                                              'PRIMARY KEY(branch_id)'});

                    %% Create "fields" table
                    this_obj.create_table('fields', ...
                                             {'class      TEXT NOT NULL', ...
                                              'field_name TEXT NOT NULL UNIQUE', ...
                                              'json_name  TEXT NOT NULL', ...
                                              'field_idx  INTEGER NOT NULL DEFAULT 1', ...
                                              'PRIMARY KEY(field_idx AUTOINCREMENT)'});

                    %% Create "doc_data" table
                    this_obj.create_table('doc_data', ...
                                             {'doc_idx   INTEGER NOT NULL', ...
                                              'field_idx INTEGER NOT NULL', ...
                                              'value', ... %BLOB - any data type
                                              'FOREIGN KEY(doc_idx)   REFERENCES docs(doc_idx)', ...
                                              'FOREIGN KEY(field_idx) REFERENCES fields(field_idx)'});

                catch err
                    this_obj.close_db();
                    try delete(filename); catch, end
                    error('DID:SQLITEDB:CREATE','Error creating %s as a new DID SQLite database: %s',filename,err.message);
                end

                % Close the database
                this_obj.close_db();

                % No cleanup object in this case
                hCleanup = [];
            end
        end

        function data = run_sql_noOpen(this_obj, query_str, varargin)
            % Run the SQL query in an open database
            try
                %query_str  %debug
                data = mksqlite(this_obj.dbid, query_str, varargin{:});
            catch err
                query_str = regexprep(query_str, {' +',' = '}, {' ','='});
                fprintf(2,'Error running the following SQL query in SQLite DB:\n%s\n',query_str)
                rethrow(err)
            end
        end

        function close_db(this_obj)
            % Close the database file (ignore any errors)
            try mksqlite(this_obj.dbid, 'close'); catch, end
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

        function insert_doc_data_field(this_obj, doc_idx, group_name, field_name, value)
            % Fetch the field_id (auto-incremented) for the specified field_name
            field_name = regexprep(strtrim(field_name),'___','.');       % ___ => .
            field_name = regexprep(field_name,['^' group_name '\.'],''); % strip group_name
            field_name = [group_name '.' field_name];                    % add group_name
            json_name = regexprep(field_name,{'\.','\s+'},{'___','_'});  % . => ___
            results = this_obj.run_sql_noOpen('SELECT field_idx FROM fields WHERE field_name=?', field_name);
            if isempty(results)
                % Insert a new field key and rerun the query
                this_obj.run_sql_noOpen('INSERT INTO fields (class,field_name,json_name) VALUES (?,?,?)', group_name, field_name, json_name);
                this_obj.insert_doc_data_field(doc_idx, group_name, field_name, value);
            else
                % Add a new field with the specified field_id to the doc_data table
                field_idx = results(1).field_idx;
                %if ~isempty(value)
                    this_obj.run_sql_noOpen('INSERT INTO doc_data (doc_idx,field_idx,value) VALUES (?,?,?)', doc_idx, field_idx, value);
                %end
            end
        end
    end    

end % sqlitedb classdef
