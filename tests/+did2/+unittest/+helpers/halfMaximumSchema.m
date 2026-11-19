function halfMaximumSchema(testCase)
%HALFMAXIMUMSCHEMA Run the rest of a test on a copy of the loaded schema whose
%   contrast_sensitivity spells the half-maximum point `half_maximum_below`.
%
%   did2.unittest.helpers.halfMaximumSchema(TESTCASE)
%
%   [one spelling for the half-maximum point] (Decided by Jess Haley,
%   2026-11-10, did-schema did_v2_go_forward_class_audit.md):
%   contrast_sensitivity's `value.interpolated_values.c50` and
%   `value.model_fit.c50` become `half_maximum_below`. DID-matlab follows
%   first and writes whichever name the loaded schema declares
%   (+migrators_j/private/jContrastSensitivityValue.m); DID-matlab CI reads
%   did-schema `main`, which says `c50` until did-schema renames the two
%   fields. So that BOTH spellings are exercised in every CI run, this copies
%   the loaded schema flat to a temporary folder, renames the two fields in
%   the copy's contrast_sensitivity.json (as text, so nothing else moves; a
%   copy already renamed is left as it is), points the schema cache at the
%   copy, and registers the teardowns that point it back and delete the copy.

src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
f = fullfile(tmp, 'contrast_sensitivity.json');
assertTrue(testCase, isfile(f), 'contrast_sensitivity.json is not in the schema in use');
txt = fileread(f);
n = numel(regexp(txt, '"name"\s*:\s*"c50"'));
assertTrue(testCase, n == 2 || (n == 0 && ...
    numel(regexp(txt, '"name"\s*:\s*"half_maximum_below"')) == 2), ...
    sprintf('contrast_sensitivity.json declares %d `c50` fields; expected 2 (or none, renamed)', n));
txt = regexprep(txt, '"name"\s*:\s*"c50"', '"name": "half_maximum_below"');
fid = fopen(f, 'w', 'n', 'UTF-8');
fwrite(fid, txt, 'char');
fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
% (added after the rmdir, so it runs before it)
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
for b = {'interpolated_values', 'model_fit'}
    assertTrue(testCase, did2.unittest.helpers.schemaDeclares('contrast_sensitivity', ...
        {'value', b{1}, 'half_maximum_below'}), ...
        ['the copy does not declare value.' b{1} '.half_maximum_below']);
end
end
