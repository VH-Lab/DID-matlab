function [main, absEntry, n] = interpolatedEntries(iv)
%INTERPOLATEDENTRIES The main and the 'absolute value' entries of a tuning
%   calculation's `interpolated_values`, in either shape.
%
%   [MAIN, ABSENTRY, N] = did2.unittest.helpers.interpolatedEntries(IV)
%
%   [interpolated values are a list] (Decided by Jess Haley, 2026-10-30,
%   did-schema V_eta_go_forward_class_audit.md): `interpolated_values` on
%   spatial_frequency_tuning_calculation, temporal_frequency_tuning_calculation,
%   contrast_tuning_calculation and contrast_sensitivity's value becomes a LIST
%   of entries, each with the optional `response_transform` ('absolute value'
%   on the entry read from |response|, v1 `abs.fitless`). Until did-schema
%   declares it the field is ONE structure. The writer
%   (+migrators_j/private/jCalculation.m) writes whichever the loaded schema
%   declares, so a test reads both through this helper:
%
%     IV         one structure, a struct array, or a cell of structs
%     MAIN       the entry with no (or an empty) response_transform, i.e. the
%                values read off the curve as stated; struct() when none
%     ABSENTRY   the entry whose response_transform is 'absolute value';
%                struct() when none
%     N          how many entries IV holds (1 for the one structure)
%
%   Each returned entry is given without its `response_transform` field and
%   without fields holding [] (the absent marker did2.build.list and a ragged
%   JSON array give a field another entry has). A test asserts N itself, so a
%   second entry with the same transform, or one with any other transform, is
%   seen as a wrong count rather than hidden.
%
%   The production reader is +roundtrip/private/interpolatedEntry.m; this is
%   the test-side copy, kept separate so a test does not share the premise of
%   the code it checks.

main = struct();
absEntry = struct();
n = 0;
if isempty(iv)
    return;
end
if isstruct(iv)
    entries = num2cell(reshape(iv, 1, []));
elseif iscell(iv)
    entries = reshape(iv, 1, []);
else
    error('did2:unittest:interpolatedEntries', ...
        'interpolated_values is a %s, neither a structure nor a list.', class(iv));
end
n = numel(entries);
haveMain = false;
haveAbs = false;
for k = 1:n
    e = entries{k};
    if ~(isstruct(e) && isscalar(e))
        continue;
    end
    t = '';
    if isfield(e, 'response_transform') && ~isempty(e.response_transform)
        t = strtrim(char(e.response_transform));
    end
    if isfield(e, 'response_transform')
        e = rmfield(e, 'response_transform');
    end
    fns = fieldnames(e);
    for j = 1:numel(fns)
        if isempty(e.(fns{j})) && ~ischar(e.(fns{j}))
            e = rmfield(e, fns{j});
        end
    end
    if isempty(t) && ~haveMain
        main = e;
        haveMain = true;
    elseif strcmp(t, 'absolute value') && ~haveAbs
        absEntry = e;
        haveAbs = true;
    end
end
end
