@echo off
setlocal
set "ROOT_DIR=%~dp0"
set "APP_DIR=%ROOT_DIR%app"

if exist "%ROOT_DIR%bin\hwp-kordoc-cli.js" (
  set "APP_DIR=%ROOT_DIR%"
)

if not exist "%APP_DIR%bin\hwp-kordoc-cli.js" (
  echo [hwp-kordoc] CLI entrypoint was not found: %APP_DIR%bin\hwp-kordoc-cli.js
  exit /b 1
)

set "NEED_SETUP=0"
where node >nul 2>nul
if errorlevel 1 set "NEED_SETUP=1"

if not exist "%APP_DIR%node_modules\jszip\package.json" set "NEED_SETUP=1"
if not exist "%APP_DIR%node_modules\@xmldom\xmldom\package.json" set "NEED_SETUP=1"
if not exist "%APP_DIR%node_modules\cfb\package.json" set "NEED_SETUP=1"
if not exist "%APP_DIR%node_modules\markdown-it\package.json" set "NEED_SETUP=1"

if "%NEED_SETUP%"=="1" (
  if exist "%APP_DIR%scripts\setup-local.ps1" (
    echo [hwp-kordoc] First-run setup is required.
    powershell -NoProfile -ExecutionPolicy Bypass -File "%APP_DIR%scripts\setup-local.ps1"
    if errorlevel 1 exit /b %ERRORLEVEL%
  ) else (
    echo [hwp-kordoc] Runtime dependencies are missing and no setup script was found.
    echo [hwp-kordoc] Run setup.cmd, or use the offline release bundle.
    exit /b 1
  )
)

node "%APP_DIR%\bin\hwp-kordoc-cli.js" %*
exit /b %ERRORLEVEL%
