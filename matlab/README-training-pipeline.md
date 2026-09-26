# SIH 26038 — MATLAB Training Pipeline (Ready to Run in R2026a)

This package trains and explains a Diabetic Retinopathy severity grading
model from your uploaded dataset (`archive.zip`), following the
methodology of the MathWorks reference example *"Multilabel Diabetic
Retinopathy Fundus Image Classification Using Deep Learning"*, adapted to
your specific dataset and toolbox constraints.

## 1. What's in your dataset (already verified)

`archive.zip` contains **2,750 fundus images**, all 256×256 RGB PNGs, in
five class folders that map directly onto the ICDR severity scale:

| Folder            | ICDR Grade | Count |
|-------------------|:----------:|------:|
| Healthy           | 0          | 1000  |
| Mild DR           | 1          | 370   |
| Moderate DR       | 2          | 900   |
| Severe DR         | 3          | 190   |
| Proliferate DR    | 4          | 290   |

All 2,750 images loaded and verified successfully (no corrupt files).

## 2. Important scope note — please read before you start

This dataset has **image-level DR grade labels only**. It does **not**
contain pixel-level masks for microaneurysms, hemorrhages, hard
exudates, vessels, or neovascularization — this remains true even if
you merge in additional data (APTOS, IDRiD's Disease Grading subset,
etc.) as long as it keeps the same 5-folder structure, since folder-
level labels are still image-level, not pixel-level.

- ✅ **Module 3 (DR severity grading)** — fully trainable from this data.
- ✅ **Module 4 (Explainability)** — fully supported via Grad-CAM plus
  calibrated confidence.
- ✅ **Module 2 (lesion segmentation) — now implemented via WEAK
  SUPERVISION.** See section 2b below for full details. This is a real
  trained U-Net/DeepLabV3+ network, but trained on approximate
  pseudo-masks, not expert pixel annotations — report it accordingly.
- ✅ **Module 1 (quality gate)** — rule-based, tune thresholds against
  real handheld-camera images before field use.
- 📎 **Module 5 (Simulink)** — not part of this package yet.

## 2b. Module 2: weakly-supervised lesion segmentation

**This build uses ONLY ResNet-101 (classification) and DeepLabV3+ with a
ResNet-101 backbone (segmentation)** — no architecture comparison, no
alternative backbones. Since no dataset with real pixel-level lesion
masks is available, Module 2 uses **weak supervision**: Grad-CAM
attention from your trained classifier is combined with the classical
lesion heuristic to produce approximate pseudo-masks, and DeepLabV3+ is
trained against those pseudo-masks.

| File | Role |
|---|---|
| `generatePseudoMasks.m` | Combines Grad-CAM + classical heuristic into pseudo-masks saved to `pseudoMasks/` |
| `buildSegmentationDatastores.m` | Builds train/val `pixelLabelDatastore` pairs from `preprocessedData/` + `pseudoMasks/` |
| `trainSegmentation_DeepLabV3ResNet101.m` | Trains DeepLabV3+ResNet-101, evaluates Dice/IoU on validation, and saves `models/lesionSegNet.mat` directly — one self-contained script |
| `segmentLesionsTrained.m` | Module 2's entry point — uses the trained model if present, otherwise falls back to the classical heuristic automatically |
| `mapEvidenceToICDR.m` | Maps lesion quadrant distribution to the Severe NPDR "4-2-1 rule" lesion-count criterion |

**Run this whole sub-pipeline with `runSegmentationPipeline.m`** (after
`runFullPipelineDemo.m` has already produced a trained
`models/drGradingNet.mat`, since pseudo-mask generation needs it).

**Loss function note:** both the classification model (`trainDRModel.m`)
and the segmentation model use `focalCrossEntropy`, per project
requirement — for segmentation this down-weights the large majority of
"easy" background pixels, addressing the foreground/background
imbalance within each mask the same way it addresses class imbalance in
the classification labels.

**Read `generatePseudoMasks.m`'s header before you run it or present
these results.** The short version: these masks are a legitimate,
published technique (weak supervision from image-level labels), but
they are meaningfully less accurate than a network trained on true
expert pixel annotations (e.g. IDRiD's separate Segmentation subset,
which is a different download from its Disease Grading subset and has
only 54 training images). Present this honestly as "weakly-supervised
lesion localization" in your report/demo, not as clinically validated
segmentation.

**On the >90% sensitivity / >85% specificity target:** `evaluateDRModel.m`
reports whether your trained model meets this after every run — no
combination of architecture or loss function guarantees hitting it on
the first attempt, since it also depends on dataset size and label
quality. If you fall short, the guidance printed at the end of that
script (more epochs, more data, adjusting the balancing target) is the
place to start. Worth watching specifically for ResNet-101: with a
dataset in the low thousands of images, its much larger parameter count
(versus a smaller backbone) carries real overfitting risk — check the
training-progress plot's validation curve, not just the training curve,
before trusting the final numbers.

## 3. Toolbox usage (updated: GPU training + Computer Vision Toolbox now included)

This version uses **all 6** of your listed toolboxes, including GPU
acceleration via Parallel Computing Toolbox and real Computer Vision
Toolbox functions for the annotated evidence image.

**GPU training is now enabled.** `trainDRModel.m` calls `canUseGPU()`,
which checks for both a compatible NVIDIA GPU and a licensed Parallel
Computing Toolbox. If both are present, training runs on GPU
automatically; if not, it safely falls back to CPU with no changes
needed. Requirements for GPU training to actually kick in:
- An NVIDIA GPU with a supported CUDA compute capability
- Up-to-date NVIDIA driver installed
- Parallel Computing Toolbox licensed and installed

