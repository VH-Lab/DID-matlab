function p = homeDirectory(homeValue)
    % HOMEDIRECTORY - the current user's home directory
    %
    % P = HOMEDIRECTORY()
    % P = HOMEDIRECTORY(HOMEVALUE)
    %
    % Return the user's home directory: USERPROFILE on Windows, HOME
    % elsewhere. That is exactly what Python's pathlib.Path.home() resolves
    % to, which is the point -- did.common.PathConstants.filecachepath is
    % built on this so that MATLAB and DID-python name the same cache
    % directory by construction rather than by coincidence.
    %
    % Falls back to TEMPDIR when neither variable is set. An absolute
    % temporary path makes a poor cache, but it beats a relative one that
    % follows the working directory around.
    %
    % HOMEVALUE is an argument so the empty case can be tested without
    % altering the environment, which is global state shared with every
    % other test in the session.
    %
    % See also: DID.COMMON.PATHCONSTANTS, DID.COMMON.USERPATHORDEFAULT

    if nargin < 1
        if ispc
            homeValue = getenv('USERPROFILE');
        else
            homeValue = getenv('HOME');
        end
    end

    p = strtrim(char(homeValue));
    if isempty(p)
        p = tempdir();
    end
end
