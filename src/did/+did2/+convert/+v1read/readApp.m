function a = readApp(body)
%READAPP The `app` block of a RAW v1 document, keeping every spelling.
%
%   A = did2.convert.v1read.readApp(BODY) reads the v1 `app` block, as NDI's
%   app.json declares it at the locked NDI-matlab `main` (3cb19a8):
%
%       name, version, url, os, os_version, interpreter, interpreter_version
%
%   and returns a struct with
%
%     present     true when BODY carries an `app` block
%     name, version, url, os, os_version, interpreter, interpreter_version
%                 as text ('' when the block does not state the field)
%     app_name, app_version
%                 the V2 spellings, read as given when a body carries them
%                 ('' otherwise). A raw v1 body never does; they are read so
%                 that a body which holds BOTH spellings loses neither.
%     conflicts   cellstr: 'name' and/or 'version' when both spellings are
%                 present, non-empty and DIFFERENT. Both values are kept above;
%                 the caller decides (or carries the document). universalRenames
%                 kept `app_name` and dropped `name` here (carry-100).
%     extra       a struct of every field outside the nine above
%
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): the `app` block is read by a shared
%   helper each migrator calls on the raw v1 document, not renamed by a pass.
%
%   See also did2.convert.v1read.readBase, did2.convert.v1read.readDependsOn,
%            did2.convert.v1read.readStamp.

template = {'name', 'version', 'url', 'os', 'os_version', 'interpreter', ...
    'interpreter_version'};
renamed = {'app_name', 'app_version'};
a = struct('present', false);
for k = 1:numel(template)
    a.(template{k}) = '';
end
for k = 1:numel(renamed)
    a.(renamed{k}) = '';
end
a.conflicts = {};
a.extra = struct();
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'app') ...
        || ~isstruct(body.app) || ~isscalar(body.app)
    return;
end
a.present = true;
block = body.app;
fns = fieldnames(block);
for k = 1:numel(fns)
    f = fns{k};
    if any(strcmp(f, template)) || any(strcmp(f, renamed))
        a.(f) = textOf(block.(f));
    else
        a.extra.(f) = block.(f);
    end
end
pairs = {'name', 'app_name'; 'version', 'app_version'};
for p = 1:size(pairs, 1)
    v1 = a.(pairs{p, 1});
    v2 = a.(pairs{p, 2});
    if ~isempty(v1) && ~isempty(v2) && ~isequal(v1, v2)
        a.conflicts{end+1} = pairs{p, 1};
    end
end
end
