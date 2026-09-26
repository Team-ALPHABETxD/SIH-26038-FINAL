function jsonResult = analyzeRetinalImageAPI(imagePath)
%ANALYZERETINALIMAGEAPI Deployment-safe entry point for backend/frontend use.
%
%   jsonResult = analyzeRetinalImageAPI(imagePath)
%
%   Same pipeline as explainDRPrediction.m (Module 1 quality gate ->
%   Module 3 grading -> Module 4 Grad-CAM + evidence), but designed to be
%   called from OUTSIDE MATLAB (a Python/Node backend) rather than
%   interactively:
%     - Never opens a figure window (figures cannot be displayed on a
%       headless server or sent across a network).
%     - Returns ONE JSON string containing every field the frontend
%       needs, including the Grad-CAM heatmap and the Computer Vision
%       Toolbox annotated image, both base64-encoded PNGs, ready to drop
%       straight into an <img> tag as:
%         <img src="data:image/png;base64,BASE64STRING_HERE">
%
%   This is the function you call from:
%     - MATLAB Engine API for Python (eng.analyzeRetinalImageAPI(path))
%     - A packaged MATLAB Compiler SDK / Production Server deployment

persistent trainedNet classNames inputSize calibModel
if isempty(trainedNet)
    m = load(fullfile("models", "drGradingNet.mat"));
    trainedNet = m.trainedNet;
    classNames = m.classNames;
    inputSize  = m.inputSize;

    c = load(fullfile("models", "calibrationModel.mat"));
    calibModel = c.calibModel;
end

results = struct();
img = imread(imagePath);

% ================= Module 1: quality gate =================
[qualityLabel, qualityScore, feedback] = assessImageQuality(img);
results.qualityLabel = qualityLabel;
results.qualityScore = qualityScore;
results.feedback = feedback;

if qualityLabel == "Reject"
    results.status = "REJECTED";
    jsonResult = jsonencode(results);
    return
end

imgProc = preprocessFundusImage(img, inputSize(1:2));
results.preprocessedImageBase64 = imageToBase64PNG(imgProc);

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
results.referable = ~ismember(predLabel, ["Healthy", "Mild DR"]);

% JSON-friendly per-class scores (avoid returning a MATLAB table directly)
results.allScores = struct( ...
    "className", cellstr(classNames(:)), ...
    "score", num2cell(scores(:)));

% ================= Module 4a: Grad-CAM -> encoded overlay image =================
map = gradCAM(trainedNet, imgProc, predIdx);
heatmapOverlay = renderGradCAMOverlay(imgProc, map);
results.heatmapImageBase64 = imageToBase64PNG(heatmapOverlay);

% ================= Module 4b: lesion evidence (trained model, classical fallback) =================
evidence = segmentLesionsTrained(imgProc);
results.exudateCount = evidence.exudateCount;
results.darkLesionCount = evidence.darkLesionCount;
results.lesionEvidenceSource = evidence.modelUsed;

% ================= Module 4b-1: ICDR criteria mapping =================
criteriaReport = mapEvidenceToICDR(evidence, size(imgProc));
results.icdrQuadrantCounts = criteriaReport.quadrantCounts;
results.icdrQuadrantsAffected = criteriaReport.quadrantsAffected;
results.icdrSevereNPDRFlag = criteriaReport.severeNPDRFlag;
results.icdrCriteriaText = criteriaReport.criteriaText;

% ================= Module 4b-2: annotated evidence image (Computer Vision Toolbox) =================
annotatedImg = imgProc;
if ~isempty(evidence.exudateBoxes)
    annotatedImg = insertShape(annotatedImg, "rectangle", evidence.exudateBoxes, ...
        "Color", "yellow", "LineWidth", 2);
end
if ~isempty(evidence.darkLesionBoxes)
    annotatedImg = insertShape(annotatedImg, "rectangle", evidence.darkLesionBoxes, ...
        "Color", "red", "LineWidth", 2);
end
labelText = sprintf("%s | %.1f%% confidence", predLabel, calibratedConfidence*100);
annotatedImg = insertText(annotatedImg, [5 5], labelText, ...
    "FontSize", 14, "BoxColor", "black", "BoxOpacity", 0.6, "TextColor", "white");
results.annotatedImageBase64 = imageToBase64PNG(annotatedImg);

% ================= Module 4c: evidence text for the reviewing clinician =================
results.evidenceText = sprintf( ...
    "Predicted grade: %s (ICDR %d)  |  Calibrated confidence: %.1f%%  |  Referable: %s\n" + ...
    "Heuristic bright-lesion candidates: %d  |  Heuristic dark-lesion candidates: %d\n" + ...
    "Lesion evidence source: %s\n" + ...
    "%s\n" + ...
    "Grad-CAM overlay shows the image regions most influential to this prediction.\n" + ...
    "Note: lesion evidence and ICDR criteria matching are supporting cues " + ...
    "derived from weakly-supervised/classical signals, not a clinically " + ...
    "validated diagnosis.", ...
    predLabel, results.gradeIndex, calibratedConfidence*100, ...
    string(results.referable), evidence.exudateCount, evidence.darkLesionCount, ...
    evidence.modelUsed, criteriaReport.criteriaText);

jsonResult = jsonencode(results);

end

% ------------------------------------------------------------------
function overlayImg = renderGradCAMOverlay(img, map)
%RENDERGRADCAMOVERLAY Bake the Grad-CAM heatmap onto the image as pixel
%data (no figure/colormap display needed), so it can be saved/encoded.

mapNorm = mat2gray(map);                          % scale to [0,1]
heatmapRGB = ind2rgb(im2uint8(mapNorm), jet(256)); % apply jet colormap
heatmapRGB = imresize(heatmapRGB, [size(img,1) size(img,2)]);

alpha = 0.45;
overlayImg = uint8((1-alpha) * double(img) + alpha * 255 * heatmapRGB);
end

% ------------------------------------------------------------------
function b64 = imageToBase64PNG(img)
%IMAGETOBASE64PNG Encode an image matrix as a base64 PNG string, ready
%to embed directly in an <img src="data:image/png;base64,..."> tag.

tmpFile = [tempname, '.png'];
imwrite(img, tmpFile);

fid = fopen(tmpFile, 'rb');
bytes = fread(fid, Inf, 'uint8=>uint8');
fclose(fid);
delete(tmpFile);

b64 = matlab.net.base64encode(bytes);
end
