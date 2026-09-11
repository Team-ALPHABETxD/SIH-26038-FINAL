function results = explainDRPrediction(imagePath)
%EXPLAINDRPREDICTION Single entry-point orchestrator for one fundus image.
%
%   results = explainDRPrediction(imagePath)
%
%   Runs the full explainable screening pipeline on one image:
%     Module 1 - quality gate            (assessImageQuality.m)
%     Module 3 - DR severity grading      (trained CNN, models/drGradingNet.mat)
%     Module 4 - Grad-CAM + calibrated confidence + evidence report
%                (+ classical Module 2 lesion cues as a supporting signal)
%
%   This is the function you would package with MATLAB Compiler SDK for
%   Production Server / web app deployment (see README.md, Deployment
%   section) -- everything the app needs happens inside this one call.
%
%   Uses ONLY: Deep Learning Toolbox, Image Processing Toolbox,
%   Statistics and Machine Learning Toolbox (via the calibration model).

persistent trainedNet classNames inputSize calibModel
if isempty(trainedNet)
    m = load(fullfile("models", "drGradingNet.mat"));
    trainedNet = m.trainedNet;
    classNames = m.classNames;
    inputSize  = m.inputSize;

    c = load(fullfile("models", "calibrationModel.mat"));
    calibModel = c.calibModel;
end

img = imread(imagePath);

% ================= Module 1: quality gate =================
[qualityLabel, qualityScore, feedback] = assessImageQuality(img);
results.qualityLabel = qualityLabel;
results.qualityScore = qualityScore;
results.feedback = feedback;

if qualityLabel == "Reject"
    results.status = "REJECTED";
    fprintf("Image REJECTED (quality score %.0f/100). Feedback:\n", qualityScore);
    for k = 1:numel(feedback)
        fprintf("  - %s\n", feedback(k));
    end
    return
end

imgProc = preprocessFundusImage(img, inputSize(1:2));

% ================= Module 3: DR severity grading =================
scores = predict(trainedNet, single(imgProc));
[rawConfidence, predIdx] = max(scores);
predLabel = classNames(predIdx);
calibratedConfidence = predict(calibModel, rawConfidence);

results.status = "GRADED";
results.grade = predLabel;
results.gradeIndex = predIdx - 1; % ICDR scale: 0=Healthy ... 4=Proliferate DR
results.rawConfidence = rawConfidence;
results.calibratedConfidence = calibratedConfidence;
results.allScores = table(classNames', scores(:), VariableNames=["Class", "Score"]);
results.referable = ~ismember(predLabel, ["Healthy", "Mild DR"]);

% ================= Module 4a: Grad-CAM explainability =================
map = gradCAM(trainedNet, imgProc, predIdx);
results.heatmap = map;

figure;
imshow(imgProc); hold on;
imagesc(map, "AlphaData", 0.45);
colormap jet;
hold off;
title(sprintf("Grad-CAM: %s (calibrated confidence %.1f%%)", ...
    predLabel, calibratedConfidence*100));

% ================= Module 4b: classical lesion cues (heuristic) =================
% See highlightLesionCandidates.m header: this is NOT a trained
% segmentation network, just a classical supporting signal.
evidence = highlightLesionCandidates(imgProc);
results.lesionEvidence = evidence;

% ================= Module 4c: evidence text for the reviewing clinician =================
results.evidenceText = sprintf( ...
    "Predicted grade: %s (ICDR %d)  |  Calibrated confidence: %.1f%%  |  Referable: %s\n" + ...
    "Heuristic bright-lesion candidates: %d  |  Heuristic dark-lesion candidates: %d\n" + ...
    "Grad-CAM overlay shows the image regions most influential to this prediction.\n" + ...
    "Note: heuristic lesion counts come from classical image processing, not a\n" + ...
    "trained segmentation network -- treat as a supporting cue, not a diagnosis.", ...
    predLabel, results.gradeIndex, calibratedConfidence*100, ...
    string(results.referable), evidence.exudateCount, evidence.darkLesionCount);

disp(results.evidenceText)

end
