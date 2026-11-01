function [body, collision, unplaced] = jRawAccount(preBody, blocks, edges)
%JRAWACCOUNT The raw v1 read of an acquisition-system family document: its
%   identity, and every v1 field its migrator does not read.
%
%   [BODY, COLLISION, UNPLACED] = jRawAccount(PREBODY, BLOCKS, EDGES).
%   PREBODY is the RAW v1 document (did2.convert.rawV1Classes: no
%   universalRenames). BLOCKS is a struct: one field per property block the
%   migrator reads, holding the cellstr of that block's fields it reads (the
%   NDI template's fields at the locked NDI-matlab `main`, 3cb19a8, as the
%   writer sets them). EDGES is a cellstr of regular expressions: the
%   depends_on names the migrator reads.
%
%   BODY is PREBODY, except that an `ndi_document` block is read as `base`
%   (Decided by Jess Haley, 2026-10-31 [ndi_document read as base], did-schema
%   did_v2_go_forward_class_audit.md): a pre-2023 document whose only identity
%   block is the legacy `ndi_document` gets a `base` holding the four fields
%   did2.convert.v1read.readBase reads from it, a block BESIDE `base` fills
%   the four `base` leaves empty, and the legacy block is removed (its other
%   fields, and a field it and `base` state differently, come back in
%   UNPLACED); and a depends_on that jsondecode gave as a cell (entries with
%   different keys) is read into a struct array of {name, value}. BODY is the
%   migrator's reading copy; a carry or passthrough returns PREBODY.
%
%   COLLISION lists the rename-era clashes (what universalRenames would have
%   discarded). They are fields outside the template, carried under carry-100
%   like UNPLACED (Decided by Jess Haley, 2026-11-01 [rename clashes are
%   malformed], did-schema did_v2_go_forward_class_audit.md):
%     - a depends_on entry's `version`, or a second, different id;
%     - a camelCase field of a read block beside its snake_case twin, holding a
%       different value (an equal twin restates it and is neither).
%
%   UNPLACED lists the v1 fields no part of the migrator reads, each as a path
%   (the caller carries the document whole as v1; there is no register row for
%   these yet):
%     - a top-level block other than document_class, base, depends_on and
%       BLOCKS, when it holds anything;
%     - a field of a read block outside its list, when it holds anything;
%     - a `base` field outside base.json's four (or a legacy identity field
%       outside them, `ndi_document.<field>`), when it holds anything; a stale
%       `base.schema_version` is the stamp, not a field;
%     - `ndi_document.<field>` for one of the four that the block beside
%       `base` and `base` state with different non-empty values;
%     - a depends_on entry whose name EDGES does not match and which names a
%       document.
%   An EMPTY value is never unplaced: nothing is lost by not writing it
%   ([writer default is not set]).
%
%   A body that a batch pass hands back to a migrator after pass 1 (stamped
%   did_v2: did2.convert.resolveClockAlignment re-runs syncgraph and syncrule
%   with transient stamps) was accounted for in pass 1: COLLISION and UNPLACED
%   are empty for it.
%
%   Decided by Jess Haley, 2026-10-26 [migrators read raw v1] (did-schema
%   V_eta_go_forward_class_audit.md): a migrator reads v1 exactly as v1 defines
%   it and accounts for every v1 field.
%
%   See also jRawBody, did2.convert.v1read.readBase,
%            did2.convert.v1read.readDependsOn, did2.convert.rawV1Classes.

body = preBody;
collision = {};
unplaced = {};

b = did2.convert.v1read.readBase(preBody);
if strcmp(b.source, 'ndi_document') && any(strcmp(b.present, 'id'))
    base = struct();
    for f = {'id', 'session_id', 'name', 'datestamp'}
        if any(strcmp(b.present, f{1}))
            base.(f{1}) = b.(f{1});
        end
    end
    body.base = base;
    body = rmfield(body, 'ndi_document');
elseif strcmp(b.source, 'base') && isfield(body, 'ndi_document')
    % [ndi_document read as base]: the block beside `base` fills what `base`
    % leaves empty (readBase); a conflict comes back in UNPLACED below
    for f = {'id', 'session_id', 'name', 'datestamp'}
        if any(strcmp(b.present, f{1})) && ~any(strcmp(b.conflict, ['ndi_document.' f{1}]))
            body.base.(f{1}) = b.(f{1});
        end
    end
    body = rmfield(body, 'ndi_document');
end

stamp = did2.convert.v1read.readStamp(preBody);
if stamp.is_v2
    return;     % a pass-1 body a batch pass re-runs: accounted for in pass 1
end

