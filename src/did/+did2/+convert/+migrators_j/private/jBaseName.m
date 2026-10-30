function name = jBaseName(preBody)
%JBASENAME The v1 `base.name` a document that becomes an `entity` writes to
%   `entity.name`, or '' when it writes nothing.
%
%   NAME = jBaseName(PREBODY). PREBODY is the raw v1 document; its identity
%   block is read by did2.convert.v1read.readBase (a pre-2023 `ndi_document`
%   block too). Decided by Jess Haley, 2026-10-27 [v1 name is the entity name]
%   (did-schema V_eta_go_forward_class_audit.md): a non-empty v1 `base.name` of
%   a document that becomes an entity is written to `entity.name`, whether or
%   not it equals the local identifier; an empty one writes nothing, and
%   nothing is carried for it. The value is written as v1 wrote it (no
%   trimming), so the round trip reads it back exactly. A name that is not
%   text writes nothing, and the round trip reports it lost.
%
%   Callers: did2.convert.migrators_j.subject, .subject_group, .session,
%   .dataset_remote; each inverse (did2.convert.roundtrip.<class>) rebuilds
%   base.name from entity.name, '' when the entity has none. .element reads it
%   only to carry an element whose base.name is not empty: since [element name
%   and reference stored apart] (2026-10-29) an element's entity.name is its
%   element.name.

name = '';
b = did2.convert.v1read.readBase(preBody);
v = b.name;
if ischar(v) && ~isempty(v)
    name = v;
elseif isstring(v) && isscalar(v) && strlength(v) > 0
    name = char(v);
end
end
