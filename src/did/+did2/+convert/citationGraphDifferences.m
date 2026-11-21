function [differences, facts] = citationGraphDifferences(formBodies, graphBodies, datasetId)
%CITATIONGRAPHDIFFERENCES Where an openMINDS dataset graph's v2 documents
%   differ from what the dataset's `metadata_editor` form produced.
%
%   [DIFFERENCES, FACTS] = did2.convert.citationGraphDifferences(FORMBODIES,
%   GRAPHBODIES, DATASETID). FORMBODIES are the v2 documents (structs) the
%   form became in pass 1 (did2.convert.migrators_j.metadata_editor), with
%   every `dataset` entity of DATASETID in the batch; GRAPHBODIES are the v2
%   documents did2.convert.resolveOpenmindsCitations builds from the graph.
%   DIFFERENCES is a cellstr, empty when the two match: one line per fact one
%   side states and the other does not ('form only: ...', 'graph only:
%   ...'). FACTS is {form, graph, compared}: the fact counts of each side and
%   of their union, the denominator of the comparison.
%
%   THE DECISION. Decided by Jess Haley, 2026-11-20 [metadata editor graph
%   compared with its form] (did-schema did_v2_go_forward_class_audit.md,
%   amending [metadata editor form is the source]): "(1) both present and
%   matching: the graph's documents are dropped as derived; (2) both present
%   and differing: the graph is carried as v1 and counted (carry-174,
%   needs_mapping)". NDI's metadata-editor app writes the graph only on Save,
%   from the same form data (convertFormDataToDocuments), and the form on
%   every close, so the form is at least as new as the graph.
%
%   FIELD BY FIELD, ON THE V2 DOCUMENTS. Each side is read into FACTS, one
%   text line per stated value, by the same rules, so the two are compared
%   as documents, not as v1 sources:
%
%     dataset        its entity's name and notes; each assertion about it, as
%                    variable = value (text, the term's label, or the date's
%                    instant); a variable stated twice is one line with its
%                    values sorted
%     author(i)      by has_author order: given name, family name, e-mail,
%                    ORCID, and the names of its affiliated_with organizations
%     funding        each funded_by funding: title, award number, and its
%                    issued_by organization's name (a set: funding is
%                    unordered)
%     publication    each cited publication's DOI (a set)
%     documentation  each documented_by entity's identifiers
%     other          any other relation from the dataset, as its name and its
%                    target's name (the graph's copyright_holder, which the
%                    form never writes, is one)
%
%   NOT COMPARED, because the graph build cannot state them, so the graph
%   cannot differ there (did2.convert.resolveOpenmindsCitations, the
%   "not in the graph" lines of buildComponent): the dataset's keywords,
%   support channel, how to cite, accessibility, ethics jurisdiction,
%   technique (NCIT:C16847) and scientific data type (NCIT:C175886); a
%   publication's title, PMID and PMCID ("THE GRAPH HOLDS ONLY A DOI"); a
%   person's or organization's own entity name (derived from the fields
%   compared). The graph's technique, data type and contribution documents
%   have no v2 document, so they are counted by the pass, not compared here.
%
%   SPELLING IS NOTATION. A DOI is compared as `doi:<lower-case DOI>` whether
%   it is written `doi:`, `https://doi.org/` or `https://dx.doi.org/`, and an
%   ORCID without its `ORCID:` or `https://orcid.org/` prefix; a term value by
%   its label, case-insensitively (its node when it has no label), since the
%   form path names a closed-list term and the graph an openMINDS instance.
%
%   THE FORM'S DATASET ENTITY. Pass 1 gives the form's dataset entity the
%   dataset id, which the bare entities of `dataset_remote`,
%   `session_in_a_dataset` and `dataset_session_info` share until
%   did2.convert.resolveDatasetEntities keeps one; those state no name and no
%   notes. So the name (notes) is the one non-empty name (notes) the dataset
%   entities of DATASETID in FORMBODIES state; several different ones are one
%   line naming them all, which no graph matches.
%
%   See also did2.convert.resolveOpenmindsCitations,
%   did2.convert.migrators_j.metadata_editor.

