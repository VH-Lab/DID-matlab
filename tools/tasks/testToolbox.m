function testToolbox(varargin)
    installMatBox("commit")
    projectRootDirectory = didtools.projectdir();
    matbox.installRequirements(projectRootDirectory)

    matbox.tasks.testToolbox(projectRootDirectory, "CreateBadge", false, varargin{:})
end
