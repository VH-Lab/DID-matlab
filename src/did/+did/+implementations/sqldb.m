classdef (Abstract) sqldb < did.database
    % did.implementations.sqldb - An abstract implementation of a SQL database for DID

    properties
        % insert needed properties here
    end

    methods % constructor
        function sqldb_obj = sqldb(varargin)
            % SQLDB create a new SQLDB object
            %
            % SQLDB_OBJ = SQLDB(...)
            %
            % Creates a new SQLDB object.
            %
            % COMMAND can either be 'Load' or 'New'. The 2nd argument should be
            % the full pathname of where the files should be stored on disk.
            %
            % See also: DUMBJSONDB, SQLITEDB, POSTGRESDB
            connection = '';
            if nargin>1
                connection = varargin{2};
            end
            sqldb_obj = sqldb_obj@did.database(connection);
        end % sqldb()
    end

    methods % public
        function docids = alldocids(sqldb_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            % DOCIDS = ALLDOCIDS(SQLDB_OBJ)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.

            docids = sqldb_obj.db.alldocids();
        end % alldocids()
    end

    methods (Access=protected)

        function sqldb_obj = do_add(sqldb_obj, did_document_obj, add_parameters)
            namevaluepairs = {};
            fn = {};
            if nargin>2
                fn = fieldnames(add_parameters);
            end
            for i=1:numel(fn)
                if strcmpi(fn{i},'Update')
                    namevaluepairs{end+1} = 'Overwrite'; %#ok<AGROW>
                    namevaluepairs{end+1} = add_parameters.(fn{i}); %#ok<AGROW>
                end
            end
            sqldb_obj.db = sqldb_obj.db.add(did_document_obj.document_properties, namevaluepairs{:});
        end % do_add

        function [did_document_obj, version] = do_read(sqldb_obj, did_document_id, version)
            if nargin<3
                version = [];
            end
            [doc, version] = sqldb_obj.db.read(did_document_id, version);
            did_document_obj = did.document(doc);
        end % do_read

        function sqldb_obj = do_remove(sqldb_obj, did_document_id, versions)
            if nargin<3
                versions = [];
            end
            sqldb_obj = sqldb_obj.db.remove(did_document_id, versions);
        end % do_remove

        function [did_document_objs,doc_versions] = do_search(sqldb_obj, searchoptions, searchparams)
            if isa(searchparams,'did.query')
                searchparams = searchparams.to_searchstructure;
                if 0 % display
                    disp('search params');
                    for i=1:numel(searchparams)
                        searchparams(i),
                        searchparams(i).param1,
                        searchparams(i).param2,
                    end
                end
            end
            did_document_objs = {};
            [docs,doc_versions] = sqldb_obj.db.search(searchoptions, searchparams);
            for i=1:numel(docs)
                did_document_objs{i} = did.document(docs{i}); %#ok<AGROW>
            end
        end % do_search()

        % for now, let's disregard these

        function [did_binarydoc_obj, key] = do_openbinarydoc(sqldb_obj, did_document_id, version)
            did_binarydoc_obj = [];
            [fid, key] = sqldb_obj.db.openbinaryfile(did_document_id, version);
            if fid>0
                [filename,permission,machineformat,~] = fopen(fid);
                did_binarydoc_obj = did_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
                    'machineformat',machineformat,'permission',permission, 'doc_unique_id', did_document_id, 'key', key);
                did_binarydoc_obj.frewind(); % move to beginning of the file
            end
        end % do_binarydoc()

        function [did_binarydoc_matfid_obj] = do_closebinarydoc(sqldb_obj, did_binarydoc_matfid_obj)
            % DO_CLOSEBINARYDOC - close and unlock an DID_BINARYDOC_MATFID_OBJ
            %
            % DID_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(SQLDB_OBJ, DID_BINARYDOC_MATFID_OBJ, KEY, DID_DOCUMENT_ID)
            %
            % Close and unlock the binary file associated with DID_BINARYDOC_OBJ.

            sqldb_obj.db.closebinaryfile(did_binarydoc_matfid_obj.fid, ...
                did_binarydoc_matfid_obj.key, did_binarydoc_matfid_obj.doc_unique_id);
            did_binarydoc_matfid_obj.fclose();
        end % do_closebinarydoc()
    end
end
