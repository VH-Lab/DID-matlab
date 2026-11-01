function body = jRawBody(preBody, className)
%JRAWBODY The raw v1 document a switched migrator reads, its identity read
%   through did2.convert.v1read.readBase.
%
%   BODY = jRawBody(PREBODY, CLASSNAME). PREBODY is the RAW v1 document
%   (did2.convert.rawV1Classes: no universalRenames). BODY is PREBODY itself
%   when it has a `base` block. A pre-2023 document whose only identity block
%   is the legacy `ndi_document` gets a `base` holding the four fields
%   readBase reads from it (id, session_id, name, datestamp), and the legacy
%   block is removed, so the migrator's builders (jOpts, jSid, jStamp) find the
%   identity where they read it. That is what universalRenames' wholesale move
%   gave the migrator before the switch; the legacy block's other fields were
%   read by no migrator then either (readBase returns them in `extra`).
%
%   A document whose identity block states no `id` field raises
%   did2:convert:<CLASSNAME>:noId, which v1_to_v2 quarantines -- as the
%   migrator's read of `preBody.base.id` did before the switch.
%
%   A migrator that carries the document returns PREBODY, never BODY: the carry
%   is the untouched v1 source ([migrators read raw v1]).
%
%   See also did2.convert.v1read.readBase, did2.convert.rawV1Classes.

b = did2.convert.v1read.readBase(preBody);
if isempty(b.source) || ~any(strcmp(b.present, 'id'))
    error(['did2:convert:' className ':noId'], ...
        'A v1 %s with no base.id cannot keep its id.', className);
end
body = preBody;
if strcmp(b.source, 'ndi_document')
    base = struct();
    for f = {'id', 'session_id', 'name', 'datestamp'}
        if any(strcmp(b.present, f{1}))
            base.(f{1}) = b.(f{1});
        end
    end
    body.base = base;
    body = rmfield(body, 'ndi_document');
elseif strcmp(b.source, 'base') && isfield(body, 'ndi_document')
    % Decided by Jess Haley, 2026-10-31 [ndi_document read as base]: the block
    % beside `base` fills what `base` leaves empty; a field the two state
    % differently, and the block's other fields, are the caller's to account
    % for (jRawAccount: carry-100)
    for f = {'id', 'session_id', 'name', 'datestamp'}
        if any(strcmp(b.present, f{1})) && ~any(strcmp(b.conflict, ['ndi_document.' f{1}]))
            body.base.(f{1}) = b.(f{1});
        end
    end
    body = rmfield(body, 'ndi_document');
end
end
