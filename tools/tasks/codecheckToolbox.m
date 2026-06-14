function codecheckToolbox(varargin)
    % codecheckToolbox  Project code-check wrapper invoked by CI
    %   (ehennestad/matbox-actions check-code@v1).
    %
    %   The check-code action adds tools/ to the path and calls the bare
    %   name, e.g. codecheckToolbox("FoldersToCheck","src"). This wrapper
    %   must therefore:
    %     (a) live at the bare name so the action's
    %         exist("codecheckToolbox","file") branch resolves to it
    %         (rather than falling through to matbox with CreateBadge=true),
    %     (b) accept and forward those name-value args, and
    %     (c) force CreateBadge=false. Badge generation goes through
    %         matbox.utility.createBadgeSvg, which needs a CPython install
    %         the CI runner does not have ("Python commands require a
    %         supported version of CPython").
    %
    %   Earlier this was a zero-arg wrapper, which broke once the action
    %   began passing "FoldersToCheck"/"src" ("Too many input arguments").
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDirectory, "CreateBadge", false, varargin{:});
end
