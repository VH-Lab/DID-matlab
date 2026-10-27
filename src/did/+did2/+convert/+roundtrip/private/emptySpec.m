function spec = emptySpec()
%EMPTYSPEC An inverse's SPEC with nothing in it (did2.convert.roundtrip.check).
spec = struct('equivalents', struct('path', {}, 'values', {}, 'why', {}), ...
    'same', struct('path', {}, 'fn', {}, 'why', {}), 'unplaced', {{}});
end
