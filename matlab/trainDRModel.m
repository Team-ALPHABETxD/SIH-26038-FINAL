%% trainDRModel.m
% Trains the core DR-severity grading model (Module 3) via transfer
% learning, following the same methodology as the MathWorks reference
% example "Multilabel Diabetic Retinopathy Fundus Image Classification
% Using Deep Learning" (Medical Imaging Toolbox documentation), adapted
% to the folder-labeled dataset in archive.zip.
%
% Uses ONLY: Deep Learning Toolbox, Image Processing Toolbox.
%
% *** IMPORTANT: NO Parallel Computing Toolbox ***
% Per your requirement, Parallel Computing Toolbox is intentionally not
% used. trainnet() therefore trains on CPU only, even if your machine has
% a GPU (MATLAB requires Parallel Computing Toolbox to use a GPU for
% training). Expect CPU training of ResNet-101 on ~1900 balanced training
% images to take roughly several hours on a typical laptop CPU, depending
% on core count. Two ways to speed up iteration while developing:
%   1. Set backboneName = "resnet18" below (much faster, slightly lower
%      accuracy) to validate the whole pipeline quickly first.
%   2. Reduce MaxEpochs for a quick smoke test, then increase for the
%      final run you'll report/demo.

load("datastoreSplit.mat", "imdsTrainBalanced", "imdsVal", "imdsTest", "classNames");
numClasses = numel(classNames);

% ---- Configuration ----
backboneName = "resnet101";   % "resnet101" | "resnet50" | "resnet18"
inputSize = [224 224 3];
miniBatchSize = 16;            % lower than the reference's 32 to keep CPU memory usage reasonable
maxEpochs = 15;

% ---- Data augmentation (reduces overfitting, helps minority classes) ----
augmenter = imageDataAugmenter( ...
    "RandRotation", [-15 15], ...
    "RandXTranslation", [-10 10], ...
    "RandYTranslation", [-10 10], ...
    "RandXReflection", true);

augTrain = augmentedImageDatastore(inputSize(1:2), imdsTrainBalanced, ...
    "ColorPreprocessing", "gray2rgb", "DataAugmentation", augmenter);
augVal = augmentedImageDatastore(inputSize(1:2), imdsVal, ...
    "ColorPreprocessing", "gray2rgb");

% ---- Load pretrained backbone, replace head for numClasses ----
fprintf("Loading pretrained %s ...\n", backboneName);
fprintf("(If MATLAB prompts to install 'Deep Learning Toolbox Model for %s Network', do so via Add-On Explorer.)\n", backboneName);
net = imagePretrainedNetwork(backboneName, NumClasses=numClasses);

% ---- Training options (mirrors the reference example) ----
options = trainingOptions("sgdm", ...
    InitialLearnRate=5e-4, ...
    LearnRateDropFactor=0.2, ...
    LearnRateDropPeriod=5, ...
    LearnRateSchedule="cosine", ...
    MiniBatchSize=miniBatchSize, ...
    MaxEpochs=maxEpochs, ...
    Verbose=true, ...
    ValidationData=augVal, ...
    ValidationFrequency=20, ...
    ExecutionEnvironment="cpu", ...    % explicit: no Parallel Computing Toolbox available
    Metrics="rmse", ...
    Plots="training-progress");

% ---- Focal cross-entropy loss: down-weights easy/majority-class samples,
%      helps with the Healthy/Moderate DR vs Mild/Severe/Proliferate DR
%      class imbalance seen in this dataset ----
lossFcn = @(Y,T) focalCrossEntropy(Y, T, ClassificationMode="single-label");

fprintf("Starting training (%s, %d epochs, CPU) ...\n", backboneName, maxEpochs);
tic
trainedNet = trainnet(augTrain, net, lossFcn, options);
trainingTimeSeconds = toc;
fprintf("Training finished in %.1f minutes.\n", trainingTimeSeconds/60);

% ---- Save the trained model ----
if ~exist("models", "dir")
    mkdir("models");
end
save(fullfile("models", "drGradingNet.mat"), ...
    "trainedNet", "classNames", "inputSize", "backboneName");

disp("Model saved to models/drGradingNet.mat");
