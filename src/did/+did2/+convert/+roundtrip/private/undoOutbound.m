function v1 = undoOutbound(body)
%UNDOOUTBOUND A pass-1 body as v1 stated it: v1_to_v2's outbound renames
%   undone. The `session_id` edge goes back to base.session_id and
%   base.creation_timestamp back to base.datestamp; an empty `depends_on` left
%   by removing the edge is removed. Nothing else is changed.
%
%   See also did2.convert.roundtrip.epochfiles_ingested,
%            did2.convert.roundtrip.daqreader_mfdaq_epochdata_ingested.
v1 = body;
sid = char(did2.schema.cache.sessionIdOf(body));
if isfield(v1, 'depends_on') && isstruct(v1.depends_on)
    if ~isempty(v1.depends_on)
        keep = true(1, numel(v1.depends_on));
        for k = 1:numel(v1.depends_on)
            keep(k) = ~strcmp(char(v1.depends_on(k).name), 'session_id');
        end
        v1.depends_on = v1.depends_on(keep);
    end
    if isempty(v1.depends_on)
        v1 = rmfield(v1, 'depends_on');
    end
end
if isfield(v1, 'base') && isstruct(v1.base) && ~isfield(v1.base, 'session_id') && ~isempty(sid)
    v1.base.session_id = sid;
end
if isfield(v1, 'base') && isstruct(v1.base) && isfield(v1.base, 'creation_timestamp') ...
        && ~isfield(v1.base, 'datestamp')
    v1.base.datestamp = v1.base.creation_timestamp;
    v1.base = rmfield(v1.base, 'creation_timestamp');
end
end
