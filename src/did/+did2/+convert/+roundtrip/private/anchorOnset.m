function onset = anchorOnset(anchor)
%ANCHORONSET The instant an `absolute_time_reference` anchor states, as the
%   v1 text it was read from (`value.start.source_value`, jAbsoluteReference);
%   '' for any other anchor (a "during the session" reference states none).
onset = '';
if ~strcmp(classNameOf(anchor), 'absolute_time_reference')
    return;
end
[v, ok] = getIn(anchor, 'absolute_time_reference', 'value', 'start', 'source_value');
if ok && (ischar(v) || (isstring(v) && isscalar(v)))
    onset = char(v);
end
end