arguments
    formBodies cell
    graphBodies cell
    datasetId (1,:) char
end

formFacts = factsOf(formBodies, datasetId);
graphFacts = factsOf(graphBodies, datasetId);
onlyForm = setdiff(formFacts, graphFacts, 'stable');
onlyGraph = setdiff(graphFacts, formFacts, 'stable');
differences = [cellfun(@(s) ['form only: ' s], onlyForm, 'UniformOutput', false), ...
    cellfun(@(s) ['graph only: ' s], onlyGraph, 'UniformOutput', false)];
differences = reshape(differences, 1, []);
facts = struct('form', numel(formFacts), 'graph', numel(graphFacts), ...
    'compared', numel(union(formFacts, graphFacts)));
end

% ===================== the facts of one side ===============================

function lines = factsOf(bodies, datasetId)
lines = {};
n = numel(bodies);
ids = cell(1, n);
for k = 1:n
    ids{k} = idOf(bodies{k});
end

% --- the dataset entity: name and notes ------------------------------------
names = {};
notes = {};
for k = 1:n
    if strcmp(ids{k}, datasetId) && isEntityOfType(bodies{k}, 'dataset')
        names{end+1} = entityText(bodies{k}, 'name'); %#ok<AGROW>
        notes{end+1} = entityText(bodies{k}, 'notes'); %#ok<AGROW>
    end
end
lines = [lines, oneValue('dataset name', names), oneValue('dataset notes', notes)];

% --- the assertions about the dataset ----------------------------------------
lines = [lines, statementLines(bodies, datasetId, 'dataset', true)];

% --- the relations from the dataset ------------------------------------------
authors = struct('order', {}, 'line', {});
funding = {};
pubs = {};
docs = {};
for k = 1:n
    b = bodies{k};
    if ~strcmp(classNameOf(b), 'directed_relation') || ~strcmp(edgeId(b, 'child_id'), datasetId)
        continue;
    end
    rname = relationName(b);
    target = find(strcmp(ids, edgeId(b, 'parent_id')), 1);
    switch rname
        case 'has_author'
            authors(end+1) = struct('order', relationOrder(b), ...
                'line', personLine(bodies, ids, target)); %#ok<AGROW>
        case 'funded_by'
            funding{end+1} = fundingLine(bodies, ids, target); %#ok<AGROW>
        case 'cites'
            for g = identifiersOf(bodies, target)
                if startsWith(g{1}, 'doi:')
                    pubs{end+1} = ['publication ' g{1}]; %#ok<AGROW>
                end
            end
        case 'documented_by'
            for g = identifiersOf(bodies, target)
                docs{end+1} = ['documentation ' g{1}]; %#ok<AGROW>
            end
        otherwise
            lines{end+1} = sprintf('dataset %s (order %d) %s', rname, ...
                relationOrder(b), targetName(bodies, target)); %#ok<AGROW>
    end
end
if ~isempty(authors)
    [~, o] = sort([authors.order]);
    authors = authors(o);
    for i = 1:numel(authors)
        lines{end+1} = sprintf('author %d: %s', i - 1, authors(i).line); %#ok<AGROW>
    end
end
lines = [lines, sort(funding), unique(pubs), unique(docs)];
lines = reshape(lines, 1, []);
end

function lines = oneValue(label, values)
values = unique(values(~cellfun(@isempty, values)));
lines = {};
if isempty(values); return; end
lines = {sprintf('%s: %s', label, strjoin(values, ' | '))};
end

