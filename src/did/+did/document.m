classdef document
    %DOCUMENT - DID_database storage item, general purpose data and parameter storage
    % The DID_DOCUMENT datatype for storing results in the DID_DATABASE
    %

    properties (SetAccess=protected,GetAccess=public)
        document_properties % a struct with the fields for the document
    end

    methods
        function did_document_obj = document(document_type, options)
            % DID_DOCUMENT - create a new DID_DATABASE object
            %
            % DID_DOCUMENT_OBJ = DID_DOCUMENT(DOCUMENT_TYPE, 'PARAM1', VALUE1, ...)
            %   or
            % DID_DOCUMENT_OBJ = DID_DOCUMENT(MATLAB_STRUCT)
            arguments
                document_type
            end
            arguments (Repeating)
                options
            end

            made_from_struct = 0;

            if nargin<1
                document_type = 'base';
            end

            if isstruct(document_type)
                document_properties = document_type;
                made_from_struct = 1;
            else  % create blank from definitions
                document_properties = did.document.readblankdefinition(document_type);
                document_properties.base.id = did.ido.unique_id();
                document_properties.base.datestamp = char(datetime('now','TimeZone','UTCLeapSeconds'));

                if numel(options)==1 % see if user put it all as one cell array
                    if iscell(options{1})
                        options = options{1};
                    end
                end
                if mod(numel(options),2)~=0
                    error('Variable inputs must be name/value pairs');
                end

                for i=1:2:numel(options) % assign variable arguments
                    try
                        document_properties = did.datastructures.assignPropertyPath( ...
                            document_properties, options{i}, options{i+1});
                    catch
                        error(['Could not assign document_properties.' options{i} '.']);
                    end
                end
            end

            did_document_obj.document_properties = document_properties;

            if ~made_from_struct
                did_document_obj = did_document_obj.reset_file_info();
            end

            % A name must be served by exactly one mechanism. Checking here
            % catches a malformed class definition the first time anyone
            % constructs one, rather than at the point where two mechanisms
            % disagree about membership.
            localValidateFileDeclarations(did_document_obj);

        end % document() creator

        function uid = id(did_document_obj)
            % ID - return the document unique identifier for an DID_DOCUMENT
            %
            % UID = ID (DID_DOCUMENT_OBJ)
            %
            % Returns the unique id of an DID_DOCUMENT
            % (Found at DID_DOCUMENT_OBJ.documentproperties.base.id)
            %
            uid = did_document_obj.document_properties.base.id;
        end % id()

        function did_document_obj = setproperties(did_document_obj, options)
            % SETPROPERTIES - Set property values of an DID_DOCUMENT object
            %
            % DID_DOCUMENT_OBJ = SETPROPERTIES(DID_DOCUMENT_OBJ, 'PROPERTY1', VALUE1, ...)
            %
            % Sets the property values of DID_DOCUMENT_OBJ.    PROPERTY values should be expressed
            % relative to DID_DOCUMENT_OBJ.document_properties (see example).
            %
            % See also: DID_DOCUMENT, DID_DOCUMENT/DID_DOCUMENT
            %
            % Example:
            %   mydoc = mydoc.setproperties('base.name','mydoc name');
            arguments
                did_document_obj
            end
            arguments (Repeating)
                options
            end

            newproperties = did_document_obj.document_properties;
            for i=1:2:numel(options)
                try
                    newproperties = did.datastructures.assignPropertyPath( ...
                        newproperties, options{i}, options{i+1});
                catch
                    error(['Error in assigning ' options{i} '.']);
                end
            end

            did_document_obj.document_properties = newproperties;
        end % setproperties

        function did_document_obj_out = plus(did_document_obj_a, did_document_obj_b)
            % PLUS - merge two DID_DOCUMENT objects
            %
            % DID_DOCUMENT_OBJ_OUT = PLUS(DID_DOCUMENT_OBJ_A, DID_DOCUMENT_OBJ_B)
            %
            % Merges the DID_DOCUMENT objects A and B. First, the 'document_class'
            % superclasses are merged. Then the fields of B are merged into A.
            % Where both documents have the same field, B's value is taken --
            % did.datastructures.structmerge, which does the merging in step 4,
            % is documented as "when S1 and S2 share the same fieldname, the
            % value of S2 is taken". Dependencies follow the same rule: a
            % 'depends_on' entry whose name is in both is taken from B.

            did_document_obj_out = did_document_obj_a;
            % Step 1): Merge superclasses
            did_document_obj_out.document_properties.document_class.superclasses = ...
                (cat(1,did_document_obj_out.document_properties.document_class.superclasses,...
                did_document_obj_b.document_properties.document_class.superclasses));
            otherproperties = rmfield(did_document_obj_b.document_properties, 'document_class');

            % Step 2): Merge dependencies if we have to
            if isfield(did_document_obj_out.document_properties,'depends_on') && ...
               isfield(did_document_obj_b.document_properties,'depends_on')
                % Merge by name. Concatenating produced a depends_on holding
                % the same name twice whenever both documents declared it,
                % which every reader here resolves with matches(1) -- so the
                % duplicate was invisible to a lookup but real in the stored
                % document, and a second one could never be reached.
                %
                % B wins a name collision, which is what structmerge does for
                % every other field in step 4, and what ndi.document's plus
                % has always done for dependencies.
                aDepends = did_document_obj_out.document_properties.depends_on;
                bDepends = did_document_obj_b.document_properties.depends_on;
                if isempty(aDepends)
                    merged = bDepends(:);
                elseif isempty(bDepends)
                    merged = aDepends(:);
                else
                    merged = aDepends(:);
                    mergedNames = {merged.name};
                    for k=1:numel(bDepends)
                        match = find(strcmpi(bDepends(k).name, mergedNames));
                        if isempty(match)
                            merged(end+1) = bDepends(k); %#ok<AGROW>
                            mergedNames{end+1} = bDepends(k).name; %#ok<AGROW>
                        else
                            merged(match(1)) = bDepends(k);
                        end
                    end
                end
                did_document_obj_out.document_properties.depends_on = merged;
                otherproperties = rmfield(otherproperties,'depends_on');
            end

            % Step 3): Merge file_list
            if isfield(did_document_obj_b.document_properties,'files')
                % does doc a also have it?
                if isfield(did_document_obj_out.document_properties,'files')
                    file_list = cat(2,did_document_obj_out.document_properties.files.file_list(:)', ...
                        did_document_obj_b.document_properties.files.file_list(:)');
                    file_info = cat(1,did_document_obj_out.document_properties.files.file_info(:),...
                        did_document_obj_b.document_properties.files.file_info(:));
                    if numel(unique(file_list))~=numel(file_list)
                        error('Documents have files of the same name. Cannot be combined.');
                    end
                    did_document_obj_out.document_properties.files.file_list = file_list;
                    did_document_obj_out.document_properties.files.file_info = file_info;
                else
                    % doc a doesn't have it, just use doc b's info
                    did_document_obj_out.document_properties.files = did_document_obj_b.document_properties.files;
                end
            end

            % Step 4): Merge the other fields
            did_document_obj_out.document_properties = did.datastructures.structmerge(did_document_obj_out.document_properties,...
                otherproperties);
        end % plus()

        function d = dependency_value(did_document_obj, dependency_name, options)
            % DEPENDENCY_VALUE - return dependency value given dependency name
            %
            % D = DEPENDENCY_VALUE(DID_DOCUMENT_OBJ, DEPENDENCY_NAME, ...)
            %
            % Examines the 'depends_on' field (if it is present) for a given DID_DOCUMENT_OBJ
            % and returns the 'value' associated with the given 'name'. If there is no such
            % field (either 'depends_on' or 'name'), then D is empty and an error is generated.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ErrorIfNotFound (1)      | If 1, generate an error if the entry is
            %                          |   not found. Otherwise, return empty.

            arguments
                did_document_obj
                dependency_name
                options.ErrorIfNotFound (1,1) logical = 1
            end

            d = [];
            notfound = 1;

            hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
            if hasdependencies
                % As in dependency_value_n and set_dependency_value: an empty
                % depends_on has no .name to index.
                hasdependencies = numel(did_document_obj.document_properties.depends_on)>=1;
            end

            if hasdependencies
                matches = find(strcmpi(dependency_name,{did_document_obj.document_properties.depends_on.name}));
                if numel(matches)>0
                    notfound = 0;
                    d = getfield(did_document_obj.document_properties.depends_on(matches(1)),'value');
                end
            end

            if notfound && options.ErrorIfNotFound
                error(['Dependency name ' dependency_name ' not found.']);
            end
        end %

        function did_document_obj = set_dependency_value(did_document_obj, dependency_name, value, options)
            % SET_DEPENDENCY_VALUE - set the value of a dependency field
            %
            % DID_DOCUMENT_OBJ = SET_DEPENDENCY_VALUE(DID_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
            %
            % Examines the 'depends_on' field (if it is present) for a given DID_DOCUMENT_OBJ
            % and, if there is a dependency with a given 'dependency_name', then the value of the
            % dependency is set to DEPENDENCY_VALUE.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ErrorIfNotFound (1)      | If 1, generate an error if the entry is
            %                          |   not found. Otherwise, generate no error but take no action.

            arguments
                did_document_obj
                dependency_name
                value
                options.ErrorIfNotFound (1,1) logical = 1
            end

            notfound = 1;

            hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
            if hasdependencies
                % As in dependency_value_n: an empty depends_on has no .name
                % to index, so the branch below would throw rather than fall
                % through to creating the list.
                hasdependencies = numel(did_document_obj.document_properties.depends_on)>=1;
            end
            d_struct = struct('name',dependency_name,'value',value);

            if hasdependencies
                matches = find(strcmpi(dependency_name,{did_document_obj.document_properties.depends_on.name}));
                if numel(matches)>0
                    notfound = 0;
                    did_document_obj.document_properties.depends_on(matches(1)).value = value;
                elseif ~options.ErrorIfNotFound % add it
                    did_document_obj.document_properties.depends_on(end+1) = d_struct;
                    notfound = 0;
                end
            elseif ~options.ErrorIfNotFound
                did_document_obj.document_properties.depends_on = d_struct;
                notfound = 0;
            end

            if notfound && options.ErrorIfNotFound
                error(['Dependency name ' dependency_name ' not found.']);
            end
        end %

        function d = dependency_value_n(did_document_obj, dependency_name, options)
            % DEPENDENCY_VALUE_N - return dependency values from list given dependency name
            %
            % D = DEPENDENCY_VALUE_N(DID_DOCUMENT_OBJ, DEPENDENCY_NAME, ...)
            %
            % Examines the 'depends_on' field (if it is present) for a given DID_DOCUMENT_OBJ
            % and returns the 'values' associated with the given 'name_i', where i varies from 1 to the
            % maximum number of entries titled 'name_i'. If there is no such field (either
            % 'depends_on' or 'name_i'), then D is empty and an error is generated.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ErrorIfNotFound (1)      | If 1, generate an error if the entry is
            %                          |   not found. Otherwise, return empty.

            arguments
                did_document_obj
                dependency_name
                options.ErrorIfNotFound (1,1) logical = 1
            end

            d = {};
            notfound = 1;

            hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
            if hasdependencies
                % A declaration of "depends_on": [ ] decodes to an empty
                % array, which has no .name to index. Treat it as no
                % dependencies rather than reaching for a field of a double.
                hasdependencies = numel(did_document_obj.document_properties.depends_on)>=1;
            end

            if hasdependencies
                finished = 0;
                i = 1;
                while ~finished
                    matches = find(strcmpi([dependency_name '_' int2str(i)],{did_document_obj.document_properties.depends_on.name}));
                    if isempty(matches) && i == 1
                        % No 'name_1', so accept a plain 'name'. A document
                        % that carries a single dependency unnumbered is the
                        % same thing as one numbered _1, and callers should
                        % not have to know which form a definition used.
                        matches = find(strcmpi(dependency_name,{did_document_obj.document_properties.depends_on.name}));
                        if ~isempty(matches)
                            % An empty value is the placeholder a blank
                            % definition carries, not an entry in the list.
                            if isempty(did_document_obj.document_properties.depends_on(matches(1)).value)
                                matches = [];
                            end
                        end
                    end
                    if numel(matches)>0
                        notfound = 0;
                        d{i} = getfield(did_document_obj.document_properties.depends_on(matches(1)),'value');
                    end
                    finished = numel(matches)==0;
                    i = i + 1;
                end
            end

            if notfound && options.ErrorIfNotFound
                error(['Dependency name ' dependency_name ' not found.']);
            end
        end %

        function did_document_obj = add_dependency_value_n(did_document_obj, dependency_name, value, options)
            % ADD_DEPENDENCY_VALUE_N - add a dependency to a named list
            %
            % DID_DOCUMENT_OBJ = ADD_DEPENDENCY_VALUE_N(DID_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, ...)
            %
            % Examines the 'depends_on' field (if it is present) for a given DID_DOCUMENT_OBJ
            % and adds a dependency name 'dependency_name_(n+1)', where n is the number of entries with
            % the form 'depenency_name_i' that exist presently. If there is no dependency field with that, then
            % an entry is added.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ErrorIfNotFound (1)      | If 1, generate an error if the entry is
            %                          |   not found. Otherwise, generate no error but take no action.

            arguments
                did_document_obj
                dependency_name
                value
                options.ErrorIfNotFound (1,1) logical = 1
            end

            d = dependency_value_n(did_document_obj, dependency_name, 'ErrorIfNotFound', 0);
            hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
            if ~hasdependencies && options.ErrorIfNotFound
                error('This document does not have any dependencies.');
            else
                d_struct = struct('name',[dependency_name '_' int2str(numel(d)+1)],'value',value);
                did_document_obj = set_dependency_value(did_document_obj, d_struct.name, d_struct.value, 'ErrorIfNotFound', 0);
            end
        end %

        function did_document_obj = remove_dependency_value_n(did_document_obj, dependency_name, value, n, options)
            % REMOVE_DEPENDENCY_VALUE_N - remove a dependency from a named list
            %
            % DID_DOCUMENT_OBJ = REMOVE_DEPENDENCY_VALUE_N(DID_DOCUMENT_OBJ, DEPENDENCY_NAME, VALUE, N, ...)
            %
            % Examines the 'depends_on' field (if it is present) for a given DID_DOCUMENT_OBJ
            % and removes the dependency name 'dependency_name_(n)'.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ErrorIfNotFound (1)      | If 1, generate an error if the entry is
            %                          |   not found. Otherwise, generate no error but take no action.

            arguments
                did_document_obj
                dependency_name
                value
                n
                options.ErrorIfNotFound (1,1) logical = 1
            end

            d = dependency_value_n(did_document_obj, dependency_name, 'ErrorIfNotFound', 0);
            hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
            if ~hasdependencies && options.ErrorIfNotFound
                error('This document does not have any dependencies.');
            end

            if n>numel(d) && options.ErrorIfNotFound
                error(['Number to be removed ' int2str(n) ' is greater than total number of entries ' int2str(numel(d)) '.']);
            end

            match = find(strcmpi([dependency_name '_' int2str(n)],{did_document_obj.document_properties.depends_on.name}));
            if numel(match)~=1
                error(['Could not locate entry ' dependency_name '_' int2str(n)]);
            end

            did_document_obj.document_properties.depends_on = did_document_obj.document_properties.depends_on([1:match-1 match+1:end]);

            for i=n+1:numel(d)
                match = find(strcmpi([dependency_name '_' int2str(i)],{did_document_obj.document_properties.depends_on.name}));
                if numel(match)~=1
                    error(['Could not locate entry ' dependency_name '_' int2str(i)]);
                end
                did_document_obj.document_properties.depends_on(match).name = [dependency_name '_' int2str(i-1)];
            end
        end %

        function did_document_obj = add_file(did_document_obj, name, location, options)
            % ADD_FILE - add a file to a did.document
            %
            % DID_DOCUMENT_OBJ = ADD_FILE(DID_DOCUMENT_OBJ, NAME, LOCATION, ...)
            %
            % Adds a file's information to a did.document, for later ingestion into
            % the database. NAME is the name of the file record for the document.
            % LOCATION is a string that identifies the file or URL location on the
            % internet.
            %
            % Note: NAME must not include any file separator characters on any
            % platform (':','\','/') and may not have leading or trailing spaces.
            % Leading or trailing spaces will be trimmed.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ingest (1 or 0)          | 0/1 Should the file be copied into the local
            %                          |   database by did.database.add_doc() ?
            %                          |   If LOCATION does not begin with 'http://' or
            %                          |   'https://', then ingest is 1 by default.
            %                          |   If LOCATION begins with 'http(s)://', then
            %                          |   ingest is 0 by default. Note that the file
            %                          |   is only copied upon the later call to
            %                          |   did.database.add_doc(), not at the call to
            %                          |   did.document.add_file().
            % delete_original (1 or 0) | 0/1 Should we delete the file after ingestion?
            %                          |   If LOCATION does not begin with 'http://' or
            %                          |   'https://', then delete_original is 1 by default.
            %                          |   If LOCATION begins with 'http(s)://', then
            %                          |   delete_original is 0 by default. Note that the
            %                          |   file is only deleted upon the later call to
            %                          |   did.database.add_doc(), not at the call to
            %                          |   did.document.add_file().
            % location_type ('file' or | Can be 'file' or 'url'. By default, it is set
            %   'url')                 |   to 'file' if LOCATION does not begin with
            %                          |   'http://' or 'https://', and 'url' otherwise.

            arguments
                did_document_obj
                name
                location
                options.ingest = NaN
                options.delete_original = NaN
                options.location_type = NaN
            end
            
            % Step 1: make sure that the did_document_obj has a 'files' portion
            % and that name is one of the listed files.

            [b,msg,fI_index] = did_document_obj.is_in_file_list(name);
            if ~b
                error(msg);
            end

            % A series member must not gain an inline file_info entry: the
            % manifest would not know about it, and the two mechanisms would
            % then disagree about what the series contains.
            seriesStem = localSeriesMemberStem(did_document_obj, name);
            if ~isempty(seriesStem)
                error('DID:Document:add_file:isSeriesMember', ...
                    ['"%s" is a member of the file series "%s". Members are ' ...
                     'added together by addFileSeries, which records them in ' ...
                     'the series manifest.'], name, seriesStem);
            end

            % Step 2: detect the default property values, if necessary, and build the structure
            detected_location_type = 'file'; % default
            location = strip(location);  % remove whitespace
            if (startsWith(location,'https://','IgnoreCase',true) || ...
                startsWith(location,'http://','IgnoreCase',true))
                detected_location_type = 'url';
            end

            if isnan(options.ingest) % assign default value
                switch detected_location_type
                    case 'url'
                        options.ingest = 0;
                    case 'file'
                        options.ingest = 1;
                    otherwise
                        error(['Unknown detected_location_type ' detected_location_type '.']);
                end
            end
            if isnan(options.delete_original) % assign default value
                switch detected_location_type
                    case 'url'
                        options.delete_original = 0;
                    case 'file'
                        options.delete_original = 1;
                    otherwise
                        error(['Unknown detected_location_type ' detected_location_type '.']);
                end
            end
            if isnan(options.location_type) % assign default value
                options.location_type = detected_location_type;
            end

            % Step 2b: build the structure to add

            location_here = struct();
            location_here.delete_original = options.delete_original;
            location_here.uid = did.ido.unique_id();
            location_here.location = location;
            location_here.parameters = '';
            location_here.location_type = options.location_type;
            location_here.ingest = options.ingest;

            % Step 3: Add the file to the list

            if isempty(fI_index)
                fI_index = numel(did_document_obj.document_properties.files.file_info)+1;
                file_info_here = struct('name',name,'locations',location_here);
                did_document_obj.document_properties.files.file_info(fI_index) = file_info_here;
            else
                did_document_obj.document_properties.files.file_info(fI_index).locations(end+1) = location_here;
            end

        end % add_file

        function did_document_obj = remove_file(did_document_obj, name, location, options)
            % REMOVE_FILE - remove file information from a did.document
            %
            % DID_DOCUMENT_OBJ = REMOVE_FILE(DID_DOCUMENT_OBJ, NAME, [LOCATION], ...)
            %
            % Removes the file information for a name or a name and location
            % combination from a did.document() object.
            %
            % If LOCATION is not specified or is empty, then all locations are removed.
            %
            % If DID_DOCUMENT_OBJ does not have a file NAME in its file_list, then an error is
            % generated.
            %
            % This function accepts name/value pairs that alter its default behavior:
            % Parameter (default)      | Description
            % -----------------------------------------------------------------
            % ErrorIfNoFileInfo (0)    | 0/1 If a name is specified and the
            %                          |   file info is already empty, should we
            %                          |   produce an error?

            arguments
                did_document_obj
                name
                location = []
                options.ErrorIfNoFileInfo (1,1) logical = 0
            end

            [b,msg,fI_index] = did_document_obj.is_in_file_list(name);
            if ~b
                error(msg);
            end

            if isempty(fI_index)
                if options.ErrorIfNoFileInfo
                    error(['No file_info for name ' name ' .']);
                end
            end

            if isempty(location)
                did_document_obj.document_properties.files.file_info(fI_index) = [];
                return;
            end

            location_match_index = find(strcmpi(location,{did_document_obj.document_properties.files.file_info(fI_index).locations.location}));

            if isempty(location_match_index)
                if options.ErrorIfNoFileInfo
                    error(['No match found for file ' name ' with location ' location '.']);
                end
            else
                did_document_obj.document_properties.files.file_info(fI_index).locations = ...
                    did_document_obj.document_properties.files.file_info(fI_index).locations([1:location_match_index-1 location_match_index+1:end]);
            end

        end % remove_file

        function [b, msg, fI_index] = is_in_file_list(did_document_obj, name)
            % IS_IN_FILE_LIST - is a file name in a did.document's file list?
            %
            % [B, MSG, FI_INDEX] = IS_IN_FILE_LIST(DID_DOCUMENT_OBJ, NAME)
            %
            % Is the file NAME a valid named binary file for the did.document
            % DID_DOCUMENT_OBJ? If so, B is 1; else, B is 0.
            %
            % A name is a valid name if it appears in DID_DOCUMENT_OBJ....
            % document_properties.files.file_list or if it is a numbered
            % file with an entry in document_properties.files.file_list
            % as 'filename.ext_#'. (For example, 'filename.ext_1' would
            % be valid if 'filename.ext_# is in the file_list.)
            %
            % If the file NAME is not valid, a reason is returned in MSG.
            %
            % If it is a valid file NAME, then the index value of NAME
            % in DID_DOCUMENT_OBJ.DOCUMENT_PROPERTIES.FILES.FILE_INFO is also
            % returned.

            b = 1;
            msg = '';
            fI_index = [];

            % Step 1: does this did.document have 'files' at all?

            if ~isfield(did_document_obj.document_properties,'files')
                b = 0;
                msg = 'This type of document does not accept files; it has no ''files'' field';
                return;
            end

            % Step 2: is it a valid filename for this document? It must appear in files.file_list
            %   or be a proper numbered file if files.file_list{i} has has the form 'filename.ext_#'.

            % Step 2a: see if name ends in '_#', where # is a non-negative integer.

            search_name = name;
            underscores = find(name=='_');
            if ~isempty(underscores)
                n = str2num(name(underscores(end)+1:end));
                if ~isempty(n) % we have a number
                    search_name = [name(1:underscores(end)) '#'];
                end
            end

            % Step 2b: now we have the name to search for; make sure it is in the file list

            I = find(strcmpi(search_name,did_document_obj.document_properties.files.file_list));
            if isempty(I)
                % Second resolution rule, added by file series. The lookup
                % above maps NAME_12 to NAME_#; this maps it to the series
                % NAME when that misses. A member carries no file_info entry
                % of its own -- membership is the manifest's to answer -- so
                % fI_index stays empty while the NAME is still valid.
                if ~isempty(localSeriesMemberStem(did_document_obj, name))
                    fI_index = [];
                    return;
                end
                b = 0;
                msg = ['No such file ' name ' in file_list of did.document; file must match an expected name.'];
                return;
            end

            % Step 3: now, find which file_info corresponds to search_name, if any

            fI_index = find(strcmpi(name,{did_document_obj.document_properties.files.file_info.name}));

        end % is_in_file_list()

        function uids = fileUids(did_document_obj, name)
            % FILEUIDS - the uids recorded for a named file, from memory alone
            %
            % UIDS = FILEUIDS(DID_DOCUMENT_OBJ, NAME)
            %
            % Returns a cell array of the uid strings recorded for the file
            % NAME in this document, in the order the locations were added by
            % ADD_FILE. Returns {} if this document has no such file.
            %
            % This reads only the in-memory document; it runs no query. It is
            % the first half of resolving a file without touching the
            % database, the second half being did.file.cachedPathForUid, and
            % did.database/cachedPathForFile is the two together.
            %
            % IMPORTANT: this answers about THE DOCUMENT YOU HOLD, which is
            % not necessarily the document in the database. A file added to a
            % stored copy after this object was read is not visible here. For
            % iterating the files a document declares -- the case this exists
            % for -- that is exactly right; when you need what the database
            % currently holds, use did.database/exist_doc instead.
            %
            % See also: did.database/cachedPathForFile, did.file.cachedPathForUid

            uids = {};

            if ~isfield(did_document_obj.document_properties,'files')
                return;
            end
            files = did_document_obj.document_properties.files;
            if ~isfield(files,'file_info') || isempty(files.file_info)
                return;
            end

            index = find(strcmpi(name,{files.file_info.name}));
            if isempty(index)
                return;
            end

            locations = files.file_info(index(1)).locations;
            uids = cell(1,numel(locations));
            for i=1:numel(locations)
                if isfield(locations(i),'uid')
                    uids{i} = locations(i).uid;
                else
                    uids{i} = '';
                end
            end
            uids = uids(~cellfun('isempty',uids));

        end % fileUids()

        function names = seriesNames(did_document_obj)
            % SERIESNAMES - the file series this document's class declares
            %
            % NAMES = SERIESNAMES(DID_DOCUMENT_OBJ)
            %
            % Returns a cell array of the names declared in
            % document_properties.files.file_series, or {} if this class
            % declares none.
            %
            % A declared name IS the series' manifest: it is an ordinary file
            % in file_list, and its members are NAME_1 ... NAME_N. Declaring
            % the manifest rather than a separate NAME_# entry is what lets
            % code that knows nothing about series still carry the manifest
            % correctly, and skip the members visibly rather than enumerate
            % them wrongly.

            names = {};
            if ~isfield(did_document_obj.document_properties,'files')
                return;
            end
            files = did_document_obj.document_properties.files;
            if ~isfield(files,'file_series') || isempty(files.file_series)
                return;
            end
            names = files.file_series;
            if ~iscell(names)
                names = {names};
            end

        end % seriesNames()

        function tf = isFileSeries(did_document_obj, name)
            % ISFILESERIES - is NAME declared as a file series by this document?
            %
            % TF = ISFILESERIES(DID_DOCUMENT_OBJ, NAME)
            %
            % Case-insensitive, matching did.document/is_in_file_list.

            tf = any(strcmpi(name, did_document_obj.seriesNames()));

        end % isFileSeries()

        function [n, nPresent] = seriesCount(did_document_obj, name)
            % SERIESCOUNT - how many members a series has, WITHOUT reading anything
            %
            % [N, NPRESENT] = SERIESCOUNT(DID_DOCUMENT_OBJ, NAME)
            %
            % N is the number of member SLOTS -- the series runs NAME_1 to
            % NAME_N. NPRESENT is how many of those actually exist; a sparse
            % series has fewer, because a member with nothing to store is not
            % written. Both are 0 for a declared series that has not been
            % populated.
            %
            % WHY THIS LIVES ON THE DOCUMENT. Without it, answering "how many
            % members?" would mean either paging a cloud listFiles or fetching
            % the manifest -- which for a large series is most of a megabyte,
            % possibly over the network. A count is a few bytes and is wanted
            % constantly: sizing an upload, reporting progress, deciding
            % whether a dataset is complete. So it is recorded per series when
            % the series is added, next to the name rather than per member.

            n = 0; nPresent = 0;

            index = localSeriesInfoIndex(did_document_obj, name);
            if isempty(index)
                return;
            end
            si = did_document_obj.document_properties.files.series_info(index);
            n = si.count;
            nPresent = si.n_present;

        end % seriesCount()

        function root = seriesSourceRoot(did_document_obj, name)
            % SERIESSOURCEROOT - the directory a series' members came from
            %
            % ROOT = SERIESSOURCEROOT(DID_DOCUMENT_OBJ, NAME)
            %
            % Returns '' when no root was recorded.
            %
            % Members record their source path RELATIVE to this root, in the
            % manifest. The root is kept here, as ONE string, so that a
            % document shared with someone else exposes one directory name to
            % review or clear rather than one copy of it per member.

            root = '';
            index = localSeriesInfoIndex(did_document_obj, name);
            if ~isempty(index)
                root = did_document_obj.document_properties.files.series_info(index).source_root;
            end

        end % seriesSourceRoot()

        function entries = seriesIngestLocations(did_document_obj, name)
            % SERIESINGESTLOCATIONS - where a series' members are, pending ingestion
            %
            % ENTRIES = SERIESINGESTLOCATIONS(DID_DOCUMENT_OBJ, NAME)
            %
            % Returns a struct array with one entry per PRESENT member, with
            % fields index, uid, location, location_type, ingest,
            % delete_original and parameters. Empty if the series has not been
            % added, or if the document has already been ingested.
            %
            % This record is TRANSIENT. It is what lets the database copy each
            % member from where it currently sits into FileDir/<uid>, and
            % did.document.stripSeriesIngestLocations removes it before a
            % document's JSON is stored, so member paths never persist and
            % never travel to the cloud.
            %
            % Contrast files.file_info(i).locations, which survives ingestion.
            %
            % See also: did.document/addFileSeries,
            %           did.document.stripSeriesIngestLocations

            arguments
                did_document_obj
                name (1,:) char
            end

            entries = did.datastructures.emptystruct('index','uid','location', ...
                'location_type','ingest','delete_original','parameters');

            index = localSeriesInfoIndex(did_document_obj, name);
            if isempty(index), return; end

            si = did_document_obj.document_properties.files.series_info(index);
            if ~isfield(si,'ingest_locations'), return; end
            if isempty(si.ingest_locations), return; end
            entries = si.ingest_locations;

        end % seriesIngestLocations()

        function did_document_obj = addFileSeries(did_document_obj, name, locations, options)
            % ADDFILESERIES - add a whole file series to a did.document at once
            %
            % DOC = ADDFILESERIES(DOC, NAME, LOCATIONS)
            % DOC = ADDFILESERIES(DOC, NAME, LOCATIONS, 'indices', IDX, ...)
            %
            % NAME must be declared in this class's files.file_series. The
            % members become NAME_1 ... NAME_N; NAME itself is the manifest
            % that records them, and is added as an ordinary file.
            %
            % Inputs:
            %   LOCATIONS - cellstr of source paths, one per member being added
            %
            % Optional Name-Value Arguments:
            %   indices ([])      - ONE-BASED member numbers, one per entry of
            %       LOCATIONS. Default 1:numel(LOCATIONS), i.e. dense. Pass
            %       them explicitly for a SPARSE series -- a chunk grid whose
            %       empty regions were never written -- which is the case the
            %       series mechanism exists for and which a NAME_# entry
            %       cannot express.
            %   sourceRoot ('')   - the directory the members came from. Default
            %       '' derives the longest common directory prefix. Pass a root
            %       to override, or set recordSourceNames false to record none.
            %   recordSourceNames (true) - record each member's path relative to
            %       the root, as permanent provenance in the manifest. Absolute
            %       paths never PERSIST: a full path exposes a directory layout
            %       the moment a document is shared. Setting this false costs
            %       only the provenance -- ingestion locates members from the
            %       transient ingest_locations record, not from these names.
            %   uidWidth (33)     - passed through to did.file.writeSeriesManifest
            %   deleteOriginal (NaN) - should ingestion delete each member's
            %       original file? NaN follows add_file's per-type default: 1
            %       for a local file, 0 for a URL. Pass 0 to keep the sources.
            %
            % INDICES ARE ONE-BASED, matching the live NAME_# convention set by
            % ingested epoch data (ndi.daq.reader.mfdaq writes _seg.nbf_1
            % upward). The manifest's own array is zero-based; the conversion
            % happens here and nowhere else.
            %
            % See also: did.document/seriesCount, did.file.writeSeriesManifest

            arguments
                did_document_obj
                name (1,:) char
                locations cell
                options.indices double = []
                options.sourceRoot (1,:) char = ''
                options.recordSourceNames (1,1) logical = true
                options.uidWidth (1,1) {mustBePositive, mustBeInteger} = 33
                options.deleteOriginal (1,1) double = NaN
            end

            if ~did_document_obj.isFileSeries(name)
                error('DID:Document:addFileSeries:notDeclared', ...
                    ['"%s" is not declared as a file series by this document ' ...
                     'class. Add it to files.file_series in the class definition.'], name);
            end

            if ~isempty(localSeriesInfoIndex(did_document_obj, name))
                error('DID:Document:addFileSeries:alreadyAdded', ...
                    ['The series "%s" has already been added to this document. ' ...
                     'Use removeFileSeries first to replace it.'], name);
            end

            indices = options.indices;
            if isempty(indices)
                indices = 1:numel(locations);
            end
            if numel(indices) ~= numel(locations)
                error('DID:Document:addFileSeries:lengthMismatch', ...
                    'indices has %d entries but locations has %d.', ...
                    numel(indices), numel(locations));
            end
            if ~isempty(indices)
                if any(indices < 1) || any(indices ~= round(indices))
                    error('DID:Document:addFileSeries:badIndex', ...
                        'Member indices must be positive integers (one-based).');
                end
                if numel(unique(indices)) ~= numel(indices)
                    error('DID:Document:addFileSeries:duplicateIndex', ...
                        'Member indices must be unique.');
                end
            end

            % Derive the root and the relative names, unless told not to.
            sourceNames = {};
            root = options.sourceRoot;
            if options.recordSourceNames
                if isempty(root)
                    root = localCommonRoot(locations);
                end
                if ~isempty(root)
                    sourceNames = localRelativeNames(locations, root);
                else
                    % No meaningful common root: the members are scattered, and
                    % putting absolute paths in the MANIFEST would be both a
                    % disclosure and the bloat it exists to avoid. Record none.
                    % Locatability does not depend on this -- ingest_locations
                    % below carries the paths, and is stripped before storage.
                    sourceNames = {};
                end
            else
                root = '';
            end

            n = 0;
            if ~isempty(indices), n = max(indices); end

            % Slot i of these arrays is member i (one-based); the manifest
            % writes them zero-based, which is the only place the two differ.
            uids = repmat({''}, 1, n);
            relnames = repmat({''}, 1, n);
            for i = 1:numel(locations)
                uids{indices(i)} = did.ido.unique_id();
                if ~isempty(sourceNames)
                    relnames{indices(i)} = sourceNames{i};
                end
            end

            manifestPath = [tempname '.manifest'];
            if isempty(sourceNames)
                did.file.writeSeriesManifest(manifestPath, uids, ...
                    'uidWidth', options.uidWidth);
            else
                did.file.writeSeriesManifest(manifestPath, uids, ...
                    'sourceNames', relnames, 'uidWidth', options.uidWidth);
            end

            % The manifest is an ORDINARY file under the series' own name, so
            % every path that already carries a document's files carries it too.
            did_document_obj = did_document_obj.add_file(name, manifestPath);

            % Where each member's bytes are RIGHT NOW, so that ingestion can
            % find them. This is transient: did.document.stripSeriesIngestLocations
            % removes it before a document's JSON is stored, so absolute paths
            % exist only between authoring and ingestion and never travel.
            %
            % It is deliberately not called 'locations'. file_info.locations
            % survives ingestion; this does not, and giving two fields with
            % opposite lifetimes the same name reads fine today and misleads
            % whoever later assumes they behave alike.
            %
            % Carrying the uid and the index here is what lets ingestion work
            % without opening the manifest at all: it has the destination
            % (FileDir/<uid>), the source, and the files-table filename
            % (NAME_<index>). The manifest stays a download-side artifact.
            ingestLocations = localIngestLocations(locations, indices, uids, ...
                options.deleteOriginal);

            entry = struct('name', name, 'count', n, ...
                'n_present', numel(locations), 'source_root', root, ...
                'ingest_locations', {ingestLocations});
            if ~isfield(did_document_obj.document_properties.files,'series_info')
                did_document_obj.document_properties.files.series_info = ...
                    did.datastructures.emptystruct('name','count','n_present', ...
                        'source_root','ingest_locations');
            end
            k = numel(did_document_obj.document_properties.files.series_info)+1;
            did_document_obj.document_properties.files.series_info(k) = entry;

        end % addFileSeries()

        function did_document_obj = removeFileSeries(did_document_obj, name)
            % REMOVEFILESERIES - drop a file series' record from a did.document
            %
            % DOC = REMOVEFILESERIES(DOC, NAME)
            %
            % Removes the series' record and its manifest file entry. The
            % DECLARATION in files.file_series is untouched -- that belongs to
            % the class, not to this document -- so the series may be added again.

            arguments
                did_document_obj
                name (1,:) char
            end

            index = localSeriesInfoIndex(did_document_obj, name);
            if isempty(index)
                error('DID:Document:removeFileSeries:notAdded', ...
                    'The series "%s" has not been added to this document.', name);
            end

            si = did_document_obj.document_properties.files.series_info;
            si(index) = [];
            did_document_obj.document_properties.files.series_info = si;

            % Drop the manifest's file entry too, if one was recorded.
            files = did_document_obj.document_properties.files;
            if isfield(files,'file_info') && ~isempty(files.file_info)
                fI = find(strcmpi(name,{files.file_info.name}));
                if ~isempty(fI)
                    files.file_info(fI) = [];
                    did_document_obj.document_properties.files = files;
                end
            end

        end % removeFileSeries()

        function did_document_obj = reset_file_info(did_document_obj)
            % RESET_FILE_INFO - reset the file information parameters for a new did.document
            %
            % DID_DOCUMENT_OBJ = RESET_FILE_INFO(DID_DOCUMENT_OBJ)
            %
            % Reset (make empty) all file info structures for a new did.document object.
            %
            % Sets document_properties.files.file_info to an empty structure

            % First, check if we even have file info
            if ~isfield(did_document_obj.document_properties,'files')
                return;
            end

            % Now, clear it out:
            did_document_obj.document_properties.files.file_info = did.datastructures.emptystruct('name','locations');

            % A series' per-instance record is reset with the rest. The
            % DECLARATION (files.file_series, from the class definition) is
            % left alone: it says which names are series, which is a property
            % of the class and not of this instance.
            did_document_obj.document_properties.files.series_info = ...
                did.datastructures.emptystruct('name','count','n_present', ...
                    'source_root','ingest_locations');

        end % reset_file_info()

        function b = eq(did_document_obj1, did_document_obj2)
            % EQ - are two DID_DOCUMENT objects equal?
            %
            % B = EQ(DID_DOCUMENT_OBJ1, DID_DOCUMENT_OBJ2)
            %
            % Returns 1 if and only if the objects have identical document
            % identifiers, as returned by ID().

            b = strcmp(did_document_obj1.id(), did_document_obj2.id());
        end % eq()

    end % methods

    methods (Static)

        function props = stripSeriesIngestLocations(props)
            % STRIPSERIESINGESTLOCATIONS - clear transient member paths from properties
            %
            % PROPS = did.document.STRIPSERIESINGESTLOCATIONS(PROPS)
            %
            % Returns PROPS with every files.series_info(:).ingest_locations
            % emptied. Call this on the way to storing or shipping a
            % document's JSON.
            %
            % A series' member paths are recorded so ingestion can find the
            % bytes; they are of no use afterwards, and a level of a lightsheet
            % pyramid has tens of thousands of them. The stored JSON is
            % preserved and returned whole, so anything left in it is paid for
            % on every fetch of that document.
            %
            % The field is EMPTIED rather than removed, deliberately. rmfield
            % would leave a stored document's series_info with one fewer field
            % than a fresh one, and adding a series to such a document would
            % then fail: addFileSeries assigns a full entry into the array, and
            % MATLAB refuses assignment between dissimilar structures. Keeping
            % the field costs an "ingest_locations": [] per series -- bytes,
            % and per series rather than per member.
            %
            % A document with no series is untouched. Safe to call twice.
            %
            % See also: did.document/seriesIngestLocations

            if ~isstruct(props), return; end
            if ~isfield(props,'files'), return; end
            if ~isstruct(props.files), return; end
            if ~isfield(props.files,'series_info'), return; end

            si = props.files.series_info;
            if ~isstruct(si), return; end
            if ~isfield(si,'ingest_locations'), return; end

            emptyLocations = did.datastructures.emptystruct('index','uid', ...
                'location','location_type','ingest','delete_original','parameters');
            for i = 1:numel(si)
                si(i).ingest_locations = emptyLocations;
            end
            props.files.series_info = si;

        end % stripSeriesIngestLocations()
        function s = readblankdefinition(jsonfilelocationstring, s)
            % READBLANKDEFINITION - read a blank JSON class definitions from a file location string
            %
            % S = READBLANKDEFINITION(JSONFILELOCATIONSTRING)
            %
            % Given a JSONFILELOCATIONSTRING, this function creates a blank document using the JSON definitions.
            %
            % A JSONFILELOCATIONSTRING can be:
            %    a) a url
            %    b) a filename (full path)
            %       c) a filename referenced with respect to $NDIDOCUMENTPATH
            %
            % See also: READJSONFILELOCATION

            %{
            s_is_empty = 0;
            if nargin<2
                s_is_empty = 1;
                s = did.datastructures.emptystruct;
            end
            %}

            % Step 1): read the information we have here

            t = did.document.readjsonfilelocation(jsonfilelocationstring);
            j = jsondecode(t);
            s = j;

            % Step 2): read the information about all the superclasses

            s_super = {};
            superclasses = did.datastructures.emptystruct('definition','property_list_name','class_version');
            if isfield(j,'document_class')
                if isfield(j.document_class,'superclasses')
                    for i=1:numel(j.document_class.superclasses)
                        item = did.datastructures.celloritem(j.document_class.superclasses, i, 1);
                        s_super{end+1} = did.document.readblankdefinition(item.definition);
                        % add more fields besides 'definition' to the document_class.superclasses struct
                        item.property_list_name = s_super{end}.document_class.property_list_name;
                        item.class_version = s_super{end}.document_class.class_version;
                        superclasses(end+1) = item;
                    end
                    j.document_class.superclasses = superclasses;
                end
            end

            % Step 2): integrate the superclasses into the document we are building

            for i=1:numel(s_super)
                % merge s and s_super{i}
                % part 1: do we need to merge superclass labels?

                if isfield(s,'document_class') && isfield(s_super{i},'document_class')
                    s.document_class.superclasses = cat(1,s.document_class.superclasses(:),...
                        s_super{i}.document_class.superclasses(:));
                    [~,unique_indexes] = unique({s.document_class.superclasses.definition});
                    s.document_class.superclasses = s.document_class.superclasses(unique_indexes);
                else
                    error('Documents lack ''document_class'' fields.');
                end

                s_super{i} = rmfield(s_super{i},'document_class');

                % part 2: merge dependencies
                if isfield(s,'depends_on') && isfield(s_super{i},'depends_on') % if only s or super_s has it, merge does it right
                    s.depends_on = cat(1,s.depends_on(:),s_super{i}.depends_on(:));
                    s_super{i} = rmfield(s_super{i},'depends_on');
                    [~,unique_indexes] = unique({s.depends_on.name});
                    s.depends_on= s.depends_on(unique_indexes);
                else
                    % regular structmerge is fine, will use 'depends_on' field of whichever structure has it, or none
                end
                s = did.datastructures.structmerge(s,s_super{i});
            end
        end % readblankdefinition()

        function t = readjsonfilelocation(jsonfilelocationstring)
            % READJSONFILELOCATION - return the text from a json file location string in NDI
            %
            % T = READJSONFILELOCATION(JSONFILELOCATIONSTRING)
            %
            % A JSONFILELOCATIONSTRING can be:
            %      a) a url
            %      b) a full path filename with the .json extension
            %      c) a full path filename referenced with respect to a $PATH, where $PATH is
            %         one of the keys in did.common.PathConstants.definitions.keys()
            %      d) a filename (without the .json extension) located in any directory or subdirectory
            %         of did.common.PathConstants.definitions.values()

            % step a) do we have a URL?

            if did.file.isurl(jsonfilelocationstring)
                t = webread(jsonfilelocationstring);
                return
            end

            % step b) do we have a fullpath filename?

            if any(jsonfilelocationstring=='.') && isfile(jsonfilelocationstring)
                t = fileread_(jsonfilelocationstring);
                return
            end

            % step c) do we have a $PATH reference

            extracted_str = regexp(jsonfilelocationstring, '\$\w+', 'match');

            if ~isempty(extracted_str)
                if numel(extracted_str)>1
                    error('DID:Document:readjsonfilelocation:more than one $PATH indicated.');
                end

                locations = did.common.PathConstants.definitions(extracted_str{1});
                if ~iscell(locations)
                    locations = {locations};
                end
                for i=1:numel(locations)
                    filename = strrep(jsonfilelocationstring,extracted_str{1},locations{i});
                    if isfile(filename)
                        t = fileread_(filename);
                        return
                    end
                end
                % if we are here, we didn't find it in the locations
                error(['DID:Document:readjsonfilelocation:could not find a match for ' jsonfilelocationstring ' in ' extracted_str{1} ' directories .']);
            end

            % step d) look for 'jsonfilelocationstring.json' in our paths
            defLocs = did.common.PathConstants.definitions.values();
            for i=1:numel(defLocs)
                if ~iscell(defLocs{i})
                    mypaths = defLocs(i);
                else
                    mypaths = defLocs{i};
                end
                for j=1:numel(mypaths)
                    files = dir([char(mypaths{j}) filesep '**']);
                    %files = dir([char(mypaths{j}) filesep jsonfilelocationstring '.json']); %'**' this fails for some reason 
                    index = find( strcmp([jsonfilelocationstring '.json'], {files.name}) );
                    if numel(index)>1
                        error(['DID:Document:readjsonfilelocation:found multiple matches for ' jsonfilelocationstring '.']);
                    elseif ~isempty(index) % files
                        t = fileread_(fullfile(files(index).folder, files(index).name)); %files(index)
                        return
                    end
                end
            end

            % if we are here, we did not find any matches
            error(['DID:Document:readjsonfilelocation:found no match for ' jsonfilelocationstring '.']);

        end %  did.document.readjsonfilelocation()
    end % methods Static
