%SCRATCH Ad-hoc MATLAB probe, run by .github/workflows/matlab-scratch.yml.
%
%   PROBE: does TestSuite.fromPackage(..., "InvalidFileFoundAction", "error")
%   fail on BOTH kinds of left-out test file -- one that does not parse, and
%   one whose fixture function declares an arguments block -- and what are the
%   warning IDs of the default (warn) behaviour?

root = tempname; mkdir(root); pkg = fullfile(root, '+probepkg'); mkdir(pkg);
w = @(name, txt) writeFile(fullfile(pkg, [name '.m']), txt);
w('testGood', sprintf('function tests = testGood\ntests = functiontests(localfunctions);\nend\nfunction testA(testCase)\nverifyTrue(testCase, true);\nend\n'));
w('testBadParse', sprintf('function tests = testBadParse\ntests = functiontests(localfunctions);\nend\nfunction testA(testCase)\nverifyTrue(testCase, true);\nend\nend\n'));
w('testFixtureArgs', sprintf(['function tests = testFixtureArgs\ntests = functiontests(localfunctions);\nend\n' ...
    'function teardownOnce(testCase)\narguments\n    testCase (1,1) matlab.unittest.TestCase\nend\nend\n' ...
    'function testA(testCase)\nverifyTrue(testCase, true);\nend\n']));
addpath(root);
import matlab.unittest.TestSuite;
fprintf('MATLAB %s\n', version);

fprintf('\n==== 1. default (warn): warning IDs ====\n');
for f = {'testBadParse', 'testFixtureArgs'}
    lastwarn('', '');
    s = TestSuite.fromFile(fullfile(pkg, [f{1} '.m'])); %#ok<NASGU>
    [msg, id] = lastwarn;
    fprintf('%s: id="%s"\n  msg=%s\n', f{1}, id, strrep(msg, newline, ' | '));
end
lastwarn('', '');
s = TestSuite.fromPackage("probepkg");
[~, id] = lastwarn;
fprintf('fromPackage default: %d tests selected; last warning id="%s"\n', numel(s), id);

fprintf('\n==== 2. InvalidFileFoundAction="error", one bad file at a time ====\n');
for f = {'testBadParse', 'testFixtureArgs'}
    other = setdiff({'testBadParse', 'testFixtureArgs'}, f);
    movefile(fullfile(pkg, [other{1} '.m']), fullfile(root, [other{1} '.m.off']));
    try
        s = TestSuite.fromPackage("probepkg", "InvalidFileFoundAction", "error");
        fprintf('%s alone: NO ERROR, %d tests selected\n', f{1}, numel(s));
    catch ME
        fprintf('%s alone: ERROR id="%s"\n  msg=%s\n', f{1}, ME.identifier, strrep(ME.message, newline, ' | '));
    end
    movefile(fullfile(root, [other{1} '.m.off']), fullfile(pkg, [other{1} '.m']));
end

fprintf('\n==== 3. warning("error", <id>) for each captured ID ====\n');
for f = {'testBadParse', 'testFixtureArgs'}
    lastwarn('', '');
    TestSuite.fromFile(fullfile(pkg, [f{1} '.m']));
    [~, id] = lastwarn;
    if isempty(id); fprintf('%s: no id to arm\n', f{1}); continue; end
    old = warning('error', id); %#ok<NASGU>
    try
        s = TestSuite.fromPackage("probepkg");
        fprintf('%s with warning("error","%s"): NO ERROR, %d tests\n', f{1}, id, numel(s));
    catch ME
        fprintf('%s with warning("error","%s"): ERROR id="%s"\n', f{1}, id, ME.identifier);
    end
    warning('on', id);
end
fprintf('\n==== PROBE DONE ====\n');

function writeFile(p, txt)
fid = fopen(p, 'w'); fwrite(fid, txt); fclose(fid);
end
