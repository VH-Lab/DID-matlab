function [id,d] = apply_didquery(docs,q)
%APPLY_DIDQUERY returns the expected document and id output of the selected query
%   
%   [ID,D] = APPLY_DIDQUERY(DOCS,Q)
%   
%   Given DOCS, a cell array of did.document objects, and Q, a did.query
%   object, calculate the expected outcome of the query by breaking down
%   the query into subqueries that can be calculated and combined by
%   fieldsearch, a previously verified means of querying a document
%
%   ID is a cell array of the did.document ids that should be
%   returned, and D is a cell array of did.document objects
%   that match the query.
%
%   Example: 
%      [ide,de] = apply_didquery(docs, did.query('base.id','exact_string','41268c9f518203ae_c0c5ed97d6afccde'))
%               % searches for a document with the exact id 41268c9f518203ae_c0c5ed97d6afccde
%             

search_params = q.to_searchstructure;
id = {};
d = {};
for i = 1:numel(docs)
    b = vlt.data.fieldsearch(docs{i}.document_properties,search_params);
    if b
        d{end+1,1} = docs{i}; %save the chosen docs in a columnar cell array
        id{end+1,1} = docs{i}.id; %save the chosen docs' ids in a columnar cell array
    end
end
end

