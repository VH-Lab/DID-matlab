function key = mintKey(body)
%MINTKEY The key a v1 source document's minted ids are derived from.
%
%   KEY = did2.convert.mintKey(BODY), BODY one v1 source document (a struct).
%   did2.convert.v1_to_v2 opens the did2.convert.mintId context for each source
%   with this key, so every document the migration mints for it gets an id
%   derived from (KEY, role, n): practice (b) of [migration reliability
%   practices] (Jess Haley, 2026-10-26, did-schema
%   V_eta_go_forward_class_audit.md), "a document the migration mints gets an
%   id derived from its v1 source id and its role, so two runs on the same
%   input are identical".
%
%   In order, the first that is non-empty:
%     1. `base.id`                       every document since 2023 (base.json)
%     2. the legacy identity block's id  a pre-2023 document whose identity is
%                                        only in `ndi_document`: its `id`
%                                        (did2.convert.v1read.readBase), else
%                                        the 2019 spellings `document_id`
%                                        (5d0b66d8f) or
%                                        `document_unique_reference` (4f1a2b801)
%     3. 'json:' + the document's JSON  a document stating no id at all: its
%                                        canonical JSON (jsonencode of the
%                                        decoded body), so the same input gives
%                                        the same key on every run
%   Only 3 can be '' (a body jsonencode cannot encode), and then mintId falls
%   back to random ids, as before.
%
%   Before this function the key was `base.id` alone, so a document with no
%   `base` block minted RANDOM ids on every run.
%
%   See also did2.convert.mintId, did2.convert.v1_to_v2.

key = '';
if ~isstruct(body) || ~isscalar(body)
    return;
end
key = textOf(fieldOf(body, 'base', 'id'));
if ~isempty(key)
    return;
end
try
    b = did2.convert.v1read.readBase(body);
    key = textOf(b.id);
    for f = {'document_id', 'document_unique_reference'}
        if isempty(key) && isstruct(b.extra) && isfield(b.extra, f{1})
            key = textOf(b.extra.(f{1}));
        end
    end
catch
    key = '';
end
if ~isempty(key)
    return;
end
try
    key = ['json:' jsonencode(body)];
catch
    key = '';
end
end

function v = fieldOf(s, block, name)
v = [];
if isfield(s, block) && isstruct(s.(block)) && isscalar(s.(block)) ...
        && isfield(s.(block), name)
    v = s.(block).(name);
end
end

function t = textOf(v)
t = '';
if ischar(v)
    t = strtrim(v);
elseif isstring(v) && isscalar(v)
    t = strtrim(char(v));
end
end
