function [v1, spec] = geneList(bodies)
%GENELIST Rebuild a v1 `geneList` from what the migration made of it.
%
%   [V1, SPEC] = did2.convert.roundtrip.geneList(BODIES). BODIES is what
%   did2.convert.migrators_j.gene_list emitted when it CONVERTED the document
%   ([gene list as a term, file kept], Jess Haley, 2026-11-01): the standalone
%   `term` (the source id) and its `opaque_body`. V1 is the document in the
%   shape NDI-matlab +ndi/+fun/+doc/+gene/makeGeneList.m writes it:
%
%     base.id, session_id, datestamp   the term (rebuildBase)
%     geneList.label                   the body's notes ('' when it has none)
%     geneList.n_genes                 the body's one dimension's `n`
%     files                            the body's, as v1 wrote them
%
%   NOT rebuilt, and so reported lost by did2.convert.roundtrip.check (the
%   known findings testRawV1RoundTripGene lists): genome_assembly,
%   annotation_source, gene_id_namespace and gene_symbol_namespace, which the
%   run's report lists instead (did2.convert.reportNote 'not_converted'), and
%   gene_name_completeness and n_duplicate_gene_names, which item 21 of
%   did_v2_spatial_transcriptomics_plan.md drops as computable from genes.tsv.
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
for k = 1:numel(bodies)
    switch names{k}
        case 'term'
            if isempty(term); term = bodies{k}; continue; end
        case 'opaque_body'
            if isempty(ob); ob = bodies{k}; continue; end
    end
    spec.unplaced{end+1} = sprintf('an unexpected %s document', names{k});
end
[base, ~] = rebuildBase(term);
v1.document_class = struct('class_name', 'geneList');
v1.base = base;
blk = struct('label', '', 'n_genes', []);
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
    for f = {'files', 'file'}
        if isfield(ob, f{1})
            v1.(f{1}) = ob.(f{1});
        end
    end
end
v1.geneList = blk;
end
