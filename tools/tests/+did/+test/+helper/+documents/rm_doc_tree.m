function [doc_ids_rm, doc_ids_rm_seed, G_out, node_names_out, docs_out] = rm_doc_tree(N, G, node_names, docs)
% ADD_DOC_TREE - add to a "tree" of documents for a DID database
%
% [DOC_IDS_RM, DOC_IDS_RM_SEED, G_OUT, NODE_NAMES_OUT, DOCS_OUT] = RM_DOC_TREE(N, G, NODE_NAMES, DOCS)
%
% Given a directed graph G and associated node names and demo did.document objects
% DOCS, RM_DOC_TREE removes N nodes at random, plus any nodes that depend on that
% the removed nodes. 
%
% DOC_IDS_RM are the document IDs that were removed, and DOC_IDS_RM_SEED are the 
% document IDs that were initially selected for removal (any others removed are due
% to dependency relationships).
%
% If the number of nodes/documents to be removed N is larger than the number of 
% nodes/documents, then N is reduced to match the number of nodes/documents.
%
% G_OUT(i,j) is 1 if document j depends on document i and 0 otherwise.
% 
% Example:
%   [G,node_names,docs] = did.test.helper.documents.make_doc_tree([10 10 10]);
%   [doc_ids_rm,doc_ids_rm_seed,Grm,node_names_rm,docs_rm] = did.test.helper.documents.rm_doc_tree(2, G, node_names, docs);
%   dG = digraph(Grm,node_names_rm);
%   figure;
%   plot(dG,'layout','layered');
%   box off;
% 

if N > numel(node_names),
	N = numel(node_names);
end;

node_indexes_to_delete = randperm(numel(node_names));
node_indexes_to_delete = node_indexes_to_delete(1:N);

doc_ids_rm_seed = {};

for i=1:numel(node_indexes_to_delete),
	doc_ids_rm_seed{end+1} = docs{node_indexes_to_delete(i)}.id();
end;

dG = digraph(G,node_names);

additional_indexes_to_delete = [];

for i=1:numel(node_indexes_to_delete),
	D = distances(dG,node_indexes_to_delete(i));
	additional_indexes_to_delete = cat(1,additional_indexes_to_delete(:),...
		vlt.data.colvec(find(~isinf(D))));
end;

node_indexes_to_delete = union(node_indexes_to_delete(:),additional_indexes_to_delete(:));
node_indexes_to_keep = setdiff(1:numel(node_names),node_indexes_to_delete);

G_out = G(node_indexes_to_keep,node_indexes_to_keep);
node_names_out = node_names(node_indexes_to_keep);
docs_out = docs(node_indexes_to_keep);

doc_ids_rm = {};

for i=1:numel(node_indexes_to_delete),
	doc_ids_rm{end+1} = docs{node_indexes_to_delete(i)}.id();
end;


