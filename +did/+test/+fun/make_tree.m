function [G] = make_tree(N_initial, children_rate, children_rate_decay, max_depth)
% MAKE_TREE - construct a random tree structure
%
% G = did.test.fun.make_tree(N_INITIAL, CHILDREN_RATE, CHILDREN_RATE_DECAY, MAX_DEPTH)
%
% Creates a tree structure starting from N_INITIAL nodes. Each initial node generates
% a certain number of children according to the Poisson rate CHILDREN_RATE. In each
% subsequent generation, the CHILDREN_RATE is discounted by multiplying by the factor
% CHILDREN_RATE_DECAY, so that in generation g the rate is CHILDREN_RATE*(CHILDREN_RATE_DECAY^(g-1)).
% After reaching MAX_DEPTH, no more children are generated.
%
% G is a connectivity matrix such that G(i,j) is 1 if node j is a direct child of node i.
%
% Example:
%  G = did.test.fun.make_tree(4, 3, 0.8, 10);
%  figure;
%  plot(digraph(G),'layout','layered');
%

if max_depth < 0,
	children_rate = 0;
end;

G = sparse(zeros(N_initial));

% now work on children

for i=1:N_initial,
	current_nodes = size(G,1);
	num_children_here = poissrnd(children_rate);
	G_ = did.test.fun.make_tree(num_children_here, children_rate*children_rate_decay, children_rate_decay, max_depth-1);
	G = [ G zeros(size(G,1),size(G_,2)) ; ...
		zeros(size(G_,1), size(G,2)) G_ ];
	if num_children_here>0, 
		G(current_nodes+[1:num_children_here],i) = 1; % connect it to the existing graph
	end;
end;

