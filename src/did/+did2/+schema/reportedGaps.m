function [fields, problems] = reportedGaps(s)
%REPORTEDGAPS The field paths the migration report lists as gaps of a document.
%
%   [FIELDS, PROBLEMS] = did2.schema.reportedGaps(S) reads the gaps the
%   migration run held by did2.convert.migrationReport lists for S.base.id
%   (S a document struct) and returns the `field` of each as a cellstr, and
%   PROBLEMS, a cellstr naming each gap for a field S gives (a gap for a fact
%   that is present says something false). A document no held run lists, or
%   any document while no run is held, gives {} and {}.
%
%   Decided by Jess Haley, 2026-11-01 (did-schema
%   docs/plans/did_v2_go_forward_class_audit.md) [gap accepted when the report
%   lists it]: "a migrated document may lack a required field only when its
%   run's migration report lists that document and field with a reason; any
%   other missing required field fails validation", and [migration record]:
%   `base.needs_info` is dropped, so the document itself no longer says what
%   its source left out. A path is <block>.<field>, with (k) after a
%   struct-array field and . between levels:
%   'coordinate_system.reference_point',
%   'coordinate_system.axes(2).positive_direction'.
%
%   See also did2.convert.migrationReport, did2.schema.cache/validateDocument,
%            did2.build.document.

fields = {};
problems = {};
if ~isstruct(s) || ~isfield(s, 'base') || ~isstruct(s.base) || ~isfield(s.base, 'id')
    return;
end
id = s.base.id;
if ~(ischar(id) || (isstring(id) && isscalar(id))) || ~did2.convert.migrationReport('active')
    return;
end
entries = did2.convert.migrationReport('gaps', char(id));
for k = 1:numel(entries)
    f = entries(k).field;
    if holdsValue(s, f)
        problems{end+1} = sprintf(['the migration report lists "%s" of %s as a ' ...
            'gap, but the document gives it'], f, char(id)); %#ok<AGROW>
    end
    fields{end+1} = f; %#ok<AGROW>
end
end

function tf = holdsValue(s, path)
% True when PATH reaches a value in S that is not empty.
tf = false;
parts = strsplit(path, '.');
v = s;
for k = 1:numel(parts)
    % 'name' or 'name(k)'. Read without an optional regexp group: MATLAB
    % leaves an unmatched optional group (named or not) out of its result.
    [name, index] = segmentOf(parts{k});
    if isempty(name) || ~isstruct(v) || isempty(v) || ~isfield(v, name)
        return;
    end
    if numel(v) > 1
        return;   % a path names one element at each level
    end
    v = v.(name);
    if ~isnan(index)
        i = index;
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

function [name, index] = segmentOf(seg)
% 'axes(2)' -> 'axes', 2; 'reference_point' -> 'reference_point', NaN;
% anything else -> '', NaN.
name = '';
index = NaN;
whole = regexp(seg, '^[A-Za-z]\w*$', 'match', 'once');
if ~isempty(whole)
    name = whole;
    return;
end
tok = regexp(seg, '^([A-Za-z]\w*)\((\d+)\)$', 'tokens', 'once');
if numel(tok) == 2
    name = tok{1};
    index = str2double(tok{2});
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
