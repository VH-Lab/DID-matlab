function [G, node_names, docs] = make_doc_tree(rates)
    % MAKE_DOC_TREE - make a "tree" of documents to add to a database
    %
    % [G, NODE_NAMES, DOCS] = MAKE_DOC_TREE(RATES)
    %
    % Makes a directed graph G, associated NODE_NAMES, and demo did.documents
    % DOCS by generating documents of type demoA demoB and demoC at poisson
    % rates RATES. RATES(1) is the rate of creation of document type A,
    % RATES(2) is the poisson rate of creation of document type B, and
    % RATES(3) is the poisson rate of creation of document type C.
    %
    % The As and Bs are created first. When each C type document is created,
    % an A and B document (and C document, if they exist) are randomly selected
    % to be the dependencies of the new C-type document.
    %
    % G(i,j) is 1 if document j depends on document i and 0 otherwise.
    %
    % Example:
    %   [G,node_names,docs] = did.test.helper.documents.make_doc_tree([10 10 10]);
    %   dG = digraph(G,node_names);
    %   figure;
    %   plot(dG,'layout','layered');
    %   set(gca,'ydir','reverse');
    %   box off;
    %

    numA = poissrnd(rates(1));
    numB = poissrnd(rates(2));
    numC = poissrnd(rates(3));

    G = sparse(numA+numB+numC,numA+numB+numC);

    counter = 1;

    docs = {};
    node_names = {};
    ids_A = {};
    ids_B = {};
    ids_C = {};

    for i=1:numA
        docs{end+1} = did.document('demoA','demoA.value',counter);
        node_names{end+1} = int2str(counter);
        ids_A{end+1} = docs{end}.id();
        counter = counter + 1;
    end

    for i=1:numB
        docs{end+1} = did.document('demoB','demoB.value',counter,...
            'demoA.value',counter);
        node_names{end+1} = int2str(counter);
        ids_B{end+1} = docs{end}.id();
        counter = counter + 1;
    end

    c_count = 0;

    for i=1:numC
        depA = randi([0 numA]);
        depB = randi([0 numB]);
        depC = randi([0 c_count]);

        docs{end+1} = did.document('demoC','demoC.value',counter);
        node_names{end+1} = int2str(counter);
        ids_C{end+1} = docs{end}.id();
        if depA>0
            docs{end} = docs{end}.set_dependency_value('item1',...
                ids_A{depA});
            G(depA,counter) = 1;
        end
        if depB>0
            docs{end} = docs{end}.set_dependency_value('item2',...
                ids_B{depB});
            G(numA+depB,counter) = 1;
        end
        if depC>0
            docs{end} = docs{end}.set_dependency_value('item3',...
                ids_C{depC});
            G(numA+numB+depC,counter) = 1;
        end

        counter = counter + 1;
        c_count = c_count + 1;
    end
