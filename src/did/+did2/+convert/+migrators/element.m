function v2Body = element(preBody)
%ELEMENT Base migrator: did_v1 element body -> the class-preserving V2 shape.
%
%   V2's element schema declares `direct` as integer (default 0,
%   range 0..1). The did_v1 element_schema also declares it integer,
%   but some v1 producers (PRED corpus, and historical writes across
%   the other public corpora) emit it as a JSON boolean. After
%   jsondecode that lands as a MATLAB `logical`, which V2's
%   validator rejects because `isnumeric(true)` is false. This
%   migrator coerces logical (and a couple of defensive char shapes)
%   to integer so the corpus migrates cleanly.
%
%   Other element fields pass through unchanged: V2 keeps the
%   v1 names for ndi_element_class, name, reference, and type.

arguments
    preBody (1,1) struct
end

v2Body = preBody;
if ~isfield(v2Body, 'element') || ~isstruct(v2Body.element)
    return;
end

block = v2Body.element;

if isfield(block, 'direct')
    block.direct = coerceDirectToInteger(block.direct);
end

v2Body.element = block;
end

function out = coerceDirectToInteger(value)
if islogical(value)
    out = double(value);
elseif isnumeric(value)
    out = value;
elseif ischar(value) || (isstring(value) && isscalar(value))
    s = lower(strtrim(char(value)));
    switch s
        case {'1', 'true'}
            out = 1;
        case {'0', 'false', ''}
            out = 0;
        otherwise
            n = str2double(s);
            if isnan(n)
                out = value;
            else
                out = n;
            end
    end
else
    out = value;
end
end
