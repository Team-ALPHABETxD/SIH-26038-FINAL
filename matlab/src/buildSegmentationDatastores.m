%% buildSegmentationDatastores.m
% Builds train/validation pixelLabelDatastores from preprocessedData/
% (images) and pseudoMasks/ (weak pseudo-ground-truth, see
% generatePseudoMasks.m) for training the lesion segmentation networks.
%
% Uses: Image Processing Toolbox, Computer Vision Toolbox
% (pixelLabelDatastore).

imageDir = fullfile(pwd, "preprocessedData");
maskDir = fullfile(pwd, "pseudoMasks");

assert(exist(maskDir, "dir") == 7, ...
    "pseudoMasks/ not found. Run generatePseudoMasks.m first.");

classNamesSeg = ["background", "lesion"];
pixelLabelIDs = [0, 255];

imds = imageDatastore(imageDir, "IncludeSubfolders", true, "FileExtensions", ".png");
pxds = pixelLabelDatastore(maskDir, classNamesSeg, pixelLabelIDs, ...
    "IncludeSubfolders", true, "FileExtensions", ".png");

assert(numel(imds.Files) == numel(pxds.Files), ...
    "Image count (%d) does not match mask count (%d). Re-run " + ...
    "generatePseudoMasks.m -- some images may be missing masks.", ...
    numel(imds.Files), numel(pxds.Files));

rng(42); % reproducible split
n = numel(imds.Files);
idx = randperm(n);
nTrain = round(0.85 * n);

trainIdx = idx(1:nTrain);
valIdx = idx(nTrain+1:end);

imdsTrain = subset(imds, trainIdx);
pxdsTrain = subset(pxds, trainIdx);
imdsVal = subset(imds, valIdx);
pxdsVal = subset(pxds, valIdx);

trainingData = combine(imdsTrain, pxdsTrain);
validationData = combine(imdsVal, pxdsVal);

fprintf("Segmentation train set: %d images | validation set: %d images\n", ...
    numel(trainIdx), numel(valIdx));

save("segDatastoreSplit.mat", "trainingData", "validationData", ...
    "classNamesSeg", "pixelLabelIDs");
disp("Saved segDatastoreSplit.mat");
