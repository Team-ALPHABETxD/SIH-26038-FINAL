function [qualityLabel, qualityScore, feedback] = assessImageQuality(img)
%ASSESSIMAGEQUALITY Module 1: rule-based fundus image quality gate.
%
%   [qualityLabel, qualityScore, feedback] = assessImageQuality(img)
%
%   This is a classical, rule-based check -- NOT a trained model, since
%   the provided dataset has no ground-truth "good/bad image" labels to
%   train a quality classifier against. It uses only Image Processing
%   Toolbox functions and runs in milliseconds, which matters for
%   real-time feedback to a field operator.
%
%   Outputs
%     qualityLabel : "Accept" | "Enhance" | "Reject"
%     qualityScore : 0-100 (higher = better)
%     feedback     : string array of recapture instructions (empty if Accept)
%
%   IMPORTANT: the thresholds below are reasonable starting points, not
%   clinically validated values. Before field deployment, calibrate them
%   against a small hand-labeled set of real handheld-camera images
%   (some clearly good, some clearly blurry/dark/off-center) captured on
%   your actual target device.

gray = rgb2gray(im2double(img));

% ---- 1) Sharpness / focus: variance of the Laplacian response ----
lapKernel = fspecial('laplacian');
lapResp = imfilter(gray, lapKernel, 'replicate');
sharpness = var(lapResp(:));

% ---- 2) Illumination: mean and spread of luminance ----
meanLum = mean(gray(:));

% ---- 3) Field of view: fraction of frame occupied by the retina ----
mask = gray > 0.05;
mask = bwareafilt(mask, 1);
if isempty(mask) || nnz(mask) == 0
    fovRatio = 0;
else
    fovRatio = nnz(mask) / numel(mask);
end

feedback = strings(0);
score = 100;

SHARPNESS_THRESH = 0.0008; % tune against real device images
if sharpness < SHARPNESS_THRESH
    score = score - 40;
    feedback(end+1) = "Image appears blurry. Ensure steady fixation and hold the camera still, then recapture.";
end

if meanLum < 0.15
    score = score - 25;
    feedback(end+1) = "Image is under-illuminated. Increase flash intensity or improve pupil dilation.";
elseif meanLum > 0.85
    score = score - 25;
    feedback(end+1) = "Image is over-exposed or shows glare. Reduce flash intensity or reposition the camera.";
end

if fovRatio < 0.35
    score = score - 30;
    feedback(end+1) = "Retinal field of view is too small or off-center. Recenter on the macula and recapture.";
end

score = max(0, score);
qualityScore = score;

if score >= 70
    qualityLabel = "Accept";
elseif score >= 40
    qualityLabel = "Enhance";
else
    qualityLabel = "Reject";
end

end
