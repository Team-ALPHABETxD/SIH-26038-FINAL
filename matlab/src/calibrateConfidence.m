%% calibrateConfidence.m
% Calibrates the CNN's raw softmax confidence into a well-calibrated
% probability of "this prediction is correct", using Platt scaling
% (logistic regression) fit on the VALIDATION set.
%
% This directly implements the "calibrated confidence scores"
% requirement in SIH 26038's Explainability Module, and is the one step
% in this pipeline that genuinely needs Statistics and Machine Learning
% Toolbox (fitglm) rather than Deep Learning Toolbox.

load(fullfile("models", "drGradingNet.mat"), "trainedNet", "classNames", "inputSize");
load("datastoreSplit.mat", "imdsVal");

augVal = augmentedImageDatastore(inputSize(1:2), imdsVal, "ColorPreprocessing", "gray2rgb");
valScores = minibatchpredict(trainedNet, augVal);

[rawConfidence, predIdx] = max(valScores, [], 2);
predLabels = classNames(predIdx)';
trueLabels = string(imdsVal.Labels);
isCorrect = double(predLabels == trueLabels); % 1 = correct, 0 = incorrect

calibModel = fitglm(rawConfidence, isCorrect, ...
    "Distribution", "binomial", "Link", "logit");

if ~exist("models", "dir")
    mkdir("models");
end
save(fullfile("models", "calibrationModel.mat"), "calibModel");

disp("Calibration model saved to models/calibrationModel.mat");
disp(calibModel)

% ---- Visualize the calibration curve ----
x = linspace(0, 1, 100)';
yCalibrated = predict(calibModel, x);

figure;
plot(x, x, "--", "LineWidth", 1.2); hold on;
plot(x, yCalibrated, "-", "LineWidth", 1.8); hold off;
xlabel("Raw softmax confidence");
ylabel("Calibrated P(prediction is correct)");
legend("Uncalibrated (identity)", "Calibrated", "Location", "best");
title("Confidence Calibration Curve (Platt Scaling)");
grid on;
