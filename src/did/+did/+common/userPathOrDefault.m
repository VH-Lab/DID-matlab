function p = userPathOrDefault(userPathValue)
    % USERPATHORDEFAULT - MATLAB's userpath, or its documented default
    %
    % P = USERPATHORDEFAULT()
    % P = USERPATHORDEFAULT(USERPATHVALUE)
    %
    % Return USERPATHVALUE -- by default USERPATH() -- or, when that is
    % empty, MATLAB's documented default userpath, <home>/Documents/MATLAB.
    %
    % USERPATH() is empty on an installation that cannot find a personal
    % folder, which is the normal state on a headless machine or a CI
    % runner; MATLAB says as much with "Unable to locate a personal folder
    % for $documents/MATLAB". The trouble is that FULLFILE('', 'a', 'b') is
    % the RELATIVE path 'a/b', so every path constant built on an empty
    % userpath was resolved against whatever the current working directory
    % happened to be. did.common.PathConstants.filecachepath named a
    % different directory in every session, and nothing cached in it was
    % ever found again -- a cache that could not cache.
    %
    % Falling back to what userpath would have been, rather than straight to
    % the home directory, leaves the paths exactly where they already are on
    % machines where userpath works.
    %
    % USERPATHVALUE is an argument so the empty case can be tested without
    % altering MATLAB's userpath, which is global state shared with every
    % other test in the session.
    %
    % See also: USERPATH, DID.COMMON.PATHCONSTANTS

    arguments
        userPathValue {mustBeTextScalar} = userpath()
    end

    % userpath can carry a trailing separator, and historically a whole path
    % list; take the first entry.
    parts = strsplit(char(userPathValue), pathsep);
    p = strtrim(parts{1});

    if isempty(p)
        if ispc
            home = getenv('USERPROFILE');
        else
            home = getenv('HOME');
        end
        if isempty(home)
            % Nothing else to go on. An absolute temporary path makes a poor
            % cache, but it beats a relative one that follows the working
            % directory around.
            home = tempdir();
        end
        p = fullfile(home, 'Documents', 'MATLAB');
    end
end
