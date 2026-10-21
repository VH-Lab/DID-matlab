function c = condition(variable, options)
%CONDITION One entry of a statement's `conditions`: a one-value fact true of
%   EVERY value of the statement that is not a dimension of the stored array.
%
%   C = did2.build.condition(VARIABLE, 'Term', T)       categorical
%   C = did2.build.condition(VARIABLE, 'Value', X)      number ('Quantity' is
%                                                       the same option)
%   C = did2.build.condition(VARIABLE, 'Count', N)      integer
%   C = did2.build.condition(VARIABLE, 'Text', S)       free string
%
%   VARIABLE is a term or a name (arm direction, OD600, trial type). Exactly ONE
%   value form is given, and it is ONE value: "a one-value fact true of EVERY
%   value of the statement" (statement.conditions). A fact with several values
%   is a key, not a condition. The entry is the same as a method parameter's
%   (data_body AMENDMENT 3): {variable, unit, source_unit, approximate} plus
%   one of `term`, `quantity` {value, source_value}, `count` or `text`, so it
%   takes the same options as did2.build.parameter.
%
%   Options:
%     'Term'           a term (or a name)
%     'Value'          a number, canonical, in 'Unit' -> quantity.value
%     'Quantity'       the same as 'Value'
%     'SourceValue'    what the source wrote for the number, AS TEXT
%                      -> quantity.source_value (kept verbatim)
%     'Count'          an integer
%     'Text'           char
%     'Unit'           canonical unit (a term or a name); absent when categorical
%     'SourceUnit'     the unit as the source gave it: its registered term
%                      where the schema declares source_unit a term, text
%                      where it declares char (see did2.build.valueCell)
%     'Approximate'    logical, for the whole condition
%     'SchemaCache'    a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. A variable appears at most once across
%   a statement's keys and conditions (checked when the document is built).
%
%   See also did2.build.key, did2.build.parameter, did2.build.statement.

arguments
    variable
    options.Term = []
    options.Value = []
    options.Quantity = []
    options.SourceValue = ''
    options.Count = []
    options.Text = ''
    options.Unit = []
    options.SourceUnit = ''
    options.Approximate = []
    options.SchemaCache = []
end

s = oneValueEntry(variable, {'Term', 'Value', 'Quantity', 'Count', 'Text'}, options, ...
    'conditions_one_value');
statementClass = vetaNames(options.SchemaCache);   % `subject_statement` before 2026-10-08
c = did2.build.composite(statementClass, 'conditions', s, ...
    'SchemaCache', options.SchemaCache);
end
