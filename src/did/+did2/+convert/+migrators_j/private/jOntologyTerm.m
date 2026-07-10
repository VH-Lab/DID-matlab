function t = jOntologyTerm(node, name)
%JONTOLOGYTERM Build a V_eta ontology_term composite {node, name}.
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
t = struct('node', char(node), 'name', char(name));
end
