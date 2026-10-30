function [entry, bad] = interpolatedEntry(iv, transform, where)
%INTERPOLATEDENTRY The `interpolated_values` entry read from the responses
%   transformed by TRANSFORM ('' for the responses as stated), in either shape.
%
%   [ENTRY, BAD] = interpolatedEntry(IV, TRANSFORM, WHERE). IV is a
%   calculation's `interpolated_values`:
%     ONE structure    the shape did-schema declares today: the values read
%                      off the curve as stated (its `response_transform`, if
%                      any, says otherwise);
%     A LIST           [interpolated values are a list] (Decided by Jess Haley,
%                      2026-10-30, did-schema V_eta_go_forward_class_audit.md):
%                      entries like `model_fit`'s, each with the optional
%                      `response_transform` ('absolute value' on the one read
%                      from |response|, v1 `abs.fitless`), as a struct array
%                      or a cell of structs.
%   ENTRY is the entry whose `response_transform` is TRANSFORM (empty or
%   absent counts as ''), without that field and without fields holding []
%   (absent in a ragged list); struct() when there is none.
%   BAD names, under WHERE, a second entry with the same transform, and (when
%   TRANSFORM is '') any entry whose transform is neither '' nor 'absolute
%   value', so each problem is reported once.
%
%   The siblings-first order: DID reads both shapes before did-schema changes
%   the field to a list (jCalculation writes the list once the loaded schema
%   declares `response_transform` on it).

entry = struct();
bad = {};
if isempty(iv)
    return;
end
if isstruct(iv)
    entries = num2cell(reshape(iv, 1, []));
elseif iscell(iv)
    entries = reshape(iv, 1, []);
else
    bad{end+1} = sprintf('%s is neither a structure nor a list', where);
    return;
end
found = false;
for k = 1:numel(entries)
    e = entries{k};
    if ~(isstruct(e) && isscalar(e))
        if isempty(transform)
            bad{end+1} = sprintf('%s(%d) is not a structure', where, k); %#ok<AGROW>
        end
        continue;
    end
    t = '';
    if isfield(e, 'response_transform') && ~isempty(e.response_transform)
        t = strtrim(char(e.response_transform));
    end
    if isempty(transform) && ~any(strcmp(t, {'', 'absolute value'}))
        bad{end+1} = sprintf('%s(%d).response_transform "%s" has no place in v1', ...
            where, k, t); %#ok<AGROW>
        continue;
    end
    if ~strcmp(t, transform)
        continue;
    end
    if found
        bad{end+1} = sprintf('%s(%d) is a second entry for response transform "%s"', ...
            where, k, transform); %#ok<AGROW>
        continue;
    end
    if isfield(e, 'response_transform')
        e = rmfield(e, 'response_transform');
    end
    % a field another list entry has and this one lacks reads as [] (the
    % absent marker did2.build.list and a ragged JSON array give it)
    fns = fieldnames(e);
    for j = 1:numel(fns)
        if isempty(e.(fns{j})) && ~ischar(e.(fns{j}))
            e = rmfield(e, fns{j});
        end
    end
    entry = e;
    found = true;
end
end
