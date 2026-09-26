%% trainSegmentation_DeepLabV3ResNet101.m
% Trains the lesion segmentation network (Module 2): DeepLabV3+ with a
% ResNet-101 backbone. This is the ONLY segmentation architecture used
% in this build, per project requirement -- there is no second model to
% compare against, so this script trains, evaluates, and saves the
% deployable model directly.
%
% See generatePseudoMasks.m header for the "weakly-supervised" caveat --
% this network is trained on pseudo-masks (Grad-CAM + classical
% heuristic combined), not true expert pixel annotations.
%
% Uses: Deep Learning Toolbox, Computer Vision Toolbox
% (deeplabv3plusLayers, semanticseg), Parallel Computing Toolbox
% (GPU-accelerated training).

load("segDatastoreSplit.mat", "trainingData", "validationData");

inputSize = [224 224 3];
numClasses = 2; % background, lesion

% ---- Detect GPU / Parallel Computing Toolbox availability ----
if canUseGPU()
    gpuInfo = gpuDevice();
    executionEnvironment = "gpu";
    fprintf("GPU detected: %s (%.1f GB available). Training on GPU.\n", ...
        gpuInfo.Name, gpuInfo.AvailableMemory/1e9);
else
    executionEnvironment = "cpu";
    fprintf("WARNING: No GPU detected -- DeepLabV3+ResNet101 on CPU will be very slow.\n");
    fprintf("Check gpuDevice() in the Command Window if you expected GPU use.\n");
end

lgraph = deeplabv3plus(inputSize, numClasses, "resnet101");

options = trainingOptions("adam", ...
    InitialLearnRate=5e-4, ...
    MaxEpochs=30, ...
    MiniBatchSize=4, ...          % small batch: ResNet-101 backbone is memory-heavy
    Shuffle="every-epoch", ...
    ValidationData=validationData, ...
    ValidationFrequency=30, ...
    ExecutionEnvironment=executionEnvironment, ...
    Plots="training-progress", ...
    Verbose=true);

% ---- Loss function: focalCrossEntropy, per project instruction, applied
%      per-pixel here. This is a legitimate choice for segmentation too --
%      lesion pixels are a small minority of each image, and focal loss's
%      down-weighting of "easy" (background) pixels addresses exactly
%      that imbalance, the same way it addresses class imbalance in the
%      classification model. ----
lossFcn = @(Y,T) focalCrossEntropy(Y, T, ClassificationMode="single-label");

fprintf("Training DeepLabV3+ + ResNet-101 segmentation model...\n");
tic
deeplabTrainedNet = trainnet(trainingData, lgraph, lossFcn, options);
fprintf("Training finished in %.1f minutes.\n", toc/60);

% ---- Evaluate on the validation set (Dice / IoU) ----
reset(validationData);
allImgs = {};
allMasks = {};
while hasdata(validationData)
    d = read(validationData);
    allImgs{end+1} = d{1}; %#ok<AGROW>
    allMasks{end+1} = d{2}; %#ok<AGROW>
end

diceScores = zeros(numel(allImgs), 1);
iouScores = zeros(numel(allImgs), 1);

for i = 1:numel(allImgs)
    predMask = semanticseg(allImgs{i}, deeplabTrainedNet);
    trueMask = allMasks{i};

    predLesion = predMask == "lesion";
    trueLesion = trueMask == "lesion";

    intersection = nnz(predLesion & trueLesion);
    unionCount = nnz(predLesion | trueLesion);
    sumCount = nnz(predLesion) + nnz(trueLesion);

    if sumCount == 0
        diceScores(i) = 1;
        iouScores(i) = 1;
    else
        diceScores(i) = 2 * intersection / sumCount;
        iouScores(i) = intersection / max(unionCount, 1);
    end
end

fprintf("\nDeepLabV3+ + ResNet-101 validation performance (weak pseudo-mask set):\n");
fprintf("  Mean Dice: %.3f\n", mean(diceScores));
fprintf("  Mean IoU : %.3f\n", mean(iouScores));

% ---- Save directly as the deployable model (no comparison step needed) ----
if ~exist("models", "dir")
    mkdir("models");
end
lesionSegNet = deeplabTrainedNet;
lesionSegNetName = "DeepLabV3+ + ResNet-101";
save(fullfile("models", "lesionSegNet.mat"), "lesionSegNet", "lesionSegNetName");
disp("Saved models/lesionSegNet.mat (used by segmentLesionsTrained.m)");
