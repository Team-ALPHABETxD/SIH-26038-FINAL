function evidence = highlightLesionCandidates(img)
%HIGHLIGHTLESIONCANDIDATES Module 2 (classical heuristic, NOT a trained model).
%
%   evidence = highlightLesionCandidates(img)
%
%   *** SCOPE NOTE (read this) ***
%   The dataset in archive.zip (Healthy / Mild DR / Moderate DR /
%   Severe DR / Proliferate DR folders) contains only IMAGE-LEVEL DR
%   grade labels. It does NOT contain pixel-level ground-truth masks for
%   microaneurysms, hemorrhages, exudates, vessels, or neovascularization.
%   You cannot train a real deep-learning segmentation network (U-Net
%   etc.) for those structures from this dataset -- that requires a
%   pixel-annotated dataset such as IDRiD, e-ophtha-MA, or DDR-lesion.
%
%   This function is a classical, morphology-only APPROXIMATION using
%   Image Processing Toolbox functions (top-hat / bottom-hat filtering).
%   It gives a rough visual cue for the explainability report and a
%   secondary rule-based signal, but it is not clinically validated and
%   should never be presented as equivalent to a trained lesion detector.
%   If/when you obtain a pixel-annotated dataset, replace this function
%   with a U-Net trained via unetLayers + trainnet, and everything
%   downstream (explainDRPrediction.m) will keep working unchanged.
%
%   Output (struct)
%     exudateMask      - logical mask, candidate bright lesions
%     darkLesionMask    - logical mask, candidate dark lesions (MA/hemorrhage)
%     exudateCount      - number of candidate bright-lesion blobs
%     darkLesionCount   - number of candidate dark-lesion blobs
%     isHeuristic       - always true (flag for downstream reporting)

if size(img,3) == 3
    greenChannel = img(:,:,2); % best vessel/lesion contrast in the green channel
else
    greenChannel = img;
end

% ---- Bright lesion candidates (hard exudates): top-hat filtering ----
seExudate = strel('disk', 8);
tophatBright = imtophat(greenChannel, seExudate);
exudateMask = imbinarize(tophatBright, 'adaptive', 'Sensitivity', 0.6);
exudateMask = bwareaopen(exudateMask, 4);

% ---- Dark lesion candidates (microaneurysms / small hemorrhages) ----
seDark = strel('disk', 6);
tophatDark = imbothat(greenChannel, seDark);
darkMask = imbinarize(tophatDark, 'adaptive', 'Sensitivity', 0.6);
darkMask = bwareaopen(darkMask, 3);

evidence.exudateMask = exudateMask;
evidence.darkLesionMask = darkMask;
evidence.exudateCount = max([0, max(bwlabel(exudateMask), [], 'all')]);
evidence.darkLesionCount = max([0, max(bwlabel(darkMask), [], 'all')]);
evidence.isHeuristic = true;

end
