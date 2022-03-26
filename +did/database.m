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
		commit % the commit number of the database that we are viewing/editing at the moment
	end % properties

	methods
		function database_obj = database(varargin)
			% DATABASE - create a new DATABASE
			%
			% DATABASE_OBJ = DATABASE(...)
			%
			% Creates a new DATABASE object 
			%
			
			connection = '';
			commit = '';

			if nargin>0,
				connection = varargin{1};
			end

			database_obj.connection = connection;
			database_obj.commit = commit;
		end % database

		function database_obj = add(database_obj, did_document_obj, varargin)
			% ADD - add an DID_DOCUMENT to the database 
			%
			% DATABASE_OBJ = ADD(DATABASE_OBJ, DID_DOCUMENT_OBJ, DBPATH, ...)
			%
			% Adds the document DID_DOCUMENT_OBJ to the database DATABASE_OBJ.
			%
			% See also: NAMEVALUEPAIR 
				database_obj = do_add(database_obj, did_document_obj);
		end % add()

		function [did_document_obj, commit_out] = read(database_obj, did_document_id, commit_in)
			% READ - read an DID.DOCUMENT from a DID.DATABASE 
			%
			% [DID_DOCUMENT_OBJ,COMMIT] = READ(DATABASE_OBJ, DOCUMENT_ID, [COMMIT]) 
			%
			% Read the DID_DOCUMENT object with the document ID specified by DOCUMENT_ID. 
			% If COMMIT is omitted, then the current DATABASE_OBJ.COMMIT is read.
			%
			% The commit ID being viewed is also returned.
			%
			% If there is no DID DOCUMENT object with that ID, then empty is returned ([]).
			%
				if nargin<3,
					commit_in = database_obj.commit;
				end;
				[did_document_obj, commit_out] = do_read(database_obj, did_document_id, commit_in);
		end % read()

		function [did_binarydoc_obj,commit] = openbinarydoc(database_obj, did_document_or_id, name, commit_requested)
			% OPENBINARYDOC - open and lock an DID.BINARYDOC that corresponds to a document id
			%
			% [DID_BINARYDOC_OBJ, COMMIT] = OPENBINARYDOC(DATABASE_OBJ, DID_DOCUMENT_OR_ID, NAME, [COMMIT_REQUESTED])
			%
			% Return the open DID_BINARYDOC object and COMMIT that corresponds to a DID.DOCUMENT and the
			% NAME of the requested file record. If COMMIT_REQUESTED is provided, then the requested commit id
			% is read.
			%
			% DID.DOCUMENT_OR_ID can be either the document id of an DID.DOCUMENT or a DID.DOCUMENT object itsef.
			%
			% Note that the resulting document should be closed with DID_BINARYDOC_OBJ.close() when finished.
			%
			%
				if isa(did_document_or_id,'did.document'),
					did_document_id = did_document_or_id.id();
				else,
					did_document_id = did_document_or_id;
				end;
				if nargin<4,
					commit_requested = database_obj.commit;
				end;
				did_binarydoc_obj = do_openbinarydoc(database_obj, did_document_id, name, commit_requested);
		end; % openbinarydoc

		function database_obj = remove(database_obj, did_document_id, versions)
			% REMOVE - remove a document from an DATABASE
			%
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DID_DOCUMENT_ID, [COMMIT_REQUESTED]) 
			%     or 
			% DATABASE_OBJ = REMOVE(DATABASE_OBJ, DID_DOCUMENT) 
			%
			% Removes the DID_DOCUMENT object with the 'document unique reference' equal
			% to DID_DOCUMENT_OBJ_ID.  If COMMIT_REQUESTED is specified, then the document is
			% removed from that commit. Otherwise, the current commit is used.
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
					do_remove(database_obj, did_document_id_list{i});
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

		function commit_ids = allcommits(database_obj)
			% COMMITS - return all commit IDs for a DID database
			%
			% COMMIT_IDS = ALLCOMMITS(DATABASE_OBJ)
			%
			% Return a list of all commit IDs for the current database.
			%
				commit_ids = {};
		end;

		function database_obj = checkout_branch(database_obj, commitid)
			% CHECKOUT_BRANCH - check out a particular commit/branch of the database
			%
			% DATABASE_OBJ = CHECKOUT_BRANCH(DATABASE_OBJ, COMMITID)
			%
			%


		end; 

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