end % classdef

% Faster alternative than the built-in fileread()
function text = fileread_(filename)
    fid = fopen(filename,'r');
    text = fread(fid,'*char')';
    fclose(fid);
end

function index = localSeriesInfoIndex(did_document_obj, name)
    % Index of NAME's entry in files.series_info, or [] if absent.
    % Case-insensitive, matching is_in_file_list.
    index = [];
    if ~isfield(did_document_obj.document_properties,'files'), return; end
    files = did_document_obj.document_properties.files;
    if ~isfield(files,'series_info') || isempty(files.series_info), return; end
    index = find(strcmpi(name,{files.series_info.name}));
    if ~isempty(index), index = index(1); end
end

function stem = localSeriesMemberStem(did_document_obj, name)
    % If NAME parses as STEM_<number> and STEM is a declared series, return
    % STEM; otherwise ''. This is the second resolution rule a series adds:
    % is_in_file_list already maps NAME_12 to NAME_#, and this maps it to the
    % series NAME when that lookup misses.
    stem = '';
    underscores = find(name=='_');
    if isempty(underscores), return; end
    n = str2num(name(underscores(end)+1:end)); %#ok<ST2NM>
    if isempty(n), return; end
    candidate = name(1:underscores(end)-1);
    if did_document_obj.isFileSeries(candidate)
        stem = candidate;
    end
