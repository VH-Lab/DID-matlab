function [v1, spec] = geneList(bodies)
%GENELIST Rebuild a v1 `geneList` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.geneList(BODIES). BODIES is what
%   did2.convert.migrators_j.gene_list emitted when it CONVERTED the document
%   ([gene list as a term, file kept], Jess Haley, 2026-11-01, as amended
%   2026-11-07 by [gene-list facts split] and [gene-list history entities]):
%   the standalone `term` (the source id), its `opaque_body`, and for each of
%   the annotation and the assembly a Data Set `entity` and the
%   `directed_relation` that derives the term (or the annotation) from it. V1
%   is the document in the shape NDI-matlab +ndi/+fun/+doc/+gene/
%   makeGeneList.m writes it:
%
%     base.id, session_id, datestamp   the term (rebuildBase)
%     geneList.label                   the body's notes ('' when it has none)
%     geneList.n_genes                 the body's one dimension's `n`
%     geneList.gene_id_namespace       the body's condition EMPTY:0000436
%     geneList.gene_symbol_namespace   the body's condition EMPTY:0000437
%     geneList.annotation_source       the parameter GENEPIO:0000096 of the
%                                      relation from the term
%     geneList.genome_assembly         the parameter NCIT:C164815 of the
%                                      relation that ends the chain
%     files                            the body's, as v1 wrote them
%   Each of the four is '' (makeGeneList's default) when nothing holds it.
%
%   NOT rebuilt, and so reported lost by did2.convert.roundtrip.check (the
%   known findings testRawV1RoundTripGene lists): gene_name_completeness and
%   n_duplicate_gene_names, which item 21 of did_v2_spatial_transcriptomics_
%   plan.md drops as computable from genes.tsv.
%
%   A pass-1 passthrough (a document this migration carried) is rebuilt by
%   private/passthroughInverse, as before.
%
%   See also did2.convert.roundtrip.check, did2.convert.migrators_j.gene_list.

arguments
    bodies cell
end

names = cellfun(@classNameOf, bodies, 'UniformOutput', false);
if ~any(strcmp(names, 'term'))
    [v1, spec] = passthroughInverse(bodies, 'geneList');
    return;
end
spec = emptySpec();
v1 = struct();
term = [];
ob = [];
ents = {};
rels = {};
for k = 1:numel(bodies)
    switch names{k}
        case 'term'
            if isempty(term); term = bodies{k}; continue; end
        case 'opaque_body'
            if isempty(ob); ob = bodies{k}; continue; end
        case 'entity'
            ents{end+1} = bodies{k}; %#ok<AGROW>
            continue;
        case 'directed_relation'
            rels{end+1} = bodies{k}; %#ok<AGROW>
            continue;
    end
    spec.unplaced{end+1} = sprintf('an unexpected %s document', names{k});
end
[base, ~] = rebuildBase(term);
v1.document_class = struct('class_name', 'geneList');
v1.base = base;
blk = struct('label', '', 'n_genes', [], 'genome_assembly', '', ...
    'gene_id_namespace', '', 'gene_symbol_namespace', '', 'annotation_source', '');
if isempty(ob)
    spec.unplaced{end+1} = 'no opaque_body was emitted';
else
    if ~isequal(edgeIds(ob, 'owner_id'), {base.id})
        spec.unplaced{end+1} = 'the opaque_body is not owned by the term';
    end
    blk.label = fieldText(getIn(ob, 'data_body'), 'notes');
    dims = getIn(ob, 'data', 'dimensions');
    if isstruct(dims) && isscalar(dims) && isfield(dims, 'n')
        blk.n_genes = double(dims.n);
    else
        spec.unplaced{end+1} = 'the opaque_body does not have exactly one dimension';
    end
    conds = asCell(getIn(ob, 'data_body', 'conditions'));
    for k = 1:numel(conds)
        [node, text] = textEntry(conds{k});
        if sameCurie(node, 'EMPTY:0000436')
            blk.gene_id_namespace = text;
        elseif sameCurie(node, 'EMPTY:0000437')
            blk.gene_symbol_namespace = text;
        else
            spec.unplaced{end+1} = sprintf('a body condition with variable %s', node); %#ok<AGROW>
        end
    end
    for f = {'files', 'file'}
        if isfield(ob, f{1})
            v1.(f{1}) = ob.(f{1});
        end
    end
end
% the history chain: term -> annotation -> assembly, each step one relation
% whose one parameter keeps the v1 text
entIds = cellfun(@(e) char(getIn(e, 'base', 'id')), ents, 'UniformOutput', false);
used = false(1, numel(ents));
child = base.id;
done = false(1, numel(rels));
while true
    hit = find(~done & cellfun(@(r) isequal(edgeIds(r, 'child_id'), {child}), rels), 1);
    if isempty(hit)
        break;
    end
    done(hit) = true;
    rel = rels{hit};
    parent = edgeIds(rel, 'parent_id');
    e = find(strcmp(entIds, char(strjoin(parent, ','))), 1);
    if isempty(e)
        spec.unplaced{end+1} = 'a derived_from relation whose parent is not an emitted entity'; %#ok<AGROW>
        break;
    end
    used(e) = true;
    params = asCell(getIn(rel, 'relation', 'method', 'parameters'));
    if numel(params) ~= 1
        spec.unplaced{end+1} = 'a derived_from relation whose method holds other than one parameter'; %#ok<AGROW>
        break;
    end
    [node, text] = textEntry(params{1});
    if sameCurie(node, 'GENEPIO:0000096') && strcmp(child, base.id)
        blk.annotation_source = text;
    elseif sameCurie(node, 'NCIT:C164815')
        blk.genome_assembly = text;
    else
        spec.unplaced{end+1} = sprintf('a derived_from parameter with variable %s', node); %#ok<AGROW>
    end
    child = entIds{e};
end
if any(~done)
    spec.unplaced{end+1} = 'a directed_relation outside the gene list''s history chain';
end
if any(~used)
    spec.unplaced{end+1} = 'an entity outside the gene list''s history chain';
end
v1.geneList = blk;
end

function [node, text] = textEntry(e)
% a condition's or parameter's variable node and its text
[node, ~] = termParts(getIn(e, 'variable'));
text = '';
t = getIn(e, 'text');
if ischar(t) || isstring(t)
    text = char(t);
end
end
