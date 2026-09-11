%% buildDatastores.m
% Builds train/validation/test imageDatastores from preprocessedData/,
% in correct clinical ICDR grade order, and oversamples minority classes
% in the TRAINING set only (validation/test stay untouched so metrics
% reflect the real, imbalanced clinical population).

dataDir = fullfile(pwd, "preprocessedData");
assert(exist(dataDir, "dir") == 7, ...
    "Run prepareDataset.m first to create preprocessedData/.");

% Clinical ICDR order: 0=Healthy, 1=Mild, 2=Moderate, 3=Severe, 4=Proliferate
classNames = ["Healthy", "Mild DR", "Moderate DR", "Severe DR", "Proliferate DR"];

imds = imageDatastore(dataDir, "IncludeSubfolders", true, "LabelSource", "foldernames");
imds.Labels = reordercats(imds.Labels, classNames);

fprintf("Overall class distribution:\n");
disp(countEachLabel(imds))

rng(42); % reproducible split
[imdsTrain, imdsVal, imdsTest] = splitEachLabel(imds, 0.70, 0.15, 0.15, "randomized");

fprintf("Train: %d | Val: %d | Test: %d images\n", ...
    numel(imdsTrain.Files), numel(imdsVal.Files), numel(imdsTest.Files));

% ---- Oversample minority classes in the TRAINING set only ----
trainTbl = countEachLabel(imdsTrain);
maxCount = max(trainTbl.Count);

balancedFiles = {};
balancedLabelsCell = {};
for c = 1:numel(classNames)
    idx = find(imdsTrain.Labels == classNames(c));
    filesC = imdsTrain.Files(idx);
    nHave = numel(filesC);
    if nHave == 0
        warning("No training images found for class '%s'.", classNames(c));
        continue
    end
    nRep = ceil(maxCount / nHave);
    repFiles = repmat(filesC, nRep, 1);
    repFiles = repFiles(1:maxCount);
    balancedFiles = [balancedFiles; repFiles]; %#ok<AGROW>
    balancedLabelsCell = [balancedLabelsCell; repmat(cellstr(classNames(c)), maxCount, 1)]; %#ok<AGROW>
end

imdsTrainBalanced = imageDatastore(balancedFiles);
imdsTrainBalanced.Labels = reordercats(categorical(balancedLabelsCell), classNames);

fprintf("\nBalanced training class distribution (via oversampling):\n");
disp(countEachLabel(imdsTrainBalanced))

save("datastoreSplit.mat", "imdsTrainBalanced", "imdsVal", "imdsTest", "classNames");
disp("Saved datastoreSplit.mat");
