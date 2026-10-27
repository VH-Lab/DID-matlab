function collision = jResponseRenameCollisions(preBody, twins)
%JRESPONSERENAMECOLLISIONS What universalRenames would have DISCARDED from a raw
%   v1 stimulus-response document (stimulus_response_scalar,
%   stimulus_response_scalar_parameters_basic).
%
%   COLLISION = jResponseRenameCollisions(PREBODY, TWINS). PREBODY is the RAW
%   v1 document (did2.convert.rawV1Classes). On the renamed path,
%   universalRenames' `dropped` output made v1_to_v2 carry such a document
%   whole before any migrator ran (carry-049, [renames carry is temporary],
%   Jess Haley, 2026-10-26). A switched migrator carries the same documents, so
%   the switch changes no outcome. COLLISION lists, for the parts of the
%   document these migrators read:
%     - a depends_on entry's non-empty `version`, or a second id key (`value`,
%       `id`, `document_id`) holding a different id
%       (did2.convert.v1read.readDependsOn: `version`, and the losing key in
%       `other`);
%     - an `ndi_document` block beside `base` (the pass discarded it);
%     - an `app` block stating both `name` and `app_name` (or `version` and
%       `app_version`) with different values (did2.convert.v1read.readApp);
%     - each row {BLOCK, CAMEL, SNAKE} of TWINS (an Nx3 cell) whose block holds
%       both spellings with different values (the pass kept SNAKE).
%   It does not repeat the pass's renames of a camelCase BLOCK name or class
%   name: NDI never wrote these classes that way, and the migrators do not
%   read such a block on either path.
%
%   See also did2.convert.universalRenames, did2.convert.v1read.readDependsOn.

collision = {};
try
    deps = did2.convert.v1read.readDependsOn(preBody);
catch
    % a depends_on that is not a list of entries: the renamed pass left it
    % alone, and so does this check
    deps = struct('name', {}, 'version', {}, 'other', {});
end
for k = 1:numel(deps)
    if ~isempty(deps(k).version)
        collision{end+1} = sprintf('depends_on(%s).version', deps(k).name); %#ok<AGROW>
    end
    others = fieldnames(deps(k).other);
    for j = 1:numel(others)
        if any(strcmp(others{j}, {'value', 'id', 'document_id'}))
            collision{end+1} = sprintf('depends_on(%s).%s', deps(k).name, others{j}); %#ok<AGROW>
        end
    end
end
if isfield(preBody, 'ndi_document') && isfield(preBody, 'base') ...
        && ~isempty(preBody.ndi_document)
    collision{end+1} = 'ndi_document';
end
a = did2.convert.v1read.readApp(preBody);
for k = 1:numel(a.conflicts)
    collision{end+1} = ['app.' a.conflicts{k}]; %#ok<AGROW>
end
for k = 1:size(twins, 1)
    blk = struct();
    if isfield(preBody, twins{k, 1}) && isstruct(preBody.(twins{k, 1})) ...
            && isscalar(preBody.(twins{k, 1}))
        blk = preBody.(twins{k, 1});
    end
    if isfield(blk, twins{k, 2}) && isfield(blk, twins{k, 3}) ...
            && ~isequaln(blk.(twins{k, 2}), blk.(twins{k, 3}))
        collision{end+1} = [twins{k, 1} '.' twins{k, 2}]; %#ok<AGROW>
    end
end
end
