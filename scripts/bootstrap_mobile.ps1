$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$MobileDir = Join-Path $RepoRoot "mobile"
$TempDir = Join-Path $RepoRoot ".flutter_bootstrap_tmp"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter was not found in PATH. Install Flutter first, then rerun this script."
}

if (Test-Path (Join-Path $MobileDir "android")) {
  Write-Host "mobile/android already exists. Nothing to generate."
  exit 0
}

if (Test-Path $TempDir) { Remove-Item $TempDir -Recurse -Force }
flutter create --platforms=android --org com.aidiary --project-name ai_diary $TempDir
Copy-Item (Join-Path $TempDir "android") (Join-Path $MobileDir "android") -Recurse
Remove-Item $TempDir -Recurse -Force

Write-Host "Android platform generated. Next: cd mobile; flutter pub get; flutter run"
