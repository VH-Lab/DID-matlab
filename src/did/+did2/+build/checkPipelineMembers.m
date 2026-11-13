function checkPipelineMembers(pipeline, docs)
%CHECKPIPELINEMEMBERS A pipeline's programs are software, ordered from 0 with no gap.
%
%   did2.build.checkPipelineMembers(PIPELINE, DOCS) raises
%   did2:build:ruleViolated unless every `member of` (RO:0002350)
%   directed_relation in DOCS whose parent_id names PIPELINE
%     * names as its child_id a document in DOCS that is a `software` entity,
%     * has an `order` (an integer >= 0; -1, the blank, is "unordered"), and
%   the orders of those relations, taken together, are 0, 1, ..., N-1, each
%   exactly once.
%
%   PIPELINE is a `software` entity (did2:build:badOption otherwise). DOCS
%   holds the pipeline's `member of` relations and the program entities they
%   name; other documents in it are ignored. A software entity no `member of`
%   relation in DOCS points at is an ordinary program: nothing to check.
%
%   The decisions (did-schema did_v2_go_forward_class_audit.md):
%     [pipeline is a software entity] (Jess Haley, 2026-11-06): "a pipeline of
%       external programs is a pipeline `software` entity. Each program
%       (Kilosort, Phy, the NDI importer) is an ordinary `software` entity with
%       its name and version. The pipeline entity links to its programs with a
%       membership relation ... Statements keep their single `software_id` and
%       point at the pipeline."
%     [pipeline order counts from 0] (Jess Haley, 2026-11-12): the programs are
%       ordered on the `member of` relation from 0 (Kilosort 0, Phy 1, the NDI
%       importer 2), as every other ordered membership.
%     [pipeline steps use member of] (Jess Haley, 2026-11-12): the existing
%       `member of` relation, with a `software` entity as parent as well as a
%       `Group`; no separate step relation.
%   The rule needs the program entities and every relation, which
%   did2.build.directedRelation does not have, so a caller that builds a
%   pipeline (an importer) calls this; did2.validate.pipelineMembers runs it
%   over a batch. did2.build.pipelineMembership builds the relations in this
%   shape.
%
%   PIPELINE and each of DOCS are built document structs (did2.build.*) or
%   did2.document objects.
%
%   See also did2.build.pipelineMembership, did2.validate.pipelineMembers,
%   did2.build.directedRelation.

arguments
    pipeline
    docs
end

pipeline = asStruct(pipeline);
if ~isSoftwareEntity(pipeline)
    error('did2:build:badOption', ...
        'checkPipelineMembers: PIPELINE must be a `software` entity.');
end
pid = char(pipeline.base.id);
if ~iscell(docs)
    if isstruct(docs); docs = num2cell(docs(:)'); else; docs = {docs}; end
end
bodies = cellfun(@asStruct, docs, 'UniformOutput', false);

byId = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    b = bodies{k};
    if isstruct(b) && isfield(b, 'base') && isfield(b.base, 'id')
        byId(char(b.base.id)) = k;
    end
end

orders = [];
relIds = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isMemberOf(b) || ~isequal(edgeValues(b, 'parent_id'), {pid})
        continue;
    end
    rid = char(b.base.id);
    child = edgeValues(b, 'child_id');
    if numel(child) ~= 1
        error('did2:build:ruleViolated', ...
            ['pipeline %s: `member of` relation %s names %d child_id edge(s), ' ...
             'not one program.'], pid, rid, numel(child));
    end
    if ~isKey(byId, child{1})
        error('did2:build:ruleViolated', ...
            ['pipeline %s: `member of` relation %s names child %s, which is not ' ...
             'among the documents given, so it cannot be checked to be a ' ...
             '`software` entity.'], pid, rid, child{1});
    end
    if ~isSoftwareEntity(bodies{byId(child{1})})
        error('did2:build:ruleViolated', ...
            ['pipeline %s: `member of` relation %s names child %s, which is not ' ...
             'a `software` entity; a pipeline''s members are its programs ' ...
             '([pipeline is a software entity]).'], pid, rid, child{1});
    end
    o = orderOf(b);
    if isempty(o) || o < 0 || o ~= round(o)
        error('did2:build:ruleViolated', ...
            ['pipeline %s: `member of` relation %s has no order; a pipeline''s ' ...
             'programs are ordered from 0 ([pipeline order counts from 0]).'], pid, rid);
    end
    orders(end+1) = o; %#ok<AGROW>
    relIds{end+1} = rid; %#ok<AGROW>
end
if isempty(orders)
    return;
end
if ~isequal(sort(orders), 0:numel(orders)-1)
    error('did2:build:ruleViolated', ...
        ['pipeline %s: its %d program(s) have orders [%s]; they must be ' ...
         '0..%d, each once ([pipeline order counts from 0]). Relations: %s.'], ...
        pid, numel(orders), num2str(sort(orders)), numel(orders) - 1, ...
        strjoin(relIds, ', '));
end
end

function s = asStruct(d)
if isa(d, 'did2.document')
    s = d.documentProperties;
else
    s = d;
end
end

function tf = isSoftwareEntity(b)
tf = false;
if ~isstruct(b) || ~isfield(b, 'entity') || ~isstruct(b.entity) ...
        || ~isfield(b.entity, 'type') || ~isfield(b, 'base') || ~isfield(b.base, 'id')
    return;
end
tf = strcmp(did2.build.vocabularyHandle('entity_type', b.entity.type), 'software');
end

function tf = isMemberOf(b)
tf = false;
if ~isstruct(b) || ~isfield(b, 'directed_relation') || ~isstruct(b.directed_relation) ...
        || ~isfield(b.directed_relation, 'relation') || ~isfield(b, 'base')
    return;
end
tf = strcmp(did2.build.vocabularyHandle('relation', b.directed_relation.relation), 'member_of');
end

function o = orderOf(b)
o = [];
if isfield(b.directed_relation, 'order') && isnumeric(b.directed_relation.order) ...
        && isscalar(b.directed_relation.order)
    o = double(b.directed_relation.order);
end
end

function v = edgeValues(b, name)
v = {};
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
if iscell(deps); items = deps(:)'; else; items = num2cell(deps(:)'); end
for k = 1:numel(items)
    d = items{k};
    if ~isstruct(d) || ~strcmp(char(d.name), name); continue; end
    x = '';
    if isfield(d, 'document_id') && ~isempty(d.document_id); x = char(d.document_id);
    elseif isfield(d, 'value') && ~isempty(d.value); x = char(d.value); end
    if ~isempty(x); v{end+1} = x; end %#ok<AGROW>
end
end
