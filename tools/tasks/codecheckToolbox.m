function codecheckToolbox(varargin)
    % codecheckToolbox  Project code-check wrapper invoked by CI
    %   (ehennestad/matbox-actions check-code@v1).
    %
    %   The check-code action adds tools/ to the path and calls the bare
    %   name, e.g. codecheckToolbox("FoldersToCheck","src"). This wrapper
    %   lives at the bare name so the action's
    %   exist("codecheckToolbox","file") branch resolves to it, and it
    %   forwards the action's name-value args to
    %   matbox.tasks.codecheckToolbox.
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDirectory, "CreateBadge", true, varargin{:});
end
