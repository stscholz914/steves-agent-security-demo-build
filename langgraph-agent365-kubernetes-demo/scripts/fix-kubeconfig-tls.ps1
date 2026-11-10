<#
.SYNOPSIS
  Lets kubectl talk to the EKS cluster from a machine behind TLS inspection (Entra Global Secure Access).
.DESCRIPTION
  kubectl only trusts the cluster's own certificate authority from the kubeconfig, so an inspecting proxy that
  re-signs the connection makes it fail with "x509: certificate signed by unknown authority".
  This adds the inspection root CA (from the Windows trusted store) to the current cluster entry in the kubeconfig.
  Safe to re-run. Does nothing on machines that are not behind TLS inspection.
  Run it after:  aws eks update-kubeconfig --name a365-demo --region us-east-2
.PARAMETER CertPattern
  Regex matched against the subject of root certificates in the Windows store.
#>
param([string]$CertPattern = 'TLS Inspection|Inspection Root|Global Secure Access')
$ErrorActionPreference = "Stop"

$inspect = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -match $CertPattern }
if (-not $inspect) { Write-Host "No TLS inspection root CA in the Windows store. kubeconfig left unchanged."; return }

$cluster = kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}'
$caB64 = kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}'
if (-not $cluster -or -not $caB64) { throw "No current cluster with embedded certificate data. Run: aws eks update-kubeconfig --name a365-demo --region us-east-2" }

$pem = [Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($caB64))
$added = 0
foreach ($c in $inspect) {
    $body = [Convert]::ToBase64String($c.RawData) -replace '\s', ''
    if (($pem -replace '\s', '') -notlike "*$body*") {
        $pem += "`n-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($c.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----`n"
        $added++
    }
}
if ($added -eq 0) { Write-Host "kubeconfig already trusts the inspection certificate."; return }

$tmp = Join-Path $env:TEMP "kube-ca-$([guid]::NewGuid().ToString('N')).pem"
try {
    [IO.File]::WriteAllText($tmp, $pem, [Text.Encoding]::ASCII)
    kubectl config set-cluster $cluster --certificate-authority=$tmp --embed-certs=true | Out-Null
} finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
Write-Host "Added $added inspection certificate(s) to kubeconfig cluster '$cluster'." -ForegroundColor Green
