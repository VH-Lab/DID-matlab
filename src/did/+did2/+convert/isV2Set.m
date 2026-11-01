function tf = isV2Set(name)
%ISV2SET True when NAME names the V2 schema set: 'did_v2', or its earlier name
%   'V_eta'.
%
%   Decided by Jess Haley, 2026-10-25 [schema set renamed did_v2] (did-schema
%   V_eta_go_forward_class_audit.md): the set now named `V_eta` is renamed
%   `did_v2`, siblings first -- (1) accept both names, (2) rename in did-schema,
%   (3) drop `V_eta`. Step (1): every `TargetVersion` check and every
%   reader of the set name accepts both. Step (2), with [V2 database file
%   renamed] (Decided by Jess Haley, 2026-11-01): every `TargetVersion`
%   default is 'did_v2'; 'V_eta' is still accepted on input here. Do not
%   drop 'V_eta' here until NDI-matlab writes 'did_v2' everywhere.
%
%   See also did2.convert.targetStamp, did2.schema.cache.

tf = (ischar(name) || (isstring(name) && isscalar(name))) ...
    && any(strcmp(char(name), {'did_v2', 'V_eta'}));
end
