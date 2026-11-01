function bodies = gene_list(preBody)
%GENE_LIST Brainstorm-J migrator: did_v1 geneList -> a standalone `term`
%   document, its `genes.tsv` kept unchanged as the term's opaque_body.
%   1 -> 2.
%
%   Decided by Jess Haley, 2026-11-01 [gene list as a term, file kept] (did-schema
%   did_v2_go_forward_class_audit.md; "A ok B ok c ok"; answers docs/V2_PLAN.md
%   GL9), with 2026-10-31 [gene list mapping in the generic stage] ("Generic, and
%   yes as long as the v1 id is valid") and did_v2_spatial_transcriptomics_plan.md
%   item 21 (TEAM-SIGN-OFF [spatial_transcriptomics_family], 2026-09-29):
%
%     term          a standalone value document (not a statement: no subject
%                   fits), `data_body: true`, base.id = the v1 id, so a
%                   geneListMapping's geneList_id_a / geneList_id_b and a
%                   pyramid's geneList_id still resolve
%     opaque_body   owner_id the term; `genes.tsv` unchanged and unparsed (the
%                   v1 `files` block rides as written: renaming it would cut it
%                   from the bytes NDI stores under that name); `format`
%                   EDAM:format_3475 "TSV"; `dimensions` [{NCIT:C16612 "Gene",
%                   n = v1 n_genes}]; `notes` = v1 label
%
%   NOT CONVERTED by the generic migration, and listed in the run's report so
%   nothing is lost ([gene list as a term, file kept] (c); item 22's
%   `derived_from` links to the assembly and annotation are a per-dataset
%   import's work): `genome_assembly`, `annotation_source`,
%   `gene_id_namespace`. `gene_symbol_namespace` (item 23: dropped, "the
%   annotation it came from is recorded") is listed beside them, because the
%   annotation is only listed, not recorded, until that import runs. Each
%   non-empty value is one did2.convert.reportNote of kind 'not_converted'
%   (summary.migration_notes.not_converted), DETAIL '<field> = <value> (...)'.
%   The run's migration report ([migration record], [migration report is an
%   attached file]) takes these notes once its DID-matlab part is built.
%
%   DROPPED (item 21: "computable" from genes.tsv, which is kept):
%   `gene_name_completeness`, `n_duplicate_gene_names`.
%
%   CARRIED whole as v1 (the untouched source):
%     carry-100   a field, block or edge outside NDI's geneList template
%                 ([fields outside the template are malformed])
%     carry-120   a value no NDI writer produces ([values no writer produces
%                 are malformed]): no base.id (the id the mapping edges name
%                 must be kept, [gene list mapping in the generic stage]), a
%                 base.name (the writer leaves it empty), no `genes.tsv` attached, or an `n_genes` that is not one
%                 integer >= 0 (NDI-matlab main +ndi/+fun/+doc/+gene/
%                 makeGeneList.m writes all three)
%
%   READS RAW v1 (did2.convert.rawV1Classes; [migrators read raw v1]): the
%   document exactly as v1 wrote it (`geneList`, NDI-matlab locked `main`, as
%   +ndi/+fun/+doc/+gene/makeGeneList.m writes it).
%   did2.convert.roundtrip.geneList rebuilds the v1 document from the term and
%   its body; testRawV1RoundTripGene compares the two.
arguments
    preBody (1,1) struct
end
[body, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'geneList', {{'label', 'n_genes', 'genome_assembly', 'gene_id_namespace', ...
        'gene_symbol_namespace', 'annotation_source', 'gene_name_completeness', ...
        'n_duplicate_gene_names'}}), ...
    {});
blk = struct();
if isfield(body, 'geneList') && isstruct(body.geneList) && isscalar(body.geneList)
    blk = body.geneList;
end
id = jCarryId(body);
nGenes = fieldOr(blk, 'n_genes', []);
reasons = {};
if isempty(id)
    reasons{end+1} = '[carry-120] base.id (empty: the id a mapping''s geneList_id_a/_b names is kept)';
end
bb = did2.convert.v1read.readBase(body);
if ~isempty(bb.name)
    reasons{end+1} = '[carry-120] base.name (makeGeneList writes none, and V2 never writes base.name)';
end
if ~hasFile(body, 'genes.tsv')
    reasons{end+1} = '[carry-120] files (no genes.tsv attached)';
end
if ~(isnumeric(nGenes) && isscalar(nGenes) && isreal(nGenes) && isfinite(nGenes) ...
        && nGenes >= 0 && nGenes == round(nGenes))
    reasons{end+1} = '[carry-120] geneList.n_genes (not one integer >= 0)';
end
if jRawCarry('gene_list', preBody, collision, unplaced, 'carry-100', reasons)
    bodies = {preBody};   % the carry of the untouched v1 source
    return;
end

o = jOpts(body);
term = did2.build.document('term', struct('data_body', true), o{:}, 'Id', id);
gene = did2.convert.registeredTerm('NCIT:C16612', 'Gene');
label = char(fieldOr(blk, 'label', ''));
bodyOpts = [o, {'Dimensions', did2.build.dimension(gene, double(nGenes))}];
if ~isempty(strtrim(label))
    bodyOpts = [bodyOpts, {'Notes', label}];
end
file = did2.build.opaqueBody(id, did2.build.formatTerm('EDAM:format_3475'), bodyOpts{:});
file.files = body.files;   % genes.tsv as written, so the bytes NDI stores stay reachable

% listed in the run's report, not converted
for f = {'genome_assembly', 'annotation_source', 'gene_id_namespace', 'gene_symbol_namespace'}
    v = fieldOr(blk, f{1}, '');
    if (ischar(v) || isstring(v)) && ~isempty(strtrim(char(v)))
        did2.convert.reportNote('not_converted', 'gene_list', id, sprintf( ...
            'geneList.%s = %s (a per-dataset import''s work; [gene list as a term, file kept])', ...
            f{1}, char(v)));
    end
end
bodies = {term, file};
end

function v = fieldOr(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end

function tf = hasFile(body, name)
% whether the v1 `files` block attaches NAME
tf = false;
if ~isfield(body, 'files') || ~isstruct(body.files) || ~isscalar(body.files)
    return;
end
names = {};
if isfield(body.files, 'file_list')
    names = textList(body.files.file_list);
end
if isfield(body.files, 'file_info') && isstruct(body.files.file_info) ...
        && isfield(body.files.file_info, 'name')
    names = [names, textList({body.files.file_info.name})];
end
tf = any(strcmp(names, name));
end

function c = textList(v)
% V as a row cellstr of its text entries; an empty list (jsondecode gives [])
% or a non-text entry names no file
c = {};
if ischar(v) || isstring(v)
    v = cellstr(v);
end
if iscell(v)
    keep = cellfun(@(x) ischar(x) || (isstring(x) && isscalar(x)), v);
    c = cellfun(@char, v(keep), 'UniformOutput', false);
    c = c(:)';
end
end
