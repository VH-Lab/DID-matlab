function harmonicSchema(testCase, declared)
%HARMONICSCHEMA Run the rest of a test on a copy of the loaded schema that
%   declares (or does not declare) the integer `harmonic` of tuning_curve.value
%   and contrast_sensitivity.value.
%
%   did2.unittest.helpers.harmonicSchema(TESTCASE, DECLARED)
%
%   [harmonic is a field beside the response type] (Decided by Jess Haley,
%   2026-11-17, did-schema docs/plans/did_v2_go_forward_class_audit.md): both
%   values gain an integer `harmonic` (1 = F1, 2 = F2) beside the response
%   type. DID-matlab writes it only once the loaded schema declares it
%   (+migrators_j/private/jResponseType.m, siblings first), and DID-matlab CI
%   reads did-schema `main`, which may not declare it yet. So that BOTH shapes
%   are exercised whatever `main` holds, this helper copies the loaded schema
%   folder and, in the copy, for both classes:
%
%     DECLARED true    adds `harmonic` (an integer, blank and default [])
%                      before `response_type`, unless the copy declares it;
%     DECLARED false   removes the `harmonic` declaration, if any.
%
%   It points the schema cache at the copy, asserts the copy reads as
%   DECLARED (did2.unittest.helpers.schemaDeclares), and registers teardowns
%   that point the cache back and delete the copy. The declaration is edited
%   as text (as interpolatedListSchema does), so nothing else in the file
%   moves.

declared = logical(declared);
src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
classes = {'tuning_curve', 'contrast_sensitivity'};
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
    assertEqual(testCase, did2.unittest.helpers.schemaDeclares(classes{k}, ...
        {'value', 'harmonic'}), declared, [classes{k} ...
        ': the copy does not read as declared = ' mat2str(declared)]);
end
end

function t = rewrite(testCase, t, declared, cls)
h = regexp(t, '"name"\s*:\s*"harmonic"', 'once');
if declared
    if ~isempty(h)
        return;
    end
    r = regexp(t, '"name"\s*:\s*"response_type"');
    assertEqual(testCase, numel(r), 1, [cls ': expected one response_type declaration']);
    a = find(t(1:r - 1) == '{', 1, 'last');
    decl = ['{"name": "harmonic", "type": "integer", "blank_value": [], ' ...
        '"default_value": [], "mustBeNonEmpty": false, "mustBeScalar": true, ' ...
        '"mustNotHaveNaN": false, "queryable": true, "ontology": null, ' ...
        '"documentation": "declared by the test helper harmonicSchema ' ...
        '([harmonic is a field beside the response type])", "constraints": {}}, '];
    t = [t(1:a - 1) decl t(a:end)];
elseif ~isempty(h)
    a = find(t(1:h - 1) == '{', 1, 'last');
    b = closing(t, a);
    after = b + find(~isspace(t(b + 1:end)), 1);
    if t(after) == ','
        t = [t(1:a - 1) t(after + 1:end)];
    else
        before = find(~isspace(t(1:a - 1)), 1, 'last');
        if t(before) == ','
            t = [t(1:before - 1) t(b + 1:end)];
        else
            t = [t(1:a - 1) t(b + 1:end)];
        end
    end
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
error('did2:unittest:harmonicSchema', 'unbalanced JSON from index %d', s);
end
