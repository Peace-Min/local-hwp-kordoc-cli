@echo off
setlocal
set "APP_DIR=%~dp0app"

if exist "%~dp0bin\hwp-kordoc-cli.js" (
  set "APP_DIR=%~dp0"
)

node "%APP_DIR%\bin\hwp-kordoc-cli.js" %*
exit /b %ERRORLEVEL%

