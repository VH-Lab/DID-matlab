function v2Body = identity(preBody)
%IDENTITY Default per-class migrator: post-universal-rename passthrough.
%
%   V2BODY = did2.convert.migrators.identity(PREBODY) returns PREBODY
%   unchanged. This is the default migrator used by
%   did2.convert.v1_to_v2 when no class-specific migrator is registered
%   under did2.convert.migrators.<class_name>. The universal renames
%   have already been applied by the dispatcher; this function exists
%   so the dispatcher always has a callable.
%
%   Note on naming: PLAN.md §9.6 (sub-step 6a) labels this file
%   `_identity.m`, but a leading underscore is not a valid MATLAB
%   identifier, so the file is named `identity` here.

arguments
    preBody (1,1) struct
end
v2Body = preBody;
end
