function tests = testCompressionBlock
%TESTCOMPRESSIONBLOCK A body's `compression`: a codec name, or the {term,
%   parameters} block, read in both shapes and written in the one the schema
%   declares.
%
%   [compression block and empty levels] (1) (Decided by Jess Haley,
%   2026-10-26, did-schema V_eta_go_forward_class_audit.md; did-schema issue
%   #137): `data_body.compression`, a `char` holding a codec name, becomes a
%   {term, parameters} block, the shape `method` uses -- the codec as a term,
%   its settings as parameters. Siblings first (did-schema CLAUDE.md section
%   3, rule 2): readers here accept both shapes (did2.build.compressionCodec),
%   and writers write the block only once the loaded schema declares it
%   (did2.build.compressionBlockDeclared; did2.build.compression).
%
%   The char tests run on the loaded schema while it types `compression` as
%   char; the block tests run on a copy that declares the block
%   (did2.unittest.helpers.compressionBlockSchema), or on the loaded schema
%   once did-schema declares it.
%
%   UNVERIFIED: written without MATLAB (none in the authoring environment);
%   CI is the first place these run.
%
%   Run with:  results = runtests('did2.unittest.testCompressionBlock');

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
did2.unittest.helpers.installSchemaPath(testCase, 'skipping compression block tests');
% made-up ids and unregistered codec terms: the builder's mechanics are tested
% here, not the term registry (testBuildTermRegistry tests that)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
cache = did2.schema.cache.shared();
if ~cache.hasClass('opaque_body') || ~cache.hasClass('sampled_body')
    assumeFail(testCase, sprintf('the loaded schema (%s) has no body classes', cache.schemaPath));
end
testCase.TestData.sid = did.ido.unique_id();
end

function teardownOnce(testCase)
did2.unittest.helpers.restoreSchemaPath(testCase);
end

% ===================== reading: both shapes ================================

function testTheReaderReadsACodecName(testCase)
[c, s] = did2.build.compressionCodec('gzip');
verifyEqual(testCase, c, 'gzip');
verifyEmpty(testCase, fieldnames(s));
[c, s] = did2.build.compressionCodec('');
verifyEqual(testCase, c, '');
verifyEmpty(testCase, fieldnames(s));
[c, ~] = did2.build.compressionCodec([]);
verifyEqual(testCase, c, '');
end

function testTheReaderReadsABlock(testCase)
% written by hand, as a stored V_eta document holds it: no schema needed
blk = struct('term', struct('node', '', 'name', 'Blosc'), 'parameters', {{ ...
    struct('variable', struct('node', '', 'name', 'inner compressor'), 'text', 'zstd'), ...
    struct('variable', struct('node', '', 'name', 'compression level'), 'count', 5), ...
    struct('variable', struct('node', '', 'name', 'shuffle'), 'count', 1), ...
    struct('variable', struct('node', '', 'name', 'block size'), 'count', 0)}});
[c, s] = did2.build.compressionCodec(blk);
verifyEqual(testCase, c, 'blosc-zstd', 'Blosc with inner compressor zstd is v1''s blosc-zstd');
verifyEqual(testCase, fieldnames(s)', {'cname', 'clevel', 'shuffle', 'blocksize'});
verifyEqual(testCase, jsonencode(s), '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}', ...
    'the settings read back as NDI makePyramid.m codecParamsJSON writes them');
[c, s] = did2.build.compressionCodec(struct('term', struct('node', '', 'name', 'gzip')));
verifyEqual(testCase, c, 'gzip');
verifyEmpty(testCase, fieldnames(s));
% a term the table does not know reads as its own name
[c, ~] = did2.build.compressionCodec(struct('term', struct('node', '', 'name', 'bzip2')));
verifyEqual(testCase, c, 'bzip2');
end

% ===================== writing: the char schema ============================

function testACharSchemaGetsTheCodecName(testCase)
assumeFalse(testCase, did2.build.compressionBlockDeclared(), ...
    'the loaded schema declares the block; the char shape is no longer written');
verifyEqual(testCase, did2.build.compression('gzip'), 'gzip');
verifyEqual(testCase, did2.build.compression('blosc-zstd'), 'blosc-zstd', 'verbatim');
verifyEmpty(testCase, did2.build.compression(''));
% the inner compressor the spelling names is not a setting beyond the name
verifyEqual(testCase, did2.build.compression('blosc-zstd', 'Settings', ...
    struct('cname', 'zstd')), 'blosc-zstd');
verifyError(testCase, @() did2.build.compression('blosc-zstd', 'Settings', ...
    struct('cname', 'zstd', 'clevel', 5)), 'did2:build:compressionSettingsNotDeclared');
verifyError(testCase, @() did2.build.compression('blosc-zstd', 'Settings', ...
    struct('cname', 'lz4')), 'did2:build:compressionConflict');
body = did2.build.opaqueBody(did.ido.unique_id(), 'EDAM:format_2333', ...
    'Compression', 'gzip', 'SessionId', testCase.TestData.sid);
verifyEqual(testCase, body.data_body.compression, 'gzip');
end

% ===================== writing: the block schema ===========================

function testABlockSchemaGetsTermAndParameters(testCase)
did2.unittest.helpers.compressionBlockSchema(testCase);
c = did2.build.compression('blosc-zstd', 'Settings', ...
    '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}');
verifyEqual(testCase, c.term.name, 'Blosc', 'the codec alone is the term');
p = c.parameters;
if isstruct(p); p = num2cell(p); end
verifyEqual(testCase, numel(p), 4);
verifyEqual(testCase, cellfun(@(e) char(e.variable.name), p, 'UniformOutput', false), ...
    {'inner compressor', 'compression level', 'shuffle', 'block size'});
% [compression terms registered] (Jess Haley, 2026-11-01): the inner
% compressor is a term, Zstandard (wikidata:Q26737171) once registered
verifyTrue(testCase, isfield(p{1}, 'term'), 'the inner compressor is a term');
verifyTrue(testCase, any(strcmp(char(p{1}.term.name), {'Zstandard'})) ...
    || strcmp(char(p{1}.term.node), 'wikidata:Q26737171'), char(p{1}.term.name));
verifyEqual(testCase, double(p{2}.count), 5);
% and it reads back as written
[codec, s] = did2.build.compressionCodec(c);
verifyEqual(testCase, codec, 'blosc-zstd');
verifyEqual(testCase, jsonencode(s), '{"cname":"zstd","clevel":5,"shuffle":1,"blocksize":0}');
% a codec name alone: the term, no parameters (but a Blosc spelling's own
% inner compressor)
g = did2.build.compression('gzip');
% the table's name, or the registered EDAM:format_3989 "GZIP format" (whose
% synonym is gzip) once did-schema registers it ([compression terms registered])
verifyTrue(testCase, strcmp(char(g.term.name), 'gzip') ...
    || strcmp(char(g.term.node), 'EDAM:format_3989'), char(g.term.name));
verifyFalse(testCase, isfield(g, 'parameters') && ~isempty(g.parameters));
b = did2.build.compression('blosc-zstd');
verifyEqual(testCase, did2.build.compressionCodec(b), 'blosc-zstd');
% an old char value read from a document is re-written as the block
lzw = did2.build.compression(did2.build.compression('lzw'));
verifyTrue(testCase, strcmp(char(lzw.term.name), 'LZW') ...
    || strcmp(char(lzw.term.node), 'wikidata:Q2681'), char(lzw.term.name));
verifyEqual(testCase, did2.build.compressionCodec(lzw), 'lzw');
end

function testBodyBuildersWriteTheBlock(testCase)
did2.unittest.helpers.compressionBlockSchema(testCase);
sid = testCase.TestData.sid;
body = did2.build.opaqueBody(did.ido.unique_id(), 'EDAM:format_2333', ...
    'Compression', 'gzip', 'SessionId', sid);   % validated by the builder
verifyTrue(testCase, isstruct(body.data_body.compression));
verifyEqual(testCase, did2.build.compressionCodec(body.data_body.compression), 'gzip');
% a char where the schema declares the block is refused by the validator
bad = body;
bad.data_body.compression = 'gzip';
verifyError(testCase, @() did2.schema.cache.shared().validateDocument(bad), ?MException);
% a body with no compression has none
plain = did2.build.opaqueBody(did.ido.unique_id(), 'EDAM:format_2333', 'SessionId', sid);
verifyFalse(testCase, isfield(plain.data_body, 'compression') && ~isempty(plain.data_body.compression));
end
