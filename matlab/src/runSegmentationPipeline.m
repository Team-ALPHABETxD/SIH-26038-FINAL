%% runSegmentationPipeline.m
% End-to-end runner for Module 2 (lesion segmentation): DeepLabV3+ with
% ResNet-101, the only segmentation architecture used in this build.
% Run this AFTER runFullPipelineDemo.m has already completed (needs a
% trained models/drGradingNet.mat to generate pseudo-masks from).
%
% Run section-by-section the first time (Ctrl+Enter per section).

%% Step 0 -- setup + sanity checks
setupProject;

assert(exist(fullfile("models", "drGradingNet.mat"), "file") == 2, ...
    "models/drGradingNet.mat not found -- run runFullPipelineDemo.m first.");

if canUseGPU()
    gpuInfo = gpuDevice();
    fprintf("GPU detected: %s (%.1f GB available).\n", gpuInfo.Name, gpuInfo.AvailableMemory/1e9);
else
    fprintf("WARNING: No GPU detected -- check gpuDevice() if you expected GPU use.\n");
end

%% Step 1 -- generate weak pseudo-masks (Grad-CAM + classical heuristic)
% Read generatePseudoMasks.m's header before running this -- important
% caveat about what these masks are and are not.
generatePseudoMasks

%% Step 2 -- build segmentation train/validation datastores
buildSegmentationDatastores

%% Step 3 -- train DeepLabV3+ + ResNet-101 (trains, evaluates, and saves
%           models/lesionSegNet.mat in one script)
trainSegmentation_DeepLabV3ResNet101

%% Step 4 -- test the full Module 2 pipeline (trained model + ICDR mapping) on one image
load("datastoreSplit.mat", "imdsTest")
sampleImagePath = imdsTest.Files{1};
results = explainDRPrediction(sampleImagePath); %#ok<NASGU>
