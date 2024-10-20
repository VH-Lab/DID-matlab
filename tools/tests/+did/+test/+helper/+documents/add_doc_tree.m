function [G_out, node_names_out, docs_out] = add_doc_tree(rates, G, node_names, docs)
% ADD_DOC_TREE - add to a "tree" of documents for a DID database
%
% [G_OUT, NODE_NAMES_OUT, DOCS_OUT] = ADD_DOC_TREE(RATES, G, NODE_NAMES, DOCS)
%
% Given a directed graph G and associated node names and demo did.document objects
% DOCS, ADD_DOC_TREE adds to these elements by adding new demo documents of
% type demoA demoB and demoC at poisson rates RATES. RATES(1) is the rate of
% creation of document type A, RATES(2) is the poisson rate of creation of document
% type B, and RATES(3) is the poisson rate of createion of document type C.
%
% The As and Bs are created first. When each C type document is created,
% an A and B document (and C document, if they exist) are randomly selected
% to be the dependencies of the new C-type document.
%
% G(i,j) is 1 if document j depends on document i and 0 otherwise.
% 
% Example:
%   [G,node_names,docs] = did.test.helper.documents.make_doc_tree([10 10 10]);
%   [G_out,node_names_out,docs_out] = did.test.helper.documents.add_doc_tree([10 10 10], G, node_names, docs);
%   dG = digraph(G_out,node_names_out);
%   figure;
%   plot(dG,'layout','layered');
%   set(gca,'ydir','reverse');
%   box off;
% 

numA = poissrnd(rates(1));
numB = poissrnd(rates(2));
numC = poissrnd(rates(3));

 % extend G
G = [ G sparse(size(G,1),numA+numB+numC); sparse(numA+numB+numC,size(G,2)+numA+numB+numC)];

counter = 1;

ids_A = {};
ids_B = {};
ids_C = {};
node_ids = {};

for i=1:numel(docs),
	node_ids{end+1} = docs{i}.id();
	switch(docs{i}.document_properties.document_class.class_name),
		case {'demoA'},
			ids_A{end+1} = docs{i}.id();
		case {'demoB'},
			ids_B{end+1} = docs{i}.id();
		case {'demoC'},
			ids_C{end+1} = docs{i}.id();
		otherwise,
			error(['Unknown document class ' docs{i}.document_properties.document_class.class_name '.']);
	end;
	counter = max(counter,str2num(node_names{i}));
end;

counter = counter + 1;

for i=1:numA,
	docs{end+1} = did.document('demoA','demoA.value',counter);
	node_names{end+1} = int2str(counter);
	ids_A{end+1} = docs{end}.id();
	node_ids{end+1} = ids_A{end};
	counter = counter + 1;
end;

for i=1:numB,
	docs{end+1} = did.document('demoB','demoB.value',counter,...
		'demoA.value',counter);
	node_names{end+1} = int2str(counter);
	ids_B{end+1} = docs{end}.id();
	node_ids{end+1} = ids_B{end};
	counter = counter + 1;
end;

for i=1:numC,
	depA = randi([0 numel(ids_A)]);
	depB = randi([0 numel(ids_B)]);
	depC = randi([0 numel(ids_C)]);

	docs{end+1} = did.document('demoC','demoC.value',counter);
	node_names{end+1} = int2str(counter);
	ids_C{end+1} = docs{end}.id();
	node_ids{end+1} = ids_C{end};
	if depA>0,
		docs{end} = docs{end}.set_dependency_value('item1',...
			ids_A{depA});
		depA_index = find(strcmp(ids_A{depA},node_ids));
		G(depA_index,numel(docs)) = 1;
	end;
	if depB>0,
		docs{end} = docs{end}.set_dependency_value('item2',...
			ids_B{depB});
		depB_index = find(strcmp(ids_B{depB},node_ids));
		G(depB_index,numel(docs)) = 1;
	end;
	if depC>0,
		docs{end} = docs{end}.set_dependency_value('item3',...
			ids_C{depC});
		depC_index = find(strcmp(ids_C{depC},node_ids));
		G(depC_index,numel(docs)) = 1;
	end;

	counter = counter + 1;
end;
 
G_out = G;
node_names_out = node_names;
docs_out = docs;


