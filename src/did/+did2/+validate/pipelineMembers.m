function report = pipelineMembers(docs)
%PIPELINEMEMBERS Batch check of the pipeline rule: a software parent's members.
%
%   REPORT = did2.validate.pipelineMembers(DOCS) finds every `member of`
%   (RO:0002350) directed_relation in DOCS whose parent is a `software` entity
%   in DOCS (a pipeline), and runs did2.build.checkPipelineMembers on each such
%   pipeline with the whole batch: its members must be `software` entities,
%   each relation must carry an order, and the orders must be 0..N-1, each once
%   (did-schema did_v2_go_forward_class_audit.md: [pipeline is a software
%   entity], Jess Haley 2026-11-06; [pipeline order counts from 0] and
%   [pipeline steps use member of], Jess Haley 2026-11-12). It COUNTS; it
%   quarantines nothing. Denominator first:
%     docs_inspected, docs_unreadable  every document handed in
%     member_of_relations              `member of` directed_relations found
%     parent_not_in_batch              of those, the parent_id names no document
%                                      here (NOT CHECKED: not a pass, not a fail)
%     software_parent_relations        of those, the parent is a software entity
%     other_parent_relations           of those, the parent is something else
%                                      (a Group): not this rule
%     pipelines_inspected              distinct software parents
%     pipelines_child_not_in_batch     of those, a member names a child that is
%                                      not here (NOT CHECKED)
%     pipelines_checked                pipelines actually run through the rule
%     violations                       of those, refused by the rule
%     violation_examples               first 20 {id (the pipeline), message}
%
%   DOCS: did2.document objects or body structs (cell or array).
%
%   See also did2.build.checkPipelineMembers, did2.build.pipelineMembership.

report = struct('docs_inspected', 0, 'docs_unreadable', 0, ...
    'member_of_relations', 0, 'parent_not_in_batch', 0, ...
    'software_parent_relations', 0, 'other_parent_relations', 0, ...
    'pipelines_inspected', 0, 'pipelines_child_not_in_batch', 0, ...
    'pipelines_checked', 0, 'violations', 0, ...
    'violation_examples', struct('id', {}, 'message', {}));
[bodies, unreadable] = vBodies(docs);
report.docs_inspected = numel(bodies) + unreadable;
report.docs_unreadable = unreadable;

byId = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(bodies)
    b = bodies{k};
    if isstruct(b) && isfield(b, 'base') && isfield(b.base, 'id')
        byId(char(b.base.id)) = k;
    end
end

pipelines = {};                                   % software parent ids, first seen first
childMissing = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for k = 1:numel(bodies)
    b = bodies{k};
    if ~isMemberOf(b); continue; end
    report.member_of_relations = report.member_of_relations + 1;
    parent = edgeValues(b, 'parent_id');
    if numel(parent) ~= 1 || ~isKey(byId, parent{1})
        report.parent_not_in_batch = report.parent_not_in_batch + 1;
        continue;
    end
    if ~isSoftwareEntity(bodies{byId(parent{1})})
        report.other_parent_relations = report.other_parent_relations + 1;
        continue;
    end
    report.software_parent_relations = report.software_parent_relations + 1;
    p = parent{1};
    if ~isKey(childMissing, p)
        pipelines{end+1} = p; %#ok<AGROW>
        childMissing(p) = false;
    end
    child = edgeValues(b, 'child_id');
    if isscalar(child) && ~isKey(byId, child{1})
        childMissing(p) = true;
    end
end
report.pipelines_inspected = numel(pipelines);

for k = 1:numel(pipelines)
    p = pipelines{k};
    if childMissing(p)
        report.pipelines_child_not_in_batch = report.pipelines_child_not_in_batch + 1;
        continue;
    end
    report.pipelines_checked = report.pipelines_checked + 1;
    try
        did2.build.checkPipelineMembers(bodies{byId(p)}, bodies);
    catch err
        report.violations = report.violations + 1;
        if numel(report.violation_examples) < 20
            report.violation_examples(end+1) = struct('id', p, 'message', err.message);
        end
    end
end
end

function tf = isSoftwareEntity(b)
tf = false;
if ~isstruct(b) || ~isfield(b, 'entity') || ~isstruct(b.entity) || ~isfield(b.entity, 'type')
    return;
end
tf = strcmp(did2.build.vocabularyHandle('entity_type', b.entity.type), 'software');
end

function tf = isMemberOf(b)
tf = false;
if ~isstruct(b) || ~isfield(b, 'directed_relation') || ~isstruct(b.directed_relation) ...
        || ~isfield(b.directed_relation, 'relation')
    return;
end
tf = strcmp(did2.build.vocabularyHandle('relation', b.directed_relation.relation), 'member_of');
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
