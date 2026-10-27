function row = carryRowFor(notes, path)
%CARRYROWFOR The carry register row a `carried_as_v1` note cites for PATH.
%
%   ROW = did2.unittest.helpers.carryRowFor(NOTES, PATH). NOTES is one note's
%   detail, several joined by ' || ' (did2.unittest.helpers.carryNote), or a
%   cellstr of details. ROW is the row ('carry-100', 'carry-056', ...) of the
%   first path equal to PATH (or to PATH followed by a parenthesised reason);
%   '' when a path is named with no tag; 'not named' when no note names it.
%
%   See also did2.unittest.helpers.carryPaths.

if iscell(notes)
    details = notes;
else
    details = strsplit(char(notes), ' || ');
end
row = 'not named';
for k = 1:numel(details)
    [paths, rows] = did2.unittest.helpers.carryPaths(details{k});
    for j = 1:numel(paths)
        if strcmp(paths{j}, path) || startsWith(paths{j}, [path ' ('])
            row = rows{j};
            return;
        end
    end
end
end
