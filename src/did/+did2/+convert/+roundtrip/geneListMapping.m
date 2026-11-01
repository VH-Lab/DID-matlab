function [v1, spec] = geneListMapping(bodies)
%GENELISTMAPPING Rebuild a v1 `geneListMapping` from what the migration made
%   of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.geneListMapping(BODIES). BODIES is what
%   did2.convert.migrators_j.gene_list_mapping emitted when it CONVERTED the
%   document (did-schema did_v2_go_forward_class_audit.md, [gene list mapping
%   value shape] and the decisions it lists): the relation (the source id), its
%   standalone value (`logical` or `score`) and the value's `opaque_body`. V1
%   is the document in the shape NDI's geneListMapping template gives it:
%
%     base.id, session_id, datestamp     the relation (rebuildBase)
%     depends_on geneList_id_a / _b      a directed relation's child / parent;
%                                        an undirected relation's two ends,
%                                        in stored order
%     geneListMapping.label              the relation's notes
%     .mapping_type                      EMPTY:0000381 -> alias,
%                                        EMPTY:0000386 -> ortholog
%     .method                            the text of the method's one parameter
%     .symmetric                         1 for an undirected relation, else 0
%     .n_pairs                           the value's one dimension's `n`
%     .n_genes_mapped_a / _b             the distinct entries of the `key` 0 /
%                                        `key` 1 covariate's `index`
%     .has_score                         1 for a `score` value, 0 for `logical`
%     files                              the body's, as v1 wrote them
%
%   A pass-1 passthrough (a document this migration carried, or passed through
%   on a schema without the covariate `index`) is rebuilt by
%   private/passthroughInverse, as before.
%
%   See also did2.convert.roundtrip.check,
%            did2.convert.migrators_j.gene_list_mapping.

arguments
    bodies cell
end

names = cellfun(@classNameOf, bodies, 'UniformOutput', false);
isRel = strcmp(names, 'directed_relation') | strcmp(names, 'undirected_relation');
if ~any(isRel)
    [v1, spec] = passthroughInverse(bodies, 'geneListMapping');
    return;
end
spec = emptySpec();
v1 = struct();
rel = [];
val = [];
ob = [];
for k = 1:numel(bodies)
    if isRel(k) && isempty(rel)
        rel = bodies{k};
    elseif any(strcmp(names{k}, {'logical', 'score'})) && isempty(val)
        val = bodies{k};
    elseif strcmp(names{k}, 'opaque_body') && isempty(ob)
        ob = bodies{k};
    else
        spec.unplaced{end+1} = sprintf('an unexpected %s document', names{k}); %#ok<AGROW>
    end
end
[base, ~] = rebuildBase(rel);
v1.document_class = struct('class_name', 'geneListMapping');
v1.base = base;

symmetric = strcmp(classNameOf(rel), 'undirected_relation');
if symmetric
    ends = did2.build.relatumIds(rel);
else
    ends = [edgeIds(rel, 'child_id'), edgeIds(rel, 'parent_id')];
end
if numel(ends) ~= 2
    spec.unplaced{end+1} = sprintf('the relation has %d ends, not 2', numel(ends));
    ends(end+1:2) = {''};
end
v1.depends_on = struct('name', {'geneList_id_a', 'geneList_id_b'}, 'value', ends(1:2));

blk = struct('label', fieldText(getIn(rel, 'relation'), 'notes'), ...
    'mapping_type', '', 'method', '', 'symmetric', double(symmetric), ...
    'n_pairs', [], 'n_genes_mapped_a', [], 'n_genes_mapped_b', [], ...
    'has_score', double(strcmp(classNameOf(val), 'score')));
relBlock = getIn(rel, classNameOf(rel));
node = '';
term = getIn(relBlock, 'relation');
if isstruct(term) && isfield(term, 'node')
    node = upper(char(term.node));
end
switch node
    case 'EMPTY:0000381'
        blk.mapping_type = 'alias';
    case 'EMPTY:0000386'
        blk.mapping_type = 'ortholog';
    otherwise
        spec.unplaced{end+1} = sprintf('relation term "%s" is not a gene-list mapping', node);
end
params = getIn(rel, 'relation', 'method', 'parameters');
if isstruct(params) && ~isempty(params)
    if numel(params) == 1 && isfield(params, 'text')
        blk.method = char(params.text);
    else
        spec.unplaced{end+1} = 'the method holds other than one text parameter';
    end
end

if isempty(val)
    spec.unplaced{end+1} = 'no value document was emitted';
else
    if ~isequal(edgeIds(rel, 'value_id'), {getIn(val, 'base', 'id')})
        spec.unplaced{end+1} = 'the relation does not point at the value';
    end
    dims = getIn(val, 'data', 'dimensions');
    if isstruct(dims) && isscalar(dims)
        blk.n_pairs = double(dims.n);
    else
        spec.unplaced{end+1} = 'the value does not have exactly one dimension';
    end
    covs = getIn(val, 'data', 'covariates');
    for key = 0:1
        ix = [];
        if isstruct(covs)
            for c = 1:numel(covs)
                if isfield(covs, 'key') && isequal(double(covs(c).key), key) && isfield(covs, 'index')
                    ix = covs(c).index;
                end
            end
        end
        if iscell(ix); ix = cell2mat(ix); end
        n = numel(unique(double(ix)));
        if key == 0
            blk.n_genes_mapped_a = n;
        else
            blk.n_genes_mapped_b = n;
        end
    end
end
if isempty(ob)
    spec.unplaced{end+1} = 'no opaque_body was emitted';
else
    if ~isempty(val) && ~isequal(edgeIds(ob, 'owner_id'), {getIn(val, 'base', 'id')})
        spec.unplaced{end+1} = 'the opaque_body is not owned by the value';
    end
    for f = {'files', 'file'}
        if isfield(ob, f{1})
            v1.(f{1}) = ob.(f{1});
        end
    end
end
v1.geneListMapping = blk;
end
