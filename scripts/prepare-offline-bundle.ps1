param(
  [string]$NodeVersion = "22.14.0",
  [ValidateSet("x64", "x86", "arm64")]
  [string]$Architecture = "x64",
  [string]$OutputRoot = "dist\offline",
  [switch]$SkipNodeDownload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputRootPath = Join-Path $repoRoot $OutputRoot
$bundleName = "hwp-kordoc-cli-offline"
$bundleRoot = Join-Path $outputRootPath $bundleName
$appRoot = Join-Path $bundleRoot "app"
$toolsRoot = Join-Path $bundleRoot "tools"
$zipPath = Join-Path $outputRootPath "$bundleName.zip"

function Copy-RequiredItem {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Destination
  )

  if (!(Test-Path -LiteralPath $Source)) {
    throw "Required item not found: $Source"
  }

  Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

Push-Location $repoRoot
try {
  if (!(Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
    throw "npm.cmd was not found. Install Node.js on the online packaging PC first."
  }

  if (Test-Path -LiteralPath $outputRootPath) {
    Remove-Item -LiteralPath $outputRootPath -Recurse -Force
  }

  New-Item -ItemType Directory -Force -Path $appRoot | Out-Null
  New-Item -ItemType Directory -Force -Path $toolsRoot | Out-Null

  Write-Host "[offline] Installing locked runtime dependencies..."
  & npm.cmd ci --omit=dev
  if ($LASTEXITCODE -ne 0) {
    throw "npm ci failed with exit code $LASTEXITCODE"
  }

  Write-Host "[offline] Copying app files..."
  Copy-RequiredItem -Source (Join-Path $repoRoot "bin") -Destination $appRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "vendor") -Destination $appRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "node_modules") -Destination $appRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "package.json") -Destination $appRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "package-lock.json") -Destination $appRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "README.md") -Destination $appRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "README_OFFLINE.md") -Destination $appRoot

  Copy-RequiredItem -Source (Join-Path $repoRoot "scripts\templates\install.ps1") -Destination $bundleRoot
  Copy-RequiredItem -Source (Join-Path $repoRoot "scripts\templates\hwp-kordoc.cmd") -Destination $bundleRoot

  if (!$SkipNodeDownload) {
    $msiName = "node-v$NodeVersion-$Architecture.msi"
    $msiPath = Join-Path $toolsRoot $msiName
    $nodeUrl = "https://nodejs.org/dist/v$NodeVersion/$msiName"

    Write-Host "[offline] Downloading Node.js MSI: $nodeUrl"
    Invoke-WebRequest -Uri $nodeUrl -OutFile $msiPath -UseBasicParsing
  } else {
    Write-Host "[offline] Skipping Node.js MSI download."
  }

  Write-Host "[offline] Writing SHA256 manifest..."
  $manifestPath = Join-Path $bundleRoot "SHA256SUMS.txt"
  Get-ChildItem -LiteralPath $bundleRoot -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
      $relative = Resolve-Path -LiteralPath $_.FullName -Relative
      $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName
      "$($hash.Hash)  $relative"
    } |
    Set-Content -LiteralPath $manifestPath -Encoding UTF8

  Write-Host "[offline] Creating ZIP: $zipPath"
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }
  Compress-Archive -LiteralPath $bundleRoot -DestinationPath $zipPath -Force

  Write-Host "[offline] Done."
  Write-Host "[offline] Bundle directory: $bundleRoot"
  Write-Host "[offline] Bundle ZIP:       $zipPath"
} finally {
  Pop-Location
}