function lines = statementLines(bodies, entityId, label, skipFormOnly)
% one line per variable of the assertions about ENTITYID, its values sorted
keys = {};
vals = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isStatementAbout(b, entityId); continue; end
    [vnode, vname] = termParts(getIn(b, 'statement', 'variable'));
    if skipFormOnly && isFormOnly(vnode, vname); continue; end
    key = lower(strtrim(vname));
    if ~isempty(vnode); key = curieKey(vnode); end
    hit = find(strcmp(keys, key), 1);
    if isempty(hit)
        keys{end+1} = key; %#ok<AGROW>
        vals{end+1} = {}; %#ok<AGROW>
        hit = numel(keys);
    end
    vals{hit} = [vals{hit}, valueTexts(b)];
end
lines = cell(1, numel(keys));
for i = 1:numel(keys)
    lines{i} = sprintf('%s %s = %s', label, keys{i}, strjoin(sort(vals{i}), ' | '));
end
end

function tf = isFormOnly(node, name)
% the dataset variables the graph build never writes (header: NOT COMPARED)
nodes = {'EDAM:data_0968', 'NCIT:C175887', 'EMPTY:0000359', 'NCIT:C16847', 'NCIT:C175886'};
labels = {'keyword', 'support channel', 'how to cite', 'accessibility', ...
    'ethics jurisdiction', 'technique', 'scientific data type'};
tf = any(cellfun(@(c) strcmp(curieKey(node), curieKey(c)), nodes)) ...
    || any(strcmpi(strrep(strtrim(name), '_', ' '), labels));
end

function line = personLine(bodies, ids, p)
if isempty(p)
    line = '(not emitted)';
    return;
end
pid = ids{p};
orcid = {};
for g = identifiersOf(bodies, p)
    if startsWith(g{1}, 'orcid:'); orcid{end+1} = g{1}; end %#ok<AGROW>
end
affs = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(classNameOf(b), 'directed_relation') && strcmp(edgeId(b, 'child_id'), pid) ...
            && strcmp(relationName(b), 'affiliated_with')
        affs{end+1} = targetName(bodies, find(strcmp(ids, edgeId(b, 'parent_id')), 1)); %#ok<AGROW>
    end
end
st = statementLines(bodies, pid, 'person', false);
line = sprintf('%s; orcid %s; affiliation %s', strjoin(sort(st), '; '), ...
    strjoin(sort(orcid), ' | '), strjoin(sort(affs), ' | '));
end

function line = fundingLine(bodies, ids, f)
if isempty(f)
    line = 'funding (not emitted)';
    return;
end
fid = ids{f};
funders = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if strcmp(classNameOf(b), 'directed_relation') && strcmp(edgeId(b, 'child_id'), fid) ...
            && strcmp(relationName(b), 'issued_by')
        funders{end+1} = targetName(bodies, find(strcmp(ids, edgeId(b, 'parent_id')), 1)); %#ok<AGROW>
    end
end
line = sprintf('funding title %s; award %s; funder %s', ...
    entityText(bodies{f}, 'name'), entityText(bodies{f}, 'local_identifier'), ...
    strjoin(sort(funders), ' | '));
end

function s = targetName(bodies, k)
s = '(not emitted)';
if isempty(k); return; end
s = entityText(bodies{k}, 'name');
end

function out = identifiersOf(bodies, k)
% the entity's global identifiers, spelled one way (SPELLING IS NOTATION)
out = {};
if isempty(k); return; end
g = getIn(bodies{k}, 'entity', 'global_identifier');
if ischar(g) || (isstring(g) && isscalar(g)); g = {char(g)}; end
if ~iscell(g); return; end
for j = 1:numel(g)
    if ~(ischar(g{j}) || (isstring(g{j}) && isscalar(g{j}))); continue; end
    s = strtrim(char(g{j}));
    if isempty(s); continue; end
    doi = regexp(s, '^(?:doi:|https?://(?:dx\.)?doi\.org/)(.+)$', 'tokens', 'once', 'ignorecase');
    orcid = regexp(s, '^(?:orcid:|https?://orcid\.org/)(.+)$', 'tokens', 'once', 'ignorecase');
    if ~isempty(doi)
        s = ['doi:' lower(strtrim(doi{1}))];
    elseif ~isempty(orcid)
        s = ['orcid:' upper(strtrim(orcid{1}))];
    end
    out{end+1} = s; %#ok<AGROW>
