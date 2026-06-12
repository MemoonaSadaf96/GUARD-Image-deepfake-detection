@echo off
setlocal
cd /d "%~dp0"

echo ==============================================
echo  Image Deepfake Detection - setup (Windows)
echo ==============================================
echo.

where node >nul 2>&1 || (echo ERROR: Install Node.js 18+ from https://nodejs.org & exit /b 1)
where npm >nul 2>&1 || (echo ERROR: npm not found & exit /b 1)
where python >nul 2>&1 || (echo ERROR: Install Python 3.10+ from https://python.org & exit /b 1)

echo ^>^> Node packages...
call npm run install:all
if errorlevel 1 exit /b 1

if not exist .venv (
  echo ^>^> Creating Python virtualenv .venv ...
  python -m venv .venv
)
echo ^>^> Python packages (may take several minutes)...
call .venv\Scripts\python.exe -m pip install --upgrade pip
call .venv\Scripts\python.exe -m pip install -r api\requirements.txt
if errorlevel 1 exit /b 1

if not exist .env (
  if exist .env.example copy .env.example .env
  echo ^>^> Created .env - add OPENAI_API_KEY
)

if not exist frontend\.env.local (
  if exist frontend\.env.local.example copy frontend\.env.local.example frontend\.env.local
  echo ^>^> Created frontend\.env.local (API http://127.0.0.1:8000)
)

echo.
echo Setup finished. Edit .env then run:  npm start
echo Open UI:  http://127.0.0.1:3000
echo.
pause
