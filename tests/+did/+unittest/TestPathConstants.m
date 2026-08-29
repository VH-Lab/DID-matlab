classdef TestPathConstants < matlab.unittest.TestCase
    % Test did.common.PathConstants and did.common.userPathOrDefault.
    %
    % The path constants were built on USERPATH(), which is empty on any
    % installation that cannot find a personal folder -- a headless machine
    % or a CI runner, where MATLAB warns "Unable to locate a personal folder
    % for $documents/MATLAB". FULLFILE('', 'a', 'b') is the RELATIVE path
    % 'a/b', so filecachepath named a different directory in every session
    % and nothing cached in it was ever found again.

    methods (Static)
        function tf = isAbsolutePath(p)
            if ispc
                tf = ~isempty(regexp(p, '^([A-Za-z]:[\\/]|\\\\)', 'once'));
            else
                tf = startsWith(p, '/');
            end
        end
    end

    methods (Test)

        function testAnEmptyUserPathFallsBackToSomethingAbsolute(testCase)
            % The case that mattered: no personal folder.
            p = did.common.userPathOrDefault('');
            testCase.verifyTrue(did.unittest.TestPathConstants.isAbsolutePath(p), ...
                sprintf('"%s" is not an absolute path', p));
        end

        function testTheFallbackIsMatlabsDocumentedDefault(testCase)
            % <home>/Documents/MATLAB, which is where userpath would have
            % pointed had MATLAB been able to find it -- so the constants
            % built on it stay where they already are on machines that work.
            p = did.common.userPathOrDefault('');
            testCase.verifyTrue(endsWith(p, fullfile('Documents','MATLAB')), ...
                sprintf('"%s" should end in Documents/MATLAB', p));
        end

        function testAUserPathIsReturnedUnchanged(testCase)
            given = fullfile(tempdir, 'someUserPath');
            testCase.verifyEqual(did.common.userPathOrDefault(given), given);
        end

        function testATrailingSeparatorIsDropped(testCase)
            % userpath has historically returned a path list, and can carry
            % a trailing separator; only the first entry is a folder.
            given = fullfile(tempdir, 'someUserPath');
            testCase.verifyEqual(did.common.userPathOrDefault([given pathsep]), given);
        end

        function testTheFirstEntryOfAPathListIsUsed(testCase)
            first = fullfile(tempdir, 'firstUserPath');
            second = fullfile(tempdir, 'secondUserPath');
            testCase.verifyEqual( ...
                did.common.userPathOrDefault([first pathsep second]), first);
        end

        function testWhitespaceIsTrimmed(testCase)
            given = fullfile(tempdir, 'someUserPath');
            testCase.verifyEqual(did.common.userPathOrDefault(['  ' given '  ']), given);
        end

        function testTheDefaultArgumentIsUserpath(testCase)
            % Called with no argument it must agree with calling it with
            % userpath() explicitly, or the constants and this function
            % would disagree about where things live.
            testCase.verifyEqual(did.common.userPathOrDefault(), ...
                did.common.userPathOrDefault(userpath()));
        end

        function testThePathConstantsAreAbsolute(testCase)
            % The property that was actually broken. A relative constant
            % here means the cache follows the working directory around.
            names = {'filecachepath', 'preferences', 'temppath'};
            for i = 1:numel(names)
                p = did.common.PathConstants.(names{i});
                testCase.verifyTrue(did.unittest.TestPathConstants.isAbsolutePath(p), ...
                    sprintf('PathConstants.%s is "%s", which is not absolute', names{i}, p));
            end
        end

    end
end
