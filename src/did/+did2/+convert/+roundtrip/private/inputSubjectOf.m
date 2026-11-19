function subjectId = inputSubjectOf(ctx, id, visited)
%INPUTSUBJECTOF What the document ID in the final batch CTX is about, read the
%   way did2.convert.fitInputSubjects read it from the v1 batch, or '' when it
%   names nothing (or CTX does not hold it).
%
%   SUBJECTID = inputSubjectOf(CTX, ID). The inverse of a fit that named no
%   subject of its own reads, from the batch, the subject its input leads to
%   ([a fit is about its input's subject], Decided by Jess Haley, 2026-11-10):
%     a document carried as v1   as fitInputSubjects reads it: an `element` or
%                                `subject` is itself, a session is nothing,
%                                otherwise its `element_id` / `subject_id`,
%                                else (a fit) its own input
%     an `entity`                itself, unless its type is session or dataset
%     any other v2 document      its `entity_id` (a statement); for a v2 fit
%                                that is already the subject its own chain
%                                gave it
%   Never the session.
%
%   See also did2.convert.fitInputSubjects, modelFitInverse.

if nargin < 3
    visited = {};
end
subjectId = '';
id = char(id);
if isempty(ctx) || isempty(id) || any(strcmp(visited, id))
    return;
end
visited{end+1} = id;
b = ctxDoc(ctx, id);
if isempty(b)
    return;
end
cls = classNameOf(b);
if did2.schema.isV1Stamp(b, 'Explicit', true)
    if any(strcmp(cls, {'session', 'session_in_a_dataset'}))
        return;
    end
    if any(strcmp(cls, {'element', 'subject'}))
        subjectId = id;
        return;
    end
    for nm = {'element_id', 'subject_id'}
        s = edgeIds(b, nm{1});
        if ~isempty(s)
            if ~isSession(ctx, s{1})
                subjectId = s{1};
            end
            return;
        end
    end
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
    for k = 1:numel(edges)
        s = edgeIds(b, edges{k});
        if ~isempty(s)
            subjectId = inputSubjectOf(ctx, s{1}, visited);
            return;
        end
    end
    return;
end
if strcmp(cls, 'entity')
    if ~isEntityOfType(b, 'session') && ~isEntityOfType(b, 'dataset')
        subjectId = id;
    end
    return;
end
s = edgeIds(b, 'entity_id');
if ~isempty(s) && ~isSession(ctx, s{1})
    subjectId = s{1};
end
end

function tf = isSession(ctx, id)
tf = false;
b = ctxDoc(ctx, id);
if isempty(b)
    return;
end
tf = any(strcmp(classNameOf(b), {'session', 'session_in_a_dataset'})) ...
    || isEntityOfType(b, 'session') || isEntityOfType(b, 'dataset');
end
