@echo off
set PATH=C:\Program Files\nodejs;%APPDATA%\npm;%PATH%
echo Adding Node.js to PATH...
echo.
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Firebase CLI not found. Run: npm install -g firebase-tools
    pause
    exit /b 1
)
echo Firebase CLI found. Logging in...
echo.
firebase login --no-localhost
if %errorlevel% neq 0 (
    echo Login failed. Please try again.
    pause
    exit /b 1
)
echo.
echo Deploying cloud function...
firebase deploy --only functions
echo.
echo Done! Press any key to close.
pause