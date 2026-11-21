function acquisitionConfigurationSchema(testCase)
%ACQUISITIONCONFIGURATIONSCHEMA Run the rest of a test on a copy of the loaded
%   schema in which `acquisition_system` is renamed `acquisition_configuration`.
%
%   did2.unittest.helpers.acquisitionConfigurationSchema(TESTCASE)
%
%   Decided by Jess Haley, 2026-11-19 [acquisition configuration renamed]
%   (did-schema docs/plans/did_v2_standing_wiring_plan.md): the class is
%   renamed. DID-matlab writes whichever name the loaded schema holds
%   (did2.convert.acquisitionConfigurationClass) and DID-matlab CI reads
%   did-schema `main`, which holds the old name until did-schema renames it.
%   So that both are exercised in every CI run, this copies the loaded schema
%   flat to a temporary folder, renames the class there (its file, and the
%   whole word `acquisition_system` in every copied file: the class name, the
%   `must_refer_to_document_class` lists, the relation parent types; edge
%   names such as `acquisition_system_id` are not the word and stay), points
%   the schema cache at the copy, and registers the teardowns that point it
%   back and delete the copy. A copy already renamed is left as it is.
%   As did2.unittest.helpers.syncEdgeSchema does for the sync edges.

src = did2.schema.cache.shared().schemaPath;
tmp = tempname;
mkdir(tmp);
testCase.addTeardown(@() rmdir(tmp, 's'));
did2.schema.cache.copySchemaSet(src, tmp);
old = fullfile(tmp, 'acquisition_system.json');
new = fullfile(tmp, 'acquisition_configuration.json');
if isfile(old) && ~isfile(new)
    movefile(old, new);
end
assertTrue(testCase, isfile(new), 'neither acquisition_system.json nor acquisition_configuration.json is in the schema in use');
files = dir(fullfile(tmp, '*.json'));
for k = 1:numel(files)
    f = fullfile(files(k).folder, files(k).name);
    txt = fileread(f);
    out = regexprep(txt, '(?<![A-Za-z0-9_])acquisition_system(?![A-Za-z0-9_])', 'acquisition_configuration');
    if ~strcmp(out, txt)
        fid = fopen(f, 'w', 'n', 'UTF-8');
        fwrite(fid, out, 'char');
        fclose(fid);
    end
end
did2.schema.cache.setSchemaPath(tmp);
% (added after the rmdir, so it runs before it)
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
assertEqual(testCase, did2.convert.acquisitionConfigurationClass(), 'acquisition_configuration', ...
    'the copy does not declare acquisition_configuration');
end
