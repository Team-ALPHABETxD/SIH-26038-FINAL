
import json
import os
import shutil
import subprocess
import uuid
from pathlib import Path

from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename

BASE = Path(__file__).resolve().parent.parent
FRONTEND = BASE / "frontend"
MATLAB_DIR = BASE / "matlab"
MODEL_DIR = MATLAB_DIR / "models"
UPLOADS = BASE / "uploads"
RESULTS = BASE / "results"
for p in (UPLOADS, RESULTS):
    p.mkdir(exist_ok=True)

ALLOWED = {".jpg", ".jpeg", ".png", ".tif", ".tiff", ".bmp"}
MAX_MB = 15

app = Flask(__name__, static_folder=str(FRONTEND), static_url_path="")
CORS(app)

def matlab_executable():
    # Set MATLAB_BIN if MATLAB is not on PATH.
    return os.environ.get("MATLAB_BIN", "matlab")

def run_matlab(expression, timeout=300):
    cmd = [matlab_executable(), "-batch", expression]
    return subprocess.run(
        cmd, cwd=str(MATLAB_DIR), capture_output=True, text=True, timeout=timeout
    )

@app.get("/api/health")
def health():
    model_ok = (MODEL_DIR / "drGradingNet.mat").exists()
    calib_ok = (MODEL_DIR / "calibrationModel.mat").exists()
    return jsonify({
        "ok": True,
        "matlabIntegration": model_ok and calib_ok,
        "model": "ResNet-based DR grading pipeline",
        "modules": ["Image Quality Gate", "DR Severity Grading", "Grad-CAM", "Calibrated Confidence", "Heuristic Lesion Cues"]
    })

@app.get("/api/evaluation")
def evaluation():
    out = RESULTS / "evaluation.json"
    # Use existing JSON cache if present; otherwise ask MATLAB to export the supplied MAT.
    expr = "api_evaluation(" + matlab_quote(str(out)) + ")"
    try:
        p = run_matlab(expr, timeout=120)
        if p.returncode != 0 and not out.exists():
            return jsonify({"ok": False, "error": p.stderr[-2000:]}), 500
    except FileNotFoundError:
        return jsonify({"ok": False, "error": "MATLAB executable not found. Set MATLAB_BIN or add MATLAB to PATH."}), 503
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "error": "MATLAB evaluation export timed out."}), 504
    if out.exists():
        return jsonify(json.loads(out.read_text(encoding="utf-8")))
    return jsonify({"ok": False, "error": "Evaluation output was not generated."}), 500

def matlab_quote(s):
    # MATLAB string literal with doubled single quotes.
    return "'" + s.replace("\\", "/").replace("'", "''") + "'"

@app.post("/api/analyze")
def analyze():
    if "image" not in request.files:
        return jsonify({"ok": False, "error": "No image uploaded."}), 400
    f = request.files["image"]
    if not f.filename:
        return jsonify({"ok": False, "error": "Choose a fundus image first."}), 400
    ext = Path(secure_filename(f.filename)).suffix.lower()
    if ext not in ALLOWED:
        return jsonify({"ok": False, "error": "Unsupported image format. Use JPG, PNG, TIFF, or BMP."}), 400
    f.stream.seek(0, os.SEEK_END)
    size = f.stream.tell()
    f.stream.seek(0)
    if size > MAX_MB * 1024 * 1024:
        return jsonify({"ok": False, "error": f"Image is larger than {MAX_MB} MB."}), 413

    job = uuid.uuid4().hex
    input_path = UPLOADS / f"{job}{ext}"
    out_dir = RESULTS / job
    out_dir.mkdir()
    f.save(input_path)

    expr = "api_analyze(" + matlab_quote(str(input_path)) + "," + matlab_quote(str(out_dir)) + ")"
    try:
        p = run_matlab(expr, timeout=300)
    except FileNotFoundError:
        return jsonify({"ok": False, "error": "MATLAB executable not found. Install MATLAB and add it to PATH, or set MATLAB_BIN."}), 503
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "error": "Analysis timed out. Check MATLAB/model installation."}), 504

    result_file = out_dir / "result.json"
    if not result_file.exists():
        return jsonify({"ok": False, "error": (p.stderr or p.stdout)[-3000:]}), 500

    result = json.loads(result_file.read_text(encoding="utf-8"))
    if not result.get("ok"):
        result["matlabLog"] = (p.stderr or p.stdout)[-2000:]
        return jsonify(result), 422

    result["jobId"] = job
    result["artifacts"] = {
        k: f"/api/results/{job}/{v}" for k, v in result.get("artifacts", {}).items()
    }
    return jsonify(result)

@app.get("/api/results/<job>/<filename>")
def result_file(job, filename):
    safe = secure_filename(filename)
    return send_from_directory(RESULTS / job, safe)

@app.get("/")
def index():
    return send_from_directory(FRONTEND, "index.html")

@app.get("/<path:path>")
def frontend_assets(path):
    target = FRONTEND / path
    if target.exists() and target.is_file():
        return send_from_directory(FRONTEND, path)
    return send_from_directory(FRONTEND, "index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")), debug=False)
