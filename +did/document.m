classdef document
	%DOCUMENT - DID_database storage item, general purpose data and parameter storage
	% The DID_DOCUMENT datatype for storing results in the DID_DATABASE
	%

	properties (SetAccess=protected,GetAccess=public)
		document_properties % a struct with the fields for the document
	end

	methods
		function did_document_obj = document(document_type, varargin)
			% DID_DOCUMENT - create a new DID_DATABASE object
			%
			% DID_DOCUMENT_OBJ = DID_DOCUMENT(DOCUMENT_TYPE, 'PARAM1', VALUE1, ...)
			%   or
			% DID_DOCUMENT_OBJ = DID_DOCUMENT(MATLAB_STRUCT)
			%
			%

				if nargin<1,
					document_type = 'base';
				end

				if isstruct(document_type),
					document_properties = document_type;
				else,  % create blank from definitions
					document_properties = did.document.readblankdefinition(document_type);
					document_properties.base.id = did.ido.unique_id();
					document_properties.base.datestamp = char(datetime('now','TimeZone','UTCLeapSeconds'));

					if numel(varargin)==1, % see if user put it all as one cell array
						if iscell(varargin{1}),
							varargin = varargin{1};
						end
					end
					if mod(numel(varargin),2)~=0,
						error(['Variable inputs must be name/value pairs'.']);
					end;

					for i=1:2:numel(varargin), % assign variable arguments
						try,
							eval(['document_properties.' varargin{i} '= varargin{i+1};']);
						catch,
							error(['Could not assign document_properties.' varargin{i} '.']);
						end
					end
				end

				did_document_obj.document_properties = document_properties;

		end % document() creator

		function [b, e] = validate(did_document_obj, did_database)
			% VALIDATE - 0/1 evaluate whether DID_DOCUMENT object is valid by its schema
			% 
			% B = VALIDATE(DID_DOCUMENT_OBJ)
			%
			% Checks the fields of the DID_DOCUMENT object against the schema in 
			% DID_DOCUMENT_OBJ.did_core_properties.validation_schema and returns 1
			% if the object is valid and 0 otherwise.
				try
				    validator = did.validate(did_document_obj);
				catch
				    if nargin == 1
					error('You must pass in an instance of did.database')
				    end
				    validator = did.validate(did_document_obj, did_database);
				end
				b = validator.is_valid;
				e = validator.errormsg;
		end % validate()

		function uid = id(did_document_obj)
			% ID - return the document unique identifier for an DID_DOCUMENT
			%
			% UID = ID (DID_DOCUMENT_OBJ)
			%
			% Returns the unique id of an DID_DOCUMENT
			% (Found at DID_DOCUMENT_OBJ.documentproperties.base.id)
			%
				uid = did_document_obj.document_properties.base.id;
		end; % id()

		function did_document_obj = setproperties(did_document_obj, varargin)
			% SETPROPERTIES - Set property values of an DID_DOCUMENT object
			%
			% DID_DOCUMENT_OBJ = SETPROPERTIES(DID_DOCUMENT_OBJ, 'PROPERTY1', VALUE1, ...)
			%
			% Sets the property values of DID_DOCUMENT_OBJ.	PROPERTY values should be expressed
			% relative to DID_DOCUMENT_OBJ.document_properties (see example).
			%
			% See also: DID_DOCUMENT, DID_DOCUMENT/DID_DOCUMENT		
			%
			% Example:
			%   mydoc = mydoc.setproperties('base.name','mydoc name');

				newproperties = did_document_obj.document_properties;
				for i=1:2:numel(varargin),
					try,
						eval(['newproperties.' varargin{i} '=varargin{i+1};']);
					catch,
						error(['Error in assigning ' varargin{i} '.']);
					end
				end
				
				did_document_obj.document_properties = newproperties;
		end; % setproperties

		function did_document_obj_out = plus(did_document_obj_a, did_document_obj_b)
			% PLUS - merge two DID_DOCUMENT objects
			%
			% DID_DOCUMENT_OBJ_OUT = PLUS(DID_DOCUMENT_OBJ_A, DID_DOCUMENT_OBJ_B)
			%
			% Merges the DID_DOCUMENT objects A and B. First, the 'document_class'
			% superclasses are merged. Then, the fields that are in B but are not in A
			% are added to A. The result is returned in DID_DOCUMENT_OBJ_OUT.
			% Note that any fields that A has that are also in B will be preserved; no elements of
			% those fields of B will be combined with A.
			%
				did_document_obj_out = did_document_obj_a;
				% Step 1): Merge superclasses
				did_document_obj_out.document_properties.document_class.superclasses = ...
					(cat(1,did_document_obj_out.document_properties.document_class.superclasses,...
						did_document_obj_b.document_properties.document_class.superclasses));
				otherproperties = rmfield(did_document_obj_b.document_properties, 'document_class');

				% Step 2): Merge dependencies if we have to
				if isfield(did_document_obj_out.document_properties,'depends_on') & ...
					isfield(did_document_obj_b.document_properties,'depends_on'), 
					% we need to merge dependencies
					did_document_obj_out.document_properties.depends_on = cat(1,...
						did_document_obj_out.document_properties.depends_on(:),...
						did_document_obj_b.document_properties.depends_on(:));
						otherproperties = rmfield(otherproperties,'depends_on');
				end;

				% Step 3): Merge the other fields
				did_document_obj_out.document_properties = did.datastructures.structmerge(did_document_obj_out.document_properties,...
					otherproperties);
		end; % plus() 

		function d = dependency_value(did_document_obj, dependency_name, varargin)
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
			%
			%
				ErrorIfNotFound = 1;
				did.datastructures.assign(varargin{:});

				d = [];
				notfound = 1;

				hasdependencies = isfield(did_document_obj.document_properties,'depends_on');

				if hasdependencies,
					matches = find(strcmpi(dependency_name,{did_document_obj.document_properties.depends_on.name}));
					if numel(matches)>0,
						notfound = 0;
						d = getfield(did_document_obj.document_properties.depends_on(matches(1)),'value');
					end;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function did_document_obj = set_dependency_value(did_document_obj, dependency_name, value, varargin)
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
			%
			%
				ErrorIfNotFound = 1;
				did.datastructures.assign(varargin{:});

				notfound = 1;

				hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
				d_struct = struct('name',dependency_name,'value',value);

				if hasdependencies,
					matches = find(strcmpi(dependency_name,{did_document_obj.document_properties.depends_on.name}));
					if numel(matches)>0,
						notfound = 0;
						did_document_obj.document_properties.depends_on(matches(1)).value = value;
					elseif ~ErrorIfNotFound, % add it
						did_document_obj.document_properties.depends_on(end+1) = d_struct;
					end;
				elseif ~ErrorIfNotFound,
					did_document_obj.document_properties.depends_on = d_struct;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function d = dependency_value_n(did_document_obj, dependency_name, varargin)
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
			%
			%
				ErrorIfNotFound = 1;
				did.datastructures.assign(varargin{:});

				d = {};
				notfound = 1;

				hasdependencies = isfield(did_document_obj.document_properties,'depends_on');

				if hasdependencies,
					finished = 0;
					i = 1;
					while ~finished,
						matches = find(strcmpi([dependency_name '_' int2str(i)],{did_document_obj.document_properties.depends_on.name}));
						if numel(matches)>0,
							notfound = 0;
							d{i} = getfield(did_document_obj.document_properties.depends_on(matches(1)),'value');
						end;
						finished = numel(matches)==0;
						i = i + 1;
					end;
				end;

				if notfound & ErrorIfNotFound,
					error(['Dependency name ' dependency_name ' not found.']);
				end;
		end; % 

		function did_document_obj = add_dependency_value_n(did_document_obj, dependency_name, value, varargin)
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
			%
			%
				ErrorIfNotFound = 1;
				did.datastructures.assign(varargin{:});


				d = dependency_value_n(did_document_obj, dependency_name, 'ErrorIfNotFound', 0);
				hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
				if ~hasdependencies & ErrorIfNotFound,
					error(['This document does not have any dependencies.']);
				else,
					d_struct = struct('name',[dependency_name '_' int2str(numel(d)+1)],'value',value);
					did_document_obj = set_dependency_value(did_document_obj, d_struct.name, d_struct.value, 'ErrorIfNotFound', 0);
				end;
		end; % 

		function did_document_obj = remove_dependency_value_n(did_document_obj, dependency_name, value, n, varargin)
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
			%
			%
				ErrorIfNotFound = 1;
				did.datastructures.assign(varargin{:});

				d = dependency_value_n(did_document_obj, dependency_name, 'ErrorIfNotFound', 0);
				hasdependencies = isfield(did_document_obj.document_properties,'depends_on');
				if ~hasdependencies & ErrorIfNotFound,
					error(['This document does not have any dependencies.']);
				end;

				if n>numel(d) & ErrorIfNotFound,
					error(['Number to be removed ' int2str(n) ' is greater than total number of entries ' int2str(numel(d)) '.']);
				end;

				match = find(strcmpi([dependency_name '_' int2str(n)],{did_document_obj.document_properties.depends_on.name}));
				if numel(match)~=1,
					error(['Could not locate entry ' dependency_name '_' int2str(n)]);
				end;

				did_document_obj.document_properties.depends_on = did_document_obj.document_properties.depends_on([1:match-1 match+1:end]);

				for i=n+1:numel(d),
					match = find(strcmpi([dependency_name '_' int2str(i)],{did_document_obj.document_properties.depends_on.name}));
					if numel(match)~=1,
						error(['Could not locate entry ' dependency_name '_' int2str(i)]);
					end;
					did_document_obj.document_properties.depends_on(match).name = [dependency_name '_' int2str(i-1)];
				end;
		end; % 

		function b = eq(did_document_obj1, did_document_obj2)
			% EQ - are two DID_DOCUMENT objects equal?
			%
			% B = EQ(DID_DOCUMENT_OBJ1, DID_DOCUMENT_OBJ2)
			%
			% Returns 1 if and only if the objects have identical document_properties.did_document.id
			% fields.
			%
				b = strcmp(did_document_obj1.document_properties.did_document.id,...
					did_document_obj2.document_properties.did_document.id);
		end; % eq()

	end % methods

	methods (Static)
		function s = readblankdefinition(jsonfilelocationstring, s)
			% READBLANKDEFINITION - read a blank JSON class definitions from a file location string
			%
			% S = READBLANKDEFINITION(JSONFILELOCATIONSTRING)
			%
			% Given a JSONFILELOCATIONSTRING, this function creates a blank document using the JSON definitions.
			%
			% A JSONFILELOCATIONSTRING can be:
			%	a) a url
			%	b) a filename (full path)
			%       c) a filename referenced with respect to $NDIDOCUMENTPATH
			%
			% See also: READJSONFILELOCATION
			%
				s_is_empty = 0;
				if nargin<2,
					s_is_empty = 1;
					s = did.datastructures.emptystruct;
				end

				% Step 1): read the information we have here

				t = did.document.readjsonfilelocation(jsonfilelocationstring);
				j = jsondecode(t);
				s = j; 

				% Step 2): read the information about all the superclasses

				s_super = {};
                superclasses = did.datastructures.emptystruct('definition','property_list_name','class_version');
