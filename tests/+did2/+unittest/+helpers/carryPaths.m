function [paths, rows] = carryPaths(detail)
%CARRYPATHS The paths a `carried_as_v1` note names, each with the carry
%   register row that cites it.
%
%   [PATHS, ROWS] = did2.unittest.helpers.carryPaths(DETAIL) reads the DETAIL
%   of one `carried_as_v1` note in the two shapes the raw-v1 migrators write:
%
%     '[carry-100] malformed: outside the NDI template, unplaced: a, b'
%         (private/jRawCarry: every path cites carry-100)
%     'unplaced: [carry-056] c, [carry-016] d (reason, with commas)'
%         (each path after its own tag)
%
%   and the two joined by '; ' (jRawCarry lists the tagged reasons after the
%   carry-100 paths). PATHS and ROWS are 1xN cellstr; a path written with no
%   tag of its own has the row '' . A path keeps the parenthesised reason
%   written after it; a comma inside parentheses does not split a path.
%
%   Decided by Jess Haley, 2026-10-27 [tuning stray fields are malformed]
%   (did-schema V_eta_go_forward_class_audit.md): the tuning family's notes
%   cite carry-100 for a field outside the template and carry-056 for a
%   template field with no home, so a test reads both shapes.

paths = {};
rows = {};
malformed = '^\[(carry-\d{3})\] malformed: outside the NDI template, unplaced: ';
for seg = splitOutside(char(detail), ';')
    s = strtrim(seg{1});
    row = '';
    tok = regexp(s, malformed, 'tokens', 'once');
    if ~isempty(tok)
        row = tok{1};
        s = regexprep(s, malformed, '');
    else
        s = regexprep(s, '^unplaced: ', '');
    end
    for item = splitOutside(s, ',')
        p = strtrim(item{1});
        if isempty(p)
            continue;
        end
        r = row;
        t = regexp(p, '^\[(carry-\d{3})\] ', 'tokens', 'once');
        if ~isempty(t)
            r = t{1};
            p = regexprep(p, '^\[carry-\d{3}\] ', '');
        end
        paths{end+1} = p; %#ok<AGROW>
        rows{end+1} = r; %#ok<AGROW>
    end
end
end

function parts = splitOutside(s, sep)
%SPLITOUTSIDE S split at SEP followed by a space, outside parentheses.
parts = {};
depth = 0;
start = 1;
for k = 1:numel(s)
    switch s(k)
        case '('
            depth = depth + 1;
        case ')'
            depth = max(depth - 1, 0);
        case sep
            if depth == 0 && k < numel(s) && s(k + 1) == ' '
                parts{end+1} = s(start:k - 1); %#ok<AGROW>
                start = k + 2;
            end
    end
end
parts{end+1} = s(start:end);
end
