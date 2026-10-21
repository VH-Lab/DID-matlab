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
        '%s: an entry holds ONE value; ''%s'' has %d. Use a key for more.', ...
        ruleName, form, numel(one));
end
numeric = any(strcmp(form, {'Value', 'Quantity'}));
if ~isAbsent(opts.SourceValue)
    if ~numeric
        error('did2:build:ruleViolated', '''SourceValue'' applies only to a number (''%s'').', ...
            strjoin(intersect(forms, {'Value', 'Quantity'}, 'stable'), ''' / '''));
    end
    if (isnumeric(opts.SourceValue) || islogical(opts.SourceValue)) && isscalar(opts.SourceValue)
        opts.SourceValue = numberText(double(opts.SourceValue));
    elseif ~(ischar(opts.SourceValue) || (isstring(opts.SourceValue) && isscalar(opts.SourceValue)))
        error('did2:build:typeMismatch', ...
            '''SourceValue'' is the text the source wrote ("1e-3", "0.030"), or one number.');
    end
end
if (~isAbsent(opts.Unit) || ~isAbsent(opts.SourceUnit)) && ~(numeric || strcmp(form, 'Count'))
    error('did2:build:ruleViolated', ...
        '''Unit''/''SourceUnit'' apply only to a number or a count.');
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
