function criteriaReport = mapEvidenceToICDR(evidence, imgSize)
%MAPEVIDENCETOICDR Rule-based ICDR criteria checklist from lesion evidence.
%
%   criteriaReport = mapEvidenceToICDR(evidence, imgSize)
%
%   Implements the lesion-count-per-quadrant component of the "4-2-1
%   rule" used to define Severe NPDR, using evidence.lesionCentroids
%   (produced by segmentLesionsTrained.m).
%
%   SCOPE NOTE: full ICDR Severe NPDR grading also requires assessing
%   venous beading and IRMA (intraretinal microvascular abnormalities),
%   which this pipeline does not detect (no trained detector for those
%   specific patterns exists in this project). This function checks the
%   hemorrhage/lesion-quadrant-distribution criterion only, as a
%   supporting cross-check against the CNN's grade -- not a complete,
%   standalone ICDR grading system on its own.
%
%   Output (struct)
%     quadrantCounts     - 1x4 vector, lesion count per quadrant (Q1..Q4)
%     quadrantsAffected  - number of quadrants with >=1 lesion
%     severeNPDRFlag     - true if lesions present in all 4 quadrants
%                           (simplified proxy for the 4-2-1 rule's
%                           lesion-distribution criterion)
%     criteriaText        - human-readable string for the clinician report

centroids = evidence.lesionCentroids;
h = imgSize(1);
w = imgSize(2);
cx = w / 2;
cy = h / 2;

quadrantCounts = zeros(1, 4);
for i = 1:size(centroids, 1)
    x = centroids(i, 1);
    y = centroids(i, 2);
    if x >= cx && y < cy
        quadrantCounts(1) = quadrantCounts(1) + 1; % top-right
    elseif x < cx && y < cy
        quadrantCounts(2) = quadrantCounts(2) + 1; % top-left
    elseif x < cx && y >= cy
        quadrantCounts(3) = quadrantCounts(3) + 1; % bottom-left
    else
        quadrantCounts(4) = quadrantCounts(4) + 1; % bottom-right
    end
end

quadrantsAffected = nnz(quadrantCounts > 0);
severeNPDRFlag = quadrantsAffected == 4;

criteriaReport.quadrantCounts = quadrantCounts;
criteriaReport.quadrantsAffected = quadrantsAffected;
criteriaReport.severeNPDRFlag = severeNPDRFlag;

if severeNPDRFlag
    criteriaReport.criteriaText = sprintf( ...
        "Severe NPDR criterion (4-2-1 rule, lesion-distribution component) MATCHED: " + ...
        "lesions detected in all 4 quadrants (Q1:%d Q2:%d Q3:%d Q4:%d). " + ...
        "Recommend cross-checking this case even if the CNN grade is lower than Severe NPDR.", ...
        quadrantCounts(1), quadrantCounts(2), quadrantCounts(3), quadrantCounts(4));
elseif quadrantsAffected >= 2
    criteriaReport.criteriaText = sprintf( ...
        "Lesions detected in %d/4 quadrants (Q1:%d Q2:%d Q3:%d Q4:%d). " + ...
        "Does not meet the simplified Severe NPDR quadrant criterion, " + ...
        "but multi-quadrant involvement is consistent with at least Moderate NPDR.", ...
        quadrantsAffected, quadrantCounts(1), quadrantCounts(2), quadrantCounts(3), quadrantCounts(4));
else
    criteriaReport.criteriaText = sprintf( ...
        "Lesions detected in %d/4 quadrants (Q1:%d Q2:%d Q3:%d Q4:%d). " + ...
        "Limited/localized involvement only.", ...
        quadrantsAffected, quadrantCounts(1), quadrantCounts(2), quadrantCounts(3), quadrantCounts(4));
end

end
