$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\backend")
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
