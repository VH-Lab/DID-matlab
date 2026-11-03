function tf = isV2Set(name)
%ISV2SET True when NAME names the v2 schema set: 'did_v2'.
%
%   Decided by Jess Haley, 2026-10-25 [schema set renamed did_v2] (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md): the set once named `V_eta`
%   is renamed `did_v2`, siblings first -- (1) accept both names, (2) rename
%   in did-schema, (3) drop `V_eta`. Step (3), Decided by Jess Haley,
%   2026-11-02 [V_eta not kept as an alias]: only 'did_v2' is accepted;
%   'V_eta' is not the v2 set any more (NDI-matlab stopped passing it first,
%   VH-Lab/NDI-matlab#1147).
%
%   See also did2.convert.targetStamp, did2.schema.cache.

tf = (ischar(name) || (isstring(name) && isscalar(name))) ...
    && strcmp(char(name), 'did_v2');
end
