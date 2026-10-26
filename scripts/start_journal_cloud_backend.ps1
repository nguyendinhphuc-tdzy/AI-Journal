# Journal Cloud development-only FastAPI launcher (Windows PowerShell).
# Requires backend/.env with the PRIVATE Postgres connection string and
# SUPABASE_URL. Do not print, commit, or paste .env contents.
param(
  [ValidateRange(1, 65535)]
  [int]$Port = 8000
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Backend = Join-Path $Root "backend"
$Python = Join-Path $Backend ".venv\Scripts\python.exe"
$EnvFile = Join-Path $Backend ".env"

if (-not (Test-Path $Python)) {
  throw "Missing backend virtualenv. Run: py -3.11 -m venv .venv; .\.venv\Scripts\python.exe -m pip install -r requirements.txt"
}
if (-not (Test-Path $EnvFile)) {
  throw "Missing backend/.env. Configure DATABASE_URL and SUPABASE_URL privately."
}
Push-Location $Backend
try {
  # Read-only revision gate: a mismatched schema must not serve journals.
  $Revision = (& $Python -m alembic current 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0 -or $Revision -notmatch "(?m)^20261026_08(\s|\()") {
    throw "Journal Cloud requires Alembic 20261026_08. Check your backend DATABASE_URL and migration branch; do NOT rerun migrations."
  }
  Write-Host "Journal Cloud schema confirmed at 20261026_08."
  Write-Host "FastAPI: http://127.0.0.1:$Port"
  Write-Host "Android Emulator API_BASE_URL: http://10.0.2.2:$Port/api/v1"
  # Loopback host is deliberate: do not expose personal Journal APIs on LAN.
  & $Python -m uvicorn app.main:app --reload --host 127.0.0.1 --port $Port
  if ($LASTEXITCODE -ne 0) { throw "FastAPI exited with a nonzero code." }
}
finally {
  Pop-Location
}
