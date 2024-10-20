function [node_names, node_indexes] = name_tree(G, initial_node_name_prefix, node_start)
% NAME_TREE - name the nodes in a tree structure with given adjacency matrix
%
% [NODE_NAMES, NODE_INDEXES] = did.test.helper.utility.name_tree(G, [INITAL_NODE_NAME_PREFIX], [NODE_START])
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

if nargin<2,
	initial_node_name_prefix = '';
end;

if nargin<3,
	node_start = 0;
end;

	% if we are building a node name from a previous iteration, make sure to add a '_'
if ~isempty(initial_node_name_prefix),
	if initial_node_name_prefix(end)~='_',
		initial_node_name_prefix(end+1) = '_';
	end;
end;

if node_start==0,
 	% look for roots
	starting_nodes = find(sum(G,2)==0);
else,
	starting_nodes = node_start;
end;

 % initialize the node names
node_names = {};
node_indexes = [];

for i=1:size(G,2),
	node_names{i} = '';
end;

for i=1:numel(starting_nodes),
	node_here = starting_nodes(i);
	node_names{node_here} = [initial_node_name_prefix did.test.helper.utility.number_to_alpha_label(i)];
	node_indexes(end+1) = node_here;
	% where do we go from here?
	next_nodes = find(G(:,node_here)==1); % who is connected to this node?
	[node_names_next,node_indexes_next] = did.test.helper.utility.name_tree(G, node_names{node_here}, next_nodes);
	for k=1:numel(node_indexes_next), % copy any non-empty node_names
		index_here = node_indexes_next(k); % global index
		if isempty(node_names_next{index_here}),
			keyboard;
			% this should not happen
		end;
		if ~isempty(node_names_next{index_here}),
			if ~isempty(node_names{index_here}), 
				error(['We visited a node twice, should not happen in a real tree.']);
			else,
				node_names{index_here} = node_names_next{index_here};
			end;
		end;
	end;
	node_indexes = cat(1,node_indexes(:),node_indexes_next);
end;