end

function entries = localIngestLocations(locations, indices, uids, deleteOriginal)
    % Build the transient uid -> source-path record for a series' members.
    %
    % Shaped like a file_info location so the ingestion loop can treat the two
    % the same way, plus 'index' so the member's files-table filename
    % (NAME_<index>) is known without consulting the manifest.
    %
    % Defaults follow add_file: a URL is not ingested and its original is not
    % deleted; a local file is ingested and, unless the caller says otherwise,
    % its original is deleted. DELETEORIGINAL of NaN means "use that default".

    entries = did.datastructures.emptystruct('index','uid','location', ...
        'location_type','ingest','delete_original','parameters');

    for i = 1:numel(locations)
        L = locations{i};
        if isstring(L) && isscalar(L), L = char(L); end
        L = strip(L);

        if startsWith(L,'https://','IgnoreCase',true) || ...
                startsWith(L,'http://','IgnoreCase',true)
            locationType = 'url';
            ingest = 0;
            defaultDelete = 0;
        else
            locationType = 'file';
            ingest = 1;
            defaultDelete = 1;
        end

        if isnan(deleteOriginal)
            thisDelete = defaultDelete;
        else
            thisDelete = deleteOriginal;
        end

        entries(end+1) = struct('index', indices(i), ...
            'uid', uids{indices(i)}, ...
            'location', L, ...
            'location_type', locationType, ...
            'ingest', ingest, ...
            'delete_original', thisDelete, ...
            'parameters', ''); %#ok<AGROW>
    end
