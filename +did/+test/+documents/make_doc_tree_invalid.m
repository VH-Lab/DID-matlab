function [G, node_names, docs] = make_doc_tree_invalid(rates,varargin)
% MAKE_DOC_TREE - make a "tree" of documents to add to a database
%
% [G, NODE_NAMES, DOCS] = MAKE_DOC_TREE_INVALID(RATES)
%
% Makes a directed graph G, associated NODE_NAMES, and demo did.documents 
% DOCS by generating documents of type demoA demoB and demoC at poisson
% rates RATES. RATES(1) is the rate of creation of document type A,
% RATES(2) is the poisson rate of creation of document type B, and
% RATES(3) is the poisson rate of createion of document type C.
%
% The As and Bs are created first. When each C type document is created,
% an A and B document (and C document, if they exist) are randomly selected
% to be the dependencies of the new C-type document.
%
% This version takes name/value pairs that may make changes that are invalid 
% to the schema:
% -----------------------------------------------------------------------------------------------------
% | Parameter (default)                        | Description                                          |
% |--------------------------------------------|------------------------------------------------------|
% | value_modifier ('sham')                    | How should we modify the value field?                          |
% | id_modifier ('sham')                    | How should we modify the id field?                          |
% | datestamp_modifier ('sham')                    | How should we modify the datestamp field?                          |
% | session_id_modifier ('sham')                    | How should we modify the session_id field?                          |
% | dependency_modifier ('sham')                    | How should we modify the doc dependencies?                          |
% | remover ('sham')                    | Which field should we remove?                         |
% |--------------------------------------------|------------------------------------------------------|
%
% G(i,j) is 1 if document j depends on document i and 0 otherwise.
% 
% Example:
%   [G,node_names,docs] = did.test.documents.make_doc_tree([10 10 10]);
%   dG = digraph(G,node_names);
%   figure;
%   plot(dG,'layout','layered');
%   set(gca,'ydir','reverse');
%   box off;
% 

numA = poissrnd(rates(1));
numB = poissrnd(rates(2));
numC = poissrnd(rates(3));

G = sparse(numA+numB+numC,numA+numB+numC);

counter = 1;

docs = {};
node_names = {};
ids_A = {};
ids_B = {};
ids_C = {};


%list of possible tests and their default option
value_modifier = 'sham';
id_modifier = 'sham';
datestamp_modifier = 'sham';
session_id_modifier= 'sham';
dependency_modifier = 'sham'; % primarily for demoC
remover = 'sham';
did.datastructures.assign(varargin{:});


for i=1:numA,
	docs{end+1} = did.document('demoA'); %add unmodified document to list
    %now can continue modifying docs:
    d = docs{end};
    d_struct = struct(d);
    %modify value:
    d_struct.document_properties.demoA.value = modifyvalue(value_modifier,counter);
    %modify id: 
    current_id = docs{end}.document_properties.base.id; 
    d_struct.document_properties.base.id = modifyid(id_modifier,current_id);
    %remove a struct or field:
    d_struct = remove(remover,d_struct);
    %finish:
    if isfield(d_struct,'document_properties')
        docs{end} = did.document(d_struct.document_properties); %replace document in list with the modified version
    else
        docs{end} = did.document(d_struct);
    end
	node_names{end+1} = int2str(counter);
    if isfield(docs{end}.document_properties,'base') && isfield(docs{end}.document_properties.base,'id')
        ids_A{end+1} = docs{end}.id();
    end
	counter = counter + 1;
end;

for i=1:numB,
	docs{end+1} = did.document('demoB','demoB.value',counter,...
		'demoA.value',counter);
    %now can continue modifying docs:
    d = docs{end};
    d_struct = struct(d);
    %modify value:
    d_struct.document_properties.demoA.value = modifyvalue(value_modifier,counter);
    %modify id: 
    current_id = docs{end}.document_properties.base.id; 
    d_struct.document_properties.base.id = modifyid(id_modifier,current_id);
    %remove a struct or field:
    d_struct = remove(remover,d_struct);
    %finish:
    if isfield(d_struct,'document_properties')
        docs{end} = did.document(d_struct.document_properties); %replace document in list with the modified version
    else
        docs{end} = did.document(d_struct);
    end
	node_names{end+1} = int2str(counter);
    if isfield(docs{end}.document_properties,'base') && isfield(docs{end}.document_properties.base,'id')
        ids_B{end+1} = docs{end}.id();
    end
	counter = counter + 1;
end;

c_count = 0;

