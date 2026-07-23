function codecheckToolbox()
    % didtools.codecheckToolbox  Developer convenience wrapper for
    %   matbox.tasks.codecheckToolbox: run the project code check
    %   against the DID-matlab repo root with badge writing disabled.
    %
    %   Call as `didtools.codecheckToolbox` from the MATLAB prompt.
    %
    %   This used to live at tools/tasks/codecheckToolbox.m (bare name)
    %   but check-code@v1 puts tools/ on the path and resolved to this
    %   zero-arg wrapper instead of matbox.tasks.codecheckToolbox's
    %   multi-arg version, breaking CI with "Too many input arguments".
    %   Moving it into +didtools/ keeps the convenience without
    %   shadowing matbox.
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDirectory, "CreateBadge", false)
end
