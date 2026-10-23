function t = jOntologyTerm(node, name)
%JONTOLOGYTERM Build a V_eta ontology_term composite {node, name}.
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
%   did-schema #88 (tenet T19): a term the registry holds is written as the
%   registry writes it -- its registered label for a known node, its
%   registered node for a known name (did2.convert.registeredTerm).
t = did2.convert.registeredTerm(char(node), char(name));
end
