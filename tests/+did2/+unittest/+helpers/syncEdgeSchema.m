function syncEdgeSchema(testCase)
%SYNCEDGESCHEMA Run the rest of a test on a copy of the loaded schema whose
%   clock_alignment_configuration names its rigs `input_id` / `output_id`.
%
%   did2.unittest.helpers.syncEdgeSchema(TESTCASE)
%
%   [sync configuration edges are input and output] (Decided by Jess Haley,
%   2026-11-10, did-schema did_v2_go_forward_class_audit.md): the edges
%   `from_acquisition_system_id` / `to_acquisition_system_id` become
%   `input_id` / `output_id`. DID-matlab writes whichever the loaded schema
%   declares (+migrators_j/syncrule.m systemEdgeNames) and DID-matlab CI reads
%   did-schema `main`, which declares the from / to names until did-schema
%   renames them. So that both are exercised in every CI run, this copies the
%   loaded schema flat to a temporary folder, renames the two edges in the
%   copy's clock_alignment_configuration.json (as text; a copy already
%   renamed is left as it is), points the schema cache at the copy, and
%   registers the teardowns that point it back and delete the copy.

src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
f = fullfile(tmp, 'clock_alignment_configuration.json');
assertTrue(testCase, isfile(f), 'clock_alignment_configuration.json is not in the schema in use');
txt = fileread(f);
txt = regexprep(txt, '"name"\s*:\s*"from_acquisition_system_id"', '"name": "input_id"');
txt = regexprep(txt, '"name"\s*:\s*"to_acquisition_system_id"', '"name": "output_id"');
fid = fopen(f, 'w', 'n', 'UTF-8');
fwrite(fid, txt, 'char');
fclose(fid);
did2.schema.cache.setSchemaPath(tmp);
% (added after the rmdir, so it runs before it)
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
[inEdge, outEdge] = did2.unittest.helpers.syncEdgeNames();
assertEqual(testCase, {inEdge, outEdge}, {'input_id', 'output_id'}, ...
    'the copy does not declare input_id / output_id');
end
