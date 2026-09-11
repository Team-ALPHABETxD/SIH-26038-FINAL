@echo off
setlocal
if "%MATLAB_BIN%"=="" set MATLAB_BIN=matlab

echo Starting DR-xAI Flask backend...
start "DR-xAI Flask" cmd /k "python backend\app.py"

echo.
echo Starting DR-xAI Next.js frontend...
start "DR-xAI Next.js" cmd /k "cd frontend && npm install && npm run dev"

echo.
echo Backend:  http://127.0.0.1:5000
 echo Frontend: http://localhost:3000
pause
