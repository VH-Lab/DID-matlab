function bodies = gene_list_mapping(preBody)
%GENE_LIST_MAPPING Brainstorm-J migrator: did_v1 geneListMapping -> a relation
%   between the two gene lists, its pairs a standalone value with
%   `mapping.tsv` as that value's opaque_body. 1 -> 3.
%
%   Decided by Jess Haley (did-schema did_v2_go_forward_class_audit.md; issue
%   did-schema #117; docs/V2_PLAN.md GL1-GL11):
%     [gene list mapping is built], [gene list mapping in the generic stage]
%         (2026-10-31): migrated here, in the generic stage, between the two
%         gene-list `term` documents gene_list.m makes (ids kept)
%     [gene list mapping value shape], [gene list mapping value kind],
%     [gene list mapping method text], [gene list mapping leftovers],
%     [gene list mapping other types carried], [orthology mapping has no
%     method term], [mapping rows counted, indices 0-based], [key covariate
%     index], [undirected relation widened], [undirected ends are relata]
%         (2026-11-01)
%
%   THE DOCUMENTS
%     relation   v1 `symmetric` 0: a `directed_relation` from gene list A
%                (`child_id`, v1 geneList_id_a) to gene list B (`parent_id`,
%                v1 geneList_id_b). v1 `symmetric` 1: an `undirected_relation`
%                whose two ends (`relatum_id`, or `entity_id` on a schema from
%                before the rename; did2.build.undirectedRelation) are [A, B].
%                base.id = the v1 id. `relation`: EMPTY:0000381 "gene alias
%                mapping" (mapping_type `alias`) or EMPTY:0000386 "orthologous
%                gene mapping" (`ortholog`). `method`: an alias mapping's term
%                is EDAM:operation_3282 "ID mapping"; an orthology mapping has
%                no method term. The v1 `method` text is kept unchanged as the
%                text of one method parameter (its variable NCIT:C150832
%                "Software Name" is Proposed (not decided), [gene list mapping
%                terms]). `notes` = v1 label. `value_id` = the value below.
%     value      a standalone `logical` (v1 has_score 0: true for each listed
%                pair) or `score` (has_score 1), `data_body: true`, with ONE
%                dimension, one position per data row of mapping.tsv (its term
%                SIO:000752 "row" is Proposed (not decided), [gene list mapping
%                terms]), and two covariates along it, variable NCIT:C16612
%                "Gene": `key` 0 with `index` = the gene_index_a column and `key`
%                1 with `index` = the gene_index_b column (0-based), `key_id`
%                [list A, list B]. A score's scale is not stated: v1 never
%                records it; the gap is listed in the run's migration report
%                (did2.build.document 'Gaps', [migration record]).
%     body       an `opaque_body` owned by the value: mapping.tsv unchanged
%                (the v1 `files` block as written), `format` EDAM:format_3475
%                "TSV".
%   `n_pairs`, `n_genes_mapped_a` and `n_genes_mapped_b` are dropped as fields:
%   they are recomputed from the file (the row count; the distinct indices of
%   each covariate), and checked against it first.
%
%   READING mapping.tsv. The indices and the row count come from the file,
%   which a migrator reads through did2.convert.v1Files (v1_to_v2's
%   'V1FileReader'). Its first line names the columns gene_index_a,
%   gene_index_b and, optionally, score; each data row has one value per
%   column.
%
%   CARRIED whole as v1 (the untouched source):
%     carry-100   a field, block or edge outside NDI's geneListMapping template
%                 ([fields outside the template are malformed])
%     carry-120   a value no NDI writer produces ([values no writer produces
%                 are malformed]; NDI has no writer of this class, so the
%                 template's own documentation is the reference): no base.id,
%                 a base.name, an edge to list A or B missing, `symmetric` or
%                 `has_score` not 0 or 1, a mapping.tsv whose header or rows
%                 are not as the template documents (a gene index that is not
%                 an integer >= 0; a score that is not a number when has_score
%                 is 1, or any score when it is 0), `n_pairs` not the number
%                 of data rows ([mapping rows counted, indices 0-based]: "if
%                 they disagree, the document is malformed"), or
%                 n_genes_mapped_a/_b not the number of distinct genes of
%                 that list in the file
%     carry-166   a `mapping_type` other than alias or ortholog ([gene list
%                 mapping other types carried]: "anything else keeps the whole
%                 document as v1"; not_modelled)
%     carry-167   a mapping.tsv this run cannot read (malformed: NDI's
%                 template declares the file and no NDI writer makes the
%                 class; a DID-only run given no 'V1FileReader' and no local
%                 file location carries every mapping this way)
%
%   READS RAW v1 (did2.convert.rawV1Classes; [migrators read raw v1]): the
%   document exactly as v1 wrote it (`geneListMapping`, NDI-matlab locked
%   `main`; no NDI writer constructs one, so the template alone fixes its
%   shape). did2.convert.roundtrip.geneListMapping rebuilds the v1 document
%   from the relation, the value and the body; testRawV1RoundTripGene compares.
arguments
    preBody (1,1) struct
end
[body, collision, unplaced] = jRawAccount(preBody, struct( ...
    'files', {{'file_list', 'file_series', 'file_info'}}, ...
    'geneListMapping', {{'label', 'mapping_type', 'method', 'symmetric', 'n_pairs', ...
        'n_genes_mapped_a', 'n_genes_mapped_b', 'has_score'}}), ...
    {'^geneList_id_a$', '^geneList_id_b$'});
% Siblings first: until the schema in use declares a covariate's `index` (and,
% for a symmetric mapping, an undirected relation whose ends are `relatum_id`),
% the mapping passes through as it did before this conversion
if ~schemaReady(body)
    jRawCarry('gene_list_mapping', preBody, collision, unplaced, 'carry-100');
    bodies = {preBody};   % a passthrough, or the carry of the untouched v1 source
    return;
end
blk = struct();
if isfield(body, 'geneListMapping') && isstruct(body.geneListMapping) ...
        && isscalar(body.geneListMapping)
    blk = body.geneListMapping;
end
bb = did2.convert.v1read.readBase(body);
id = jCarryId(body);
listA = edgeValue(body, 'geneList_id_a');
listB = edgeValue(body, 'geneList_id_b');
reasons = {};
if isempty(id)
    reasons{end+1} = '[carry-120] base.id (empty)';
end
if ~isempty(bb.name)
    reasons{end+1} = '[carry-120] base.name (V2 never writes base.name)';
end
if isempty(listA) || isempty(listB)
    reasons{end+1} = '[carry-120] depends_on geneList_id_a/geneList_id_b (one is empty)';
end
symmetric = flag(blk, 'symmetric');
hasScore = flag(blk, 'has_score');
if ~islogical(symmetric)
    reasons{end+1} = '[carry-120] geneListMapping.symmetric (not 0 or 1)';
end
if ~islogical(hasScore)
    reasons{end+1} = '[carry-120] geneListMapping.has_score (not 0 or 1)';
end
mappingType = lower(strtrim(char(fieldOr(blk, 'mapping_type', ''))));
switch mappingType
    case 'alias'
        relationTerm = did2.convert.registeredTerm('EMPTY:0000381', 'gene alias mapping');
        methodTerm = did2.convert.registeredTerm('EDAM:operation_3282', 'ID mapping');
    case 'ortholog'
        relationTerm = did2.convert.registeredTerm('EMPTY:0000386', 'orthologous gene mapping');
        methodTerm = [];   % [orthology mapping has no method term]
    otherwise
        % [gene list mapping other types carried] (Jess Haley, 2026-11-01)
        reasons{end+1} = sprintf(['[carry-166] geneListMapping.mapping_type (''%s'': only alias and ' ...
            'ortholog have relation terms; [gene list mapping other types carried])'], mappingType);
end
rows = struct('a', [], 'b', [], 'n', 0);
if isempty(reasons)
    [text, ok, why] = did2.convert.v1Files('read', body, 'mapping.tsv');
    if ~ok
        reasons{end+1} = sprintf('[carry-167] files mapping.tsv (%s)', why);
    else
        [rows, problem] = readMapping(text, hasScore);
        if ~isempty(problem)
            reasons{end+1} = sprintf('[carry-120] mapping.tsv (%s)', problem);
        else
            reasons = [reasons, countReasons(blk, rows)];
        end
    end
end
% carry-register: carry-100 carry-120 carry-166 carry-167
if jRawCarry('gene_list_mapping', preBody, collision, unplaced, 'carry-100', reasons)
    bodies = {preBody};   % the carry of the untouched v1 source
    return;
end

o = jOpts(body);
gene = did2.convert.registeredTerm('NCIT:C16612', 'Gene');
% Proposed (not decided), [gene list mapping terms]: the `row` dimension's term
rowTerm = did2.convert.registeredTerm('SIO:000752', 'row');
covs = did2.build.list( ...
    did2.build.covariate(gene, 0, 'Key', 0, 'Index', rows.a), ...
    did2.build.covariate(gene, 0, 'Key', 1, 'Index', rows.b));
if hasScore
    valueClass = 'score';
else
    valueClass = 'logical';
end
valueId = did2.convert.mintId(['gene_list_mapping ' valueClass]);
gaps = struct('field', {}, 'reason', {});
if hasScore
    % [gene list mapping value kind]: v1 never states the score's scale; the
    % gap is listed in the run's migration report ([migration record])
    gaps = struct('field', 'value.scale', 'reason', ...
        'v1 geneListMapping never states the score''s scale ([gene list mapping value kind])');
end
value = did2.build.document(valueClass, struct('data_body', true, ...
    'dimensions', {did2.build.dimension(rowTerm, rows.n)}, 'covariates', {covs}), ...
    o{:}, 'Edges', struct('key_id', {{listA, listB}}), 'Id', valueId, 'Gaps', gaps);
file = did2.build.opaqueBody(valueId, did2.build.formatTerm('EDAM:format_3475'), o{:});
file.files = body.files;   % mapping.tsv as written, so the bytes NDI stores stay reachable

params = [];
methodText = char(fieldOr(blk, 'method', ''));
if ~isempty(strtrim(methodText))
    % Proposed (not decided), [gene list mapping terms]: the parameter's variable
    params = did2.build.parameter( ...
        did2.convert.registeredTerm('NCIT:C150832', 'Software Name'), 'Text', methodText);
end
fields = struct();
label = char(fieldOr(blk, 'label', ''));
if ~isempty(strtrim(label))
    fields.notes = label;   % [gene list mapping leftovers]
end
if symmetric
    % [undirected relation widened], [undirected ends are relata]
    rel = did2.build.undirectedRelation({listA, listB}, relationTerm, ...
        'Method', methodTerm, 'MethodParameters', params, 'ValueId', valueId, ...
        'Fields', fields, o{:}, 'Id', id);
else
    rel = did2.build.directedRelation(listA, listB, relationTerm, ...
        'Method', methodTerm, 'MethodParameters', params, 'ValueId', valueId, ...
        'Fields', fields, o{:}, 'Id', id);
end
bodies = {rel, value, file};
end

% ===================== mapping.tsv ==========================================

function [rows, problem] = readMapping(text, hasScore)
% The data rows of mapping.tsv: A and B, the 0-based gene indices (row
% vectors), and N, the number of data rows ([mapping rows counted, indices
% 0-based]). PROBLEM is '' or what is not as the template documents.
rows = struct('a', [], 'b', [], 'n', 0);
problem = '';
lines = regexp(char(text), '\r?\n', 'split');
while ~isempty(lines) && isempty(lines{end})
    lines(end) = [];   % the final newline
end
if isempty(lines)
    problem = 'empty: no header row';
    return;
end
tab = sprintf('\t');
header = strsplit(lines{1}, tab, 'CollapseDelimiters', false);
withScore = isequal(header, {'gene_index_a', 'gene_index_b', 'score'});
if ~(withScore || isequal(header, {'gene_index_a', 'gene_index_b'}))
    problem = sprintf('header "%s" is not gene_index_a, gene_index_b[, score]', lines{1});
    return;
end
if hasScore && ~withScore
    problem = 'has_score is 1 but there is no score column';
    return;
end
data = lines(2:end);
n = numel(data);
a = zeros(1, n);
b = zeros(1, n);
for k = 1:n
    cols = strsplit(data{k}, tab, 'CollapseDelimiters', false);
    if numel(cols) ~= numel(header)
        problem = sprintf('data row %d has %d columns, the header %d', k, numel(cols), numel(header));
        return;
    end
    a(k) = str2double(cols{1});
    b(k) = str2double(cols{2});
    if ~(isIndex(a(k)) && isIndex(b(k)))
        problem = sprintf('data row %d: a gene index that is not an integer >= 0', k);
        return;
    end
    if withScore
        s = strtrim(cols{3});
        if hasScore && ~isfinite(str2double(s))
            problem = sprintf('data row %d: the score "%s" is not a number', k, s);
            return;
        end
        if ~hasScore && ~isempty(s)
            problem = sprintf('data row %d holds a score, but has_score is 0', k);
            return;
        end
    end
end
rows = struct('a', a, 'b', b, 'n', n);
end

function tf = isIndex(v)
tf = isfinite(v) && v >= 0 && v == round(v);
end

function reasons = countReasons(blk, rows)
% [mapping rows counted, indices 0-based]: n_pairs is the number of data rows;
% the two coverage counts are recomputed too, so each must agree with the file
reasons = {};
checks = {'n_pairs', rows.n; ...
    'n_genes_mapped_a', numel(unique(rows.a)); ...
    'n_genes_mapped_b', numel(unique(rows.b))};
for k = 1:size(checks, 1)
    v = fieldOr(blk, checks{k, 1}, []);
    if ~(isnumeric(v) && isscalar(v) && v == checks{k, 2})
        reasons{end+1} = sprintf('[carry-120] geneListMapping.%s (%s; mapping.tsv gives %d)', ...
            checks{k, 1}, mat2str(v), checks{k, 2}); %#ok<AGROW>
    end
end
end

% ===================== small readers ========================================

function tf = schemaReady(body)
% the loaded schema declares what this conversion writes: data.covariates.index
% ([key covariate index]) and, for a symmetric mapping, undirected_relation's
% `relatum_id` ends ([undirected ends are relata], with [undirected relation
% widened])
tf = jSchemaHasPath('data', {'covariates', 'index'});
if ~tf
    return;
end
blk = struct();
if isfield(body, 'geneListMapping') && isstruct(body.geneListMapping)
    blk = body.geneListMapping;
end
if isequal(flag(blk, 'symmetric'), true)
    tf = false;
    try
        s = did2.schema.cache.shared().getClass('undirected_relation');
        deps = s.depends_on;
        if ~iscell(deps); deps = num2cell(deps); end
        tf = any(cellfun(@(d) strcmp(char(d.name), 'relatum_id'), deps));
    catch
    end
end
end

function v = fieldOr(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end

function f = flag(blk, name)
% 0 or 1 as a logical; NaN when the field is not one of them
f = NaN;
v = fieldOr(blk, name, []);
if (isnumeric(v) || islogical(v)) && isscalar(v) && (v == 0 || v == 1)
    f = logical(v);
end
end

function v = edgeValue(body, name)
v = '';
deps = did2.convert.v1read.readDependsOn(body, 'Name', ['^' name '$']);
for k = 1:numel(deps)
    if ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
        return;
    end
end
end
