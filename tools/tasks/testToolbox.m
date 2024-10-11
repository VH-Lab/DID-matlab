function testToolbox(varargin)
    installMatBox("commit")
    projectRootDirectory = didtools.projectdir();
    matbox.installRequirements(projectRootDirectory)
    
    tf = isfile('/home/runner/work/DID-matlab/DID-matlab/MATLAB-AddOns/mksqlite-master/mksqlite.mexa64');
    fprintf("File is present: %d\n", tf)

    matbox.tasks.testToolbox(projectRootDirectory, varargin{:})
end
