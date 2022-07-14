classdef sqlitedb < did.database
% did.implementations.sqlitedb - An implementation of an SQLite database for DID
%
% See also: did.implementations.dumbjasondb, did.implementations.postgresdb

    properties
	    % insert needed properties here
    end

    methods % constructor
        function sqlitedb_obj = sqlitedb(filename)
    	    % SQLITEDB create a new SQLITEDB object
    	    %
    	    % SQLDB_OBJ = SQLITEDB(filename)
    	    %
    	    % Creates a new SQLITEDB object with optional FILENAME. 
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

            % Set the database version
            sqlitedb_obj.version = '1.0';

            % Open/create the database (croaks in case of error)
            sqlitedb_obj.open_db(filename);

            % Looks ok - set the filename in the object's connection property
            sqlitedb_obj.connection = filename;
	    end % sqlitedb()
    end 

    methods % destructor
        function delete(sqlitedb_obj)
            % DELETE - destructor function. Closes the database connection.
            try mksqlite(sqlitedb_obj.dbid, 'close'); catch, end
        end  % delete()
    end

    methods % public
        function data = run_sql_query(sqlitedb_obj, query_str, returnStruct)
        % runSqlQuery - run an SQL query on the database
        % 
        % Inputs:
        %    sqlitedb_obj - this class object
        %    query_str - the SQL query string. For example: 
        %                'SELECT docs.doc_id FROM docs, doc_data, fields 
        %                 WHERE docs.doc_idx = doc_data.doc_idx 
        %                   AND fields.field_idx = doc_data.field_idx
        %                   AND fields.field_idx = doc_data.field_idx
        %                   AND ((fields.field_name = "meta.class" AND 
        %                         doc_data.value = "ndi_documentx") OR
        %                        (fields.field_name = "meta.superclass" AND 
        %                         doc_data.value like "%ndi_documentx%"))'
        %    returnStruct - true to return a struct (or struct array) of values.
        %                   false (default) to return an array of values.
        %                     If multiple fields are returned by the query,
        %                     they are enclused within a containing cell-array.

            % Open the database for query
            filename = sqlitedb_obj.connection;
            sqlitedb_obj.dbid = mksqlite('open',filename);
            hCleanup = onCleanup(@()mksqlite(sqlitedb_obj.dbid, 'close'));

            % Run the SQL query in the database
            try
                %query_str  %debug
                data = mksqlite(sqlitedb_obj.dbid, query_str);
            catch err
                fprintf(2,'Error running the following SQL query in SQLite DB:\n%s\n',query_str)
                rethrow(err)
            end
            if isempty(data), data = {}; return, end
            returnStruct = nargin > 2 && returnStruct;  % default=false
            if ~returnStruct && isstruct(data)
                fn = fieldnames(data);
                numFields = numel(fn);
                dataTable = struct2table(data);
                dataCells = {};
                for i = numFields : -1 : 1
                    results = dataTable.(fn{i});
                    if isempty(results)
                        results = {};  % ensure it's a cell-array
                    elseif ~iscell(results) && (isscalar(results) || ischar(results))
                        results = {results};
                    end
                    dataCells{i} = results;
                end
                %if numFields == 1, dataCells = dataCells{1}; end  %de-cell
                data = dataCells;
            end
        end

	    function doc_ids = alldocids(sqlitedb_obj)
	    % ALLDOCIDS - return all unique document ids in the database
	    %
	    % DOC_IDS = ALLDOCIDS(SQLITEDB_OBJ)
	    %
	    % Return all unique document ids as a cell array of strings. 
	    % If there are no documents, an empty cell array is returned.

            % Run the SQL query in the database
            query_str = 'SELECT DISTINCT doc_id FROM docs';
            data = run_sql_query(sqlitedb_obj, query_str);

            % Parse the results
            doc_ids = data{1};
            if ~iscell(doc_ids)
                doc_ids = {doc_ids};
            end
	    end % alldocids()

	    function doc_ids = allcommits(sqlitedb_obj)
	    % ALLCOMMITS - return all unique commit ids in the database
	    %
	    % COMMIT_IDS = ALLCOMMITS(SQLITEDB_OBJ)
	    %
	    % Return all unique commit ids as a cell array of strings. 
	    % If there are no commits, an empty cell array is returned.

            % Run the SQL query in the database
            query_str = 'SELECT DISTINCT commit_id FROM commits';
            data = run_sql_query(sqlitedb_obj, query_str);

            % Parse the results
            doc_ids = data{1};
            if ~iscell(doc_ids)
                doc_ids = {doc_ids};
            end
	    end % all_doc_ids()

        function doc_objs = doc_ids_to_objects(sqlitedb_obj, doc_ids)
	    % doc_ids_to_objects - convert doc ids into DID.DOCUMENT objects
	    %
	    % DOC_OBJS = DOC_IDS_TO_OBJECTS(SQLITEDB_OBJ)
	    %
	    % Return an array of DID.DOCUMENT objects corresponding to the documents
        % within the database.

            % Initialize an empty results array of no objects
            doc_objs = did.document.empty;

            % Loop over all specified doc_ids
            if ~iscell(doc_ids), doc_ids = {doc_ids}; end
            for i = 1 : numel(doc_ids)
                % Run the SQL query in the database
                doc_id = doc_ids{i};
                query_str = ['SELECT json_code FROM docs WHERE doc_id="' doc_id '"'];
                data = run_sql_query(sqlitedb_obj, query_str);

                % Parse the results
                if isempty(data)
                    error('DID:SQLITEDB:DOC_ID','Document id %s was not found in the database',doc_id);
                else
                    json_code = data{1};
                    if iscell(json_code), json_code = json_code{1}; end
                    doc_objs(i) = did.document(jsondecode(json_code));
                end
            end

            % Reshape the output array based on the input array's dimensions
            doc_objs = reshape(doc_objs,size(doc_ids));
        end
    end

    methods (Access=protected)
        function open_db(sqlitedb_obj, filename)
        % open_db - Open/create a DID SQLite database with the specified filename

            % Is this a new or existing file?
            isNew = ~exist(filename,'file');

            % Open the specified filename
            sqlitedb_obj.dbid = mksqlite('open',filename);

            % If this is an existing file
            if ~isNew

                % Ensure that the file is a valid DID SQLite database
                try
                    tables = mksqlite(sqlitedb_obj.dbid, 'show tables');
                    tablenames = {tables.tablename};
                    mandatory_tables = {'commits','docs','fields','doc_data'};
                    for i = 1 : numel(mandatory_tables)
                        table_name = mandatory_tables{i};
                        errMsg = ['"' table_name '" table not found in database'];
                        assert(any(strcmp(tablenames,table_name)), errMsg);
                    end
                catch err
                    error('DID:SQLITEDB:OPEN','Error opening %s as a DID SQLite database: %s',filename,err.message);
                end

            else % new database

                % Create empty default tables in the newly-created database
                try
                    % Use Types BLOBs to store data values of any type/size
                    % http://mksqlite.sourceforge.net/d2/dd2/example_6.html
                    mksqlite('typedBLOBs', 2);

                    %{
                    % "app" table
                    sqlitedb_obj.create_table('app', {'field TEXT NOT NULL', 'value'});
                    mksqlite(sqlitedb_obj.dbid, 'INSERT INTO app VALUES ("name",?)',    filename);
                    mksqlite(sqlitedb_obj.dbid, 'INSERT INTO app VALUES ("version",?)', sqlitedb_obj.version);
                    mksqlite(sqlitedb_obj.dbid, 'INSERT INTO app VALUES ("creation",?)',getUnixTime());
                    %}

                    % "commits" table
                    sqlitedb_obj.create_table('commits', ...
                                             {'commit_id   TEXT NOT NULL UNIQUE', ...
                                              'commit_name TEXT', ...
                                              'commit_time INTEGER', ...
                                              'PRIMARY KEY(commit_id)'});

                    % "docs" table
                    sqlitedb_obj.create_table('docs', ...
                                             {'doc_id  TEXT    NOT NULL UNIQUE', ...
                                              'doc_idx INTEGER NOT NULL', ...
                                              'commit_id TEXT NOT NULL', ...
                                              'json_code TEXT', ...
                                              ... 'object', ... %BLOB
                                              'FOREIGN KEY(commit_id) REFERENCES commits(commit_id)', ...
                                              'PRIMARY KEY(doc_idx AUTOINCREMENT)'});

                    % "fields" table
                    sqlitedb_obj.create_table('fields', ...
                                             {'class      TEXT NOT NULL', ...
                                              'field_name TEXT NOT NULL UNIQUE', ...
                                              'json_name  TEXT NOT NULL', ...
                                              'field_idx  INTEGER NOT NULL DEFAULT 1', ...
                                              'PRIMARY KEY(field_idx AUTOINCREMENT)'});

                    % "doc_data" table
                    sqlitedb_obj.create_table('doc_data', ...
                                             {'doc_idx   INTEGER NOT NULL', ...
                                              'field_idx INTEGER NOT NULL', ...
                                              'value', ... %BLOB - any data type
                                              'FOREIGN KEY(doc_idx)   REFERENCES docs(doc_idx)', ...
                                              'FOREIGN KEY(field_idx) REFERENCES fields(field_idx)'});

                    % Close the database
                    try mksqlite(sqlitedb_obj.dbid, 'close'); catch, end
                catch err
                    try mksqlite(sqlitedb_obj.dbid, 'close'); catch, end
                    try delete(filename); catch, end
                    error('DID:SQLITEDB:CREATE','Error creating %s as a new DID SQLite database: %s',filename,err.message);
                end
            end
        end

        function create_table(sqlitedb_obj, table_name, columns, extra)
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
            mksqlite(sqlitedb_obj.dbid, sql_str);
        end

        function sqlitedb_obj = do_add(sqlitedb_obj, did_document_obj, varargin)
        % do_add - Add a DID document to the database

            % Open the database for update
            filename = sqlitedb_obj.connection;
            sqlitedb_obj.dbid = mksqlite('open',filename);
            hCleanup = onCleanup(@()mksqlite(sqlitedb_obj.dbid, 'close'));

            % Get the document id
            meta_data = did.implementations.doc2sql(did_document_obj);
            meta_data_struct = cell2struct({meta_data.columns}',{meta_data.name}');
            doc_id = meta_data_struct.meta(1).value;

            % Get the JSON code that parses all the document's properties
            json_code = jsonencode(did_document_obj.document_properties);

            % Handle case of existing document
            params = parseOptionalParams(varargin{:});
            try doOnDuplicate = params.OnDuplicate; catch, doOnDuplicate = 'error'; end
            data = mksqlite(sqlitedb_obj.dbid, 'SELECT * FROM docs WHERE doc_id=?', doc_id);
            if ~isempty(data)
                %errMsg = sprintf('Error adding document %s to %s - document already exists', doc_id, filename);
                %assert(isempty(data),'DID:SQLITEDB:DUPLICATE_DOC','%s',errMsg)
                doOnDuplicate = lower(doOnDuplicate(doOnDuplicate~=' '));
                switch doOnDuplicate
                    case 'replacenowarn'
                        sqlitedb_obj.do_remove(doc_id);
                    case 'replaceandwarn'
                        warning('DID:SQLITEDB:DUPLICATE_DOC','Document %s already exists in %s - replacing', doc_id, filename);
                        sqlitedb_obj.do_remove(doc_id);
                    otherwise %case 'error'
                        error('DID:SQLITEDB:DUPLICATE_DOC','Error adding document %s to %s - document already exists', doc_id, filename);
                end
                mksqlite('open',filename); %do_remove closes the db, so we must reopen it
            end

            % Add the new document to commits, docs tables
            commit_id = num2str(now,'%.9f');
            mksqlite(sqlitedb_obj.dbid, 'INSERT INTO commits (commit_id,commit_time) VALUES (?,?)', ...
                                        commit_id, getUnixTime());
            mksqlite(sqlitedb_obj.dbid, 'INSERT INTO docs (doc_id,commit_id,json_code) VALUES (?,?,?)', ...
                                        doc_id, commit_id, json_code); %, did_document_obj);
            data = mksqlite(sqlitedb_obj.dbid, 'SELECT doc_idx FROM docs WHERE doc_id=?', doc_id);
            doc_idx = data(1).doc_idx;

            % Add the document fields to doc_data table (possibly also fields entries)
            %sqlitedb_obj.insert_doc_data_field(doc_idx, 'app', 'name', filename);
            %sqlitedb_obj.insert_doc_data_field(doc_idx, 'app', 'version', sqlitedb_obj.version);
            field_groups = fieldnames(meta_data_struct);
            for groupIdx = 1 : numel(field_groups)
                group_name = field_groups{groupIdx};
                group_data = meta_data_struct.(group_name);
                for fieldIdx = 1 : numel(group_data)
                    field_data = group_data(fieldIdx);
                    field_name  = field_data.name;
                    if strcmpi(field_name,'doc_id'), continue, end
                    field_value = field_data.value;
                    sqlitedb_obj.insert_doc_data_field(doc_idx, group_name, field_name, field_value);
                end
            end
	    end % do_add

        function insert_doc_data_field(sqlitedb_obj, doc_idx, group_name, field_name, value)
            % Fetch the field_id (auto-incremented) for the specified field_name
            field_name = regexprep(strtrim(field_name),'___','.');       % ___ => .
            field_name = regexprep(field_name,['^' group_name '\.'],''); % strip group_name
            field_name = [group_name '.' field_name];                    % add group_name
            json_name = regexprep(field_name,{'\.','\s+'},{'___','_'});  % . => ___
            results = mksqlite(sqlitedb_obj.dbid, 'SELECT field_idx FROM fields WHERE field_name=?', field_name);
            if isempty(results)
                % Insert a new field key and rerun the query
                mksqlite(sqlitedb_obj.dbid, 'INSERT INTO fields (class,field_name,json_name) VALUES (?,?,?)', group_name, field_name, json_name);
                sqlitedb_obj.insert_doc_data_field(doc_idx, group_name, field_name, value);
            else
                % Add a new field with the specified field_id to the doc_data table
                field_idx = results(1).field_idx;
                %if ~isempty(value)
                    mksqlite(sqlitedb_obj.dbid, 'INSERT INTO doc_data (doc_idx,field_idx,value) VALUES (?,?,?)', doc_idx, field_idx, value);
                %end
            end
        end

	    function [did_document_obj, version] = do_read(sqlitedb_obj, did_document_id, version)
        % TODO
		    if nargin<3
			    version = [];
		    end
		    [doc, version] = sqlitedb_obj.db.read(did_document_id, version);
		    did_document_obj = did.document(doc);
	    end % do_read

        function sqlitedb_obj = do_remove(sqlitedb_obj, did_document_id, varargin)
        % do_remove - Remove the specified DID document from the database

            % Open the database for update
            filename = sqlitedb_obj.connection;
            sqlitedb_obj.dbid = mksqlite('open',filename);
            hCleanup = onCleanup(@()mksqlite(sqlitedb_obj.dbid, 'close'));

            % Get the document id (ensure that we have a string if doc object was specified)
            if ~ischar(did_document_id)
                meta_data = did.implementations.doc2sql(did_document_id);
                meta_data_struct = cell2struct({meta_data.columns}',{meta_data.name}');
                did_document_id = meta_data_struct.meta(1).value;
            end
            doc_id = did_document_id;

            % Handle case of missing document
            params = parseOptionalParams(varargin{:});
            try doOnMissing = params.OnMissing; catch, doOnMissing = 'error'; end
            data = mksqlite(sqlitedb_obj.dbid, 'SELECT doc_idx FROM docs WHERE doc_id=?', doc_id);
            if isempty(data)
                %errMsg = sprintf('Error removing document %s from %s - document not found', doc_id, filename);
                %assert(~isempty(data),'DID:SQLITEDB:NO_SUCH_DOC','%s',errMsg)
                doOnMissing = lower(doOnMissing(doOnMissing~=' '));
                switch doOnMissing
                    case 'ignore'
                        return
                    case 'warn'
                        warning('DID:SQLITEDB:NO_SUCH_DOC','Cannot remove document %s from %s - document not found', doc_id, filename);
                        return
                    otherwise %case 'error'
                        error('DID:SQLITEDB:NO_SUCH_DOC','Error removing document %s from %s - document not found', doc_id, filename);
                end
            end

            % Remove the document records from docs, doc_data tables
            doc_idx = data(1).doc_idx;
            mksqlite(sqlitedb_obj.dbid, 'DELETE FROM docs     WHERE doc_idx=?', doc_idx)
            mksqlite(sqlitedb_obj.dbid, 'DELETE FROM doc_data WHERE doc_idx=?', doc_idx)
        end % do_remove
    end

    % Search-related methods
    methods (Access=protected)
        function sql_str = query_struct_to_sql_str(sqlitedb_obj, query_struct)
            sql_str = ''; %#ok<NASGU>
            field  = query_struct.field;
            param1 = query_struct.param1;
            param2 = query_struct.param2;
            op = strtrim(lower(query_struct.operation));
            isNot = op(1)=='~';
            op(op=='~') = '';
            switch op
                case 'or'
                    sql_str = [query_struct_to_sql_str(sqlitedb_obj, param1) ' OR ' ...
                               query_struct_to_sql_str(sqlitedb_obj, param2)];
                case 'exact_string'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value = "' param1 '"'];
                case 'exact_string_anycase'
                    sql_str = ['fields.field_name="' field '" AND LOWER(doc_data.value) = "' lower(param1) '"'];
                case 'contains_string'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value like "%' param1 '%"'];
                case 'exact_number'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value = '  num2str(param1(1))];
                case 'lessthan'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value < '  num2str(param1(1))];
                case 'lessthaneq'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value <= ' num2str(param1(1))];
                case 'greaterthan'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value > '  num2str(param1(1))];
                case 'greaterthaneq'
                    sql_str = ['fields.field_name="' field '" AND doc_data.value >= ' num2str(param1(1))];
                case 'hassize'   %TODO
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
                case 'hasmember' %TODO
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
                case 'hasfield'  %TODO
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
                case 'partial_struct'  %TODO
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
                case 'hasanysubfield_contains_string'  %TODO
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
                case 'hasanysubfield_exact_string'     %TODO
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
                case 'regexp'
                    sql_str = ['fields.field_name="' field '" AND regex(doc_data.value,"' param1 '") NOT NULL'];
                case 'isa'
                    sql_str = ['(fields.field_name="meta.class" AND doc_data.value = "' param1 '") OR ' ...
                               '(fields.field_name="meta.superclass" AND doc_data.value like "%' param1 '%")'];
                otherwise
                    %error('DID:Implementations:SQLiteDB','Unrecognized query operation "%s"',op);
                    error('DID:Implementations:SQLiteDB','Query operation "%s" is not yet implemented for SQLiteDB',op);
            end
            sql_str = ['(' sql_str ')'];
            if isNot
                sql_str = ['NOT ' sql_str];
            end
        end

        function query_str = get_sql_query_str(sqlitedb_obj, query_structs)
            query_str = ['SELECT DISTINCT docs.doc_id ' ...
                         'FROM   docs, doc_data, fields ' ...
                         'WHERE  docs.doc_idx = doc_data.doc_idx AND ' ...
                               ' fields.field_idx = doc_data.field_idx AND ' ...
                               ' fields.field_idx = doc_data.field_idx'];
                         %((fields.field_name = "meta.class" AND doc_data.value = "ndi_document") OR (fields.field_name = "meta.superclass" AND doc_data.value like "%ndi_document%"))')';
            for i = 1 : numel(query_structs)
                sql_str = query_struct_to_sql_str(sqlitedb_obj, query_structs(i));
                if ~isempty(sql_str)
                    query_str = [query_str ' AND ' sql_str]; %#ok<AGROW>
                end
            end
        end

        function doc_ids = search_doc_ids(sqlitedb_obj, query_struct)
        % search_doc_ids - recursively search the database for matching doc IDs

            num_structs = numel(query_struct);
            if num_structs > 1  % loop over all &-ed queries
                doc_ids = {};
                for i = 1 : num_structs
                    new_doc_ids = search_doc_ids(sqlitedb_obj, query_struct(i));
                    if i > 1
                        doc_ids = intersect(doc_ids{1}, new_doc_ids{1});
                    else
                        doc_ids = new_doc_ids;
                    end
                end
                if size(doc_ids,1)==1 && size(doc_ids,2)>1
                    doc_ids = doc_ids';  % ensure column vector
                end
            else
                op = strtrim(lower(query_struct.operation));
                op(op=='~') = '';
                if strcmpi(op,'or')
                    doc_ids1 = search_doc_ids(sqlitedb_obj, query_struct.param1);
                    doc_ids2 = search_doc_ids(sqlitedb_obj, query_struct.param2);
                    doc_ids = union(doc_ids1{1}, doc_ids2{1});
                    if size(doc_ids,1)==1 && size(doc_ids,2)>1
                        doc_ids = doc_ids';  % ensure column vector
                    end
                else  % leaf scalar query
                    query_str = get_sql_query_str(sqlitedb_obj, query_struct);
                    doc_ids = run_sql_query(sqlitedb_obj, query_str);
                end
            end
        end

	    function did_document_ids = do_search(sqlitedb_obj, query_obj)
        % do_search - searches database for doc_ids that match specified query

            % Convert the query object into an SQL query string
            if isa(query_obj,'did.query')
			    query_obj = query_obj.searchstructure;
            end

            % Run the SQL query on the DB and return the matching documents
            if isstruct(query_obj)
                doc_ids = search_doc_ids(sqlitedb_obj, query_obj);
            else  % already in SQL str format
                query_str = query_obj;
                doc_ids = run_sql_query(sqlitedb_obj, query_str);
            end
            if numel(doc_ids)==1 && iscell(doc_ids{1})
                doc_ids = doc_ids{1};  %de-cell
            end

            % Return the resulting doc IDs
		    did_document_ids = doc_ids; %TODO: convert from doc_id => doc_obj?
	    end % do_search()
    end

    % Disregard these
    methods (Access=protected)
	    function [did_binarydoc_obj, key] = do_openbinarydoc(sqlitedb_obj, did_document_id, version)
		    did_binarydoc_obj = [];
		    [fid, key] = sqlitedb_obj.db.openbinaryfile(did_document_id, version);
		    if fid>0
			    [filename,permission,machineformat,encoding] = fopen(fid);
			    did_binarydoc_obj = did_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
				    'machineformat',machineformat,'permission',permission, 'doc_unique_id', did_document_id, 'key', key);
			    did_binarydoc_obj.frewind(); % move to beginning of the file
		    end
	    end % do_binarydoc()

	    function [did_binarydoc_matfid_obj] = do_closebinarydoc(sqlitedb_obj, did_binarydoc_matfid_obj)
	    % DO_CLOSEBINARYDOC - close and unlock an DID_BINARYDOC_MATFID_OBJ
	    %
	    % DID_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(SQLDB_OBJ, DID_BINARYDOC_MATFID_OBJ, KEY, DID_DOCUMENT_ID)
	    %
	    % Close and unlock the binary file associated with DID_BINARYDOC_OBJ.

		    sqlitedb_obj.db.closebinaryfile(did_binarydoc_matfid_obj.fid, ...
			    did_binarydoc_matfid_obj.key, did_binarydoc_matfid_obj.doc_unique_id);
		    did_binarydoc_matfid_obj.fclose(); 
	    end % do_closebinarydoc()
    end
end

function value = getUnixTime()
    value = java.util.Date().getTime;
end

function params = parseOptionalParams(varargin)
    params = struct;
    if nargin < 1, return, end
    if isstruct(varargin{1})
        params = varargin{1};
        varargin(1) = [];
    end
    for idx = 1 : 2 : length(varargin)
        params.(varargin{idx}) = varargin{idx+1};
    end
end
