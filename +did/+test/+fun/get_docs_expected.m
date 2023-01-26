function [ids_expected,docs_expected] = get_docs_expected(docs,id_input,value_input,query)
%GET_DOCS_EXPECTED returns the expected document output of the selected query
%
%   [IDS_EXPECTED, DOCS_EXPECTED] = GET_DOCS_EXPECTED(DOCS, ID_INPUT, VALUE_INPUT, QUERY)
%
%   Given DOCS, a cell array of did.document objects, id_input (the id of a
%   selected document), an array of VALUEs to search for in either demoA, demoB, or
%   demoC, and query (either 'and', 'or', or 'not'), this calculates
%   the expected output of the query.
%
%   IDS_EXPECTED is a cell array of the did.document ids that should be
%   returned, and DOCS_EXPECTED is a cell array of did.document objects
%   that match the query.
%
%   Example: 
%      [ide,de] = get_docs_expected(docs, '12345',1,'and')
%               % searches for a document that has a field
%               % demoA.value equal to 1 or demoB.value equal to 1 or
%               % demoC.value equal to 1 AND an id equal to '12345'.
%
%

docs_expected = {};
switch query
    case 'and'
        %first find docs that match the id
        docs_id_match = {};
        for doc_ind = 1:length(docs)
            if strcmp(docs{doc_ind}.id,id_input)
                docs_id_match{end+1} = docs{doc_ind};
            end
        end
        %from those docs, find docs that match the value
        for doc_ind = 1:length(docs_id_match)
            demoType = did.test.fun.get_demoType(docs{doc_ind});
            each_value = eval(['docs{doc_ind}.document_properties.',demoType,'.value']);
            if did.datastructures.eqlen(each_value,value_input),
                docs_expected{end+1} = docs{doc_ind};
            end
        end
    case 'or'
        %keep adding docs that match the version to the list of docs that
        %match the id (but don't add those that already match id and are in the list)
        for doc_ind = 1:length(docs)
            demoType = did.test.fun.get_demoType(docs{doc_ind});
            each_value = eval(['docs{doc_ind}.document_properties.',demoType,'.value']);
            if ismember(each_value,value_input) | strcmp(docs{doc_ind}.id,id_input)
                docs_expected{end+1} = docs{doc_ind};
            end
        end
    case 'not'
        %add docs that don't match the ID
        for doc_ind = 1:length(docs)
            demoType = did.test.fun.get_demoType(docs{doc_ind});
            each_value = eval(['docs{doc_ind}.document_properties.',demoType,'.value']);
            if ~strcmp(docs{doc_ind}.id,id_input)
                docs_expected{end+1} = docs{doc_ind};
            end
        end
end % switch

ids_expected = {};
for i=1:numel(docs_expected), 
    ids_expected{i} = docs_expected{i}.id();
end;

end

