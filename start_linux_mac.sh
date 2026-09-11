#!/usr/bin/env bash
set -e
export MATLAB_BIN="${MATLAB_BIN:-matlab}"
python3 backend/app.py &
BACKEND_PID=$!
trap 'kill $BACKEND_PID 2>/dev/null || true' EXIT
cd frontend
npm install
npm run dev
