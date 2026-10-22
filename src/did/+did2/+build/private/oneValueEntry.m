function s = oneValueEntry(variable, forms, opts, ruleName)
%ONEVALUEENTRY The fields of a one-value entry: a condition or a parameter.
%
%   S = oneValueEntry(VARIABLE, FORMS, OPTS, RULENAME) builds the struct shared
%   by a statement's `conditions` and a method's `parameters` list (data_body
%   AMENDMENT 3): {variable, unit, source_unit, approximate} plus exactly ONE
%   value form, holding ONE value:
%
%     term       a term (or a name)                  OPTS.Term
%     quantity   {value, source_value}               OPTS.Value (+ SourceValue)
%     count      an integer                          OPTS.Count
%     text       char                                OPTS.Text
%     matrix     a numeric N-D array, as ONE value   OPTS.Matrix
%
%   MATRIX (data_body AMENDMENT 4, did-schema #88) holds a whole numeric
%   array -- a colour palette n x 3, a weight vector, a 35-number seed -- as
%   ONE value of VARIABLE, in Unit. It carries no SourceValue (an array has no
%   source spelling to keep). It is stored as double, its shape kept: did2's
%   JSON writer (did2.document/toJSON) writes it row-major as nested arrays
%   with every dimension present, so a 1xN row, an Nx1 column and an n x 3
%   palette each read back as they were written. A logical array is stored as
%   0/1 doubles.
%
%   SourceValue is stored as TEXT. Give the source's own spelling when there
%   is one; a number is written as the shortest decimal that reads back to it.
%
%   FORMS lists the option names the caller offers, in its preferred order
%   (the first form given wins its name in error messages). OPTS also carries
%   SourceValue (the text the source wrote for the number, kept verbatim),
%   Unit, SourceUnit and Approximate. RULENAME names the rule an error cites
%   ('conditions_one_value' or 'parameter_one_form').
%
%   Fields that are not given are left out. The result is not yet checked
%   against the schema; the caller passes it to did2.build.composite.

arguments
    variable
    forms (1,:) cell
    opts (1,1) struct
    ruleName (1,:) char
end

if iscell(variable) || (isstruct(variable) && ~isscalar(variable)) ...
        || (isstring(variable) && ~isscalar(variable))
    error('did2:build:typeMismatch', ...
        'The variable is one term: a name or a scalar {node, name} struct.');
end

given = forms(cellfun(@(f) ~isAbsent(opts.(f)), forms));
if numel(given) ~= 1
    error('did2:build:ruleViolated', ...
        '%s: give exactly one of %s; got %d.', ruleName, ...
        strjoin(strcat('''', forms, ''''), ', '), numel(given));
end
form = given{1};
one = opts.(form);
switch form
    case 'Term'
        isOne = ischar(one) || (isstring(one) && isscalar(one)) || (isstruct(one) && isscalar(one));
    case 'Matrix'
        % the whole array is ONE value of the variable, whatever its size
        if ~((isnumeric(one) || islogical(one)) && isreal(one))
            error('did2:build:typeMismatch', ...
                '%s: ''Matrix'' is a real numeric array.', ruleName);
        end
        isOne = true;
    case 'Text'
        isOne = (ischar(one) && size(one, 1) <= 1) || (isstring(one) && isscalar(one));
        if ~isOne
            error('did2:build:typeMismatch', '%s: ''Text'' is one char row.', ruleName);
        end
    otherwise   % Value, Quantity, Count
        if ~(isnumeric(one) || islogical(one))
            error('did2:build:typeMismatch', '%s: ''%s'' is a number.', ruleName, form);
        end
        isOne = isscalar(one);
end
if ~isOne
    error('did2:build:ruleViolated', ...
        '%s: an entry holds ONE value; ''%s'' has %d. Use a covariate along a dimension for more.', ...
        ruleName, form, numel(one));
end
numeric = any(strcmp(form, {'Value', 'Quantity'}));
if ~isAbsent(opts.SourceValue)
    if ~numeric
        error('did2:build:ruleViolated', ...
            '''SourceValue'' applies only to a number (''%s''); a ''Matrix'' carries none.', ...
            strjoin(intersect(forms, {'Value', 'Quantity'}, 'stable'), ''' / '''));
    end
    if (isnumeric(opts.SourceValue) || islogical(opts.SourceValue)) && isscalar(opts.SourceValue)
        opts.SourceValue = numberText(double(opts.SourceValue));
    elseif ~(ischar(opts.SourceValue) || (isstring(opts.SourceValue) && isscalar(opts.SourceValue)))
        error('did2:build:typeMismatch', ...
            '''SourceValue'' is the text the source wrote ("1e-3", "0.030"), or one number.');
    end
end
if (~isAbsent(opts.Unit) || ~isAbsent(opts.SourceUnit)) && ~(numeric || any(strcmp(form, {'Count', 'Matrix'})))
    error('did2:build:ruleViolated', ...
        '''Unit''/''SourceUnit'' apply only to a number, a count or a matrix.');
end

s = struct('variable', {variable});
if ~isAbsent(opts.Unit);        s.unit = opts.Unit;               end
if ~isAbsent(opts.SourceUnit);  s.source_unit = opts.SourceUnit;  end
if ~isAbsent(opts.Approximate); s.approximate = opts.Approximate; end
switch form
    case 'Term'
        s.term = one;
    case 'Count'
        s.count = one;
    case 'Text'
        s.text = char(one);
    case 'Matrix'
        s.matrix = double(one);
    otherwise
        q = struct('value', one);
        if ~isAbsent(opts.SourceValue)
            q.source_value = char(opts.SourceValue);
        end
        s.quantity = q;
end
end

function t = numberText(x)
%NUMBERTEXT The shortest decimal text (up to 17 significant digits) that reads
%   back as X.
arguments
    x (1,1) double
end

for digits = 15:17
    t = num2str(x, digits);
    if str2double(t) == x || isnan(x)
        return;
    end
end
end
