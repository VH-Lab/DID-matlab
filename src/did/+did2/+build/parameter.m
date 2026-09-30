function p = parameter(variable, options)
%PARAMETER One knob of a `method_parameters` list: an algorithm setting.
%
%   P = did2.build.parameter(VARIABLE, 'Value', X, 'Unit', U)   numeric knob
%   P = did2.build.parameter(VARIABLE, 'Term', T)               categorical knob
%   P = did2.build.parameter(VARIABLE, 'Text', S)               free-string knob
%
%   VARIABLE says WHAT knob this is: a term, or a name when the knob has no
%   ontology term (a label, item 33). Exactly one value form is given. The
%   shape is the same whether the list sits inline on a statement
%   (`subject_interaction.method_parameters`, #73 item 22) or on a standalone
%   `method_parameters` document, so the one builder serves both.
%
%   Options:
%     'Value'        numeric, canonical, in 'Unit'
%     'SourceValue'  what the source wrote, AS TEXT (value.source_value is char,
%                    so "1e-3" or "auto" survive exactly)
%     'Unit'         canonical unit (a term or a name) for a numeric knob
%                    (#73 audit 2 D4); absent for a unitless or non-numeric knob
%     'SourceUnit'   the unit as the source gave it
%     'Term'         a term (or a name)
%     'Text'         char
%     'SchemaCache'  a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. Knob variables must be distinct within
%   one list, and a statement carries inline parameters OR a
%   method_parameters_id edge, never both (checked when the document is built).
%
%   See also did2.build.list, did2.build.statement.

arguments
    variable
    options.Value = []
    options.SourceValue = ''
    options.Unit = []
    options.SourceUnit = ''
    options.Term = []
    options.Text = ''
    options.SchemaCache = []
end

if iscell(variable) || (isstruct(variable) && ~isscalar(variable))
    error('did2:build:typeMismatch', ...
        'The variable is one term: a name or a scalar {node, name} struct.');
end
forms = {'Value', 'Term', 'Text'};
given = forms(cellfun(@(f) ~isempty(options.(f)), forms));
if numel(given) ~= 1
    error('did2:build:ruleViolated', ...
        'parameter_one_form: give exactly one of ''Value'', ''Term'', ''Text''; got %d.', numel(given));
end
if ~isempty(options.SourceValue) && isempty(options.Value)
    error('did2:build:ruleViolated', '''SourceValue'' applies only to ''Value''.');
end
if (~isempty(options.Unit) || ~isempty(options.SourceUnit)) && isempty(options.Value)
    error('did2:build:ruleViolated', '''Unit''/''SourceUnit'' apply only to a numeric ''Value''.');
end

s = struct('variable', {variable});
if ~isempty(options.Unit);       s.unit = options.Unit;              end
if ~isempty(options.SourceUnit); s.source_unit = options.SourceUnit; end
if ~isempty(options.Value)
    v = struct('value', options.Value);
    if ~isempty(options.SourceValue)
        v.source_value = options.SourceValue;
    end
    s.value = v;
end
if ~isempty(options.Term); s.term = options.Term; end
if ~isempty(options.Text); s.text = options.Text; end
p = did2.build.composite('method_parameters', 'method_parameters', s, ...
    'SchemaCache', options.SchemaCache);
end
