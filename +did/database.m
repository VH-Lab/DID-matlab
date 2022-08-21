classdef (Abstract) database < handle
% did.database: Abstract superclass for all did.database implementations
%
% did.database defines the API for the DID database system.
% Applications/users interact with its public methods.
%
% Developers who create subclass implementations of the did.database class should
% override the corresponding do_* methods, which are called by the public methods.
%
% Properties (read-only):
%   connection - The connection details for the database (might be a file name, directory name, or struct)
%   commit     - The commit number of the database that we are viewing/editing at the moment
%   dbid       - The database ID
%   version    - Version of the database
%
% Public methods with a default implementation:
%   database - Create a new database
%   add - Add a document to the database
%   read - Read a did.document from the database based on the document's unique identifier
%   remove - Remove a did.document from the database
%   clear - Remove all did.documents from the database
%   all_doc_ids - Returns a cell-array of all document IDs in the database
%   all_commit_ids - Returns a cell-array of all commit IDs in the database
%   search - Search for a did.document(s) using a did.query
%   checkout_branch - check out a particular database commit/branch (TODO)
%   open_doc - Open the binary portion of a did.document for reading/writing (returns a did.binarydoc)
%   close_doc - Close a did.binarydoc
%   run_sql_query - Run the specified SQL query in the database
%
% Protected methods that have a default implementation and may be overloaded:
%   do_search    - implements the core logic for the search() method
%   do_open_doc  - implements the core logic for the open_doc() method
%   do_close_doc - implements the core logic for the close_doc() method
%   all_doc_ids    - returns a list of all document IDs in the DB
%   all_commit_ids - returns a list of all document commit IDs in the DB
% 
% Methods that *MUST* be overloaded by specific subclass implementations:
%   do_add(database_obj, did_document_obj, add_parameters)
%   do_read(database_obj, did_document_id, version)
%   do_remove(database_obj, did_document_id, versions)
%   do_run_sql_query(database_obj, query_str, returnStruct)
%   delete - destructor (typically closes the database connection/file, if open)

	properties (SetAccess=protected, GetAccess=public)
		connection % A variable or struct describing the connection parameters of the database; may be a simple file path
		commit     % The commit number of the database that we are viewing/editing at the moment
        dbid       % Database ID
        version    % Database version
	end % properties

	methods
		function database_obj = database(varargin)
			% DATABASE - create a new DATABASE
			%
			% DATABASE_OBJ = DATABASE(...)
			%
			% Creates a new DATABASE object 
			
			connection = '';
			commit = '';

			if nargin>0
				connection = varargin{1};
			end

			database_obj.connection = connection;
			database_obj.commit = commit;
		end % database

		function database_obj = add(database_obj, did_document_obj, varargin)
			% ADD - add an DID_DOCUMENT to the database 
			%
			% DATABASE_OBJ = ADD(DATABASE_OBJ, DID_DOCUMENT_OBJ, [PARAMS...])
			%
			% Adds the document DID_DOCUMENT_OBJ to the database DATABASE_OBJ.
			%
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnDuplicate' - followed by 'replacenowarn', 'replaceandwarn', or 'error' (default)

            % Ensure we got a valid input doc object
            if isempty(did_document_obj)
                return; % nothing to do
            end

            % Call the specific database's addition method
            database_obj = do_add(database_obj, did_document_obj, varargin{:});
		end % add()

		function did_document_obj = read(database_obj, did_document_id, commit_id)
			% READ - read an DID.DOCUMENT from a DID.DATABASE 
			%
			% DID_DOCUMENT_OBJ = READ(DATABASE_OBJ, DOCUMENT_ID, [COMMIT_ID]) 
			%
			% Read the DID_DOCUMENT object with the document ID specified by DOCUMENT_ID. 
			% If COMMIT_ID is omitted, then the current DATABASE_OBJ.COMMIT_ID is read.
			%
			% If there is no DID DOCUMENT object with that ID, then empty is returned ([]).

            if nargin<3
                commit_id = database_obj.commit;
            end
            did_document_obj = do_read(database_obj, did_document_id, commit_id);
		end % read()

        function database_obj = remove(database_obj, did_document_id, varargin)
			% REMOVE - remove a document from an DATABASE
			%
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DID_DOCUMENT_ID, [COMMIT_ID], [PARAMS...])
			%
			% Removes the DID_DOCUMENT object with the 'document unique reference' equal
			% to DID_DOCUMENT_OBJ_ID. If an optional COMMIT_ID is specified, the
			% document is removed from the DB. Otherwise the last commit is removed.
			%
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'CommitId'  - followed by the requested commit_id
            %   - 'OnMissing' - followed by 'ignore', 'warn', or 'error' (default)
            % 
			% If a DID.DOCUMENT is passed, then the DID DOCUMENT_ID is extracted
			% using DID_DOCUMENT/DOC_UNIQUE_ID. If a cell array of DID.DOCUMENT
            % is passed instead, then all of the matching documents are removed.

            if isempty(did_document_id)
                return; % nothing to do
            end

            if ~iscell(did_document_id)
                did_document_id = {did_document_id};
            end

            did_document_id_list = {};
            for i=1:numel(did_document_id)
                if isa(did_document_id{i}, 'did_document')
                    did_document_id_list{end+1} = did_document_id{i}.id(); %#ok<AGROW>
                else
                    did_document_id_list{end+1} = did_document_id{i}; %#ok<AGROW>
                end
            end

            % Process optional input parameters
            idx = 1;
            while ~isempty(varargin) && mod(nargin,2) && idx <= numel(varargin)
                paramName = varargin{idx};
                if any(strcmpi(paramName,{'CommitId','OnMissing'}))
                    idx = idx + 2;
                else
                    varargin = [varargin(1:idx-1) 'CommitId' varargin(idx:end)];
                    break
                end
            end

            % Call the specific database's removal method
            for i=1:numel(did_document_id_list)
                do_remove(database_obj, did_document_id_list{i}, varargin{:});
            end
		end % remove()

		function database_obj = clear(database_obj, areYouSure)
			% CLEAR - remove/delete all records from an DATABASE
			% 
			% DATABASE_OBJ = CLEAR(DATABASE_OBJ, [AREYOUSURE])
			%
			% Removes all documents from the database object.
			% 
			% Use with care!
            % If AREYOUSURE='yes' the function will proceed, otherwise not.
			%
			% See also: DATABASE/REMOVE

            if nargin<2
                areYouSure = 'no';
            end
            if strcmpi(areYouSure,'Yes')
                ids = database_obj.all_doc_ids();
                for i=1:numel(ids)
                    database_obj.remove(ids{i}) % remove the entry
                end
            else
                disp('Not clearing because user did not indicate he/she is sure.');
            end
		end % clear

		function did_document_objs = search(database_obj, query_obj)
			% SEARCH - search for an DID_DOCUMENT from an DATABASE
			%
			% DOCUMENT_OBJS = SEARCH(DATABASE_OBJ, DID.QUERYOBJ)
			%
			% Performs a search of the database with a DID QUERY object.
			% 
			% This function returns a cell array of DID_DOCUMENT objects. If no
            % documents match the query, then an empty cell array ({}) is returned.

            did_document_objs = database_obj.do_search(query_obj);
		end % search()

		function doc_ids = all_doc_ids(database_obj) %#ok<MANU>
			% ALL_DOC_IDS - return all document unique reference numbers for the database
			%
			% DOC_IDS = ALL_DOC_IDS(DATABASE_OBJ)
			%
			% Return all document unique reference strings as a cell array of
            % strings. If there are no documents, empty is returned.
            %
            % This method is typically overloaded by the specific DB sub-class.

            doc_ids = {}; % needs to be overridden
        end % all_doc_ids()

		function commit_ids = all_commit_ids(database_obj) %#ok<MANU>
			% ALL_COMMIT_IDS - return all commit IDs for a DID database
			%
			% COMMIT_IDS = ALL_COMMIT_IDS(DATABASE_OBJ)
			%
			% Return a list of all commit IDs for the current database.
            %
            % This method is typically overloaded by the specific DB sub-class.
            
            commit_ids = {};
        end

        function did_document_obj = open_doc(database_obj, did_document_or_id, name)
			% OPEN_DOC - open and lock an DID.DOCUMENT that corresponds to a document id
			%
			% DID_DOCUMENT_OBJ = OPEN_DOC(DATABASE_OBJ, DID_DOCUMENT_OR_ID, NAME)
			%
			% Return the open DID.DOCUMENT object and COMMIT ID that corresponds
            % to the requested file record. 
			%
			% DID.DOCUMENT_OR_ID can be either the document id of an DID.DOCUMENT
            % or a DID.DOCUMENT object itsef.
			%
			% Note: close the document with DID_DOCUMENT_OBJ.close() when finished.
            %
            % See also: CLOSE_DOC

            if isa(did_document_or_id,'did.document')
                did_document_id = did_document_or_id.id();
            else
                did_document_id = did_document_or_id;
            end
            did_document_obj = do_open_doc(database_obj, did_document_id, name);
        end % open_doc

        function did_document_obj = close_doc(database_obj, did_document_obj)
			% CLOSE_DOC - close an open DID_DOCUMENT in the database 
			%
			% DID_DOCUMENT_OBJ = CLOSE_DOC(DATABASE_OBJ, DID_DOCUMENT_OBJ)
			%
			% Closes a DID_DOCUMENT_OBJ that was previously opened with OPEN_DOC().
			%
			% See also: OPEN_DOC 
            did_document_obj = do_close_doc(database_obj, did_document_obj);
		end % add()

        function data = run_sql_query(sqlitedb_obj, query_str, returnStruct)
            % run_sql_query - run an SQL query on the database
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
            data = do_run_sql_query(sqlitedb_obj, query_str);

            % Post-process the returned data
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
    end % methods database

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
		    did_document_ids = doc_ids;
	    end % do_search()
    end

    % Disregard these
    methods (Access=protected)
        function did_document_obj = do_open_doc(database_obj, did_document_id, version)
		    did_document_obj = [];
		    [fid, key] = database_obj.db.openbinaryfile(did_document_id, version);
		    if fid>0
			    [filename,permission,machineformat,encoding] = fopen(fid);
			    did_document_obj = did_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
				    'machineformat',machineformat,'permission',permission, 'doc_unique_id', did_document_id, 'key', key);
			    did_document_obj.frewind(); % move to beginning of the file
		    end
	    end % do_binarydoc()

        function did_document_obj = do_close_doc(database_obj, did_document_obj)
	    % DO_CLOSE_DOC - close and unlock an DID_DOC_OBJ
	    %
	    % DID_DOC_OBJ = DO_CLOSE_DOC(sqlitedb_obj, DID_DOC_OBJ)
	    %
	    % Close and unlock the file associated with DID_DOC_OBJ.

		    database_obj.db.closebinaryfile(did_document_obj.fid, ...
			    did_document_obj.key, did_document_obj.doc_unique_id);
		    did_document_obj.fclose(); 
	    end % do_close_doc()
    end

    % These methods *MUST* be overloaded by implementation subclasses
	methods (Abstract, Access=protected)
		database_obj     = do_add(database_obj, did_document_obj, add_parameters)
		did_document_obj = do_read(database_obj, did_document_id, commit_id)
		did_document_obj = do_remove(database_obj, did_document_id, varargin)
	end % Methods (Access=Protected) protected methods
end % classdef
