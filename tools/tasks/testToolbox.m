function testToolbox(varargin)
    projectRootDirectory = didtools.projectdir();
    matbox.installRequirements(projectRootDirectory)
    matbox.tasks.testToolbox(projectRootDirectory, "CreateBadge", false, varargin{:})
end
