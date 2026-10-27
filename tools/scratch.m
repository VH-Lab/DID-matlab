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

bad = {'testBadParse', 'testFixtureArgs'};
park = @(f) movefile(fullfile(pkg, [f '.m']), fullfile(root, [f '.m.off']));
unpark = @(f) movefile(fullfile(root, [f '.m.off']), fullfile(pkg, [f '.m']));
park('testBadParse'); park('testFixtureArgs');
for b = bad
    unpark(b{1});
    fprintf('\n==== %s (with testGood) ====\n', b{1});
    lastwarn('', '');
    s = TestSuite.fromPackage("probepkg");
    [msg, id] = lastwarn;
    fprintf('1. default: %d tests; warning id="%s"\n   msg=%s\n', numel(s), id, strrep(msg, newline, ' | '));
    try
        s = TestSuite.fromPackage("probepkg", "InvalidFileFoundAction", "error");
        fprintf('2. InvalidFileFoundAction="error": NO ERROR, %d tests\n', numel(s));
    catch ME
        fprintf('2. InvalidFileFoundAction="error": ERROR id="%s"\n   msg=%s\n', ME.identifier, strrep(ME.message, newline, ' | '));
    end
    if ~isempty(id)
        warning('error', id);
        try
            s = TestSuite.fromPackage("probepkg");
            fprintf('3. warning("error","%s"): NO ERROR, %d tests\n', id, numel(s));
        catch ME
            fprintf('3. warning("error","%s"): ERROR id="%s"\n', id, ME.identifier);
        end
        warning('on', id);
    end
    park(b{1});
end
fprintf('\n==== PROBE DONE ====\n');

function writeFile(p, txt)
fid = fopen(p, 'w'); fwrite(fid, txt); fclose(fid);
end
