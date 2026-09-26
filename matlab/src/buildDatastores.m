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

% ---- Diagnose folder-name mismatches BEFORE reordercats, which
%      otherwise fails with a generic, unhelpful message ----
actualCategories = categories(imds.Labels);
missingFromData = setdiff(classNames, actualCategories);
extraInData = setdiff(actualCategories, classNames);

if ~isempty(missingFromData) || ~isempty(extraInData)
    fprintf("Folder names found in preprocessedData:\n");
    disp(actualCategories)
    fprintf("Folder names expected by this script:\n");
    disp(classNames')
    if ~isempty(missingFromData)
        fprintf("MISSING (expected but not found): %s\n", strjoin(missingFromData, ", "));
    end
    if ~isempty(extraInData)
        fprintf("UNEXPECTED (found but not in classNames): %s\n", strjoin(extraInData, ", "));
    end
    error("buildDatastores:folderMismatch", ...
        "Folder names in preprocessedData do not exactly match classNames " + ...
        "(see lists printed above). Rename the mismatched folder(s) under " + ...
        "rawData and re-run prepareDataset.m, or edit the classNames " + ...
        "variable in this script to match your actual folder names.");
end

imds.Labels = reordercats(imds.Labels, classNames);

fprintf("Overall class distribution:\n");
disp(countEachLabel(imds))

rng(42); % reproducible split
[imdsTrain, imdsVal, imdsTest] = splitEachLabel(imds, 0.70, 0.15, 0.15, "randomized");

fprintf("Train: %d | Val: %d | Test: %d images\n", ...
    numel(imdsTrain.Files), numel(imdsVal.Files), numel(imdsTest.Files));

% ---- Hybrid over/undersampling for the TRAINING set only ----
% Pure "oversample everyone up to the majority count" can mean repeating
% a small class's images 9-10x each verbatim (exactly what a ~9x
% imbalance ratio like Healthy:Severe produces). Instead, target a value
% between the median and the max: mildly undersample the majority
% class, and oversample minority classes by a smaller, less extreme
% factor.
trainTbl = countEachLabel(imdsTrain);
counts = trainTbl.Count;
targetCount = min(max(counts), round(3 * median(counts)));

fprintf("Class counts before balancing:\n"); disp(trainTbl)
fprintf("Balancing target per class: %d (median=%d, max=%d)\n", ...
    targetCount, median(counts), max(counts));

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

    if nHave >= targetCount
        % Majority class: randomly undersample down to targetCount
        keepIdx = randperm(nHave, targetCount);
        selFiles = filesC(keepIdx);
    else
        % Minority class: oversample up to targetCount (repeat + trim)
        nRep = ceil(targetCount / nHave);
        repFiles = repmat(filesC, nRep, 1);
        selFiles = repFiles(1:targetCount);
    end

    balancedFiles = [balancedFiles; selFiles]; %#ok<AGROW>
    balancedLabelsCell = [balancedLabelsCell; repmat(cellstr(classNames(c)), targetCount, 1)]; %#ok<AGROW>
end

imdsTrainBalanced = imageDatastore(balancedFiles);
imdsTrainBalanced.Labels = reordercats(categorical(balancedLabelsCell), classNames);

fprintf("\nBalanced training class distribution (via oversampling):\n");
disp(countEachLabel(imdsTrainBalanced))

save("datastoreSplit.mat", "imdsTrainBalanced", "imdsVal", "imdsTest", "classNames");
disp("Saved datastoreSplit.mat");
