function path = compressionBlockSchema(testCase)
%COMPRESSIONBLOCKSCHEMA Point the schema cache at a schema that declares
%   `data_body.compression` as the {term, parameters} block.
%
%   PATH = did2.unittest.helpers.compressionBlockSchema(TESTCASE)
%
%   [compression block and empty levels] (1) (Decided by Jess Haley,
%   2026-10-26, did-schema V_eta_go_forward_class_audit.md; did-schema issue
%   #137): `compression` becomes a {term, parameters} block, the shape
%   `method` uses. did-schema changes the type after DID-matlab and NDI-matlab
%   (siblings first), so until then this copies the loaded schema to a
%   temporary folder and declares the block there: data_body.json's
%   `compression` declaration is replaced by interaction.json's `method`
%   declaration, renamed. When the loaded schema already declares the block,
%   nothing is copied and its own path is returned.
%
%   The schema path and the copy are restored and removed by TESTCASE's
%   teardown. Skips (assumeFail) when the loaded schema has no data_body.json
%   or no interaction `method` block to copy (before did-schema #88).

arguments
    testCase (1,1) matlab.unittest.TestCase
end

cache = did2.schema.cache.shared();
src = cache.schemaPath;
path = src;
if did2.build.compressionBlockDeclared(cache)
    return;   % did-schema has declared it: test the real thing
end
% found at any depth: did-schema's family layout ([schema folders by family])
files = did2.schema.cache.classFilesIn(src);
dataBody = ''; interaction = '';
if files.isKey('data_body'); dataBody = files('data_body'); end
if files.isKey('interaction'); interaction = files('interaction'); end
if ~isfile(dataBody) || ~isfile(interaction)
    assumeFail(testCase, sprintf(['the loaded schema (%s) has no data_body.json or ' ...
        'interaction.json to declare the compression block from'], src));
end

ia = jsondecode(fileread(interaction));
defs = ia.fields;
if isstruct(defs); defs = num2cell(reshape(defs, 1, [])); end
hit = cellfun(@(d) isstruct(d) && isfield(d, 'name') && strcmp(char(d.name), 'method'), defs);
if ~any(hit)
    assumeFail(testCase, 'the loaded interaction.json declares no `method` block (before did-schema #88)');
end
decl = defs{find(hit, 1)};
decl.name = 'compression';
decl.documentation = ['declared for this test: [compression block and empty levels] ' ...
    '(1), the codec as a term, its settings as parameters'];

txt = fileread(dataBody);
old = regexp(txt, ['\{\s*"name"\s*:\s*"compression"\s*,\s*"type"\s*:\s*"char"' ...
    '[^{}]*"constraints"\s*:\s*\{\}\s*\}'], 'match', 'once');
assertNotEmpty(testCase, old, ...
    'data_body.json declares no char `compression` to replace (has the declaration changed?)');

path = tempname;
mkdir(path);
testCase.addTeardown(@() rmdir(path, 's'));
did2.schema.cache.copySchemaSet(src, path);
fid = fopen(fullfile(path, 'data_body.json'), 'w');
fwrite(fid, strrep(txt, old, jsonencode(decl)));
fclose(fid);
did2.schema.cache.setSchemaPath(path);
testCase.addTeardown(@() did2.schema.cache.setSchemaPath(src));
assertTrue(testCase, did2.build.compressionBlockDeclared(), ...
    'the copy does not declare the compression block');
end
