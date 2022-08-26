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
%   connection - Connection details for the database (might be a file name, directory name, or struct)
%   branch_id  - Branch ID that we are currently viewing/editing
%   dbid       - Database ID
%   frozen_branch_ids = Cell array of ids of branches that cannot be modified
%
% Public methods with a default implementation that should not be overloaded:
%   database - Create a new database object with no branches initially
%
%   all_branch_ids     - Return a cell-array of all branch IDs in the database
%   add_branch         - Create a new branch, at the current or specified branch
%   set_branch         - Set the current branch used by subsequent queries/actions
%   get_branch         - Return the current branch used by subsequent queries/actions
%   get_branch_parent  - Return the parent branch of the current/specified branch
%   get_sub_branches   - Returns array of sub-branches of the current/specified branch
%   freeze_branch      - Mark a branch as protected from further modification
%   is_branch_editable - Is current/specified branch locked for modification?
%   delete_branch      - Delete the current or specified branch, if not frozen
%   display_branches   - Display branches hierarchy under specified branch
%
%   get_doc_ids - Return a cell-array of all document IDs in the specific branch
%   add_doc     - Add a did.document to the current or specified branch
%   get_docs    - Return did.document(s) that match the specified document ID(s)
%   remove_doc  - Remove a did.document from the current or specified branch
%   open_doc    - Open binary portion of a did.document for read/write (returns a did.binarydoc)
%   close_doc   - Close an open did.binarydoc
%
%   search - Search current/specified branch for did.document(s) matching a did.query
%   run_sql_query - Run the specified SQL query in the database
%
% Protected methods with a default implementation that *MAY* be overloaded:
%   do_search      - implements the core logic for the search() method
%   do_open_doc    - implements the core logic for the open_doc() method
%   do_close_doc   - implements the core logic for the close_doc() method
%   delete - destructor (typically closes the database connection/file, if open)
% 
% Protected methods that *MUST* be overloaded by specific subclass implementations:
%   do_run_sql_query  - implements the core logic for the run_sql_query() method
%
%   do_get_branch_ids - implements the core logic for the all_branch_ids() method
%   do_add_branch     - implements the core logic for the add_branch() method
%   do_delete_branch  - implements the core logic for the delete_branch() method
%   do_get_branch_parent - implements core logic for the get_branch_parent() method
%   do_get_sub_branches  - implements core logic for the get_sub_branches() method
%
%   do_get_doc_ids    - implements the core logic for the all_doc_ids() method
%   do_add_doc        - implements the core logic for the add_doc() method
%   do_get_doc        - implements the core logic for the get_doc() method, for a single doc_id
%   do_remove_doc     - implements the core logic for the remove_doc() method

    % Read-only properties
	properties (SetAccess=protected, GetAccess=public)
		connection % A variable or struct describing the connection parameters of the database; may be a simple file path
		branch_id  % The branch ID that we are viewing/editing at the moment
        dbid       % Database ID
        frozen_branch_ids = {} % Cell array of ids of branches that cannot be modified
	end % properties

    % Main database constructor
	methods
		function database_obj = database(varargin)
			% DATABASE - create a new DATABASE
			%
			% DATABASE_OBJ = DATABASE(...)
			%
			% Creates a new DATABASE object 
			
			connection = '';
			branchId = '';

			if nargin>0
				connection = varargin{1};
			end

			database_obj.connection = connection;
			database_obj.branch_id = branchId;
		end % database
    end

    % Branch-related methods
    methods
		function branch_ids = all_branch_ids(database_obj)
			% ALL_BRANCH_IDS - return all branch IDs for a DID database
			%
			% BRANCH_IDS = ALL_BRANCH_IDS(DATABASE_OBJ)
			%
			% Return a cell array of all branch IDs in the database.
    	    % If there are no branches, an empty cell array is returned.
            
            branch_ids = database_obj.do_get_branch_ids();
        end % all_branch_ids()

        function add_branch(database_obj, branch_id, parent_branch_id)
			% ADD_BRANCH - Adds a new database branch based on specified parent branch
			%
			% ADD_BRANCH(DATABASE_OBJ, BRANCH_ID, [PARENT_BRANCH_ID])
			%
			% Adds a new branch with the specified BRANCH_ID to the database,
            % based on (duplicating) the specified PARENT_BRANCH_ID.
            % If PARENT_BRANCH_ID is empty or not specified, the current branch is used.
            %
            % An error is generated if PARENT_BRANCH_ID does not exist in the
            % database, or if BRANCH_ID already exists in the database, or if
            % the specified BRANCH_ID is empty or not a string.
            %
            % The current database branch is set to the newly-created BRANCH_ID.

            % If parent_branch_id was not specified, use the current branch
            if nargin < 3 || isempty(parent_branch_id)
                parent_branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            [branch_id, branch_ids] = database_obj.validate_branch_id(branch_id, false);
            if ismember(branch_id, branch_ids)
                error('DID:Database:InvalidBranch','Branch id "%s" already exists in the database',branch_id);
            elseif ~ismember(parent_branch_id, branch_ids) && ~isempty(parent_branch_id)
                error('DID:Database:InvalidBranch','Parent branch id "%s" does not exist in the database',parent_branch_id);
            end

            % Add the new branch to the database
            check_parent = ~isempty(parent_branch_id); %only check if not empty
            parent_branch_id = database_obj.validate_branch_id(parent_branch_id, check_parent);
            database_obj.do_add_branch(branch_id, parent_branch_id);

            % The new branch was successfully added - set current branch to it
            database_obj.branch_id = branch_id;
        end % add_branch()

        function set_branch(database_obj, branch_id)
			% SET_BRANCH - Sets the current database branch
			%
			% SET_BRANCH(DATABASE_OBJ, BRANCH_ID)
			%
			% Sets the current database branch to the specified BRANCH_ID.
            % An error is generated if BRANCH_ID does not exist in the database.

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Update the current database branch
            database_obj.branch_id = branch_id;
        end % set_branch()

        function branch_id = get_branch(database_obj)
			% GET_BRANCH - Returns the current database branch
			%
			% BRANCH_ID = GET_BRANCH(DATABASE_OBJ)

            % Return the current database branch
            branch_id = database_obj.branch_id;
        end % get_branch()

        function parent_branch_id = get_branch_parent(database_obj, branch_id)
			% GET_BRANCH_PARENT - Return the id of the specified branch's parent
			%
			% PARENT_BRANCH_ID = GET_BRANCH_PARENT(DATABASE_OBJ, [BRANCH_ID])
			%
			% Returns the ID of the parent branch for the specified BRANCH_ID.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is generated if BRANCH_ID does not exist in the database.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Get the branch'es parent branch id
            parent_branch_id = database_obj.do_get_branch_parent(branch_id);
        end % get_branch_parent()

        function branch_ids = get_sub_branches(database_obj, branch_id)
			% GET_SUB_BRANCHES - Return the IDs of sub-branches of a branch
			%
			% BRANCH_IDS = GET_SUB_BRANCHES(DATABASE_OBJ, [BRANCH_ID])
			%
			% Returns the ID of sub-branches for the specified BRANCH_ID.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is generated if BRANCH_ID does not exist in the database.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Get the branch's sub-branch ids
            branch_ids = database_obj.do_get_sub_branches(branch_id);
        end % get_sub_branches()

        function freeze_branch(database_obj, branch_id)
			% FREEZE_BRANCH - Freeses specified branch from further modification
			%
			% FREEZE_BRANCH(DATABASE_OBJ, [BRANCH_ID])
			%
			% Indicates the specified BRANCH_ID as protected from modification.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is generated if BRANCH_ID does not exist in the database.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Add the branch to the list of frozen branches
            database_obj.frozen_branch_ids = unique([database_obj.frozen_branch_ids branch_id]);
        end % freeze_branch()

        function tf = is_branch_editable(database_obj, branch_id)
			% IS_BRANCH_EDITABLE - Returns true if branch has no sub-branches and is not frozen
			%
			% TF = IS_BRANCH_EDITABLE(DATABASE_OBJ, [BRANCH_ID])
			%
			% Returns a logical true/false flag indicating whether the specified
            % BRANCH_ID can be modified/deleted (not frozen and no sub-branches).
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is generated if BRANCH_ID does not exist in the database.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Branch is editable only if it's not frozen AND has no sub-branches
            tf = ~ismember(branch_id, database_obj.frozen_branch_ids) && ...
                 isempty(database_obj.do_get_sub_branches(branch_id));
        end % is_branch_editable()

        function delete_branch(database_obj, branch_id)
			% DELETE_BRANCH - Deletes the specified branch from the database
			%
			% DELETE_BRANCH(DATABASE_OBJ, [BRANCH_ID])
			%
			% Removes all documents in the specified BRANCH_ID and then deletes
            % the branch itself.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            %
            % An error is generated if BRANCH_ID does not exist in the database,
            % or if the branch is marked as frozen or has any sub-branches.
            %
            % The current database branch is set to the root BRANCH_ID if the
            % deleted branch was the current branch.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            [branch_id, branch_ids] = database_obj.validate_branch_id(branch_id);
            if ismember(branch_id, database_obj.frozen_branch_ids)
                error('DID:Database:FrozenBranch','Branch id "%s" is frozen and cannot be deleted',branch_id);
            elseif ~isempty(database_obj.get_sub_branches(branch_id))
                error('DID:Database:ParentBranch','Branch id "%s" has sub-branches and cannot be deleted',branch_id);
            end

            % Delete the branch from the database
    		database_obj.do_delete_branch(branch_id)

            % Remove the branch from the list of frozen branches
            database_obj.frozen_branch_ids = setdiff(database_obj.frozen_branch_ids,branch_id);

            % If this was the current branch, update the current branch to root
            if isequal(database_obj.branch_id, branch_id)
                database_obj.branch_id = branch_ids{1};
                if isequal(database_obj.branch_id, branch_id)
                    % Root branch was deleted - reset current branch id to none
                    database_obj.branch_id = '';
                end
            end
        end % delete_branch()

        function display_branches(database_obj, branch_id)
			% DISPLAY_BRANCHES - Display branches hierarchy under specified branch
			%
			% DISPLAY_BRANCHES(DATABASE_OBJ, [BRANCH_ID])
			%
			% Display all branches whose ancestor is the specified BRANCH_ID.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is generated if BRANCH_ID does not exist in the database.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Display the hierarchy recursively
            display_sub_branches(branch_id, 0);

            function display_sub_branches(branch_id,indent)
                % Display the current branch
                disp([repmat('  ',1,indent) ' - ' branch_id])

                % Loop over all sub-branches of this branch
                sub_ids = database_obj.get_sub_branches(branch_id);
                for i = 1 : numel(sub_ids)
                    display_sub_branches(sub_ids{i},indent+1)
                end
            end
        end % set_branch()
    end

    % Document-related methods
    methods
        function doc_ids = get_doc_ids(database_obj, branch_id)
			% GET_DOC_IDS - return all document identifiers in a database branch
			%
			% DOC_IDS = GET_DOC_IDS(DATABASE_OBJ, [BRANCH_ID])
			%
			% Return all document unique reference strings as a cell array of
            % strings. If there are no documents, empty is returned.
            %
            % If BRANCH_ID is empty or not specified, the current branch is used.

            % If branch_id was not specified, use the current branch
            if nargin < 2 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Get the doc_ids within the specified branch from the database
            doc_ids = database_obj.do_get_doc_ids(branch_id);
        end % all_doc_ids()

        function add_doc(database_obj, document_obj, branch_id, varargin)
			% ADD - add a DID.DOCUMENT object to the specified branch
			%
			% DATABASE_OBJ = ADD(DATABASE_OBJ, DOCUMENT_OBJ, [BRANCH_ID], [PARAMS...])
			%
			% Adds the document DOCUMENT_OBJ to the specified BRANCH_ID.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            %
            % An error is generated if the branch is frozen and cannot be modified.
			%
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnDuplicate' - followed by 'ignore', 'warn', or 'error' (default)

            % Ensure we got a valid input doc object
            if isempty(document_obj)
                return; % nothing to do
            elseif ~isa(document_obj,'did.document') && ~isstruct(document_obj)
                error('DID:Database:InvalidDoc','Invalid doc specified in did.database.add_doc() call - must be a valid did.document object');
            end

            % Parse the input parameters
            if mod(numel(varargin),2) == 1  % odd number of values
                if any(strcmpi(branch_id,'OnDuplicate'))
                    % the specified branch_id is actually a param name
                    branch_id = database_obj.branch_id;
                    varargin = ['OnDuplicate' varargin];
                else
                    error('DID:Database:InvalidParams','Invalid parameters specified in did.database.add_doc() call');
                end
            elseif nargin > 3 && ~any(strcmpi(varargin{1},'OnDuplicate'))
                error('DID:Database:InvalidParams','Invalid parameters specified in did.database.add_doc() call');
            end

            % If branch_id was not specified, use the current branch
            if nargin < 3 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Call the specific database's addition method
            database_obj.do_add_doc(document_obj, branch_id, varargin{:});
        end % add_doc()

        function document_objs = get_docs(database_obj, document_ids, varargin)
			% GET_DOC - Return DID.DOCUMENT object(s) that match the specified doc ID(s)
			%
			% DOCUMENT_OBJS = GET_DOC(DATABASE_OBJ, [DOCUMENT_IDS], [PARAMS]) 
			%
			% Returns the DID.DOCUMENT object with the specified by DOCUMENT_IDS. 
            % DOCUMENT_IDS may be a scalar ID string, or a cell-array of IDs
            % (in this case, an array of corresponding doc objects is returned).
            %
            % If DOCUMENT_IDS is not specified, the get_doc_ids() method is used
            % to fetch the document IDs of the current branch, which are then
            % used by this method.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnMissing' - followed by 'ignore', 'warn', or 'error' (default)

            % Parse the input parameters
            if mod(nargin,2) == 1  % odd number of input args
                if any(strcmpi(document_ids,'OnMissing'))
                    % the specified document_ids is actually a param name
                    document_ids = database_obj.get_doc_ids();
                    varargin = ['OnMissing' varargin];
                else
                    error('DID:Database:InvalidParams','Invalid parameters specified in did.database.get_doc() call');
                end
            elseif nargin > 2 && ~any(strcmpi(varargin{1},'OnMissing'))
                error('DID:Database:InvalidParams','Invalid parameters specified in did.database.get_doc() call');
            end

            % Initialize an empty results array of no objects
            document_objs = did.document.empty;

            % If document ids were not specified, get them from the current branch
            if nargin < 2
                document_ids = database_obj.get_doc_ids();
            end
            if isempty(document_ids)
                document_objs = did.document.empty;
                return
            end

            % Loop over all specified doc_ids
            if ~iscell(document_ids), document_ids = {document_ids}; end
            numDocs = numel(document_ids);
            for i = 1 : numDocs
                % Fetch the document object from the database
                doc_id = database_obj.validate_doc_id(document_ids{i}, false);
                document_objs(i) = database_obj.do_get_doc(doc_id, varargin{:});
            end

            % Reshape the output array based on the input array's dimensions
            if numDocs > 1
                document_objs = reshape(document_objs,size(document_ids));
            end
        end % get_doc()

        function remove_doc(database_obj, document_ids, branch_id, varargin)
			% REMOVE - remove a document from an DATABASE
			%
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DOCUMENT_IDS, [BRANCH_ID], [PARAMS...])
			%
			% Removes specified DOCUMENT_IDS from the specified BRANCH_ID.
            % If BRANCH_ID is empty or not specified, the current branch is used.
            %
            % DOCUMENT_IDS may be a single document ID or cell array of IDs.
            % Any of the specified DOCUMENT_IDS may be a DID.DOCUMENT object
            % or a unique document ID for such a DID.DOCUMENT object.
            %
            % An error is generated if the specified BRANCH_ID does not exist
            % in the database, or if any of the DOCUMENT_IDS do not exist
            % in the specified branch.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value. The following parameters are possible:
            %   - 'OnMissing' - followed by 'ignore', 'warn', or 'error' (default)

            % Parse the input document_ids
            if isempty(document_ids)
                return; % nothing to do
            end
            if ~iscell(document_ids)
                document_ids = {document_ids};
            end

            % Parse the input parameters
            if mod(numel(varargin),2) == 1  % odd number of values
                if any(strcmpi(branch_id,'OnMissing'))
                    % the specified branch_id is actually a param name
                    branch_id = database_obj.branch_id;
                    varargin = ['OnMissing' varargin];
                else
                    error('DID:Database:InvalidParams','Invalid parameters specified in did.database.remove_doc() call');
                end
            elseif nargin > 3 && ~any(strcmpi(varargin{1},'OnMissing'))
                error('DID:Database:InvalidParams','Invalid parameters specified in did.database.remove_doc() call');
            end

            % If branch_id was not specified, use the current branch
            if nargin < 3 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Loop over all the specified documents
            for i = 1 : numel(document_ids)
                % Replace did.document object reference with its unique doc id
                doc_id = database_obj.validate_doc_id(document_ids{i}, false);
   
                % Call the specific database's removal method
                database_obj.do_remove_doc(doc_id, branch_id, varargin{:});

                % TODO also delete all documents that depend on the deleted doc
            end
        end % remove_doc()

        function document_obj = open_doc(database_obj, document_id)
			% OPEN_DOC - open and lock a specified DID.DOCUMENT in the database
			%
			% DOCUMENT_OBJ = OPEN_DOC(DATABASE_OBJ, DOCUMENT_ID)
			%
			% Return a DID.DOCUMENT object matching the specified DOCUMENT_ID. 
			%
			% DID.DOCUMENT_ID can be either the document id of a DID.DOCUMENT
            % or a DID.DOCUMENT object itsef.
			%
			% Note: close the document with DOCUMENT_OBJ.close() when finished.
            %
            % See also: CLOSE_DOC

            % Validate document ID validity (extract ID from object if needed)
            document_id = database_obj.validate_doc_id(document_id, false);

            % Open the document
            document_obj = database_obj.do_open_doc(document_id);
        end % open_doc()

        function close_doc(database_obj, document_obj)
			% CLOSE_DOC - close an open DID.DOCUMENT file
			%
			% DOCUMENT_OBJ = CLOSE_DOC(DATABASE_OBJ, DOCUMENT_OBJ)
			%
			% Closes a DOCUMENT_OBJ that was previously opened with OPEN_DOC().
			%
			% See also: OPEN_DOC 

            database_obj.do_close_doc(document_obj);
        end % close_doc()
    end

    % Search-related methods
    methods
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

            % Run the SQL using the specific internal database implementation
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

        function document_ids = search(database_obj, query_obj, branch_id)
			% SEARCH - find matching DID.DOCUMENTs in the specified branch
			%
			% DOCUMENT_IDS = SEARCH(DATABASE_OBJ, DID.QUERYOBJ, [BRANCH_ID])
			%
			% Search the specified BRANCH_ID using a DID QUERY object, return a
            % list of matching DID.DOCUMENT IDs.
            %
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is genereted if the specified BRANCH_ID does not exist.
			% 
			% This function returns a cell array of DID.DOCUMENT IDs. If no
            % documents match the query, an empty cell array ({}) is returned.

            % If branch_id was not specified, use the current branch
            if nargin < 3 || isempty(branch_id)
                branch_id = database_obj.branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Call the specific database's search method, return matching doc IDs
            document_ids = database_obj.do_search(query_obj, branch_id);
		end % search()
    end
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
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasmember' %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasfield'  %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'partial_struct'  %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasanysubfield_contains_string'  %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasanysubfield_exact_string'     %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'regexp'
                    sql_str = ['fields.field_name="' field '" AND regex(doc_data.value,"' param1 '") NOT NULL'];
                case 'isa'
                    sql_str = ['(fields.field_name="meta.class" AND doc_data.value = "' param1 '") OR ' ...
                               '(fields.field_name="meta.superclass" AND doc_data.value like "%' param1 '%")'];
                otherwise
                    %error('DID:Database:SQL','Unrecognized query operation "%s"',op);
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
            end
            sql_str = ['(' sql_str ')'];
            if isNot
                sql_str = ['NOT ' sql_str];
            end
        end
        function query_str = get_sql_query_str(sqlitedb_obj, query_structs, branch_id)
            query_str = ['SELECT DISTINCT docs.doc_id ' ...
                         'FROM   docs, branch_docs, doc_data, fields ' ...
                         'WHERE  docs.doc_idx = doc_data.doc_idx ' ...
                         '  AND  docs.doc_idx = branch_docs.doc_idx ' ...
                         '  AND  branch_docs.branch_id = "' branch_id '" ' ...
                         '  AND  fields.field_idx = doc_data.field_idx ' ...
                         '  AND  fields.field_idx = doc_data.field_idx'];
                         %((fields.field_name = "meta.class" AND doc_data.value = "ndi_document") OR (fields.field_name = "meta.superclass" AND doc_data.value like "%ndi_document%"))')';
            for i = 1 : numel(query_structs)
                sql_str = query_struct_to_sql_str(sqlitedb_obj, query_structs(i));
                if ~isempty(sql_str)
                    query_str = [query_str ' AND ' sql_str]; %#ok<AGROW>
                end
            end
        end
        function doc_ids = search_doc_ids(sqlitedb_obj, query_struct, branch_id)
            % search_doc_ids - recursively search the database for matching doc IDs

            num_structs = numel(query_struct);
            if num_structs > 1  % loop over all &-ed queries
                doc_ids = {};
                for i = 1 : num_structs
                    new_doc_ids = search_doc_ids(sqlitedb_obj, query_struct(i), branch_id);
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
                    doc_ids1 = search_doc_ids(sqlitedb_obj, query_struct.param1, branch_id);
                    doc_ids2 = search_doc_ids(sqlitedb_obj, query_struct.param2, branch_id);
                    doc_ids = union(doc_ids1, doc_ids2);
                    if size(doc_ids,1)==1 && size(doc_ids,2)>1
                        doc_ids = doc_ids';  % ensure column vector
                    end
                else  % leaf scalar query
                    query_str = get_sql_query_str(sqlitedb_obj, query_struct, branch_id);
                    doc_ids = run_sql_query(sqlitedb_obj, query_str);
                end
            end
            if numel(doc_ids)==1 && iscell(doc_ids{1})
                doc_ids = doc_ids{1};  %de-cell
            end
        end
        function document_ids = do_search(sqlitedb_obj, query_obj, branch_id)
            % do_search - searches a branch for doc_ids that match specified query
        
            % Convert the query object into an SQL query string
            if isa(query_obj,'did.query')
			    query_obj = query_obj.searchstructure;
            end

            % Run the SQL query on the DB and return the matching documents
            if isstruct(query_obj)
                doc_ids = sqlitedb_obj.search_doc_ids(query_obj, branch_id);
            else  % already in SQL str format
                query_str = query_obj;
                doc_ids = sqlitedb_obj.run_sql_query(query_str);
            end
            if numel(doc_ids)==1 && iscell(doc_ids{1})
                doc_ids = doc_ids{1};  %de-cell
            end

            % Return the matching documents' IDs
		    document_ids = doc_ids;
	    end % do_search()
    end

    % These methods *MUST* be overloaded by implementation subclasses
	methods (Abstract, Access=protected)
        results = do_run_sql_query(database_obj, query_str, varargin)

        branch_ids = do_get_branch_ids(database_obj)
        do_add_branch(database_obj, branch_id, parent_branch_id, varargin)
		do_delete_branch(database_obj, branch_id, varargin)
        parent_branch_id = do_get_branch_parent(database_obj, branch_id, varargin)
        branch_ids = do_get_sub_branches(database_obj, branch_id, varargin)

        doc_ids = do_get_doc_ids(database_obj, branch_id, varargin)
		do_add_doc(database_obj, document_obj, branch_id, varargin)
		document_obj = do_get_doc(database_obj, document_id, varargin)
		do_remove_doc(database_obj, document_id, branch_id, varargin)
    end

    % Disregard these
    methods (Access=protected)
        function document_obj = do_open_doc(database_obj, document_id)
		    document_obj = [];
		    [fid, key] = database_obj.db.openbinaryfile(document_id);
		    if fid>0
			    [filename,permission,machineformat,encoding] = fopen(fid); %#ok<ASGLU>
			    document_obj = did_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
				    'machineformat',machineformat,'permission',permission, 'doc_unique_id', document_id, 'key', key);
			    document_obj.frewind(); % move to beginning of the file
		    end
	    end % do_binarydoc()
        function do_close_doc(database_obj, document_obj)
    	    % DO_CLOSE_DOC - close and unlock a DID.DOCUMENT object
    	    %
    	    % DO_CLOSE_DOC(sqlitedb_obj, DOCUMENT_OBJ)
    	    %
    	    % Close and unlock the file associated with DOCUMENT_OBJ.

		    database_obj.db.closebinaryfile(document_obj.fid, document_obj.key, document_obj.doc_unique_id);
		    document_obj.fclose(); 
	    end % do_close_doc()
    end

    % General utility functions used by this class that don't depend on a class object
    methods (Access=protected)
        function [branch_id, branch_ids] = validate_branch_id(database_obj, branch_id, check_existance)
            % The branch_id must be a non-empty string
            if isstring(branch_id), branch_id = char(branch_id); end
            if isempty(branch_id) || ~ischar(branch_id)
                error('DID:Database:InvalidBranch','Branch ID must be a non-empty string');
            end

            % Optionally ensure that the branch exists in the database
            if nargin < 3 || check_existance
                branch_ids = database_obj.all_branch_ids();
                if ~ismember(branch_id, branch_ids)
                    error('DID:Database:InvalidBranch','Branch ID "%s" does not exist in the database',branch_id);
                end
            elseif nargout > 1
                branch_ids = database_obj.all_branch_ids();
            end
        end

        function doc_id = validate_doc_id(database_obj, doc_id, check_existance)
            % The doc_id must be a non-empty string
            if isstring(doc_id), doc_id = char(doc_id); end
            if isa(doc_id, 'did_document')
                doc_id = doc_id.id();
            elseif isempty(doc_id) || ~ischar(doc_id)
                error('DID:Database:InvalidDocID','Document ID must be a non-empty string');
            end

            % Optionally ensure that the branch exists in the database
            if nargin < 3 || check_existance
                doc_ids = database_obj.get_doc_ids();
                if ~ismember(doc_id, doc_ids)
                    error('DID:Database:InvalidDocID','Document ID "%s" does not exist in the database',doc_id);
                end
            end
        end
    end

    % General utility functions used by this class that don't depend on a class object
    methods (Access=protected, Static)
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
    end

end % database classdef
