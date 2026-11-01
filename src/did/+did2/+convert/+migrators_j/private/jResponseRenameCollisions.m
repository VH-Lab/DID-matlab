function collision = jResponseRenameCollisions(preBody, twins)
%JRESPONSERENAMECOLLISIONS The rename-era clashes of a raw v1 document: what
%   universalRenames would have DISCARDED. They are fields outside the
%   template, carried under carry-100 (Decided by Jess Haley, 2026-11-01
%   [rename clashes are malformed], did-schema did_v2_go_forward_class_audit.md).
%
%   COLLISION = jResponseRenameCollisions(PREBODY, TWINS). PREBODY is the RAW
%   v1 document (did2.convert.rawV1Classes). Such a document is carried
%   whole under carry-100 ([rename clashes are malformed]; the rename pass,
%   universalRenames, which carried it under its own temporary row, is
%   deleted). COLLISION lists, for the parts of the
%   document these migrators read:
%     - a depends_on entry's non-empty `version`, or a second id key (`value`,
%       `id`, `document_id`) holding a different id
%       (did2.convert.v1read.readDependsOn: `version`, and the losing key in
%       `other`);
%     - `ndi_document.<field>` of a block beside `base`: one of the four that
%       it and `base` state with different non-empty values, or a non-empty
%       field outside them ([ndi_document read as base]);
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
% an `ndi_document` block beside `base` is read as `base` (Decided by Jess
% Haley, 2026-10-31 [ndi_document read as base]): only a field it and `base`
% state differently, or one of its fields outside base.json's four, is listed
b = did2.convert.v1read.readBase(preBody);
collision = [collision, b.conflict];
lextra = fieldnames(b.legacy_extra);
for k = 1:numel(lextra)
    if ~did2.convert.isEmptyBlock(b.legacy_extra.(lextra{k}))
        collision{end+1} = ['ndi_document.' lextra{k}]; %#ok<AGROW>
    end
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
