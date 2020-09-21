classdef database
	% did.database: The superclass for all did.database implementations
	%
	% did.database defines the API for the DID database system. Applications or users that use
	% did.database interact with the ADD, READ, REMOVE, SEARCH, OPENBINARYDOC and CLOSEBINARYDOC methods.
	%
	% Developers that create subclass implementations of the did.database class should override the functions do_*
	% that are called to implement these procedures.
	%
	% did.database Properties:
	%   connection - The connection details for the database (might be a file name, directory name, or structure)
	%
	% did.database Methods:
	%   database - Create a new database
	%   add - Add a document to the database
	%   read - Read a did.document from the database based on the document's unique identifier
	%   remove - Remove a did.document from the database
	%   search - Search for a did.document(s) using a did.query
	%   openbinarydoc - Open the binary portion of a did.document for reading/writing (returns a did.binarydoc)
	%   closebinarydoc - Close a did.binarydoc
	%   
	%   do_add - The add function that must be overridden by specific subclass implementations
	%   do_read - The read function that must be overridden by specific subclass implementations
	%   do_remove - The remove function that must be overridden by specific subclass implementations
	%   do_search - The search function that must be overrideen by specific subclass implementations
	%   do_openbinarydoc - The function that opens binary documents that must be overridden in subclass implementations
	%   do_closebinarydoc - The function that closes binary documents that must be overridden in subclass implementations
	%

	properties (SetAccess=protected,GetAccess=public)
		connection % A variable or structure describing the connection parameters of the database; may be a simple file path
	end % properties

	methods
		function database_obj = database(varargin)
			% DATABASE - create a new DATABASE
			%
			% DATABASE_OBJ = DATABASE(PATH, REFERENCE)
			%
			% Creates a new DATABASE object with data path PATH
			% and reference REFERENCE.
			%
			
			connection = '';

			if nargin>0,
				connection = varargin{1};
			end

			database_obj.connection = connection;
		end % database

		function database_obj = add(database_obj, did_document_obj, varargin)
			% ADD - add an DID_DOCUMENT to the database 
			%
			% DATABASE_OBJ = ADD(DATABASE_OBJ, DID_DOCUMENT_OBJ, DBPATH, ...)
			%
			% Adds the document DID_DOCUMENT_OBJ to the database DATABASE_OBJ.
			%
			% This function also accepts name/value pairs that modify its behavior:
			% Parameter (default)      | Description
			% -------------------------------------------------------------------------
			% 'Update'  (1)            | If document exists, update it. If 0, an error is 
			%                          |   generated if a document with the same ID exists
			% 
			% See also: NAMEVALUEPAIR 
				Update = 1;
				did.datastructures.assign(varargin{:});
				add_parameters = did.datastructures.var2struct('Update');
				database_obj = do_add(database_obj, did_document_obj, add_parameters);
		end % add()

		function [did_document_obj, version] = read(database_obj, did_document_id, version )
			% READ - read an DID.DOCUMENT from a DID.DATABASE 
			%
			% DID_DOCUMENT_OBJ = READ(DATABASE_OBJ, DOCUMENT_ID, [VERSION]) 
			%
			% Read the DID_DOCUMENT object with the document ID specified by DOCUMENT_ID. If VERSION
			% is provided (an integer) then only the version that is equal to VERSION is returned.
			% Otherwise, the latest version is returned.
			%
			% If there is no DID DOCUMENT object with that ID, then empty is returned ([]).
			%
				if nargin<3,
					[did_document_obj, version] = do_read(database_obj, did_document_id);
				else,
					[did_document_obj, version] = do_read(database_obj, did_document_id, version);
				end
		end % read()

		function [did_binarydoc_obj, version] = openbinarydoc(database_obj, did_document_or_id, version)
			% OPENBINARYDOC - open and lock an DID.BINARYDOC that corresponds to a document id
			%
			% [DID_BINARYDOC_OBJ, VERSION] = OPENBINARYDOC(DATABASE_OBJ, DID_DOCUMENT_OR_ID, [VERSION])
			%
			% Return the open DID_BINARYDOC object and VERSION that corresponds to an DID.DOCUMENT and
			% the requested version (the latest version is used if the argument is omitted).
			% DID.DOCUMENT_OR_ID can be either the document id of an DID.DOCUMENT or an DID.DOCUMENT object itsef.
			%
			% Note that this DID_BINARYDOC_OBJ must be closed and unlocked with DATABASE/CLOSEBINARYDOC.
			% The locked nature of the binary doc is a property of the database, not the document, which is why
			% the database is needed.
			% 
				if isa(did_document_or_id,'did.document'),
					did_document_id = did_document_or_id.id();
				else,
					did_document_id = did_document_or_id;
				end;
				if nargin<3,
					[did_document_obj,version] = database_obj.read(did_document_id);
				else,
					[did_document_obj,version] = database_obj.read(did_document_id, version);
				end;
				did_binarydoc_obj = do_openbinarydoc(database_obj, did_document_id, version);
		end; % openbinarydoc

		function [did_binarydoc_obj] = closebinarydoc(database_obj, did_binarydoc_obj)
			% CLOSEBINARYDOC - close and unlock an DID.BINARYDOC 
			%
			% [DID_BINARYDOC_OBJ] = CLOSEBINARYDOC(DATABASE_OBJ, DID_BINARYDOC_OBJ)
			%
			% Close and lock an DID_BINARYDOC_OBJ. The DID_BINARYDOC_OBJ must be unlocked in the
			% database, which is why it is necessary to call this function through the database.
			%
				did_binarydoc_obj = do_closebinarydoc(database_obj, did_binarydoc_obj);
		end; % closebinarydoc

		function database_obj = remove(database_obj, did_document_id, versions)
			% REMOVE - remove a document from an DATABASE
			%
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DID_DOCUMENT_ID) 
			%     or
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DID_DOCUMENT_ID, VERSIONS)
			%     or 
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DID_DOCUMENT) 
			%
			% Removes the DID_DOCUMENT object with the 'document unique reference' equal
			% to DID_DOCUMENT_OBJ_ID.  If VERSIONS is specified, then only the versions that match
			% the entries in VERSIONS are removed.
			%
			% If a DID.DOCUMENT is passed, then the DID DOCUMENT_ID is extracted using
			% DID_DOCUMENT/DOC_UNIQUE_ID. If a cell array of DID.DOCUMENT is passed instead, then
			% all of the documents are removed.
			%
				if isempty(did_document_id),
					return; % nothing to do
				end;

				did_document_id_list = {};
				
				if ~iscell(did_document_id),
					did_document_id = {did_document_id};
				end;
				
				for i=1:numel(did_document_id)
					if isa(did_document_id{i}, 'did_document'),
						did_document_id_list{end+1} = did_document_id{i}.id();
					else,
						did_document_id_list{end+1} = did_document_id{i};
					end;
				end;

				for i=1:numel(did_document_id_list),
					if nargin<3,
						do_remove(database_obj, did_document_id_list{i});
					else,
						do_remove(database_obj, did_document_id{i}, versions);
					end;
				end;
		end % remove()

		function docids = alldocids(database_obj)
			% ALLDOCIDS - return all document unique reference numbers for the database
			%
			% DOCIDS = ALLDOCIDS(DATABASE_OBJ)
			%
			% Return all document unique reference strings as a cell array of strings. If there
			% are no documents, empty is returned.
			%
				docids = {}; % needs to be overridden
		end; % alldocids()

		function clear(database_obj, areyousure)
			% CLEAR - remove/delete all records from an DATABASE
			% 
			% CLEAR(DATABASE_OBJ, [AREYOUSURE])
			%
			% Removes all documents from the DUMBJSONDB object.
			% 
			% Use with care. If AREYOUSURE is 'yes' then the
			% function will proceed. Otherwise, it will not.
			%
			% See also: DATABASE/REMOVE

				if nargin<2,
					areyousure = 'no';
				end;
				if strcmpi(areyousure,'Yes')
					ids = database_obj.alldocids;
					for i=1:numel(ids), 
						database_obj.remove(ids{i}) % remove the entry
					end
				else,
					disp(['Not clearing because user did not indicate he/she is sure.']);
				end;
		end % clear

		function [did_document_objs,versions] = search(database_obj, searchparams)
			% SEARCH - search for an DID_DOCUMENT from an DATABASE
			%
			% [DOCUMENT_OBJS,VERSIONS] = SEARCH(DATABASE_OBJ, DID.QUERYOBJ)
			%
			% Performs a search of the database with a DID QUERY object.
			% 
			% This function returns a cell array of DID_DOCUMENT objects. If no documents match the
			% query, then an empty cell array ({}) is returned. An array VERSIONS contains the document version of
			% of each DID_DOCUMENT.
			% 
				searchOptions = {};
				[did_document_objs, versions] = database_obj.do_search(searchOptions,searchparams);
		end % search()

	end % methods database

	methods (Access=protected)
		function database_obj = do_add(database_obj, did_document_obj, add_parameters)
		end % do_add
		function [did_document_obj, version] = do_read(database_obj, did_document_id, version);
		end % do_read
		function did_document_obj = do_remove(database_obj, did_document_id, versions)
		end % do_remove
		function [did_document_objs,versions] = do_search(database_obj, searchoptions, searchparams) 
		end % do_search()
		function [did_binarydoc_obj] = do_openbinarydoc(database_obj, did_document_id, version) 
		end % do_openbinarydoc()
		function [did_binarydoc_obj] = do_closebinarydoc(database_obj, did_binarydoc_obj) 
		end % do_closebinarydoc()

	end % Methods (Access=Protected) protected methods
end % classdef


