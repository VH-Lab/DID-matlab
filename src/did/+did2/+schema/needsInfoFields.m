function [fields, problems] = needsInfoFields(s)
%NEEDSINFOFIELDS The field paths a document's `needs_info` names.
%
%   [FIELDS, PROBLEMS] = did2.schema.needsInfoFields(S) reads S.base.needs_info
%   (S a document struct) and returns the `field` of each entry as a cellstr,
%   and PROBLEMS, a cellstr naming each entry that is not a {field, reason}
%   pair of non-empty text, or that names a field S gives (an entry for a
%   fact that is present says something false). A document with no
%   `needs_info` gives {} and {}.
%
%   [missing facts are needs info] (Jess Haley, 2026-10-29, did-schema
%   V_eta_go_forward_class_audit.md): a document records a fact its source
%   never stated as a `needs_info` entry naming the missing field and why; a
%   required field may be absent only when that entry names it. A path is
%   <block>.<field>, with (k) after a struct-array field and . between levels:
%   'coordinate_system.reference_point',
%   'coordinate_system.axes(2).positive_direction'.
%
%   See also did2.schema.cache/validateDocument, did2.build.document.

fields = {};
problems = {};
if ~isstruct(s) || ~isfield(s, 'base') || ~isstruct(s.base) || ~isfield(s.base, 'needs_info')
    return;
end
entries = s.base.needs_info;
if isempty(entries)
    return;
end
if ~isstruct(entries)
    problems{end+1} = 'base.needs_info is not a list of {field, reason} entries';
    return;
end
for k = 1:numel(entries)
    e = entries(k);
    f = textOf(e, 'field');
    r = textOf(e, 'reason');
    if isempty(f) || isempty(r)
        problems{end+1} = sprintf('base.needs_info(%d) needs both a field and a reason', k); %#ok<AGROW>
        continue;
    end
    if holdsValue(s, f)
        problems{end+1} = sprintf(['base.needs_info(%d) names "%s", which the ' ...
            'document gives'], k, f); %#ok<AGROW>
    end
    fields{end+1} = f; %#ok<AGROW>
end
end

function v = textOf(s, name)
v = '';
if isfield(s, name) && (ischar(s.(name)) || (isstring(s.(name)) && isscalar(s.(name))))
    v = strtrim(char(s.(name)));
end
end

function tf = holdsValue(s, path)
% True when PATH reaches a value in S that is not empty.
tf = false;
parts = strsplit(path, '.');
v = s;
for k = 1:numel(parts)
    % 'names', not 'tokens': MATLAB drops an optional group that did not
    % match from a 'tokens' result, so its index would not exist
    tok = regexp(parts{k}, '^(?<name>[A-Za-z]\w*)(?:\((?<index>\d+)\))?$', 'names', 'once');
    if isempty(tok) || ~isstruct(v) || isempty(v) || ~isfield(v, tok.name)
        return;
    end
    if numel(v) > 1
        return;   % a path names one element at each level
    end
    v = v.(tok.name);
    if ~isempty(tok.index)
        i = str2double(tok.index);
        if ~isstruct(v) || i > numel(v)
            return;
        end
        v = v(i);
    end
end
if isstruct(v)
    tf = ~isempty(v) && ~isempty(fieldnames(v)) && ~allBlank(v);
else
    tf = ~isempty(v) && ~(isstring(v) && all(strlength(v) == 0));
end
end

function tf = allBlank(v)
% A struct whose every leaf is empty text or [] says nothing (an all-blank
% ontology term).
tf = true;
f = fieldnames(v);
for k = 1:numel(f)
    x = v.(f{k});
    if isstruct(x) && numel(x) > 1
        tf = false; return;
    elseif isstruct(x)
        if ~isempty(x) && ~allBlank(x); tf = false; return; end
    elseif ~isempty(x) && ~(isstring(x) && all(strlength(x) == 0))
        tf = false; return;
    end
end
end
