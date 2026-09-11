%% prepareDataset.m
% Batch-preprocesses the raw fundus dataset (archive.zip, extracted) and
% writes enhanced images into a new folder structure ready for
% imageDatastore-based training.
%
% BEFORE RUNNING: extract archive.zip so this layout exists relative to
% your MATLAB current folder:
%
%   rawData/Healthy/*.png
%   rawData/Mild DR/*.png
%   rawData/Moderate DR/*.png
%   rawData/Severe DR/*.png
%   rawData/Proliferate DR/*.png
%
% Uses ONLY Image Processing Toolbox functions (via preprocessFundusImage.m).

rawDataDir = fullfile(pwd, "rawData");
outDataDir = fullfile(pwd, "preprocessedData");
targetSize = [224 224]; % matches ResNet-101/50/18 input size

classFolders = ["Healthy", "Mild DR", "Moderate DR", "Severe DR", "Proliferate DR"];

assert(exist(rawDataDir, "dir") == 7, ...
    "Could not find 'rawData' folder in %s. Extract archive.zip there first.", pwd);

if ~exist(outDataDir, "dir")
    mkdir(outDataDir);
end

totalProcessed = 0;
totalSkipped = 0;

for c = 1:numel(classFolders)
    inFolder = fullfile(rawDataDir, classFolders(c));
    outFolder = fullfile(outDataDir, classFolders(c));

    if ~exist(inFolder, "dir")
        warning("Class folder not found, skipping: %s", inFolder);
        continue
    end
    if ~exist(outFolder, "dir")
        mkdir(outFolder);
    end

    files = dir(fullfile(inFolder, "*.png"));
    fprintf("Processing class '%s': %d images\n", classFolders(c), numel(files));

    for i = 1:numel(files)
        imgPath = fullfile(inFolder, files(i).name);
        try
            img = imread(imgPath);
            imgProc = preprocessFundusImage(img, targetSize);
            imwrite(imgProc, fullfile(outFolder, files(i).name));
            totalProcessed = totalProcessed + 1;
        catch ME
            fprintf("  Skipped %s (%s)\n", files(i).name, ME.message);
            totalSkipped = totalSkipped + 1;
        end
    end
end

fprintf("\nPreprocessing complete.\n");
fprintf("  Processed : %d images\n", totalProcessed);
fprintf("  Skipped   : %d images\n", totalSkipped);
fprintf("  Output    : %s\n", outDataDir);