%                 superclasses = {}
				if isfield(j,'document_class'),
					if isfield(j.document_class,'superclasses'),
						for i=1:numel(j.document_class.superclasses),
							item = did.datastructures.celloritem(j.document_class.superclasses, i, 1);
							s_super{end+1} = did.document.readblankdefinition(item.definition);
                            %% add more fields besides 'definition' to the document_class.superclasses struct
                            item.property_list_name = s_super{end}.document_class.property_list_name
                            item.class_version = s_super{end}.document_class.class_version
%                             superclasses{end+1} = item 
                            superclasses(end+1) = item 
                        end
                        j.document_class.superclasses = superclasses
					end
				end

				% Step 2): integrate the superclasses into the document we are building

				for i=1:numel(s_super),
					% merge s and s_super{i}
					% part 1: do we need to merge superclass labels?
              
					if isfield(s,'document_class')&isfield(s_super{i},'document_class'),
                    
                        
						s.document_class.superclasses = cat(1,s.document_class.superclasses(:),...
							s_super{i}.document_class.superclasses(:));
						[dummy,unique_indexes] = unique({s.document_class.superclasses.definition});
						s.document_class.superclasses = s.document_class.superclasses(unique_indexes);
                        
					else,
						error(['Documents lack ''document_class'' fields.']);
					end;

					s_super{i} = rmfield(s_super{i},'document_class');

					% part 2: merge dependencies
					if isfield(s,'depends_on') & isfield(s_super{i},'depends_on'), % if only s or super_s has it, merge does it right
						s.depends_on = cat(1,s.depends_on(:),s_super{i}.depends_on(:));
						s_super{i} = rmfield(s_super{i},'depends_on');
						[dummy,unique_indexes] = unique({s.depends_on.name});
						s.depends_on= s.depends_on(unique_indexes);
					else,
						% regular structmerge is fine, will use 'depends_on' field of whichever structure has it, or none
					end;
					s = did.datastructures.structmerge(s,s_super{i});
				end;
		end % readblankdefinition() 

		function t = readjsonfilelocation(jsonfilelocationstring)
			% READJSONFILELOCATION - return the text from a json file location string in NDI
			%
			% T = READJSONFILELOCATION(JSONFILELOCATIONSTRING)
			%
			% A JSONFILELOCATIONSTRING can be:
			%      a) a url
			%      b) a filename (full path)
			%      c) a relative filename with respect to $NDIDOCUMENTPATH
			%      d) a filename referenced with respect to $NDIDOCUMENTPATH
			%
				did.globals;

					% temporary : I've fixed the search string so it can only be DIDDOCUMENT_EX1 and gets replaced with the first
					%           : did.path.documentpath{1} entry
					%           : Should search through all the names


                match_index = 0
                search_str_location = []
                for i = 1:numel(did_globals.path.definition_names)
                    did_globals.path.definition_names{i}
                    loc = strfind(jsonfilelocationstring, did_globals.path.definition_names{i});
                    if ~isempty(loc)
                        match_index = i
                        search_str_location = loc
                        break
                    end
                end
                
                
				
				if ~isempty(search_str_location), % insert the location
					filename = [...
                        did_globals.path.definition_locations{match_index} filesep ...
						did.file.filesepconversion(...
                        jsonfilelocationstring(search_str_location+numel(did_globals.path.definition_names{match_index}):end), ...
                        did.filesep, filesep)...
                        ];
				else,
					% first, guess that it is a complete path from the first search path
                    for i = 1:numel(did_globals.path.definition_locations)
                        filename = [did_globals.path.definition_locations{i} filesep did.file.filesepconversion(jsonfilelocationstring,did.filesep,filesep)];
                        if ~exist(filename,'file'),
                            % try adding extension
                            filename = [filename '.json'];
                        end;
                        if ~exist(filename,'file'), 
                            filename = jsonfilelocationstring;
                            [p,n,e] = fileparts(filename);
                            if isempty(e),
                                filename = [filename '.json'];
                            end;
                            if ~exist(filename,'file'),
                                filename2 = [did_globals.path.definition_locations{i} filesep filename];
                                if ~exist(filename2,'file'),
                                    error(['Cannot find file ' filename '.']);
                                else,
                                    filename = filename2;
                                end;
                            end;
                        end;
                    end
                end

            % filename could be url or filename

                if did.file.isurl(filename),
                    t = urlread(filename);
                else,
                    t = did.file.textfile2char(filename);
                end
        end

    end % methods Static
end % classdef

