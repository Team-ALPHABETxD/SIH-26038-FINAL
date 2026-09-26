function evidence = segmentLesionsTrained(img)
%SEGMENTLESIONSTRAINED Module 2: trained lesion segmentation, with a
%classical fallback.
%
%   evidence = segmentLesionsTrained(img)
%
%   Uses the trained segmentation model (DeepLabV3+ResNet-101, the only
%   segmentation architecture in this build, saved as
%   models/lesionSegNet.mat by trainSegmentation_DeepLabV3ResNet101.m) Falls back automatically to
%   the classical heuristic (highlightLesionCandidates.m) if no trained
%   model is present yet, so the rest of the pipeline keeps working
%   either way -- explainDRPrediction.m and analyzeRetinalImageAPI.m can
%   call this function unconditionally.
%
%   IMPORTANT: the trained model (if present) was trained on WEAK
%   pseudo-masks (see generatePseudoMasks.m), not true expert-annotated
%   segmentation ground truth. Report it as "weakly-supervised lesion
%   localization", not clinically validated pixel-accurate segmentation.

persistent lesionSegNet lesionSegNetName modelAvailable
if isempty(modelAvailable)
    modelPath = fullfile("models", "lesionSegNet.mat");
    if exist(modelPath, "file") == 2
        s = load(modelPath);
        lesionSegNet = s.lesionSegNet;
        lesionSegNetName = s.lesionSegNetName;
        modelAvailable = true;
        fprintf("segmentLesionsTrained: using trained model (%s)\n", lesionSegNetName);
    else
        modelAvailable = false;
        fprintf("segmentLesionsTrained: no trained segmentation model found, ");
        fprintf("using classical heuristic fallback.\n");
    end
end

if modelAvailable
    predMask = semanticseg(img, lesionSegNet);
    lesionMask = predMask == "lesion";

    evidence.exudateMask = lesionMask;
    evidence.darkLesionMask = false(size(lesionMask));
    evidence.isHeuristic = false;
    evidence.modelUsed = lesionSegNetName;
else
    evidence = highlightLesionCandidates(img);
    evidence.modelUsed = "classical heuristic (no trained model available)";
end

% ---- Combined blob stats, used by mapEvidenceToICDR.m for quadrant
%      analysis regardless of which path produced the mask ----
combinedMask = evidence.exudateMask | evidence.darkLesionMask;
statsAll = regionprops(combinedMask, "BoundingBox", "Centroid");

if isempty(statsAll)
    evidence.lesionBoxes = zeros(0, 4);
    evidence.lesionCentroids = zeros(0, 2);
else
    evidence.lesionBoxes = vertcat(statsAll.BoundingBox);
    evidence.lesionCentroids = vertcat(statsAll.Centroid);
end

if ~isfield(evidence, "exudateCount")
    evidence.exudateCount = size(regionprops(evidence.exudateMask, "Centroid"), 1);
end
if ~isfield(evidence, "darkLesionCount")
    evidence.darkLesionCount = size(regionprops(evidence.darkLesionMask, "Centroid"), 1);
end
if ~isfield(evidence, "exudateBoxes")
    statsExudate = regionprops(evidence.exudateMask, "BoundingBox");
    if isempty(statsExudate)
        evidence.exudateBoxes = zeros(0, 4);
    else
        evidence.exudateBoxes = vertcat(statsExudate.BoundingBox);
    end
end
if ~isfield(evidence, "darkLesionBoxes")
    statsDark = regionprops(evidence.darkLesionMask, "BoundingBox");
    if isempty(statsDark)
        evidence.darkLesionBoxes = zeros(0, 4);
    else
        evidence.darkLesionBoxes = vertcat(statsDark.BoundingBox);
    end
end

end
