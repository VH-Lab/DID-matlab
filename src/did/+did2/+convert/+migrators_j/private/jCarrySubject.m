function deps = jCarrySubject(preBody, srcNames)
%JCARRYSUBJECT Carry a source dependency forward as the V_eta `subject_id`.
%   srcNames is a cell of candidate did_v1 depends_on names, tried in order;
%   the first present one supplies the subject_id value. Defaults to
%   {'subject_id'}. The time_reference edge is attached separately by the
%   caller. In strict J the referent of `subject_id` is a `subject` (device,
%   organism, sample, ...); the element concept is dissolved (D2) and any
%   reconciliation of element/probe referents is the NDI second pass's job.
%
%   Shared helper for the Brainstorm-J (+migrators_j) split migrators.
if nargin < 2 || isempty(srcNames)
    srcNames = {'subject_id'};
end
subjectVal = '';
if isfield(preBody, 'depends_on') && isstruct(preBody.depends_on)
    for s = 1:numel(srcNames)
        for k = 1:numel(preBody.depends_on)
            d = preBody.depends_on(k);
            if isfield(d, 'name') && strcmp(d.name, srcNames{s})
                if isfield(d, 'value') && ~isempty(d.value)
                    subjectVal = d.value;
                elseif isfield(d, 'document_id') && ~isempty(d.document_id)
                    subjectVal = d.document_id;
                end
            end
        end
        if ~isempty(subjectVal); break; end
    end
end
deps = struct('name', 'subject_id', 'value', subjectVal);
end
