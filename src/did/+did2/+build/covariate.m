function c = covariate(variable, along, options)
%COVARIATE One entry of a value's `covariates`: what is known along its axes.
%
%   C = did2.build.covariate(VARIABLE, ALONG, <one value form>, ...) states
%   VARIABLE at every position of the dimensions ALONG lists (did-schema
%   data_body AMENDMENT 6, Jess Haley 2026-10-22 [covariates]). ALONG is a
%   NON-EMPTY vector of distinct 0-based indices into the value's
%   `dimensions` [along by index]; a fact true of the whole value is a
%   condition, never a covariate with no dimension [conditions stay on the
%   statement].
%
%   The value has the shape of the ALONG dimensions' extents, in ALONG's
%   order (for 'Matrix', those extents followed by the array's own shape);
%   that is checked when the document is built, where the dimensions are.
%
%   EXACTLY ONE value form:
%     'Origin'+'Spacing'  positions origin + k*spacing; numeric; along ONE
%                         dimension ('SourceOrigin', 'SourceSpacing': what the
%                         source wrote, in 'SourceUnit')
%     'Value'             numbers, canonical, in 'Unit' -> quantity.value
%                         ('SourceValue': the same numbers as the source
%                         wrote them -> quantity.source_value)
%     'Count'             integers
%     'Term'              terms (struct array) or names (cellstr) -> term;
%                         a name with no ontology term is a label {name}
%     'Text'              strings (cellstr) -> text
%     'Logical'           true/false -> logical
%     'Matrix'            a whole numeric array at each position
%                         (data_body AMENDMENT 4) -> matrix
%     'Key'               the 0-based position of a `key_id` entry on the
%                         document; position k is entry k of that document's
%                         value; along ONE dimension -> key. 'Document' is
%                         the same form under its old name (Jess Haley,
%                         2026-11-01, "Yes, rename document to key",
%                         did-schema did_v2_data_body_model_plan.md
%                         [covariate key]). The field is written as the
%                         loaded schema spells it, `key` or `document`
%                         (did2.schema.cache/covariateKeyField).
%
%   Options:
%     'Unit'           canonical unit (a term or a name) of a number, a count
%                      or a matrix. Angles are DEGREES.
%     'SourceUnit'     the unit as the source gave it
%     'Approximate'    logical, for the whole covariate
%     'Cyclic'         logical: after the last position comes the first. Only
%                      on an 'Origin'/'Spacing' or a 'Value' (quantity)
%                      covariate along exactly one dimension (Jess Haley
%                      2026-10-22 [covariate details], 5.1a: not 'Count' or
%                      'Matrix').
%     'SchemaCache'    a did2.schema.cache; default the shared one.
%
%   Join several with did2.build.list. A condition's variable appears once
%   across a statement's conditions and its covariates; two covariates may
%   share a variable when they differ in ALONG or in 'Key' (rule
%   variable_once, relaxed by Jess Haley, 2026-11-01, "Yes, relax it",
%   did-schema did_v2_data_body_model_plan.md [covariate variable may
%   repeat]; checked when the document is built).
%
%   Examples:
%     t  = did2.build.covariate('time', 0, 'Origin', 0, 'Spacing', 1/30000, 'Unit', 'second');
%     ch = did2.build.covariate('channel', 1, 'Term', {'A1','A2','A3','A4'});
%     ctl = did2.build.covariate(controlTerm, 0, 'Logical', [false true false]);
%
%   See also did2.build.dimension, did2.build.condition, did2.build.list.

arguments
    variable
    along
    options.Value = []
    options.SourceValue = []
    options.Origin = []
    options.Spacing = []
    options.SourceOrigin = []
    options.SourceSpacing = []
    options.Count = []
    options.Term = []
    options.Text = []
    options.Logical = []
    options.Matrix = []
    options.Key = []
    options.Document = []
    options.Unit = []
    options.SourceUnit = ''
    options.Approximate = []
    options.Cyclic = []
    options.SchemaCache = []
end

if iscell(variable) || (isstruct(variable) && ~isscalar(variable)) ...
        || (isstring(variable) && ~isscalar(variable))
    error('did2:build:typeMismatch', ...
        'The variable is one term: a name or a scalar {node, name} struct.');
end

% ---- along: non-empty, distinct, 0-based --------------------------------
if isAbsent(along) || ~(isnumeric(along) && isreal(along))
    error('did2:build:ruleViolated', ...
        ['covariate_along: ALONG lists at least one 0-based dimension index; ' ...
         'a fact true of the whole value is a condition.']);
end
along = double(reshape(along, 1, []));
if any(along < 0 | along ~= round(along))
    error('did2:build:ruleViolated', ...
        'covariate_along: ALONG holds 0-based dimension indices (integers >= 0); got %s.', mat2str(along));
end
if numel(unique(along)) ~= numel(along)
    error('did2:build:ruleViolated', ...
        'covariate_along: ALONG names each dimension at most once; got %s.', mat2str(along));
end

% ---- exactly one value form ----------------------------------------------
regular = ~isAbsent(options.Origin) || ~isAbsent(options.Spacing);
if regular && (isAbsent(options.Origin) || isAbsent(options.Spacing))
    error('did2:build:ruleViolated', ...
        'covariate_one_value_form: give BOTH ''Origin'' and ''Spacing''.');
end
if ~regular && (~isAbsent(options.SourceOrigin) || ~isAbsent(options.SourceSpacing))
    error('did2:build:ruleViolated', ...
        'covariate_one_value_form: ''SourceOrigin''/''SourceSpacing'' need ''Origin'' and ''Spacing''.');
end
if ~isAbsent(options.Document)
    if ~isAbsent(options.Key)
        error('did2:build:ruleViolated', ...
            'covariate_one_value_form: ''Key'' and ''Document'' are one form; give one.');
    end
    options.Key = options.Document;   % the old name of the same form ([covariate key])
end
forms = {'Value', 'Count', 'Term', 'Text', 'Logical', 'Matrix', 'Key'};
given = forms(cellfun(@(f) ~isAbsent(options.(f)), forms));
if regular
    given = [{'Origin+Spacing'}, given];
end
if numel(given) ~= 1
    error('did2:build:ruleViolated', ...
        ['covariate_one_value_form: give exactly one of ''Origin''+''Spacing'', ''Value'', ' ...
         '''Count'', ''Term'', ''Text'', ''Logical'', ''Matrix'', ''Key''; got %d (%s).'], ...
        numel(given), strjoin(given, ', '));
end
form = given{1};
if isAbsent(options.Value) && ~isAbsent(options.SourceValue)
    error('did2:build:ruleViolated', '''SourceValue'' needs ''Value''.');
end
if any(strcmp(form, {'Origin+Spacing', 'Key'})) && numel(along) ~= 1
    error('did2:build:ruleViolated', ...
        'covariate_single_dimension_forms: a covariate given by ''%s'' runs along exactly one dimension; ALONG has %d.', ...
        form, numel(along));
end
numeric = any(strcmp(form, {'Origin+Spacing', 'Value', 'Count'}));
if (~isAbsent(options.Unit) || ~isAbsent(options.SourceUnit)) && ~(numeric || strcmp(form, 'Matrix'))
    error('did2:build:ruleViolated', ...
        '''Unit''/''SourceUnit'' apply only to a number, a count or a matrix.');
end
if ~isAbsent(options.Cyclic) && isTrue(options.Cyclic) ...
        && ~(any(strcmp(form, {'Origin+Spacing', 'Value'})) && numel(along) == 1)
    error('did2:build:ruleViolated', ...
        ['covariate_cyclic: ''Cyclic'' applies only to an ''Origin''+''Spacing'' or a ' ...
         '''Value'' (quantity) covariate along exactly one dimension; got ''%s'' along %d.'], ...
        form, numel(along));
end

% ---- the entry -----------------------------------------------------------
s = struct('variable', {variable});
if ~isAbsent(options.Unit);        s.unit = options.Unit;               end
if ~isAbsent(options.SourceUnit);  s.source_unit = options.SourceUnit;  end
if ~isAbsent(options.Approximate); s.approximate = options.Approximate; end
s.along = along;
switch form
    case 'Origin+Spacing'
        s.origin = pair(options.Origin, options.SourceOrigin);
        s.spacing = pair(options.Spacing, options.SourceSpacing);
    case 'Value'
        mustBeNumbers(options.Value, 'Value');
        s.quantity = struct('value', positions(options.Value, along));
        if ~isAbsent(options.SourceValue)
            mustBeNumbers(options.SourceValue, 'SourceValue');
            if ~isequal(size(positions(options.SourceValue, along)), size(s.quantity.value))
                error('did2:build:ruleViolated', ...
                    'covariate_shape: ''SourceValue'' has %d values, ''Value'' %d.', ...
                    numel(options.SourceValue), numel(options.Value));
            end
            s.quantity.source_value = positions(options.SourceValue, along);
        end
    case 'Count'
        mustBeNumbers(options.Count, 'Count');
        s.count = positions(options.Count, along);
    case 'Term'
        t = options.Term;
        if ischar(t) || isstring(t) || iscellstr(t)
            t = did2.build.label(cellstr(t));
        end
        if ~isstruct(t)
            error('did2:build:typeMismatch', ...
                '''Term'' is a struct array of terms or a cellstr of names.');
        end
        s.term = positions(t, along);
    case 'Text'
        t = options.Text;
        if ischar(t)
            t = {t};
        end
        if ~(iscellstr(t) || isstring(t))
            error('did2:build:typeMismatch', '''Text'' is a cellstr (one string per position).');
        end
        s.text = positions(cellstr(t), along);
    case 'Logical'
        v = options.Logical;
        if ~(islogical(v) || (isnumeric(v) && all(v(:) == 0 | v(:) == 1)))
            error('did2:build:typeMismatch', '''Logical'' is true/false (or 0/1) per position.');
        end
        s.logical = positions(logical(v), along);
    case 'Matrix'
        v = options.Matrix;
        if ~((isnumeric(v) || islogical(v)) && isreal(v))
            error('did2:build:typeMismatch', '''Matrix'' is a real numeric array.');
        end
        s.matrix = double(v);
    case 'Key'
        v = options.Key;
        if ~(isnumeric(v) && isscalar(v) && v >= 0 && v == round(v))
            error('did2:build:typeMismatch', ...
                '''Key'' is ONE 0-based index among the document''s `key_id` entries.');
        end
        s.(schemaCache(options.SchemaCache).covariateKeyField()) = double(v);
end
if ~isAbsent(options.Cyclic);  s.cyclic = options.Cyclic;  end

c = did2.build.composite('data', 'covariates', s, 'SchemaCache', options.SchemaCache);
end

function p = pair(value, source)
if ~(isnumeric(value) && isscalar(value))
    error('did2:build:typeMismatch', '''Origin''/''Spacing'' are numbers.');
end
p = struct('value', double(value));
if ~isAbsent(source)
    p.source_value = source;
end
end

function v = positions(v, along)
% Along one dimension the positions are a row (JSON: a flat list); along
% several, the array keeps its shape (extents of ALONG, in that order).
if numel(along) == 1
    v = reshape(v, 1, []);
end
end

function mustBeNumbers(v, name)
if ~((isnumeric(v) || islogical(v)) && isreal(v))
    error('did2:build:typeMismatch', '''%s'' is numeric.', name);
end
end

function tf = isTrue(v)
tf = ~isempty(v) && (islogical(v) || isnumeric(v)) && all(v(:));
end
