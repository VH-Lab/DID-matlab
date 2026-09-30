function out = list(varargin)
%LIST Join entries built separately into one array field.
%
%   OUT = did2.build.list(A, B, C, ...) concatenates structs (each scalar or a
%   struct array) into one 1xN struct array, even when they carry different
%   fields. A field an entry lacks is set to [] -- the "absent" marker the
%   schema cache uses for a ragged JSON array, and the one every did2.build
%   function reads as "not given". Field order follows the first entry that
%   carries each field.
%
%   Use it to assemble `keys`, `conditions`, `method_parameters`, a fit's
%   `coefficients`, ... from entries made by did2.build.key, .condition,
%   .parameter, etc. With no arguments it returns a 0x0 struct.
%
%   Example:
%     keys = did2.build.list( ...
%         did2.build.key('time', 1000, 'Origin', 0, 'Spacing', 0.001, 'Unit', 's'), ...
%         did2.build.key('channel', 4, 'Labels', {'A','B','C','D'}));

elems = {};
names = {};
for k = 1:nargin
    v = varargin{k};
    if iscell(v)
        parts = reshape(v, 1, []);
    elseif isstruct(v)
        parts = num2cell(reshape(v, 1, []));
    else
        error('did2:build:typeMismatch', ...
            'list: argument %d is a %s, not a struct.', k, class(v));
    end
    for j = 1:numel(parts)
        p = parts{j};
        if ~(isstruct(p) && isscalar(p))
            error('did2:build:typeMismatch', ...
                'list: argument %d element %d is not a scalar struct.', k, j);
        end
        fn = fieldnames(p);
        % drop fields that are absent in this element, so they do not
        % survive as [] into positions where another entry defines them
        for f = 1:numel(fn)
            if isAbsent(p.(fn{f}))
                p = rmfield(p, fn{f});
            end
        end
        names = [names, setdiff(fieldnames(p)', names, 'stable')]; %#ok<AGROW>
        elems{end+1} = p; %#ok<AGROW>
    end
end
out = mergeRagged(elems, names);
end
