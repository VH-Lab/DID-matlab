function sid = jSid(preBody)
%JSID The v1 session id of PREBODY: `base.session_id`, or its `session_id`
%   edge when the body already carries the edge shape. '' when it has neither.

sid = '';
if ~isstruct(preBody)
    return;
end
if isfield(preBody, 'base') && isstruct(preBody.base) && isscalar(preBody.base) ...
        && isfield(preBody.base, 'session_id') && ~isempty(preBody.base.session_id)
    sid = char(preBody.base.session_id);
    return;
end
try
    sid = char(did2.schema.cache.sessionIdOf(preBody));
catch
    sid = '';
end
end
