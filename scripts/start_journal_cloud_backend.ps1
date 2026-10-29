# Journal Cloud development-only FastAPI launcher (Windows PowerShell).
# Requires backend/.env with the PRIVATE Postgres connection string and
# SUPABASE_URL. Do not print, commit, or paste .env contents.
param(
  [ValidateRange(1, 65535)]
  [int]$Port = 8000,
  [ValidateNotNullOrEmpty()]
  [string]$OllamaModel = 'qwen3.5:4b'
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
$PreviousAiProvider = $env:AI_PROVIDER
$PreviousOllamaModel = $env:OLLAMA_MODEL
try {
  # Inference runs on backend loopback, locally or through a private SSH tunnel.
  # Override the development .env mock only for this process, never rewrite it.
  $env:AI_PROVIDER = 'ollama'
  $env:OLLAMA_MODEL = $OllamaModel
  & $Python -m scripts.runtime_preflight
  if ($LASTEXITCODE -ne 0) {
    throw 'Runtime preflight failed. Correct local configuration before starting.'
  }
  Write-Host "FastAPI: http://127.0.0.1:$Port"
  Write-Host "Android Emulator API_BASE_URL: http://10.0.2.2:$Port/api/v1"
  # Loopback host is deliberate: do not expose personal Journal APIs on LAN.
  & $Python -m uvicorn app.main:app --reload --host 127.0.0.1 --port $Port
  if ($LASTEXITCODE -ne 0) { throw "FastAPI exited with a nonzero code." }
}
finally {
  $env:AI_PROVIDER = $PreviousAiProvider
  $env:OLLAMA_MODEL = $PreviousOllamaModel
  Pop-Location
}
