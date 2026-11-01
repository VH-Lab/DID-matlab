function tests = testSchemaSetNames
%TESTSCHEMASETNAMES The V2 schema set answers to both its names.
%
%   Decided by Jess Haley, 2026-10-25 [schema set renamed did_v2] (did-schema
%   V_eta_go_forward_class_audit.md): the set named `V_eta` is renamed
%   `did_v2`, siblings first -- step 1, built here, is "accept both names":
%   every TargetVersion check takes 'did_v2' as well as 'V_eta', and a reader
%   of the set by path takes schemas/did_v2/<tier>, preferring it when present,
%   else schemas/V_eta/<tier>.

tests = functiontests(localfunctions);
end

function setupOnce(testCase)
prev = did2.schema.cache.strictMode('TermRegistry', false);
testCase.addTeardown(@() did2.schema.cache.strictMode('TermRegistry', prev));
end

function testBothNamesAreTheV2Set(testCase)
verifyTrue(testCase, did2.convert.isV2Set('did_v2'));
verifyTrue(testCase, did2.convert.isV2Set('V_eta'));
verifyFalse(testCase, did2.convert.isV2Set('V_zeta'));
verifyFalse(testCase, did2.convert.isV2Set('did_v1'));
verifyFalse(testCase, did2.convert.isV2Set(''));
end

function testEitherNameStampsTheDocumentDidV2(testCase)
verifyEqual(testCase, did2.convert.targetStamp('V_eta'), 'did_v2');
verifyEqual(testCase, did2.convert.targetStamp('did_v2'), 'did_v2');
end

function testPassOneAcceptsTheNewName(testCase)
v1 = struct();
v1.document_class = struct('class_name', 'session', 'class_version', 1, ...
    'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
v1.depends_on = struct('name', {}, 'value', {});
v1.base = struct('id', 'sd_1', 'session_id', 'sess_1', ...
    'name', '', 'datestamp', '2024-03-23T13:47:40.237Z');
v1.session = struct('reference', 'ref');
a = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'V_eta');
b = did2.convert.v1_to_v2(v1, 'Validate', false, 'TargetVersion', 'did_v2');
verifyEqual(testCase, b.summary.migrated_count, a.summary.migrated_count);
verifyEqual(testCase, char(b.migrated{1}.get('document_class.schema_version')), ...
    char(a.migrated{1}.get('document_class.schema_version')), ...
    'the two names are one set: the same stamp');
[~, rep] = did2.convert.epochMint(b, 'Validate', false, 'TargetVersion', 'did_v2');
verifyTrue(testCase, rep.ran);
end

function testThePathPrefersDidV2AndFallsBackToVEta(testCase)
root = tempname;
mkdir(fullfile(root, 'V_eta', 'stable'));
testCase.addTeardown(@() rmdir(root, 's'));
% only the old layout: V_eta
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'stable'), ...
    fullfile(root, 'V_eta', 'stable'));
% the new layout present: did_v2, preferred
mkdir(fullfile(root, 'did_v2', 'stable'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'stable'), ...
    fullfile(root, 'did_v2', 'stable'));
% a tier only the old layout has (deprecated/, which leaves V2): the old one
mkdir(fullfile(root, 'V_eta', 'deprecated'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'deprecated'), ...
    fullfile(root, 'V_eta', 'deprecated'));
end

function testTheFlatLayoutIsTheSetFolder(testCase)
% [one folder, final classes only] (Decided by Jess Haley, 2026-10-29,
% did-schema V_eta_go_forward_class_audit.md): every V2 class in one folder,
% schemas/did_v2/*.json, no stable/ or draft/ tier. A did_v2 folder with no
% tier is that layout: each tier asked for is the folder itself.
root = tempname;
mkdir(fullfile(root, 'did_v2'));
testCase.addTeardown(@() rmdir(root, 's'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'stable'), ...
    fullfile(root, 'did_v2'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'draft'), ...
    fullfile(root, 'did_v2'));
% an old V_eta set beside it does not win over the flat did_v2
mkdir(fullfile(root, 'V_eta', 'stable'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'stable'), ...
    fullfile(root, 'did_v2'));
% a did_v2 that still has one tier is the tiered layout: a missing tier
% falls back as before
mkdir(fullfile(root, 'did_v2', 'draft'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'draft'), ...
    fullfile(root, 'did_v2', 'draft'));
verifyEqual(testCase, did2.schema.cache.schemaSetTierPath(root, 'stable'), ...
    fullfile(root, 'V_eta', 'stable'));
end

function testTheDefaultTargetIsDidV2(testCase)
% Step 2 of [schema set renamed did_v2] with [V2 database file renamed]
% (Decided by Jess Haley, 2026-11-01, did-schema
% did_v2_go_forward_class_audit.md): every TargetVersion default is
% 'did_v2'; 'V_eta' is still accepted on input (testBothNamesAreTheV2Set).
% A default that reverts to 'V_eta' is found here, file by file.
srcDir = fileparts(fileparts(fileparts(which('did2.convert.v1_to_v2'))));   % src/did
files = dir(fullfile(srcDir, '**', '*.m'));
verifyGreaterThan(testCase, numel(files), 0, 'no source files read');
for k = 1:numel(files)
    txt = fileread(fullfile(files(k).folder, files(k).name));
    bad = regexp(txt, ['options\.TargetVersion \(1,:\) char[^\n]*= ''V_eta''' ...
        '|''TargetVersion'', ''V_eta''|targetVersion = ''V_eta'''], 'match', 'once');
    verifyEmpty(testCase, bad, fullfile(files(k).folder, files(k).name));
end
end

function testNoCodeTestsTheTargetByItsOldNameAlone(testCase)
% [schema set renamed did_v2] step 1 (Jess Haley, 2026-10-25): every
% TargetVersion check accepts both names (did2.convert.isV2Set). A check
% that compares the target with 'V_eta' alone stops the code behind it once
% the default is 'did_v2': the corpus driver's batch-pass gate did, and Test
% code run 41339468679 ran 1 of its 10 batch passes. Read: src/did and this
% test tree (the corpus driver is a test helper).
here = fileparts(mfilename('fullpath'));                                     % tests/+did2/+unittest
srcDir = fileparts(fileparts(fileparts(which('did2.convert.v1_to_v2'))));   % src/did
files = [dir(fullfile(srcDir, '**', '*.m')); dir(fullfile(here, '**', '*.m'))];
verifyGreaterThan(testCase, numel(files), 0, 'no files read');
verifyTrue(testCase, any(strcmp({files.name}, 'runCorpusDiscovery.m')), ...
    'the corpus driver is among the files read');
me = [mfilename '.m'];
for k = 1:numel(files)
    if strcmp(files(k).name, me); continue; end
    txt = fileread(fullfile(files(k).folder, files(k).name));
    bad = regexp(txt, ['(strcmpi?|isequal)\([^)\n]*[Tt]argetVersion[^)\n]*''V_eta''\)' ...
        '|(strcmpi?|isequal)\(''V_eta'',[^)\n]*[Tt]argetVersion[^)\n]*\)'], 'match', 'once');
    verifyEmpty(testCase, bad, fullfile(files(k).folder, files(k).name));
end
end
