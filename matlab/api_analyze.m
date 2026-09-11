
function api_analyze(imagePath, outputDir)
% API_ANALYZE Bridge between the Flask web backend and the trained MATLAB pipeline.
% Usage from command line:
%   matlab -batch "api_analyze('input.jpg','results/run123')"
%
% The original explainDRPrediction pipeline remains the source of truth.

if ~exist(outputDir, "dir"), mkdir(outputDir); end
payload = struct();
payload.ok = false;

try
    results = explainDRPrediction(imagePath);
    payload.ok = true;
    payload.status = char(results.status);
    payload.qualityLabel = char(results.qualityLabel);
    payload.qualityScore = double(results.qualityScore);
    payload.feedback = cellstr(results.feedback);

    if results.status == "REJECTED"
        payload.message = "Image did not pass the quality gate.";
        writeJson(payload, fullfile(outputDir, "result.json"));
        return;
    end

    payload.grade = char(results.grade);
    payload.gradeIndex = double(results.gradeIndex);
    payload.rawConfidence = double(extractdata(results.rawConfidence));
    payload.calibratedConfidence = double(extractdata(results.calibratedConfidence));
    payload.referable = logical(results.referable);
    payload.evidenceText = char(results.evidenceText);

    % Class probabilities
    classNames = string(results.allScores.Class);
    classScores = double(results.allScores.Score);
    scoreStruct = struct();
    for k = 1:numel(classNames)
        key = matlab.lang.makeValidName(char(classNames(k)));
        scoreStruct.(key) = classScores(k);
    end
    payload.allScores = scoreStruct;

    % Lesion evidence is explicitly heuristic in the supplied MATLAB code.
    payload.lesionEvidence = struct( ...
        "exudateCount", double(results.lesionEvidence.exudateCount), ...
        "darkLesionCount", double(results.lesionEvidence.darkLesionCount), ...
        "isHeuristic", logical(results.lesionEvidence.isHeuristic));

    % Save preprocessed image.
    img = imread(imagePath);
    imgProc = preprocessFundusImage(img, [224 224]);
    imwrite(imgProc, fullfile(outputDir, "preprocessed.png"));

    % Save raw Grad-CAM heatmap.
    map = double(extractdata(results.heatmap));
    map = mat2gray(map);
    imwrite(map, fullfile(outputDir, "gradcam.png"));

    % Save an aesthetic overlay without opening a MATLAB figure.
    heatRGB = ind2rgb(uint8(round(map * 255)), jet(256));
    base = im2double(imgProc);
    overlay = 0.55 * base + 0.45 * heatRGB;
    overlay = min(max(overlay,0),1);
    imwrite(overlay, fullfile(outputDir, "gradcam_overlay.png"));

    % Save heuristic lesion-candidate overlay.
    exMask = logical(results.lesionEvidence.exudateMask);
    darkMask = logical(results.lesionEvidence.darkLesionMask);
    lesionOverlay = base;
    % Bright candidates are rendered in red; dark candidates in blue.
    lesionOverlay(:,:,1) = min(1, lesionOverlay(:,:,1) + 0.55*double(exMask));
    lesionOverlay(:,:,2) = lesionOverlay(:,:,2) .* (1 - 0.30*double(darkMask));
    lesionOverlay(:,:,3) = min(1, lesionOverlay(:,:,3) + 0.55*double(darkMask));
    imwrite(min(max(lesionOverlay,0),1), fullfile(outputDir, "lesion_overlay.png"));

    payload.artifacts = struct( ...
        "preprocessed", "preprocessed.png", ...
        "gradcam", "gradcam.png", ...
        "gradcamOverlay", "gradcam_overlay.png", ...
        "lesionOverlay", "lesion_overlay.png");

    writeJson(payload, fullfile(outputDir, "result.json"));
catch ME
    payload.ok = false;
    payload.error = ME.message;
    writeJson(payload, fullfile(outputDir, "result.json"));
    rethrow(ME);
end
end

function writeJson(s, path)
txt = jsonencode(s);
fid = fopen(path, "w");
if fid < 0, error("Could not open JSON output file: %s", path); end
fwrite(fid, txt, "char");
fclose(fid);
end
