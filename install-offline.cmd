@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "NODE_NAME=node-v22.14.0-x64.msi"
set "NODE_EXPECT=2c0cc97ec64c1e4111362e1e32e0547fd870e4d9c79ec844c117da583f21b386"
set "PART_DIR=parts"
set "NODE_EXE="
set "NODE_MAJOR="

echo ============================================
echo   hwp-kordoc CLI offline install
echo ============================================
echo.

if not exist "%NODE_NAME%" (
  echo Node.js installer not found. Building it from parts...
  call :ReassembleNode || goto :Fail
) else (
  call :VerifyNodeInstaller || goto :Fail
)

call :FindNode
if defined NODE_EXE (
  call :ReadNodeMajor
)

if not defined NODE_EXE (
  call :InstallNode || goto :Fail
) else if %NODE_MAJOR% LSS 18 (
  echo [install] Existing Node.js is too old: major %NODE_MAJOR%
  call :InstallNode || goto :Fail
) else (
  echo [install] Node.js is ready: %NODE_EXE%
)

call :FindNode
if not defined NODE_EXE (
  echo [ERROR] Node.js was installed, but node.exe was not found.
  echo Open a new Command Prompt and run install-offline.cmd again.
  goto :Fail
)

call :ReadNodeMajor
if %NODE_MAJOR% LSS 18 (
  echo [ERROR] Node.js 18+ is required. Current major version: %NODE_MAJOR%
  goto :Fail
)

if not exist "node_modules\jszip\package.json" (
  echo [ERROR] node_modules is missing. This repository must include runtime dependencies for offline use.
  echo Run git pull again, or rebuild the offline repository on an internet-connected PC.
  goto :Fail
)

echo.
echo [install] Verifying CLI...
"%NODE_EXE%" "%~dp0bin\hwp-kordoc-cli.js" --help >nul
if errorlevel 1 (
  echo [ERROR] CLI verification failed.
  goto :Fail
)

echo.
"%NODE_EXE%" --version
echo [OK] hwp-kordoc CLI is ready.
echo Run: %~dp0hwp-kordoc.cmd --help
echo.
pause
exit /b 0

:ReassembleNode
if not exist "%PART_DIR%\%NODE_NAME%.001" (
  echo [ERROR] Missing %PART_DIR%\%NODE_NAME%.001
  echo Run git clone or git pull again, then retry.
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

copy /b !COPY_LIST! "%NODE_NAME%" >nul
if errorlevel 1 (
  echo [ERROR] Reassemble failed.
  exit /b 1
)

call :VerifyNodeInstaller
exit /b %ERRORLEVEL%

:VerifyNodeInstaller
set "GOT="
for /f "skip=1 delims=" %%H in ('certutil -hashfile "%NODE_NAME%" SHA256') do (
  if not defined GOT set "GOT=%%H"
)
set "GOT=%GOT: =%"

if /I not "%GOT%"=="%NODE_EXPECT%" (
  echo [ERROR] Node.js installer SHA256 mismatch.
  echo   Got:      %GOT%
  echo   Expected: %NODE_EXPECT%
  exit /b 1
)

echo [install] Node.js installer integrity OK.
exit /b 0

:FindNode
set "NODE_EXE="
for /f "delims=" %%P in ('where node 2^>nul') do (
  if not defined NODE_EXE set "NODE_EXE=%%P"
)
if not defined NODE_EXE if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
if not defined NODE_EXE if exist "%LocalAppData%\Programs\nodejs\node.exe" set "NODE_EXE=%LocalAppData%\Programs\nodejs\node.exe"
exit /b 0

:ReadNodeMajor
set "NODE_MAJOR="
for /f "tokens=1 delims=." %%V in ('""%NODE_EXE%" --version"') do (
  if not defined NODE_MAJOR set "NODE_MAJOR=%%V"
)
set "NODE_MAJOR=!NODE_MAJOR:v=!"
if not defined NODE_MAJOR set "NODE_MAJOR=0"
exit /b 0

:InstallNode
echo [install] Installing Node.js from %NODE_NAME% ...
msiexec.exe /i "%~dp0%NODE_NAME%" /qn /norestart
if errorlevel 1 (
  echo [ERROR] Node.js installer returned an error. Try running this cmd as Administrator.
  exit /b 1
)
exit /b 0

:Fail
echo.
echo [install] Failed.
pause
exit /b 1
