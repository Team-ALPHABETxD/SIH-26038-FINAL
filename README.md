# eyeQ AI — Retinal Decision Support

A full-stack diabetic retinopathy screening interface built around the supplied MATLAB inference pipeline.

## Stack
- Frontend: Next.js + TypeScript + Recharts + Lucide
- Backend: Flask + MATLAB Engine for Python
- Inference: supplied MATLAB grading, image-quality, Grad-CAM and lesion-evidence pipeline
- Persistence: local JSON records + uploaded images

## Run the backend
From the project root:

```powershell
.venv\Scripts\activate
$env:PYTHONPATH="C:\Program Files\MATLAB\R2026a\extern\engines\python\dist"
python backend\app.py
```

Backend: `http://127.0.0.1:5000`

## Run the frontend
Open a second PowerShell terminal. Do not run npm from the project root.

```powershell
cd frontend
npm install
npm run dev
```

Frontend: `http://localhost:3000`

## Main screens
- `/` — product-style landing page
- `/dashboard` — screening overview and recent records
- `/screening` — patient metadata + fundus upload
- `/history` — searchable screening archive
- `/report/<id>` — detailed report
- `/how-it-works` — pipeline explanation
- `/about` — project and design principles

## Report contents
The report is intentionally organized around the requested clinical/model outputs:

- Image Quality score
- Predicted ICDR grade
- Calibrated confidence
- Referable DR
- Class probability distribution
- Preprocessed fundus image
- Grad-CAM
- Lesion evidence
- Evidence report
- XAI explanation
- Patient/screening details
- Printable PDF

The MATLAB API now also returns the preprocessed image as `preprocessedImageBase64`, so the frontend can display the actual preprocessing output rather than a placeholder.

## UI direction
The redesign uses an editorial clinical aesthetic: warm white/beige surfaces, forest green and muted sage accents, restrained gold highlights, rounded cards, generous whitespace, responsive layouts, subtle entrance/hover animations, and an inline vector doctor/patient clinical illustration.

The illustration is an original SVG component (`frontend/components/ClinicalIllustration.tsx`), so the package does not depend on external stock-image URLs.

## Important
The application is an AI-assisted screening/decision-support project. It is not a standalone clinical diagnosis system. Referable or uncertain cases should be reviewed by a qualified clinician.
