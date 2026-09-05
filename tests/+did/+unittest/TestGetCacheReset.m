classdef TestGetCacheReset < matlab.unittest.TestCase
    % Test did.common.getCache('reset').
    %
    % getCache() is the process-wide file-cache singleton. The plain
    % form memoizes a fileCache handle in a persistent variable so
    % every DID call sees the same catalog and lock state. That
    % memoization is also what kept the failure in issue #174 alive
    % across did.common.getCache().clear() -- clear() operated on the
    % object but did not replace it. The 'reset' form is the callable
    % equivalent of "clear did.common.getCache", so a caller can
    % force a fresh construction without ending the MATLAB session.

    methods (TestMethodSetup)
        function setupMethod(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.applyFixture(did.test.fixture.PathConstantFixture);
            % Start every test from a fresh singleton so the persistent
            % state left by other tests cannot leak in.
            did.common.getCache('reset');
        end
    end

    methods (TestMethodTeardown)
        function teardownMethod(~)
            did.common.getCache('reset');
        end
    end

    methods (Test)

        function testDefaultCallReusesTheSingleton(testCase)
            a = did.common.getCache();
            b = did.common.getCache();
            testCase.verifyTrue(a == b);
        end

        function testResetProducesANewSingleton(testCase)
            a = did.common.getCache();
            b = did.common.getCache('reset');
            testCase.verifyFalse(a == b);
            % Subsequent plain calls memoize the new one.
            c = did.common.getCache();
            testCase.verifyTrue(b == c);
        end

        function testResetClearsStuckInMemoryLockState(testCase)
            % The mechanism from issue #174: a prior addFile error path
            % left binaryTable.hasLock stuck true. getCache().clear()
            % did not reset it (fixed separately); getCache('reset')
            % rebuilds the whole singleton so any such stuck state is
            % gone by construction.
            a = did.common.getCache();
            [~,~] = a.binaryTable.getLock();
            testCase.verifyTrue(a.binaryTable.hasLock);

            b = did.common.getCache('reset');
            testCase.verifyFalse(b.binaryTable.hasLock);
        end

        function testUnknownActionIsRefused(testCase)
            testCase.verifyError(@() did.common.getCache('nope'), ?MException);
        end

    end
end
