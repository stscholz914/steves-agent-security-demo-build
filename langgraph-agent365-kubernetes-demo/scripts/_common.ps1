# Shared helpers. Dot-source from other scripts:  . "$PSScriptRoot\_common.ps1"
# Loads config.ps1 (your values) if it exists, and defines small helper functions.

$cfg = Join-Path $PSScriptRoot "config.ps1"
if (Test-Path $cfg) { . $cfg }

# Native tools write progress text to stderr, which Windows PowerShell 5.1 treats as fatal under "Stop".
# These scripts use "Continue" plus explicit exit-code checks instead.
$ErrorActionPreference = "Continue"

function Quiet([scriptblock]$s) { $old = $ErrorActionPreference; $ErrorActionPreference = "Continue"; try { & $s 2>$null } finally { $ErrorActionPreference = $old } }
function Step($m) { Write-Host "`n=== $m" -ForegroundColor Cyan }
function Check($what) { if ($LASTEXITCODE -ne 0) { throw "Failed: $what (exit code $LASTEXITCODE)" } }
function Show($lines) { $lines | ForEach-Object { "$_" } }
function Require($name, $value, $hint) {
    if (-not $value -or $value -match '^<.*>$') { throw "Missing value for $name. $hint" }
}
