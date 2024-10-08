function codecheckToolbox()
    installMatBox()
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDirectory)
end
