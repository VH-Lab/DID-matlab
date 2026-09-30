function out = composite(className, fieldPath, values, options)
%COMPOSITE Any nested structure a class declares, checked against its schema.
%
%   OUT = did2.build.composite(CLASSNAME, FIELDPATH, VALUES) builds the
%   structure declared at CLASSNAME's field FIELDPATH (dot-separated: 'keys',
%   'value', 'value.start', 'conditions') from VALUES, a struct (or struct
%   array / cell of structs when the field is an array).
%
%   This is the general form of every other component builder in the package,
%   and the one to use for a shape none of them covers (a tuning_curve value, a
%   formulation's ingredients, ...). The rules:
%     * every name in VALUES must be declared at that level, recursively
%                                              -> did2:build:unknownField
%     * a nested field declared mustBeNonEmpty must be given
%                                              -> did2:build:missingField
%     * fields that are not given are LEFT OUT (not blank-filled), because
%       several schema rules turn on whether a field is present
%     * output field order is the schema's declared order
%     * leaf values are checked for declared type, scalarity, enum and bounds
%     * an ontology_term may be given as a name (char) or a struct {node,name}
%   The binding constraint (T8) is not checked; that is the schema cache's.
%
%   Options:
%     'SchemaCache'   a did2.schema.cache; default the shared one.
%
%   Example:
%     start = did2.build.composite('relative_time_reference', 'value.start', ...
%         struct('seconds', 1.5, 'source_value', 1500, 'source_unit', 'ms'));
%
%   See also did2.build.document.

arguments
    className (1,:) char
    fieldPath (1,:) char
    values
    options.SchemaCache = []
end

cache = schemaCache(options.SchemaCache);
def = fieldDef(cache, className, fieldPath);
out = fillField(def, values, [className '.' fieldPath]);
end
