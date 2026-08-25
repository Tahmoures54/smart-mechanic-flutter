@echo off
setlocal
cd /d "%~dp0"

echo ================================================
echo Smart Mechanic - Release Build 1.2.0+3
echo ================================================

where flutter >nul 2>&1
if errorlevel 1 (
  echo ERROR: Flutter was not found in PATH.
  echo Install Flutter and restart this terminal.
  exit /b 1
)

flutter doctor -v
if errorlevel 1 exit /b 1

flutter clean
if errorlevel 1 exit /b 1

flutter pub get
if errorlevel 1 exit /b 1

if exist "%~dp0assets\branding\app_icon.png" (
  dart run flutter_launcher_icons
  if errorlevel 1 exit /b 1
)

flutter analyze
if errorlevel 1 (
  echo ERROR: Dart analyzer found problems.
  exit /b 1
)

flutter build apk --release --split-debug-info=build\symbols
if errorlevel 1 (
  echo ERROR: APK build failed.
  exit /b 1
)

echo.
echo SUCCESS
 echo APK: build\app\outputs\flutter-apk\app-release.apk
exit /b 0
