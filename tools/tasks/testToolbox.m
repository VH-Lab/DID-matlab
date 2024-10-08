function testToolbox(varargin)
    installMatBox()
    projectRootDirectory = didtools.projectdir();
    sourceFolderName = '+did';
    matbox.tasks.testToolbox(projectRootDirectory, varargin{:}, 'SourceFolderName', sourceFolderName)
end
