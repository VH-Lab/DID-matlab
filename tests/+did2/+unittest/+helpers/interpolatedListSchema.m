function varargout = interpolatedListSchema(testCase, declared)
%INTERPOLATEDLISTSCHEMA Run the rest of a test on a copy of the loaded schema
%   that declares (or does not declare) `interpolated_values` as a list.
%
%   did2.unittest.helpers.interpolatedListSchema(TESTCASE, DECLARED)
%   [CLS, PATH] = did2.unittest.helpers.interpolatedListSchema('-path', CLASSNAME)
%
%   [interpolated values are a list] (Decided by Jess Haley, 2026-10-30,
%   did-schema V_eta_go_forward_class_audit.md): a tuning calculation's
%   `interpolated_values` becomes a LIST of entries, each with the optional
%   `response_transform` ('absolute value' on the entry read from |response|),
%   on spatial_frequency_tuning_calculation,
%   temporal_frequency_tuning_calculation, contrast_tuning_calculation and
%   contrast_sensitivity's value. DID-matlab writes the list only once the
%   loaded schema declares it (+migrators_j/private/jCalculation.m), and
%   DID-matlab CI reads did-schema `main`, which declares the one structure
%   until did-schema's side lands. So that BOTH shapes are exercised in every
%   CI run, whatever did-schema `main` holds, this helper copies the loaded
%   schema folder to a temporary folder and, in the copy, for each of the four:
%
%     DECLARED true    makes `interpolated_values` a list (mustBeScalar false,
%                      blank and default []) whose entries may state
%                      `response_transform` (char, enum ['absolute value']),
%                      the declaration did-schema is about to make; a copy
%                      already declaring it is left as it is;
%     DECLARED false   removes `response_transform` from the entries and makes
%                      the field one structure again (mustBeScalar true, blank
%                      and default {}), the declaration before the decision.
%
%   It then points the schema cache at the copy (did2.schema.cache.
%   setSchemaPath), asserts the probe the writer uses now reads DECLARED, and
%   registers teardowns that point the cache back and delete the copy. It may
%   be called more than once in a test (each call copies the schema in use).
%
%   The declaration is edited as text, the way testTuningDecisions
%   already declares a field on a copy, so the file keeps
%   did-schema's formatting and nothing else in it moves.
%
%   '-path' returns the class file holding the field and the field's path in
%   it (for interpolatedListDeclared).

if ischar(testCase) && strcmp(testCase, '-path')
    [varargout{1}, varargout{2}] = pathOf(declared);
    return;
end
declared = logical(declared);
src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
classes = {'spatial_frequency_tuning_calculation', ...
    'temporal_frequency_tuning_calculation', 'contrast_tuning_calculation', ...
    'contrast_sensitivity'};
for k = 1:numel(classes)
    file = fullfile(tmp, [classes{k} '.json']);
    assertTrue(testCase, isfile(file), [classes{k} '.json is not in the schema in use']);
    t = fileread(file);
    t = rewrite(testCase, t, declared, classes{k});
    fid = fopen(file, 'w', 'n', 'UTF-8');
    fwrite(fid, t, 'char');
    fclose(fid);
end
did2.schema.cache.setSchemaPath(tmp);
% (added after the rmdir, so it runs before it)
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
for k = 1:numel(classes)
    assertEqual(testCase, did2.unittest.helpers.interpolatedListDeclared(classes{k}), ...
        declared, [classes{k} ': the copy does not read as declared = ' mat2str(declared)]);
end
end

function [cls, path] = pathOf(className)
switch className
    case {'contrast_sensitivity', 'contrast_sensitivity_calculation'}
        cls = 'contrast_sensitivity';
        path = {'value', 'interpolated_values'};
    otherwise
        cls = className;
        path = {'interpolated_values'};
end
end

function t = rewrite(testCase, t, declared, cls)
% the one `interpolated_values` field declaration in T, rewritten
s = regexp(t, '"name"\s*:\s*"interpolated_values"');
assertEqual(testCase, numel(s), 1, [cls ': expected one interpolated_values declaration']);
objStart = find(t(1:s - 1) == '{', 1, 'last');
assertTrue(testCase, ~isempty(objStart) && all(isspace(t(objStart + 1:s - 1))), ...
    [cls ': "name" is not the first key of interpolated_values']);
objEnd = closing(t, objStart);
obj = t(objStart:objEnd);
lb = regexp(obj, '"fields"\s*:\s*\[', 'end', 'once');
assertNotEmpty(testCase, lb, [cls ': interpolated_values has no fields list']);
head = obj(1:lb - 1);
rb = closing(obj, lb);
list = obj(lb:rb);
tail = obj(rb + 1:end);
if declared
    head = setKey(head, 'mustBeScalar', 'false');
    head = setKey(head, 'blank_value', '[]');
    head = setKey(head, 'default_value', '[]');
    if isempty(regexp(list, '"name"\s*:\s*"response_transform"', 'once'))
        decl = ['{"name": "response_transform", "type": "char", "blank_value": "", ' ...
            '"default_value": "", "mustBeNonEmpty": false, "mustBeScalar": true, ' ...
            '"mustNotHaveNaN": false, "queryable": true, "ontology": null, ' ...
            '"documentation": "declared by the test helper interpolatedListSchema ' ...
            '([interpolated values are a list])", ' ...
            '"constraints": {"enum": ["absolute value"]}}, '];
        list = [list(1) decl list(2:end)];
    end
else
    head = setKey(head, 'mustBeScalar', 'true');
    head = setKey(head, 'blank_value', '{}');
    head = setKey(head, 'default_value', '{}');
    n = regexp(list, '"name"\s*:\s*"response_transform"', 'once');
    if ~isempty(n)
        a = find(list(1:n - 1) == '{', 1, 'last');
        b = closing(list, a);
        after = b + find(~isspace(list(b + 1:end)), 1);
        if list(after) == ','
            list = [list(1:a - 1) list(after + 1:end)];
        else
            before = find(~isspace(list(1:a - 1)), 1, 'last');
            if list(before) == ','
                list = [list(1:before - 1) list(b + 1:end)];
            else
                list = [list(1:a - 1) list(b + 1:end)];
            end
        end
    end
end
t = [t(1:objStart - 1) head list tail t(objEnd + 1:end)];
end

function h = setKey(h, key, value)
% KEY's value in the field header H (a scalar JSON value: true/false, {} or [])
% (spliced, not regexprep'd: a replacement holding '{' or '$' is not literal)
ext = regexp(h, ['"' key '"\s*:\s*(true|false|\{\s*\}|\[\s*\]|null)'], ...
    'tokenExtents', 'once');
if ~isempty(ext)
    h = [h(1:ext(1) - 1) value h(ext(2) + 1:end)];
end
end

function e = closing(t, s)
% the index of the bracket closing the one at S, skipping JSON strings
depth = 0;
inStr = false;
esc = false;
for i = s:numel(t)
    c = t(i);
    if inStr
        if esc
            esc = false;
        elseif c == '\'
            esc = true;
        elseif c == '"'
            inStr = false;
        end
        continue;
    end
    if c == '"'
        inStr = true;
    elseif c == '{' || c == '['
        depth = depth + 1;
    elseif c == '}' || c == ']'
        depth = depth - 1;
        if depth == 0
            e = i;
            return;
        end
    end
end
error('did2:unittest:interpolatedListSchema', 'unbalanced JSON from index %d', s);
end
