function packageToolbox(releaseType, versionString)
    arguments
        releaseType {mustBeTextScalar,mustBeMember(releaseType,["build","major","minor","patch","specific"])} = "build"
        versionString {mustBeTextScalar} = "";
    end
    projectRootDirectory = didtools.projectdir();
    matbox.tasks.packageToolbox(projectRootDirectory, releaseType, versionString, "ToolboxShortName", "DID_MATLAB")
end
