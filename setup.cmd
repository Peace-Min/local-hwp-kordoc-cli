@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup-local.ps1"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [setup] Failed with exit code %EXIT_CODE%.
  echo [setup] Press any key to close.
  pause >nul
  exit /b %EXIT_CODE%
)

echo.
echo [setup] Complete.
echo [setup] Run hwp-kordoc.cmd to use the CLI.
echo [setup] Press any key to close.
pause >nul
exit /b 0

