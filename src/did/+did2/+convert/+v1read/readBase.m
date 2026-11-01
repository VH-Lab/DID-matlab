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
%     legacy_extra  a struct of every field of that block beside `base` OUTSIDE
%                 the four (`type`, `database_version`, the 2019 identity
%                 names, ...), for the caller to place or carry
%     conflict    cellstr of 'ndi_document.<field>' for each of the four that
%                 the block beside `base` and `base` both state, NON-EMPTY and
%                 DIFFERENT: one value cannot be read as the other
%
%   A legacy `ndi_document` block is read for the same four names only: its
%   2019 shapes spell identity differently (`experiment_id`, `document_id`),
%   and those fields come back in `extra` (or `legacy_extra`), unread, for the
%   caller to place or carry.
%
%   A BLOCK BESIDE `base` IS READ AS `base` (Decided by Jess Haley, 2026-10-31
%   [ndi_document read as base], did-schema did_v2_go_forward_class_audit.md:
%   "But yes. a makes sense", to "treat `ndi_document` as v1 `base`?"): each of
%   the four that `base` leaves empty is read from the block, and is then in
%   `present`. A field both state with the same value restates it. A field
%   both state with different non-empty values is a `conflict`: the caller
%   carries the document under carry-100 ([fields outside the template are
%   malformed]: the block is outside base.json, and the value the migrator
%   does not read would otherwise be lost).
%
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): the `base` block is read by a shared
%   helper each migrator calls on the raw v1 document.
%
%   See also did2.convert.v1read.readDependsOn, did2.convert.v1read.readApp,
%            did2.convert.v1read.readStamp.

fields = {'id', 'session_id', 'name', 'datestamp'};
b = struct('source', '', 'id', '', 'session_id', '', 'name', '', ...
    'datestamp', '', 'present', {{}}, 'extra', struct(), 'legacy', struct(), ...
    'legacy_extra', struct(), 'conflict', {{}});
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
% [ndi_document read as base]: the block beside `base` is read as `base`
if isempty(fieldnames(b.legacy)) || did2.convert.isEmptyBlock(b.legacy)
    return;
end
lfns = fieldnames(b.legacy);
for k = 1:numel(lfns)
    f = lfns{k};
    v = b.legacy.(f);
    if ~any(strcmp(f, fields))
        b.legacy_extra.(f) = v;
        continue;
    end
    if did2.convert.isEmptyBlock(v)
        continue;   % states nothing
    end
    lv = textOf(v);
    if ~any(strcmp(b.present, f)) || did2.convert.isEmptyBlock(b.(f))
        b.(f) = lv;
        if ~any(strcmp(b.present, f))
            b.present{end+1} = f;
        end
    elseif ~isequal(lv, b.(f))
        b.conflict{end+1} = ['ndi_document.' f];
    end
end
end