end

function root = localCommonRoot(locations)
    % The longest common DIRECTORY prefix of LOCATIONS, or '' when there is
    % none worth recording.
    %
    % '' is returned for a trivial result -- the filesystem root, or paths
    % with nothing in common -- because the alternative is recording absolute
    % paths, which discloses a directory layout and is the bloat the manifest
    % exists to avoid. A URL is likewise given no root: it carries no home
    % directory to leak, and is stored whole.
    root = '';
    if isempty(locations), return; end
    parents = cell(1,numel(locations));
    for i = 1:numel(locations)
        L = locations{i};
        if isstring(L) && isscalar(L), L = char(L); end
        if ~ischar(L) || isempty(L), return; end
        if contains(L,'://'), return; end
        parents{i} = fileparts(L);
    end
    common = parents{1};
    for i = 2:numel(parents)
        common = localCommonPrefixDir(common, parents{i});
        if isempty(common), return; end
    end
    if isempty(common) || strcmp(common, filesep) || strcmp(common,'.')
        return;
    end
    root = common;
end

function c = localCommonPrefixDir(a, b)
    % Common leading path components of A and B, joined. Splits on either
    % separator so a path written on one platform is handled on the other.
    pa = regexp(a,'[\\/]','split');
    pb = regexp(b,'[\\/]','split');
    n = min(numel(pa),numel(pb));
    k = 0;
    for i = 1:n
        if strcmp(pa{i},pb{i}), k = i; else, break; end
    end
    if k == 0, c = ''; return; end
    c = strjoin(pa(1:k), filesep);
