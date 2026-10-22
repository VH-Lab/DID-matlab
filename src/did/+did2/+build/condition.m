function c = condition(variable, options)
%CONDITION One entry of a statement's `conditions`: a one-value fact true of
%   EVERY value of the statement that is not a dimension of the stored array.
%
%   C = did2.build.condition(VARIABLE, 'Term', T)       categorical
%   C = did2.build.condition(VARIABLE, 'Value', X)      number ('Quantity' is
%                                                       the same option)
%   C = did2.build.condition(VARIABLE, 'Count', N)      integer
%   C = did2.build.condition(VARIABLE, 'Text', S)       free string
%   C = did2.build.condition(VARIABLE, 'Logical', TF)   true / false (Jess
%                                                       Haley 2026-10-22
%                                                       [logical entries])
%   C = did2.build.condition(VARIABLE, 'Matrix', A)     a numeric array, as
%                                                       ONE value
%
%   VARIABLE is a term or a name (arm direction, OD600, trial type). Exactly ONE
%   value form is given, and it is ONE value: "a one-value fact true of EVERY
%   value of the statement" (statement.conditions). A fact with several values
%   is a covariate along a dimension, not a condition. The entry is the same as a method parameter's
%   (data_body AMENDMENT 3): {variable, unit, source_unit, approximate} plus
%   one of `term`, `quantity` {value, source_value}, `count`, `text` or
%   `matrix` (data_body AMENDMENT 4), so it takes the same options as
%   did2.build.parameter.
%
%   Options:
%     'Term'           a term (or a name)
%     'Value'          a number, canonical, in 'Unit' -> quantity.value
%     'Quantity'       the same as 'Value'
%     'SourceValue'    what the source wrote for the number, AS TEXT
%                      -> quantity.source_value (kept verbatim)
%     'Count'          an integer
%     'Text'           char
%     'Matrix'         a numeric array that is ONE value of VARIABLE, in
%                      'Unit'; no 'SourceValue' (did-schema #88)
%     'Unit'           canonical unit (a term or a name); absent when categorical
%     'SourceUnit'     the unit as the source gave it: its registered term
%                      where the schema declares source_unit a term, text
%                      where it declares char (see did2.build.valueCell)
%     'Approximate'    logical, for the whole condition
%     'SchemaCache'    a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. A variable appears at most once across
%   a statement's conditions and its value's covariates (checked when the
%   document is built).
%
%   See also did2.build.covariate, did2.build.parameter, did2.build.statement.

arguments
    variable
    options.Term = []
    options.Value = []
    options.Quantity = []
    options.SourceValue = ''
    options.Count = []
    options.Text = ''
    options.Matrix = []
    options.Logical = []
    options.Unit = []
    options.SourceUnit = ''
    options.Approximate = []
    options.SchemaCache = []
end

s = oneValueEntry(variable, {'Term', 'Value', 'Quantity', 'Count', 'Text', 'Matrix', 'Logical'}, options, ...
    'conditions_one_value');
statementClass = vetaNames(options.SchemaCache);   % `subject_statement` before 2026-10-08
c = did2.build.composite(statementClass, 'conditions', s, ...
    'SchemaCache', options.SchemaCache);
end
