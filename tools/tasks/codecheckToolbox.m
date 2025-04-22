function codecheckToolbox()
    installMatBox("commit")
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.codecheckToolbox(projectRootDirectory, "CreateBadge", false)
end
