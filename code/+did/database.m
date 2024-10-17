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
%   connection - Database connection details (e.g. file/folder name or a struct)
%   dbid       - Database ID (set by the specific implementation class)
%   version    - Database version (set by the specific implementation class)
%   current_branch_id - Branch ID that we are currently viewing/editing
%   frozen_branch_ids - Cell array of ids of branches that cannot be modified
%
% Properties (read/write):
%   debug      - Whether to display debug info in console (default: false)
%
% Public methods with a default implementation that should not be overloaded:
%   database - Create a new database object with no branches initially
%
%   all_branch_ids     - Return a cell-array of all branch IDs in the database
%   add_branch         - Create a new branch, at the current or specified branch
%   set_branch         - Set the current branch used by subsequent queries/actions
%   get_branch         - Return current branch, used by subsequent queries/actions
%   get_branch_parent  - Return the parent branch of the current/specified branch
%   get_sub_branches   - Return array of sub-branches of current/specified branch
%   freeze_branch      - Mark a branch as protected from further modification
%   is_branch_editable - Is current/specified branch locked for modification?
%   delete_branch      - Delete the current or specified branch, if not frozen
%   display_branches   - Display branches hierarchy under specified branch
%
%   all_doc_ids - Return a cell-array of all document IDs in the database
%   get_doc_ids - Return a cell-array of all document IDs in the specific branch
%   add_docs    - Add did.document(s) to the current or specified branch
%   get_docs    - Return did.document(s) that match the specified document ID(s)
%   remove_docs - Remove did.document(s) from the current or specified branch
%   open_doc    - Return a did.file.fileobj wrapper for a file in a did.document
%   close_doc   - Close an open did.binarydoc
%
%   get_preference_names - return cell-array of defined database pref names
%   set_preference - set new value to a preference name in this database
%   get_preference - get the value of a preference name in this database
%
%   search - Search current/specified branch for did.document(s) matching a did.query
%   run_sql_query - Run the specified SQL query in the database, return results
%
% Protected methods with a default implementation that *MAY* be overloaded:
%   do_search            - core logic for database.search()
%   do_close_doc         - core logic for database.close_doc()
%   delete - destructor (typically closes the database connection/file, if open)
% 
% Protected methods that *MUST* be overloaded by specific subclass implementations:
%   do_run_sql_query     - core logic for database.run_sql_query()
%
%   do_get_branch_ids    - core logic for database.all_branch_ids()
%   do_add_branch        - core logic for database.add_branch()
%   do_delete_branch     - core logic for database.delete_branch()
%   do_get_branch_parent - core logic for database.get_branch_parent()
%   do_get_sub_branches  - core logic for database.get_sub_branches()
%
%   do_get_doc_ids       - core logic for database.get_doc_ids()
%   do_add_doc           - core logic for database.add_docs(),    for a single doc
%   do_get_doc           - core logic for database.get_doc(),     for a single doc
%   do_open_doc          - core logic for database.open_doc(),    for a single doc
%   do_remove_doc        - core logic for database.remove_docs(), for a single doc

    % Read-only properties
	properties (SetAccess=protected, GetAccess=public)
		connection % A variable or struct describing the connection parameters of the database; may be a simple file path
        dbid       % Database ID
        version    % Database version

        current_branch_id = '' % The branch ID that we are viewing/editing at the moment
        frozen_branch_ids = {} % Cell array of ids of branches that cannot be modified
	end % properties

    properties (Access=protected)
        preferences
    end % properties

    % Public read/write properties
    properties (Access=public)
        debug (1,1) logical = false  % Display debug info in console? (default: false)
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
			database_obj.current_branch_id = branchId;
			database_obj.preferences = containers.Map;
		end % database
    end

    methods % Database open
        function [hCleanup, filename] = open(database_obj)
            [hCleanup, filename] = database_obj.open_db();
        end
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
                parent_branch_id = database_obj.current_branch_id;
            end

            % Ensure branch IDs validity
            [branch_id, branch_ids] = database_obj.validate_branch_id(branch_id, false);
            if ismember(branch_id, branch_ids)
                error('DID:Database:InvalidBranch','Branch id "%s" already exists in the database',branch_id);
            elseif ~ismember(parent_branch_id, branch_ids) && ~isempty(parent_branch_id)
                error('DID:Database:InvalidBranch','Parent branch id "%s" does not exist in the database',parent_branch_id);
            end

            % Add the new branch to the database
            if ~isempty(parent_branch_id) %only check if not empty
                parent_branch_id = database_obj.validate_branch_id(parent_branch_id);
            end
            database_obj.do_add_branch(branch_id, parent_branch_id);

            % The new branch was successfully added - set current branch to it
            database_obj.current_branch_id = branch_id;
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
            database_obj.current_branch_id = branch_id;
        end % set_branch()

        function branch_id = get_branch(database_obj)
			% GET_BRANCH - Returns the current database branch
			%
			% BRANCH_ID = GET_BRANCH(DATABASE_OBJ)

            % Return the current database branch
            branch_id = database_obj.current_branch_id;
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
                branch_id = database_obj.current_branch_id;
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
                branch_id = database_obj.current_branch_id;
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
                branch_id = database_obj.current_branch_id;
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
                branch_id = database_obj.current_branch_id;
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
                branch_id = database_obj.current_branch_id;
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
            if isequal(database_obj.current_branch_id, branch_id)
                database_obj.current_branch_id = branch_ids{1};
                if isequal(database_obj.current_branch_id, branch_id)
                    % Root branch was deleted - reset current branch id to none
                    database_obj.current_branch_id = '';
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
                branch_id = database_obj.current_branch_id;
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
		function doc_ids = all_doc_ids(database_obj)
			% ALL_DOC_IDS - return all document IDs for a DID database
			%
			% DOC_IDS = ALL_DOC_IDS(DATABASE_OBJ)
			%
			% Return a cell array of all document IDs in the database.
    	    % If there are no documents, an empty cell array is returned.
            
            doc_ids = database_obj.do_get_doc_ids();
        end % all_branch_ids()

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
                branch_id = database_obj.current_branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Get the doc_ids within the specified branch from the database
            doc_ids = database_obj.do_get_doc_ids(branch_id);
        end % all_doc_ids()

        function add_docs(database_obj, document_objs, branch_id, varargin)
			% ADD_DOCS - add did.document object(s) to the specified branch
			%
			% ADD_DOCS(DATABASE_OBJ, DOCUMENT_OBJS, [BRANCH_ID], [PARAMETERS...])
			%
			% Adds the DOCUMENT_OBJS to the specified BRANCH_ID, subject to a
            % schema validation check. DOCUMENT_OBJS may be a single did.document
            % object, struct, or an array of such (either regular or cell array).
            %
            % If BRANCH_ID is empty or not specified, the current branch is used.
            %
            % An error is generated if the branch is frozen and cannot be modified.
			%
            % Optional PARAMETERS may be specified as P-V pairs of parameter name
            % followed by parameter value. The following parameters are accepted:
            %   - 'OnDuplicate' - followed by 'ignore', 'warn', or 'error' (default)

            % Ensure we got a valid input doc object
            if isempty(document_objs)
                return; % nothing to do
            else
                % Ensure all documents are either a struct or did.document object
                for idx = 1 : numel(document_objs)
                    doc = document_objs(idx);
                    if iscell(doc), doc = doc{1}; end
                    if ~(isa(doc,'did.document') || isa(doc,'ndi.document')) && ~isstruct(doc)
                        error('DID:Database:InvalidDoc','Invalid doc specified in did.database.add_docs() call - must be a valid did.document object');
                    end
                end
            end

            % Parse the input parameters
            if mod(numel(varargin),2) == 1  % odd number of values
                if any(strcmpi(branch_id,'OnDuplicate'))
                    % the specified branch_id is actually a param name
                    branch_id = database_obj.current_branch_id;
                    varargin = ['OnDuplicate' varargin];
                else
                    error('DID:Database:InvalidParams','Invalid parameters specified in did.database.add_doc() call');
                end
            elseif nargin > 3 && ~any(strcmpi(varargin{1},'OnDuplicate'))
                error('DID:Database:InvalidParams','Invalid parameters specified in did.database.add_doc() call');
            end

            % If branch_id was not specified, use the current branch
            if nargin < 3 || isempty(branch_id)
                branch_id = database_obj.current_branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Ensure that all the input docs pass schema validation
            database_obj.validate_docs(document_objs);

            % Call the database's addition method separately for each doc
            for idx = 1 : numel(document_objs)
                doc = document_objs(idx);
                if iscell(doc), doc = doc{1}; end
                if database_obj.debug
                    try
                        docProps = doc.document_properties;
                        doc_id = docProps.base.id;
                        try
                            className = docProps.document_class.class_name;
                        catch
                            className = '<unknown class>';
                        end
                        fprintf('Adding %s doc %s to database branch %s\n', ...
                                className, doc_id, branch_id);
                    catch
                    end
                end
                database_obj.do_add_doc(doc, branch_id, varargin{:});
            end
        end % add_doc()

        function document_objs = get_docs(database_obj, document_ids, varargin)
			% GET_DOCS - Return did.document object(s) that match the specified doc ID(s)
			%
			% DOCUMENT_OBJS = GET_DOCS(DATABASE_OBJ, [DOCUMENT_IDS], [PARAMETERS...]) 
			%
			% Returns the did.document object for the specified by DOCUMENT_IDS. 
            % DOCUMENT_IDS may be a scalar ID string, or an array of IDs
            % (in this case, an array of corresponding doc objects is returned).
            %
            % If DOCUMENT_IDS is not specified, the get_doc_ids() method is used
            % to fetch the document IDs of the current branch, which are then
            % used by this method.
            %
            % Optional PARAMETERS may be specified as P-V pairs of parameter name
            % followed by parameter value. The following parameters are accepted:
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
            document_ids = database_obj.normalizeDocIDs(document_ids);
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

        function remove_docs(database_obj, documents, branch_id, varargin)
			% REMOVE_DOCS - remove did.document object(s) from a database branch
			%
			% REMOVE_DOCS(DATABASE_OBJ, DOCUMENTS, [BRANCH_ID], [PARAMETERS...])
			%
			% Removes the specified DOCUMENTS from the specified database branch.
            % DOCUMENTS may be a single document or an array of documents.
            % Any of the specified DOCUMENTS may be a did.document object,
            % or a unique document ID for a did.document object.
            %
            % If BRANCH_ID is empty or not specified, the current branch is used.
            %
            % An error is generated if the specified BRANCH_ID does not exist
            % in the database. Depending on the value of the optional OnMissing
            % parameter, an error may also be generated if any of the DOCUMENTS
            % do not exist in the specified branch.
            %
            % Optional PARAMETERS may be specified as P-V pairs of parameter name
            % followed by parameter value. The following parameters are accepted:
            %   - 'OnMissing' - followed by 'ignore', 'warn', or 'error' (default)

            % Parse the input document_ids, convert to a cell-array of char ids
            if isempty(documents)
                return  % nothing to do
            end
            documents = database_obj.normalizeDocIDs(documents);

            % Parse the input parameters
            if mod(numel(varargin),2) == 1  % odd number of values
                if any(strcmpi(branch_id,'OnMissing'))
                    % the specified branch_id is actually a param name
                    branch_id = database_obj.current_branch_id;
                    varargin = ['OnMissing' varargin];
                else
                    error('DID:Database:InvalidParams','Invalid parameters specified in did.database.remove_doc() call');
                end
            elseif nargin > 3 && ~any(strcmpi(varargin{1},'OnMissing'))
                error('DID:Database:InvalidParams','Invalid parameters specified in did.database.remove_doc() call');
            end

            % If branch_id was not specified, use the current branch
            if nargin < 3 || isempty(branch_id)
                branch_id = database_obj.current_branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Loop over all the specified documents
            for i = 1 : numel(documents)
                % Replace did.document object reference with its unique doc id
                doc_id = database_obj.validate_doc_id(documents{i}, false);
   
                % Call the specific database's removal method
                try, % failure is not an error
                database_obj.do_remove_doc(doc_id, branch_id, varargin{:});
                end

                % TODO also delete all documents that depend on the deleted doc
            end
        end % remove_doc()

        function file_obj = open_doc(database_obj, document_id, filename, varargin)
			% OPEN_DOC - open and lock a specified did.document in the database
			%
			% FILE_OBJ = OPEN_DOC(DATABASE_OBJ, DOCUMENT_ID, FILENAME, [PARAMS])
			%
			% Return a DID.FILE.READONLY_FILEOBJ object for a data file within
            % the specified DOCUMENT_ID. The requested filename should be
            % specified using the (mandatory) FILENAME parameter.
			%
			% DOCUMENT_ID can be either the document id of a did.document, or a
            % did.document object itsef.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value, as accepted by the DID.FILE.FILEOBJ
            % constructor method.
			%
			% Note: Close the document with FILE_OBJ.close() when finished.
            %
            % See also: CLOSE_DOC

            % Validate document ID validity (extract ID from object if needed)
            document_id = database_obj.validate_doc_id(document_id, false);

            % Open the document
            %if nargin > 2, varargin = [filename, varargin]; end %filename is NOT optional!
            file_obj = database_obj.do_open_doc(document_id, filename, varargin{:});
        end % open_doc()

        function [tf, file_path] = exist_doc(database_obj, document_id, filename, varargin)
            % EXIST_DOC - Check if a did.document exists as a file
            %
            % [TF, FILE_PATH] = exist_doc(DATABASE_OBJ, DOCUMENT_ID, FILENAME, [PARAMS])
            %
            % Return a boolean flag indicating whether a specified file
            % exists for the specified DOCUMENT_ID. The requested filename 
            % must be specified using the (mandatory) FILENAME parameter.
            % Also returns the absolute FILE_PATH for the file. If the file
            % does not exist, this output is an empty character vector.
            %
			% DOCUMENT_ID can be either the document id of a did.document, or a
            % did.document object itsef.
            %
            % Optional PARAMS may be specified as P-V pairs of a parameter name
            % followed by parameter value, as accepted by the DID.FILE.FILEOBJ
            % constructor method.
            %
            % If multiple files are found, only the file path for the first
            % document is returned.

            % Validate document ID validity (extract ID from object if needed)
            document_id = database_obj.validate_doc_id(document_id, false);
            
            [tf, file_path] = database_obj.check_exist_doc(document_id, filename, varargin{:});
        end

        function close_doc(database_obj, file_obj)
			% CLOSE_DOC - close an open did.document file
			%
			% CLOSE_DOC(DATABASE_OBJ, FILE_OBJ)
			%
			% Closes a FILE_OBJ that was previously opened with OPEN_DOC().
			%
			% See also: OPEN_DOC 

            database_obj.do_close_doc(file_obj);
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
                %dataTable = struct2table(data,'AsArray',true);
                dataCells = {};
                for i = numFields : -1 : 1
                    %results = dataTable.(fn{i});
                    results = {data.(fn{i})};
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
			% SEARCH - find matching did.documents in the specified branch
			%
			% DOCUMENT_IDS = SEARCH(DATABASE_OBJ, DID.QUERYOBJ, [BRANCH_ID])
			%
			% Search the specified BRANCH_ID using a DID QUERY object, return a
            % list of matching did.document IDs.
            %
            % If BRANCH_ID is empty or not specified, the current branch is used.
            % An error is genereted if the specified BRANCH_ID does not exist.
			% 
			% This function returns a cell array of did.document IDs. If no
            % documents match the query, an empty cell array ({}) is returned.

            % If branch_id was not specified, use the current branch
            if nargin < 3 || isempty(branch_id)
                branch_id = database_obj.current_branch_id;
            end

            % Ensure branch IDs validity
            branch_id = database_obj.validate_branch_id(branch_id);

            % Call the specific database's search method, return matching doc IDs
            document_ids = database_obj.do_search(query_obj, branch_id);
		end % search()
    end
    methods (Access=protected)
        function sql_str = query_struct_to_sql_str(sqlitedb_obj, query_struct)
            % Convert a single did.query object/struct into SQL query string
            sql_str = ''; %#ok<NASGU>
            field  = query_struct.field;
            param1 = query_struct.param1;
            param2 = query_struct.param2;
            param1Str = num2str(param1);
            if numel(param1)>=1
                param1Val = num2str(param1(1));
            else
                param1Val = [];
            end
            param1Like = regexprep(num2str(param1),{'\\','\*','_'},{'\\\\','%','\\_'});
            field_check = ['fields.field_name="' field '"'];
            op = strtrim(lower(query_struct.operation));
            isNot = op(1)=='~';
            if isNot
                notStr = 'NOT ';
            else
                notStr = '';
            end
            op(op=='~') = '';
            switch op
                case 'or'
                    sql_str = [query_struct_to_sql_str(sqlitedb_obj, param1) ' OR ' ...
                               query_struct_to_sql_str(sqlitedb_obj, param2)];
                case 'exact_string'
                    sql_str = [field_check ' AND ' notStr 'doc_data.value = "' param1Str '"'];
                case 'exact_string_anycase'
                    sql_str = [field_check ' AND ' notStr 'LOWER(doc_data.value) = "' lower(param1Str) '"'];
                case 'contains_string'
                    sql_str = [field_check ' AND ' notStr 'doc_data.value like "%' param1Like '%" ESCAPE "\"'];
                case 'exact_number'
	            if ~isempty(param1Val),
                        sql_str = [field_check ' AND ' notStr 'doc_data.value = '  param1Val];
                    else,
                        sql_str = [field_check ' AND ' notStr 'doc_data.value > 9e999']; % if is it empty, we have to make it fail
                    end;
                case 'lessthan'
                    sql_str = [field_check ' AND ' notStr 'doc_data.value < '  param1Val];
                case 'lessthaneq'
                    sql_str = [field_check ' AND ' notStr 'doc_data.value <= ' param1Val];
                case 'greaterthan'
                    sql_str = [field_check ' AND ' notStr 'doc_data.value > '  param1Val];
                case 'greaterthaneq'
                    sql_str = [field_check ' AND ' notStr 'doc_data.value >= ' param1Val];
                case 'hassize'   %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasmember'
                    fieldNameLike = regexprep(field,{'\\','\*','_'},{'\\\\','%','\\_'});
                    field_check = ['(' field_check ' OR fields.field_name like "' fieldNameLike '.%" ESCAPE "\")'];
                    %value_check= ['(doc_data.value like "%' param1 ',%"' ...
                    value_check = ['(regex(doc_data.value,"^(.*,\s*)*' param1Str '\s*(,.*)*$") NOT NULL' ...
                                   ' OR doc_data.value='  param1Str ...
                                   ' OR doc_data.value="' param1Str '")'];
                    sql_str = [field_check ' AND ' notStr value_check];
                case 'hasfield'
                    fieldNameLike = regexprep(field,{'\\','\*','_'},{'\\\\','%','\\_'});
                    sql_str = [field_check ' OR fields.field_name like "' fieldNameLike '.%" ESCAPE "\"'];
                case 'depends_on'
                    field_check = 'fields.field_name="meta.depends_on"';
                    sql_str = [field_check ' AND ' notStr 'doc_data.value like "%' param1Like ',' param2 ';%" ESCAPE "\"'];
                case 'partial_struct'  %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasanysubfield_contains_string'  %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'hasanysubfield_exact_string'     %TODO
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
                case 'regexp'
                    sql_str = [field_check ' AND ' notStr 'regex(doc_data.value,"' param1Str '") NOT NULL'];
                case 'isa'
                    sql_str = ['(fields.field_name="meta.class"      AND ' notStr 'doc_data.value = "' param1Str '") OR ' ...
                               '(fields.field_name="meta.superclass" AND ' notStr 'doc_data.value like "%' param1Like '%" ESCAPE "\")'];
                otherwise
                    error('DID:Database:SQL','Query operation "%s" is not yet implemented',op);
            end
            sql_str = ['(' sql_str ')'];
            %sql_str = [notStr sql_str];
        end
        function query_str = get_sql_query_str(sqlitedb_obj, query_structs, branch_id)
            % Convert an array of did.query objects/structs into SQL query string
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
            query_str = regexprep(query_str,' +',' ');
        end
        function doc_ids = search_doc_ids(sqlitedb_obj, query_struct, branch_id)
            % search_doc_ids - recursively search the database for matching doc IDs

            num_structs = numel(query_struct);
            if num_structs > 1  % loop over all &-ed queries
                doc_ids = {};
                for i = 1 : num_structs
                    new_doc_ids = search_doc_ids(sqlitedb_obj, query_struct(i), branch_id);
                    if i > 1
                        doc_ids = intersect(doc_ids, new_doc_ids);
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
        function [hCleanup, filename] = open_db(database_obj) %#ok<STOUT,MANU>
            % Subclasses may implement
        end
    end

    % Hidden synonym methods
    methods (Hidden)
        function parent_branch_id = get_parent_branch(database_obj, varargin)
            parent_branch_id = get_branch_parent(database_obj, varargin{:});
        end
        function display_branch(database_obj, varargin)
            display_branches(database_obj, varargin{:});
        end

        function add_doc(database_obj, varargin)
            add_docs(database_obj, varargin{:});
        end
        function document_obj = get_doc(database_obj, varargin)
            document_obj = get_docs(database_obj, varargin{:});
        end
        function remove_doc(database_obj, varargin)
            remove_docs(database_obj, varargin{:});
        end
    end

    % These methods *MUST* be overloaded by implementation subclasses
	methods (Abstract, Access=protected)
        results = do_run_sql_query(database_obj, query_str, varargin)

        % Branch-related methods
        branch_ids = do_get_branch_ids(database_obj)
        do_add_branch(database_obj, branch_id, parent_branch_id, varargin)
		do_delete_branch(database_obj, branch_id, varargin)
        parent_branch_id = do_get_branch_parent(database_obj, branch_id, varargin)
        branch_ids = do_get_sub_branches(database_obj, branch_id, varargin)

        % Document-related methods
        doc_ids = do_get_doc_ids(database_obj, branch_id, varargin)
		do_add_doc(database_obj, document_obj, branch_id, varargin)
		document_obj = do_get_doc(database_obj, document_id, varargin)
		do_remove_doc(database_obj, document_id, branch_id, varargin)
        file_obj = do_open_doc(database_obj, document_id, filename, varargin)
        [tf, file_path] = check_exist_doc(database_obj, document_id, filename, varargin)
    end

    % General utility functions used by this class that depend on a class object
    methods (Access=protected)
        %{
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
        %}
        function do_close_doc(database_obj, file_obj) %#ok<INUSL>
    	    % DO_CLOSE_DOC - close and unlock a did.document object
    	    %
    	    % DO_CLOSE_DOC(sqlitedb_obj, FILE_OBJ)
    	    %
    	    % Close and unlock the file associated with FILE_OBJ.

		    %database_obj.db.closebinaryfile(document_obj.fid, document_obj.key, document_obj.doc_unique_id);
		    file_obj.fclose(); 
	    end % do_close_doc()

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
            % The doc_id must be a non-empty string or char-array
            if isstring(doc_id)
                doc_id = char(doc_id);  % "id" => 'id'
            end
            if isa(doc_id, 'did_document') || isa(doc_id,'did.document')
                doc_id = doc_id.id();
            else
                if isstruct(doc_id)
                    try
                        doc_id = doc_id.document_properties.ndi_document.id;
                    catch
                        error('DID:Database:InvalidDocID','Input document must be a valid document object or ID');
                    end
                elseif isempty(doc_id) || ~ischar(doc_id)
                    error('DID:Database:InvalidDocID','Input document must be a valid document object or ID');
                end
            end

            % Optionally ensure that the branch exists in the database
            if nargin < 3 || check_existance
                doc_ids = database_obj.get_doc_ids();
                if ~ismember(doc_id, doc_ids)
                    error('DID:Database:InvalidDocID','Document ID "%s" does not exist in the database',doc_id);
                end
            end
        end

        function validate_docs(database_obj, document_objs)

            % Get the superset of all doc IDs in the database and the input docs
            all_ids = database_obj.all_doc_ids();
            for docIdx = 1 : numel(document_objs)
                try
                    %add the ids in the input document_objs
                    doc = document_objs(docIdx);
                    if iscell(doc), doc = doc{1}; end
                    docProps = doc.document_properties;
                    all_ids{end+1} = docProps.base.id; %#ok<AGROW>
                catch
                    % ignore this document
                end
            end
            all_ids = unique(lower(all_ids));

            for docIdx = 1 : numel(document_objs)
                % Get the document properties
                doc = document_objs(docIdx);
                if iscell(doc), doc = doc{1}; end
                docProps = doc.document_properties;

                % Ensure the docProps have a minimal document_class sub-struct
                try doc_id = docProps.base.id; catch, doc_id = ''; end
                validateField(docProps,'document_properties','document_class');
                classProps = docProps.document_class;
                validateField(classProps,'document_class','class_name');
                validateField(classProps,'document_class','property_list_name');
                validateField(classProps,'document_class','class_version');

                % Get the validation schema filename (if defined & exists)
                try
                    schema_filename = classProps.validation;
                catch
                    continue  % no validation field, so don't validate this doc!
                end
                if isempty(schema_filename), continue, end
                schemaStruct = database_obj.get_document_schema(schema_filename);

                % Check all the defined validation rules
                database_obj.validate_doc_vs_schema(docProps, schemaStruct, all_ids);
            end

            % Validate a single field in a parent struct (existing, non-empty)
            function validateField(parentStruct, parentName, fieldName)
                assert(isfield(parentStruct,fieldName), ...
                       'DID:Database:MissingRequiredField','Doc %s %s has no %s field!',doc_id,parentName,fieldName);
                value = parentStruct.(fieldName);
                assert(~isempty(value),'Doc %s %s field is empty!',doc_id,fieldName);
            end
        end

        function schemaStruct = get_document_schema(database_obj, schema_filename) %#ok<INUSL>
            % Get the path location of path placeholders
            definitionNames = did.common.PathConstants.definitions.keys();
            definitionLocations = did.common.PathConstants.definitions.values();
            try pathDefs = strrep(definitionNames,'$','\$');    catch, pathDefs = {}; end
            try pathLocs = strrep(definitionLocations,'\','/'); catch, pathLocs = {}; end

            schema_filename_potential = {};
            matches = [];
            % could be multiple candidates
            for i=1:numel(pathDefs),
                schema_filename_potential{i} = regexprep(schema_filename,pathDefs{i},pathLocs{i});
                if ~strcmp(schema_filename_potential{i},schema_filename),
                    matches(end+1) = i;
                end;
            end;
            schema_filename_potential = schema_filename_potential(matches);

            matches = [];
            for i=1:numel(schema_filename_potential),
                if ~isfile(schema_filename_potential{i}),
                    schema_filename_potential{i} = regexprep(schema_filename_potential{i},'\.json$','.schema.json');
                    if ~isfile(schema_filename_potential{i})
                       schema_filename_potential{i} = strrep(schema_filename_potential{i},'.schema.json','_schema.json');
                       if isfile(schema_filename_potential{i})
                           matches(end+1) = i;
                       end
                    else, 
                        matches(end+1) = i;
                    end
                else,
                    matches(end+1) = i;
                end
                if any(matches),
                    schema_filename = schema_filename_potential{i};
                    break;
                end;
            end

            if ~any(matches)
                error('DID:Database:ValidationFileMissing','Validation file "%s" not found',schema_filename);
            end;

            % Read the file contents
            fid = fopen(schema_filename,'r');
            if fid < 1
                error('DID:Database:ValidationFileCorrupt','Validation file "%s" cannot be read',schema_filename);
            end
            txt = fread(fid,'*char')';
            fclose(fid);

            % Ensure the contents is valid JSON, convert it a to Matlab struct
            try
                schemaStruct = jsondecode(txt);
            catch
                error('DID:Database:ValidationFileBad','Validation file "%s" has invalid JSON format',schema_filename);
            end
        end

        function validate_doc_vs_schema(database_obj, docProps, schemaStruct, all_ids)
            % Validate a document vs. its definition schema(s)

            IGNORE_DID_CLASS_PREFIX = true;

            % Loop over all fields in the validation schema
            try doc_id = docProps.base.id; catch, doc_id = ''; end
            classProps = docProps.document_class; % this croaks if document_class is missing - good!
            class_name = classProps.class_name; % this croaks if class_name field is missing - good!
            doc_name = [class_name ' doc ' doc_id];
            schemaClassName = schemaStruct.classname;
            if IGNORE_DID_CLASS_PREFIX
                class_name      = regexprep(class_name,     'did.','','ignorecase');
                schemaClassName = regexprep(schemaClassName,'did.','','ignorecase');
            end
            isSuperClass = ~strcmpi(class_name,schemaClassName);
            if isSuperClass
                doc_name = [doc_name ' (superclass ' schemaClassName ')'];
            end
            if database_obj.debug
                fprintf('Validating %s\n',doc_name);
            end
            try
                superFullNames = {classProps.superclasses.definition};
            catch
                superFullNames = {};
            end
            superNames = {};
            for i = 1 : numel(superFullNames)
                [~,superNames{i}] = fileparts(superFullNames{i}); %#ok<AGROW> % keep compatibility with Matlab 2019a
            end
            if ~iscell(superNames), superNames = {superNames}; end
            superNames = unique(superNames);
            schemaFields = fieldnames(schemaStruct);
            for fieldIdx = 1 : numel(schemaFields)
                field = schemaFields{fieldIdx};
                expected = schemaStruct.(field);
                switch field
                    case 'classname'
                        % Compare the defined vs. actual class name
                        % Note: schema field: 'classname', doc field: 'class_name'
                        if IGNORE_DID_CLASS_PREFIX
                            expected = regexprep(expected,'did.','','ignorecase');
                        end
                        areSame = ismember(lower(expected), lower([superNames,class_name]));
                        assert(areSame,'DID:Database:ValidationClassname', ...
                            'Mismatched classname ("%s" <=> "%s") in doc %s', ...
                            expected, class_name, doc_id);

                    case 'superclasses'
                        % Compare the defined vs. actual superclass names
                        if isSuperClass, continue, end  % && isempty(expected)
                        try expectedStr = strjoin(unique(expected),','); catch, expectedStr = ''; end
                        superNamesStr = strjoin(superNames,',');
                        areSame = strcmpi(expectedStr, superNamesStr);
                        assert(areSame,'DID:Database:ValidationSuperClasses', ...
                            'Dissimilar superclasses defined/found for %s ("%s" <=> "%s")', ...
                            doc_name, expectedStr, superNamesStr);
                        % Recursively validate all superNames against this doc:
                        for idx = 1 : numel(superNames)
                            % First get the superClass' definition struct
                            defStruct = database_obj.get_document_schema(superFullNames{idx});
                            % Extract validation file from definition
                            validationFile = defStruct.document_class.validation;
                            if ~isempty(validationFile)
                                % Read the superClass' schema from the validation file
                                schemaStruct2 = database_obj.get_document_schema(validationFile);
                                % Validate the superClass' schema
                                database_obj.validate_doc_vs_schema(docProps, schemaStruct2, all_ids);
                            end
                        end

                    case 'depends_on'
                        % Compare the defined vs. actual dependency names
                        if isempty(expected) && isSuperClass, continue, end
                        try depends = docProps.depends_on; docNames = {depends.name}; catch, docNames = {}; end
                        if isempty(expected) && isempty(docNames), continue, end
                        docNames_alt = docNames;
                        for dn=1:numel(docNames_alt), 
                            stridx = regexp(docNames{dn},'_(\d*)\>');
                            if isempty(stridx),
                                stridx = numel(docNames{dn})+1;
                            end;
                            docNames_alt{dn}=docNames{dn}(1:stridx-1);
                        end;
                        if ~isempty(expected),
                            expectedNames = {expected.name};
                            mustHaveValue = {expected.mustbenotempty};
                        else,
                            expectedNames = {};
                            mustHaveValue = {};
                        end;
                        areSame = all(ismember(lower(unique(expectedNames)), lower(unique(docNames_alt))));
                        if ~areSame,
                            disp(['Expected dependencies:']);
                            expectedNames(:)'
                            disp(['Found dependencies:']);
                            docNames_alt(:)'
                        end;
                        assert(areSame,'DID:Database:ValidationDependsOn', ...
                            'Dissimilar dependencies defined/found for %s', doc_name);
                        % Loop over all dependencies and ensure they exist
                        for idx = 1 : numel(mustHaveValue)
                            item_name = expectedNames{idx};
                            idx2 = find(strcmpi(item_name,docNames),1);
                            if isempty(idx2),
                                value = [];
                            else,
                                value = depends(idx2).value;
                            end;
                            % If dependency is marked as MustBeNotEmpty, ensure it's not empty
                            expectedValue = mustHaveValue{idx};
                            if ~isempty(expectedValue) && expectedValue
                                assert(~isempty(value), ...
                                    'DID:Database:ValidationDependEmpty', ...
                                    'Empty dependency found for "%s" in %s', ...
                                    item_name, doc_name)
                            end

                            % Ensure the dependent ID exists in database or input docs
                            if ~isempty(value)
                                assert(ischar(value),'DID:Database:ValidationDependNotACharacterArray',...
                                    'Non-character dependency value entered for "%s" in %s',...
                                    item_name,doc_name);
                                % compare the dependent value to all doc IDs
                                isOk = ismember(lower(value), all_ids);
                                assert(isOk,'DID:Database:ValidationDependency', ...
                                    'Dependent doc ID "%s" (%s) of %s not found in the database or input docs', ...
                                    value, item_name, doc_name)
                            end
                        end

                    case 'file'
                        % Compare the defined vs. actual file names
                        try
                           actual_files_here = docProps.files.file_info;
                           actualFileNames = {actual_files_here.name};
                           file_list = docProps.files.file_list;
                        catch,
                           actual_files_here= [];
                           actualFileNames = {};
                           file_list = {};
                        end
                        if isempty(expected) && (isSuperClass || isempty(actualFileNames)),
                           continue,
                        end
                        expectedNames = {expected.name};
                        mustHaveValue = {expected.mustbenotempty};
                        for idx = 1 : numel(actualFileNames),
                            actualFileNames{idx} = char(actualFileNames{idx});
                        end;
                        [isvalid,errmsg] = did.database.checkfiles(expectedNames,mustHaveValue,actualFileNames,doc_name,actual_files_here,file_list);
                        assert(isvalid,'DID:Database:ValidationFiles',errmsg);
                   otherwise  % class-specific field
                        % Compare the type and value of all class-specific fields
                        try,
                            docValue = docProps.(field);
                        catch E,
                            assert(false,'DID:Database:PropertyFieldMissing',E.message);
                        end

                        if isempty(expected), continue; end;
                        expectedSubFields = strjoin(unique({expected.name}),',');
                        docSubFields = strjoin(unique(fieldnames(docValue)),',');
                        areSame = strcmpi(expectedSubFields,docSubFields);
                        assert(areSame,'DID:Database:ValidationFields', ...
                            'Dissimilar sub-fields defined/found for %s field in %s (expected fields "%s" <=> actual fields "%s")', ...
                            field, doc_name, expectedSubFields, docSubFields);
                        for idx = 1 : numel(expected)
                            definition = expected(idx);
                            subfield = definition.name;
                            field_name = [field '.' subfield];
                            docSubValue = docValue.(subfield);
                            database_obj.validate_field_type_and_value(doc_name, field_name, docSubValue, definition)
                        end
                end
            end
        end

        function validate_field_type_and_value(database_obj, doc_name, field_name, value, definition) %#ok<INUSL>
            % Validate a field value vs. its definition (expected type etc.)
            expectedType   = definition.type;
            expectedParams = definition.parameters;
            switch lower(expectedType)
                case 'integer'
                    if islogical(value),
                        value = double(value);
                    end;
                    assert(isnumeric(value), ...
                        'DID:Database:ValidationFieldInteger', ...
                        'Invalid non-numeric sub-field %s found in %s', ...
                        field_name, doc_name);
                    assert(numel(expectedParams)==3|numel(expectedParams)==4, ...
                        'DID:Database:ValidationFieldInteger', ...
                        '3 or 4 parameters must be defined for Integer fields in a document schema, but %d defined', ...
                        numel(expectedParams))
                    if numel(expectedParams)>=4,
                        canbeempty = expectedParams(4);
                    else,
                        canbeempty = 0;
                    end;
                    if isempty(value) && canbeempty,
                        isOk = true;
                    elseif isempty(value) && ~canbeempty,
                        isOk = false;
                    elseif isnan(value) && expectedParams(3)
                        isOk = true;
                    else,
                        isOk = value >= expectedParams(1) && ...
                            value <= expectedParams(2);
                    end
                    assert(isOk,'DID:Database:ValidationFieldInteger', ...
                        'Invalid sub-field %s value found in %s', ...
                        field_name, doc_name);
                    isInteger = (  abs(value-fix(value)) < 1e-12  );
                    assert(isInteger,'DID:Database:ValidationFieldInteger',...
                         'Invalid non-integer value %f provided', value);

                case 'double'
                    assert(isnumeric(value), ...
                        'DID:Database:ValidationFieldDouble', ...
                        'Invalid non-numeric sub-field %s found in %s', ...
                        field_name, doc_name);
                    assert(numel(expectedParams)==3|numel(expectedParams)==4, ...
                        'DID:Database:ValidationFieldDouble', ...
                        '3 or 4 parameters must be defined for Double fields in a document schema, but %d defined', ...
                        numel(expectedParams))
                    if numel(expectedParams)>=4,
                        canbeempty = expectedParams(4);
                    else,
                        canbeempty = 0;
                    end;
                    if isempty(value) && canbeempty,
                        isOk = true;
                    elseif isnan(value) && expectedParams(3)
                        isOk = true;
                    else,
                        isOk = value >= expectedParams(1) && ...
                            value <= expectedParams(2);
                    end
                    assert(isOk,'DID:Database:ValidationFieldDouble', ...
                        'Invalid sub-field Double %s value found in %s', ...
                        field_name, doc_name);

                case 'matrix'
                    isOk = isempty(value)|isnumeric(value);
                    assert(isOk, ...
                        'DID:Database:ValidationFieldMatrix', ...
                        'Invalid non-numeric Matrix sub-field %s found in %s', ...
                        field_name, doc_name);
                    assert(numel(expectedParams)>=2, ...
                        'DID:Database:ValidationFieldMatrix', ...
                        'At least 2 parameters must be defined for Matrix fields in a document schema, but %d defined', ...
                        numel(expectedParams));
                    % convert size vector to columns
                    sz = size(value);
                    sz = sz(:);
                    nonNans = find(~isnan(expectedParams));
                    if numel(nonNans)==0,
                        isOk = true;
                    elseif any(expectedParams(nonNans)==1),
                        isOk = any(sz==1); % allow column/row switch, a vector is a vector; this is temporary
                    else,
                        isOk = isequal(sz(nonNans),expectedParams(nonNans));
                    end;
                    assert(isOk,'DID:Database:ValidationFieldMatrix', ...
                        'Invalid sub-field %s size %dx%d found in %s', ...
                        field_name, size(value,1), size(value,2), ...
                        doc_name);

                case 'timestamp'
                    assert(ischar(value), ...
                        'DID:Database:ValidationFieldTimestamp', ...
                        'Invalid non-timestamp sub-field %s found in %s', ...
                        field_name, doc_name);
                    value = regexprep(value,'Z$',''); %discard trailing 'Z' (unparsable by LocalDateTime)
                    try,
                        jTimestr = java.lang.String(value);
                        java.time.LocalDateTime.parse(jTimestr);  % will croak if unparsable
                    catch,
                        assert(false,'DID:Database:ValidationFieldTimeStamp','Invalid timestamp sub-field %s found in %s',...
                            field_name, doc_name);
                    end;

                case {'char','string'}
                    isOk = isempty(value)|ischar(value);
                    assert(isOk, ...
                        'DID:Database:ValidationFieldChar', ...
                        'Invalid non-char sub-field %s found in %s', ...
                        field_name, doc_name);
                    if numel(expectedParams)==0, 
                        isOk = true;
                    else,
                        isOk = length(value) <= expectedParams(1);
                    end;
                    assert(isOk,'DID:Database:ValidationFieldChar', ...
                        'Invalid sub-field %s length %d found in %s', ...
                        field_name, length(value), doc_name);

                case 'did_uid'
                    assert(ischar(value), ...
                        'DID:Database:ValidationFieldUID', ...
                        'Invalid non-UID sub-field %s found in %s', ...
                        field_name, doc_name);
                    if isempty(value), return, end
                    uid_part = '[\dA-F]{16}';
                    regex = [uid_part '_' uid_part];
                    isOk = length(value)==33 && ~isempty(regexpi(value,regex,'once'));
                    assert(isOk,'DID:Database:ValidationFieldUID', ...
                        'Invalid non-UID sub-field %s found in %s', ...
                        field_name, doc_name);

                case 'structure'
                    assert(isempty(value)|isstruct(value),...
                        'DID:Database:ValidationFieldStructure',...
                        'Invalid structure sub-field %s found in %s',...
                        field_name, doc_name);
                case 'cell'
                    assert(isempty(value)|iscell(value),...
                        'DID:Database:ValidationFieldStructure',...
                        'Invalid cell sub-field %s found in %s',...
                        field_name, doc_name);                    
                otherwise
                    error('DID:Database:ValidationFieldType', ...
                          'Invalid sub-field %s type "%s" defined in %s', ...
                          field_name, expectedType, doc_name);
            end
        end
    end

    % General utility functions used by this class that don't depend on a class object
    methods (Access=protected, Static)
        function value = getUnixTime()
            % Return the current time in UNIX format
            value = java.util.Date().getTime;
        end

        function params = parseOptionalParams(varargin)
            % Return optional input args in struct format
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

        function document_ids = normalizeDocIDs(document_ids)
            % Convert scalar or regular array of doc_ids to cell-array of doc_ids
            if isempty(document_ids)
                document_ids = {};
            elseif isa(document_ids,'string')
                document_ids = arrayfun(@char,document_ids,'uniform',0); %[".." ".."] => {'..','..'}
            elseif ischar(document_ids)
                document_ids = {document_ids};
            elseif ~iscell(document_ids)  % regular array of objs/structs
                document_ids = num2cell(document_ids);
            end
        end
    end

    % Preferences management
    methods
        function prefNames = get_preference_names(this)
			% GET_PREFERENCE_NAMES - return a cell-array of all defined pref names
			%
			% prefNames = GET_PREFERENCE_NAMES(DATABASE_OBJ)
			%
			% Returns a cell-array of all preference names defined in this DB obj.
            % If no preferences were defined (via SET_PREFERENCE method), an empty
            % cell-array is returned.
            %
            % See also: SET_PREFERENCE, GET_PREFERENCE

            prefNames = this.preferences.keys;
        end
        function value = get_preference(this, pref_name, default_value)
			% GET_PREFERENCE - return value of pre-defined preference in this object.
			%
			% value = GET_PREFERENCE(DATABASE_OBJ, PREF_NAME, [DEFAULT_VALUE])
			%
			% Return the value pre-stored for the specified PREF_NAME in this obj.
            % If no value was pre-stored (via the SET_PREFERENCE method), then if
            % the optional DEFAULT_VALUE input parameter was specified it will be
            % returned; otherwise, an error will be generated.
            %
            % See also: SET_PREFERENCE, GET_PREFERENCE_NAMES

            if nargin < 2 || isempty(pref_name)
                error('DID:Database:MissingPrefName','The get_preference method requires a valid preference name input parameter')
            elseif ~ischar(pref_name) && ~isa(pref_name,'string')
                error('DID:Database:InvalidPrefName','The get_preference method requires a valid preference name input parameter')
            end
            try
                value = this.preferences(pref_name);
            catch
                if nargin  > 2
                    value = default_value;
                else
                    error('DID:Database:InvalidPreference','Preference value %s is not defined', pref_name)
                end
            end
        end
        function set_preference(this, pref_name, value)
			% SET_PREFERENCE - sets value of specified preference in this object.
			%
			% SET_PREFERENCE(DATABASE_OBJ, PREF_NAME, [VALUE])
			%
			% Sets the value of the specified PREF_NAME preference in this obj.
            % If VALUE is not specified, an empty [] value will be set.
            %
            % See also: GET_PREFERENCE, GET_PREFERENCE_NAMES

            if nargin < 2 || isempty(pref_name)
                error('DID:Database:MissingPrefName','The set_preference method requires a valid preference name input parameter')
            elseif ~ischar(pref_name) && ~isa(pref_name,'string')
                error('DID:Database:InvalidPrefName','The set_preference method requires a valid preference name input parameter')
            end
            if nargin < 3, value = []; end  % default = empty value
            this.preferences(pref_name) = value;
        end
    end
    methods(Static)
       function [isvalid,errmsg] = checkfiles(expectedNames,mustHaveValue,actualFileNames, doc_name, files, actual_file_list)
           % CHECKFILES - check to make sure that files that are offered match those that are expected or needed
           % 
           % [ISVALID,ERRMSG] = CHECKFILES(EXPECTEDNAMES, MUSTHAVEVALUE, ACTUALFILENAMES, DOC_NAME, files, actual_file_list)
           %
           %
              isvalid = 0;
              errmsg = '';

              % need to check:
              %  1 - that every entry of the expected file_list is present in the actual document's file_list
              %  2 - that every entry of the actual document's file_list is valid (it might differ from
              %      the literal expected file_list if there are enumerated files that end in _##)
              %  3 - that every file that is required to be present is in fact present

                % check that each expectedName has a match in the actualFileNames
              expectedNamesList = unique(expectedNames);
              actualFileNamesList = unique(actualFileNames);

              % Step 1: are any expectedNames missing in the actual file list?
              missing_files = setdiff(expectedNamesList,actual_file_list);
              if ~isempty(missing_files)
                 errmsg = sprintf('Some required files are missing (including %s) from the file_list in document %s', missing_files{1}, doc_name);
              end;

              % Step 2: are all files in the actual document's file_list valid?
              areSame = 1;
              for i=1:numel(actualFileNamesList),
                 exact_match = any(strcmp(actualFileNamesList{i},expectedNames));
                 begin_match = 0;
                 if ~exact_match,
                    for j=1:numel(expectedNamesList),
                       if did.database.isfilenamematch(expectedNamesList{j},actualFileNamesList{i}),
                          begin_match = 1;
                          break;
                       end;
                    end;
                 end;
                 areSame = areSame & (exact_match | begin_match);
                 if ~areSame,
                    break;
                 end
              end;

              if ~areSame,
                    errmsg=sprintf('Dissimilar files defined/found (including %s) for %s', actualFileNamesList{i}, doc_name);
keyboard
                    return;
              end;

              % Loop over all files and ensure they exist
              for idx = 1 : numel(mustHaveValue)
                 expectedValue = mustHaveValue{idx};
                 if ~isempty(expectedValue) && expectedValue
                    item_name = expectedNames{idx};
                    idx2 = did.database.findfilematch(item_name,actualFileNames);
                    for k=1:numel(idx2),
                       locations = files(idx2(k)).locations;
                       found = did.database.canfindonefile(locations);
                       if ~found,
                          errmsg = sprintf('Missing file %s in %s',item_name,doc_name);
                          return;
                       end
                    end
                 end
              end
              isvalid = 1;
       end; % checkfiles()
       function index = findfilematch(expectedName,actualNames)
          % INDEX = FINDFILEMATCH(EXPECTEDNAME, ACTUALNAMES)
          %
          % Return the index of the item in the cell array of strings ACTUALNAMES
          % that matches the EXPECTEDNAME. EXPECTEDNAME can either be an exact match
          % or can a string 'ANYTHING_#' and ACTUALNAMES{INDEX} can have a number (e.g., 'ANYTHING_5').
          %
             index = find(strcmp(expectedName,actualNames));
             if isempty(index),
                if expectedName(end)=='#', 
                   tf = startsWith(actualNames,expectedName(1:end-1));
                   indexes = find(tf);
                   for k=1:numel(indexes),
                      rest_of_name = docNamesList{i}(numel(expectedNamesList{indexes(k)}):end);
                      if all(rest_of_name>=double('0') & rest_of_name<=double('9')),
                         index(end+1) = k;
                      end;
                   end;
                end;
             end;
       end; % findfilematch()
       function b = isfilenamematch(expectedName,actualName)
           % ISFILENAMEMATCH - are two file names matched?
           % 
           % B = ISFILENAMEMATCH(EXPECTEDNAME,ACTUALNAME)
           %
           % EXPECTEDNAME and ACTUALNAME can match if 
           %   1) they are equal
           %   2) If EXPECTEDNAME ends in a '#', ACTUALNAME can begin
           %      with EXPECTEDNAME and end in an integer.
              b = isequal(expectedName,actualName);
              if ~b,
                 if expectedName(end)=='#',
                    tf = startsWith(actualName,expectedName(1:end-1));
                    if tf,
                       rest_of_name = actualName(numel(expectedName):end);
                       b = all(rest_of_name>=double('0') & rest_of_name<=double('9'));
                    end
                 end
              end
       end; % isfilenamematch()
       function found = canfindonefile(locations)
          % CANFINDONEFILE - can we find at least one file for this?
              found = false;
              for idx2 = 1 : numel(locations)
                 fileLocation = locations(idx2).location;
                 if isfile(fileLocation)
                    found = true;
                    break
                 else
                    try
                       filename = websave(tempname,fileLocation);
                       if isfile(filename)
                          delete(filename);
                          found = true;
                          break
                       end
                    catch
                       % ignore this location
                    end
                 end
              end
       end; % canfindonefile
    end; % Static methods
end % database classdef
