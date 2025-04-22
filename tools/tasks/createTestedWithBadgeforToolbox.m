function createTestedWithBadgeforToolbox(versionNumber)
    arguments
        versionNumber (1,1) string
    end
    installMatBox()
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.createTestedWithBadgeforToolbox(versionNumber, projectRootDirectory)
end
