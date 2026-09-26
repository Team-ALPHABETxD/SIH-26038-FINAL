%% runFullPipelineDemo.m
% End-to-end pipeline runner for SIH 26038.
% Run this section-by-section the first time (click into a section and
% press Ctrl+Enter) so you can inspect intermediate output before moving
% to the next, slower step.

%% Step 0 -- one-time setup check
setupProject;   % sets current folder to project root, adds src/ to path

rawDataCheck = fullfile(pwd, "rawData");
if exist(rawDataCheck, "dir") ~= 7
    error(['Could not find a "rawData" folder at: %s\n' ...
        'Create a folder named rawData in your project root, and place the ' ...
        '5 class folders (Healthy, Mild DR, Moderate DR, Severe DR, ' ...
        'Proliferate DR) directly inside it. See README.md.'], rawDataCheck);
end
fprintf("Found rawData at: %s\n", rawDataCheck);

%% Step 1 -- preprocess raw images (Image Processing Toolbox)
% Crops black borders, applies CLAHE contrast enhancement, denoises,
% resizes to 224x224. Takes a few minutes for ~2750 images.
prepareDataset

%% Step 2 -- build train/val/test datastores with class balancing
buildDatastores

%% Step 3 -- train the DR grading model (Deep Learning Toolbox, CPU)
% This is the slow step. See the header of trainDRModel.m for timing
% guidance and how to switch to resnet18 for faster iteration.
trainDRModel

%% Step 4 -- evaluate against SIH 26038 clinical targets
% Reports per-class PPV/F1/Accuracy/AUC, confusion matrix, ROC curves,
% and referable-DR sensitivity/specificity vs the >90%/>85% targets.
evaluateDRModel

%% Step 5 -- calibrate confidence scores (Statistics and ML Toolbox)
calibrateConfidence

%% Step 6 -- run the full explainable pipeline on one test image
load("datastoreSplit.mat", "imdsTest")
sampleImagePath = imdsTest.Files{1};
results = explainDRPrediction(sampleImagePath); %#ok<NASGU>
