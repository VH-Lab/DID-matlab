function [doc_struct_out, branch_node_indexes] = addrm_docs_to_branches(db, bG, branch_node_names, doc_struct, parent_node, node_start)
% ADDRM_DOCS_TO_BRANCHES - randomly add and remove documents as we add branches, check changes
%
% [DOC_STRUCT, BRANCH_NODE_INDEXES] = did.test.helper.utility.addrm_docs_to_branches(DB, BG, NODE_START )
%
% Names nodes in a tree with connectivity matrix specified by G, where G(i,j) is 1 if
% and only if node j is connected to i, and 0 otherwise. The connectivity matrix should
% specify a tree, with descending connectivity only and no loops.
%
% Nodes are named with any provided INITIAL_NODE_NAME_PREFIX, and children are named
% with suffixes '_a', '_b', etc. If INITIAL_NODE_NAME_PREFIX is empty, then no
% initial '_' is used in the labeling.
%
% If NODE_START is provided, then the tree is traversed from that node
% number. This can be a single node or an array of nodes.
% 
% NODE_NAMES are returned as a cell array of strings. NODE_INDEXES returns the 
% index values of the node names that were updated in the call.
%
% Example:
%  G = did.test.helper.utility.make_tree(4, 3, 0.8, 10);
%  node_names = did.test.helper.utility.name_tree(G);
%  figure;
%  plot(digraph(G,node_names),'layout','layered');
%

if nargin<5,
	parent_node = 0;
end;

if nargin<6,
	node_start = 0;
end;

isroot = 0;
if node_start==0,
	isroot = 1;
 	% look for roots
	starting_nodes = find(sum(bG,2)==0);
else,
	starting_nodes = node_start;
end;

 % initialize the outputs
doc_struct_out = {};
branch_node_indexes = [];

for i=1:size(bG,2),
	doc_struct_out{i} = vlt.data.emptystruct('G','node_names','docs');;
end;

for i=1:numel(starting_nodes),
        % Step 2-1: set up our branch

	if parent_node~=0,
		db.set_branch(branch_node_names{parent_node});
	end;

	node_here = starting_nodes(i);
	branch_node_indexes(end+1) = node_here;

	disp(['About to add branch ' branch_node_names{node_here} '.'])
	db.add_branch(branch_node_names{node_here});

	if isroot, % need to add the documents from doc_struct
		db.add_docs(doc_struct.docs);
		%for d=1:numel(doc_struct.docs),
		%	db.add_doc(doc_struct.docs{d});
		%end;
	end;

	% Step 2-2 modify doc_struct from the inputs by removing and adding some docs

	[~,docs_to_rm,new_doc_struct.G,new_doc_struct.node_names,new_doc_struct.docs]=...
		did.test.helper.documents.rm_doc_tree(2, doc_struct.G, doc_struct.node_names, doc_struct.docs);

	if ~isempty(docs_to_rm)
		db.remove_docs(docs_to_rm);
	end;

	N = numel(new_doc_struct.docs);
	[new_doc_struct2.G,new_doc_struct2.node_names,new_doc_struct2.docs] = ...
		did.test.helper.documents.add_doc_tree([5 5 5],new_doc_struct.G,...
		new_doc_struct.node_names, new_doc_struct.docs);

	db.add_docs(new_doc_struct2.docs(N+1:numel(new_doc_struct2.docs)));
	%for n=N+1:numel(new_doc_struct2.docs),
	%	db.add_doc(new_doc_struct2.docs{n});
	%end;

	doc_struct_out{node_here} = new_doc_struct2;

	% Step 2-3 check that the documents match what we expect

	[b,msg] = did.test.helper.documents.verify_db_document_structure(db,...
		new_doc_struct2.G, new_doc_struct2.docs);

	if ~b,
		msg,
		error(['Error adding branch ' branch_node_names(node_here) '...']);
	end;

	% Step 2-4 Now continue to traverse the branch tree

	next_nodes = find(bG(:,node_here)==1); % who is connected to this node?

	for j=1:numel(next_nodes),
		[doc_struct_next,node_indexes_next] = did.test.helper.utility.addrm_docs_to_branches(db, bG, branch_node_names, ...
			new_doc_struct2, node_here, next_nodes(j));
		for k=1:numel(node_indexes_next), % copy any non-empty node_names
			index_here = node_indexes_next(k); % global index
			if isempty(doc_struct_next{index_here}),
				keyboard;
				% this should not happen
			end;
			if ~isempty(doc_struct_next{index_here}),
				if ~isempty(doc_struct_out{index_here}), 
					error(['We visited a node twice, should not happen in a real tree.']);
				else,
					doc_struct_out{index_here} = doc_struct_next{index_here};
				end;
			end;
		end;
		branch_node_indexes = cat(1,branch_node_indexes(:),node_indexes_next);
	end;
end;


