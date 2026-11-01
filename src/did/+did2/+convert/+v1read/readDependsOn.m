function deps = readDependsOn(body, options)
%READDEPENDSON The `depends_on` entries of a RAW v1 document, nothing dropped.
%
%   DEPS = did2.convert.v1read.readDependsOn(BODY) reads BODY's top-level
%   `depends_on` as v1 writes it and returns a 1xN struct array, one element per
%   entry, in the document's order:
%
%     name         the dependency name (char)
%     document_id  the id the entry names (char; '' when it names none)
%     source_key   which key held that id: 'value' (NDI v1: ndi.document
%                  add_dependency_value_n / set_dependency_value), 'id' (the
%                  older {name, id, version} shape), 'document_id' (a body
%                  already renamed), or '' when no key held one
%     version      the entry's `version` as given ('' when it has none)
%     other        a struct of every OTHER key of the entry, and of any target
%                  key that lost the precedence below while holding a
%                  DIFFERENT value. Nothing is discarded: a caller that cannot
%                  place a key in `other` carries the document.
%
%   DEPS = ...readDependsOn(BODY, 'Name', PATTERN) keeps only the entries whose
%   name matches the regular expression PATTERN (e.g. '^subject_id(_\d+)?$').
%
%   PRECEDENCE when an entry holds more than one target key: `value` (the v1
%   spelling), then `id`, then `document_id`. A losing key with the SAME value
%   restates the winner and is not repeated in `other`.
%
%   WHY THIS EXISTS. Decided by Jess Haley, 2026-10-26 [migrators read raw v1]
%   (did-schema V_eta_go_forward_class_audit.md): what is truly shared --
%   `depends_on`, the `base` and `app` blocks, the stamp -- becomes reading
%   helpers each migrator calls on the raw v1 document, not a pass that rewrites
%   it. This replaces, for a switched class, universalRenames'
%   renameDependsOnEntries, which kept one key and DROPPED `version` and any
%   losing key (carry-100).
%
%   BODY is the raw v1 document (a struct, as jsondecode gives it). A
%   `depends_on` that is absent or empty gives a 1x0 struct array with the
%   fields above. A struct array and a cell array of structs (jsondecode's
%   shape for entries with different keys) are both read. Anything else is
%   an error (did2:convert:v1read:badDependsOn), which v1_to_v2 quarantines.
%
%   See also did2.convert.v1read.readBase, did2.convert.v1read.readApp,
%            did2.convert.v1read.readStamp.

arguments
    body
    options.Name (1,:) char = ''
end

deps = struct('name', {}, 'document_id', {}, 'source_key', {}, ...
    'version', {}, 'other', {});
deps = reshape(deps, 1, 0);
if ~isstruct(body) || ~isscalar(body) || ~isfield(body, 'depends_on')
    return;
end
raw = body.depends_on;
if isempty(raw)
    return;
end
if isstruct(raw)
    entries = num2cell(reshape(raw, 1, []));
elseif iscell(raw)
    entries = reshape(raw, 1, []);
else
    error('did2:convert:v1read:badDependsOn', ...
        'depends_on is a %s; v1 writes a list of {name, value} entries.', class(raw));
end

targetKeys = {'value', 'id', 'document_id'};
for k = 1:numel(entries)
    e = entries{k};
    if ~isstruct(e) || ~isscalar(e)
        error('did2:convert:v1read:badDependsOn', ...
            'depends_on entry %d is a %s, not a {name, value} struct.', k, class(e));
    end
    name = '';
    if isfield(e, 'name')
        name = textOf(e.name);
    end
    if ~isempty(options.Name) && (~ischar(name) || isempty(regexp(name, options.Name, 'once')))
        continue;
    end
    docId = '';
    sourceKey = '';
    for t = 1:numel(targetKeys)
        key = targetKeys{t};
        if isfield(e, key) && ~isempty(e.(key))
            docId = textOf(e.(key));
            sourceKey = key;
            break;
        end
    end
    version = '';
    if isfield(e, 'version')
        version = textOf(e.version);
    end
    other = struct();
    fns = fieldnames(e);
    for f = 1:numel(fns)
        key = fns{f};
        if any(strcmp(key, {'name', 'version'})) || strcmp(key, sourceKey)
            continue;
        end
        v = e.(key);
        if any(strcmp(key, targetKeys)) ...
                && (isempty(v) || isequal(textOf(v), docId))
            continue;   % empty, or restates the winner
        end
        other.(key) = v;
    end
    deps(end+1) = struct('name', {name}, 'document_id', {docId}, ...
        'source_key', {sourceKey}, 'version', {version}, 'other', {other}); %#ok<AGROW>
end
end
