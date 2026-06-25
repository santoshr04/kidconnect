@echo off
echo ===================================
echo    KidConnect - Deploy AI Function  
echo ===================================
echo.
echo Adding Node.js to PATH...
set NODE_PATH=C:\Program Files\nodejs
set PATH=%NODE_PATH%;%APPDATA%\npm;%PATH%

echo Checking Node.js...
"%NODE_PATH%\node.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Node.js not found at %NODE_PATH%
    echo Please install Node.js from https://nodejs.org
    pause
    exit /b 1
)

echo Checking Firebase CLI...
call firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Firebase CLI not found, installing...
    call npm install -g firebase-tools
)

echo.
echo Step 1: Login to Firebase (browser will open)
echo =============================================
call firebase login
if %errorlevel% neq 0 (
    echo Login failed. Try running: firebase login
    pause
    exit /b 1
)

echo.
echo Step 2: Deploying face detection function
echo =========================================
echo This uploads the Google Cloud Vision AI code to Firebase.
echo After deployment, every photo upload will trigger face detection.
echo.
call firebase deploy --only functions
if %errorlevel% neq 0 (
    echo.
    echo DEPLOY FAILED. Possible reasons:
    echo - Firebase Blaze plan not enabled (Functions require Blaze)
    echo   Go to: Firebase Console ^> Project Settings ^> Usage and Billing
    echo - Cloud Vision API not enabled
    echo   Go to: https://console.cloud.google.com/apis/library/vision.googleapis.com
    pause
    exit /b 1
)

echo.
echo ===================================
echo DEPLOY SUCCESSFUL!
echo ===================================
echo.
echo Every photo you upload will now trigger AI face detection.
echo Open any photo in the app to see colored circles on faces.
echo.
pause