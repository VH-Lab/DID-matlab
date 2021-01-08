classdef  mongodb < did.database
	properties (SetAccess=protected, GetAccess=public)
		collection
    	end
    
    	properties(SetAccess=protected, GetAccess=private)
        	cleanup
    	end

	methods
		function did_mongodb_obj = mongodb(varargin)
			% DID_MONGODB_OBJ make a new MONGODB object
			% 
			% DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(SERVER, PORT, DBNAME, COLLECTION, COMMAND)
			%
			% DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(DBNAME, COLLECTION, COMMAND)
			%
			% DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(DBNAME, USERNAME, PASSWORD, COLLECTION, COMMAND)
			%
			% DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(SERVER, PORT, DBNAME, USERNAME, PASSWORD, COLLECTION, COMMAND)
			%
			% Creates a new MONGODB object.
			%
			% COMMAND can either be 'Load' or 'New'. 
			%
            		default = struct("port", 27017, "server", "localhost");
			conn = "";
			command = "";
			collection = "";
			if nargin == 3
				conn = mongo(default.server, default.port, varargin{1});
				collection = varargin{2};
				command = varargin{3};
			elseif nargin == 5
				if isnumeric(varargin{2})
				    conn = mongo(varargin{1}, varargin{2}, varargin{3});
				else
				    conn = mongo(default.server, default.port, varargin{1}, 'UserName', varargin{2}, 'Password', varargin{3});
				end
				collection = varargin{4};
				command = varargin{5};
			elseif nargin == 7
				conn = mongo(varargin{1}, varargin{2}, varargin{3}, 'UserName', varargin{4}, 'Password', varargin{5});
				collection = varargin{6};
				command = varargin{7};
			else
				error("usage:" + newline + ...
					"DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(SERVER, PORT, DBNAME, COLLECTION, COMMAND)" + newline + ...
					"DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(DBNAME, COLLECTION, COMMAND)" + newline + ...
					"DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(DBNAME, USERNAME, PASSWORD, COLLECTION, COMMAND)" + newline + ...
					"DID_MONGODB_OBJ = DID_MATLABDUMBJSONDB(SERVER, PORT, DBNAME, USERNAME, PASSWORD, COLLECTION, COMMAND))");
			end  
			did_mongodb_obj = did_mongodb_obj@did.database(conn);
			command = string(lower(strtrim(command)));
			if command == "load"
				if ~any(strcmp(conn.CollectionNames,collection))
					error("The collection you are trying to load does not exist. You must load one of the following collections " + newline ...
						+ conn.CollectionNames);
				end
			elseif command == "new"
				createCollection(conn,collection)
				disp("A new collection " + collection + " has been created into the database");
			else
				error("command either has to be NEW or LOAD");
			end    
			did_mongodb_obj.collection = collection;
			did_mongodb_obj.cleanup = onCleanup(@()destructor(did_mongodb_obj));
		end % did_mongodb_obj()
	end 

	methods % public
		function docids = alldocids(did_mongodb_obj)
			% ALLDOCIDS - return all document unique reference numbers for the database
			%
			% DOCIDS = ALLDOCIDS(DID_MATLABDUMBJSONDB_OBJ)
			%
			% Return all document unique reference strings as a cell array of strings. If there
			% are no documents, empty is returned.
			%
			ids = find(did_mongodb_obj.connection,did_mongodb_obj.collection, 'Projection', '{"document_properties.base.id": 1.0}');
                	docids = cell(1, numel(ids));
                	for i = 1:numel(ids)
                    		ids(i).document_properties.base.id
                    		docids{i} = ids(i).document_properties.base.id;
                	end
        	end % alldocids()
    	end

	methods (Access=protected)
		function did_mongodb_obj = destructor(did_mongodb_obj)
		    %Close the connection to the database when the object is being
		    %destroyed to prevent memory leak. This method is called when
		    %we clear an instance of mongodb from the workspace
		   	if isopen(did_mongodb_obj.connection)
			   close(did_mongodb_obj.connection);
		  	end
		end

		function did_mongodb_obj = do_add(did_mongodb_obj, did_document_obj, add_parameters)
		    db = did_mongodb_obj.connection;
		    cn = did_mongodb_obj.collection;
		    id = did_document_obj.document_properties.base.id;
		    update = 0;
		    if isfield(add_parameters, 'Update')
				update = add_parameters.Update;
		    end
		    %First look up the document in the database
		    lookup = find(db, cn,'Query', ['{"document_properties.base.id" : "', id, '"}']);
		    if isempty(lookup)
				insert(db, cn, struct(did_document_obj));
		    else
				if update == 0
			    		error("The document already exist in the database");
				else
			    		remove(db, cn, ['{"document_properties.base.id" : "', id, '"}']);
                        do_add(did_mongodb_obj, did_document_obj, add_parameters)
				end
		    end
		end % do_add
		
        function [did_document_obj, version] = do_read(did_mongodb_obj, did_document_id, version)
		    if nargin < 3
				version = [];
		    end
		    db = did_mongodb_obj.connection;
		    cn = did_mongodb_obj.collection;
		    id = did_document_id.id();
		    if isempty(version)
				raw = find(db, cn,'Query', ['{"document_properties.base.id" : "', id, '"}']);
		    else
				raw = find(db, cn,'Query', ['{"document_properties.base.id" : "', id, '", "document_properties.base.document_version" : ', num2str(version), '}']);
		    end
		    if ~isempty(raw)
				did_document_obj = did.document(raw.document_properties);
				version = did_document_obj.document_properties.base.document_version;
		    else
				did_document_obj = [];
				version = -1;
		    end
		end % do_read

		
        function did_document_obj = do_remove(did_mongodb_obj, did_document_id, versions)
            db = did_mongodb_obj.connection;
		    cn = did_mongodb_obj.collection;
            did_document_obj = do_read(did_mongodb_obj, did_document_id, versions);
            if ~isempty(did_document_obj)
                remove(db, cn, ['{"document_properties.base.id" : "', id, '"}'])
            end
		end % do_remove

		
        function [did_document_obj,doc_versions] = do_search(did_mongodb_obj, searchoptions, searchparams)
            %searchoptions is not used
            
            db = did_mongodb_obj.connection;
		    cn = did_mongodb_obj.collection;
            if isa(searchparams,'did.query')
				searchparams = searchparams.to_searchstructure;
            end            
            if ~(isa(searchparams, 'struct'))
                error('You must pass in either an instance of did.query or struct')
            end
            if numel(searchparams) > 1
                query = did.implementations.mongodb.didquery2mongodb('', '', searchparams, '');
            else
                query = did.implementations.mongodb.didquery2mongodb(searchparams.searchstructure.field, ...
                                                                     searchparams.searchstructure.operation, ...
                                                                     searchparams.searchstructure.param1, ...
                                                                     searchparams.searchstructure.param2);
            end
            raw = find(db, cn,'Query', query);
            if ~isempty(raw)
                did_document_obj = did.document.empty(numel(raw), 0);
                for i = 1:numel(raw)
                    did_document_obj(i) = did.document(raw(i).document_properties);
                    doc_versions = did_document_obj(i).document_properties.base.document_version;
                end
		    else
				did_document_obj = [];
				doc_versions = [];
            end
		end % do_search()

        
		function [did_binarydoc_obj, key] = do_openbinarydoc(did_mongodb_obj, did_document_id, version)
		    error("Not implemented");
		end % do_binarydoc()

		function [did_binarydoc_matfid_obj] = do_closebinarydoc(did_mongodb_obj, did_binarydoc_matfid_obj)
		    error("Not implemented");
		end % do_closebinarydoc()    
    end
    
    methods(Static)
        
        function query = didquery2mongodb(field, operation, param1, param2)
            if numel(param1) > 1
                queries = string(1, numel(param1));
                for i = 1:numel(param1)
                    queries(i) = didquery2mongodb(param1(i).searchstructure.field, ...
                                            param1(i).searchstructure.operation, ...
                                            param1(i).searchstructure.param1, ...
                                            param1(i).searchstructure.param2);
                end
                query = jsonencode(struct('$and', queries));
                return
            end
            switch operation
                case {'exact_string', 'exact_number'}
                    query = jsonencode(struct(field, match));
                case 'regexp'
                    query = jsonencode(struct(field, struct('$regex', ['/', param1, '/i'])));
                case 'contains_string'
                    query =  jsonencode(struct(field, struct('$regex', pattern)));
                case 'lessthan'
                    query = jsonencode(struct(field, struct('$lt', value)));
                case 'lessthaneq'
                    query = jsonencode(struct(field, struct('$lte', value)));
                case 'greaterthan'
                    query = jsonencode(struct(field, struct('$gte', value)));
                case 'greaterthaneq'
                    query = jsonencode(struct(field, struct('$gte', value)));
                case 'hasfield'
                    query = jsonencode(struct(field, struct('$exists', true)));
                case 'depends_on'
                    query = jsonencode(struct(field, match));
                case 'or'
                    if numel(param1) > 1
                        q1 = didquery2mongodb('', '', param1, '');
                    else
                        q1 = didquery2mongodb(param1.searchstructure.field, ...
                                            param1.searchstructure.operation, ...
                                            param1.searchstructure.param1, ...
                                            param1.searchstructure.param2);
                    end
                    if numel(param2) > 1
                        q2 = didquery2mongodb('', '', param2, '');
                    else
                        q2 = didquery2mongodb(param2.searchstructure.field, ...
                                            param2.searchstructure.operation, ...
                                            param2.searchstructure.param1, ...
                                            param2.searchstructure.param2);
                    end 
                    query = jsonencode(struct('$or', [q1, q2]));
                otherwise
                    error('Invalid operation')
            end
        end
    end
end
