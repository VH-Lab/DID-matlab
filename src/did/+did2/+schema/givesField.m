function tf = givesField(s, path)
%GIVESFIELD True when the document struct S gives a value at the field PATH.
%
%   TF = did2.schema.givesField(S, PATH): PATH is <block>.<field>, with (k)
%   after a struct-array field and . between levels, as a gap of the
%   migration report names it ('coordinate_system.reference_point',
%   'coordinate_system.axes(2).positive_direction'). TF is true when PATH
%   reaches a value that is not empty: not [], not empty text, not a struct
%   whose every leaf is empty (an all-blank ontology term).
%
%   did2.schema.reportedGaps uses it to refuse a gap for a field S gives;
%   did2.convert.migrationReport uses it to refuse a known v1 defect for a
%   field S does not give (a defect is about a value the document holds).
%
%   See also did2.schema.reportedGaps, did2.convert.migrationReport.

tf = holdsValue(s, char(path));
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
