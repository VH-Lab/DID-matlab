function b = readBase(body)
%READBASE The identity block of a RAW v1 document, nothing dropped.
%
%   B = did2.convert.v1read.readBase(BODY) reads the v1 `base` block, as NDI's
%   base.json declares it at the locked NDI-matlab `main` (3cb19a8):
%
%       id, session_id, name, datestamp
%
%   and returns a struct with
%
%     source      'base', 'ndi_document' (a pre-2023 document whose only
%                 identity block is the legacy one), or '' (neither)
%     id, session_id, name, datestamp
%                 as text ('' when the block does not state the field; a value
%                 that is not text is returned as given)
%     present     cellstr: which of the four fields the block states
%     extra       a struct of every field of the block OUTSIDE those four (a
%                 stale `schema_version`, or the 2019 `ndi_document` fields
%                 `experiment_id`, `type`, `database_version`, ...)
%     legacy      the `ndi_document` block when it is present BESIDE `base`
%                 (struct() otherwise)
%
%   A legacy `ndi_document` block is read for the same four names only: its
%   2019 shapes spell identity differently (`experiment_id`, `document_id`),
%   and those fields come back in `extra`, unread, for the caller to place or
%   carry. Nothing is renamed or moved; universalRenames' wholesale move of
%   the block into `base` is not repeated here.
%
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): the `base` block is read by a shared
%   helper each migrator calls on the raw v1 document.
%
%   See also did2.convert.v1read.readDependsOn, did2.convert.v1read.readApp,
%            did2.convert.v1read.readStamp.

fields = {'id', 'session_id', 'name', 'datestamp'};
b = struct('source', '', 'id', '', 'session_id', '', 'name', '', ...
    'datestamp', '', 'present', {{}}, 'extra', struct(), 'legacy', struct());
if ~isstruct(body) || ~isscalar(body)
    return;
end
block = [];
if isfield(body, 'base') && isstruct(body.base) && isscalar(body.base)
    block = body.base;
    b.source = 'base';
    if isfield(body, 'ndi_document') && isstruct(body.ndi_document) ...
            && isscalar(body.ndi_document)
        b.legacy = body.ndi_document;
    end
elseif isfield(body, 'ndi_document') && isstruct(body.ndi_document) ...
        && isscalar(body.ndi_document)
    block = body.ndi_document;
    b.source = 'ndi_document';
end
if isempty(block)
    return;
end
fns = fieldnames(block);
for k = 1:numel(fns)
    f = fns{k};
    if any(strcmp(f, fields))
        b.(f) = textOf(block.(f));
        b.present{end+1} = f;
    else
        b.extra.(f) = block.(f);
    end
end
end
