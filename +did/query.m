classdef query
	% did.query: search a did.database for did.documents
	%
	% did.query objects define searches for did.documents; they are passed to the did.database/search function
	%
	% did.query Properties:
	%   searchstructure - a structure with fields 'field','operation','param1','param2' that describe the search
	% 
	% did.query Methods:
	%   query - The creator, and includes documentation for specifying the search
	%   and - Combine two queries into a single query; search for A AND B
	%   or - Create a query that searches for A OR B
	%   to_searchstructure - Convert a did.query into a structure that can be passed to did.datastructures.fieldsearch
	%   searchstruct - make a search structure from field, operation, param1, param2 inputs
	%   searchcellarray2searchstructure - convert a search cell array to a search structure
	%   
	% Examples:
	%   q = did.query('base.id','exact_string','12345678','') %last '' is optional
	%   q = did.query('base.name','exact_string','myname','') %last '' is optional
	%   q = did.query('base.name','regexp','(.*)') % match any base.name
	%   q = did.query('base.id','regexp','(.*)') % match any base.id
	%   q = did.query('','isa','base') % match any document that is member of class 'base'
	%   
	% See also: did.query/query, did.datastructures.fieldsearch

	properties (SetAccess=protected,GetAccess=public)
		searchstructure % search structure
	end

	methods
		function did_query_obj = query(field,op,param1,param2)
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
            %  FIELD, OPERATION are mandatory.
            %  PARAM1, PARAM2 are optional; default value = ''
			%   
			% Examples:
			%   q = did.query('base.id','exact_string','12345678','')
			%   q = did.query('base.name','exact_string','myname')
			%   q = did.query('base.name','regexp','(.*)') % match any base.name
			%   q = did.query('base.id','regexp','(.*)') % match any base.id
			%   q = did.query('','isa','base') % match any document that is member of class 'base'

            if nargin == 0 % not an error => empty query
                query_struct = did.datastructures.emptystruct('field','operation','param1','param2');
            elseif nargin == 1
                if isstruct(field)
                    % check arguments
                    if ~did.datastructures.eqlen(sort(fieldnames(field)),sort({'field','operation','param1','param2'}))
                        error('Field names of search structure do not match expected fields.');
                    end
                    query_struct = field;
                elseif iscell(field)
                    query_struct = did.query.searchcellarray2searchstructure(field);
                elseif isa(field,'did_query') % just copy search structure
                    query_struct = field.searchstructure;
                else
                    error('No operation specified for did.query.');
                end
            else
                if nargin < 3, param1 = ''; end
                if nargin < 4, param2 = ''; end
                query_struct = struct('field',field,'operation',op,'param1',param1,'param2',param2);
            end
            did_query_obj.searchstructure = query_struct;
		end  %query()

		function C = and(A,B)
			% AND - add DID.QUERY objects
			%
			% C = AND(A,B) or C = A & B
			%
			% Produces a new DID.QUERY object C that is true if both DID.QUERY A and DID.QUERY B are true.
			%
			% Combines the searches from A and B into a search C. The searchstructure field of
			% C will be a concatenated version of those from A and B. The query C will only pass if
			% all of the characteristics of A and B are satisfied.

				C = A;
				C.searchstructure = [C.searchstructure(:); B.searchstructure(:)];
		end % and()

		function C = or(A,B)
			% OR - search for _this_ DID.QUERY object or _that_ DID.QUERY object
			%
			% C = OR(A,B) or C = A | B
			%
			% Produces a new DID.QUERY object C that is true if either DID.QUERY A or DID.QUERY B is true.

				C = did.query();
				C.searchstructure = did.query.searchstruct('','or',A.searchstructure(:),B.searchstructure(:));
		end % or()

		function searchstructure = to_searchstructure(did_query_obj)
			% TO_SEARCHSTRUCTURE - convert an DID.QUERY object to a set of search structures
			%
			% SEARCHSTRUCTURE = TO_SEARCHSTRUCTURE(DID.QUERY_OBJ)
			%
			% Converts an DID.QUERY object to a set of search structures without any
			% DID.QUERY dependencies (see FIELDSEARCH).
			%
			% See also: FIELDSEARCH

				searchstructure = did.datastructures.emptystruct('field','operation','param1','param2');
				for i=1:numel(did_query_obj)
					for j=1:numel(did_query_obj(i).searchstructure)
						ss_here = did.datastructures.emptystruct('field','operation','param1','param2');
						ss_here(1).field = did_query_obj(i).searchstructure(j).field;
						% check to see if we have a special case that needs to be reduced
						if strcmpi('isa',did_query_obj(i).searchstructure(j).operation) % replace with search structures
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
                                                elseif strcmpi('~isa',ndi_query_obj(i).searchstructure(j).operation), % replace with search structures
							% use one of DeMorgan's law: not(A or B) = not(A) AND not(B)
							findinsubfield = struct('field','document_class.superclasses',...
								'operation','~hasanysubfield_contains_string',...
								'param1','definition');
							findinsubfield.param2 = ndi_query_obj(i).searchstructure(j).param1;
                                                        findinmainfield = struct('field','document_class.definition', ...
								'operation','~contains_string');
							findinmainfield.param1 = ndi_query_obj(i).searchstructure(j).param1;
							findinmainfield.param2 = '';
							ss_here = cat(1, findinsubfield, findinmainfield);
						elseif strcmpi('depends_on',did_query_obj(i).searchstructure(j).operation)
							param1 = {'name','value'};
							param2 = { did_query_obj(i).searchstructure(j).param1 did_query_obj(i).searchstructure(j).param2 };
							if strcmp(param2{1},'*') % ignore the name
								param1 = param1(2);
								param2 = param2(2);
							end
							ss_here = struct('field','depends_on','operation','hasanysubfield_exact_string');
							ss_here(1).param1 = param1;
							ss_here(1).param2 = param2;
						elseif strcmpi('~depends_on',ndi_query_obj(i).searchstructure(j).operation),
							param1 = {'name','value'};
							param2 = { ndi_query_obj(i).searchstructure(j).param1 ndi_query_obj(i).searchstructure(j).param2 };
							if strcmp(param2{1},'*'), % ignore the name
								param1 = param1(2);
								param2 = param2(2);
							end;
							ss_here = struct('field','depends_on','operation','~hasanysubfield_exact_string');
							ss_here(1).param1 = param1;
							ss_here(1).param2 = param2;
						else % regular case
							ss_here(1).operation = did_query_obj(i).searchstructure(j).operation;
							if isa(did_query_obj(i).searchstructure(j).param1,'did_query')
								ss_here(1).param1 = did_query_obj(i).searchstructure(j).param1.to_searchstructure();
							else
								ss_here(1).param1 = did_query_obj(i).searchstructure(j).param1;
							end
							if isa(did_query_obj(i).searchstructure(j).param2,'did_query')
								ss_here(1).param2 = did_query_obj(i).searchstructure(j).param2.to_searchstructure();
							else
								ss_here(1).param2 = did_query_obj(i).searchstructure(j).param2;
							end
						end
						searchstructure(end+1) = ss_here;
					end
				end
		end % to_searchstructure();
	end % methods

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

				if ~iscell(searchcellarray) || mod(numel(searchcellarray),2) ~= 0
					error('Input must be a cell array in the form {''property1'',value1,...}');
				end

				searchstruct = did.datastructures.emptystruct('field','operation','param1','param2');

				for i=1:2:numel(searchcellarray)
					if ischar(searchcellarray{i+1})
						newstructure = struct('field',searchcellarray{i}, 'operation','regexp',...
							'param1',searchcellarray{i+1},'param2',[]);
					else
						newstructure = struct('field',searchcellarray{i}, 'operation','exact_number',...
						'param1',searchcellarray{i+1},'param2',[]);
					end
					searchstruct(end+1) = newstructure;
				end
		end

		function searchstruct_out = searchstruct(field, operation, param1, param2)
			% SEARCHSTRUCT - make a search structure from field, operation, param1, param2 inputs
			%
			% SEARCHSTRUCT_OUT = SEARCHSTRUCT(FIELD, OPERATION, PARAM1, PARAM2)
			%
			% Creates search structure with the given fields FIELD, OPERATION, PARAM1, PARAM2.
			% 
			% See also: FIELDSEARCH, DID.QUERY/DID.QUERY

				searchstruct_out = struct('field',field,'operation',operation,'param1',param1,'param2',param2);	 
		end 
	end % methods (Static)
end 
