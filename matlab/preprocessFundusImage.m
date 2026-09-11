function imgOut = preprocessFundusImage(imgIn, targetSize)
%PREPROCESSFUNDUSIMAGE Standardize a raw fundus image for DR grading.
%
%   imgOut = preprocessFundusImage(imgIn, targetSize)
%
%   Replicates the preprocessing philosophy of the MathWorks example
%   "Multilabel Diabetic Retinopathy Fundus Image Classification Using
%   Deep Learning" (Medical Imaging Toolbox documentation):
%       1. Crop to remove unnecessary black border around the retina
%       2. Contrast enhancement (CLAHE on the L channel, tile 8x8,
%          clip limit 0.05)
%       3. Noise removal (mild Gaussian smoothing after CLAHE)
%       4. Resize to the network input size
%
%   NOTE ON STEP "Color Normalization": the reference example subtracts
%   the per-channel mean and divides by the per-channel std as an
%   offline step. We deliberately skip that here because
%   imagePretrainedNetwork's built-in image input layer already applies
%   its own (ImageNet-style) normalization internally -- doing both would
%   double-normalize the data and can hurt transfer-learning accuracy.
%   If you want to reproduce the reference pipeline exactly, set
%   NORMALIZE_CHANNELS = true below.
%
%   Uses ONLY Image Processing Toolbox functions.
%
%   Inputs
%     imgIn      - uint8 RGB fundus image (H x W x 3)
%     targetSize - [rows cols], e.g. [224 224] for ResNet-101/50/18
%
%   Output
%     imgOut     - uint8 RGB image, size targetSize(1) x targetSize(2) x 3

NORMALIZE_CHANNELS = false; % set true to replicate the reference doc exactly

if nargin < 2
    targetSize = [224 224];
end

if size(imgIn,3) == 1
    imgIn = repmat(imgIn, 1, 1, 3); % guard against stray grayscale images
end

% ---- Step 1: crop black border around the retina (skip if already tight) ----
imgCropped = cropRetinaFOV(imgIn);

% ---- Step 2: CLAHE contrast enhancement on the L channel ----
imgDouble = im2double(imgCropped);
labImg = rgb2lab(imgDouble);
L = labImg(:,:,1) / 100;                      % scale L to [0,1] for adapthisteq
L_eq = adapthisteq(L, 'NumTiles', [8 8], 'ClipLimit', 0.05);
labImg(:,:,1) = L_eq * 100;
imgEnhanced = lab2rgb(labImg);
imgEnhanced = max(0, min(1, imgEnhanced));    % clip any small out-of-range values
imgEnhanced = im2uint8(imgEnhanced);

% ---- Step 3: mild denoise (CLAHE can amplify sensor noise) ----
imgDenoised = imgaussfilt(imgEnhanced, 0.6);

% ---- Step 4 (optional): per-channel z-score normalization ----
if NORMALIZE_CHANNELS
    imgD = im2double(imgDenoised);
    for c = 1:3
        ch = imgD(:,:,c);
        imgD(:,:,c) = (ch - mean(ch(:))) / (std(ch(:)) + eps);
    end
    imgDenoised = im2uint8(mat2gray(imgD)); % rescale back to displayable range
end

% ---- Step 5: resize to network input size ----
imgOut = imresize(imgDenoised, targetSize);

end

% ------------------------------------------------------------------
function cropped = cropRetinaFOV(img)
%CROPRETINAFOV Detect the circular retina field-of-view and crop tightly
%around it, removing surrounding black margin. Falls back to the
%original image if no clear foreground region is found (e.g. the image
%is already tightly cropped, as is common in pre-processed datasets).

gray = rgb2gray(img);
mask = gray > 10; % anything brighter than near-black is "retina"
mask = bwareafilt(mask, 1); % keep only the largest connected component

stats = regionprops(mask, 'BoundingBox');
if isempty(stats)
    cropped = img;
    return
end

bbox = stats(1).BoundingBox; % [x y width height]

% If the bounding box already covers ~95%+ of the image, there is no
% meaningful black border to remove -- skip cropping.
coverage = (bbox(3) * bbox(4)) / numel(gray);
if coverage > 0.90
    cropped = img;
    return
end

margin = 0.02; % small safety margin so we don't clip retina edge features
x1 = max(1, floor(bbox(1) - margin * bbox(3)));
y1 = max(1, floor(bbox(2) - margin * bbox(4)));
x2 = min(size(img,2), ceil(bbox(1) + bbox(3) * (1 + margin)));
y2 = min(size(img,1), ceil(bbox(2) + bbox(4) * (1 + margin)));

cropped = img(y1:y2, x1:x2, :);
end