You can confirm what MATLAB sees before training by running
`canUseGPU()` and `gpuDevice()` directly in the Command Window.

**ResNet-18 is now the default and recommended backbone**, not just a
fallback. `trainDRModel.m` still exposes `backboneName = "resnet50"` or
`"resnet101"` as optional experiments if you want to compare accuracy
later, but ResNet-18 is the one this project is built around — it's
fast even on modest GPUs, and accurate enough for a dataset this size
(2,750 images).

Toolboxes actually exercised by this code:

| Toolbox | Used for |
|---|---|
| Image Processing Toolbox | Cropping, CLAHE, denoising, morphological lesion heuristic, quality checks, `regionprops` for lesion boxes/centroids |
| Deep Learning Toolbox | `imagePretrainedNetwork`, `trainnet`, `focalCrossEntropy`, `gradCAM`, `rocmetrics`, `confusionchart`, `canUseGPU` |
| Parallel Computing Toolbox | GPU-accelerated training for both classification (`trainDRModel.m`) and segmentation (`trainSegmentation_*.m`) via `gpuDevice`/`canUseGPU` and `ExecutionEnvironment="gpu"` |
| Computer Vision Toolbox | `insertShape`/`insertText` (annotated evidence image); `unet`, `deeplabv3plusLayers`, `semanticseg`, `pixelLabelDatastore` (Module 2 segmentation training/inference) |
| Statistics and Machine Learning Toolbox | `fitglm` for Platt-scaling confidence calibration |
| Medical Imaging Toolbox | Not strictly required by this specific code — its main relevance here is that the original MathWorks reference example lives in its documentation. It becomes directly useful if you later add DICOM ingestion or hospital-system integration. |
| Simulink | Not part of this package (see Module 5 note above) |

## 4. Setup instructions for MATLAB R2026a

1. **Extract the dataset.** Unzip `archive.zip` and rename/arrange it so
   your MATLAB current folder contains a `rawData` folder like this:
   ```
   yourProjectFolder/
     rawData/
       Healthy/
       Mild DR/
       Moderate DR/
       Severe DR/
       Proliferate DR/
     src/            <- copy all the .m files from this package here
   ```
2. **Install the required Add-On.** In MATLAB: `Home` tab → `Add-Ons` →
   `Get Add-Ons` → search **"Deep Learning Toolbox Model for ResNet-101
   Network"** → Install. (If you set `backboneName = "resnet50"` or
   `"resnet18"` instead, install the matching support package.)
3. **Confirm your toolboxes are licensed.** Run this in the Command
   Window:
   ```matlab
   ver
   ```
   Confirm Image Processing Toolbox, Deep Learning Toolbox, and
   Statistics and Machine Learning Toolbox appear in the list.
4. **Add the code to your path.**
   ```matlab
   addpath(genpath(fullfile(pwd, "src")))
   ```

## 5. Running the pipeline

Open `runFullPipelineDemo.m` and run it section-by-section (click a
section, press **Ctrl+Enter**), in this order:

| Step | Script | What it does | Approx. time |
|---|---|---|---|
| 1 | `prepareDataset.m` | Crop + CLAHE + denoise + resize all 2,750 images | ~2-5 min |
| 2 | `buildDatastores.m` | Stratified 70/15/15 split, oversamples minority classes for training | seconds |
| 3 | `trainDRModel.m` | Transfer-learning training of the grading CNN (ResNet-18, GPU-accelerated if available) | minutes on GPU, longer on CPU fallback — see §3 |
| 4 | `evaluateDRModel.m` | Per-class metrics, ROC/AUC, confusion matrix, referable-DR sensitivity/specificity vs SIH targets | ~1 min |
| 5 | `calibrateConfidence.m` | Platt-scaling calibration (Statistics and ML Toolbox) | seconds |
| 6 | `explainDRPrediction(imagePath)` | Full explainable prediction: quality check → grade → Grad-CAM → evidence text | ~1-2 sec/image |

Each script saves its output to disk (`preprocessedData/`,
`datastoreSplit.mat`, `models/drGradingNet.mat`,
`models/calibrationModel.mat`, `evaluationResults.mat`), so you can
re-run any later step without repeating earlier ones.

## 6. Interpreting your results

- `evaluateDRModel.m` prints **referable DR sensitivity/specificity**
  against SIH 26038's explicit targets (**>90% sensitivity, >85%
  specificity** for Grade ≥ 2). If you fall short on the first run,
  that's expected and normal — options to improve, roughly in order of
  effort:
  1. Increase `MaxEpochs` in `trainDRModel.m` (start at 15, try 25-30).
  2. Try `backboneName = "resnet50"` instead of 101 (sometimes
     generalizes better on smaller datasets — 2,750 images is modest for
     ResNet-101).
  3. Add more/stronger augmentation in `trainDRModel.m`.
  4. The Moderate DR (900) and Healthy (1000) classes dominate; watch the
     confusion matrix specifically for Mild DR (370) and Severe DR (190)
     misclassification, since those are the smallest classes and most
     clinically important to catch correctly.
- The confusion matrix and ROC plot are figures — use `savefig`/`exportgraphics`
  if you want to drop them straight into your SIH report/slides.

## 7. Next steps (beyond this package)

- **Deployment** (MATLAB Compiler SDK → Production Server / web app):
  `explainDRPrediction.m` is already written as the single orchestrator
  function you'd package — see our earlier conversation for the full
  deployment walkthrough.
- **Simulink Module 5** (resource-allocation simulation): independent of
  this dataset, can be built any time — just ask.
- **Real lesion segmentation**: if you can source IDRiD, e-ophtha-MA, or
  DDR-lesion (all have pixel-level masks), I can build the actual trained
  U-Net for Module 2 to replace the classical heuristic.
