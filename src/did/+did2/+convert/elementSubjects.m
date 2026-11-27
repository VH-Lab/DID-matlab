function [subjectId, found] = elementSubjects(action, arg)
%ELEMENTSUBJECTS The subject_id every v1 `element` in the batch names.
%
%   Decided by Jess Haley, 2026-10-27 [unit direct and subject rebuild from
%   the probe] (did-schema V_eta_go_forward_class_audit.md): "a v1
%   sorted-unit `element` with an `underlying_element_id` is written without
%   `direct` and `subject_id`; the round trip rebuilds `direct` as 0 and
%   `subject_id` as the underlying element's subject; a v1 unit whose values
%   differ is carried whole as malformed". NDI's writer gives a derived
%   element its underlying element's subject (ndi.element: a derived element
%   copies the subject of the element it is built on), so the unit's
%   subject_id follows from its probe's.
%
%   A per-document migrator cannot follow an edge, so did2.convert.v1_to_v2
%   indexes the subject of every v1 element in its batch before the first
%   migrator runs (as did2.convert.unitQualityLabels). migrators_j.element
%   compares a unit's subject_id with its probe's; roundtrip.element rebuilds
%   the unit's subject_id from it.
%
%   did2.convert.elementSubjects('reset')         forget all
%   did2.convert.elementSubjects('load', BODIES)  index every v1 `element`
%       in the cell BODIES (structs or JSON text) by its base.id: the value of
%       its `subject_id` edge ('' when the edge is empty). Adds to what is
%       held; v1_to_v2 resets first.
%   [SUBJECTID, FOUND] = did2.convert.elementSubjects('get', ELEMENTID)
%       the subject_id of the v1 element ELEMENTID; FOUND false (and '') when
%       no element of that id is in the batch. An id two elements in the batch
%       share with different subjects also reads FOUND false: the probe's
%       subject is then not one value.
%   S = did2.convert.elementSubjects('snapshot')  every element held with a
%       subject, as a struct array {element_id, subject_id} (an id two
%       elements share with different subjects is left out). did2.convert.
%       v1_to_v2 hands it on in its result (`element_subjects`), because a
%       later did2.convert.v1_to_v2 call (a batch pass re-folding minted
%       bodies) resets this index to its own input: Decided by Jess Haley,
%       2026-11-26 [no observes relation in v2] (did-schema
%       docs/plans/did_v2_standing_wiring_plan.md), no `observes` relation
%       carries a direct element's subject past pass 1, and
%       did2.convert.resolveEpochProbemap compares a stimulator row's subject
%       with it.
%   M = did2.convert.elementSubjects('map', RESULT)  the same as a
%       containers.Map (element id -> subject id): RESULT.element_subjects
%       when a v1_to_v2 RESULT holds it, else the index now. Read by
%       did2.convert.resolveEpochProbemap and resolveDeferredBaths.
%
%   An element not in the batch is NOT a pass: migrators_j.element does not
%   drop a unit's subject_id it cannot check.
%
%   See also did2.convert.migrators_j.element, did2.convert.roundtrip.element,
%            did2.convert.unitQualityLabels.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'get', 'snapshot', 'map'})}
    arg = []
end

persistent index conflicted
if isempty(index) || ~isa(index, 'containers.Map')
    index = containers.Map('KeyType', 'char', 'ValueType', 'char');
end
if isempty(conflicted) || ~isa(conflicted, 'containers.Map')
    conflicted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
end
subjectId = '';
found = false;
switch action
    case 'reset'
        index = containers.Map('KeyType', 'char', 'ValueType', 'char');
        conflicted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        for k = 1:numel(bodies)
            b = bodies{k};
            if ischar(b) || (isstring(b) && isscalar(b))
                if ~contains(b, '"element"'); continue; end
                try
                    b = jsondecode(char(b));
                catch
                    continue;
                end
            end
            if ~isElement(b); continue; end
            id = char(b.base.id);
            subj = subjectOf(b);
            if isKey(index, id) && ~strcmp(index(id), subj)
                conflicted(id) = true;
            elseif ~isKey(index, id)
                index(id) = subj;
            end
        end
    case 'get'
        id = char(arg);
        if ~isempty(id) && isKey(index, id) && ~isKey(conflicted, id)
            subjectId = index(id);
            found = true;
        end
    case 'snapshot'
        ids = keys(index);
        keep = cellfun(@(i) ~isKey(conflicted, i) && ~isempty(index(i)), ids);
        ids = ids(keep);
        subjects = cellfun(@(i) index(i), ids, 'UniformOutput', false);
        subjectId = struct('element_id', ids, 'subject_id', subjects);
        found = true;
    case 'map'
        if isstruct(arg) && isfield(arg, 'element_subjects') && isstruct(arg.element_subjects)
            es = arg.element_subjects;
        else
            es = did2.convert.elementSubjects('snapshot');
        end
        subjectId = containers.Map('KeyType', 'char', 'ValueType', 'char');
        for k = 1:numel(es)
            id = char(es(k).element_id);
            if ~isempty(id) && ~isempty(es(k).subject_id)
                subjectId(id) = char(es(k).subject_id);
            end
        end
        found = true;
end
end

function tf = isElement(b)
tf = isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
    && isstruct(b.document_class) && isfield(b.document_class, 'class_name') ...
    && strcmp(char(b.document_class.class_name), 'element') ...
    && isfield(b, 'base') && isstruct(b.base) && isfield(b.base, 'id') ...
    && ~isempty(b.base.id);
end

function s = subjectOf(b)
s = '';
try
    deps = did2.convert.v1read.readDependsOn(b, 'Name', '^subject_id$');
catch
    return;
end
if ~isempty(deps) && ~isempty(deps(1).document_id)
    s = char(deps(1).document_id);
end
end
