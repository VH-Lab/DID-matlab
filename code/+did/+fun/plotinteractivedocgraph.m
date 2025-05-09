function plotinteractivedocgraph(varargin) %(docs, G, mdigraph, nodes)
    % PLOTINTERACTIVEDOCGRAPH(DOCS, G, MDIGRAPH, NODES, LAYOUT)
    %
    % Given a cell array of NDI_DOCUMENTs DOCS, a connectivity matrix
    % G, a DIGRAPH object MDIGRAPH, a cell array of node names NODES,
    % and a type of DIGRAPH/PLOT layout LAYOUT, this plots a graph
    % of the graph of the NDI_DOCUMENTS. Usually, G, MDIGRAPH, and NODES
    % are the output of NDI_DOCS2GRAPH
    %
    % The plot is interactive, in that the closest node to any clicked
    % point will be displayed on the command line, and a global variable
    % 'clicked_node' will be set to the NDI_DOCUMENT of the closest node
    % to the clicked point. The user should click nearby but not directly on
    % the node to reveal it.
    %
    % Example values of LAYOUT include 'force', 'layered', 'auto', and
    % others. See HELP DIGRAPH/PLOT for all options.
    %
    % See also: DIGRAPH/PLOT, DOCS2GRAPH
    %
    % Example: % Given a DID database DB, plot a graph of all documents.
    %   docs = db.search(did.query({'document_class.class_name','(.*)'}));
    %   [G,nodes,mdigraph] = did.fun.docs2graph(docs);
    %   did.fun.plotinteractivedocgraph(docs,G,mdigraph,nodes,'layered');
    %

    if nargin==0

        global clicked_node;

        f = gcf;
        a = gca;
        userData = get(f,'userdata');
        pt = get(gca,'CurrentPoint');

        pt = pt(1,1:2); % just take first row, live in 2-d only
        ch = get(gca,'children'); % assume we got the only plot
        X = get(ch(1),'XData');
        Y = get(ch(1),'YData');
        Z = get(ch(1),'ZData'); % in case we want to go to 3-d
        ind = did.datastructures.findclosest( sqrt( (X-pt(1)).^2 + (Y-pt(2)).^2), 0);

        id = userData.nodes(ind);

        disp(['Doc index ' int2str(ind) ' with id ' id ':']);
        userData.docs{ind}.document_properties
        userData.docs{ind}.document_properties.document_class
        userData.docs{ind}.document_properties.ndi_document

        clicked_node = userData.docs{ind};
        disp('Global variable ''clicked_node'' set to clicked document');

        return;
    end

    layout = varargin{5};

    f = figure;
    
    userData = struct();
    userData.docs =  varargin{1};
    userData.G = varargin{2};
    userData.mdigraph = varargin{3};
    userData.nodes = varargin{4};
    
    set(f,'userdata',userData);

    plot(userData.mdigraph,'layout',layout);

    set(gca,'ButtonDownFcn','did.fun.plotinteractivedocgraph');
