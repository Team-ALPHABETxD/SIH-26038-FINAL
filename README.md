# DR-xAI Web — MATLAB + Flask + Frontend

A presentation-ready web interface around the supplied MATLAB diabetic-retinopathy pipeline.

## What is included

- `matlab/models/drGradingNet.mat` — supplied trained network
- `matlab/models/calibrationModel.mat` — supplied confidence calibration model
- Original MATLAB pipeline functions, cleaned to standard filenames
- `matlab/api_analyze.m` — web bridge for single-image inference
- `matlab/api_evaluation.m` — exports the supplied evaluation MAT for the dashboard
- Flask backend with upload, inference, result artifacts and evaluation endpoints
- Responsive vanilla HTML/CSS/JS frontend
- Quality gate, 5-class ICDR grading, calibrated confidence, class scores, Grad-CAM overlay, heuristic lesion overlay, evidence report and evaluation dashboard
- Footer: **Developed by Team Alphabet.**

## Important deployment note

The actual trained network is a MATLAB `.mat` model. Therefore this version intentionally keeps MATLAB as the inference engine rather than attempting to recreate the model in Python and risk changing its behavior.

For local use, you need:
1. MATLAB with the toolboxes required by the supplied files.
2. The network/model support used when the model was trained.
3. Python 3.10+ and the packages in `backend/requirements.txt`.

The supplied MATLAB code documents the required stack: Deep Learning Toolbox, Image Processing Toolbox, and Statistics and Machine Learning Toolbox for calibration.

## Windows quick start

1. Open a terminal in this folder.
2. Create a Python environment:
   `py -m venv .venv`
3. Activate:
   `.venv\Scripts\activate`
4. Install:
   `pip install -r backend\requirements.txt`
5. If `matlab` is not on PATH, set it:
   `set MATLAB_BIN=C:\Program Files\MATLAB\R2025b\bin\matlab.exe`
6. Start:
   `python backend\app.py`
7. Open:
   `http://localhost:5000`

## Linux/macOS quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
export MATLAB_BIN=/usr/local/MATLAB/R2025b/bin/matlab
python backend/app.py
```

Then open `http://localhost:5000`.

## How inference works

Browser → Flask `/api/analyze` → MATLAB `api_analyze.m` → `explainDRPrediction.m`

The supplied MATLAB entry point performs:

1. Rule-based image quality gate.
2. Fundus preprocessing: retinal crop, CLAHE on L channel, Gaussian denoising, 224×224 resize.
3. Trained CNN prediction.
4. Platt-scaled calibrated confidence.
5. Grad-CAM.
6. Classical bright/dark lesion candidate cues.

The lesion candidate module is explicitly heuristic and is not a trained segmentation model; the UI labels it accordingly.

## API

- `GET /api/health`
- `POST /api/analyze` with multipart field `image`
- `GET /api/evaluation`
- `GET /api/results/<job>/<filename>`

## Safety / demonstration scope

This interface is designed for demonstration and research presentation. It must not be represented as an autonomous clinical diagnosis system. The supplied MATLAB quality thresholds are documented as starting points and the lesion cues are explicitly non-clinically-validated heuristics.

## Next.js frontend

The frontend has been rebuilt in `frontend/` using Next.js App Router + React. It includes responsive screening UI, upload flow, MATLAB bridge status, quality gate, ICDR results, class probabilities, Grad-CAM/lesion artifacts, evidence report and evaluation dashboard.

Run Flask first on port 5000, then:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:3000`. The Next.js rewrite proxies `/api/*` to Flask. For a different backend, set `BACKEND_URL` in `.env.local`.
