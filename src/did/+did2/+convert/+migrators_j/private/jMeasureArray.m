function m = jMeasureArray(vals, unit)
%JMEASUREARRAY A length-N inline quantity value: an array of measurement
%   composites {source_unit, source_value, approximate}, one per reading.
%   Series-as-cardinality (Brainstorm I): the length-1 case is a single reading;
%   a quantity leaf's `value` field is mustBeScalar:false, so the leaf holds the
%   whole array. Per-reading identity is positional; a continuous axis, if any,
%   is a subject_statement `parameters` qualifier (see jTuningFold).
%
%   vals   numeric vector of readings.
%   unit   source_unit (char) applied to every reading.
%
%   Shared helper for the Brainstorm-J (+migrators_j) inline-quantity migrators.
m = struct('source_unit', {}, 'source_value', {}, 'approximate', {});
for k = 1:numel(vals)
    m(k) = struct('source_unit', char(unit), 'source_value', double(vals(k)), ...
        'approximate', false);
end
end
