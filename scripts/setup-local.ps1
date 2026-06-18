Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$launcherPath = Join-Path $repoRoot "hwp-kordoc.cmd"

function Get-NodeMajorVersion {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (!$node) {
    return $null
  }

  $versionText = (& node --version).TrimStart("v")
  return [int]($versionText.Split(".")[0])
}

function Install-NodeFromLocalMsi {
  $candidateDirs = @(
    (Join-Path $repoRoot "tools"),
    (Join-Path $repoRoot "dist\offline\hwp-kordoc-cli-offline\tools")
  )

  foreach ($dir in $candidateDirs) {
    if (!(Test-Path -LiteralPath $dir)) {
      continue
    }

    $msi = Get-ChildItem -LiteralPath $dir -Filter "node-v*.msi" -File -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending |
      Select-Object -First 1

    if ($msi) {
      Write-Host "[setup] Installing Node.js from $($msi.FullName)"
      $process = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "`"$($msi.FullName)`"", "/qn", "/norestart") -Wait -PassThru
      if ($process.ExitCode -ne 0) {
        throw "Node.js MSI install failed with exit code $($process.ExitCode). Try running setup.cmd as Administrator."
      }
      return
    }
  }

  throw @"
Node.js 18+ was not found, and no local Node.js MSI was found.

Install Node.js 18+ first, or place a Node.js Windows MSI here:
  $repoRoot\tools\node-vXX.XX.X-x64.msi

For closed-network use, download the release offline bundle instead:
  https://github.com/Peace-Min/local-hwp-kordoc-cli/releases
"@
}

function Write-Launcher {
  $content = @"
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

node "%APP_DIR%bin\hwp-kordoc-cli.js" %*
exit /b %ERRORLEVEL%
"@

  Set-Content -LiteralPath $launcherPath -Value $content -Encoding ASCII
}

Push-Location $repoRoot
try {
  Write-Host "[setup] Repository: $repoRoot"

  $nodeMajor = Get-NodeMajorVersion
  if ($null -eq $nodeMajor) {
    Install-NodeFromLocalMsi
    $nodeMajor = Get-NodeMajorVersion
  }

  if ($null -eq $nodeMajor) {
    throw "Node.js install did not make node.exe available on PATH. Open a new terminal and run setup.cmd again."
  }

  if ($nodeMajor -lt 18) {
    throw "Node.js 18+ is required. Current major version: $nodeMajor"
  }

  if (!(Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw "npm.cmd was not found. Reinstall Node.js with npm enabled."
  }

  Write-Host "[setup] Installing npm dependencies from package-lock.json..."
  & npm.cmd ci --omit=dev
  if ($LASTEXITCODE -ne 0) {
    throw "npm ci failed with exit code $LASTEXITCODE"
  }

  Write-Host "[setup] Creating root launcher: $launcherPath"
  Write-Launcher

  Write-Host "[setup] Verifying CLI..."
  & $launcherPath --version
  if ($LASTEXITCODE -ne 0) {
    throw "CLI version check failed."
  }

  & npm.cmd run check
  if ($LASTEXITCODE -ne 0) {
    throw "npm check failed with exit code $LASTEXITCODE"
  }

  Write-Host "[setup] Ready."
} finally {
  Pop-Location
}
