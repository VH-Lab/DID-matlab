function c = condition(variable, options)
%CONDITION One entry of a statement's `conditions`: a one-value fact true of
%   EVERY value of the statement that is not a dimension of the stored array.
%
%   C = did2.build.condition(VARIABLE, 'Term', T)       categorical
%   C = did2.build.condition(VARIABLE, 'Count', N)      integer
%   C = did2.build.condition(VARIABLE, 'Quantity', Q)   dimensioned number
%
%   VARIABLE is a term or a name (arm direction, OD600, trial type). Exactly ONE
%   of 'Term', 'Count', 'Quantity' is given, and it is ONE value: "carries
%   exactly one value form ... Cardinality exactly 1" (statement.
%   conditions, data_body AMENDMENT 2, #73 item 23). A fact with several values
%   is a key, not a condition.
%
%   Options:
%     'Term'           a term (or a name)
%     'Count'          an integer
%     'Quantity'       a number, canonical, in 'Unit'
%     'SourceValue'    what the source wrote for 'Quantity'
%     'Unit'           canonical unit (a term or a name); absent when categorical
%     'SourceUnit'     the unit as the source gave it
%     'Approximate'    logical, for the whole condition
%     'SchemaCache'    a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. A variable appears at most once across
%   a statement's keys and conditions (checked when the document is built).
%
%   See also did2.build.key, did2.build.statement.

arguments
    variable
    options.Term = []
    options.Count = []
    options.Quantity = []
    options.SourceValue = []
    options.Unit = []
    options.SourceUnit = ''
    options.Approximate = []
    options.SchemaCache = []
end

forms = {'Term', 'Count', 'Quantity'};
given = forms(cellfun(@(f) ~isempty(options.(f)), forms));
if numel(given) ~= 1
    error('did2:build:ruleViolated', ...
        'conditions_one_value: give exactly one of ''Term'', ''Count'', ''Quantity''; got %d.', ...
        numel(given));
end
one = options.(given{1});
if ~(ischar(one) || (isstring(one) && isscalar(one))) && numel(one) ~= 1
    error('did2:build:ruleViolated', ...
        'conditions_one_value: a condition is ONE value; ''%s'' has %d. Use a key for more.', ...
        given{1}, numel(one));
end
if ~isempty(options.SourceValue) && isempty(options.Quantity)
    error('did2:build:ruleViolated', '''SourceValue'' applies only to ''Quantity''.');
end

s = struct('variable', {variableArg(variable)});
if ~isempty(options.Unit);        s.unit = options.Unit;               end
if ~isempty(options.SourceUnit);  s.source_unit = options.SourceUnit;  end
if ~isempty(options.Approximate); s.approximate = options.Approximate; end
switch given{1}
    case 'Term'
        s.term = struct('value', {{one}});
    case 'Count'
        s.count = struct('value', one);
    case 'Quantity'
        q = struct('value', one);
        if ~isempty(options.SourceValue)
            q.source_value = options.SourceValue;
        end
        s.quantity = struct('value', q);
end
c = did2.build.composite('statement', 'conditions', s, ...
    'SchemaCache', options.SchemaCache);
end

function v = variableArg(v)
% A variable is ONE term: a name (char/string) or a scalar struct {node,name}.
if iscell(v) || (isstruct(v) && ~isscalar(v)) || (isstring(v) && ~isscalar(v))
    error('did2:build:typeMismatch', ...
        'The variable is one term: a name or a scalar {node, name} struct.');
end
end
