function testToolbox(varargin)
    installMatBox()
    projectRootDirectory = didtools.projectdir();
    matbox.installRequirements(projectRootDirectory)
    matbox.tasks.testToolbox(projectRootDirectory, varargin{:})
end
