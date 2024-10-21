classdef  matlabdumbjsondb < did.database

    properties
        db        % dumbjsondb object
    end

    methods

        function did_matlabdumbjsondb_obj = matlabdumbjsondb(varargin)
        % DID_MATLABDUMBJSONDB make a new MATLABDUMBJSONDB object
        % 
        % DID_MATLABDUMBJSONDB_OBJ = DID_MATLABDUMBJSONDB(COMMAND, PATHNAME)
        %
        % Creates a new MATLABDUMBJSONDB object.
        %
        % COMMAND can either be 'Load' or 'New'. The second argument
        % should be the full pathname of the location where the files
        % should be stored on disk.
        %
        % See also: DUMBJSONDB, DUMBJSONDB/DUMBJSONDB
            connection = '';
            if nargin>1,
                connection = varargin{2};
            end;
            did_matlabdumbjsondb_obj = did_matlabdumbjsondb_obj@did.database(connection);
            did_matlabdumbjsondb_obj.db = did.file.dumbjsondb(varargin{1:end},...
                'dirname','dumbjsondb','unique_object_id_field','base.id');
        end; % did_matlabdumbjsondb()
    end 

    methods, % public
        function docids = alldocids(did_matlabdumbjsondb_obj)
            % ALLDOCIDS - return all document unique reference numbers for the database
            %
            % DOCIDS = ALLDOCIDS(DID_MATLABDUMBJSONDB_OBJ)
            %
            % Return all document unique reference strings as a cell array of strings. If there
            % are no documents, empty is returned.
            %
                docids = did_matlabdumbjsondb_obj.db.alldocids();
        end; % alldocids()
    end;

    methods (Access=protected),

        function did_matlabdumbjsondb_obj = do_add(did_matlabdumbjsondb_obj, did_document_obj, add_parameters)
            namevaluepairs = {};
            fn = {};
            if nargin>2,
                fn = fieldnames(add_parameters);
            end;
            for i=1:numel(fn), 
                if strcmpi(fn{i},'Update'),
                    namevaluepairs{end+1} = 'Overwrite';
                    namevaluepairs{end+1} = getfield(add_parameters,fn{i});
                end;
            end;
            
            did_matlabdumbjsondb_obj.db = did_matlabdumbjsondb_obj.db.add(did_document_obj.document_properties, namevaluepairs{:});
        end; % do_add

        function [did_document_obj, version] = do_read(did_matlabdumbjsondb_obj, did_document_id, version);
            if nargin<3,
                version = [];
            end;
            [doc, version] = did_matlabdumbjsondb_obj.db.read(did_document_id, version);
            did_document_obj = did.document(doc);
        end; % do_read

        function did_matlabdumbjsondb_obj = do_remove(did_matlabdumbjsondb_obj, did_document_id, versions)
            if nargin<3,
                versions = [];
            end;
            did_matlabdumbjsondb_obj = did_matlabdumbjsondb_obj.db.remove(did_document_id, versions);
            
        end; % do_remove

        function [did_document_objs,doc_versions] = do_search(did_matlabdumbjsondb_obj, searchoptions, searchparams)
            if isa(searchparams,'did.query'),
                searchparams = searchparams.to_searchstructure;
                if 0, % display
                    disp('search params');
                    for i=1:numel(searchparams),
                        searchparams(i),
                        searchparams(i).param1,
                        searchparams(i).param2,
                    end
                end;
            end;
            did_document_objs = {};
            [docs,doc_versions] = did_matlabdumbjsondb_obj.db.search(searchoptions, searchparams);
            for i=1:numel(docs),
                did_document_objs{i} = did.document(docs{i});
            end;
        end; % do_search()

        function [did_binarydoc_obj, key] = do_openbinarydoc(did_matlabdumbjsondb_obj, did_document_id, version)
            did_binarydoc_obj = [];
            [fid, key] = did_matlabdumbjsondb_obj.db.openbinaryfile(did_document_id, version);
            if fid>0,
                [filename,permission,machineformat,encoding] = fopen(fid);
                did_binarydoc_obj = did_binarydoc_matfid('fid',fid,'fullpathfilename',filename,...
                    'machineformat',machineformat,'permission',permission, 'doc_unique_id', did_document_id, 'key', key);
                did_binarydoc_obj.frewind(); % move to beginning of the file
            end
        end; % do_binarydoc()

        function [did_binarydoc_matfid_obj] = do_closebinarydoc(did_matlabdumbjsondb_obj, did_binarydoc_matfid_obj)
            % DO_CLOSEBINARYDOC - close and unlock an DID_BINARYDOC_MATFID_OBJ
            %
            % DID_BINARYDOC_OBJ = DO_CLOSEBINARYDOC(DID_MATLABDUMBJSONDB_OBJ, DID_BINARYDOC_MATFID_OBJ, KEY, DID_DOCUMENT_ID)
            %
            % Close and unlock the binary file associated with DID_BINARYDOC_OBJ.
            %    
                did_matlabdumbjsondb_obj.db.closebinaryfile(did_binarydoc_matfid_obj.fid, ...
                    did_binarydoc_matfid_obj.key, did_binarydoc_matfid_obj.doc_unique_id);
                did_binarydoc_matfid_obj.fclose(); 
        end; % do_closebinarydoc()
    end;
end
