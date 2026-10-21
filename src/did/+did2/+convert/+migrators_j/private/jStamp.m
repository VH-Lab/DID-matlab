function ts = jStamp(preBody)
%JSTAMP The creation timestamp a document built from PREBODY carries: the v1
%   `base.datestamp` (or `creation_timestamp`), else the sentinel jBase states
%   ('2024-01-01T00:00:00.000Z': base.creation_timestamp is required and a v1
%   document may carry none).

ts = '';
if isstruct(preBody) && isfield(preBody, 'base') && isstruct(preBody.base) ...
        && isscalar(preBody.base)
    for f = {'datestamp', 'creation_timestamp'}
        if isfield(preBody.base, f{1}) && ~isempty(preBody.base.(f{1})) ...
                && (ischar(preBody.base.(f{1})) || isstring(preBody.base.(f{1})))
            ts = char(preBody.base.(f{1}));
            return;
        end
    end
end
if isempty(ts)
    ts = '2024-01-01T00:00:00.000Z';
end
end
