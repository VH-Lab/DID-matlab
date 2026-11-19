function tuningSummariesSchema(testCase)
%TUNINGSUMMARIESSCHEMA Run the rest of a test on a copy of the loaded schema
%   that declares the tuning summaries in `tuning_curve.value`.
%
%   did2.unittest.helpers.tuningSummariesSchema(TESTCASE)
%
%   [tuning summaries in the value] (Decided by Jess Haley, 2026-11-10,
%   did-schema did_v2_go_forward_class_audit.md): `circular_statistics`
%   (orientation/direction) and `interpolated_values` (the four tuning
%   calculators) move from the calculator classes into `tuning_curve.value`,
%   beside model_fit and significance; `interpolated_values` becomes ONE list
%   whose fields are the union of what the calculators write. DID-matlab
%   writes and reads whichever place the loaded schema declares, and its CI
%   reads did-schema `main`, which declares them on the calculators until
%   did-schema moves them. So that both places are exercised in every CI run,
%   this copies the loaded schema flat to a temporary folder and, in the copy,
%   as text (so nothing else moves):
%     - cuts `circular_statistics` and `interpolated_values` out of
%       orientation_direction_tuning_calculation.json and `interpolated_values`
%       out of the spatial frequency, temporal frequency and contrast tuning
%       calculation classes;
%     - adds to tuning_curve.json's `value` the cut `circular_statistics` and
%       one `interpolated_values`: the spatial frequency calculator's list
%       (preferred value, half-maximum points, bandwidth, pass indexes,
%       response_transform) with the orientation calculator's
%       `full_width_half_height` added, the union of the four.
%   A copy that already declares both in tuning_curve.value is left as it
%   is. It then points the schema cache at the copy and registers the
%   teardowns that point it back and delete the copy.

src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
moved = did2.unittest.helpers.schemaDeclares('tuning_curve', {'value', 'circular_statistics'}) ...
    && did2.unittest.helpers.schemaDeclares('tuning_curve', {'value', 'interpolated_values'});
if ~moved
    od = readText(tmp, 'orientation_direction_tuning_calculation');
    [od, cstat] = cutField(testCase, od, 'circular_statistics');
    [od, odIv] = cutField(testCase, od, 'interpolated_values');
    writeText(tmp, 'orientation_direction_tuning_calculation', od);
    union = '';
    for c = {'spatial_frequency_tuning_calculation', ...
            'temporal_frequency_tuning_calculation', 'contrast_tuning_calculation'}
        t = readText(tmp, c{1});
        [t, iv] = cutField(testCase, t, 'interpolated_values');
        writeText(tmp, c{1}, t);
        if strcmp(c{1}, 'spatial_frequency_tuning_calculation')
            union = iv;
        end
    end
    [~, fwhh] = cutField(testCase, odIv, 'full_width_half_height');
    if isempty(regexp(union, '"name"\s*:\s*"full_width_half_height"', 'once'))
        union = insertIntoFields(testCase, union, fwhh);
    end
    tc = readText(tmp, 'tuning_curve');
    s = regexp(tc, '"name"\s*:\s*"value"', 'once');
    assertNotEmpty(testCase, s, 'tuning_curve.json declares no value');
    objStart = find(tc(1:s - 1) == '{', 1, 'last');
    objEnd = closing(tc, objStart);
    obj = insertIntoFields(testCase, tc(objStart:objEnd), cstat);
    obj = insertIntoFields(testCase, obj, union);
    writeText(tmp, 'tuning_curve', [tc(1:objStart - 1) obj tc(objEnd + 1:end)]);
end
did2.schema.cache.setSchemaPath(tmp);
% (added after the rmdir, so it runs before it)
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
for p = {{'value', 'circular_statistics', 'orientation_preference'}, ...
        {'value', 'interpolated_values', 'full_width_half_height'}, ...
        {'value', 'interpolated_values', 'low_pass_index'}, ...
        {'value', 'interpolated_values', 'response_transform'}}
    assertTrue(testCase, did2.unittest.helpers.schemaDeclares('tuning_curve', p{1}), ...
        ['the copy does not declare tuning_curve.' strjoin(p{1}, '.')]);
end
assertFalse(testCase, did2.unittest.helpers.schemaDeclares( ...
    'orientation_direction_tuning_calculation', {'interpolated_values'}), ...
    'the copy still declares interpolated_values on the calculator');
end

function t = readText(dir, cls)
t = fileread(fullfile(dir, [cls '.json']));
end

function writeText(dir, cls, t)
fid = fopen(fullfile(dir, [cls '.json']), 'w', 'n', 'UTF-8');
fwrite(fid, t, 'char');
fclose(fid);
end

function [t, obj] = cutField(testCase, t, name)
% T without the one field object named NAME (and its separating comma); OBJ
% is that object's text
s = regexp(t, ['"name"\s*:\s*"' name '"']);
assertNumElements(testCase, s, 1, sprintf('expected one %s declaration', name));
a = find(t(1:s - 1) == '{', 1, 'last');
assertTrue(testCase, ~isempty(a) && all(isspace(t(a + 1:s - 1))), ...
    sprintf('"name" is not the first key of %s', name));
b = closing(t, a);
obj = t(a:b);
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

function obj = insertIntoFields(testCase, obj, def)
% DEF as the first entry of OBJ's own `fields` list
lb = regexp(obj, '"fields"\s*:\s*\[', 'end', 'once');
assertNotEmpty(testCase, lb, 'the field has no fields list');
rest = obj(lb + 1:end);
if isempty(regexp(rest, '^\s*\]', 'once'))
    def = [def ', '];
end
obj = [obj(1:lb) def rest];
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
error('did2:unittest:tuningSummariesSchema', 'unbalanced JSON from index %d', s);
end
