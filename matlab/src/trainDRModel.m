%% trainDRModel.m
% Trains the core DR-severity grading model (Module 3) via transfer
% learning. ResNet-101 is the ONLY backbone used in this build, per
% project requirement.
%
% Uses: Deep Learning Toolbox, Image Processing Toolbox, Parallel
% Computing Toolbox (GPU-accelerated training).
%
% *** GPU training via Parallel Computing Toolbox ***
% canUseGPU() checks for both a compatible NVIDIA GPU AND a licensed
% Parallel Computing Toolbox. Since you have a working GPU, this should
% resolve to "gpu" automatically -- no manual configuration needed. If it
% ever reports "cpu" instead, that means either the GPU isn't visible to
% MATLAB or Parallel Computing Toolbox isn't licensed/installed; check
% with gpuDevice() directly in the Command Window if that happens.
%
% *** Why ResNet-101 needs different settings than a smaller backbone ***
% ResNet-101 has roughly 5-6x the layers of ResNet-18 and correspondingly
% higher GPU memory use. MiniBatchSize is reduced accordingly below to
% avoid an out-of-memory error. Expect training to take noticeably
% longer than a smaller backbone even on GPU.
%
% *** On the >90% sensitivity / >85% specificity target ***
% This script trains the model and evaluateDRModel.m reports whether
% that target is met -- no combination of architecture/loss function
% GUARANTEES hitting it; that depends on your dataset's size and label
% quality too. If the first run falls short, see the guidance printed at
% the end of evaluateDRModel.m for what to try next (more epochs, more
% data, adjusting the balancing target in buildDatastores.m).

load("datastoreSplit.mat", "imdsTrainBalanced", "imdsVal", "imdsTest", "classNames");
numClasses = numel(classNames);

% ---- Configuration ----
backboneName = "resnet101";    % fixed per project requirement -- do not change
inputSize = [224 224 3];
miniBatchSize = 8;              % reduced from 32: ResNet-101 is memory-heavy.
                                 % If you hit an out-of-memory error, try 4.
maxEpochs = 20;

% ---- Detect GPU / Parallel Computing Toolbox availability ----
if canUseGPU()
    gpuInfo = gpuDevice();
    executionEnvironment = "gpu";
    fprintf("GPU detected: %s (%.1f GB available memory).\n", ...
        gpuInfo.Name, gpuInfo.AvailableMemory/1e9);
    fprintf("Training will use GPU acceleration via Parallel Computing Toolbox.\n");
else
    executionEnvironment = "cpu";
    fprintf("WARNING: No compatible GPU / Parallel Computing Toolbox detected.\n");
    fprintf("Falling back to CPU. ResNet-101 on CPU will be very slow --\n");
    fprintf("check gpuDevice() in the Command Window if you expected GPU use.\n");
end

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

% ---- Load pretrained ResNet-101, replace head for numClasses ----
fprintf("Loading pretrained %s ...\n", backboneName);
fprintf("(If MATLAB prompts to install 'Deep Learning Toolbox Model for %s Network', do so via Add-On Explorer.)\n", backboneName);
net = imagePretrainedNetwork(backboneName, NumClasses=numClasses);

% ---- Training options ----
options = trainingOptions("sgdm", ...
    InitialLearnRate=5e-4, ...
    LearnRateDropFactor=0.2, ...
    LearnRateDropPeriod=5, ...
    LearnRateSchedule="cosine", ...
    MiniBatchSize=miniBatchSize, ...
    MaxEpochs=maxEpochs, ...
    Shuffle="every-epoch", ...
    Verbose=true, ...
    ValidationData=augVal, ...
    ValidationFrequency=20, ...
    ExecutionEnvironment=executionEnvironment, ...
    Metrics="rmse", ...
    Plots="training-progress");

% ---- Focal cross-entropy loss: down-weights easy/majority-class samples,
%      required per project instruction for training on this imbalanced
%      dataset (combined with the hybrid over/undersampling already
%      applied in buildDatastores.m) ----
lossFcn = @(Y,T) focalCrossEntropy(Y, T, ClassificationMode="single-label");

fprintf("Starting training (%s, %d epochs, %s) ...\n", ...
    backboneName, maxEpochs, upper(executionEnvironment));
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
