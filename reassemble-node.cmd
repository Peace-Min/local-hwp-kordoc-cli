@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "NODE_NAME=node-v22.14.0-x64.msi"
set "NODE_EXPECT=2c0cc97ec64c1e4111362e1e32e0547fd870e4d9c79ec844c117da583f21b386"
set "PART_DIR=parts"

echo ============================================
echo   Node.js installer reassemble
echo ============================================
echo.

if not exist "%PART_DIR%\%NODE_NAME%.001" (
  echo [ERROR] Missing %PART_DIR%\%NODE_NAME%.001
  echo Run git clone or git pull again, then retry.
  pause
  exit /b 1
)

set "COPY_LIST="
for /f "delims=" %%F in ('dir /b /on "%PART_DIR%\%NODE_NAME%.*"') do (
  if defined COPY_LIST (
    set "COPY_LIST=!COPY_LIST!+"%PART_DIR%\%%F""
  ) else (
    set "COPY_LIST="%PART_DIR%\%%F""
  )
)

echo Reassembling %NODE_NAME% ...
copy /b !COPY_LIST! "%NODE_NAME%" >nul
if errorlevel 1 (
  echo [ERROR] Reassemble failed.
  pause
  exit /b 1
)

echo Done: %~dp0%NODE_NAME%
echo.
echo Checking SHA256...
set "GOT="
for /f "skip=1 delims=" %%H in ('certutil -hashfile "%NODE_NAME%" SHA256') do (
  if not defined GOT set "GOT=%%H"
)
set "GOT=%GOT: =%"

echo   Got:      %GOT%
echo   Expected: %NODE_EXPECT%

if /I "%GOT%"=="%NODE_EXPECT%" (
  echo [OK] Integrity check passed.
) else (
  echo [ERROR] SHA256 mismatch. Delete %NODE_NAME%, run git pull, and retry.
  pause
  exit /b 1
)

echo.
pause
