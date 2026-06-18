@echo off
setlocal
cd /d "%~dp0"
node "%~dp0bin\hwp-kordoc-cli.js" %*
exit /b %ERRORLEVEL%
