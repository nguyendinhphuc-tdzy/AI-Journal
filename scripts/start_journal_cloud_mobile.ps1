# Android emulator development-only Journal Cloud launcher.
# No Postgres credentials, JWT secrets, or service_role keys belong in Flutter.
param(
  [string]$DeviceId = ""
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Mobile = Join-Path $Root "mobile"
$LocalConfig = Join-Path $Mobile ".env.journal-cloud.json"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter is not available in PATH."
}
if (-not (Test-Path $LocalConfig)) {
  throw "Missing mobile/.env.journal-cloud.json. Copy mobile/journal_cloud.example.json, then add the Supabase publishable key locally."
}

# Fail safely before app starts if the opt-in config is missing or contains
# example placeholders. Do not echo public keys or other JSON values.
$Cfg = Get-Content -LiteralPath $LocalConfig -Raw | ConvertFrom-Json
if ("$($Cfg.AUTH_ENABLED)" -ne "true" -or
    "$($Cfg.JOURNAL_CLOUD_ENABLED)" -ne "true" -or
    "$($Cfg.SUPABASE_URL)" -ne "https://rjwentsuqmwncpseakkt.supabase.co" -or
    -not "$($Cfg.SUPABASE_PUBLISHABLE_KEY)".Trim() -or
    "$($Cfg.SUPABASE_PUBLISHABLE_KEY)".Contains("REPLACE") -or
    "$($Cfg.API_BASE_URL)" -ne "http://10.0.2.2:8000/api/v1") {
  throw "Invalid local Flutter Journal Cloud config. Review mobile/.env.journal-cloud.json privately."
}

Push-Location $Mobile
try {
  $FlutterArgs = @("run", "--dart-define-from-file=.env.journal-cloud.json")
  if ($DeviceId.Trim()) { $FlutterArgs += @("-d", $DeviceId.Trim()) }
  & flutter @FlutterArgs
  if ($LASTEXITCODE -ne 0) { throw "Flutter run exited with a nonzero code." }
}
finally {
  Pop-Location
}