end
out = unique(out);
end

% ===================== reading one document ================================

function t = valueTexts(b)
% the values of an assertion as text: text values, a term's label (its node
% when it has none), a date's instant
t = {};
for v = asCell(getIn(b, 'text', 'value'))
    x = v{1};
    if isstruct(x) && isfield(x, 'text'); x = x.text; end
    if ischar(x) || (isstring(x) && isscalar(x)); t{end+1} = char(x); end %#ok<AGROW>
end
for v = asCell(getIn(b, 'term', 'value'))
    [node, name] = termParts(v{1});
    if ~isempty(name)
        t{end+1} = lower(strtrim(name)); %#ok<AGROW>
    elseif ~isempty(node)
        t{end+1} = curieKey(node); %#ok<AGROW>
    end
end
d = getIn(b, 'date', 'value', 'instant');
if ischar(d) || (isstring(d) && isscalar(d)); t{end+1} = char(d); end
end

function tf = isStatementAbout(b, id)
tf = isstruct(b) && isscalar(b) && isfield(b, 'statement') ...
    && strcmp(edgeId(b, 'entity_id'), id);
end

function tf = isEntityOfType(b, handle)
tf = strcmp(classNameOf(b), 'entity') && isfield(b, 'entity') && isstruct(b.entity) ...
    && isscalar(b.entity) && isfield(b.entity, 'type') ...
    && strcmp(did2.build.vocabularyHandle('entity_type', b.entity.type), handle);
end

function s = entityText(b, name)
s = '';
e = getIn(b, 'entity', name);
if ischar(e) || (isstring(e) && isscalar(e)); s = strtrim(char(e)); end
end

function n = relationName(b)
n = char(did2.build.vocabularyHandle('relation', getIn(b, 'directed_relation', 'relation')));
end

function o = relationOrder(b)
o = getIn(b, 'directed_relation', 'order');
if isempty(o) || ~isnumeric(o); o = -1; end
o = double(o(1));
end

function id = edgeId(b, name)
id = '';
if ~isstruct(b) || ~isscalar(b); return; end
deps = did2.convert.v1read.readDependsOn(b, 'Name', ['^' name '$']);
for k = 1:numel(deps)
    if ~isempty(deps(k).document_id)
        id = char(deps(k).document_id);
        return;
    end
end
end

function id = idOf(b)
id = '';
if isstruct(b) && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id') ...
        && ~isempty(b.base.id)
    id = char(b.base.id);
end
end

function c = classNameOf(b)
c = '';
if isstruct(b) && isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    c = char(b.document_class.class_name);
end
end

function [node, name] = termParts(t)
node = '';
name = '';
if iscell(t) && ~isempty(t); t = t{1}; end
if isstruct(t) && ~isempty(t)
    t = t(1);
    if isfield(t, 'node') && ~isempty(t.node); node = char(t.node); end
    if isfield(t, 'name') && ~isempty(t.name); name = char(t.name); end
elseif ischar(t) || (isstring(t) && isscalar(t))
    name = char(t);
end
end

function v = getIn(s, varargin)
v = s;
for i = 1:numel(varargin)
    if iscell(v) && ~isempty(v); v = v{1}; end
    if isstruct(v) && ~isempty(v); v = v(1); end
    if isstruct(v) && isscalar(v) && isfield(v, varargin{i})
        v = v.(varargin{i});
    else
        v = [];
        return;
    end
end
end

function c = asCell(v)
if iscell(v)
    c = reshape(v, 1, []);
elseif isstruct(v)
    c = num2cell(reshape(v, 1, []));
elseif isempty(v)
    c = {};
else
    c = {v};
end
end

function k = curieKey(s)
s = strtrim(char(s));
k = lower(s);
if isempty(s); return; end
try
    k = char(did2.schema.curieKey(s));
catch
end
end
