<#
.SYNOPSIS
  Fixes "CERTIFICATE_VERIFY_FAILED ... self-signed certificate in certificate chain" for the AWS and Azure CLIs
  on machines behind TLS inspection (for example Microsoft Entra Global Secure Access).
.DESCRIPTION
  The AWS CLI and Azure CLI bring their own certificate list and ignore the Windows store, so they reject the
  inspection certificate. This builds a bundle (the CLI's own list + the inspection root CA from Windows) and points
  both tools at it with machine-wide environment variables. Run elevated (or via run-command). Safe to re-run.
  Afterwards open a NEW terminal window.
#>
$ErrorActionPreference = "Stop"
$out = "C:\Tools\ca-bundle.pem"
New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null

$inspect = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match 'TLS Inspection|Inspection Root|Global Secure Access' }
if (-not $inspect) { Write-Host "No TLS inspection root CA found in the Windows store. Nothing to fix."; return }

$base = Get-ChildItem "C:\Program Files\Amazon\AWSCLIV2" -Recurse -Filter cacert.pem -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $base) { $base = Get-ChildItem "C:\Program Files\Microsoft SDKs\Azure\CLI2" -Recurse -Filter cacert.pem -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (-not $base) { throw "Could not find a base certificate bundle. Install the AWS CLI first (scripts\setup-device.ps1)." }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine((Get-Content $base.FullName -Raw))
foreach ($c in $inspect) {
    $b64 = [Convert]::ToBase64String($c.RawData, 'InsertLineBreaks')
    [void]$sb.AppendLine("# $($c.Subject)")
    [void]$sb.AppendLine("-----BEGIN CERTIFICATE-----`n$b64`n-----END CERTIFICATE-----")
    Write-Host "Added: $($c.Subject)"
}
[IO.File]::WriteAllText($out, $sb.ToString(), [Text.Encoding]::ASCII)

foreach ($n in 'AWS_CA_BUNDLE', 'REQUESTS_CA_BUNDLE') {
    [Environment]::SetEnvironmentVariable($n, $out, "Machine")
}
Write-Host "Bundle written to $out and AWS_CA_BUNDLE / REQUESTS_CA_BUNDLE set machine-wide."
Write-Host "Open a NEW terminal window, then retry: aws login --region us-east-2" -ForegroundColor Green