end

function rel = localRelativeNames(locations, root)
    % Each location's path RELATIVE to ROOT, using '/' as the separator so a
    % manifest written on one platform reads the same on another.
    rootParts = regexp(root,'[\\/]','split');
    rel = cell(1,numel(locations));
    for i = 1:numel(locations)
        L = locations{i};
        if isstring(L) && isscalar(L), L = char(L); end
        parts = regexp(L,'[\\/]','split');
        if numel(parts) <= numel(rootParts) || ...
                ~isequal(parts(1:numel(rootParts)), rootParts)
            error('DID:Document:addFileSeries:notUnderRoot', ...
                ['Location "%s" is not under the series source root "%s". ' ...
                 'Recording it would store an absolute path, which is the ' ...
                 'disclosure relative names exist to prevent.'], L, root);
        end
        rel{i} = strjoin(parts(numel(rootParts)+1:end), '/');
    end
end

function localValidateFileDeclarations(did_document_obj)
    % Enforce that a file name is served by ONE mechanism, not two.
    %
    % If a name were reachable through both the file-entry path (file_list
    % plus file_info, with NAME_# members found by probing) and the series
    % path (a manifest that states membership), the two would give different
    % answers for it -- and the file-entry path's answer stops at the first
    % gap, which is exactly the case series exist to serve. So this is not
    % hygiene; it is what makes the two mechanisms safe to coexist.
    %
    % Comparisons are case-insensitive, because is_in_file_list matches with
    % strcmpi and a difference it cannot see is not a difference.

    if ~isfield(did_document_obj.document_properties,'files'), return; end
    files = did_document_obj.document_properties.files;
    if ~isfield(files,'file_series') || isempty(files.file_series), return; end

    seriesNames = files.file_series;
    if ~iscell(seriesNames), seriesNames = {seriesNames}; end

    fileList = {};
    if isfield(files,'file_list') && ~isempty(files.file_list)
        fileList = files.file_list;
        if ~iscell(fileList), fileList = {fileList}; end
    end

    for i = 1:numel(seriesNames)
        thisSeries = seriesNames{i};

        % Duplicated series name (possibly differing only in case).
        if sum(strcmpi(thisSeries, seriesNames)) > 1
            error('DID:Document:fileDeclarations:duplicateSeries', ...
                ['The file series "%s" is declared more than once (matching ' ...
                 'is case-insensitive).'], thisSeries);
        end

        % The series name IS its manifest, so it must be an ordinary file.
        if ~any(strcmpi(thisSeries, fileList))
            error('DID:Document:fileDeclarations:seriesNotInFileList', ...
                ['The file series "%s" is not in file_list. A series name is ' ...
                 'its manifest, which is an ordinary file, so it must be ' ...
                 'declared there too.'], thisSeries);
        end

        % Collision 1: the same family declared both ways.
        if any(strcmpi([thisSeries '_#'], fileList))
            error('DID:Document:fileDeclarations:seriesAndNumberedEntry', ...
                ['"%s" is declared as a file series and "%s_#" is also in ' ...
                 'file_list. "%s_12" would match both, and the two mechanisms ' ...
                 'would disagree about membership.'], ...
                thisSeries, thisSeries, thisSeries);
        end
    end

    % Collision 2 (and 4): a literal entry that a series would shadow.
    % is_in_file_list resolves the trailing integer first, so such an entry is
    % unreachable. Note str2num EVALUATES, so a name ending _pi or _i parses
    % as a number too and is caught here as well.
    for i = 1:numel(fileList)
        thisName = fileList{i};
        if isempty(thisName) || thisName(end) == '#', continue; end
        underscores = find(thisName == '_');
        if isempty(underscores), continue; end
        if isempty(str2num(thisName(underscores(end)+1:end))) %#ok<ST2NM>
            continue;
        end
        stem = thisName(1:underscores(end)-1);
        if any(strcmpi(stem, seriesNames))
            error('DID:Document:fileDeclarations:shadowedBySeries', ...
                ['file_list entry "%s" is unreachable: it parses as member ' ...
                 '%s of the file series "%s", so the series answers for it.'], ...
                thisName, thisName(underscores(end)+1:end), stem);
        end
    end
end
