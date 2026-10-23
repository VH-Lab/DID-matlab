function p = parameter(variable, options)
%PARAMETER One knob of a method's `parameters` list: an algorithm setting.
%
%   P = did2.build.parameter(VARIABLE, 'Value', X, 'Unit', U)   numeric knob
%   P = did2.build.parameter(VARIABLE, 'Term', T)               categorical knob
%   P = did2.build.parameter(VARIABLE, 'Count', N)              integer knob
%   P = did2.build.parameter(VARIABLE, 'Text', S)               free-string knob
%   P = did2.build.parameter(VARIABLE, 'Logical', TF)           on/off knob ([logical entries])
%   P = did2.build.parameter(VARIABLE, 'Matrix', A, 'Unit', U)  numeric array knob
%
%   VARIABLE says WHAT knob this is: a term, or a name when the knob has no
%   ontology term (a label, item 33). Exactly one value form is given, and it
%   is ONE value. The shape is the same whether the list sits inline on a
%   statement (`interaction.method.parameters`; `interaction.method_parameters`
%   before did-schema #88) or on a standalone `method` document
%   (did2.build.method; `method_parameters` before #88), so the one builder
%   serves both,
%   and it is the same entry as a condition's (data_body AMENDMENT 3):
%   {variable, unit, source_unit, approximate} plus one of `term`, `quantity`
%   {value, source_value}, `count`, `text` or `matrix` (data_body AMENDMENT
%   4, did-schema #88: a numeric N-D array that is ONE value of VARIABLE).
%
%   Options:
%     'Value'        numeric, canonical, in 'Unit' -> quantity.value
%     'SourceValue'  what the source wrote, AS TEXT -> quantity.source_value
%                    (char, so "1e-3" or "auto" survive exactly)
%     'Unit'         canonical unit (a term or a name) for a numeric knob
%                    (#73 audit 2 D4); absent for a unitless or non-numeric knob
%     'SourceUnit'   the unit as the source gave it: its registered term
%                    where the schema declares source_unit a term, text
%                    where it declares char (see did2.build.valueCell)
%     'Approximate'  logical, for the whole knob
%     'Term'         a term (or a name)
%     'Count'        an integer
%     'Text'         char
%     'Matrix'       a numeric array, ONE value of VARIABLE, in 'Unit'
%                    (a palette n x 3, weights 1 x n, a 35 x 1 seed); no
%                    'SourceValue'. Its shape is kept through did2's JSON
%                    writer and reader. Needs a schema that declares
%                    `matrix` (did-schema #88; did2:build:unknownField before)
%     'SchemaCache'  a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. Knob variables must be distinct within
%   one list, and a statement carries an inline method OR a `method_id` edge
%   (`method_parameters_id` before #88), never both (checked when the document
%   is built).
%
%   See also did2.build.list, did2.build.statement, did2.build.condition.

arguments
    variable
    options.Value = []
    options.SourceValue = ''
    options.Unit = []
    options.SourceUnit = ''
    options.Approximate = []
    options.Term = []
    options.Count = []
    options.Text = ''
    options.Matrix = []
    options.Logical = []
    options.SchemaCache = []
end

s = oneValueEntry(variable, {'Value', 'Term', 'Count', 'Text', 'Matrix', 'Logical'}, options, ...
    'parameter_one_form');
shape = methodShape(options.SchemaCache);
p = did2.build.composite(shape.docClass, shape.listPath, s, ...
    'SchemaCache', options.SchemaCache);
end
