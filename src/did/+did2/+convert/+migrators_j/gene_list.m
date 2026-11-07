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
%   THE FOUR SOURCE FACTS (Decided by Jess Haley, 2026-11-07, did-schema
%   did_v2_go_forward_class_audit.md [gene-list facts split] "C2",
%   [gene-list history entities] "1. A", [gene symbol namespace kept],
%   [annotation source is GENEPIO], [namespace variable terms], [no
%   source-facts list]; amending (c) of [gene list as a term, file kept]):
%     gene_id_namespace       a condition on the opaque_body, variable
%                             EMPTY:0000436 "identifier namespace", text the
%                             v1 value (it says how to read genes.tsv)
%     gene_symbol_namespace   a condition on the opaque_body, variable
%                             EMPTY:0000437 "symbol namespace" (kept: item 23,
%                             which dropped it, is amended)
%     annotation_source       history: a minimal `entity` of type Data Set
%                             (NCIT:C47824) named by the v1 text, and a
%                             `directed_relation` term -wasDerivedFrom->
%                             annotation (item 22) whose method carries the
%                             v1 text as one parameter, variable GENEPIO:0000096
%                             "genome annotation source"
%     genome_assembly         the same, one step further: annotation
%                             -wasDerivedFrom-> assembly (term -> assembly
%                             when there is no annotation), parameter
%                             variable NCIT:C164815 "Reference Genome Assembly
%                             Version"
%   Only a non-empty value is written. The relation's parameter keeps the v1
%   words when a per-dataset import later fills in the entity and keeps its
%   id ([gene-list history filled by import]), and it says which of the two
%   facts an entity is when only one is present. Nothing goes to the run's
%   report as not converted ([no source-facts list]).
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
%   did2.convert.roundtrip.geneList rebuilds the v1 document from the term, its
%   body and the history entities and relations; testRawV1RoundTripGene
%   compares the two.
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
    reasons{end+1} = '[carry-120] base.name (makeGeneList writes none, and v2 never writes base.name)';
end
if ~hasFile(body, 'genes.tsv')
    reasons{end+1} = '[carry-120] files (no genes.tsv attached)';
end
if ~(isnumeric(nGenes) && isscalar(nGenes) && isreal(nGenes) && isfinite(nGenes) ...
        && nGenes >= 0 && nGenes == round(nGenes))
    reasons{end+1} = '[carry-120] geneList.n_genes (not one integer >= 0)';
end
facts = {'gene_id_namespace', 'gene_symbol_namespace', 'annotation_source', 'genome_assembly'};
for f = facts
    v = fieldOr(blk, f{1}, '');
    if ~(ischar(v) || (isstring(v) && isscalar(v)))
        reasons{end+1} = sprintf('[carry-120] geneList.%s (not text)', f{1}); %#ok<AGROW>
    end
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
% the two namespaces say how to read genes.tsv: conditions on its body
% ([gene-list facts split], [namespace variable terms])
conds = {};
idNs = factText(blk, 'gene_id_namespace');
if ~isempty(idNs)
    conds{end+1} = did2.build.condition( ...
        did2.convert.registeredTerm('EMPTY:0000436', 'identifier namespace'), 'Text', idNs);
end
symNs = factText(blk, 'gene_symbol_namespace');
if ~isempty(symNs)
    conds{end+1} = did2.build.condition( ...
        did2.convert.registeredTerm('EMPTY:0000437', 'symbol namespace'), 'Text', symNs);
end
if ~isempty(conds)
    bodyOpts = [bodyOpts, {'Conditions', did2.build.list(conds{:})}];
end
file = did2.build.opaqueBody(id, did2.build.formatTerm('EDAM:format_3475'), bodyOpts{:});
file.files = body.files;   % genes.tsv as written, so the bytes NDI stores stay reachable

% the history: gene list -> annotation -> assembly ([gene-list history
% entities]; item 22), each a minimal Data Set named by the v1 text
bodies = {term, file};
child = id;
steps = { ...
    'annotation_source', 'GENEPIO:0000096', 'genome annotation source', 'gene_list annotation'; ...
    'genome_assembly',   'NCIT:C164815',    'Reference Genome Assembly Version', 'gene_list assembly'};
for k = 1:size(steps, 1)
    v = factText(blk, steps{k, 1});
    if isempty(v)
        continue;
    end
    [ent, rel] = historyStep(o, child, v, steps{k, 2:4});
    bodies = [bodies, {ent, rel}]; %#ok<AGROW>
    child = ent.base.id;
end
end

function [ent, rel] = historyStep(o, childId, text, varNode, varName, role)
% a minimal Data Set entity named TEXT, and CHILDID -wasDerivedFrom-> it,
% whose method's one parameter keeps TEXT under the fact's variable
ent = did2.build.document('entity', struct( ...
    'type', did2.convert.registeredTerm('NCIT:C47824', 'Data Set'), 'name', text), ...
    o{:}, 'Id', did2.convert.mintId(role));
param = did2.build.parameter(did2.convert.registeredTerm(varNode, varName), 'Text', text);
rel = did2.build.directedRelation(childId, ent.base.id, ...
    did2.convert.registeredTerm('prov:wasDerivedFrom', 'wasDerivedFrom'), ...
    'MethodParameters', param, o{:}, 'Id', did2.convert.mintId([role ' derived_from']));
end

function v = factText(blk, name)
% the v1 fact NAME as char, '' when absent or blank (makeGeneList's default)
v = fieldOr(blk, name, '');
if isstring(v)
    v = char(v);
end
if ~ischar(v) || isempty(strtrim(v))
    v = '';
end
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
