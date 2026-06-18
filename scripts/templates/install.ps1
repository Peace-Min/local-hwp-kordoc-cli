param(
  [string]$InstallDir = "$env:LOCALAPPDATA\Programs\hwp-kordoc-cli",
  [switch]$InstallNode,
  [switch]$AddToUserPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$bundleRoot = $PSScriptRoot
$sourceApp = Join-Path $bundleRoot "app"
$sourceCmd = Join-Path $bundleRoot "hwp-kordoc.cmd"

function Get-NodeMajorVersion {
  $node = Get-Command node -ErrorAction SilentlyContinue
  if (!$node) {
    return $null
  }

  $versionText = (& node --version).TrimStart("v")
  return [int]($versionText.Split(".")[0])
}

function Install-NodeFromBundle {
  $msi = Get-ChildItem -LiteralPath (Join-Path $bundleRoot "tools") -Filter "node-v*.msi" -File -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if (!$msi) {
    throw "Node.js MSI was not found in bundle tools directory."
  }

  Write-Host "[install] Installing Node.js from $($msi.FullName)"
  $process = Start-Process -FilePath "msiexec.exe" -ArgumentList @("/i", "`"$($msi.FullName)`"", "/qn", "/norestart") -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    throw "Node.js MSI install failed with exit code $($process.ExitCode). Try running PowerShell as Administrator."
  }
}

function Add-DirectoryToUserPath {
  param([string]$Directory)

  $current = [Environment]::GetEnvironmentVariable("Path", "User")
  $parts = @()
  if ($current) {
    $parts = $current.Split(";") | Where-Object { $_ -ne "" }
  }

  if ($parts -contains $Directory) {
    return
  }

  $newPath = (($parts + $Directory) -join ";")
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
  Write-Host "[install] Added to user PATH: $Directory"
}

if (!(Test-Path -LiteralPath $sourceApp)) {
  throw "Bundle app directory was not found: $sourceApp"
}

$nodeMajor = Get-NodeMajorVersion
if ($null -eq $nodeMajor -and $InstallNode) {
  Install-NodeFromBundle
  $nodeMajor = Get-NodeMajorVersion
}

if ($null -eq $nodeMajor) {
  throw "Node.js was not found. Re-run with -InstallNode or install Node.js 18+ first."
}

if ($nodeMajor -lt 18) {
  throw "Node.js 18+ is required. Current major version: $nodeMajor"
}

Write-Host "[install] Installing app to $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

Copy-Item -Path (Join-Path $sourceApp "*") -Destination $InstallDir -Recurse -Force
Copy-Item -LiteralPath $sourceCmd -Destination (Join-Path $InstallDir "hwp-kordoc.cmd") -Force

if ($AddToUserPath) {
  Add-DirectoryToUserPath -Directory $InstallDir
}

Write-Host "[install] Verifying CLI..."
& (Join-Path $InstallDir "hwp-kordoc.cmd") --version
if ($LASTEXITCODE -ne 0) {
  throw "CLI verification failed."
}

Write-Host "[install] Done."
Write-Host "[install] Run: $InstallDir\hwp-kordoc.cmd --help"
