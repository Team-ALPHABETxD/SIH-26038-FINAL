function setupProject()
%SETUPPROJECT Run this once at the start of every MATLAB session.
%   Sets the current folder to the project root (the folder containing
%   rawData/, src/, models/) regardless of where you currently are, and
%   adds src/ to the MATLAB path. This avoids "file not found" errors
%   caused by running scripts from inside src/ instead of the project
%   root.

thisFile = mfilename('fullpath');   % .../SIH26038/src/setupProject
srcDir = fileparts(thisFile);       % .../SIH26038/src
projectRoot = fileparts(srcDir);    % .../SIH26038

cd(projectRoot);
addpath(genpath(srcDir));

fprintf("Project root set to: %s\n", projectRoot);
fprintf("src/ added to the MATLAB path.\n");
fprintf("You can now run: prepareDataset, buildDatastores, trainDRModel, etc.\n");
end
