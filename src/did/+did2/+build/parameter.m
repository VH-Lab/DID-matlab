function p = parameter(variable, options)
%PARAMETER One knob of a `method_parameters` list: an algorithm setting.
%
%   P = did2.build.parameter(VARIABLE, 'Value', X, 'Unit', U)   numeric knob
%   P = did2.build.parameter(VARIABLE, 'Term', T)               categorical knob
%   P = did2.build.parameter(VARIABLE, 'Count', N)              integer knob
%   P = did2.build.parameter(VARIABLE, 'Text', S)               free-string knob
%
%   VARIABLE says WHAT knob this is: a term, or a name when the knob has no
%   ontology term (a label, item 33). Exactly one value form is given, and it
%   is ONE value. The shape is the same whether the list sits inline on a
%   statement (`interaction.method_parameters`, #73 item 22) or on a
%   standalone `method_parameters` document, so the one builder serves both,
%   and it is the same entry as a condition's (data_body AMENDMENT 3):
%   {variable, unit, source_unit, approximate} plus one of `term`, `quantity`
%   {value, source_value}, `count` or `text`.
%
%   Options:
%     'Value'        numeric, canonical, in 'Unit' -> quantity.value
%     'SourceValue'  what the source wrote, AS TEXT -> quantity.source_value
%                    (char, so "1e-3" or "auto" survive exactly)
%     'Unit'         canonical unit (a term or a name) for a numeric knob
%                    (#73 audit 2 D4); absent for a unitless or non-numeric knob
%     'SourceUnit'   the unit as the source gave it
%     'Approximate'  logical, for the whole knob
%     'Term'         a term (or a name)
%     'Count'        an integer
%     'Text'         char
%     'SchemaCache'  a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. Knob variables must be distinct within
%   one list, and a statement carries inline parameters OR a
%   method_parameters_id edge, never both (checked when the document is built).
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
    options.SchemaCache = []
end

s = oneValueEntry(variable, {'Value', 'Term', 'Count', 'Text'}, options, ...
    'parameter_one_form');
p = did2.build.composite('method_parameters', 'method_parameters', s, ...
    'SchemaCache', options.SchemaCache);
end
