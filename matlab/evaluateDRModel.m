%% evaluateDRModel.m
% Evaluates the trained DR grading model on the held-out test set and
% reports the metrics required by SIH 26038: per-class PPV/F1/Accuracy/AUC,
% confusion matrix, and referable-DR (Grade >= 2) sensitivity/specificity.
%
% Uses ONLY: Deep Learning Toolbox (rocmetrics, confusionchart), Image
% Processing Toolbox (implicitly, via the datastore pipeline).

load(fullfile("models", "drGradingNet.mat"), "trainedNet", "classNames", "inputSize");
load("datastoreSplit.mat", "imdsTest");

augTest = augmentedImageDatastore(inputSize(1:2), imdsTest, "ColorPreprocessing", "gray2rgb");

predScores = minibatchpredict(trainedNet, augTest);
trueLabels = string(imdsTest.Labels);

rocObj = rocmetrics(trueLabels, predScores, classNames, ...
    AdditionalMetrics=["ppv", "f1score", "accu"]);
metricsTbl = rocObj.Metrics;
aucScores = auc(rocObj);

results = table(Size=[numel(classNames) 5], ...
    VariableTypes=["string", "double", "double", "double", "double"], ...
    VariableNames=["ClassName", "PPV", "F1Score", "Accuracy", "AUC"]);

for i = 1:numel(classNames)
    className = classNames(i);
    rows = metricsTbl.ClassName == className;
    sub = metricsTbl(rows, :);
    [maxF1, idx] = max(sub.F1Score);
    results.ClassName(i) = className;
    results.PPV(i) = sub.PositivePredictiveValue(idx);
    results.F1Score(i) = maxF1;
    results.Accuracy(i) = sub.Accuracy(idx);
    results.AUC(i) = aucScores(i);
end

disp("Per-class metrics:");
disp(results)

figure;
plot(rocObj, ShowModelOperatingPoint=false);
title("ROC Curves per DR Grade");

[~, predIdx] = max(predScores, [], 2);
predLabels = classNames(predIdx)';

figure;
confusionchart(trueLabels, predLabels, ...
    RowSummary="row-normalized", ColumnSummary="column-normalized", ...
    Title="DR Grading Confusion Matrix");

% ---- Clinically critical metric: Referable DR (Grade >= 2, i.e.
%      Moderate/Severe/Proliferate) sensitivity and specificity ----
referableTrue = ~ismember(trueLabels, ["Healthy", "Mild DR"]);
referablePred = ~ismember(predLabels, ["Healthy", "Mild DR"]);

TP = sum(referableTrue & referablePred);
FN = sum(referableTrue & ~referablePred);
TN = sum(~referableTrue & ~referablePred);
FP = sum(~referableTrue & referablePred);

sensitivity = TP / max(1, (TP + FN));
specificity = TN / max(1, (TN + FP));

fprintf("\nReferable DR (Grade >= 2) screening performance:\n");
fprintf("  Sensitivity : %.2f%%  (SIH 26038 target: > 90%%)\n", sensitivity*100);
fprintf("  Specificity : %.2f%%  (SIH 26038 target: > 85%%)\n", specificity*100);

if sensitivity > 0.90 && specificity > 0.85
    fprintf("  --> Meets SIH 26038 clinical acceptability targets.\n");
else
    fprintf("  --> Does NOT yet meet targets. Consider: more epochs, more\n");
    fprintf("      training data, a deeper backbone, or better calibration\n");
    fprintf("      of the decision threshold (see calibrateConfidence.m).\n");
end

save("evaluationResults.mat", "results", "sensitivity", "specificity");
