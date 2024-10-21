function [G,nodes,mdigraph] = docs2graph(document_obj)
    % DOCS2GRAPH - create a directed graph from a cell array of DID.DOCUMENT objects
    %
    % [G,NODES,MDIGRAPH] = DOCS2GRAPH(DOCUMENT_OBJ)
    %
    % Given a cell array of DID.DOCUMENT objects, this function creates a directed graph with the
    % 'depends_on' relationships. If an object A 'depends on' another object B, there will be an edge from B to A.
    % The adjacency matrix G, the node names (document ids) NODES, and the Matlab directed graph object MDIGRAPH are
    % all returned.
    %
    % See also: DIGRAPH
    %
    %

    nodes = {};

    for i=1:numel(document_obj),
        nodes{i} = document_obj{i}.document_properties.ndi_document.id;
    end;

    % now we have all the nodes, build adjacency matrix

    G = sparse(numel(nodes),numel(nodes));

    for i=1:numel(document_obj),
        here = i;
        if isfield(document_obj{i}.document_properties,'depends_on'),
            for j=1:numel(document_obj{i}.document_properties.depends_on),
                there = find(strcmp(document_obj{i}.document_properties.depends_on(j).value, nodes));
                G(here,there) = 1;
            end;
        end;
    end;

    mdigraph = digraph(G, nodes);
