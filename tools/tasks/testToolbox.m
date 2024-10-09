function testToolbox(varargin)
    installMatBox()
    projectRootDirectory = didtools.projectdir();
    matbox.installRequirements(projectRootDirectory)
    sourceFolderName = '+did';
    matbox.tasks.testToolbox(projectRootDirectory, varargin{:}, 'SourceFolderName', sourceFolderName)
end