% --- identity --------------------------------------------------------------
% [ndi_document read as base]: the block beside `base` is `base`; what it
% states that `base` cannot hold is outside the template (carry-100)
unplaced = [unplaced, b.conflict];
lextra = fieldnames(b.legacy_extra);
for k = 1:numel(lextra)
    if ~isEmptyValue(b.legacy_extra.(lextra{k}))
        unplaced{end+1} = ['ndi_document.' lextra{k}]; %#ok<AGROW>
    end
end
extra = fieldnames(b.extra);
for k = 1:numel(extra)
    if strcmp(b.source, 'base') && strcmp(extra{k}, 'schema_version')
        continue;   % a stale stamp an early draft migrator wrote on base: the
                    % stamp (universalRenames moved it to document_class)
    end
    if ~isEmptyValue(b.extra.(extra{k}))
        unplaced{end+1} = [b.source '.' extra{k}]; %#ok<AGROW>
    end
end

% --- depends_on ------------------------------------------------------------
deps = did2.convert.v1read.readDependsOn(preBody);
if isfield(body, 'depends_on') && iscell(body.depends_on)
    % jsondecode's shape for entries with different keys: the migrators' edge
    % reads take a struct array, so the reading copy gets one (same names, same
    % ids, in order); nothing is emitted from it but the edges read by name
    body.depends_on = struct('name', {deps.name}, 'value', {deps.document_id});
end
for k = 1:numel(deps)
    nm = deps(k).name;
    if ~isempty(deps(k).version)
        collision{end+1} = sprintf('depends_on(%s).version', nm); %#ok<AGROW>
    end
    others = fieldnames(deps(k).other);
    for j = 1:numel(others)
        collision{end+1} = sprintf('depends_on(%s).%s', nm, others{j}); %#ok<AGROW>
    end
    known = ischar(nm) && any(cellfun(@(re) ~isempty(regexp(nm, re, 'once')), edges));
    if ~known && ~isempty(deps(k).document_id)
        unplaced{end+1} = sprintf('depends_on(%s)', char(nm)); %#ok<AGROW>
    end
end

% --- the property blocks -----------------------------------------------------
read = fieldnames(blocks);
top = setdiff(fieldnames(preBody), [{'document_class', 'base', 'depends_on', ...
    'ndi_document'}, read(:)'], 'stable');
for k = 1:numel(top)
    if ~isEmptyValue(preBody.(top{k}))
        unplaced{end+1} = top{k}; %#ok<AGROW>
    end
end
for k = 1:numel(read)
    name = read{k};
    if ~isfield(preBody, name) || isEmptyValue(preBody.(name))
        continue;
    end
    blk = preBody.(name);
    if ~isstruct(blk) || ~isscalar(blk)
        unplaced{end+1} = name; %#ok<AGROW>
        continue;
    end
    fields = blocks.(name);
    fns = fieldnames(blk);
    for j = 1:numel(fns)
        fn = fns{j};
        if any(strcmp(fn, fields))
            continue;
        end
        sc = snakeCase(fn);
        if ~strcmp(sc, fn) && isfield(blk, sc)
            if ~isequaln(blk.(sc), blk.(fn))
                collision{end+1} = [name '.' fn]; %#ok<AGROW>
            end
            % an equal twin restates the field the migrator reads
        elseif ~isEmptyValue(blk.(fn))
            unplaced{end+1} = [name '.' fn]; %#ok<AGROW>
        end
    end
end
end

% ===================== helpers =============================================

function tf = isEmptyValue(v)
%ISEMPTYVALUE Empty, or a struct whose every field is empty (a template
%   block the writer did not fill).
if isempty(v)
    tf = true;
elseif isstruct(v) && isscalar(v)
    tf = all(cellfun(@(f) isEmptyValue(v.(f)), fieldnames(v)));
else
    tf = false;
end
end

function out = snakeCase(name)
%SNAKECASE The snake_case spelling universalRenames gives a camelCase field
%   (its acronym-aware rule, copied: fooBar -> foo_bar, XMLParser ->
%   xml_parser), used only to find a twin.
name = char(name);
n = numel(name);
if n == 0
    out = name;
    return;
end
result = lower(name(1));
for k = 2:n
    c = name(k);
    if ~(c >= 'A' && c <= 'Z')
        result = [result, c]; %#ok<AGROW>
        continue;
    end
    prev = name(k-1);
    prevUpper = prev >= 'A' && prev <= 'Z';
    nextLower = (k < n) && (name(k+1) >= 'a' && name(k+1) <= 'z');
    if (~prevUpper || nextLower) && result(end) ~= '_'
        result = [result, '_', char(c + ('a' - 'A'))]; %#ok<AGROW>
    else
        result = [result, char(c + ('a' - 'A'))]; %#ok<AGROW>
    end
end
out = result;
end