for i=1:numC,
	depA = randi([0 numA]);
	depB = randi([0 numB]);
	depC = randi([0 c_count]);

	docs{end+1} = did.document('demoC','demoC.value',counter);
    %now can continue modifying docs:
    d = docs{end};
    d_struct = struct(d);
    %modify value:
    d_struct.document_properties.demoA.value = modifyvalue(value_modifier,counter);
    %modify id: 
    current_id = docs{end}.document_properties.base.id; 
    d_struct.document_properties.base.id = modifyid(id_modifier,current_id);
    %remove a struct or field:
    d_struct = remove(remover,d_struct);
    %finish:
    if isfield(d_struct,'document_properties')
        docs{end} = did.document(d_struct.document_properties); %replace document in list with the modified version
    else
        docs{end} = did.document(d_struct);
    end
	node_names{end+1} = int2str(counter);
    if isfield(docs{end}.document_properties,'base') && isfield(docs{end}.document_properties.base,'id')
        ids_C{end+1} = docs{end}.id();
    end
	if depA>0 && numel(ids_A)>0 % check that ids_A is being filled in before accessing its indices 
		docs{end} = docs{end}.set_dependency_value('item1',...
			ids_A{depA});
		G(depA,counter) = 1;
	end;
	if depB>0 && numel(ids_B)>0,
		docs{end} = docs{end}.set_dependency_value('item2',...
			ids_B{depB});
		G(numA+depB,counter) = 1;
	end;
	if depC>0 && numel(ids_C)>0,
		docs{end} = docs{end}.set_dependency_value('item3',...
			ids_C{depC});
		G(numA+numB+depC,counter) = 1;
	end;

	counter = counter + 1;
	c_count = c_count + 1;
end;
 

function value = modifyvalue(method, value)

    switch method
        case 'int2str'
            value = int2str(value);
        case 'blank int'
            value = [];
        case 'blank str'
            value = '';
        case 'nan'
            value = nan;
        case 'double'
            value = value + .5;
        case 'too negative'
            value = -1 * intmax;
        case 'too positive'
            value = intmax;
        case 'sham'
        otherwise
            error(['Unknown method ' method '.']);    
    end;

function id = modifyid(method,id)
switch method
    case 'substring'
        id = cell2mat(extractBetween(id,1,32));
    case 'replace_underscore'
        id = replaceBetween(id,17,17,'a'); %replace underscore with the letter a
    case 'add'
        id = [id 'a']; %add the letter a to the end of the id
    case 'replace_letter_valid'
        id = replaceBetween(id,1,1,'a'); %replace letter/digit with another letter
    case 'replace_letter_invalid1'
        id = replaceBetween(id,1,1,'*'); %replace letter/digit with a special character
    case 'replace_letter_invalid2'
        id = replaceBetween(id,1,1,''''); %replace letter/digit with a special charactercase 'sham'
    case 'sham'
    otherwise
        error(['Unknown method ' method '.']);
end
function struct = remove(method,struct)
switch method
    case 'document_properties'
        struct = rmfield(struct,'document_properties');
    case 'base'
        struct.document_properties = rmfield(struct.document_properties,'base');
    case 'session_id'
        struct.document_properties.base = rmfield(struct.document_properties.base,'session_id');
    case 'id'
        struct.document_properties.base = rmfield(struct.document_properties.base,'id');
    case 'name'
        struct.document_properties.base = rmfield(struct.document_properties.base,'name');
    case 'datestamp'
        struct.document_properties.base = rmfield(struct.document_properties.base,'datestamp');
    case 'demoA'
        struct.document_properties = rmfield(struct.document_properties,'base');
    case 'demoB' %for demoB docs
    case 'demoC' %for demoC docs
    case 'value'
        struct.document_properties.demoA = rmfield(struct.document_properties.demoA,'value');
    case 'document_class'
        struct.document_properties = rmfield(struct.document_properties,'document_class');
    case 'definition'
        struct.document_properties.document_class = rmfield(struct.document_properties.document_class,'definition');
    case 'validation'
        struct.document_properties.document_class = rmfield(struct.document_properties.document_class,'validation');
    case 'class_name'
        struct.document_properties.document_class = rmfield(struct.document_properties.document_class,'class_name');
    case 'property_list_name'
        struct.document_properties.document_class = rmfield(struct.document_properties.document_class,'property_list_name');
    case 'class_version'
        struct.document_properties.document_class = rmfield(struct.document_properties.document_class,'class_version');
    case 'superclasses'
        struct.document_properties.document_class = rmfield(struct.document_properties.document_class,'superclasses');
    case 'superclasses.definition'
        struct.document_properties.document_class.superclasses = rmfield(struct.document_properties.document_class.superclasses,'definition');
    case 'sham'
    otherwise
        error(['Unknown method ' method '.']);
end
    


