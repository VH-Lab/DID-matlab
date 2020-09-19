 / crystallclassdef quer2

	properties (SetAccess=protected,GetAccess=public)
		searchstructure % search structure
	end

	methods

		function did_query_obj = query(varargin)
			% QUERY - create a DID query object for searching a DID database
			%
			% Creates an DID.QUERY object, which has a single property
			% SEARCH that is a structure array of search structures
			% appropriate for use with FIELDSEARCH.
			%
			% Tha is, SEARCH has the fields:
			% Field:                   | Description
			% ---------------------------------------------------------------------------
			% field                      | A character string of the field of A to examine
			% operation                  | The operation to perform. This operation determines 
			%                            |   values of fields 'param1' and 'param2'.
			%     |----------------------|
			%     |   'regexp'             - are there any regular expression matches between 
			%     |                          the field value and 'param1'?
			%     |   'exact_string'       - is the field value an exact string match for 'param1'?
			%     |   'contains_string'    - is the field value a char array that contains 'param1'?
			%     |   'exact_number'       - is the field value exactly 'param1' (same size and values)?
			%     |   'lessthan'           - is the field value less than 'param1' (and comparable size)
			%     |   'lessthaneq'         - is the field value less than or equal to 'param1' (and comparable size)
			%     |   'greaterthan'        - is the field value greater than 'param1' (and comparable size)
			%     |   'greaterthaneq'      - is the field value greater than or equal to 'param1' (and comparable size)
			%     |   'hasfield'           - is the field present? (no role for 'param1' or 'param2')
			%     |   'hasanysubfield_contains_string' - Is the field value an array of structs or cell array of structs
			%     |                        such that any has a field named 'param1' with a string that contains the string
			%     |                        in 'param2'?
			%     |   'or'                 - are any of the searchstruct elements specified in 'param1' true?
			%     |   'isa'                - is 'param1' either a superclass or the document class itself of the DID_DOCUMENT?
			%     |   'depends_on'         - does the document depend on an item with name 'param1' and value 'param2'?
			%     |----------------------|
			% param1                     | Search parameter 1. Meaning depends on 'operation' (see above).
			% param2                     | Search parameter 2. Meaning depends on 'operation' (see above).
			% ---------------------------------------------------------------------------
			% See FIELDSEARCH for full documentation of the search structure.
			%  
			% There are a few creator options:
			%
			% DID_QUERY_OBJ = QUERY(SEARCHSTRUCT)
			%
			% Accepts a SEARCHSTRUCT with the fields above
			%
			% DID_QUERY_OBJ = QUERY(SEARCHCELLARRAY)
			%
			% Accepts a cell array with SEARCHCELLARRAY = {'property1',value1,'property2',value2, ...}
			% This query is converted into a SEARCHSTRUCT with the 'regexp' operator.
			%
			% DID_QUERY_OBJ = QUERY(FIELD, OPERATION, PARAM1, PARAM2)
			%
			%  creates a SEARCHSTRUCT with the fields of the appropriate names.
			% 
				did_query_obj.searchstructure = did.datastructures.emptystruct('field','operation','param1','param2');
				if nargin==1,
					if isstruct(varargin{1}),
						% check arguments
						if ~eqlen(sort(fieldnames(varargin{1})),sort({'field','operation','param1','param2'})),
							error(['Field names of search structure do not match expected fields.']);
						end;
						did_query_obj.searchstructure = varargin{1};
					elseif iscell(varargin{1}),
						did_query_obj.searchstructure = did.query.searchcellarray2searchstructure(varargin{1});
					elseif isa(varargin{1},'did_query'), % just copy search structure
						did_query_obj.searchstructure = varargin{1}.searchstructure;
					end;
				elseif nargin==4,
					did_query_obj.searchstructure = struct('field',varargin{1},'operation',varargin{2},...
						'param1',varargin{3},'param2',varargin{4});
				elseif nargin==0, % not an error
				else,
					error(['Unknown inputs to DID_QUERY; number of inputs was ' int2str(nargin) ' but expected 0, 1, or 4.']);
				end;
		end;  %query() % 

		function C = and(A,B)
			% AND - add DID.QUERY objects
			%
			% C = AND(A,B) or C = A & B
			%
			% Combines the searches from A and B into a search C. The searchstructure field of
			% C will be a concatenated version of those from A and B. The query C will only pass if
			% all of the characteristics of A and B are satisfied.
				C = A;
				C.searchstructure = [C.searchstructure(:); B.searchstructure(:)];
		end; % and()

		function C = or(A,B)
			% OR - search for _this_ DID.QUERY object or _that_ DID.QUERY object
			%
			% C = OR(A,B)
			%
			% Produces a new DID.QUERY object C that is true if either DID.QUERY A or DID.QUERY B is true.
			%
				C = did.query();
				C.searchstructure = did.query.searchstruct('','or',A.searchstructure(:),B.searchstructure(:));
		end; % or()

		function searchstructure = to_searchstructure(did_query_obj)
			% TO_SEARCHSTRUCTURE - convert an DID.QUERY object to a set of search structures
			%
			% SEARCHSTRUCTURE = TO_SEARCHSTRUCTURE(DID.QUERY_OBJ)
			%
			% Converts an DID.QUERY object to a set of search structures without any
			% DID.QUERY dependencies (see FIELDSEARCH).
			%
			% See also: FIELDSEARCH
			%
				searchstructure = did.datastructures.emptystruct('field','operation','param1','param2');
				for i=1:numel(did_query_obj)
					for j=1:numel(did_query_obj(i).searchstructure),
						ss_here = did.datastructures.emptystruct('field','operation','param1','param2');
						ss_here(1).field = did_query_obj(i).searchstructure(j).field;
						% check to see if we have a special case that needs to be reduced
						if strcmpi('isa',did_query_obj(i).searchstructure(j).operation), % replace with search structures
							findinsubfield = struct('field','document_class.superclasses',...
									'operation','hasanysubfield_contains_string',...
									'param1','definition');
							findinsubfield.param2 = did_query_obj(i).searchstructure(j).param1;
							findinmainfield = struct('field','document_class.definition', ...
									'operation','contains_string');
							findinmainfield.param1 = did_query_obj(i).searchstructure(j).param1;
							findinmainfield.param2 = '';
							ss_here(1).field = '';
							ss_here(1).operation = 'or';
							ss_here(1).param1 = findinsubfield;
							ss_here(1).param2 = findinmainfield;
						elseif strcmpi('depends_on',did_query_obj(i).searchstructure(j).operation),
							param1 = {'name','value'};
							param2 = { did_query_obj(i).searchstructure(j).param1 did_query_obj(i).searchstructure(j).param2 };
							if strcmp(param2{1},'*'), % ignore the name
								param1 = param1(2);
								param2 = param2(2);
							end;
							ss_here = struct('field','depends_on','operation','hasanysubfield_exact_string');
							ss_here(1).param1 = param1;
							ss_here(1).param2 = param2;
						else, % regular case
							ss_here(1).operation = did_query_obj(i).searchstructure(j).operation;
							if isa(did_query_obj(i).searchstructure(j).param1,'did_query'),
								ss_here(1).param1 = did_query_obj(i).searchstructure(j).param1.to_searchstructure();
							else,
								ss_here(1).param1 = did_query_obj(i).searchstructure(j).param1;
							end;
							if isa(did_query_obj(i).searchstructure(j).param2,'did_query'),
								ss_here(1).param2 = did_query_obj(i).searchstructure(j).param2.to_searchstructure();
							else,
								ss_here(1).param2 = did_query_obj(i).searchstructure(j).param2;
							end;
						end;
						searchstructure(end+1) = ss_here;
					end;
				end;
		end; % to_searchstructure();

	end; % methods

	methods (Static)
		function searchstruct = searchcellarray2searchstructure(searchcellarray)
			%SEARCHCELLARRAY2SEARCHSTRUCTURE - convert a search cell array to a search structure
			%
			% SEARCHSTRUCT = SEARCHCELLARRAY2SEARCHSTRUCTURE(SEACHCELLARRAY)
			%
			% Converts a cell array with SEARCHCELLARRAY = {'property1',value1,'property2',value2, ...}
			% into a SEARCHSTRUCT with the 'regexp' operator in the case of a character 'value' or the 'exact_number'
			% operator in the case of a non-character value.
			% 
			% See also: FIELDSEARCH, DID.QUERY/DID.QUERY
			%
				if ~iscell(searchcellarray) | mod(numel(searchcellarray),2)~=0,
					error(['Input must be a cell array in the form {''property1'',value1,...}']);
				end;

				searchstruct = did.datastructures.emptystruct('field','operation','param1','param2');

				for i=1:2:numel(searchcellarray),
					if ischar(searchcellarray{i+1}),
						newstructure = struct('field',searchcellarray{i}, 'operation','regexp',...
							'param1',searchcellarray{i+1},'param2',[]);
					else,
						newstructure = struct('field',searchcellarray{i}, 'operation','exact_number',...
							'param1',searchcellarray{i+1},'param2',[]);
					end;
					searchstruct(end+1) = newstructure;
				end;
		end;

		function searchstruct_out = searchstruct(field, operation, param1, param2)
			% SEARCHSTRUCT - make a search structure from field, operation, param1, param2 inputs
			%
			% SEARCHSTRUCT_OUT = SEARCHSTRUCT(FIELD, OPERATION, PARAM1, PARAM2)
			%
			% Creates search structure with the given fields FIELD, OPERATION, PARAM1, PARAM2.
			% 
			% See also: FIELDSEARCH, DID.QUERY/DID.QUERY
				searchstruct_out = struct('field',field,'operation',operation,'param1',param1,'param2',param2);	 
		end; 
	end; % methods (Static)
end 

