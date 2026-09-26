%% generatePseudoMasks.m
% Generates WEAK, pseudo-ground-truth lesion masks for every image in
% preprocessedData/, by combining:
%   1. Grad-CAM attention from the trained DR grading CNN
%      (models/drGradingNet.mat)
%   2. The classical lesion heuristic (highlightLesionCandidates.m)
% and writes them to pseudoMasks/<class>/<filename>.png
%
% *** IMPORTANT -- READ THIS BEFORE TRAINING ANYTHING ON THESE MASKS ***
% These are NOT real expert-annotated lesion masks. Your dataset
% (rawData/Healthy, Mild DR, Moderate DR, Severe DR, Proliferate DR)
% only has IMAGE-LEVEL DR grade labels -- there is no pixel-level ground
% truth anywhere in it, regardless of whether the images originated from
% APTOS, IDRiD's Disease Grading subset, or a merge of both.
%
% True supervised segmentation training needs a dataset with real
% per-pixel masks (e.g. IDRiD's separate "Segmentation" subset, which is
% a DIFFERENT download from its Disease Grading subset, drawn by
% ophthalmologists).
%
% What this script does instead is WEAK SUPERVISION: combine Grad-CAM
% (from a classifier that already learned to distinguish DR grades) with
% classical blob detection to produce an approximate, noisy pseudo-mask,
% then train a real segmentation network to reproduce it. This IS a
% genuine trained network with a real training loop -- but its masks
% will be less accurate than one trained on true expert pixel
% annotations. Report it as "weakly-supervised lesion localization",
% not clinically validated segmentation.

load(fullfile("models", "drGradingNet.mat"), "trainedNet", "classNames", "inputSize");

dataDir = fullfile(pwd, "preprocessedData");
outDir = fullfile(pwd, "pseudoMasks");

assert(exist(dataDir, "dir") == 7, ...
    "preprocessedData/ not found. Run prepareDataset.m first.");

if ~exist(outDir, "dir")
    mkdir(outDir);
end

CAM_THRESHOLD = 0.55; % keep only strongly-attended CNN regions

for c = 1:numel(classNames)
    inFolder = fullfile(dataDir, classNames(c));
    outFolder = fullfile(outDir, classNames(c));

    if ~exist(inFolder, "dir")
        warning("Missing folder, skipping: %s", inFolder);
        continue
    end
    if ~exist(outFolder, "dir")
        mkdir(outFolder);
    end

    files = dir(fullfile(inFolder, "*.png"));
    fprintf("Generating pseudo-masks for '%s': %d images\n", classNames(c), numel(files));

    for i = 1:numel(files)
        imgPath = fullfile(inFolder, files(i).name);
        img = imread(imgPath);

        % ---- Signal 1: Grad-CAM from the trained classifier ----
        scores = predict(trainedNet, single(img));
        [~, predIdx] = max(scores);
        camMap = gradCAM(trainedNet, img, predIdx);
        camNorm = mat2gray(camMap);
        camMask = camNorm > CAM_THRESHOLD;

        % ---- Signal 2: classical lesion candidates ----
        evidence = highlightLesionCandidates(img);
        classicalMask = evidence.exudateMask | evidence.darkLesionMask;

        % ---- Combine: pseudo-lesion = classical candidate that also
        %      falls inside the CNN's attended region. Requiring BOTH
        %      signals to agree reduces false positives from either
        %      signal alone. ----
        pseudoMask = classicalMask & camMask;

        % Healthy images should contain no lesions by definition --
        % zero out defensively regardless of what the heuristics found.
        if classNames(c) == "Healthy"
            pseudoMask = false(size(pseudoMask));
        end

        outPath = fullfile(outFolder, files(i).name);
        imwrite(uint8(pseudoMask) * 255, outPath);
    end
end

fprintf("\nPseudo-mask generation complete. Saved to: %s\n", outDir);
fprintf("Before proceeding, visually spot-check a few masks against\n");
fprintf("their source images -- open preprocessedData/Moderate DR/<file>\n");
fprintf("and pseudoMasks/Moderate DR/<same file> side by side in MATLAB's\n");
fprintf("image viewer to sanity-check the masks look plausible.\n");
