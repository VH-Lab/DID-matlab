function [docs_actual] = get_docs_expected(docs,id_expected,value_expected,query)
%GET_DOCS_ACTUAL returns the expected document output of the selected query
%   inputs: docs is a cell array of documents, id_actual is a string id,
%   version_actual is a number, query is a string operation (either 'and'
%   or 'or')
%   outputs: docs_actual is a cell array of documents
docs_actual = {};
switch query
    case 'and'
        %first find docs that match the id
        docs_id_match = {};
        for doc_ind = 1:length(docs)
            if strcmp(docs{doc_ind}.id,id_expected)
                docs_id_match{end+1} = docs{doc_ind};
            end
        end
        %from those docs, find docs that match the value
        for doc_ind = 1:length(docs_id_match)
            demoType = did.test.fun.get_demoType(docs{doc_ind});
            each_value = eval(['docs{doc_ind}.document_properties.',demoType,'.value']);
            if each_value == value_expected
                docs_actual{end+1} = docs{doc_ind};
            end
        end
    case 'or'
        %first find docs that match the id
        for doc_ind = 1:length(docs)
            if strcmp(docs{doc_ind}.id,id_expected)
                docs_actual{end+1} = docs{doc_ind};
            end
        end
        %keep adding docs that match the version to the list of docs that
        %match the id (but don't add those that already match id and are in the list)
        for doc_ind = 1:length(docs)
            demoType = did.test.fun.get_demoType(docs{doc_ind});
            each_value = eval(['docs{doc_ind}.document_properties.',demoType,'.value']);
            if each_value == value_expected...
                    && ~strcmp(docs{doc_ind}.id,id_expected)
                docs_actual{end+1} = docs{doc_ind};
            end
        end
end
end

