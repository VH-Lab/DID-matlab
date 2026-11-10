function [subjectId, reason] = fitInputSubjects(action, arg, inputEdges)
%FITINPUTSUBJECTS What a fit's input is about, for a fit that names no subject.
%
%   Decided by Jess Haley, 2026-11-10 [a fit is about its input's subject]: a
%   v1 `fitcurve`, `vmspikefit` or `hartley_calc` with no element_id or
%   subject_id of its own is about what its input is about: follow the input
%   edge (`fit_example_data_id` for fitcurve, `fit_input_id` for vmspikefit,
%   hartley_calc's input edge `stimulus_presentation_id`) to that document and
%   take its subject; when the chain names none, the fit is carried as before
%   (carry-136, carry-137, carry-138). Never the session.
%
%   A per-document migrator cannot follow an edge, so did2.convert.v1_to_v2
%   indexes every v1 document of its batch here before the first migrator runs
%   (as did2.convert.elementSubjects).
%
%   did2.convert.fitInputSubjects('reset')         forget all
%   did2.convert.fitInputSubjects('load', BODIES)  index every v1 document in
%       the cell BODIES (structs or JSON text) by its base.id. Adds to what is
%       held; v1_to_v2 resets first.
%   [SUBJECTID, REASON] = did2.convert.fitInputSubjects('get', FITBODY, INPUTEDGES)
%       the subject the first non-empty edge among INPUTEDGES of the v1 fit
%       FITBODY leads to, or '' with REASON saying reason not:
%         'no_input'            no edge among INPUTEDGES names a document
%         'input_not_in_batch'  the document it names is not in the batch
%         'chain_names_none'    the chain ends at a document naming no subject
%         'session'             the chain ends at a session (never the subject)
%         'cycle'               the chain comes back to a document it passed
%
%   WHAT "ITS SUBJECT" IS, for the document an input edge names:
%     an `element` or a `subject`   that document itself: it becomes the
%                                   entity a statement is about (the
%                                   element migrator keeps its id), so a fit
%                                   of an element's data is about the element,
%                                   as a fit naming that element in its own
%                                   element_id is
%     a `session` (or
%       `session_in_a_dataset`)     none: never the session
%     any other document            the first non-empty of its own
%                                   `element_id` and `subject_id`, the edges
%                                   every migrator reads a statement's subject
%                                   from (jSubjectOf); when it has neither and
%                                   is itself a fit, that fit's own input, and
%                                   so on (the chain)
%   A subject id the chain reaches that names a session in the batch is also
%   'session'.
%
%   See also did2.convert.elementSubjects, did2.convert.v1_to_v2.

arguments
    action (1,:) char {mustBeMember(action, {'reset', 'load', 'get'})}
    arg = []
    inputEdges = {}
end

persistent index
if isempty(index) || ~isa(index, 'containers.Map')
    index = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
subjectId = '';
reason = '';
switch action
    case 'reset'
        index = containers.Map('KeyType', 'char', 'ValueType', 'any');
    case 'load'
        bodies = arg;
        if isstruct(bodies); bodies = num2cell(bodies); end
        % Indexed only when the batch holds a fit that names no subject: the
        % index is read for nothing else, and a corpus batch is large.
        if ~any(cellfun(@isFitWithoutSubject, bodies))
            return;
        end
        for k = 1:numel(bodies)
            b = decoded(bodies{k});
            if isempty(b)
                continue;
            end
            [id, entry] = entryOf(b);
            if isempty(id) || isKey(index, id)
                continue;
            end
            index(id) = entry;
        end
    case 'get'
        if ischar(inputEdges); inputEdges = {inputEdges}; end
        first = firstEdge(arg, inputEdges);
        if isempty(first)
            reason = 'no_input';
            return;
        end
        [subjectId, reason] = follow(index, first, {});
end
end

function [subjectId, reason] = follow(index, id, visited)
subjectId = '';
if any(strcmp(visited, id))
    reason = 'cycle';
    return;
end
if ~isKey(index, id)
    if isempty(visited)
        reason = 'input_not_in_batch';
    else
        reason = 'chain_names_none';
    end
    return;
end
e = index(id);
visited{end+1} = id;
if e.is_session
    reason = 'session';
    return;
end
if e.is_entity
    subjectId = id;
    reason = '';
    return;
end
if ~isempty(e.subject)
    if isKey(index, e.subject)
        target = index(e.subject);   % a Map value is indexed one level at a time
        if target.is_session
            reason = 'session';
            return;
        end
    end
    subjectId = e.subject;
    reason = '';
    return;
end
if isempty(e.inputs)
    reason = 'chain_names_none';
    return;
end
[subjectId, reason] = follow(index, e.inputs{1}, visited);
end

function [id, entry] = entryOf(b)
id = '';
entry = struct();
if ~(isstruct(b) && isscalar(b) && isfield(b, 'base') && isstruct(b.base) ...
        && isfield(b.base, 'id') && ~isempty(b.base.id))
    return;
end
cls = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cls = char(b.document_class.class_name);
end
id = char(b.base.id);
entry.class_name = cls;
entry.is_entity = any(strcmp(cls, {'element', 'subject'}));
entry.is_session = any(strcmp(cls, {'session', 'session_in_a_dataset'}));
entry.subject = firstEdge(b, {'element_id', 'subject_id'});
inputs = {};
edges = fitInputEdges(cls);
for k = 1:numel(edges)
    v = firstEdge(b, edges(k));
    if ~isempty(v); inputs{end+1} = v; end %#ok<AGROW>
end
entry.inputs = inputs;
end

function b = decoded(b)
if ischar(b) || (isstring(b) && isscalar(b))
    try
        b = jsondecode(char(b));
    catch
        b = [];
    end
end
if ~(isstruct(b) && isscalar(b))
    b = [];
end
end

function tf = isFitWithoutSubject(b)
tf = false;
if ischar(b) || (isstring(b) && isscalar(b))
    if ~(contains(b, '"fitcurve"') || contains(b, '"vmspikefit"') ...
            || contains(b, '"hartley_calc"'))
        return;
    end
    b = decoded(b);
end
if ~(isstruct(b) && isscalar(b) && isfield(b, 'document_class') ...
        && isstruct(b.document_class) && isfield(b.document_class, 'class_name'))
    return;
end
cls = char(b.document_class.class_name);
tf = ~isempty(fitInputEdges(cls)) ...
    && isempty(firstEdge(b, {'element_id', 'subject_id'}));
end

function edges = fitInputEdges(cls)
% the input edges of the three fit classes the decision names (their
% migrators' INPUTEDGES), followed when a fit in the chain names no subject
switch cls
    case 'fitcurve'
        edges = {'fit_example_data_id', 'fit_input_id'};
    case 'vmspikefit'
        edges = {'fit_input_id'};
    case 'hartley_calc'
        edges = {'stimulus_presentation_id'};
    otherwise
        edges = {};
end
end

function v = firstEdge(b, names)
v = '';
if ~isstruct(b) || ~isfield(b, 'depends_on') || isempty(b.depends_on)
    return;
end
deps = b.depends_on;
if isstruct(deps); deps = num2cell(deps); end
if ~iscell(deps); return; end
for n = 1:numel(names)
    for k = 1:numel(deps)
        d = deps{k};
        if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), names{n})
            continue;
        end
        for key = {'value', 'document_id', 'id'}
            if isfield(d, key{1}) && ~isempty(d.(key{1}))
                v = char(d.(key{1}));
                return;
            end
        end
    end
end
end
